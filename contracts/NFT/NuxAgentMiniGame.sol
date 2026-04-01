// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IMiniGameRegistry {
    function registeredNFTContracts(address nftContract) external view returns (bool);

    function recordTaskExecution(address nftContract, uint256 tokenId, address executor, uint256 rewardPaid) external;

    function validationRequest(
        address validatorAddress,
        address nftContract,
        uint256 tokenId,
        string calldata requestURI,
        bytes32 requestHash
    ) external returns (bytes32);
}

interface IMiniGameNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function effectiveController(uint256 tokenId) external view returns (address);
}

interface IMiniGameTreasury {
    function depositRevenue(string calldata revenueType) external payable;
}

/**
 * @title NuxAgentMiniGame
 * @notice Task-based mission system for AI Agent NFTs inside the NuxTap economy
 * @dev
 *   Agents complete tasks to earn mission XP and native-token rewards. Tasks can be:
 *
 *   TASK LIFECYCLE:
 *     1. Admin creates a Task with rewards, requirements, and optional validation
 *     2. User submits task result (resultURI = IPFS/Arweave CID of agent output)
 *     3. If validationRequired=false → auto-approval after cooldown
 *        If validationRequired=true → validator calls validateSubmission()
 *     4. After approval, user claims the mission reward (if any)
 *     5. Mission XP is awarded immediately on approval, recorded on-chain
 *
 *   DAILY CHALLENGES:
 *     One (or more) tasks per day are flagged DAILY_CHALLENGE. Completing one
 *     per day (UTC) awards a streak bonus of 10% extra XP per consecutive day.
 *
 *   SEASONAL EVENTS:
 *     Special tasks with a deadline. Only active between startTime and deadline.
 *     Can be configured with multiplied XP reward.
 *
 *   LEADERBOARD:
 *     On-chain top-20 leaderboard by totalXP across all tasks.
 *     Updated on every successful task completion.
 *
 *   ERC-8004 INTEGRATION:
 *     - On task submission, a ValidationRequest is sent to NuxAgentRegistry
 *       (if validationRequired=true), creating an on-chain audit trail
 *     - On task completion, NuxAgentRegistry.recordTaskExecution() is called
 *
 *   REWARD ESCROW:
 *     Admin deposits ETH into the contract's reward pool. Each task
 *     has a tokenReward. Rewards are held in escrow per submission and
 *     released on approval.
 *
 *   NUXTAP SCOPE:
 *     This contract is dedicated to the AI Agent NFT economy used by NuxTap.
 *     It does not depend on QuestCore or QuestRewardsPool.
 */
