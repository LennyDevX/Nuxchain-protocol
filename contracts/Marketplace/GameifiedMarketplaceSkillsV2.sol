// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/IStakingIntegration.sol";

/**
 * @title GameifiedMarketplaceSkillsV2
 * @dev NFT Skills system - embedded skills in marketplace NFTs
 * 
 * ARCHITECTURE:
 * This contract handles ONLY NFT-embedded skills.
 * Individual skills are now managed by IndividualSkillsMarketplace.sol
 * 
 * SKILLS: 17 total × 5 rarities = 85 combinations
 * - STAKING SKILLS (7): Affect staking rewards (STAKE_BOOST_I/II/III, AUTO_COMPOUND, LOCK_REDUCER, FEE_REDUCER_I/II)
 * - ACTIVE SKILLS (10): Platform features (PRIORITY_LISTING, BATCH_MINTER, VERIFIED_CREATOR, etc.)
 * 
 * FEATURES:
 * - Register skills for NFTs
 * - 30-day expiration with renewal
 * - Switch skills between NFTs with 25% fee
 * - Integrate with EnhancedSmartStaking
 * 
 * @custom:security-contact security@nuvo.com
 */

interface IGameifiedMarketplaceCore {
    function createStandardNFT(
        string calldata _tokenURI,
        string calldata _category,
        uint96 _royaltyPercentage
    ) external returns (uint256);
    
    function updateUserXP(address _user, uint256 _amount) external;
}

interface IEnhancedSmartStaking {
    function getTotalDeposit(address user) external view returns (uint256);
}

