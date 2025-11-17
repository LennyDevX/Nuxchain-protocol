// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IEnhancedSmartStakingGamification
 * @notice Interface for gamification features in the EnhancedSmartStaking system
 * @dev This module handles XP, levels, quests, achievements, and auto-compound functionality
 */
interface IEnhancedSmartStakingGamification {
    
    // ============================================
    // STRUCTS
    // ============================================
    
    struct QuestReward {
        uint256 amount;
        uint256 expirationTime;
        bool claimed;
    }
    
    struct AchievementReward {
        uint256 amount;
        uint256 expirationTime;
        bool claimed;
    }
    
    struct AutoCompoundConfig {
        bool enabled;
        uint256 minAmount;
        uint256 lastCompoundTime;
    }
    
    // ============================================
    // EVENTS
    // ============================================
    
    event XPUpdated(address indexed user, uint256 newXP, uint16 newLevel);
    event QuestCompleted(address indexed user, uint256 questId, uint256 rewardAmount);
    event AchievementUnlocked(address indexed user, uint256 achievementId, uint256 rewardAmount);
    event RewardExpired(address indexed user, string rewardType, uint256 amount);
    event AutoCompoundEnabled(address indexed user, uint256 minAmount);
    event AutoCompoundDisabled(address indexed user);
    event AutoCompoundExecuted(address indexed user, uint256 amount);
    
    // ============================================
    // STATE-CHANGING FUNCTIONS - XP & LEVELS
    // ============================================
    
    /**
     * @notice Update user XP and level based on action
     * @param user The user address
     * @param actionType The type of action (0=stake, 1=compound, 2=quest, 3=achievement)
     * @param amount The amount involved in the action (for stake/compound)
     */
    function updateUserXP(address user, uint8 actionType, uint256 amount) external;
    
    /**
     * @notice Manually set XP for a user (admin only)
     * @param user The user address
     * @param xp The XP amount to set
     */
    function setUserXP(address user, uint256 xp) external;
    
    // ============================================
    // STATE-CHANGING FUNCTIONS - QUESTS
    // ============================================
    
    /**
     * @notice Complete a quest and award reward to user
     * @param user The user address
     * @param questId The quest identifier
     * @param rewardAmount The reward amount in tokens
     * @param expirationDays Days until reward expires
     */
    function completeQuest(
        address user,
        uint256 questId,
        uint256 rewardAmount,
        uint256 expirationDays
    ) external;
    
    /**
     * @notice Claim a pending quest reward
     * @param questId The quest identifier
     */
    function claimQuestReward(uint256 questId) external;
    
    /**
     * @notice Check and expire unclaimed quest rewards
     * @param user The user address
     * @param questIds Array of quest IDs to check
     */
    function expireQuestRewards(address user, uint256[] calldata questIds) external;
    
    // ============================================
    // STATE-CHANGING FUNCTIONS - ACHIEVEMENTS
    // ============================================
    
    /**
     * @notice Unlock an achievement and award reward to user
     * @param user The user address
     * @param achievementId The achievement identifier
     * @param rewardAmount The reward amount in tokens
     * @param expirationDays Days until reward expires
     */
    function unlockAchievement(
        address user,
        uint256 achievementId,
        uint256 rewardAmount,
        uint256 expirationDays
    ) external;
    
    /**
     * @notice Claim a pending achievement reward
     * @param achievementId The achievement identifier
     */
    function claimAchievementReward(uint256 achievementId) external;
    
    /**
     * @notice Check and expire unclaimed achievement rewards
     * @param user The user address
     * @param achievementIds Array of achievement IDs to check
     */
    function expireAchievementRewards(address user, uint256[] calldata achievementIds) external;
    
    // ============================================
    // STATE-CHANGING FUNCTIONS - AUTO-COMPOUND
    // ============================================
    
    /**
     * @notice Enable auto-compound for caller
     * @param minAmount Minimum amount to trigger auto-compound
     */
    function enableAutoCompound(uint256 minAmount) external;
    
    /**
     * @notice Disable auto-compound for caller
     */
    function disableAutoCompound() external;
    
    /**
     * @notice Check if auto-compound should be performed for a user
     * @param user The user address
     * @return shouldCompound True if auto-compound criteria are met
     * @return compoundAmount The amount that would be compounded
     */
    function checkAutoCompound(address user) external view returns (bool shouldCompound, uint256 compoundAmount);
    
    /**
     * @notice Perform auto-compound for a user (Chainlink Keeper compatible)
     * @param user The user address
     */
    function performAutoCompound(address user) external;
    
    /**
     * @notice Batch perform auto-compound for multiple users
     * @param users Array of user addresses
     */
    function batchAutoCompound(address[] calldata users) external;
    
    // ============================================
    // VIEW FUNCTIONS - XP & LEVELS
    // ============================================
    
    /**
     * @notice Get user XP and level
     * @param user The user address
     * @return xp Current XP
     * @return level Current level
     * @return xpToNextLevel XP needed for next level
     */
    function getUserXPInfo(address user) external view returns (
        uint256 xp,
        uint16 level,
        uint256 xpToNextLevel
    );
    
    /**
     * @notice Calculate level from XP amount
     * @param xp The XP amount
     * @return level The calculated level
     */
    function calculateLevel(uint256 xp) external pure returns (uint16 level);
    
    /**
     * @notice Get XP required for a specific level
     * @param level The target level
     * @return xp The XP required
     */
    function getXPForLevel(uint16 level) external pure returns (uint256 xp);
    
    // ============================================
    // VIEW FUNCTIONS - QUESTS & ACHIEVEMENTS
    // ============================================
    
    /**
     * @notice Get pending quest reward
     * @param user The user address
     * @param questId The quest identifier
     * @return reward The quest reward details
     */
    function getQuestReward(address user, uint256 questId) external view returns (QuestReward memory reward);
    
    /**
     * @notice Get pending achievement reward
     * @param user The user address
     * @param achievementId The achievement identifier
     * @return reward The achievement reward details
     */
    function getAchievementReward(address user, uint256 achievementId) external view returns (AchievementReward memory reward);
    
    /**
     * @notice Get all pending quest rewards for a user
     * @param user The user address
     * @return questIds Array of quest IDs
     * @return rewards Array of quest rewards
     */
    function getAllQuestRewards(address user) external view returns (
        uint256[] memory questIds,
        QuestReward[] memory rewards
    );
    
    /**
     * @notice Get all pending achievement rewards for a user
     * @param user The user address
     * @return achievementIds Array of achievement IDs
     * @return rewards Array of achievement rewards
     */
    function getAllAchievementRewards(address user) external view returns (
        uint256[] memory achievementIds,
        AchievementReward[] memory rewards
    );
    
    // ============================================
    // VIEW FUNCTIONS - AUTO-COMPOUND
    // ============================================
    
    /**
     * @notice Get auto-compound configuration for a user
     * @param user The user address
     * @return config The auto-compound configuration
     */
    function getAutoCompoundConfig(address user) external view returns (AutoCompoundConfig memory config);
    
    /**
     * @notice Get all users with auto-compound enabled (paginated)
     * @param offset Starting index
     * @param limit Maximum number of users to return
     * @return users Array of user addresses
     * @return configs Array of auto-compound configurations
     * @return total Total number of users with auto-compound enabled
     */
    function getAutoCompoundUsersPage(uint256 offset, uint256 limit) external view returns (
        address[] memory users,
        AutoCompoundConfig[] memory configs,
        uint256 total
    );
}
