// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/IStakingIntegration.sol";
import "../interfaces/IIndividualSkills.sol";

/**
 * @title IndividualSkillsMarketplace
 * @dev Marketplace for purchasing and managing individual skills without NFT minting
 * 
 * KEY FEATURES:
 * - Purchase skills directly without minting NFTs
 * - Activate/Deactivate skills for staking bonuses or platform features
 * - Transfer skills between wallets (gift functionality)
 * - 30-day expiration with renewal option
 * - Integrates with EnhancedSmartStaking for reward multipliers
 * 
 * SKILL CATEGORIES (17 total):
 * - STAKING SKILLS (7): Direct rewards impact (STAKE_BOOST_I/II/III, AUTO_COMPOUND, LOCK_REDUCER, FEE_REDUCER_I/II)
 * - ACTIVE SKILLS (10): Platform features (PRIORITY_LISTING, BATCH_MINTER, VERIFIED_CREATOR, etc.)
 * 
 * PRICING: 0.1 ETH + (rarity × 0.05 ETH)
 * VARIETIES: 17 skills × 5 rarities = 85 total combinations
 * 
 * @custom:security-contact security@nuvo.com
 */
contract IndividualSkillsMarketplace is AccessControl, Pausable, ReentrancyGuard, IIndividualSkills {
    using Counters for Counters.Counter;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    uint256 private constant MIN_STAKING_REQUIREMENT = 250 ether;      // 250 POL minimum
    uint256 private constant INDIVIDUAL_SKILL_BASE_PRICE = 0.1 ether;  // Base price 0.1 ETH
    uint256 private constant RARITY_MULTIPLIER = 0.05 ether;           // +0.05 ETH per rarity
    uint256 private constant MAX_ACTIVE_SKILLS_PER_TYPE = 3;           // Max 3 active per type
    uint256 private constant SKILL_DURATION = 30 days;                 // 30-day expiration
    
    // Skill type validation bounds
    uint8 private constant MIN_SKILL_TYPE = 1;                         // STAKE_BOOST_I
    uint8 private constant MAX_SKILL_TYPE = 17;                        // PRIVATE_AUCTIONS (17 total skills)
    uint8 private constant MAX_RARITY = 4;                             // LEGENDARY
    uint8 private constant MIN_LEVEL = 1;
    uint8 private constant MAX_LEVEL = 50;                             // Synchronized with GameifiedMarketplaceQuests
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    Counters.Counter private _skillCounter;
    
    // Core storage
    mapping(uint256 => IndividualSkill) public individualSkills;                              // skillId => IndividualSkill
    mapping(address => uint256[]) public userIndividualSkills;                                 // user => [skillIds]
    mapping(address => mapping(IStakingIntegration.SkillType => uint256[])) public userActiveSkills;  // user => skillType => [activeSkillIds]
    
    // Active count tracking (O(1) instead of O(n))
    mapping(address => mapping(IStakingIntegration.SkillType => uint8)) public userActiveSkillCount;
    
    // Contract addresses
    address public treasuryAddress;
    address public stakingContractAddress;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    error InsufficientStakingBalance(uint256 required, uint256 current);
    error InvalidPrice(uint256 expected, uint256 provided);
    error InvalidSkillType(uint8 skillType);
    error InvalidRarity(uint8 rarity);
    error InvalidLevel(uint256 level);
    error InvalidMetadata();
    error InvalidAddress();
    error SkillNotFound(uint256 skillId);
    error SkillAlreadyExpired(uint256 expiresAt);
    error SkillNotExpired(uint256 expiresAt);
    error SkillNotActive();
    error SkillIsActive();
    error CannotTransferActiveSkill();
    error NotSkillOwner();
    error MaxActiveSkillsReached(uint8 max);
    error SkillNotInList(uint256 skillId);
    error StakingNotificationFailed(address user, uint256 skillId);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS (Additional to IIndividualSkills)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    event TreasuryAddressUpdated(address indexed oldTreasury, address indexed newTreasury);
    event StakingContractUpdated(address indexed oldStaking, address indexed newStaking);
    event SkillCleanedUp(address indexed user, uint256 indexed skillId);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    constructor(address _treasuryAddress) {
        if (_treasuryAddress == address(0)) revert InvalidAddress();
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        
        treasuryAddress = _treasuryAddress;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MAIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @inheritdoc IIndividualSkills
     * @notice Implements CEI pattern and all security validations from audit
     * - Added skill type validation (1-17)
     * - Added rarity validation (0-4)
     * - Added level validation (1-10)
     * - CEI pattern: all state changes before external calls
     * - Reentrancy guard
     * - NO staking requirement for purchase (only for activation)
     */
    function purchaseIndividualSkill(
        IStakingIntegration.SkillType _skillType,
        IStakingIntegration.Rarity _rarity,
        uint256 _level,
        string calldata _metadata
    ) external payable whenNotPaused nonReentrant returns (uint256 skillId) {
        // ═══ CHECKS ═══
        
        // Validate skill type (1-17, excluding NONE, ROYALTY_BOOSTER, AIRDROP_MAGNET)
        if (uint8(_skillType) < MIN_SKILL_TYPE || uint8(_skillType) > MAX_SKILL_TYPE) {
            revert InvalidSkillType(uint8(_skillType));
        }
        
        // Validate rarity (0-4)
        if (uint8(_rarity) > MAX_RARITY) {
            revert InvalidRarity(uint8(_rarity));
        }
        
        // Validate level (1-50, synchronized with MAX_LEVEL)
        if (_level < MIN_LEVEL || _level > MAX_LEVEL) {
            revert InvalidLevel(_level);
        }
        
        // Validate metadata is not empty
        if (bytes(_metadata).length == 0) {
            revert InvalidMetadata();
        }
        
        // Calculate and validate price
        uint256 price = INDIVIDUAL_SKILL_BASE_PRICE + (uint256(_rarity) * RARITY_MULTIPLIER);
        if (msg.value < price) {
            revert InvalidPrice(price, msg.value);
        }
        
        // ═══ EFFECTS ═══
        
        // Create new skill ID
        skillId = _skillCounter.current();
        _skillCounter.increment();
        
        uint256 expiresAt = block.timestamp + SKILL_DURATION;
        
        // Store skill data
        IndividualSkill storage skill = individualSkills[skillId];
        skill.skillType = _skillType;
        skill.rarity = _rarity;
        skill.level = _level;
        skill.owner = msg.sender;
        skill.purchasedAt = block.timestamp;
        skill.expiresAt = expiresAt;
        skill.isActive = false;
        skill.metadata = _metadata;
        skill.createdAt = block.timestamp;
        
        // Track skill for user
        userIndividualSkills[msg.sender].push(skillId);
        
        // Emit event
        emit IndividualSkillPurchased(msg.sender, skillId, _skillType, _rarity, price);
        
        // ═══ INTERACTIONS ═══
        
        // Transfer payment to treasury (CEI pattern - external call last)
        (bool success, ) = payable(treasuryAddress).call{value: msg.value}("");
        if (!success) revert InvalidAddress();
        
        return skillId;
    }
    
    /**
     * @inheritdoc IIndividualSkills
     * @notice FIXES:
     * - Added staking requirement validation on activation (CRITICAL)
     * - Added max active skills check per type
     * - Error handling for staking notification
     */
    function activateIndividualSkill(uint256 _skillId) external whenNotPaused {
        IndividualSkill storage skill = individualSkills[_skillId];
        
        // Validate ownership
        if (skill.owner != msg.sender) revert NotSkillOwner();
        if (skill.owner == address(0)) revert SkillNotFound(_skillId);
        
        // Validate state
        if (skill.isActive) revert SkillIsActive();
        if (block.timestamp >= skill.expiresAt) revert SkillAlreadyExpired(skill.expiresAt);
        
        // ✅ CRITICAL FIX: Validate staking requirement on activation
        _validateStakingRequirement(msg.sender);
        
        // Check max active skills per type (3)
        if (userActiveSkillCount[msg.sender][skill.skillType] >= MAX_ACTIVE_SKILLS_PER_TYPE) {
            revert MaxActiveSkillsReached(uint8(MAX_ACTIVE_SKILLS_PER_TYPE));
        }
        
        // Update state
        skill.isActive = true;
        userActiveSkills[msg.sender][skill.skillType].push(_skillId);
        
        unchecked {
            userActiveSkillCount[msg.sender][skill.skillType]++;
        }
        
        // Notify staking contract
        _notifyStakingActivation(msg.sender, _skillId, skill.skillType, skill.rarity);
        
        emit IndividualSkillActivated(msg.sender, _skillId, skill.skillType);
    }
    
    /**
     * @inheritdoc IIndividualSkills
     * @notice FIXES:
     * - Added found validation to array removal (CRITICAL)
     * - Decrement active count
     */
    function deactivateIndividualSkill(uint256 _skillId) external whenNotPaused {
        IndividualSkill storage skill = individualSkills[_skillId];
        
        if (skill.owner != msg.sender) revert NotSkillOwner();
        if (!skill.isActive) revert SkillNotActive();
        
        skill.isActive = false;
        
        // ✅ CRITICAL FIX: Safe array removal with validation
        bool found = _removeFromArray(userActiveSkills[msg.sender][skill.skillType], _skillId);
        if (!found) revert SkillNotInList(_skillId);
        
        // Decrement active count
        if (userActiveSkillCount[msg.sender][skill.skillType] > 0) {
            unchecked {
                userActiveSkillCount[msg.sender][skill.skillType]--;
            }
        }
        
        // Notify staking contract
        _notifyStakingDeactivation(msg.sender, _skillId);
        
        emit IndividualSkillDeactivated(msg.sender, _skillId, skill.skillType);
    }
    
    /**
     * @inheritdoc IIndividualSkills
     * @notice FIXES:
     * - Added skill existence validation
     * - Safe array removal with found validation
     */
    function transferIndividualSkill(uint256 _skillId, address _recipient) external whenNotPaused {
        if (_recipient == address(0)) revert InvalidAddress();
        
        IndividualSkill storage skill = individualSkills[_skillId];
        
        // Validate skill exists
        if (skill.owner == address(0)) revert SkillNotFound(_skillId);
        if (skill.owner != msg.sender) revert NotSkillOwner();
        if (skill.isActive) revert CannotTransferActiveSkill();
        if (block.timestamp >= skill.expiresAt) revert SkillAlreadyExpired(skill.expiresAt);
        
        // ✅ CRITICAL FIX: Safe removal with validation
        bool found = _removeFromArray(userIndividualSkills[msg.sender], _skillId);
        if (!found) revert SkillNotInList(_skillId);
        
        // Transfer ownership
        skill.owner = _recipient;
        userIndividualSkills[_recipient].push(_skillId);
        
        emit IndividualSkillTransferred(msg.sender, _recipient, _skillId, skill.skillType);
    }
    
    /**
     * @inheritdoc IIndividualSkills
     * @notice FIXES:
     * - CEI pattern: state before external call
     * - Better error handling
     */
    function renewIndividualSkill(uint256 _skillId) external payable whenNotPaused nonReentrant {
        IndividualSkill storage skill = individualSkills[_skillId];
        
        if (skill.owner != msg.sender) revert NotSkillOwner();
        if (block.timestamp < skill.expiresAt) revert SkillNotExpired(skill.expiresAt);
        
        // Calculate renewal price: 50% of original
        uint256 originalPrice = INDIVIDUAL_SKILL_BASE_PRICE + (uint256(skill.rarity) * RARITY_MULTIPLIER);
        uint256 renewalPrice = originalPrice / 2;
        
        if (msg.value < renewalPrice) {
            revert InvalidPrice(renewalPrice, msg.value);
        }
        
        // ═══ EFFECTS ═══
        skill.expiresAt = block.timestamp + SKILL_DURATION;
        
        emit IndividualSkillRenewed(msg.sender, _skillId, skill.expiresAt);
        
        // ═══ INTERACTIONS ═══
        (bool success, ) = payable(treasuryAddress).call{value: msg.value}("");
        if (!success) revert InvalidAddress();
    }
    
    /**
     * @inheritdoc IIndividualSkills
     * @notice FIXES:
     * - Removes expired skill from ownership array (CRITICAL)
     * - Safe array removal
     */
    function claimExpiredIndividualSkill(uint256 _skillId) external {
        IndividualSkill storage skill = individualSkills[_skillId];
        
        if (skill.owner != msg.sender) revert NotSkillOwner();
        if (block.timestamp < skill.expiresAt) revert SkillNotExpired(skill.expiresAt);
        
        // Deactivate if still active
        if (skill.isActive) {
            skill.isActive = false;
            
            bool found = _removeFromArray(userActiveSkills[msg.sender][skill.skillType], _skillId);
            if (!found) revert SkillNotInList(_skillId);
            
            if (userActiveSkillCount[msg.sender][skill.skillType] > 0) {
                unchecked {
                    userActiveSkillCount[msg.sender][skill.skillType]--;
                }
            }
            
            _notifyStakingDeactivation(msg.sender, _skillId);
        }
        
        // ✅ CRITICAL FIX: Remove from ownership array to prevent state bloat
        bool ownershipRemoved = _removeFromArray(userIndividualSkills[msg.sender], _skillId);
        if (!ownershipRemoved) revert SkillNotInList(_skillId);
        
        emit IndividualSkillExpired(msg.sender, _skillId, skill.skillType);
        emit SkillCleanedUp(msg.sender, _skillId);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @inheritdoc IIndividualSkills
    function getIndividualSkill(uint256 _skillId) external view returns (IndividualSkill memory) {
        return individualSkills[_skillId];
    }
    
    /// @inheritdoc IIndividualSkills
    function getUserIndividualSkills(address _user) external view returns (uint256[] memory) {
        return userIndividualSkills[_user];
    }
    
    /// @inheritdoc IIndividualSkills
    function getUserActiveIndividualSkills(address _user, IStakingIntegration.SkillType _skillType) external view returns (uint256[] memory) {
        return userActiveSkills[_user][_skillType];
    }
    
    /// @inheritdoc IIndividualSkills
    function getIndividualSkillPrice(IStakingIntegration.Rarity _rarity) external pure returns (uint256) {
        return INDIVIDUAL_SKILL_BASE_PRICE + (uint256(_rarity) * RARITY_MULTIPLIER);
    }
    
    /// @inheritdoc IIndividualSkills
    function getUserIndividualSkillsDetailed(address _user) external view returns (IndividualSkill[] memory skills, bool[] memory isActive) {
        uint256[] memory skillIds = userIndividualSkills[_user];
        skills = new IndividualSkill[](skillIds.length);
        isActive = new bool[](skillIds.length);
        
        for (uint256 i = 0; i < skillIds.length; i++) {
            skills[i] = individualSkills[skillIds[i]];
            isActive[i] = block.timestamp < skills[i].expiresAt && skills[i].isActive;
        }
        
        return (skills, isActive);
    }
    
    /**
     * @dev Get filtered active skills for user (excludes expired)
     * @param _user Address of user
     * @return activeSkillIds Array of active (non-expired) skill IDs
     */
    function getActiveIndividualSkills(address _user) external view returns (uint256[] memory activeSkillIds) {
        uint256[] memory allSkills = userIndividualSkills[_user];
        uint256 activeCount = 0;
        
        // Count active
        for (uint256 i = 0; i < allSkills.length; i++) {
            if (block.timestamp < individualSkills[allSkills[i]].expiresAt) {
                activeCount++;
            }
        }
        
        // Build result
        activeSkillIds = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allSkills.length; i++) {
            if (block.timestamp < individualSkills[allSkills[i]].expiresAt) {
                activeSkillIds[index] = allSkills[i];
                index++;
            }
        }
        
        return activeSkillIds;
    }
    
    /**
     * @dev Get active skill count per type for user (O(1) lookup)
     * @param _user Address of user
     * @param _skillType Type of skill
     * @return count Number of active skills of this type
     */
    function getUserActiveSkillCountByType(address _user, IStakingIntegration.SkillType _skillType) external view returns (uint8 count) {
        return userActiveSkillCount[_user][_skillType];
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPER FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Validate user has minimum 250 POL in staking
     * @param _user Address to validate
     */
    function _validateStakingRequirement(address _user) internal view {
        if (stakingContractAddress == address(0)) {
            return; // Skip if staking not configured
        }
        
        (bool success, bytes memory data) = stakingContractAddress.staticcall(
            abi.encodeWithSignature("getTotalDeposit(address)", _user)
        );
        
        if (success && data.length >= 32) {
            uint256 totalDeposit = abi.decode(data, (uint256));
            if (totalDeposit < MIN_STAKING_REQUIREMENT) {
                revert InsufficientStakingBalance(MIN_STAKING_REQUIREMENT, totalDeposit);
            }
        }
    }
    
    /**
     * @dev Notify staking contract of skill activation
     * @param _user User address
     * @param _skillId Skill ID
     * @param _skillType Skill type
     * @param _rarity Skill rarity
     */
    function _notifyStakingActivation(
        address _user,
        uint256 _skillId,
        IStakingIntegration.SkillType _skillType,
        IStakingIntegration.Rarity _rarity
    ) internal {
        if (stakingContractAddress == address(0)) return;
        
        uint16 skillValue = uint16(5 + (uint256(_rarity) * 2));
        
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = stakingContractAddress.call(
            abi.encodeWithSignature(
                "notifySkillActivation(address,uint256,uint8,uint16)",
                _user,
                _skillId,
                uint8(_skillType),
                skillValue
            )
        );
        // Note: If staking notification fails, we continue without reverting
        if (!success) return;
    }
    
    /**
     * @dev Notify staking contract of skill deactivation
     * @param _user User address
     * @param _skillId Skill ID
     */
    function _notifyStakingDeactivation(address _user, uint256 _skillId) internal {
        if (stakingContractAddress == address(0)) return;
        
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = stakingContractAddress.call(
            abi.encodeWithSignature(
                "notifySkillDeactivation(address,uint256)",
                _user,
                _skillId
            )
        );
        // Note: If staking notification fails, we continue without reverting
        if (!success) return;
    }
    
    /**
     * @dev Remove value from array using swap-and-pop
     * @param _array Storage array to modify
     * @param _value Value to remove
     * @return found Whether value was found and removed
     */
    function _removeFromArray(uint256[] storage _array, uint256 _value) internal returns (bool found) {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] == _value) {
                _array[i] = _array[_array.length - 1];
                _array.pop();
                return true;
            }
        }
        return false;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Set staking contract address
     * @param _stakingAddress Address of staking contract
     */
    function setStakingContract(address _stakingAddress) external onlyRole(ADMIN_ROLE) {
        if (_stakingAddress == address(0)) revert InvalidAddress();
        address oldStaking = stakingContractAddress;
        stakingContractAddress = _stakingAddress;
        emit StakingContractUpdated(oldStaking, _stakingAddress);
    }
    
    /**
     * @dev Set treasury address
     * @param _treasuryAddress Address of treasury
     */
    function setTreasuryAddress(address _treasuryAddress) external onlyRole(ADMIN_ROLE) {
        if (_treasuryAddress == address(0)) revert InvalidAddress();
        address oldTreasury = treasuryAddress;
        treasuryAddress = _treasuryAddress;
        emit TreasuryAddressUpdated(oldTreasury, _treasuryAddress);
    }
    
    /**
     * @dev Pause contract
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Emergency withdraw (only if funds stuck)
     */
    function emergencyWithdraw() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(treasuryAddress).call{value: balance}("");
            if (!success) revert InvalidAddress();
        }
    }
    
    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}
}
