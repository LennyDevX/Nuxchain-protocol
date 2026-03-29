// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IQuestCore.sol";
import "../interfaces/IXPHub.sol";

interface IQuestPoolCaller {
    function requestPayout(address recipient, uint256 amount, string calldata source) external;
}

/**
 * @title QuestCore
 * @notice Central quest registry for the entire Nuxchain protocol.
 *
 * ARCHITECTURE:
 *   - The ONLY contract where quests are created (admin dashboard calls createQuest()).
 *   - Covers all domains: Marketplace, Staking, AI NFT Agents, General.
 *   - External modules (StakingCoreV2, MarketplaceSocial, NuxAgentMiniGame) hold REPORTER_ROLE
 *     and call notifyAction() whenever a tracked user action occurs.
 *   - Users call completeQuest() once their progress reaches the requirement.
 *
 * PROGRESS CALCULATION:
 *   Profile-based (data from LevelingSystem.getUserProfile):
 *     PURCHASE  → profile.nftsBought
 *     CREATE    → profile.nftsCreated
 *     TRADING   → profile.nftsSold
 *     LEVEL_UP  → profile.level (capped at 50)
 *   Counter-based (incremented via notifyAction):
 *     SOCIAL    → likes + comments (notified by MarketplaceSocial)
 *     STAKE     → wei deposited    (notified by SmartStakingCoreV2)
 *     COMPOUND  → compound count   (notified by SmartStakingCoreV2)
 *     AGENT_TASK → tasks approved  (notified by NuxAgentMiniGame)
 *
 * POST-DEPLOY SETUP (admin dashboard):
 *   1. grantRole(REPORTER_ROLE, stakingCoreV2)
 *   2. grantRole(REPORTER_ROLE, miniGame)
 *   3. grantRole(REPORTER_ROLE, marketplaceSocial)
 *   4. setLevelingContract(levelingSystemAddress)
 *   5. setQuestRewardsPool(questRewardsPoolAddress)
 *   6. Grant MODULE_ROLE on QuestRewardsPool to this contract's address
 */