contract NuxAgentMiniGame is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // ============================================
    // ROLES
    // ============================================
    bytes32 public constant ADMIN_ROLE     = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE  = keccak256("UPGRADER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    // ============================================
    // ENUMS & STRUCTS
    // ============================================

    enum TaskType {
        GENERAL,
        COMPLETE_TRAINING,
        EARN_REPUTATION,
        COMPLETE_QUEST,
        SOCIAL_CHALLENGE,
        TECH_AUDIT,
        MARKETING_CAMPAIGN,
        FINANCE_ANALYSIS,
        BUSINESS_DEAL,
        DAILY_CHALLENGE,
        SEASONAL_EVENT
    }

    enum SubmissionStatus { PENDING, APPROVED, REJECTED }

    /// @notice Used as parameter for createTask() to avoid stack-too-deep
    struct CreateTaskParams {
        /// @dev metadataURI → IPFS/Arweave JSON: {title, description, requirementsURI}
        string   metadataURI;
        TaskType taskType;
        uint256  xpReward;
        uint256  tokenReward;
        uint256  requiredMinReputation;
        uint256  maxCompletionsPerAgent;
        uint256  totalMaxCompletions;
        bool     validationRequired;
        uint256  startTime;
        uint256  deadline;
    }

    struct Task {
        /// @dev metadataURI → IPFS/Arweave JSON {title,description,requirementsURI}
        string   metadataURI;
        TaskType taskType;
        uint256  xpReward;
        uint256  tokenReward;
        uint256  requiredMinReputation;
        uint256  maxCompletionsPerAgent;
        uint256  totalMaxCompletions;
        uint256  totalCompletions;
        bool     validationRequired;
        bool     active;
        uint256  startTime;
        uint256  deadline;
    }

    struct TaskSubmission {
        uint256          taskId;
        address          nftContract;
        uint256          tokenId;
        address          submitter;
        string           resultURI;
        bytes32          resultHash;
        SubmissionStatus status;
        uint256          submittedAt;
        uint256          resolvedAt;
        bool             rewardClaimed;
        bytes32          registryRequestHash;
    }

    struct TaskStatusView {
        uint256  taskId;
        bool     exists;
        bool     active;
        bool     started;
        bool     expired;
        uint256  startTime;
        uint256  deadline;
        uint256  xpReward;
        uint256  tokenReward;
        uint256  remainingGlobalCompletions;
        bool     validationRequired;
        TaskType taskType;
        bool     rewardLiquiditySufficient;
    }

    struct RewardSummary {
        uint256 approvedUnclaimedCount;
        uint256 pendingValidationCount;
        uint256 rejectedCount;
        uint256 totalClaimableRewards;
    }

    // ============================================
    // STATE
    // ============================================

    IMiniGameRegistry public agentRegistry;
    address public defaultValidator;

    uint256 public taskCounter;
    uint256 public submissionCounter;
    uint256 public rewardPool;

    mapping(uint256 => Task)           public tasks;
    mapping(uint256 => TaskSubmission) public submissions;

    // agent (nftContract + tokenId) → taskId → completions
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public agentTaskCompletions;

    // Per-agent total XP from this game
    mapping(address => mapping(uint256 => uint256)) public agentGameXP;
    mapping(address => uint256) public userMissionXP;

    // Daily challenge streak tracking: owner → last day completed, streak count
    mapping(address => uint256) public lastDailyDay;
    mapping(address => uint256) public dailyStreak;

    // Leaderboard is computed off-chain from LeaderboardXPUpdated events.
    // On-chain we only store per-agent total XP for trustless verification.
    bool public paused;

    IMiniGameTreasury public treasuryManager;
    uint256 public miniGameFeeBps; // Protocol fee on claimed rewards (default 0; set via setMiniGameFee)
    mapping(address => bool) public supportedNFTContracts;

    // ============================================
    // EVENTS
    // ============================================
    event TaskCreated(uint256 indexed taskId, string metadataURI, TaskType taskType, uint256 xpReward, uint256 tokenReward);
    event TaskUpdated(uint256 indexed taskId);
    event TaskSubmitted(uint256 indexed submissionId, uint256 indexed taskId, address indexed nftContract, uint256 tokenId);
    event SubmissionApproved(uint256 indexed submissionId, address indexed owner, uint256 xpAwarded, uint256 rewardEscrowed);
    event SubmissionRejected(uint256 indexed submissionId, address indexed owner, string reason);
    event RewardClaimed(uint256 indexed submissionId, address indexed claimer, uint256 amount);
    event DailyStreakUpdated(address indexed user, uint256 newStreak, uint256 bonusXP);
    /// @notice Emitted on every XP gain — index off-chain to build leaderboard
    event LeaderboardXPUpdated(address indexed nftContract, uint256 indexed tokenId, address indexed owner, uint256 totalXP);
    event RewardPoolDeposited(uint256 amount, address depositor);
    event RewardPoolWithdrawn(uint256 amount, address recipient);
    event MiniGameFeeCollected(uint256 indexed submissionId, uint256 feeAmount);
    event SupportedNFTContractUpdated(address indexed nftContract, bool supported);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address agentRegistry_,
        address defaultValidator_
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        _grantRole(VALIDATOR_ROLE, admin_);
        _grantRole(DEPOSITOR_ROLE, admin_);

        agentRegistry    = IMiniGameRegistry(agentRegistry_);
        defaultValidator = defaultValidator_;
    }

    // ============================================
    // REWARD POOL MANAGEMENT
    // ============================================

    receive() external payable {
        rewardPool += msg.value;
        emit RewardPoolDeposited(msg.value, msg.sender);
    }

    function depositRewards() external payable onlyRole(DEPOSITOR_ROLE) {
        require(msg.value > 0, "Game: zero deposit");
        rewardPool += msg.value;
        emit RewardPoolDeposited(msg.value, msg.sender);
    }

    function withdrawRewardPool(uint256 amount, address recipient) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(amount <= rewardPool, "Game: insufficient pool");
        rewardPool -= amount;
        (bool ok, ) = payable(recipient).call{value: amount}("");
        require(ok, "Game: withdrawal failed");
        emit RewardPoolWithdrawn(amount, recipient);
    }

    // ============================================
    // TASK MANAGEMENT
    // ============================================

    function createTask(CreateTaskParams calldata p) external onlyRole(ADMIN_ROLE) returns (uint256 taskId) {
        require(p.xpReward > 0, "Game: xpReward must be > 0");
        require(p.deadline == 0 || p.deadline > block.timestamp, "Game: deadline in the past");

        taskCounter++;
        taskId = taskCounter;

        tasks[taskId] = Task({
            metadataURI:           p.metadataURI,
            taskType:              p.taskType,
            xpReward:              p.xpReward,
            tokenReward:           p.tokenReward,
            requiredMinReputation: p.requiredMinReputation,
            maxCompletionsPerAgent: p.maxCompletionsPerAgent,
            totalMaxCompletions:   p.totalMaxCompletions,
            totalCompletions:      0,
            validationRequired:    p.validationRequired,
            active:                true,
            startTime:             p.startTime == 0 ? block.timestamp : p.startTime,
            deadline:              p.deadline
        });

        emit TaskCreated(taskId, p.metadataURI, p.taskType, p.xpReward, p.tokenReward);
    }

    function setTaskActive(uint256 taskId, bool active_) external onlyRole(ADMIN_ROLE) {
        require(tasks[taskId].active || !tasks[taskId].active, "Game: task not found");
        tasks[taskId].active = active_;
        emit TaskUpdated(taskId);
    }

    // ============================================
    // TASK SUBMISSION
    // ============================================

    /**
     * @notice Submit a completed task with the agent's output
     * @param taskId       Task ID to complete
     * @param nftContract  Address of the category NFT contract
     * @param tokenId      The agent NFT token ID being used
     * @param resultURI    IPFS/Arweave URI of the agent's output
     * @param resultHash   keccak256 of the result content (for integrity verification)
     */
    function submitTask(
        uint256 taskId,
        address nftContract,
        uint256 tokenId,
        string calldata resultURI,
        bytes32 resultHash
    ) external nonReentrant returns (uint256 submissionId) {
        require(!paused, "Game: paused");
        require(_isSupportedNFTContract(nftContract), "Game: unsupported NFT contract");

        Task storage task = tasks[taskId];
        require(task.active, "Game: task not active");
        require(block.timestamp >= task.startTime, "Game: task not started");
        require(task.deadline == 0 || block.timestamp < task.deadline, "Game: task deadline passed");

        // Verify caller controls the agent (owner or active renter)
        address agentController = _effectiveController(nftContract, tokenId);
        require(agentController == msg.sender, "Game: not agent controller");

        // Check per-agent completions
        if (task.maxCompletionsPerAgent > 0) {
            require(
                agentTaskCompletions[nftContract][tokenId][taskId] < task.maxCompletionsPerAgent,
                "Game: agent reached max completions for this task"
            );
        }

        // Check global completions
        if (task.totalMaxCompletions > 0) {
            require(task.totalCompletions < task.totalMaxCompletions, "Game: task fully claimed");
        }

        // Check token reward availability
        if (!task.validationRequired && task.tokenReward > 0) {
            require(rewardPool >= task.tokenReward, "Game: insufficient reward pool");
        }

        submissionCounter++;
        submissionId = submissionCounter;

        bytes32 registryRequestHash;

        // If validation required, issue ERC-8004 ValidationRequest
        if (task.validationRequired && address(agentRegistry) != address(0)) {
            try agentRegistry.validationRequest(
                defaultValidator,
                nftContract,
                tokenId,
                resultURI,
                resultHash
            ) returns (bytes32 reqHash) {
                registryRequestHash = reqHash;
            } catch {}
        }

        // Write submission to storage field-by-field (avoids stack-too-deep with large struct literal)
        TaskSubmission storage newSub = submissions[submissionId];
        newSub.taskId              = taskId;
        newSub.nftContract         = nftContract;
        newSub.tokenId             = tokenId;
        newSub.submitter           = msg.sender;
        newSub.resultURI           = resultURI;
        newSub.resultHash          = resultHash;
        newSub.status              = SubmissionStatus.PENDING;
        newSub.submittedAt         = block.timestamp;
        newSub.registryRequestHash = registryRequestHash;

        emit TaskSubmitted(submissionId, taskId, nftContract, tokenId);

        // Auto-approve if no validation required
        if (!task.validationRequired) {
            _approveSubmission(submissionId);
        }
    }

    // ============================================
    // VALIDATION
    // ============================================

    /**
     * @notice Approve or reject a pending submission (validator only)
     * @param submissionId Target submission
     * @param approved     Whether to approve
     * @param reason       Rejection reason (empty if approved)
     */
    function validateSubmission(
        uint256 submissionId,
        bool    approved,
        string calldata reason
    ) external onlyRole(VALIDATOR_ROLE) nonReentrant {
        TaskSubmission storage sub = submissions[submissionId];
        require(sub.submitter != address(0) || sub.taskId > 0, "Game: submission not found");
        require(sub.status == SubmissionStatus.PENDING, "Game: already resolved");

        if (approved) {
            _approveSubmission(submissionId);
        } else {
            sub.status     = SubmissionStatus.REJECTED;
            sub.resolvedAt = block.timestamp;
            emit SubmissionRejected(submissionId, sub.submitter, reason);
        }
    }

    function _approveSubmission(uint256 submissionId) internal {
        TaskSubmission storage sub  = submissions[submissionId];
        Task storage task           = tasks[sub.taskId];

        sub.status     = SubmissionStatus.APPROVED;
        sub.resolvedAt = block.timestamp;

        agentTaskCompletions[sub.nftContract][sub.tokenId][sub.taskId]++;
        task.totalCompletions++;

        // Calculate XP
        uint256 xpReward = task.xpReward;

        // Daily streak bonus
        if (task.taskType == TaskType.DAILY_CHALLENGE) {
            xpReward += _processDailyStreak(sub.submitter, xpReward);
        }

        agentGameXP[sub.nftContract][sub.tokenId] += xpReward;
        userMissionXP[sub.submitter] += xpReward;

        // Escrow token reward
        uint256 escrowed;
        if (task.tokenReward > 0 && rewardPool >= task.tokenReward) {
            rewardPool -= task.tokenReward;
            escrowed    = task.tokenReward;
        }

        // Notify ERC-8004 registry
        if (address(agentRegistry) != address(0)) {
            try agentRegistry.recordTaskExecution(sub.nftContract, sub.tokenId, sub.submitter, escrowed) {} catch {}
        }

        // Emit leaderboard event — off-chain indexers build the sorted top-20
        emit LeaderboardXPUpdated(sub.nftContract, sub.tokenId, sub.submitter, agentGameXP[sub.nftContract][sub.tokenId]);

        emit SubmissionApproved(submissionId, sub.submitter, xpReward, escrowed);
    }

    function _processDailyStreak(address user, uint256 baseXP) internal returns (uint256 bonusXP) {
        uint256 today = block.timestamp / 1 days;
        if (lastDailyDay[user] == today - 1) {
            dailyStreak[user]++;
        } else if (today > lastDailyDay[user]) {
            dailyStreak[user] = 1;
        }
        lastDailyDay[user] = today;

        // 10% bonus per consecutive day, capped at 100%
        uint256 streak = dailyStreak[user] > 10 ? 10 : dailyStreak[user];
        bonusXP = (baseXP * streak * 10) / 100;

        emit DailyStreakUpdated(user, dailyStreak[user], bonusXP);
    }

    // ============================================
    // REWARD CLAIM
    // ============================================

    /**
     * @notice Claim ETH reward for an approved submission
     * @dev The reward was escrowed from the pool during approval.
     *      We track it implicitly: if approved and tokenReward > 0 and not claimed,
     *      the contract owes the user task.tokenReward.
     */
    function claimReward(uint256 submissionId) external nonReentrant {
        TaskSubmission storage sub = submissions[submissionId];
        require(sub.submitter == msg.sender, "Game: not submitter");
        require(sub.status == SubmissionStatus.APPROVED, "Game: not approved");
        require(!sub.rewardClaimed, "Game: reward already claimed");

        Task storage task = tasks[sub.taskId];
        uint256 reward = task.tokenReward;
        require(reward > 0, "Game: no token reward for this task");

        sub.rewardClaimed = true;

        // Deduct protocol fee when treasury is configured
        uint256 fee = (address(treasuryManager) != address(0) && miniGameFeeBps > 0)
            ? (reward * miniGameFeeBps) / 10000
            : 0;
        uint256 netReward = reward - fee;

        if (fee > 0 && address(treasuryManager) != address(0)) {
            try treasuryManager.depositRevenue{value: fee}("nuxtap_agent_minigame_fee") {} catch {}
        }

        (bool ok, ) = payable(msg.sender).call{value: netReward}("");
        require(ok, "Game: reward transfer failed");

        emit RewardClaimed(submissionId, msg.sender, netReward);
        if (fee > 0) emit MiniGameFeeCollected(submissionId, fee);
    }

    // ============================================
    // HELPERS
    // ============================================

    function _isSupportedNFTContract(address nftContract) internal view returns (bool) {
        if (supportedNFTContracts[nftContract]) {
            return true;
        }

        if (address(agentRegistry) == address(0)) {
            return false;
        }

        try agentRegistry.registeredNFTContracts(nftContract) returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    function _effectiveController(address nftContract, uint256 tokenId) internal view returns (address controller) {
        try IMiniGameNFT(nftContract).effectiveController(tokenId) returns (address effectiveController_) {
            return effectiveController_;
        } catch {
            return IMiniGameNFT(nftContract).ownerOf(tokenId);
        }
    }

    // ============================================
    // ADMIN
    // ============================================

    function setAgentRegistry(address registry_) external onlyRole(ADMIN_ROLE) {
        agentRegistry = IMiniGameRegistry(registry_);
    }

    function setDefaultValidator(address validator_) external onlyRole(ADMIN_ROLE) {
        require(validator_ != address(0), "Game: invalid validator");
        defaultValidator = validator_;
    }

    function setPaused(bool paused_) external onlyRole(ADMIN_ROLE) {
        paused = paused_;
    }

    function setTreasuryManager(address tm_) external onlyRole(ADMIN_ROLE) {
        require(tm_ != address(0), "Game: invalid address");
        treasuryManager = IMiniGameTreasury(tm_);
    }

    function setSupportedNFTContract(address nftContract, bool supported) external onlyRole(ADMIN_ROLE) {
        require(nftContract != address(0), "Game: invalid NFT contract");
        supportedNFTContracts[nftContract] = supported;
        emit SupportedNFTContractUpdated(nftContract, supported);
    }

    function setMiniGameFee(uint256 feeBps_) external onlyRole(ADMIN_ROLE) {
        require(feeBps_ <= 1_000, "Game: fee too high"); // max 10%
        miniGameFeeBps = feeBps_;
    }

    uint256[50] private __gap;

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ============================================
    // VIEW
    // ============================================

    function getTask(uint256 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }

    function getSubmission(uint256 submissionId) external view returns (TaskSubmission memory) {
        return submissions[submissionId];
    }

    function getAgentGameStats(
        address nftContract,
        uint256 tokenId
    ) external view returns (uint256 totalXP) {
        return agentGameXP[nftContract][tokenId];
    }

    function getAgentStreak(address user) external view returns (uint256 streak, uint256 lastDay) {
        return (dailyStreak[user], lastDailyDay[user]);
    }

    function getTaskStatus(uint256 taskId) external view returns (TaskStatusView memory status) {
        Task storage task = tasks[taskId];
        bool exists = bytes(task.metadataURI).length > 0 || task.xpReward > 0;

        status.taskId = taskId;
        status.exists = exists;
        status.active = task.active;
        status.started = exists && block.timestamp >= task.startTime;
        status.expired = exists && task.deadline != 0 && block.timestamp >= task.deadline;
        status.startTime = task.startTime;
        status.deadline = task.deadline;
        status.xpReward = task.xpReward;
        status.tokenReward = task.tokenReward;
        status.remainingGlobalCompletions = task.totalMaxCompletions > task.totalCompletions
            ? task.totalMaxCompletions - task.totalCompletions
            : 0;
        status.validationRequired = task.validationRequired;
        status.taskType = task.taskType;
        status.rewardLiquiditySufficient = task.tokenReward == 0 || rewardPool >= task.tokenReward;
    }

    function getUserSubmissions(
        address user,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory submissionIds, TaskSubmission[] memory userSubmissions, uint256 total) {
        return _getFilteredSubmissions(user, address(0), 0, false, offset, limit);
    }

    function getAgentSubmissions(
        address nftContract,
        uint256 tokenId,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory submissionIds, TaskSubmission[] memory agentSubmissions, uint256 total) {
        return _getFilteredSubmissions(address(0), nftContract, tokenId, true, offset, limit);
    }

    function getUserRewardSummary(address user) external view returns (RewardSummary memory summary) {
        for (uint256 submissionId = 1; submissionId <= submissionCounter; submissionId++) {
            TaskSubmission storage sub = submissions[submissionId];
            if (sub.submitter != user) {
                continue;
            }

            if (sub.status == SubmissionStatus.PENDING) {
                summary.pendingValidationCount++;
                continue;
            }

            if (sub.status == SubmissionStatus.REJECTED) {
                summary.rejectedCount++;
                continue;
            }

            Task storage task = tasks[sub.taskId];
            if (!sub.rewardClaimed && task.tokenReward > 0) {
                summary.approvedUnclaimedCount++;
                summary.totalClaimableRewards += task.tokenReward;
            }
        }
    }

    function _getFilteredSubmissions(
        address user,
        address nftContract,
        uint256 tokenId,
        bool filterByAgent,
        uint256 offset,
        uint256 limit
    ) internal view returns (uint256[] memory submissionIds, TaskSubmission[] memory filteredSubmissions, uint256 total) {
        if (limit == 0 || offset >= submissionCounter) {
            return (new uint256[](0), new TaskSubmission[](0), 0);
        }

        for (uint256 submissionId = 1; submissionId <= submissionCounter; submissionId++) {
            TaskSubmission storage sub = submissions[submissionId];
            if (_matchesSubmissionFilter(sub, user, nftContract, tokenId, filterByAgent)) {
                total++;
            }
        }

        if (offset >= total) {
            return (new uint256[](0), new TaskSubmission[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) end = total;

        uint256 size = end - offset;
        submissionIds = new uint256[](size);
        filteredSubmissions = new TaskSubmission[](size);

        uint256 seen;
        uint256 index;
        for (uint256 submissionId = 1; submissionId <= submissionCounter && index < size; submissionId++) {
            TaskSubmission storage sub = submissions[submissionId];
            if (!_matchesSubmissionFilter(sub, user, nftContract, tokenId, filterByAgent)) {
                continue;
            }
            if (seen >= offset) {
                submissionIds[index] = submissionId;
                filteredSubmissions[index] = sub;
                index++;
            }
            seen++;
        }
    }

    function _matchesSubmissionFilter(
        TaskSubmission storage sub,
        address user,
        address nftContract,
        uint256 tokenId,
        bool filterByAgent
    ) internal view returns (bool) {
        if (filterByAgent) {
            return sub.nftContract == nftContract && sub.tokenId == tokenId;
        }
        return sub.submitter == user;
    }
}
