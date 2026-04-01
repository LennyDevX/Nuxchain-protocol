// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IQuestCore
 * @notice Interface for the central quest registry.
 *
 * ARCHITECTURE:
 *   Single contract that owns ALL quest definitions for the protocol.
 *   External contracts (Staking, Social, MiniGame) hold REPORTER_ROLE and call
 *   notifyAction() when users perform tracked activities. Users call completeQuest()
 *   once their progress meets the requirement.
 *
 * QUEST TYPES:
 *   - PURCHASE / CREATE / TRADING / LEVEL_UP → progress read from ILevelingSystem.getUserProfile()
 *   - SOCIAL / STAKE / COMPOUND / AGENT_TASK → progress tracked via internal actionCounters,
 *     incremented by REPORTER_ROLE callers via notifyAction()
 *
 * REWARDS:
 *   - xpReward (uint256) → XP awarded via ILevelingSystem.updateUserXP()    (0 = XP-only disabled)
 *   - polReward (uint256) → POL in wei paid via QuestRewardsPool.requestPayout() (0 = no POL)
 */
interface IQuestCore {

    // ============================================
    // ENUMS
    // ============================================

    /// @notice Domain / category the quest belongs to (for admin dashboard filtering).
    enum QuestCategory { MARKETPLACE, STAKING, NFT_AGENT, GENERAL }

    /**
     * @notice Type of action required to make progress on a quest.
     * - PURCHASE..TRADING use ILevelingSystem profile data
     * - SOCIAL..AGENT_TASK use internal actionCounters incremented by notifyAction()
     */
    enum QuestType {
        PURCHASE,     // 0 — buy N NFTs
        CREATE,       // 1 — create N NFTs
        SOCIAL,       // 2 — N likes or comments
        LEVEL_UP,     // 3 — reach level N
        TRADING,      // 4 — sell N NFTs
        STAKE,        // 5 — stake (value = wei deposited)
        COMPOUND,     // 6 — compound N times
        AGENT_TASK    // 7 — complete N AI agent tasks
    }

    // ============================================
    // STRUCTS
    // ============================================

    struct QuestCreateParams {
        QuestCategory category;
        QuestType     questType;
        string        title;
        string        description;
        uint256       requirement;      // How many actions are needed
        uint256       xpReward;         // 0 = no XP
        uint256       polReward;        // 0 = no POL; paid via QuestRewardsPool
        uint256       startTime;        // 0 = now
        uint256       deadline;         // 0 = no deadline
        uint256       completionLimit;  // 0 = unlimited global completions
    }

    struct Quest {
        uint256       questId;
        QuestCategory category;
        QuestType     questType;
        string        title;
        string        description;
        uint256       requirement;
        uint256       xpReward;
        uint256       polReward;
        bool          active;
        uint256       startTime;
        uint256       deadline;
        uint256       completionLimit;
        uint256       createdAt;
    }

    struct UserQuestProgress {
        uint256 questId;
        uint256 currentProgress;
        bool    completed;
        uint256 completedAt;
    }

    // ============================================
    // EVENTS
    // ============================================

    event QuestCreated(
        uint256 indexed questId,
        QuestCategory   category,
        QuestType       questType,
        string          title,
        uint256         requirement,
        uint256         xpReward,
        uint256         polReward
    );
    event QuestCompleted(address indexed user, uint256 indexed questId, uint256 xpRewarded, uint256 polRewarded);
    event QuestDeactivated(uint256 indexed questId);
    event ActionNotified(address indexed user, QuestType questType, uint256 value);
    event QuestProgressUpdated(address indexed user, uint256 indexed questId, uint256 progress);
    event QuestRewardDeferred(address indexed user, uint256 indexed questId, uint256 amount);
    event PendingPolRewardsClaimed(address indexed user, uint256 amount);

    // ============================================
    // ADMIN
    // ============================================

    function createQuest(QuestCreateParams calldata params) external returns (uint256 questId);
    function deactivateQuest(uint256 questId) external;
    function setCoreContract(address coreAddress) external;
    function setStakingContract(address stakingAddress) external;
    function setLevelingContract(address levelingAddress) external;

    // ============================================
    // USER ACTIONS
    // ============================================

    function completeQuest(uint256 questId) external;
    function claimPendingPolRewards() external;

    /// @notice Called by REPORTER_ROLE contracts to record user activity.
    function notifyAction(address user, QuestType questType, uint256 value) external;

    /// @notice ADMIN_ROLE convenience that increments SOCIAL counter for a user.
    function recordSocialAction(address user) external;

    // ============================================
    // VIEW
    // ============================================

    function getAllActiveQuests() external view returns (Quest[] memory);
    function getQuestsByType(QuestType questType) external view returns (Quest[] memory);
    function getQuestsByCategory(QuestCategory category) external view returns (Quest[] memory);
    function getQuest(uint256 questId) external view returns (Quest memory);
    function getUserQuestProgress(address user, uint256 questId) external view returns (UserQuestProgress memory);
    function getUserQuestProgressByType(address user, QuestType questType)
        external
        view
        returns (uint256[] memory questIds, UserQuestProgress[] memory progresses);
    function getUserCompletedQuests(address user) external view returns (uint256[] memory);
    function getUserSocialActions(address user) external view returns (uint256);
    function getMostPopularQuests(uint256 limit)
        external
        view
        returns (uint256[] memory questIds, uint256[] memory completionCounts, string[] memory titles);
    function getQuestLeaderboard(uint256 limit)
        external
        view
        returns (address[] memory users, uint256[] memory completedCounts, uint256[] memory totalXP);

    function getQuestSystemStats() external view returns (
        uint256 totalQuests,
        uint256 activeQuests,
        uint256 totalCompletions,
        uint256 totalXPAwarded,
        uint256 averageCompletionRate
    );

    function getUserQuestStats(address user) external view returns (
        uint256 totalCompleted,
        uint256 totalInProgress,
        uint256 totalXPEarned,
        uint256 completionRate,
        QuestType favoriteType
    );

    function getUserIncompleteQuests(address user) external view returns (
        uint256[] memory questIds,
        Quest[]   memory questData,
        uint256[] memory progressPercentages
    );

    function updateQuestProgress(address user, uint256 questId) external;
}