contract GameifiedMarketplaceSkillsV2 is AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    uint256 private constant MIN_STAKING_REQUIREMENT = 250 ether;  // 250 POL minimum
    uint256 private constant MAX_ACTIVE_SKILLS_PER_USER = 3;
    uint256 private constant SKILL_DURATION = 30 days;
    uint256 private constant MAX_XP_REWARD_PER_SKILL = 50;          // Max XP per skill (level 1-50 progression)
    uint8 private constant MAX_LEVEL = 50;                           // Synchronized with GameifiedMarketplaceQuests
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTURES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    struct Skill {
        IStakingIntegration.SkillType skillType;
        IStakingIntegration.Rarity rarity;
        uint256 level;
        uint256 createdAt;
        uint256 expiresAt;
    }
    
    struct SkillNFT {
        address creator;
        Skill[] skills;
        uint256 createdAt;
        uint256 basePrice;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    Counters.Counter private _skillNFTCounter;
    
    mapping(uint256 => SkillNFT) public skillNFTs;
    mapping(address => uint256[]) public userSkillNFTs;
    mapping(IStakingIntegration.SkillType => uint256) public skillTypeCount;
    mapping(uint256 => bool) public isFirstSkillFree;
    mapping(address => mapping(IStakingIntegration.SkillType => uint256)) public userActiveSkillsByType;
    mapping(address => mapping(IStakingIntegration.SkillType => uint256)) public userSkillNFTId;
    
    address public coreContractAddress;
    address public stakingContractAddress;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    event SkillNFTCreated(
        address indexed creator,
        uint256 indexed tokenId,
        uint256 skillCount,
        uint256 totalXP
    );
    
    event SkillAdded(uint256 indexed tokenId, IStakingIntegration.SkillType skillType, IStakingIntegration.Rarity rarity);
    event SkillExpired(address indexed user, uint256 indexed tokenId, IStakingIntegration.SkillType skillType);
    event SkillRenewed(address indexed user, uint256 indexed tokenId, uint256 newExpiryTime);
    event SkillTypeAlreadyActive(address indexed user, IStakingIntegration.SkillType skillType);
    event SkillSwitched(
        address indexed user,
        uint256 indexed oldTokenId,
        uint256 indexed newTokenId,
        IStakingIntegration.SkillType skillType,
        uint256 switchFee
    );
    event SkillDeactivatedManually(
        address indexed user,
        uint256 indexed tokenId,
        IStakingIntegration.SkillType skillType
    );
    event StakingContractUpdated(address indexed oldStaking, address indexed newStaking);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    error InvalidSkillCount();
    error InvalidSkillType();
    error CoreContractNotSet();
    error SkillTypeAlreadyActiveDuplicate(IStakingIntegration.SkillType skillType);
    error MaxActiveSkillsReached();
    error SkillNotExpiredYet(uint256 expiryTime);
    error NotSkillOwner();
    error SkillNFTNotFound();
    error InvalidPrice();
    error InsufficientStakingBalance(uint256 required, uint256 current);
    error DuplicateSkillType();
    error InvalidAddress();
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    constructor(address _coreAddress) {
        if (_coreAddress == address(0)) revert InvalidAddress();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        coreContractAddress = _coreAddress;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MAIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Register skills for NFT
     * REQUIREMENTS:
     * - User must have minimum 250 POL staking
     * - No duplicate skill types per NFT
     * - Max 5 skills per NFT
     * - Each skill type can only be active once per user
     */
    function registerSkillsForNFT(
        uint256 _tokenId,
        IStakingIntegration.SkillType[] calldata _skillTypes,
        IStakingIntegration.Rarity[] calldata _rarities,
        uint256[] calldata _levels,
        uint256 _basePrice
    ) external whenNotPaused nonReentrant returns (uint256) {
        if (coreContractAddress == address(0)) revert CoreContractNotSet();
        if (_skillTypes.length == 0 || _skillTypes.length > 5) revert InvalidSkillCount();
        if (_skillTypes.length != _rarities.length || _skillTypes.length != _levels.length) {
            revert InvalidSkillCount();
        }
        
        // Verify minimum staking requirement (250 POL)
        if (stakingContractAddress != address(0)) {
            try IEnhancedSmartStaking(stakingContractAddress).getTotalDeposit(msg.sender) returns (uint256 totalDeposit) {
                if (totalDeposit < MIN_STAKING_REQUIREMENT) {
                    revert InsufficientStakingBalance(MIN_STAKING_REQUIREMENT, totalDeposit);
                }
            } catch {}
        }
        
        // Validate active skills limit
        uint256 activeSkillsCount = 0;
        for (uint256 k = 0; k < userSkillNFTs[msg.sender].length; k++) {
            if (block.timestamp < _getSkillExpiryTime(userSkillNFTs[msg.sender][k])) {
                activeSkillsCount++;
            }
        }
        if (activeSkillsCount >= MAX_ACTIVE_SKILLS_PER_USER) revert MaxActiveSkillsReached();
        
        // Validate no duplicate skill types and check if user already has each skill type active
        for (uint256 i = 0; i < _skillTypes.length; i++) {
            if (uint8(_skillTypes[i]) < 1 || uint8(_skillTypes[i]) > 17) revert InvalidSkillType();
            
            for (uint256 j = i + 1; j < _skillTypes.length; j++) {
                if (_skillTypes[i] == _skillTypes[j]) revert DuplicateSkillType();
            }
            
            if (userActiveSkillsByType[msg.sender][_skillTypes[i]] != 0) {
                emit SkillTypeAlreadyActive(msg.sender, _skillTypes[i]);
                revert SkillTypeAlreadyActiveDuplicate(_skillTypes[i]);
            }
        }
        
        // Create NFT skill entry
        SkillNFT storage nft = skillNFTs[_tokenId];
        nft.creator = msg.sender;
        nft.createdAt = block.timestamp;
        nft.basePrice = _basePrice;
        
        uint256 totalXP = 0;
        uint256 expiryTime = block.timestamp + SKILL_DURATION;
        
        for (uint256 i = 0; i < _skillTypes.length; i++) {
            Skill memory skill = Skill({
                skillType: _skillTypes[i],
                rarity: _rarities[i],
                level: _levels[i],
                createdAt: block.timestamp,
                expiresAt: expiryTime
            });
            
            nft.skills.push(skill);
            skillTypeCount[_skillTypes[i]]++;
            
            userActiveSkillsByType[msg.sender][_skillTypes[i]] = _tokenId;
            userSkillNFTId[msg.sender][_skillTypes[i]] = _tokenId;
            
            if (i == 0) {
                isFirstSkillFree[_tokenId] = true;
                totalXP += 15;
            } else {
                // XP capped to MAX_XP_REWARD_PER_SKILL (50) per skill
                uint256 skillXP = 10 + (uint256(_rarities[i]) * 5);
                totalXP += skillXP > MAX_XP_REWARD_PER_SKILL ? MAX_XP_REWARD_PER_SKILL : skillXP;
            }
            
            emit SkillAdded(_tokenId, _skillTypes[i], _rarities[i]);
        }
        
        userSkillNFTs[msg.sender].push(_tokenId);
        
        IGameifiedMarketplaceCore(coreContractAddress).updateUserXP(msg.sender, totalXP);
        
        // Notify staking contract
        if (stakingContractAddress != address(0)) {
            for (uint256 i = 0; i < _skillTypes.length; i++) {
                uint16 skillValue = uint16(5 + (uint256(_rarities[i]) * 2));
                // solhint-disable-next-line avoid-low-level-calls
                (bool success, ) = stakingContractAddress.call(
                    abi.encodeWithSignature(
                        "notifySkillActivation(address,uint256,uint8,uint16)",
                        msg.sender,
                        _tokenId,
                        uint8(_skillTypes[i]),
                        skillValue
                    )
                );
                // Continue even if notification fails
                if (!success) continue;
            }
        }
        
        emit SkillNFTCreated(msg.sender, _tokenId, _skillTypes.length, totalXP);
        return _tokenId;
    }
    
    /**
     * @dev Deactivate expired skill
     */
    function deactivateExpiredSkill(uint256 _tokenId) external {
        SkillNFT storage nft = skillNFTs[_tokenId];
        if (nft.creator == address(0)) revert SkillNFTNotFound();
        
        uint256 expiryTime = _getSkillExpiryTime(_tokenId);
        if (block.timestamp < expiryTime) revert SkillNotExpiredYet(expiryTime);
        
        for (uint256 i = 0; i < nft.skills.length; i++) {
            IStakingIntegration.SkillType skillType = nft.skills[i].skillType;
            
            if (userActiveSkillsByType[nft.creator][skillType] == _tokenId) {
                userActiveSkillsByType[nft.creator][skillType] = 0;
                userSkillNFTId[nft.creator][skillType] = 0;
            }
            
            emit SkillExpired(nft.creator, _tokenId, skillType);
        }
    }
    
    /**
     * @dev Renew expired NFT skill
     * COST: 50% of original price
     */
    function renewSkill(uint256 _tokenId) external payable whenNotPaused nonReentrant {
        SkillNFT storage nft = skillNFTs[_tokenId];
        if (nft.creator != msg.sender) revert NotSkillOwner();
        
        uint256 expiryTime = _getSkillExpiryTime(_tokenId);
        if (block.timestamp < expiryTime) revert SkillNotExpiredYet(expiryTime);
        
        uint256 renewalPrice = nft.basePrice / 2;
        if (msg.value < renewalPrice) revert InvalidPrice();
        
        uint256 newExpiryTime = block.timestamp + SKILL_DURATION;
        for (uint256 i = 0; i < nft.skills.length; i++) {
            nft.skills[i].expiresAt = newExpiryTime;
        }
        
        // Notify staking contract
        if (stakingContractAddress != address(0)) {
            for (uint256 i = 0; i < nft.skills.length; i++) {
                uint16 skillValue = uint16(5 + (uint256(nft.skills[i].rarity) * 2));
                // solhint-disable-next-line avoid-low-level-calls
                (bool success, ) = stakingContractAddress.call(
                    abi.encodeWithSignature(
                        "notifySkillActivation(address,uint256,uint8,uint16)",
                        msg.sender,
                        _tokenId,
                        uint8(nft.skills[i].skillType),
                        skillValue
                    )
                );
                // Continue even if notification fails
                if (!success) continue;
            }
        }
        
        // Transfer payment
        if (msg.value > 0) {
            (bool success, ) = payable(coreContractAddress).call{value: msg.value}("");
            if (!success) revert InvalidAddress();
        }
        
        emit SkillRenewed(msg.sender, _tokenId, newExpiryTime);
    }
    
    /**
     * @dev Switch skill instantly with 25% fee
     */
    function switchSkill(
        uint256 _oldTokenId,
        uint256 _newTokenId,
        IStakingIntegration.SkillType _skillType
    ) external payable whenNotPaused nonReentrant {
        SkillNFT storage oldNFT = skillNFTs[_oldTokenId];
        SkillNFT storage newNFT = skillNFTs[_newTokenId];
        
        if (oldNFT.creator != msg.sender) revert NotSkillOwner();
        if (newNFT.creator != msg.sender) revert NotSkillOwner();
        
        // Verify old NFT has the skill and it's active
        bool oldHasSkill = false;
        IStakingIntegration.Rarity oldRarity;
        
        for (uint256 i = 0; i < oldNFT.skills.length; i++) {
            if (oldNFT.skills[i].skillType == _skillType) {
                oldHasSkill = true;
                oldRarity = oldNFT.skills[i].rarity;
                break;
            }
        }
        
        if (!oldHasSkill) revert InvalidSkillType();
        if (userActiveSkillsByType[msg.sender][_skillType] != _oldTokenId) revert InvalidSkillType();
        
        // Verify new NFT has the skill and it's not expired
        bool newHasSkill = false;
        IStakingIntegration.Rarity newRarity;
        
        for (uint256 i = 0; i < newNFT.skills.length; i++) {
            if (newNFT.skills[i].skillType == _skillType) {
                newHasSkill = true;
                newRarity = newNFT.skills[i].rarity;
                break;
            }
        }
        
        if (!newHasSkill) revert InvalidSkillType();
        if (block.timestamp >= _getSkillExpiryTime(_newTokenId)) revert SkillNotExpiredYet(_getSkillExpiryTime(_newTokenId));
        
        // Calculate and verify switch fee (25% of original price)
        uint256 switchPrice = oldNFT.basePrice / 4;
        if (msg.value < switchPrice) revert InvalidPrice();
        
        // Deactivate old and activate new
        if (stakingContractAddress != address(0)) {
            // Notify deactivation
            // solhint-disable-next-line avoid-low-level-calls
            (bool success1, ) = stakingContractAddress.call(
                abi.encodeWithSignature(
                    "notifySkillDeactivation(address,uint256)",
                    msg.sender,
                    _oldTokenId
                )
            );
            // Continue even if notification fails
            if (!success1) {}
            
            // Notify activation
            uint16 skillValue = uint16(5 + (uint256(newRarity) * 2));
            // solhint-disable-next-line avoid-low-level-calls
            (bool success2, ) = stakingContractAddress.call(
                abi.encodeWithSignature(
                    "notifySkillActivation(address,uint256,uint8,uint16)",
                    msg.sender,
                    _newTokenId,
                    uint8(_skillType),
                    skillValue
                )
            );
            // Continue even if notification fails
            if (!success2) {}
        }
        
        userActiveSkillsByType[msg.sender][_skillType] = _newTokenId;
        userSkillNFTId[msg.sender][_skillType] = _newTokenId;
        
        // Transfer payment
        if (msg.value > 0) {
            (bool success, ) = payable(coreContractAddress).call{value: msg.value}("");
            if (!success) revert InvalidAddress();
        }
        
        emit SkillSwitched(msg.sender, _oldTokenId, _newTokenId, _skillType, switchPrice);
    }
    
    /**
     * @dev Deactivate skill manually
     */
    function deactivateSkillManually(
        uint256 _tokenId,
        IStakingIntegration.SkillType _skillType
    ) external whenNotPaused {
        SkillNFT storage nft = skillNFTs[_tokenId];
        if (nft.creator != msg.sender) revert NotSkillOwner();
        if (userActiveSkillsByType[msg.sender][_skillType] != _tokenId) revert InvalidSkillType();
        
        bool found = false;
        for (uint256 i = 0; i < nft.skills.length; i++) {
            if (nft.skills[i].skillType == _skillType) {
                found = true;
                break;
            }
        }
        if (!found) revert InvalidSkillType();
        
        if (stakingContractAddress != address(0)) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = stakingContractAddress.call(
                abi.encodeWithSignature(
                    "notifySkillDeactivation(address,uint256)",
                    msg.sender,
                    _tokenId
                )
            );
            // Continue even if notification fails
            if (!success) {}
        }
        
        userActiveSkillsByType[msg.sender][_skillType] = 0;
        userSkillNFTId[msg.sender][_skillType] = 0;
        
        emit SkillDeactivatedManually(msg.sender, _tokenId, _skillType);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Helper: Get skill expiry time for NFT
     */
    function _getSkillExpiryTime(uint256 _tokenId) internal view returns (uint256) {
        SkillNFT storage nft = skillNFTs[_tokenId];
        if (nft.skills.length == 0) return 0;
        return nft.skills[0].expiresAt;
    }
    
    function isSkillExpired(uint256 _tokenId) external view returns (bool) {
        uint256 expiryTime = _getSkillExpiryTime(_tokenId);
        return block.timestamp >= expiryTime;
    }
    
    function getSkillExpiryTime(uint256 _tokenId) external view returns (uint256) {
        return _getSkillExpiryTime(_tokenId);
    }
    
    function getActiveSkillsForUser(address _user) external view returns (uint256[] memory) {
        uint256[] memory allSkills = userSkillNFTs[_user];
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < allSkills.length; i++) {
            if (block.timestamp < _getSkillExpiryTime(allSkills[i])) {
                activeCount++;
            }
        }
        
        uint256[] memory activeSkills = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allSkills.length; i++) {
            if (block.timestamp < _getSkillExpiryTime(allSkills[i])) {
                activeSkills[index] = allSkills[i];
                index++;
            }
        }
        
        return activeSkills;
    }
    
    function getSkillNFTSkills(uint256 _tokenId) external view returns (Skill[] memory) {
        return skillNFTs[_tokenId].skills;
    }
    
    function getSkillNFT(uint256 _tokenId) external view returns (SkillNFT memory) {
        return skillNFTs[_tokenId];
    }
    
    function getUserSkillNFTs(address _user) external view returns (uint256[] memory) {
        return userSkillNFTs[_user];
    }
    
    function getSkillTypeCount(IStakingIntegration.SkillType _skillType) external view returns (uint256) {
        return skillTypeCount[_skillType];
    }
    
    function getSkillSwitchInfo(
        address _user,
        IStakingIntegration.SkillType _skillType
    ) external view returns (
        uint256 activeTokenId,
        uint256 expiresAt,
        bool canSwitch
    ) {
        activeTokenId = userActiveSkillsByType[_user][_skillType];
        
        if (activeTokenId == 0) {
            return (0, 0, true);
        }
        
        expiresAt = _getSkillExpiryTime(activeTokenId);
        
        uint256[] memory allSkills = userSkillNFTs[_user];
        for (uint256 i = 0; i < allSkills.length; i++) {
            if (allSkills[i] != activeTokenId) {
                SkillNFT storage nft = skillNFTs[allSkills[i]];
                for (uint256 j = 0; j < nft.skills.length; j++) {
                    if (nft.skills[j].skillType == _skillType) {
                        if (block.timestamp < _getSkillExpiryTime(allSkills[i])) {
                            canSwitch = true;
                            break;
                        }
                    }
                }
                if (canSwitch) break;
            }
        }
    }
    
    function getUserSkillsByType(
        address _user,
        IStakingIntegration.SkillType _skillType
    ) external view returns (
        uint256[] memory tokenIds,
        uint8[] memory statuses
    ) {
        uint256[] memory allSkills = userSkillNFTs[_user];
        uint256 count = 0;
        
        for (uint256 i = 0; i < allSkills.length; i++) {
            SkillNFT storage nft = skillNFTs[allSkills[i]];
            for (uint256 j = 0; j < nft.skills.length; j++) {
                if (nft.skills[j].skillType == _skillType) {
                    count++;
                    break;
                }
            }
        }
        
        tokenIds = new uint256[](count);
        statuses = new uint8[](count);
        uint256 index = 0;
        uint256 activeToken = userActiveSkillsByType[_user][_skillType];
        
        for (uint256 i = 0; i < allSkills.length; i++) {
            SkillNFT storage nft = skillNFTs[allSkills[i]];
            bool found = false;
            
            for (uint256 j = 0; j < nft.skills.length; j++) {
                if (nft.skills[j].skillType == _skillType) {
                    found = true;
                    break;
                }
            }
            
            if (found) {
                tokenIds[index] = allSkills[i];
                
                if (allSkills[i] == activeToken) {
                    statuses[index] = 0; // Active
                } else if (block.timestamp >= _getSkillExpiryTime(allSkills[i])) {
                    statuses[index] = 2; // Expired
                } else {
                    statuses[index] = 1; // Inactive available
                }
                
                index++;
            }
        }
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function setStakingContract(address _stakingAddress) external onlyRole(ADMIN_ROLE) {
        if (_stakingAddress == address(0)) revert InvalidAddress();
        address oldStaking = stakingContractAddress;
        stakingContractAddress = _stakingAddress;
        emit StakingContractUpdated(oldStaking, _stakingAddress);
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    receive() external payable {}
}
