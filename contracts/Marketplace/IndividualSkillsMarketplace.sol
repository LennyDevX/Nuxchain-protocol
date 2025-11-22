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
 * PRICING & IMPACT SYSTEM:
 * - PROFESSIONAL DYNAMIC PRICING: Price varies by Skill Type × Rarity × Level
 * - SKILL LEVELS determine impact magnitude (Level 1 = weak, Level 3 = strong for 3-level skills)
 * - RARITY MULTIPLIERS: Common (1.0x) to Legendary (5.0x) impact multiplier
 * - Effect values change based on both rarity and level combination
 * 
 * STAKING SKILLS (1-7):
 * - STAKE_BOOST_I/II/III: 3 levels each with different APY impact
 * - AUTO_COMPOUND, LOCK_REDUCER, FEE_REDUCER_I/II: Single level skills
 * - Base APY: +5%/+10%/+20% (×rarity multiplier)
 * 
 * ACTIVE SKILLS (8-16):
 * - Platform features with configurable effect values
 * - Variable impact based on rarity tier
 * 
 * PRICING CALCULATION: base_price × level_multiplier × rarity_multiplier
 * 
 * @custom:security-contact security@nuvo.com
 * @custom:version 2.0.0 - Professional Dynamic Pricing System
 */
contract IndividualSkillsMarketplace is AccessControl, Pausable, ReentrancyGuard, IIndividualSkills {
    using Counters for Counters.Counter;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // PRICING CONSTANTS - PROFESSIONAL DYNAMIC SYSTEM
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    uint256 private constant MIN_STAKING_REQUIREMENT = 250 ether;      // 250 POL minimum
    uint256 private constant SKILL_DURATION = 30 days;                 // 30-day expiration
    
    // Base prices (per rarity) - Used as foundation for all calculations
    // Price = basePrice × level_multiplier × rarity_multiplier
    uint256 private constant BASE_PRICE_COMMON = 50 ether;
    uint256 private constant BASE_PRICE_UNCOMMON = 80 ether;
    uint256 private constant BASE_PRICE_RARE = 100 ether;
    uint256 private constant BASE_PRICE_EPIC = 150 ether;
    uint256 private constant BASE_PRICE_LEGENDARY = 220 ether;
    
    // Rarity multipliers (basis points: 10000 = 1.0x)
    // Applied to effect values (APY boost, fee discount, etc.)
    // COMMON: 1.0x, UNCOMMON: 1.5x, RARE: 2.0x, EPIC: 3.0x, LEGENDARY: 5.0x
    uint16 private constant RARITY_MULTIPLIER_COMMON = 10000;      // 1.0x
    uint16 private constant RARITY_MULTIPLIER_UNCOMMON = 15000;    // 1.5x
    uint16 private constant RARITY_MULTIPLIER_RARE = 20000;        // 2.0x
    uint16 private constant RARITY_MULTIPLIER_EPIC = 30000;        // 3.0x
    uint16 private constant RARITY_MULTIPLIER_LEGENDARY = 50000;   // 5.0x
    
    // Level multipliers for multi-level skills (basis points)
    // Level 1 (weak): 1.0x, Level 2 (medium): 1.5x, Level 3 (strong): 2.5x
    uint16 private constant LEVEL_MULTIPLIER_1 = 10000;            // 1.0x (Level 1)
    uint16 private constant LEVEL_MULTIPLIER_2 = 15000;            // 1.5x (Level 2)
    uint16 private constant LEVEL_MULTIPLIER_3 = 25000;            // 2.5x (Level 3)
    
    // Skill type validation bounds
    uint8 private constant MIN_SKILL_TYPE = 1;                         // STAKE_BOOST_I
    uint8 private constant MAX_SKILL_TYPE = 16;                        // PRIVATE_AUCTIONS (17 total skills: 1-16)
    uint8 private constant MAX_RARITY = 4;                             // LEGENDARY
    uint8 private constant MIN_LEVEL = 1;
    uint8 private constant MAX_LEVEL = 50;                             // Synchronized with GameifiedMarketplaceQuests
    
    uint256 private constant MAX_ACTIVE_SKILLS_TOTAL = 5;              // Max 5 active skills total (synchronized with system)
    uint256 private constant BASIS_POINTS = 10000;                     // For percentage calculations
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    Counters.Counter private _skillCounter;
    
    // Core storage
    mapping(uint256 => IndividualSkill) public individualSkills;                              // skillId => IndividualSkill
    mapping(address => uint256[]) public userIndividualSkills;                                 // user => [skillIds]
    mapping(address => uint256[]) public userActiveSkills;                                       // user => [activeSkillIds]
    
    // Active count tracking (O(1) instead of O(n)) - Global active count
    mapping(address => uint8) public userActiveSkillCount;
    
    // Contract addresses
    address public treasuryAddress;
    address public stakingContractAddress;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // DYNAMIC PRICING SYSTEM - Professional Multi-Dimensional Pricing
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    // Base price per rarity (can be updated by admin)
    // rarityIndex (0-4) => price in wei
    mapping(uint8 => uint256) public basePricePerRarity;
    
    // Rarity effect multipliers (basis points, 10000 = 1.0x)
    // Skill impact multiplier based on rarity (APY, fee discount, etc.)
    mapping(uint8 => uint16) public rarityEffectMultiplier;
    
    // Level multipliers for multi-level skills (basis points)
    // levelIndex (1-3) => multiplier (e.g., 10000, 15000, 25000)
    mapping(uint8 => uint16) public levelMultiplier;
    
    // Skill effect values: skillType => rarity => baseEffectValue (in basis points)
    // e.g., STAKE_BOOST_I COMMON = 500 (5% APY), LEGENDARY = 2500 (25% APY)
    mapping(IStakingIntegration.SkillType => mapping(IStakingIntegration.Rarity => uint16)) public skillEffectValues;
    
    // Number of levels for each skill type (1 = single-level, 3 = has 3 levels)
    // For STAKE_BOOST_I/II/III: each has 3 variants (represented as separate skills with levels)
    // This tracks how many "upgrade levels" exist for skills that can be upgraded
    mapping(IStakingIntegration.SkillType => uint8) public skillLevelCount;
    
    // Old pricing mapping (kept for backward compatibility - will be overridden by new system)
    mapping(IStakingIntegration.SkillType => mapping(IStakingIntegration.Rarity => uint256)) public skillPrices;
    
    // Dashboard statistics tracking
    uint256 public totalSkillsSold;
    uint256 public totalRevenue;
    mapping(IStakingIntegration.SkillType => uint256) public skillsSoldByType;
    mapping(IStakingIntegration.Rarity => uint256) public skillsSoldByRarity;
    mapping(IStakingIntegration.SkillType => uint256) public revenueBySkillType;
    mapping(IStakingIntegration.Rarity => uint256) public revenueByRarity;
    mapping(address => uint256) public userTotalSpent;
    
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
    event SkillEffectValueUpdated(IStakingIntegration.SkillType indexed skillType, IStakingIntegration.Rarity indexed rarity, uint16 newEffectValue);
    event SkillLevelMultiplierUpdated(uint8 indexed level, uint16 newMultiplier);
    event RarityEffectMultiplierUpdated(IStakingIntegration.Rarity indexed rarity, uint16 newMultiplier);
    event BasePriceUpdated(IStakingIntegration.Rarity indexed rarity, uint256 newPrice);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    constructor(address _treasuryAddress) {
        if (_treasuryAddress == address(0)) revert InvalidAddress();
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        
        treasuryAddress = _treasuryAddress;
        
        // Initialize professional dynamic pricing system
        _initializeSkillPricing();
        _initializeSkillEffects();
    }
    
    /**
     * @dev Initialize base prices and rarity multipliers
     * Professional pricing: COMMON → LEGENDARY have exponential cost progression
     */
    function _initializeSkillPricing() internal {
        // Set base prices per rarity
        basePricePerRarity[0] = BASE_PRICE_COMMON;       // COMMON: 50 POL
        basePricePerRarity[1] = BASE_PRICE_UNCOMMON;     // UNCOMMON: 80 POL
        basePricePerRarity[2] = BASE_PRICE_RARE;         // RARE: 100 POL
        basePricePerRarity[3] = BASE_PRICE_EPIC;         // EPIC: 150 POL
        basePricePerRarity[4] = BASE_PRICE_LEGENDARY;    // LEGENDARY: 220 POL
        
        // Set rarity effect multipliers (impact on APY, fees, etc.)
        rarityEffectMultiplier[0] = RARITY_MULTIPLIER_COMMON;      // 1.0x
        rarityEffectMultiplier[1] = RARITY_MULTIPLIER_UNCOMMON;    // 1.5x
        rarityEffectMultiplier[2] = RARITY_MULTIPLIER_RARE;        // 2.0x
        rarityEffectMultiplier[3] = RARITY_MULTIPLIER_EPIC;        // 3.0x
        rarityEffectMultiplier[4] = RARITY_MULTIPLIER_LEGENDARY;   // 5.0x
        
        // Set level multipliers for multi-level skills
        levelMultiplier[1] = LEVEL_MULTIPLIER_1;  // Level 1: 1.0x
        levelMultiplier[2] = LEVEL_MULTIPLIER_2;  // Level 2: 1.5x
        levelMultiplier[3] = LEVEL_MULTIPLIER_3;  // Level 3: 2.5x
    }
    
    /**
     * @dev Initialize skill effect values (APY boosts, fee discounts, etc.)
     * Each skill type × rarity combination has a different effect magnitude
     * 
     * STAKING SKILLS (1-7): Base effect values in basis points (500 = 5%)
     * - STAKE_BOOST_I: +5% APY base (varies by rarity: 5%-25%)
     * - STAKE_BOOST_II: +10% APY base (varies by rarity: 10%-50%)
     * - STAKE_BOOST_III: +20% APY base (varies by rarity: 20%-100%)
     * - AUTO_COMPOUND: Automatic compounding trigger
     * - LOCK_REDUCER: Reduce lock time
     * - FEE_REDUCER_I: -10% fee base
     * - FEE_REDUCER_II: -25% fee base
     * 
     * ACTIVE SKILLS (8-16): Platform features with various impacts
     */
    function _initializeSkillEffects() internal {
        // ═══ STAKING SKILLS (1-7) ═══
        
        // STAKE_BOOST_I (Skill #1): Base +5% APY (500 bps)
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_I][IStakingIntegration.Rarity.COMMON] = 500;      // +5% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_I][IStakingIntegration.Rarity.UNCOMMON] = 700;    // +7% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_I][IStakingIntegration.Rarity.RARE] = 900;        // +9% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_I][IStakingIntegration.Rarity.EPIC] = 1200;       // +12% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_I][IStakingIntegration.Rarity.LEGENDARY] = 1600;  // +16% APY (less aggressive)
        
        // STAKE_BOOST_II (Skill #2): Base +10% APY (1000 bps) - COSTS 50% MORE
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_II][IStakingIntegration.Rarity.COMMON] = 1000;    // +10% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_II][IStakingIntegration.Rarity.UNCOMMON] = 1300;  // +13% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_II][IStakingIntegration.Rarity.RARE] = 1600;      // +16% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_II][IStakingIntegration.Rarity.EPIC] = 2100;      // +21% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_II][IStakingIntegration.Rarity.LEGENDARY] = 2800; // +28% APY (was 50%, now 28%)
        
        // STAKE_BOOST_III (Skill #3): Base +15% APY (1500 bps) - COSTS 120% MORE THAN I
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_III][IStakingIntegration.Rarity.COMMON] = 1500;    // +15% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_III][IStakingIntegration.Rarity.UNCOMMON] = 1900;  // +19% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_III][IStakingIntegration.Rarity.RARE] = 2300;      // +23% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_III][IStakingIntegration.Rarity.EPIC] = 3000;      // +30% APY
        skillEffectValues[IStakingIntegration.SkillType.STAKE_BOOST_III][IStakingIntegration.Rarity.LEGENDARY] = 3800; // +38% APY (was 90%, now 38%)
        
        // AUTO_COMPOUND (Skill #4): Automatic compounding
        skillEffectValues[IStakingIntegration.SkillType.AUTO_COMPOUND][IStakingIntegration.Rarity.COMMON] = 1000;      // Base 1x
        skillEffectValues[IStakingIntegration.SkillType.AUTO_COMPOUND][IStakingIntegration.Rarity.UNCOMMON] = 1300;    // 1.3x
        skillEffectValues[IStakingIntegration.SkillType.AUTO_COMPOUND][IStakingIntegration.Rarity.RARE] = 1600;        // 1.6x
        skillEffectValues[IStakingIntegration.SkillType.AUTO_COMPOUND][IStakingIntegration.Rarity.EPIC] = 2100;        // 2.1x
        skillEffectValues[IStakingIntegration.SkillType.AUTO_COMPOUND][IStakingIntegration.Rarity.LEGENDARY] = 2600;   // 2.6x (was 4.0x)
        
        // LOCK_REDUCER (Skill #5): Reduce lock time
        skillEffectValues[IStakingIntegration.SkillType.LOCK_REDUCER][IStakingIntegration.Rarity.COMMON] = 1500;       // -15% lock time
        skillEffectValues[IStakingIntegration.SkillType.LOCK_REDUCER][IStakingIntegration.Rarity.UNCOMMON] = 2000;     // -20% lock time
        skillEffectValues[IStakingIntegration.SkillType.LOCK_REDUCER][IStakingIntegration.Rarity.RARE] = 2500;         // -25% lock time
        skillEffectValues[IStakingIntegration.SkillType.LOCK_REDUCER][IStakingIntegration.Rarity.EPIC] = 3500;         // -35% lock time
        skillEffectValues[IStakingIntegration.SkillType.LOCK_REDUCER][IStakingIntegration.Rarity.LEGENDARY] = 4500;   // -45% lock time (was -90%)
        
        // FEE_REDUCER_I (Skill #6): -10% platform fees base
        skillEffectValues[IStakingIntegration.SkillType.FEE_REDUCER_I][IStakingIntegration.Rarity.COMMON] = 1000;      // -10% fees
        skillEffectValues[IStakingIntegration.SkillType.FEE_REDUCER_I][IStakingIntegration.Rarity.UNCOMMON] = 1300;    // -13% fees
        skillEffectValues[IStakingIntegration.SkillType.FEE_REDUCER_I][IStakingIntegration.Rarity.RARE] = 1600;        // -16% fees
        skillEffectValues[IStakingIntegration.SkillType.FEE_REDUCER_I][IStakingIntegration.Rarity.EPIC] = 2200;        // -22% fees
        skillEffectValues[IStakingIntegration.SkillType.FEE_REDUCER_I][IStakingIntegration.Rarity.LEGENDARY] = 2800;   // -28% fees (was -50%)
        
        // FEE_REDUCER_II (Skill #7): -20% platform fees base - COSTS 43% MORE THAN I
        skillEffectValues[IStakingIntegration.SkillType.FEE_REDUCER_II][IStakingIntegration.Rarity.COMMON] = 1800;     // -18% fees
        skillEffectValues[IStakingIntegration.SkillType.FEE_REDUCER_II][IStakingIntegration.Rarity.UNCOMMON] = 2300;   // -23% fees
        skillEffectValues[IStakingIntegration.SkillType.FEE_REDUCER_II][IStakingIntegration.Rarity.RARE] = 2800;       // -28% fees
        skillEffectValues[IStakingIntegration.SkillType.FEE_REDUCER_II][IStakingIntegration.Rarity.EPIC] = 3700;       // -37% fees
        skillEffectValues[IStakingIntegration.SkillType.FEE_REDUCER_II][IStakingIntegration.Rarity.LEGENDARY] = 4500; // -45% fees (was -90%)
        
        // ═══ ACTIVE SKILLS (8-16) ═══
        
        // PRIORITY_LISTING (Skill #8)
        skillEffectValues[IStakingIntegration.SkillType.PRIORITY_LISTING][IStakingIntegration.Rarity.COMMON] = 1000;
        skillEffectValues[IStakingIntegration.SkillType.PRIORITY_LISTING][IStakingIntegration.Rarity.UNCOMMON] = 1500;
        skillEffectValues[IStakingIntegration.SkillType.PRIORITY_LISTING][IStakingIntegration.Rarity.RARE] = 2000;
        skillEffectValues[IStakingIntegration.SkillType.PRIORITY_LISTING][IStakingIntegration.Rarity.EPIC] = 3000;
        skillEffectValues[IStakingIntegration.SkillType.PRIORITY_LISTING][IStakingIntegration.Rarity.LEGENDARY] = 5000;
        
        // BATCH_MINTER (Skill #9)
        skillEffectValues[IStakingIntegration.SkillType.BATCH_MINTER][IStakingIntegration.Rarity.COMMON] = 1000;
        skillEffectValues[IStakingIntegration.SkillType.BATCH_MINTER][IStakingIntegration.Rarity.UNCOMMON] = 1500;
        skillEffectValues[IStakingIntegration.SkillType.BATCH_MINTER][IStakingIntegration.Rarity.RARE] = 2000;
        skillEffectValues[IStakingIntegration.SkillType.BATCH_MINTER][IStakingIntegration.Rarity.EPIC] = 3000;
        skillEffectValues[IStakingIntegration.SkillType.BATCH_MINTER][IStakingIntegration.Rarity.LEGENDARY] = 5000;
        
        // VERIFIED_CREATOR (Skill #10)
        skillEffectValues[IStakingIntegration.SkillType.VERIFIED_CREATOR][IStakingIntegration.Rarity.COMMON] = 1000;
        skillEffectValues[IStakingIntegration.SkillType.VERIFIED_CREATOR][IStakingIntegration.Rarity.UNCOMMON] = 1500;
        skillEffectValues[IStakingIntegration.SkillType.VERIFIED_CREATOR][IStakingIntegration.Rarity.RARE] = 2000;
        skillEffectValues[IStakingIntegration.SkillType.VERIFIED_CREATOR][IStakingIntegration.Rarity.EPIC] = 3000;
        skillEffectValues[IStakingIntegration.SkillType.VERIFIED_CREATOR][IStakingIntegration.Rarity.LEGENDARY] = 5000;
        
        // INFLUENCER (Skill #11) - Less aggressive legendary
        skillEffectValues[IStakingIntegration.SkillType.INFLUENCER][IStakingIntegration.Rarity.COMMON] = 10000;  // 2x weight
        skillEffectValues[IStakingIntegration.SkillType.INFLUENCER][IStakingIntegration.Rarity.UNCOMMON] = 12000; // 2.4x weight
        skillEffectValues[IStakingIntegration.SkillType.INFLUENCER][IStakingIntegration.Rarity.RARE] = 14000;     // 2.8x weight
        skillEffectValues[IStakingIntegration.SkillType.INFLUENCER][IStakingIntegration.Rarity.EPIC] = 18000;     // 3.6x weight
        skillEffectValues[IStakingIntegration.SkillType.INFLUENCER][IStakingIntegration.Rarity.LEGENDARY] = 24000; // 4.8x weight (was 10x)
        
        // CURATOR (Skill #12)
        skillEffectValues[IStakingIntegration.SkillType.CURATOR][IStakingIntegration.Rarity.COMMON] = 1000;
        skillEffectValues[IStakingIntegration.SkillType.CURATOR][IStakingIntegration.Rarity.UNCOMMON] = 1200;
        skillEffectValues[IStakingIntegration.SkillType.CURATOR][IStakingIntegration.Rarity.RARE] = 1400;
        skillEffectValues[IStakingIntegration.SkillType.CURATOR][IStakingIntegration.Rarity.EPIC] = 1800;
        skillEffectValues[IStakingIntegration.SkillType.CURATOR][IStakingIntegration.Rarity.LEGENDARY] = 2400;
        
        // AMBASSADOR (Skill #13): referral bonus base - Matches GameifiedMarketplaceCoreV1 multiplier tiers
        skillEffectValues[IStakingIntegration.SkillType.AMBASSADOR][IStakingIntegration.Rarity.COMMON] = 15000;  // 1.5x
        skillEffectValues[IStakingIntegration.SkillType.AMBASSADOR][IStakingIntegration.Rarity.UNCOMMON] = 20000; // 2.0x
        skillEffectValues[IStakingIntegration.SkillType.AMBASSADOR][IStakingIntegration.Rarity.RARE] = 26000;     // 2.6x
        skillEffectValues[IStakingIntegration.SkillType.AMBASSADOR][IStakingIntegration.Rarity.EPIC] = 30000;     // 3.0x
        skillEffectValues[IStakingIntegration.SkillType.AMBASSADOR][IStakingIntegration.Rarity.LEGENDARY] = 35000; // 3.5x
        
        // VIP_ACCESS (Skill #14)
        skillEffectValues[IStakingIntegration.SkillType.VIP_ACCESS][IStakingIntegration.Rarity.COMMON] = 1000;
        skillEffectValues[IStakingIntegration.SkillType.VIP_ACCESS][IStakingIntegration.Rarity.UNCOMMON] = 1500;
        skillEffectValues[IStakingIntegration.SkillType.VIP_ACCESS][IStakingIntegration.Rarity.RARE] = 2000;
        skillEffectValues[IStakingIntegration.SkillType.VIP_ACCESS][IStakingIntegration.Rarity.EPIC] = 3000;
        skillEffectValues[IStakingIntegration.SkillType.VIP_ACCESS][IStakingIntegration.Rarity.LEGENDARY] = 5000;
        
        // EARLY_ACCESS (Skill #15): 24h early access
        skillEffectValues[IStakingIntegration.SkillType.EARLY_ACCESS][IStakingIntegration.Rarity.COMMON] = 1000;
        skillEffectValues[IStakingIntegration.SkillType.EARLY_ACCESS][IStakingIntegration.Rarity.UNCOMMON] = 1500;
        skillEffectValues[IStakingIntegration.SkillType.EARLY_ACCESS][IStakingIntegration.Rarity.RARE] = 2000;
        skillEffectValues[IStakingIntegration.SkillType.EARLY_ACCESS][IStakingIntegration.Rarity.EPIC] = 3000;
        skillEffectValues[IStakingIntegration.SkillType.EARLY_ACCESS][IStakingIntegration.Rarity.LEGENDARY] = 5000;
        
        // PRIVATE_AUCTIONS (Skill #16)
        skillEffectValues[IStakingIntegration.SkillType.PRIVATE_AUCTIONS][IStakingIntegration.Rarity.COMMON] = 1000;
        skillEffectValues[IStakingIntegration.SkillType.PRIVATE_AUCTIONS][IStakingIntegration.Rarity.UNCOMMON] = 1500;
        skillEffectValues[IStakingIntegration.SkillType.PRIVATE_AUCTIONS][IStakingIntegration.Rarity.RARE] = 2000;
        skillEffectValues[IStakingIntegration.SkillType.PRIVATE_AUCTIONS][IStakingIntegration.Rarity.EPIC] = 3000;
        skillEffectValues[IStakingIntegration.SkillType.PRIVATE_AUCTIONS][IStakingIntegration.Rarity.LEGENDARY] = 5000;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MAIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
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
        
        // Track statistics for dashboard
        totalSkillsSold++;
        totalRevenue += price;
        skillsSoldByType[_skillType]++;
        skillsSoldByRarity[_rarity]++;
        revenueBySkillType[_skillType] += price;
        revenueByRarity[_rarity] += price;
        userTotalSpent[msg.sender] += price;
        
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
        
        // Check max active skills total (5)
        if (userActiveSkillCount[msg.sender] >= MAX_ACTIVE_SKILLS_TOTAL) {
            revert MaxActiveSkillsReached(uint8(MAX_ACTIVE_SKILLS_TOTAL));
        }
        
        // Update state
        skill.isActive = true;
        userActiveSkills[msg.sender].push(_skillId);
        
        unchecked {
            userActiveSkillCount[msg.sender]++;
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
        bool found = _removeFromArray(userActiveSkills[msg.sender], _skillId);
        if (!found) revert SkillNotInList(_skillId);
        
        // Decrement active count
        if (userActiveSkillCount[msg.sender] > 0) {
            unchecked {
                userActiveSkillCount[msg.sender]--;
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
            
            bool found = _removeFromArray(userActiveSkills[msg.sender], _skillId);
            if (!found) revert SkillNotInList(_skillId);
            
            if (userActiveSkillCount[msg.sender] > 0) {
                unchecked {
                    userActiveSkillCount[msg.sender]--;
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
    
    /// @notice Get a specific individual skill by ID
    function getIndividualSkill(uint256 _skillId) external view returns (IndividualSkill memory) {
        return individualSkills[_skillId];
    }
    
    /// @notice Get all individual skills owned by a user
    function getUserIndividualSkills(address _user) external view returns (uint256[] memory) {
        return userIndividualSkills[_user];
    }
    
    /// @notice Get active individual skills for a user by skill type
    function getUserActiveIndividualSkills(address _user, IStakingIntegration.SkillType /* _skillType */) external view returns (uint256[] memory) {
        return userActiveSkills[_user];
    }
    
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
    
    /// @notice Get detailed information about user's individual skills
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
     * @dev Get active skill count for user (O(1) lookup)
     * @param _user Address of user
     * @return count Number of active skills (max 5 total)
     */
    function getUserActiveSkillCount(address _user) external view returns (uint8 count) {
        return userActiveSkillCount[_user];
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
        // Professional dynamic pricing formula:
        // price = basePrice × rarity_multiplier
        // Rarity multiplier is already applied at initialization
        // For multi-level skills, level modifier is applied during purchase if needed
        
        uint8 rarityIndex = uint8(_rarity);
        uint256 basePrice = basePricePerRarity[rarityIndex];
        
        // Rarity cost multiplier (exponential progression)
        // COMMON (1.0x) → UNCOMMON (1.5x) → RARE (2.0x) → EPIC (2.8x) → LEGENDARY (3.5x)
        uint16[5] memory rarityPriceMultipliers = [
            10000,  // COMMON: 1.0x
            15000,  // UNCOMMON: 1.5x
            20000,  // RARE: 2.0x
            28000,  // EPIC: 2.8x
            35000   // LEGENDARY: 3.5x (less aggressive)
        ];
        
        // Skill-specific multipliers (not just by category)
        // Different skills have different base costs
        uint16 skillTypeMultiplier = _getSkillTypeMultiplier(_skillType);
        
        // Calculate final price: basePrice × rarityMultiplier × skillTypeMultiplier / 10000
        uint256 price = (basePrice * rarityPriceMultipliers[rarityIndex]) / BASIS_POINTS;
        price = (price * skillTypeMultiplier) / BASIS_POINTS;
        
        return price;
    }
    
    /**
     * @dev Calculate effect value for a skill with rarity and level modifiers
     * @param _skillType Type of skill
     * @param _rarity Rarity level
     * @return effectValue Effect value in basis points (considering rarity multiplier)
     */
    function _calculateSkillEffect(IStakingIntegration.SkillType _skillType, IStakingIntegration.Rarity _rarity) internal view returns (uint16) {
        uint16 baseEffect = skillEffectValues[_skillType][_rarity];
        if (baseEffect == 0) return 0;
        
        // Effect value is already set with rarity consideration during initialization
        // Return as-is since rarity multiplier is baked into the value
        return baseEffect;
    }
    
    /**
     * @dev Get skill type multiplier for dynamic pricing
     * Each skill type has its own base cost multiplier
     * Better skills cost more to prevent everyone buying best skill
     */
    function _getSkillTypeMultiplier(IStakingIntegration.SkillType _skillType) internal pure returns (uint16) {
        // Staking Skills with different multipliers
        if (_skillType == IStakingIntegration.SkillType.STAKE_BOOST_I) {
            return 10000; // 1.0x base
        } else if (_skillType == IStakingIntegration.SkillType.STAKE_BOOST_II) {
            return 15000; // 1.5x (50% more expensive than Boost I)
        } else if (_skillType == IStakingIntegration.SkillType.STAKE_BOOST_III) {
            return 22000; // 2.2x (120% more expensive than Boost I)
        } else if (_skillType == IStakingIntegration.SkillType.AUTO_COMPOUND) {
            return 18000; // 1.8x 
        } else if (_skillType == IStakingIntegration.SkillType.LOCK_REDUCER) {
            return 16000; // 1.6x
        } else if (_skillType == IStakingIntegration.SkillType.FEE_REDUCER_I) {
            return 14000; // 1.4x
        } else if (_skillType == IStakingIntegration.SkillType.FEE_REDUCER_II) {
            return 20000; // 2.0x (better than Fee Reducer I)
        }
        // Active skills (8-16)
        else if (uint8(_skillType) >= 8 && uint8(_skillType) <= 16) {
            return 12000; // 1.2x for platform skills
        }
        return 10000; // default
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
        
        // Use the new professional effect values system
        // Effect value = skillEffectValues[skillType][rarity] with rarity multiplier already applied
        uint16 effectValue = _calculateSkillEffect(_skillType, _rarity);
        if (effectValue == 0) return; // Skill has no effect value, skip notification
        
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = stakingContractAddress.call(
            abi.encodeWithSignature(
                "notifySkillActivation(address,uint256,uint8,uint16)",
                _user,
                _skillId,
                uint8(_skillType),
                effectValue
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
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS - PRICING & EFFECTS CONFIGURATION
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Update base price for a rarity tier
     * @param _rarityIndex Rarity index (0-4: COMMON to LEGENDARY)
     * @param _newPrice New base price in POL (wei)
     */
    function setBasePricePerRarity(uint8 _rarityIndex, uint256 _newPrice) external onlyRole(ADMIN_ROLE) {
        if (_rarityIndex > MAX_RARITY) revert InvalidRarity(_rarityIndex);
        if (_newPrice == 0) revert InvalidPrice(_newPrice, 0);
        
        basePricePerRarity[_rarityIndex] = _newPrice;
        emit BasePriceUpdated(IStakingIntegration.Rarity(_rarityIndex), _newPrice);
    }
    
    /**
     * @dev Update rarity effect multiplier
     * @param _rarityIndex Rarity index (0-4)
     * @param _newMultiplier New multiplier in basis points (10000 = 1.0x)
     */
    function setRarityEffectMultiplier(uint8 _rarityIndex, uint16 _newMultiplier) external onlyRole(ADMIN_ROLE) {
        if (_rarityIndex > MAX_RARITY) revert InvalidRarity(_rarityIndex);
        if (_newMultiplier == 0) revert InvalidPrice(_newMultiplier, 0);
        
        rarityEffectMultiplier[_rarityIndex] = _newMultiplier;
        emit RarityEffectMultiplierUpdated(IStakingIntegration.Rarity(_rarityIndex), _newMultiplier);
    }
    
    /**
     * @dev Update level multiplier for multi-level skills
     * @param _levelIndex Level index (1-3)
     * @param _newMultiplier New multiplier in basis points
     */
    function setLevelMultiplier(uint8 _levelIndex, uint16 _newMultiplier) external onlyRole(ADMIN_ROLE) {
        if (_levelIndex < 1 || _levelIndex > 3) revert InvalidLevel(_levelIndex);
        if (_newMultiplier == 0) revert InvalidPrice(_newMultiplier, 0);
        
        levelMultiplier[_levelIndex] = _newMultiplier;
        emit SkillLevelMultiplierUpdated(_levelIndex, _newMultiplier);
    }
    
    /**
     * @dev Update effect value for a specific skill + rarity combination
     * @param _skillType Type of skill
     * @param _rarity Rarity level
     * @param _effectValue New effect value in basis points
     * 
     * EXAMPLES:
     * - STAKE_BOOST_I COMMON: 500 (5% APY)
     * - STAKE_BOOST_I LEGENDARY: 2500 (25% APY) 
     * - FEE_REDUCER_II COMMON: 2500 (25% fee discount)
     */
    function setSkillEffectValue(
        IStakingIntegration.SkillType _skillType,
        IStakingIntegration.Rarity _rarity,
        uint16 _effectValue
    ) external onlyRole(ADMIN_ROLE) {
        if (uint8(_skillType) < MIN_SKILL_TYPE || uint8(_skillType) > MAX_SKILL_TYPE) {
            revert InvalidSkillType(uint8(_skillType));
        }
        if (uint8(_rarity) > MAX_RARITY) {
            revert InvalidRarity(uint8(_rarity));
        }
        
        skillEffectValues[_skillType][_rarity] = _effectValue;
        emit SkillEffectValueUpdated(_skillType, _rarity, _effectValue);
    }
    
    /**
     * @dev Batch update effect values for all rarities of a single skill
     * @param _skillType Type of skill
     * @param _commonEffect Common rarity effect value
     * @param _uncommonEffect Uncommon rarity effect value
     * @param _rareEffect Rare rarity effect value
     * @param _epicEffect Epic rarity effect value
     * @param _legendaryEffect Legendary rarity effect value
     */
    function setSkillEffectValuesAllRarities(
        IStakingIntegration.SkillType _skillType,
        uint16 _commonEffect,
        uint16 _uncommonEffect,
        uint16 _rareEffect,
        uint16 _epicEffect,
        uint16 _legendaryEffect
    ) external onlyRole(ADMIN_ROLE) {
        if (uint8(_skillType) < MIN_SKILL_TYPE || uint8(_skillType) > MAX_SKILL_TYPE) {
            revert InvalidSkillType(uint8(_skillType));
        }
        
        skillEffectValues[_skillType][IStakingIntegration.Rarity.COMMON] = _commonEffect;
        skillEffectValues[_skillType][IStakingIntegration.Rarity.UNCOMMON] = _uncommonEffect;
        skillEffectValues[_skillType][IStakingIntegration.Rarity.RARE] = _rareEffect;
        skillEffectValues[_skillType][IStakingIntegration.Rarity.EPIC] = _epicEffect;
        skillEffectValues[_skillType][IStakingIntegration.Rarity.LEGENDARY] = _legendaryEffect;
        
        emit SkillEffectValueUpdated(_skillType, IStakingIntegration.Rarity.COMMON, _commonEffect);
        emit SkillEffectValueUpdated(_skillType, IStakingIntegration.Rarity.UNCOMMON, _uncommonEffect);
        emit SkillEffectValueUpdated(_skillType, IStakingIntegration.Rarity.RARE, _rareEffect);
        emit SkillEffectValueUpdated(_skillType, IStakingIntegration.Rarity.EPIC, _epicEffect);
        emit SkillEffectValueUpdated(_skillType, IStakingIntegration.Rarity.LEGENDARY, _legendaryEffect);
    }
    
    /**
     * @dev View current effect values for all rarities of a skill
     * @param _skillType Type of skill
     * @return effectValues Array of effect values [COMMON, UNCOMMON, RARE, EPIC, LEGENDARY]
     */
    function getSkillEffectValuesAllRarities(IStakingIntegration.SkillType _skillType) external view returns (uint16[5] memory effectValues) {
        if (uint8(_skillType) < MIN_SKILL_TYPE || uint8(_skillType) > MAX_SKILL_TYPE) {
            revert InvalidSkillType(uint8(_skillType));
        }
        
        effectValues[0] = skillEffectValues[_skillType][IStakingIntegration.Rarity.COMMON];
        effectValues[1] = skillEffectValues[_skillType][IStakingIntegration.Rarity.UNCOMMON];
        effectValues[2] = skillEffectValues[_skillType][IStakingIntegration.Rarity.RARE];
        effectValues[3] = skillEffectValues[_skillType][IStakingIntegration.Rarity.EPIC];
        effectValues[4] = skillEffectValues[_skillType][IStakingIntegration.Rarity.LEGENDARY];
        
        return effectValues;
    }
    
    /**
     * @dev View current pricing configuration
     * @return prices Array of base prices [COMMON, UNCOMMON, RARE, EPIC, LEGENDARY]
     */
    function getCurrentBasePrices() external view returns (uint256[5] memory prices) {
        for (uint8 i = 0; i < 5; i++) {
            prices[i] = basePricePerRarity[i];
        }
        return prices;
    }
    
    /**
     * @dev View current rarity effect multipliers
     * @return multipliers Array of multipliers [COMMON, UNCOMMON, RARE, EPIC, LEGENDARY]
     */
    function getRarityEffectMultipliers() external view returns (uint16[5] memory multipliers) {
        for (uint8 i = 0; i < 5; i++) {
            multipliers[i] = rarityEffectMultiplier[i];
        }
        return multipliers;
    }
    
    /**
     * @dev View current level multipliers
     * @return multipliers Array of multipliers [Level1, Level2, Level3]
     */
    function getLevelMultipliers() external view returns (uint16[3] memory multipliers) {
        multipliers[0] = levelMultiplier[1];
        multipliers[1] = levelMultiplier[2];
        multipliers[2] = levelMultiplier[3];
        return multipliers;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // DASHBOARD VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @dev Get individual skills marketplace statistics
     */
    function getIndividualSkillsMarketStats() external view returns (
        uint256 skillsSold,
        uint256 activeSkills,
        uint256 revenue,
        uint256 averagePricePerSkill,
        uint256 uniqueBuyers
    ) {
        skillsSold = totalSkillsSold;
        revenue = totalRevenue;
        averagePricePerSkill = skillsSold > 0 ? revenue / skillsSold : 0;
        
        // Count active skills
        uint256 counter = _skillCounter.current();
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < counter; i++) {
            if (individualSkills[i].owner != address(0) && individualSkills[i].isActive) {
                activeCount++;
            }
        }
        activeSkills = activeCount;
        
        // Count unique buyers (approximate - counts users with skills)
        uint256 buyerCount = 0;
        for (uint256 i = 0; i < counter; i++) {
            address owner = individualSkills[i].owner;
            if (owner != address(0) && userIndividualSkills[owner].length > 0) {
                buyerCount++;
                break;
            }
        }
        uniqueBuyers = buyerCount;
    }

    /**
     * @dev Get skill revenue breakdown by type
     */
    function getSkillRevenueByType() external view returns (
        IStakingIntegration.SkillType[] memory skillTypes,
        uint256[] memory revenue,
        uint256[] memory salesCount
    ) {
        uint256 totalTypes = 16;
        skillTypes = new IStakingIntegration.SkillType[](totalTypes);
        revenue = new uint256[](totalTypes);
        salesCount = new uint256[](totalTypes);
        
        for (uint8 i = 1; i <= totalTypes; i++) {
            IStakingIntegration.SkillType skillType = IStakingIntegration.SkillType(i);
            skillTypes[i - 1] = skillType;
            revenue[i - 1] = revenueBySkillType[skillType];
            salesCount[i - 1] = skillsSoldByType[skillType];
        }
    }

    /**
     * @dev Get skill revenue breakdown by rarity
     */
    function getSkillRevenueByRarity() external view returns (
        IStakingIntegration.Rarity[] memory rarities,
        uint256[] memory revenue,
        uint256[] memory salesCount
    ) {
        rarities = new IStakingIntegration.Rarity[](5);
        revenue = new uint256[](5);
        salesCount = new uint256[](5);
        
        for (uint8 i = 0; i <= 4; i++) {
            IStakingIntegration.Rarity rarity = IStakingIntegration.Rarity(i);
            rarities[i] = rarity;
            revenue[i] = revenueByRarity[rarity];
            salesCount[i] = skillsSoldByRarity[rarity];
        }
    }

    /**
     * @dev Get user's total spending on skills
     */
    function getUserSkillSpending(address _user) external view returns (
        uint256 totalSpent,
        uint256 skillsPurchased,
        uint256 averageSpentPerSkill,
        IStakingIntegration.SkillType mostPurchasedType
    ) {
        totalSpent = userTotalSpent[_user];
        skillsPurchased = userIndividualSkills[_user].length;
        averageSpentPerSkill = skillsPurchased > 0 ? totalSpent / skillsPurchased : 0;
        
        // Find most purchased skill type (simplified - returns first found)
        uint256[] memory userSkills = userIndividualSkills[_user];
        if (userSkills.length > 0) {
            mostPurchasedType = individualSkills[userSkills[0]].skillType;
        } else {
            mostPurchasedType = IStakingIntegration.SkillType.NONE;
        }
    }

    /**
     * @dev Get skill adoption rate (percentage of users with each skill)
     */
    function getSkillAdoptionRates() external view returns (
        IStakingIntegration.SkillType[] memory skillTypes,
        uint256[] memory userCounts,
        uint256[] memory percentages
    ) {
        uint256 totalTypes = 16;
        skillTypes = new IStakingIntegration.SkillType[](totalTypes);
        userCounts = new uint256[](totalTypes);
        percentages = new uint256[](totalTypes);
        
        // Simplified: count total purchases by type (not unique users)
        for (uint8 i = 1; i <= totalTypes; i++) {
            IStakingIntegration.SkillType skillType = IStakingIntegration.SkillType(i);
            skillTypes[i - 1] = skillType;
            userCounts[i - 1] = skillsSoldByType[skillType];
            
            // Calculate percentage of total sales
            if (totalSkillsSold > 0) {
                percentages[i - 1] = (skillsSoldByType[skillType] * 10000) / totalSkillsSold;
            } else {
                percentages[i - 1] = 0;
            }
        }
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS - LEGACY (kept for backward compatibility)
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