contract QuestCore is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IQuestCore
{
    // ============================================
    // ROLES
    // ============================================

    bytes32 public constant ADMIN_ROLE    = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Assigned to StakingCoreV2, MarketplaceSocial, NuxAgentMiniGame.
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");

    // ============================================
    // CONSTANTS
    // ============================================

    uint8   private constant MAX_LEVEL                    = 50;
    uint256 private constant MAX_XP_REWARD                = 50_000;
    uint256 private constant MAX_SOCIAL_ACTIONS_PER_QUEST = 1_000;

    // ============================================
    // STATE
    // ============================================

    uint256 private _questIdCounter;

    mapping(uint256 => Quest)                                      public quests;
    mapping(address => mapping(uint256 => UserQuestProgress))      public userQuestProgress;
    mapping(address => uint256[])                                  public userCompletedQuests;

    /// @notice actionCounters[user][uint8(QuestType)] for counter-based quest types.
    mapping(address => mapping(uint8 => uint256))                  public actionCounters;

    /// @notice How many times a quest has been globally completed (for completionLimit).
    mapping(uint256 => uint256)                                    public questGlobalCompletions;

    /// @notice Addresses of integrated contracts (kept for reference and backward compat).
    address public coreContractAddress;
    address public stakingContractAddress;
    address public levelingContractAddress;

    IQuestPoolCaller public questRewardsPool;

    /// @notice Total quest completions across all users (for dashboard stats).
    uint256 public totalCompletionsAllTime;

    // ============================================
    // ADDITIONAL EVENTS
    // ============================================

    event CoreContractUpdated(address indexed oldCore,    address indexed newCore);
    event StakingContractUpdated(address indexed oldStaking, address indexed newStaking);
    event LevelingContractUpdated(address indexed oldLeveling, address indexed newLeveling);
    event QuestRewardsPoolUpdated(address indexed oldPool,    address indexed newPool);
    event SocialActionRecorded(address indexed user, uint256 newTotal);

    // ============================================
    // ERRORS
    // ============================================

    error QuestNotFound();
    error QuestNotActive();
    error QuestExpired();
    error QuestNotStarted();
    error RequirementNotMet();
    error AlreadyCompleted();
    error InvalidAddress();
    error InvalidRequirement();
    error InvalidXPReward();
    error InvalidMetadata();
    error CompletionLimitReached();

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin_, address coreContractAddress_) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);

        if (coreContractAddress_ != address(0)) {
            coreContractAddress = coreContractAddress_;
        }
    }

    // ============================================
    // QUEST MANAGEMENT (Admin)
    // ============================================

    /// @inheritdoc IQuestCore
    function createQuest(QuestCreateParams calldata params)
        external
        override
        onlyRole(ADMIN_ROLE)
        returns (uint256 questId)
    {
        if (bytes(params.title).length == 0 || bytes(params.description).length == 0) revert InvalidMetadata();
        if (params.requirement == 0) revert InvalidRequirement();
        if (params.xpReward > MAX_XP_REWARD) revert InvalidXPReward();
        if (params.questType == QuestType.SOCIAL && params.requirement > MAX_SOCIAL_ACTIONS_PER_QUEST) {
            revert InvalidRequirement();
        }
        if (params.deadline != 0 && params.deadline <= block.timestamp) revert QuestExpired();

        questId = ++_questIdCounter;

        quests[questId] = Quest({
            questId:         questId,
            category:        params.category,
            questType:       params.questType,
            title:           params.title,
            description:     params.description,
            requirement:     params.requirement,
            xpReward:        params.xpReward,
            polReward:       params.polReward,
            active:          true,
            startTime:       params.startTime == 0 ? block.timestamp : params.startTime,
            deadline:        params.deadline,
            completionLimit: params.completionLimit,
            createdAt:       block.timestamp
        });

        emit QuestCreated(questId, params.category, params.questType, params.title, params.requirement, params.xpReward, params.polReward);
    }

    /// @inheritdoc IQuestCore
    function deactivateQuest(uint256 questId) external override onlyRole(ADMIN_ROLE) {
        if (!quests[questId].active) revert QuestNotActive();
        quests[questId].active = false;
        emit QuestDeactivated(questId);
    }

    // ============================================
    // QUEST COMPLETION (User)
    // ============================================

    /// @inheritdoc IQuestCore
    function completeQuest(uint256 questId) external override whenNotPaused nonReentrant {
        if (questId == 0 || questId > _questIdCounter) revert QuestNotFound();

        Quest memory quest = quests[questId];

        if (!quest.active) revert QuestNotActive();
        if (quest.deadline != 0 && block.timestamp > quest.deadline) revert QuestExpired();
        if (block.timestamp < quest.startTime) revert QuestNotStarted();
        if (userQuestProgress[msg.sender][questId].completed) revert AlreadyCompleted();
        if (quest.completionLimit > 0 && questGlobalCompletions[questId] >= quest.completionLimit) {
            revert CompletionLimitReached();
        }

        uint256 progress = _getProgress(msg.sender, quest);
        if (progress < quest.requirement) revert RequirementNotMet();

        // Effects
        userQuestProgress[msg.sender][questId] = UserQuestProgress({
            questId:         questId,
            currentProgress: progress,
            completed:       true,
            completedAt:     block.timestamp
        });

        userCompletedQuests[msg.sender].push(questId);
        questGlobalCompletions[questId]++;
        totalCompletionsAllTime++;

        // Award XP via LevelingSystem
        if (quest.xpReward > 0 && levelingContractAddress != address(0)) {
            try IXPHub(levelingContractAddress).awardXP(
                msg.sender,
                quest.xpReward,
                IXPHub.XPSource.QUEST
            ) {} catch {}
        }

        // Award POL via QuestRewardsPool
        uint256 polPaid;
        if (quest.polReward > 0 && address(questRewardsPool) != address(0)) {
            try questRewardsPool.requestPayout(msg.sender, quest.polReward, "quest_reward") {
                polPaid = quest.polReward;
            } catch {}
        }

        emit QuestCompleted(msg.sender, questId, quest.xpReward, polPaid);
    }

    // ============================================
    // REPORTER ACTIONS
    // ============================================

    /// @inheritdoc IQuestCore
    function notifyAction(address user, QuestType questType, uint256 value)
        external
        override
        onlyRole(REPORTER_ROLE)
    {
        if (user == address(0)) return;
        unchecked {
            actionCounters[user][uint8(questType)] += value;
        }
        emit ActionNotified(user, questType, value);
    }

    /// @inheritdoc IQuestCore
    function recordSocialAction(address user) external override onlyRole(ADMIN_ROLE) {
        unchecked {
            actionCounters[user][uint8(QuestType.SOCIAL)]++;
        }
        emit SocialActionRecorded(user, actionCounters[user][uint8(QuestType.SOCIAL)]);
    }

    // ============================================
    // INTERNAL PROGRESS CALCULATION
    // ============================================

    function _getProgress(address user, Quest memory quest) internal view returns (uint256) {
        QuestType qt = quest.questType;

        // Counter-based: value tracked internally via notifyAction()
        if (
            qt == QuestType.SOCIAL     ||
            qt == QuestType.STAKE      ||
            qt == QuestType.COMPOUND   ||
            qt == QuestType.AGENT_TASK
        ) {
            return actionCounters[user][uint8(qt)];
        }

        // Profile-based: read from LevelingSystem
        if (levelingContractAddress == address(0)) return 0;

        IXPHub.UserProfile memory profile =
            IXPHub(levelingContractAddress).getUserProfile(user);

        if (qt == QuestType.PURCHASE) return profile.nftsBought;
        if (qt == QuestType.CREATE)   return profile.nftsCreated;
        if (qt == QuestType.TRADING)  return profile.nftsSold;
        if (qt == QuestType.LEVEL_UP) return profile.level > MAX_LEVEL ? MAX_LEVEL : profile.level;

        return 0;
    }

    // ============================================
    // ADMIN SETTERS
    // ============================================

    /// @inheritdoc IQuestCore
    function setCoreContract(address coreAddress) external override onlyRole(ADMIN_ROLE) {
        if (coreAddress == address(0)) revert InvalidAddress();
        emit CoreContractUpdated(coreContractAddress, coreAddress);
        coreContractAddress = coreAddress;
    }

    /// @inheritdoc IQuestCore
    function setStakingContract(address stakingAddress) external override onlyRole(ADMIN_ROLE) {
        if (stakingAddress == address(0)) revert InvalidAddress();
        emit StakingContractUpdated(stakingContractAddress, stakingAddress);
        stakingContractAddress = stakingAddress;
    }

    /// @inheritdoc IQuestCore
    function setLevelingContract(address levelingAddress) external override onlyRole(ADMIN_ROLE) {
        if (levelingAddress == address(0)) revert InvalidAddress();
        emit LevelingContractUpdated(levelingContractAddress, levelingAddress);
        levelingContractAddress = levelingAddress;
    }

    function setQuestRewardsPool(address pool_) external onlyRole(ADMIN_ROLE) {
        emit QuestRewardsPoolUpdated(address(questRewardsPool), pool_);
        questRewardsPool = IQuestPoolCaller(pool_);
    }

    function pause()   external onlyRole(ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(ADMIN_ROLE) { _unpause(); }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @inheritdoc IQuestCore
    function getAllActiveQuests() external view override returns (Quest[] memory) {
        uint256 total = _questIdCounter;
        uint256 activeCount;
        for (uint256 i = 1; i <= total; i++) {
            if (quests[i].active) activeCount++;
        }
        Quest[] memory result = new Quest[](activeCount);
        uint256 idx;
        for (uint256 i = 1; i <= total; i++) {
            if (quests[i].active) result[idx++] = quests[i];
        }
        return result;
    }

    /// @inheritdoc IQuestCore
    function getQuestsByType(QuestType questType) external view override returns (Quest[] memory) {
        uint256 total = _questIdCounter;
        uint256 count;
        for (uint256 i = 1; i <= total; i++) {
            if (quests[i].active && quests[i].questType == questType) count++;
        }
        Quest[] memory result = new Quest[](count);
        uint256 idx;
        for (uint256 i = 1; i <= total; i++) {
            if (quests[i].active && quests[i].questType == questType) result[idx++] = quests[i];
        }
        return result;
    }

    /// @inheritdoc IQuestCore
    function getQuestsByCategory(QuestCategory category) external view override returns (Quest[] memory) {
        uint256 total = _questIdCounter;
        uint256 count;
        for (uint256 i = 1; i <= total; i++) {
            if (quests[i].active && quests[i].category == category) count++;
        }
        Quest[] memory result = new Quest[](count);
        uint256 idx;
        for (uint256 i = 1; i <= total; i++) {
            if (quests[i].active && quests[i].category == category) result[idx++] = quests[i];
        }
        return result;
    }

    /// @inheritdoc IQuestCore
    function getQuest(uint256 questId) external view override returns (Quest memory) {
        if (questId == 0 || questId > _questIdCounter) revert QuestNotFound();
        return quests[questId];
    }

    /// @inheritdoc IQuestCore
    function getUserQuestProgress(address user, uint256 questId)
        external view override returns (UserQuestProgress memory)
    {
        return userQuestProgress[user][questId];
    }

    /// @inheritdoc IQuestCore
    function getUserCompletedQuests(address user) external view override returns (uint256[] memory) {
        return userCompletedQuests[user];
    }

    /// @inheritdoc IQuestCore
    function getUserSocialActions(address user) external view override returns (uint256) {
        return actionCounters[user][uint8(QuestType.SOCIAL)];
    }

    /// @inheritdoc IQuestCore
    function getQuestSystemStats() external view override returns (
        uint256 totalQuests,
        uint256 activeQuests,
        uint256 totalCompletions,
        uint256 totalXPAwarded,
        uint256 averageCompletionRate
    ) {
        totalQuests = _questIdCounter;
        for (uint256 i = 1; i <= totalQuests; i++) {
            if (quests[i].active) activeQuests++;
            totalXPAwarded += quests[i].xpReward;
        }
        totalCompletions     = totalCompletionsAllTime;
        averageCompletionRate = totalQuests > 0 ? (totalCompletions * 100) / totalQuests : 0;
    }

    /// @inheritdoc IQuestCore
    function getUserQuestStats(address user) external view override returns (
        uint256 totalCompleted,
        uint256 totalInProgress,
        uint256 totalXPEarned,
        uint256 completionRate,
        QuestType favoriteType
    ) {
        totalCompleted = userCompletedQuests[user].length;
        uint256 total  = _questIdCounter;
        for (uint256 i = 1; i <= total; i++) {
            UserQuestProgress memory prog = userQuestProgress[user][i];
            if (prog.completed) {
                totalXPEarned += quests[i].xpReward;
            } else if (prog.currentProgress > 0) {
                totalInProgress++;
            }
        }
        completionRate = total > 0 ? (totalCompleted * 100) / total : 0;
        favoriteType   = QuestType.PURCHASE; // expandable with tracking
    }

    /// @inheritdoc IQuestCore
    function getUserIncompleteQuests(address user) external view override returns (
        uint256[] memory questIds,
        Quest[]   memory questData,
        uint256[] memory progressPercentages
    ) {
        uint256 total = _questIdCounter;
        uint256 count;
        for (uint256 i = 1; i <= total; i++) {
            if (quests[i].active && !userQuestProgress[user][i].completed) count++;
        }
        questIds            = new uint256[](count);
        questData           = new Quest[](count);
        progressPercentages = new uint256[](count);
        uint256 idx;
        for (uint256 i = 1; i <= total; i++) {
            if (quests[i].active && !userQuestProgress[user][i].completed) {
                questIds[idx]  = i;
                questData[idx] = quests[i];
                uint256 current  = userQuestProgress[user][i].currentProgress;
                uint256 required = quests[i].requirement;
                progressPercentages[idx] = required > 0 ? (current * 100) / required : 0;
                idx++;
            }
        }
    }
}
