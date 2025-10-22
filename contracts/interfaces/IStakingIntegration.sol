// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IStakingIntegration
 * @dev Interface for communication between GameifiedMarketplace and EnhancedSmartStaking
 * @notice This interface enables NFT skills to affect staking rewards and behavior
 * @custom:security-contact security@nuvo.com
 */
interface IStakingIntegration {
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ENUMS & STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Enum representing different types of NFT skills
     */
    enum SkillType {
        NONE,                   // No skill
        STAKE_BOOST_I,         // +5% APY
        STAKE_BOOST_II,        // +10% APY
        STAKE_BOOST_III,       // +20% APY
        AUTO_COMPOUND,         // Automatic compounding
        LOCK_REDUCER,          // -25% lock time
        FEE_REDUCER_I,         // -10% platform fees
        FEE_REDUCER_II,        // -25% platform fees
        PRIORITY_LISTING,      // Featured on homepage
        ROYALTY_BOOSTER,       // +5% on received royalties
        BATCH_MINTER,          // Mint multiple NFTs
        VERIFIED_CREATOR,      // Verified badge
        INFLUENCER,            // 2x weight on likes/comments
        CURATOR,               // Can create featured collections
        AMBASSADOR,            // 2x referral bonus
        VIP_ACCESS,            // Access to exclusive drops
        EARLY_ACCESS,          // 24h early access
        PRIVATE_AUCTIONS,      // Access to private auctions
        AIRDROP_MAGNET         // 3x airdrop probability
    }
    
    /**
     * @dev Enum representing skill rarity tiers
     */
    enum Rarity {
        COMMON,      // 1-3 stars
        UNCOMMON,    // 4-5 stars
        RARE,        // 6-7 stars
        EPIC,        // 8-9 stars
        LEGENDARY    // 10 stars
    }
    
    /**
     * @dev Structure representing an NFT skill
     */
    struct NFTSkill {
        SkillType skillType;     // Type of skill
        uint16 effectValue;      // Effect magnitude (in basis points, 500 = 5%)
        Rarity rarity;           // Skill rarity
        uint64 activatedAt;      // Timestamp when activated
        uint64 cooldownEnds;     // Cooldown expiration timestamp
        bool isActive;           // Whether skill is currently active
    }
    
    /**
     * @dev Structure representing a user's skill profile
     */
    struct UserSkillProfile {
        uint256[] activeNFTIds;           // NFT token IDs with active skills
        uint256 totalXP;                  // Total experience points
        uint8 level;                      // User level
        uint8 maxActiveSkills;            // Maximum skills that can be active
        uint16 stakingBoostTotal;         // Total staking boost percentage
        uint16 feeDiscountTotal;          // Total fee discount percentage
        bool hasAutoCompound;             // Auto-compound skill active
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Emitted when a skill is activated
     */
    event SkillActivated(
        address indexed user,
        uint256 indexed nftId,
        SkillType skillType,
        uint16 effectValue
    );
    
    /**
     * @dev Emitted when a skill is deactivated
     */
    event SkillDeactivated(
        address indexed user,
        uint256 indexed nftId,
        SkillType skillType
    );
    
    /**
     * @dev Emitted when user's skill profile is updated
     */
    event SkillProfileUpdated(
        address indexed user,
        uint8 level,
        uint8 maxActiveSkills,
        uint16 stakingBoostTotal
    );
    
    /**
     * @dev Emitted when auto-compound is triggered
     */
    event AutoCompoundTriggered(
        address indexed user,
        uint256 compoundedAmount
    );
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MARKETPLACE → STAKING FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Notifies staking contract that a skill has been activated
     * @param user Address of the user
     * @param nftId Token ID of the NFT with the skill
     * @param skillType Type of skill being activated
     * @param effectValue Magnitude of the effect (in basis points)
     */
    function notifySkillActivation(
        address user,
        uint256 nftId,
        SkillType skillType,
        uint16 effectValue
    ) external;
    
    /**
     * @dev Notifies staking contract that a skill has been deactivated
     * @param user Address of the user
     * @param nftId Token ID of the NFT with the skill
     */
    function notifySkillDeactivation(address user, uint256 nftId) external;
    
    /**
     * @dev Updates user's XP and level, potentially unlocking new skill slots
     * @param user Address of the user
     * @param xpGained Amount of XP gained
     */
    function updateUserXP(address user, uint256 xpGained) external;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STAKING → MARKETPLACE QUERY FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Retrieves all active skills for a user
     * @param user Address of the user
     * @return Array of active NFT skills
     */
    function getActiveSkills(address user) external view returns (NFTSkill[] memory);
    
    /**
     * @dev Gets user's complete skill profile
     * @param user Address of the user
     * @return User's skill profile
     */
    function getUserSkillProfile(address user) external view returns (UserSkillProfile memory);
    
    /**
     * @dev Calculates boosted APY based on active skills
     * @param user Address of the user
     * @param baseAPY Base APY percentage (in basis points)
     * @return Boosted APY percentage (in basis points)
     */
    function calculateBoostedAPY(address user, uint256 baseAPY) external view returns (uint256);
    
    /**
     * @dev Calculates reduced lock time based on active skills
     * @param user Address of the user
     * @param baseLockTime Base lock time in seconds
     * @return Reduced lock time in seconds
     */
    function calculateReducedLockTime(address user, uint256 baseLockTime) external view returns (uint256);
    
    /**
     * @dev Checks if user has auto-compound skill active
     * @param user Address of the user
     * @return True if auto-compound is active
     */
    function hasAutoCompound(address user) external view returns (bool);
    
    /**
     * @dev Calculates fee discount based on active skills and user level
     * @param user Address of the user
     * @param baseFee Base fee percentage (in basis points)
     * @return Discounted fee percentage (in basis points)
     */
    function calculateFeeDiscount(address user, uint256 baseFee) external view returns (uint256);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // AUTOMATION FUNCTIONS (For Chainlink Keepers or similar)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Checks if auto-compound should be triggered for a user
     * @param user Address of the user
     * @return upkeepNeeded True if compound should be executed
     * @return performData Encoded data for the compound operation
     */
    function checkAutoCompound(address user) external view returns (bool upkeepNeeded, bytes memory performData);
    
    /**
     * @dev Executes auto-compound for eligible users
     * @param performData Encoded data containing users to compound
     */
    function performAutoCompound(bytes calldata performData) external;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Sets the marketplace contract address (only callable by admin)
     * @param marketplaceAddress Address of the marketplace contract
     */
    function setMarketplaceAddress(address marketplaceAddress) external;
    
    /**
     * @dev Sets the staking contract address (only callable by admin)
     * @param stakingAddress Address of the staking contract
     */
    function setStakingAddress(address stakingAddress) external;
    
    /**
     * @dev Enables or disables a specific skill type
     * @param skillType Type of skill to enable/disable
     * @param enabled True to enable, false to disable
     */
    function setSkillEnabled(SkillType skillType, bool enabled) external;
    
    /**
     * @dev Updates the effect value for a skill type
     * @param skillType Type of skill to update
     * @param newEffectValue New effect value (in basis points)
     */
    function updateSkillEffect(SkillType skillType, uint16 newEffectValue) external;
}
