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
 * PRICING: Fixed per skill type + rarity (POL tokens)
 * - STAKING SKILLS (1-7): COMMON=50, UNCOMMON=80, RARE=100, EPIC=150, LEGENDARY=220
 * - ACTIVE SKILLS (8-17): +30% markup on STAKING prices
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
    uint256 private constant MAX_ACTIVE_SKILLS_PER_TYPE = 3;           // Max 3 active per type
    uint256 private constant SKILL_DURATION = 30 days;                 // 30-day expiration
    
    // Skill type validation bounds
    uint8 private constant MIN_SKILL_TYPE = 1;                         // STAKE_BOOST_I
    uint8 private constant MAX_SKILL_TYPE = 16;                        // PRIVATE_AUCTIONS (17 total skills: 1-16)
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
    
    // Skill pricing: skillType => rarity => price (in wei/POL)
    // Maps each skill + rarity combination to its price
    mapping(IStakingIntegration.SkillType => mapping(IStakingIntegration.Rarity => uint256)) public skillPrices;
    
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
    event SkillPricingUpdated(IStakingIntegration.SkillType indexed skillType, uint256 basePrice, uint256 rarityMultiplier);
    event SkillPurchaseProcessed(address indexed user, uint256 indexed skillId, IStakingIntegration.SkillType skillType, uint256 amount, string operation);
    event EmergencyWithdrawal(address indexed admin, uint256 amount, address indexed to);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    constructor(address _treasuryAddress) {
        if (_treasuryAddress == address(0)) revert InvalidAddress();
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        
        treasuryAddress = _treasuryAddress;
        
        // Initialize default pricing for all skills
        _initializeSkillPricing();
    }
    
    /**
     * @dev Initialize default pricing for all 17 skills
     * Skills 1-7: Staking skills (cheaper)
     * Skills 8-17: Active skills (30% markup)
     * 
     * STAKING PRICES (POL):
     * - COMMON: 50
     * - UNCOMMON: 80
     * - RARE: 100
     * - EPIC: 150
     * - LEGENDARY: 220
     * 
     * ACTIVE PRICES (POL) - 30% markup:
     * - COMMON: 65 (50*1.3)
     * - UNCOMMON: 104 (80*1.3)
     * - RARE: 130 (100*1.3)
     * - EPIC: 195 (150*1.3)
     * - LEGENDARY: 286 (220*1.3)
     */
    function _initializeSkillPricing() internal {
        // STAKING SKILLS (1-7): Base prices
        for (uint8 i = 1; i <= 7; i++) {
            IStakingIntegration.SkillType skillType = IStakingIntegration.SkillType(i);
            skillPrices[skillType][IStakingIntegration.Rarity.COMMON] = STAKING_COMMON_PRICE;
            skillPrices[skillType][IStakingIntegration.Rarity.UNCOMMON] = STAKING_UNCOMMON_PRICE;
            skillPrices[skillType][IStakingIntegration.Rarity.RARE] = STAKING_RARE_PRICE;
            skillPrices[skillType][IStakingIntegration.Rarity.EPIC] = STAKING_EPIC_PRICE;
            skillPrices[skillType][IStakingIntegration.Rarity.LEGENDARY] = STAKING_LEGENDARY_PRICE;
        }
        
        // ACTIVE SKILLS (8-16): 30% markup on staking prices
        for (uint8 i = 8; i <= 16; i++) {
            IStakingIntegration.SkillType skillType = IStakingIntegration.SkillType(i);
            skillPrices[skillType][IStakingIntegration.Rarity.COMMON] = ACTIVE_COMMON_PRICE;
            skillPrices[skillType][IStakingIntegration.Rarity.UNCOMMON] = ACTIVE_UNCOMMON_PRICE;
            skillPrices[skillType][IStakingIntegration.Rarity.RARE] = ACTIVE_RARE_PRICE;
            skillPrices[skillType][IStakingIntegration.Rarity.EPIC] = ACTIVE_EPIC_PRICE;
            skillPrices[skillType][IStakingIntegration.Rarity.LEGENDARY] = ACTIVE_LEGENDARY_PRICE;
        }
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
        
        // Calculate and validate price (uses dynamic pricing per skill type)
        uint256 price = _calculateSkillPrice(_skillType, _rarity);
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
        emit SkillPurchaseProcessed(msg.sender, skillId, _skillType, msg.value, "PURCHASE_INDIVIDUAL_SKILL");
        
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
        
        // Calculate renewal price: 50% of original (uses dynamic pricing)
        uint256 originalPrice = _calculateSkillPrice(skill.skillType, skill.rarity);
        uint256 renewalPrice = originalPrice / 2;
        
        if (msg.value < renewalPrice) {
            revert InvalidPrice(renewalPrice, msg.value);
        }
        
        // ═══ EFFECTS ═══
        skill.expiresAt = block.timestamp + SKILL_DURATION;
        
        emit IndividualSkillRenewed(msg.sender, _skillId, skill.expiresAt);
        emit SkillPurchaseProcessed(msg.sender, _skillId, skill.skillType, msg.value, "RENEW_INDIVIDUAL_SKILL");
        
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
    /// @notice Returns price for specific skill type and rarity
    function getIndividualSkillPrice(IStakingIntegration.Rarity _rarity) external view returns (uint256) {
        // Returns price for ACTIVE skills COMMON rarity for backward compatibility
        return skillPrices[IStakingIntegration.SkillType(8)][_rarity];
    }
    
    /**
     * @dev Get price for specific skill type and rarity
     * @param _skillType Type of skill (1-17)
     * @param _rarity Rarity level (0-4)
     * @return price Price in ETH (wei)
     */
    function getSkillPrice(IStakingIntegration.SkillType _skillType, IStakingIntegration.Rarity _rarity) external view returns (uint256) {
        return _calculateSkillPrice(_skillType, _rarity);
    }
    
    /**
     * @dev Get all prices for a skill across all rarities
     * @param _skillType Type of skill (1-17)
     * @return prices Array of prices [COMMON, UNCOMMON, RARE, EPIC, LEGENDARY]
     */
    function getSkillPricesAllRarities(IStakingIntegration.SkillType _skillType) external view returns (uint256[5] memory prices) {
        for (uint8 i = 0; i < 5; i++) {
            IStakingIntegration.Rarity rarity = IStakingIntegration.Rarity(i);
            prices[i] = _calculateSkillPrice(_skillType, rarity);
        }
        return prices;
    }
    
    /**
     * @dev Get pricing info for all skills
     * @return skillTypes Array of all skill types
     * @return categories Category of each skill (0=Staking, 1=Active)
     * @return prices 2D array of prices [skillIndex][rarityIndex]
     */
    function getAllSkillsPricing() external view returns (
        IStakingIntegration.SkillType[] memory skillTypes,
        uint8[] memory categories,
        uint256[][] memory prices
    ) {
        skillTypes = new IStakingIntegration.SkillType[](16);
        categories = new uint8[](16);
        prices = new uint256[][](16);
        
        for (uint8 i = 1; i <= 16; i++) {
            IStakingIntegration.SkillType skillType = IStakingIntegration.SkillType(i);
            skillTypes[i-1] = skillType;
            categories[i-1] = (i <= 7) ? 0 : 1; // 0=Staking, 1=Active
            
            // Get prices for all rarities
            prices[i-1] = new uint256[](5);
            for (uint8 j = 0; j < 5; j++) {
                IStakingIntegration.Rarity rarity = IStakingIntegration.Rarity(j);
                prices[i-1][j] = skillPrices[skillType][rarity];
            }
        }
        
        return (skillTypes, categories, prices);
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
    // NEW VIEW FUNCTIONS - FILTERED SKILL QUERIES FOR FRONTEND
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @dev Get ALL user's individual skills grouped by category (STAKING vs ACTIVE)
     * @param _user Address of user
     * @return stakingSkills Skills that affect staking rewards (types 1-7)
     * @return activeSkills Skills for platform features (types 8-16)
     * @notice This is the main frontend function to fetch all purchases
     */
    function getUserSkillsByCategory(address _user) external view returns (
        IndividualSkill[] memory stakingSkills,
        IndividualSkill[] memory activeSkills
    ) {
        uint256[] memory allSkillIds = userIndividualSkills[_user];
        
        // First pass: count skills in each category
        uint256 stakingCount = 0;
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < allSkillIds.length; i++) {
            IndividualSkill memory skill = individualSkills[allSkillIds[i]];
            uint8 skillTypeValue = uint8(skill.skillType);
            
            if (skillTypeValue >= 1 && skillTypeValue <= 7) {
                stakingCount++;
            } else if (skillTypeValue >= 8 && skillTypeValue <= 16) {
                activeCount++;
            }
        }
        
        // Initialize arrays with correct sizes
        stakingSkills = new IndividualSkill[](stakingCount);
        activeSkills = new IndividualSkill[](activeCount);
        
        // Second pass: fill arrays
        uint256 stakingIndex = 0;
        uint256 activeIndex = 0;
        
        for (uint256 i = 0; i < allSkillIds.length; i++) {
            IndividualSkill memory skill = individualSkills[allSkillIds[i]];
            uint8 skillTypeValue = uint8(skill.skillType);
            
            if (skillTypeValue >= 1 && skillTypeValue <= 7) {
                stakingSkills[stakingIndex] = skill;
                stakingIndex++;
            } else if (skillTypeValue >= 8 && skillTypeValue <= 16) {
                activeSkills[activeIndex] = skill;
                activeIndex++;
            }
        }
        
        return (stakingSkills, activeSkills);
    }

    /**
     * @dev Get ONLY staking skills (types 1-7) for user
     * @param _user Address of user
     * @return skills Array of staking skills with activation status
     */
    function getUserStakingSkills(address _user) external view returns (
        IndividualSkill[] memory skills,
        bool[] memory isActive,
        bool[] memory isExpired
    ) {
        uint256[] memory allSkillIds = userIndividualSkills[_user];
        
        // Count staking skills
        uint256 stakingCount = 0;
        for (uint256 i = 0; i < allSkillIds.length; i++) {
            uint8 skillTypeValue = uint8(individualSkills[allSkillIds[i]].skillType);
            if (skillTypeValue >= 1 && skillTypeValue <= 7) {
                stakingCount++;
            }
        }
        
        // Initialize arrays
        skills = new IndividualSkill[](stakingCount);
        isActive = new bool[](stakingCount);
        isExpired = new bool[](stakingCount);
        
        // Fill arrays
        uint256 index = 0;
        for (uint256 i = 0; i < allSkillIds.length; i++) {
            uint256 skillId = allSkillIds[i];
            IndividualSkill memory skill = individualSkills[skillId];
            uint8 skillTypeValue = uint8(skill.skillType);
            
            if (skillTypeValue >= 1 && skillTypeValue <= 7) {
                skills[index] = skill;
                isActive[index] = skill.isActive && block.timestamp < skill.expiresAt;
                isExpired[index] = block.timestamp >= skill.expiresAt;
                index++;
            }
        }
        
        return (skills, isActive, isExpired);
    }

    /**
     * @dev Get ONLY active/platform skills (types 8-16) for user
     * @param _user Address of user
     * @return skills Array of active skills with activation status
     */
    function getUserPlatformSkills(address _user) external view returns (
        IndividualSkill[] memory skills,
        bool[] memory isActive,
        bool[] memory isExpired
    ) {
        uint256[] memory allSkillIds = userIndividualSkills[_user];
        
        // Count platform skills
        uint256 platformCount = 0;
        for (uint256 i = 0; i < allSkillIds.length; i++) {
            uint8 skillTypeValue = uint8(individualSkills[allSkillIds[i]].skillType);
            if (skillTypeValue >= 8 && skillTypeValue <= 16) {
                platformCount++;
            }
        }
        
        // Initialize arrays
        skills = new IndividualSkill[](platformCount);
        isActive = new bool[](platformCount);
        isExpired = new bool[](platformCount);
        
        // Fill arrays
        uint256 index = 0;
        for (uint256 i = 0; i < allSkillIds.length; i++) {
            uint256 skillId = allSkillIds[i];
            IndividualSkill memory skill = individualSkills[skillId];
            uint8 skillTypeValue = uint8(skill.skillType);
            
            if (skillTypeValue >= 8 && skillTypeValue <= 16) {
                skills[index] = skill;
                isActive[index] = skill.isActive && block.timestamp < skill.expiresAt;
                isExpired[index] = block.timestamp >= skill.expiresAt;
                index++;
            }
        }
        
        return (skills, isActive, isExpired);
    }

    /**
     * @dev Get comprehensive skill info with expiration and activation details
     * @param _user Address of user
     * @return allSkills All skills with detailed info
     * @notice Includes expiration status, activation status, and time remaining
     */
    function getUserSkillsComprehensive(address _user) external view returns (
        IndividualSkill[] memory allSkills,
        bool[] memory isActive,
        bool[] memory isExpired,
        uint256[] memory expiresIn,
        string[] memory categoryNames
    ) {
        uint256[] memory skillIds = userIndividualSkills[_user];
        uint256 count = skillIds.length;
        
        allSkills = new IndividualSkill[](count);
        isActive = new bool[](count);
        isExpired = new bool[](count);
        expiresIn = new uint256[](count);
        categoryNames = new string[](count);
        
        for (uint256 i = 0; i < count; i++) {
            uint256 skillId = skillIds[i];
            IndividualSkill memory skill = individualSkills[skillId];
            uint8 skillTypeValue = uint8(skill.skillType);
            
            allSkills[i] = skill;
            isActive[i] = skill.isActive && block.timestamp < skill.expiresAt;
            isExpired[i] = block.timestamp >= skill.expiresAt;
            
            // Time remaining in seconds
            if (block.timestamp < skill.expiresAt) {
                expiresIn[i] = skill.expiresAt - block.timestamp;
            } else {
                expiresIn[i] = 0;
            }
            
            // Category name for display
            if (skillTypeValue >= 1 && skillTypeValue <= 7) {
                categoryNames[i] = "STAKING";
            } else if (skillTypeValue >= 8 && skillTypeValue <= 16) {
                categoryNames[i] = "PLATFORM";
            } else {
                categoryNames[i] = "UNKNOWN";
            }
        }
        
        return (allSkills, isActive, isExpired, expiresIn, categoryNames);
    }

    /**
     * @dev Get skill stats summary for user
     * @param _user Address of user
     * @return totalSkills Total number of skills purchased
     * @return totalStakingSkills Count of staking skills (types 1-7)
     * @return totalPlatformSkills Count of platform skills (types 8-16)
     * @return activeCount Total active (not expired) skills
     * @return expiredCount Total expired skills
     */
    function getUserSkillStats(address _user) external view returns (
        uint256 totalSkills,
        uint256 totalStakingSkills,
        uint256 totalPlatformSkills,
        uint256 activeCount,
        uint256 expiredCount
    ) {
        uint256[] memory skillIds = userIndividualSkills[_user];
        totalSkills = skillIds.length;
        
        for (uint256 i = 0; i < totalSkills; i++) {
            IndividualSkill memory skill = individualSkills[skillIds[i]];
            uint8 skillTypeValue = uint8(skill.skillType);
            
            if (skillTypeValue >= 1 && skillTypeValue <= 7) {
                totalStakingSkills++;
            } else if (skillTypeValue >= 8 && skillTypeValue <= 16) {
                totalPlatformSkills++;
            }
            
            if (block.timestamp < skill.expiresAt) {
                activeCount++;
            } else {
                expiredCount++;
            }
        }
        
        return (totalSkills, totalStakingSkills, totalPlatformSkills, activeCount, expiredCount);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPER FUNCTIONS - PRICING
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Calculate skill price based on type and rarity (lookup from mapping)
     * @param _skillType Type of skill (1-17)
     * @param _rarity Rarity level (0-4)
     * @return price Price in POL (wei)
     */
    function _calculateSkillPrice(IStakingIntegration.SkillType _skillType, IStakingIntegration.Rarity _rarity) internal view returns (uint256) {
        // Direct lookup: O(1) gas efficient
        return skillPrices[_skillType][_rarity];
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPER FUNCTIONS - VALIDATION
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
     * @dev Update pricing for a specific skill type and rarity
     * @param _skillType Type of skill (1-17)
     * @param _rarity Rarity level (0-4)
     * @param _price New price in POL (wei)
     */
    function updateSkillPrice(
        IStakingIntegration.SkillType _skillType,
        IStakingIntegration.Rarity _rarity,
        uint256 _price
    ) external onlyRole(ADMIN_ROLE) {
        if (uint8(_skillType) < MIN_SKILL_TYPE || uint8(_skillType) > MAX_SKILL_TYPE) {
            revert InvalidSkillType(uint8(_skillType));
        }
        if (uint8(_rarity) > MAX_RARITY) {
            revert InvalidRarity(uint8(_rarity));
        }
        
        skillPrices[_skillType][_rarity] = _price;
        emit SkillPricingUpdated(_skillType, _price, uint8(_rarity));
    }
    
    /**
     * @dev Reset all prices to default values
     */
    function resetSkillPricingToDefaults() external onlyRole(ADMIN_ROLE) {
        _initializeSkillPricing();
    }
    
    /**
     * @dev Update all staking skills pricing
     * @param _commonPrice Price for COMMON rarity
     * @param _uncommonPrice Price for UNCOMMON rarity
     * @param _rarePrice Price for RARE rarity
     * @param _epicPrice Price for EPIC rarity
     * @param _legendaryPrice Price for LEGENDARY rarity
     */
    function updateStakingSkillsPricing(
        uint256 _commonPrice,
        uint256 _uncommonPrice,
        uint256 _rarePrice,
        uint256 _epicPrice,
        uint256 _legendaryPrice
    ) external onlyRole(ADMIN_ROLE) {
        for (uint8 i = 1; i <= 7; i++) {
            IStakingIntegration.SkillType skillType = IStakingIntegration.SkillType(i);
            skillPrices[skillType][IStakingIntegration.Rarity.COMMON] = _commonPrice;
            skillPrices[skillType][IStakingIntegration.Rarity.UNCOMMON] = _uncommonPrice;
            skillPrices[skillType][IStakingIntegration.Rarity.RARE] = _rarePrice;
            skillPrices[skillType][IStakingIntegration.Rarity.EPIC] = _epicPrice;
            skillPrices[skillType][IStakingIntegration.Rarity.LEGENDARY] = _legendaryPrice;
        }
    }
    
    /**
     * @dev Update all active skills pricing
     * @param _commonPrice Price for COMMON rarity
     * @param _uncommonPrice Price for UNCOMMON rarity
     * @param _rarePrice Price for RARE rarity
     * @param _epicPrice Price for EPIC rarity
     * @param _legendaryPrice Price for LEGENDARY rarity
     */
    function updateActiveSkillsPricing(
        uint256 _commonPrice,
        uint256 _uncommonPrice,
        uint256 _rarePrice,
        uint256 _epicPrice,
        uint256 _legendaryPrice
    ) external onlyRole(ADMIN_ROLE) {
        for (uint8 i = 8; i <= 16; i++) {
            IStakingIntegration.SkillType skillType = IStakingIntegration.SkillType(i);
            skillPrices[skillType][IStakingIntegration.Rarity.COMMON] = _commonPrice;
            skillPrices[skillType][IStakingIntegration.Rarity.UNCOMMON] = _uncommonPrice;
            skillPrices[skillType][IStakingIntegration.Rarity.RARE] = _rarePrice;
            skillPrices[skillType][IStakingIntegration.Rarity.EPIC] = _epicPrice;
            skillPrices[skillType][IStakingIntegration.Rarity.LEGENDARY] = _legendaryPrice;
        }
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
     * @dev Emergency withdraw specific amount (only if funds stuck)
     */
    function emergencyWithdraw(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        if (_amount == 0) revert InvalidPrice(_amount, 0);
        if (_amount > address(this).balance) revert InvalidPrice(_amount, address(this).balance);
        if (treasuryAddress == address(0)) revert InvalidAddress();
        
        (bool success, ) = payable(treasuryAddress).call{value: _amount}("");
        if (!success) revert InvalidAddress();
        
        emit EmergencyWithdrawal(msg.sender, _amount, treasuryAddress);
    }
    
    /**
     * @dev Emergency withdraw all funds (only if funds stuck)
     */
    function emergencyWithdrawAll() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance == 0) revert InvalidPrice(balance, 0);
        if (treasuryAddress == address(0)) revert InvalidAddress();
        
        (bool success, ) = payable(treasuryAddress).call{value: balance}("");
        if (!success) revert InvalidAddress();
        
        emit EmergencyWithdrawal(msg.sender, balance, treasuryAddress);
    }
    
    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}
}
