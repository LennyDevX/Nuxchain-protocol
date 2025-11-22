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
    uint256 private constant MAX_ACTIVE_SKILLS_PER_USER = 5;        // Global max active skills (can distribute across NFTs)
    uint256 private constant SKILL_DURATION = 30 days;
    uint256 private constant MAX_XP_REWARD_PER_SKILL = 50;          // Max XP per skill (level 1-50 progression)
    uint8 private constant MAX_LEVEL = 50;                           // Synchronized with GameifiedMarketplaceQuests
    
    // STAKING SKILLS PRICING (Skills 1-7) - Fixed prices in POL (wei)
    // COMMON=50, UNCOMMON=80, RARE=100, EPIC=150, LEGENDARY=220
    uint256 private constant STAKING_COMMON_PRICE = 50 ether;
    uint256 private constant STAKING_UNCOMMON_PRICE = 80 ether;
    uint256 private constant STAKING_RARE_PRICE = 100 ether;
    uint256 private constant STAKING_EPIC_PRICE = 150 ether;
    uint256 private constant STAKING_LEGENDARY_PRICE = 220 ether;
    
    // ACTIVE SKILLS PRICING (Skills 8-17) - 30% markup on STAKING prices
    // COMMON=65, UNCOMMON=104, RARE=130, EPIC=195, LEGENDARY=286
    uint256 private constant ACTIVE_COMMON_PRICE = 65 ether;         // 50 * 1.3
    uint256 private constant ACTIVE_UNCOMMON_PRICE = 104 ether;      // 80 * 1.3
    uint256 private constant ACTIVE_RARE_PRICE = 130 ether;          // 100 * 1.3
    uint256 private constant ACTIVE_EPIC_PRICE = 195 ether;          // 150 * 1.3
    uint256 private constant ACTIVE_LEGENDARY_PRICE = 286 ether;     // 220 * 1.3
    IStakingIntegration.SkillType private constant DEFAULT_FREE_SKILL_TYPE = IStakingIntegration.SkillType.STAKE_BOOST_I;
    IStakingIntegration.Rarity private constant DEFAULT_FREE_SKILL_RARITY = IStakingIntegration.Rarity.COMMON;
    uint256 private constant DEFAULT_FREE_SKILL_LEVEL = 1;
    
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
    mapping(address => bool) public hasClaimedFreeSkill;
    mapping(address => mapping(IStakingIntegration.SkillType => uint256)) public userActiveSkillsByType;
    mapping(address => mapping(IStakingIntegration.SkillType => uint256)) public userSkillNFTId;
    
    // Track total active skills per user (global count across all NFTs)
    mapping(address => uint256) public userTotalActiveSkills;
    
    // Skill pricing: skillType => rarity => price (in wei/POL)
    mapping(IStakingIntegration.SkillType => mapping(IStakingIntegration.Rarity => uint256)) public skillPrices;
    
    address public coreContractAddress;
    address public stakingContractAddress;
    address public treasuryAddress;
    
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
    event TreasuryAddressUpdated(address indexed oldTreasury, address indexed newTreasury);
    event EmergencyWithdrawal(address indexed admin, uint256 amount, address indexed to);
    event SkillPaymentProcessed(address indexed user, uint256 indexed tokenId, uint256 amount, string operationType);
    event FreeSkillClaimed(address indexed user, uint256 indexed tokenId, IStakingIntegration.SkillType skillType);
    
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
    error InvalidPrice(uint256 expected, uint256 provided);
    error InsufficientStakingBalance(uint256 required, uint256 current);
    error DuplicateSkillType();
    error InvalidAddress();
    error InvalidRarity(uint8 rarity);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    constructor(address _coreAddress) {
        if (_coreAddress == address(0)) revert InvalidAddress();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        coreContractAddress = _coreAddress;
        treasuryAddress = msg.sender;
        _initializeSkillPricing();
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // PRICING INITIALIZATION
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Initialize skill prices for all 17 skills × 5 rarities
     * Enum values: NONE(0), STAKE_BOOST_I(1)-STAKE_BOOST_III(3), AUTO_COMPOUND(4), LOCK_REDUCER(5),
     * FEE_REDUCER_I(6)-FEE_REDUCER_II(7), PRIORITY_LISTING(8)-PRIVATE_AUCTIONS(16)
     */
    function _initializeSkillPricing() internal {
        // STAKING SKILLS (1-7)
        for (uint8 skillType = 1; skillType <= 7; skillType++) {
            IStakingIntegration.SkillType st = IStakingIntegration.SkillType(skillType);
            skillPrices[st][IStakingIntegration.Rarity.COMMON] = STAKING_COMMON_PRICE;
            skillPrices[st][IStakingIntegration.Rarity.UNCOMMON] = STAKING_UNCOMMON_PRICE;
            skillPrices[st][IStakingIntegration.Rarity.RARE] = STAKING_RARE_PRICE;
            skillPrices[st][IStakingIntegration.Rarity.EPIC] = STAKING_EPIC_PRICE;
            skillPrices[st][IStakingIntegration.Rarity.LEGENDARY] = STAKING_LEGENDARY_PRICE;
        }
        
        // ACTIVE SKILLS (8-16)
        for (uint8 skillType = 8; skillType <= 16; skillType++) {
            IStakingIntegration.SkillType st = IStakingIntegration.SkillType(skillType);
            skillPrices[st][IStakingIntegration.Rarity.COMMON] = ACTIVE_COMMON_PRICE;
            skillPrices[st][IStakingIntegration.Rarity.UNCOMMON] = ACTIVE_UNCOMMON_PRICE;
            skillPrices[st][IStakingIntegration.Rarity.RARE] = ACTIVE_RARE_PRICE;
            skillPrices[st][IStakingIntegration.Rarity.EPIC] = ACTIVE_EPIC_PRICE;
            skillPrices[st][IStakingIntegration.Rarity.LEGENDARY] = ACTIVE_LEGENDARY_PRICE;
        }
    }
    
    /**
     * @dev Calculate skill price based on type and rarity
     */
    function _calculateSkillPrice(IStakingIntegration.SkillType _skillType, IStakingIntegration.Rarity _rarity) internal view returns (uint256) {
        return skillPrices[_skillType][_rarity];
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
     * - First skill is FREE, others are paid per fixed pricing
     */
    function registerSkillsForNFT(
        uint256 _tokenId,
        IStakingIntegration.SkillType[] calldata _skillTypes,
        IStakingIntegration.Rarity[] calldata _rarities,
        uint256[] calldata _levels
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        if (coreContractAddress == address(0)) revert CoreContractNotSet();

        bool includeFreeSkill = !hasClaimedFreeSkill[msg.sender];
        uint256 providedSkillCount = _skillTypes.length;
        uint256 totalSkillCount = providedSkillCount + (includeFreeSkill ? 1 : 0);

        if (totalSkillCount == 0 || totalSkillCount > 5) revert InvalidSkillCount();
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
        
        // Validate global active skills limit (max 5 total, distributed across NFTs)
        // Count how many skill types the user currently has active
        uint256 currentActiveCount = 0;
        for (uint256 i = 0; i < _skillTypes.length; i++) {
            if (includeFreeSkill && _skillTypes[i] == DEFAULT_FREE_SKILL_TYPE) {
                revert DuplicateSkillType();
            }
            if (userActiveSkillsByType[msg.sender][_skillTypes[i]] != 0) {
                // This skill type is already active
                emit SkillTypeAlreadyActive(msg.sender, _skillTypes[i]);
                revert SkillTypeAlreadyActiveDuplicate(_skillTypes[i]);
            }
        }
        
        // Count existing active skill types
        currentActiveCount = userTotalActiveSkills[msg.sender];
        
        // Check if adding these skills would exceed the global limit
        if (currentActiveCount + totalSkillCount > MAX_ACTIVE_SKILLS_PER_USER) {
            revert MaxActiveSkillsReached();
        }
        
        // Validate no duplicate skill types within this registration
        for (uint256 i = 0; i < _skillTypes.length; i++) {
            if (uint8(_skillTypes[i]) < 1 || uint8(_skillTypes[i]) > 16) revert InvalidSkillType();
            if (uint8(_rarities[i]) > 4) revert InvalidRarity(uint8(_rarities[i]));
            
            for (uint256 j = i + 1; j < _skillTypes.length; j++) {
                if (_skillTypes[i] == _skillTypes[j]) revert DuplicateSkillType();
            }
        }
        
        // Create NFT skill entry
        SkillNFT storage nft = skillNFTs[_tokenId];
        nft.creator = msg.sender;
        nft.createdAt = block.timestamp;
        
        uint256 totalXP = 0;
        uint256 expiryTime = block.timestamp + SKILL_DURATION;
        uint256 totalPrice = 0;
        
        // Calculate total price and validate amounts
        for (uint256 i = 0; i < _skillTypes.length; i++) {
            uint256 skillPrice = _calculateSkillPrice(_skillTypes[i], _rarities[i]);
            totalPrice += skillPrice;
        }
        
        isFirstSkillFree[_tokenId] = includeFreeSkill;
        
        // Verify payment if not free
        if (msg.value < totalPrice) {
            revert InvalidPrice(totalPrice, msg.value);
        }

        uint256 excessPayment = msg.value - totalPrice;
        
        nft.basePrice = totalPrice;
        
        for (uint256 i = 0; i < _skillTypes.length; i++) {
            Skill memory skill = Skill(
                _skillTypes[i],
                _rarities[i],
                _levels[i],
                block.timestamp,
                expiryTime
            );
            
            nft.skills.push(skill);
            skillTypeCount[_skillTypes[i]]++;
            
            userActiveSkillsByType[msg.sender][_skillTypes[i]] = _tokenId;
            userSkillNFTId[msg.sender][_skillTypes[i]] = _tokenId;
            
            // Update global active skills count
            userTotalActiveSkills[msg.sender]++;
            
            if (i == 0) {
                totalXP += 15;
            } else {
                // XP capped to MAX_XP_REWARD_PER_SKILL (50) per skill
                uint256 skillXP = 10 + (uint256(_rarities[i]) * 5);
                totalXP += skillXP > MAX_XP_REWARD_PER_SKILL ? MAX_XP_REWARD_PER_SKILL : skillXP;
            }
            
            emit SkillAdded(_tokenId, _skillTypes[i], _rarities[i]);
        }

        if (includeFreeSkill) {
            Skill memory freeSkill = Skill(
                DEFAULT_FREE_SKILL_TYPE,
                DEFAULT_FREE_SKILL_RARITY,
                DEFAULT_FREE_SKILL_LEVEL,
                block.timestamp,
                expiryTime
            );

            nft.skills.push(freeSkill);
            skillTypeCount[DEFAULT_FREE_SKILL_TYPE]++;
            userActiveSkillsByType[msg.sender][DEFAULT_FREE_SKILL_TYPE] = _tokenId;
            userSkillNFTId[msg.sender][DEFAULT_FREE_SKILL_TYPE] = _tokenId;
            userTotalActiveSkills[msg.sender]++;
            totalXP += 15;
            hasClaimedFreeSkill[msg.sender] = true;
            emit SkillAdded(_tokenId, DEFAULT_FREE_SKILL_TYPE, DEFAULT_FREE_SKILL_RARITY);
            emit FreeSkillClaimed(msg.sender, _tokenId, DEFAULT_FREE_SKILL_TYPE);
        }
        
        userSkillNFTs[msg.sender].push(_tokenId);

        if (excessPayment > 0) {
            (bool refunded, ) = payable(msg.sender).call{value: excessPayment}("");
            require(refunded, "Refund failed");
        }
        
        // Transfer payment to treasury if needed
        if (totalPrice > 0 && treasuryAddress != address(0)) {
            (bool success, ) = payable(treasuryAddress).call{value: totalPrice}("");
            if (!success) revert InvalidAddress();
            emit SkillPaymentProcessed(msg.sender, _tokenId, totalPrice, "REGISTER_SKILLS");
        }
        
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
                // Decrement global active skills count
                if (userTotalActiveSkills[nft.creator] > 0) {
                    userTotalActiveSkills[nft.creator]--;
                }
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
        
        // Calculate 50% renewal price
        uint256 renewalPrice = nft.basePrice / 2;
        if (msg.value < renewalPrice) revert InvalidPrice(renewalPrice, msg.value);
        
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
        
        // Transfer payment to treasury
        if (renewalPrice > 0 && treasuryAddress != address(0)) {
            (bool success, ) = payable(treasuryAddress).call{value: renewalPrice}("");
            if (!success) revert InvalidAddress();
            emit SkillPaymentProcessed(msg.sender, _tokenId, renewalPrice, "RENEW_SKILLS");
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
        if (msg.value < switchPrice) revert InvalidPrice(switchPrice, msg.value);
        
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
        
        // Transfer payment to treasury
        if (switchPrice > 0 && treasuryAddress != address(0)) {
            (bool success, ) = payable(treasuryAddress).call{value: switchPrice}("");
            if (!success) revert InvalidAddress();
            emit SkillPaymentProcessed(msg.sender, _newTokenId, switchPrice, "SWITCH_SKILLS");
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
        
        // Decrement global active skills count
        if (userTotalActiveSkills[msg.sender] > 0) {
            userTotalActiveSkills[msg.sender]--;
        }
        
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
    
    /**
     * @dev Get all NFTs with skills (across all users)
     * @return Array of all skill NFT token IDs
     */
    function getAllSkillNFTs() external view returns (uint256[] memory) {
        uint256 totalCounter = _skillNFTCounter.current();
        uint256 validCount = 0;
        
        // Count valid skill NFTs
        for (uint256 i = 0; i < totalCounter; i++) {
            if (skillNFTs[i].creator != address(0)) {
                validCount++;
            }
        }
        
        uint256[] memory result = new uint256[](validCount);
        uint256 index = 0;
        
        // Populate with valid skill NFT IDs
        for (uint256 i = 0; i < totalCounter; i++) {
            if (skillNFTs[i].creator != address(0)) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get all user's skill NFTs with detailed information
     * @param _user User address
     * @return tokenIds Array of token IDs
     * @return skillNFTDetails Array of SkillNFT details
     * @return expiryTimes Array of expiry timestamps
     * @return isExpired Array of expiration status
     */
    function getUserSkillNFTsWithDetails(address _user) external view returns (
        uint256[] memory tokenIds,
        SkillNFT[] memory skillNFTDetails,
        uint256[] memory expiryTimes,
        bool[] memory isExpired
    ) {
        uint256[] memory userNFTs = userSkillNFTs[_user];
        uint256 count = userNFTs.length;
        
        tokenIds = new uint256[](count);
        skillNFTDetails = new SkillNFT[](count);
        expiryTimes = new uint256[](count);
        isExpired = new bool[](count);
        
        for (uint256 i = 0; i < count; i++) {
            uint256 nftId = userNFTs[i];
            tokenIds[i] = nftId;
            skillNFTDetails[i] = skillNFTs[nftId];
            
            uint256 expiryTime = _getSkillExpiryTime(nftId);
            expiryTimes[i] = expiryTime;
            isExpired[i] = block.timestamp >= expiryTime;
        }
        
        return (tokenIds, skillNFTDetails, expiryTimes, isExpired);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function setStakingContract(address _stakingAddress) external onlyRole(ADMIN_ROLE) {
        if (_stakingAddress == address(0)) revert InvalidAddress();
        address oldStaking = stakingContractAddress;
        stakingContractAddress = _stakingAddress;
        emit StakingContractUpdated(oldStaking, _stakingAddress);
    }
    
    function setTreasuryAddress(address _treasuryAddress) external onlyRole(ADMIN_ROLE) {
        if (_treasuryAddress == address(0)) revert InvalidAddress();
        address oldTreasury = treasuryAddress;
        treasuryAddress = _treasuryAddress;
        emit TreasuryAddressUpdated(oldTreasury, _treasuryAddress);
    }
    
    /**
     * @dev Emergency withdraw stuck funds to treasury
     * USAGE: If treasury transfer fails during registerSkillsForNFT, renewSkill, or switchSkill,
     * funds are held in contract. Admin can withdraw them with this function.
     * 
     * FUNDS SOURCE:
     * - registerSkillsForNFT: First skill free, rest paid (2+ skills = price collected)
     * - renewSkill: 50% of original registration price
     * - switchSkill: 25% of original registration price
     * 
     * @param _amount Amount to withdraw in wei/POL
     */
    function emergencyWithdraw(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        if (_amount == 0) revert InvalidPrice(_amount, 0);
        if (_amount > address(this).balance) revert InvalidPrice(_amount, address(this).balance);
        if (treasuryAddress == address(0)) revert InvalidAddress();
        
        (bool success, ) = payable(treasuryAddress).call{value: _amount}("");
        if (!success) revert InvalidAddress();
    }
    
    /**
     * @dev Withdraw all stuck funds to treasury
     * Transfers entire contract balance to treasury address
     */
    function emergencyWithdrawAll() external onlyRole(ADMIN_ROLE) {
        if (treasuryAddress == address(0)) revert InvalidAddress();
        uint256 balance = address(this).balance;
        if (balance == 0) revert InvalidPrice(0, balance);
        
        (bool success, ) = payable(treasuryAddress).call{value: balance}("");
        if (!success) revert InvalidAddress();
    }
    
    /**
     * @dev Update individual skill price (admin only)
     */
    function updateSkillPrice(IStakingIntegration.SkillType _skillType, IStakingIntegration.Rarity _rarity, uint256 _newPrice) external onlyRole(ADMIN_ROLE) {
        if (uint8(_skillType) < 1 || uint8(_skillType) > 16) revert InvalidSkillType();
        if (uint8(_rarity) > 4) revert InvalidRarity(uint8(_rarity));
        skillPrices[_skillType][_rarity] = _newPrice;
    }
    
    /**
     * @dev Update all staking skills pricing (skills 1-7)
     */
    function updateStakingSkillsPricing(uint256 _common, uint256 _uncommon, uint256 _rare, uint256 _epic, uint256 _legendary) external onlyRole(ADMIN_ROLE) {
        for (uint8 skillType = 1; skillType <= 7; skillType++) {
            IStakingIntegration.SkillType st = IStakingIntegration.SkillType(skillType);
            skillPrices[st][IStakingIntegration.Rarity.COMMON] = _common;
            skillPrices[st][IStakingIntegration.Rarity.UNCOMMON] = _uncommon;
            skillPrices[st][IStakingIntegration.Rarity.RARE] = _rare;
            skillPrices[st][IStakingIntegration.Rarity.EPIC] = _epic;
            skillPrices[st][IStakingIntegration.Rarity.LEGENDARY] = _legendary;
        }
    }
    
    /**
     * @dev Update all active skills pricing (skills 8-16)
     */
    function updateActiveSkillsPricing(uint256 _common, uint256 _uncommon, uint256 _rare, uint256 _epic, uint256 _legendary) external onlyRole(ADMIN_ROLE) {
        for (uint8 skillType = 8; skillType <= 16; skillType++) {
            IStakingIntegration.SkillType st = IStakingIntegration.SkillType(skillType);
            skillPrices[st][IStakingIntegration.Rarity.COMMON] = _common;
            skillPrices[st][IStakingIntegration.Rarity.UNCOMMON] = _uncommon;
            skillPrices[st][IStakingIntegration.Rarity.RARE] = _rare;
            skillPrices[st][IStakingIntegration.Rarity.EPIC] = _epic;
            skillPrices[st][IStakingIntegration.Rarity.LEGENDARY] = _legendary;
        }
    }
    
    /**
     * @dev Get skill price (public view)
     */
    function getSkillPrice(IStakingIntegration.SkillType _skillType, IStakingIntegration.Rarity _rarity) external view returns (uint256) {
        return skillPrices[_skillType][_rarity];
    }
    
    /**
     * @dev Get all prices for a skill across all rarities
     */
    function getSkillPricesAllRarities(IStakingIntegration.SkillType _skillType) external view returns (uint256[5] memory) {
        uint256[5] memory prices;
        prices[0] = skillPrices[_skillType][IStakingIntegration.Rarity.COMMON];
        prices[1] = skillPrices[_skillType][IStakingIntegration.Rarity.UNCOMMON];
        prices[2] = skillPrices[_skillType][IStakingIntegration.Rarity.RARE];
        prices[3] = skillPrices[_skillType][IStakingIntegration.Rarity.EPIC];
        prices[4] = skillPrices[_skillType][IStakingIntegration.Rarity.LEGENDARY];
        return prices;
    }
    
    /**
     * @dev Get user's total active skills count
     */
    function getUserTotalActiveSkills(address _user) external view returns (uint256) {
        return userTotalActiveSkills[_user];
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // DASHBOARD VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @dev Get skill marketplace statistics
     */
    function getSkillMarketStats() external view returns (
        uint256 totalSkillNFTs,
        uint256 totalActiveSkills,
        uint256 totalExpiredSkills,
        uint256 totalSkillsSold,
        uint256 totalRevenue,
        uint256 averageSkillsPerNFT
    ) {
        uint256 counter = _skillNFTCounter.current();
        uint256 validNFTs = 0;
        uint256 activeCount = 0;
        uint256 expiredCount = 0;
        uint256 totalSkills = 0;
        
        for (uint256 i = 0; i < counter; i++) {
            if (skillNFTs[i].creator != address(0)) {
                validNFTs++;
                totalRevenue += skillNFTs[i].basePrice;
                uint256 skillCount = skillNFTs[i].skills.length;
                totalSkills += skillCount;
                
                uint256 expiryTime = _getSkillExpiryTime(i);
                if (block.timestamp < expiryTime) {
                    activeCount++;
                } else {
                    expiredCount++;
                }
            }
        }
        
        totalSkillNFTs = validNFTs;
        totalActiveSkills = activeCount;
        totalExpiredSkills = expiredCount;
        totalSkillsSold = validNFTs;
        averageSkillsPerNFT = validNFTs > 0 ? totalSkills / validNFTs : 0;
    }

    /**
     * @dev Get user skill portfolio summary
     */
    function getUserSkillPortfolio(address _user) external view returns (
        uint256 totalSkillNFTs,
        uint256 activeSkillNFTs,
        uint256 expiredSkillNFTs,
        uint256 totalActiveSkills,
        uint256 stakingSkillsCount,
        uint256 platformSkillsCount,
        uint256 expiringIn24h,
        uint256 totalSpentOnSkills
    ) {
        uint256[] memory userNFTs = userSkillNFTs[_user];
        totalSkillNFTs = userNFTs.length;
        
        uint256 cutoff24h = block.timestamp + 24 hours;
        
        for (uint256 i = 0; i < userNFTs.length; i++) {
            uint256 tokenId = userNFTs[i];
            SkillNFT storage nft = skillNFTs[tokenId];
            
            totalSpentOnSkills += nft.basePrice;
            uint256 expiryTime = _getSkillExpiryTime(tokenId);
            
            if (block.timestamp < expiryTime) {
                activeSkillNFTs++;
                
                if (expiryTime <= cutoff24h) {
                    expiringIn24h++;
                }
            } else {
                expiredSkillNFTs++;
            }
            
            for (uint256 j = 0; j < nft.skills.length; j++) {
                uint8 skillTypeInt = uint8(nft.skills[j].skillType);
                if (skillTypeInt >= 1 && skillTypeInt <= 7) {
                    stakingSkillsCount++;
                } else if (skillTypeInt >= 8 && skillTypeInt <= 16) {
                    platformSkillsCount++;
                }
            }
        }
        
        totalActiveSkills = userTotalActiveSkills[_user];
    }

    /**
     * @dev Get skills expiring soon for a user
     * @param _user User address
     * @param _hoursThreshold Hours until expiry (e.g., 24 for next day)
     */
    function getExpiringSkills(address _user, uint256 _hoursThreshold) 
        external view returns (
            uint256[] memory tokenIds,
            uint256[] memory expiryTimes,
            Skill[][] memory skills
        )
    {
        uint256[] memory userNFTs = userSkillNFTs[_user];
        uint256 cutoff = block.timestamp + (_hoursThreshold * 1 hours);
        uint256 count = 0;
        
        for (uint256 i = 0; i < userNFTs.length; i++) {
            uint256 expiryTime = _getSkillExpiryTime(userNFTs[i]);
            if (expiryTime > block.timestamp && expiryTime <= cutoff) {
                count++;
            }
        }
        
        tokenIds = new uint256[](count);
        expiryTimes = new uint256[](count);
        skills = new Skill[][](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < userNFTs.length; i++) {
            uint256 tokenId = userNFTs[i];
            uint256 expiryTime = _getSkillExpiryTime(tokenId);
            if (expiryTime > block.timestamp && expiryTime <= cutoff) {
                tokenIds[index] = tokenId;
                expiryTimes[index] = expiryTime;
                skills[index] = skillNFTs[tokenId].skills;
                index++;
            }
        }
    }

    /**
     * @dev Get popular skills by purchase count
     */
    function getPopularSkills(uint256 _limit) external view returns (
        IStakingIntegration.SkillType[] memory skillTypes,
        uint256[] memory purchaseCounts,
        IStakingIntegration.Rarity[] memory mostBoughtRarity
    ) {
        uint256 totalSkillTypes = 16;
        uint256[] memory counts = new uint256[](totalSkillTypes);
        
        for (uint8 i = 1; i <= totalSkillTypes; i++) {
            counts[i - 1] = skillTypeCount[IStakingIntegration.SkillType(i)];
        }
        
        uint256 resultSize = _limit < totalSkillTypes ? _limit : totalSkillTypes;
        skillTypes = new IStakingIntegration.SkillType[](resultSize);
        purchaseCounts = new uint256[](resultSize);
        mostBoughtRarity = new IStakingIntegration.Rarity[](resultSize);
        
        for (uint256 i = 0; i < resultSize; i++) {
            uint256 maxCount = 0;
            uint8 maxIndex = 0;
            
            for (uint8 j = 0; j < totalSkillTypes; j++) {
                if (counts[j] > maxCount) {
                    maxCount = counts[j];
                    maxIndex = j;
                }
            }
            
            skillTypes[i] = IStakingIntegration.SkillType(maxIndex + 1);
            purchaseCounts[i] = maxCount;
            mostBoughtRarity[i] = IStakingIntegration.Rarity.COMMON;
            counts[maxIndex] = 0;
        }
    }

    /**
     * @dev Get skill breakdown by rarity
     */
    function getSkillRarityDistribution() external view returns (
        uint256 commonCount,
        uint256 uncommonCount,
        uint256 rareCount,
        uint256 epicCount,
        uint256 legendaryCount
    ) {
        uint256 counter = _skillNFTCounter.current();
        
        for (uint256 i = 0; i < counter; i++) {
            if (skillNFTs[i].creator != address(0)) {
                Skill[] storage skills = skillNFTs[i].skills;
                for (uint256 j = 0; j < skills.length; j++) {
                    if (skills[j].rarity == IStakingIntegration.Rarity.COMMON) {
                        commonCount++;
                    } else if (skills[j].rarity == IStakingIntegration.Rarity.UNCOMMON) {
                        uncommonCount++;
                    } else if (skills[j].rarity == IStakingIntegration.Rarity.RARE) {
                        rareCount++;
                    } else if (skills[j].rarity == IStakingIntegration.Rarity.EPIC) {
                        epicCount++;
                    } else if (skills[j].rarity == IStakingIntegration.Rarity.LEGENDARY) {
                        legendaryCount++;
                    }
                }
            }
        }
    }

    /**
     * @dev Get all user skills grouped by type and rarity
     */
    function getUserSkillsGrouped(address _user) external view returns (
        IStakingIntegration.SkillType[] memory skillTypes,
        IStakingIntegration.Rarity[] memory rarities,
        uint256[] memory counts
    ) {
        uint256[] memory userNFTs = userSkillNFTs[_user];
        uint256 maxSize = 16 * 5;
        
        IStakingIntegration.SkillType[] memory tempTypes = new IStakingIntegration.SkillType[](maxSize);
        IStakingIntegration.Rarity[] memory tempRarities = new IStakingIntegration.Rarity[](maxSize);
        uint256[] memory tempCounts = new uint256[](maxSize);
        uint256 uniqueCount = 0;
        
        for (uint256 i = 0; i < userNFTs.length; i++) {
            Skill[] storage skills = skillNFTs[userNFTs[i]].skills;
            for (uint256 j = 0; j < skills.length; j++) {
                bool found = false;
                for (uint256 k = 0; k < uniqueCount; k++) {
                    if (tempTypes[k] == skills[j].skillType && tempRarities[k] == skills[j].rarity) {
                        tempCounts[k]++;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    tempTypes[uniqueCount] = skills[j].skillType;
                    tempRarities[uniqueCount] = skills[j].rarity;
                    tempCounts[uniqueCount] = 1;
                    uniqueCount++;
                }
            }
        }
        
        skillTypes = new IStakingIntegration.SkillType[](uniqueCount);
        rarities = new IStakingIntegration.Rarity[](uniqueCount);
        counts = new uint256[](uniqueCount);
        
        for (uint256 i = 0; i < uniqueCount; i++) {
            skillTypes[i] = tempTypes[i];
            rarities[i] = tempRarities[i];
            counts[i] = tempCounts[i];
        }
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    receive() external payable {}
}
