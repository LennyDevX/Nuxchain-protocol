// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISmartStakingGamification.sol";
import "../interfaces/ITreasuryManager.sol";
import "../interfaces/IStakingIntegration.sol";
import "../interfaces/IXPHub.sol";

/// @custom:version 2.0.0
contract Gamification is Ownable, ReentrancyGuard, ISmartStakingGamification {

    // ── Custom errors ─────────────────────────────────────────────────
    error NotAuthorized();
    error OnlyCore();
    error InvalidAddress();
    error InvalidParam();
    error AlreadyDone();
    error NoReward();
    error InsufficientBalance();
    error TransferFailed();
    error BatchSizeInvalid();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Auto-compound minimum check interval (24 h)
    uint256 private constant AUTO_COMPOUND_INTERVAL = 1 days;

    /// @notice Minimum ETH a user can set as auto-compound trigger (0.01 ETH)
    uint256 private constant MIN_COMPOUND_AMOUNT = 0.01 ether;

    /// @notice Maximum users processed in a single batch operation (out-of-gas guard)
    uint256 private constant BATCH_LIMIT = 100;

    /// @notice Basis points denominator (10 000 = 100%)
    uint256 private constant BASIS_POINTS = 10_000;

    /// @notice Maximum global XP multiplier admin can set (3x during events)
    uint256 private constant MAX_XP_MULTIPLIER = 30_000; // 3x in basis points

    // ────────────────────────────────────────────────────────────────
    // XP rewards — reduced for platform stability
    // ────────────────────────────────────────────────────────────────

    uint256 private constant STAKING_XP_DIVISOR = 2;   // 1 XP per 2 POL
    uint256 private constant COMPOUND_XP        = 3;   // fixed XP per compound
    uint256 private constant MIN_QUEST_XP       = 10;  // dynamic range floor
    uint256 private constant MAX_QUEST_XP       = 25;  // dynamic range ceiling
    uint256 private constant ACHIEVEMENT_XP     = 100; // fixed XP per achievement

    uint16 private constant MAX_LEVEL = 250;
    uint16 private constant LEVELS_PER_BRACKET = 25;
    uint16 private constant BRACKET_COUNT = 10;
    uint256 private constant XP_PER_BRACKET_STEP = 50;
    uint256 private constant MAX_XP_TOTAL = 68_750;
    uint256 private constant MIN_LEVEL_REWARD = 0.05 ether;
    uint256 private constant MAX_LEVEL_REWARD = 0.5 ether;
    uint256 private constant LEVEL_REWARD_STEP = 0.05 ether;

    // ────────────────────────────────────────────────────────────────
    // Streak bonuses (applied as XP multipliers in basis points)
    // ────────────────────────────────────────────────────────────────

    uint256 private constant STREAK_7_MULT  = 11_000; // 1.1x  (7+ consecutive days)
    uint256 private constant STREAK_14_MULT = 12_500; // 1.25x (14+ consecutive days)
    uint256 private constant STREAK_21_MULT = 15_000; // 1.5x  (21+ consecutive days)
    uint256 private constant STREAK_30_MULT = 20_000; // 2.0x  (30+ consecutive days)

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    struct Badge {
        uint256 id;
        string  name;
        string  description;
        uint256 dateEarned;
    }

    struct StreakData {
        uint32  current;       // consecutive active days
        uint32  longest;       // all-time best streak
        uint40  lastActivityDay; // block.timestamp / 1 days on last action
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ════════════════════════════════════════════════════════════════════════════════════════

    // ── Module addresses ──────────────────────────────────────────────
    address                public marketplaceContract;
    address                public coreStakingContract;
    address                public levelingSystemAddress;
    ITreasuryManager       public treasuryManager;

    // ── XP multipliers ────────────────────────────────────────────────
    /// @notice Admin-settable global multiplier in basis points (default 10 000 = 1x)
    uint256 public globalXpMultiplier = BASIS_POINTS;

    /// @notice Season bonus multiplier — overrides globalXpMultiplier while active
    uint256 public seasonMultiplier;
    /// @notice UTC timestamp when the current season ends (0 = no active season)
    uint256 public seasonEndTime;
    /// @notice Human-readable name of the active season
    string  public seasonName;

    // ── Quest & Achievement reward storage ────────────────────────────
    mapping(address => mapping(uint256 => QuestReward))       private _questRewards;
    mapping(address => mapping(uint256 => AchievementReward)) private _achievementRewards;
    mapping(address => uint256[])                             private _userQuestIds;
    mapping(address => uint256[])                             private _userAchievementIds;

    // ── Auto-compound state ───────────────────────────────────────────
    mapping(address => AutoCompoundConfig) private _autoCompoundConfigs;
    address[]                             private _autoCompoundUsers;
    mapping(address => uint256)           private _autoCompoundIndex;
    mapping(address => bool)              private _isInAutoCompoundList;

    // ── Badge state ───────────────────────────────────────────────────
    mapping(address => Badge[])                      private _userBadges;
    mapping(address => mapping(bytes32 => bool))     private _userHasBadge;

    // ── Streak state ──────────────────────────────────────────────────
    mapping(address => StreakData) private _streaks;

    // ── Local XP fallback (used when LevelingSystem not set) ──────────
    mapping(address => uint256) private _localXP;

    // ── Level-up reward state ─────────────────────────────────────────
    uint256 public  totalPendingRewards;
    mapping(address => uint256) public deferredRewardAmount;
    mapping(address => uint256) public deferredRewardTime;

    // ── Protocol health state ─────────────────────────────────────────
    ITreasuryManager.ProtocolStatus private _protocolHealth;
    uint256                         private _lastHealthCheckTime;
    uint256 private constant MIN_HEALTHY_RESERVE = 5 ether;
    uint256 private constant UNSTABLE_THRESHOLD  = 10 ether;

    // ── Protocol statistics ───────────────────────────────────────────
    uint256 public statTotalXPDistributed;
    uint256 public statTotalRewardsPaid;
    uint32  public statTotalLevelUps;
    uint32  public statTotalQuests;
    uint32  public statTotalAchievements;

    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    // Inherited from ISmartStakingGamification:
    //   XPUpdated, QuestCompleted, AchievementUnlocked, RewardExpired
    //   AutoCompoundEnabled, AutoCompoundDisabled, AutoCompoundExecuted

    event LevelUp(address indexed user, uint8 newLevel);
    event RewardPaid(address indexed user, uint256 amount);
    event RewardDeferred(address indexed user, uint8 level, uint256 amount, string reason);
    event DeferredRewardClaimed(address indexed user, uint256 amount);
    event BadgeEarned(address indexed user, uint256 badgeId, string name);
    event StreakUpdated(address indexed user, uint32 streak, uint256 multiplier);
    event SeasonStarted(string name, uint256 multiplier, uint256 endTime);
    event SeasonEnded(string name);
    event GlobalMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
    event TreasuryManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event ProtocolHealthStatusChanged(ITreasuryManager.ProtocolStatus newStatus, uint256 timestamp, string reason);
    event CriticalRewardDeficit(address indexed user, uint256 rewardAmount, uint256 totalPending, uint256 contractBalance);
    event HealthCheckPerformed(uint256 contractBalance, uint256 totalPending, ITreasuryManager.ProtocolStatus status, bool emergencyFundsRequested);
    event TreasuryNotificationSent(string alertType, uint256 deficit, uint256 timestamp);
    event EmergencyWithdraw(address indexed to, uint256 amount);

    // ════════════════════════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ════════════════════════════════════════════════════════════════════════════════════════

    modifier onlyCore() {
        if (msg.sender != coreStakingContract) revert OnlyCore();
        _;
    }

    modifier onlyAuthorized() {
        if (
            msg.sender != marketplaceContract &&
            msg.sender != coreStakingContract  &&
            msg.sender != owner()
        ) revert NotAuthorized();
        _;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════

    constructor() {}

    receive() external payable {}

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    function setMarketplaceContract(address _marketplace) external onlyOwner {
        if (_marketplace == address(0)) revert InvalidAddress();
        marketplaceContract = _marketplace;
    }

    function setCoreStakingContract(address _coreStaking) external onlyOwner {
        if (_coreStaking == address(0)) revert InvalidAddress();
        coreStakingContract = _coreStaking;
    }

    function setLevelingSystemAddress(address _levelingSystem) external onlyOwner {
        if (_levelingSystem == address(0)) revert InvalidAddress();
        levelingSystemAddress = _levelingSystem;
    }

    function setTreasuryManager(address _treasuryManager) external onlyOwner {
        if (_treasuryManager == address(0)) revert InvalidAddress();
        address oldAddress = address(treasuryManager);
        treasuryManager = ITreasuryManager(_treasuryManager);
        emit TreasuryManagerUpdated(oldAddress, _treasuryManager);
    }

    /**
     * @notice Set the global XP multiplier applied to all XP awards protocol-wide.
     * @param multiplier  Multiplier in basis points. 10000 = 1x, 20000 = 2x. Max 30000 (3x).
     */
    function setGlobalXpMultiplier(uint256 multiplier) external onlyOwner {
        if (multiplier < BASIS_POINTS || multiplier > MAX_XP_MULTIPLIER) revert InvalidParam();
        uint256 old = globalXpMultiplier;
        globalXpMultiplier = multiplier;
        emit GlobalMultiplierUpdated(old, multiplier);
    }

    /**
     * @notice Activate a timed season that overrides the base XP multiplier.
     * @param name        Human-readable season name (e.g. "Summer 2026").
     * @param multiplier  Bonus multiplier in basis points applied during the season.
     * @param durationDays  Length of the season in days.
     */
    function startSeason(string calldata name, uint256 multiplier, uint256 durationDays) external onlyOwner {
        if (multiplier < BASIS_POINTS || multiplier > MAX_XP_MULTIPLIER) revert InvalidParam();
        if (durationDays == 0 || durationDays > 365) revert InvalidParam();
        seasonName       = name;
        seasonMultiplier = multiplier;
        seasonEndTime    = block.timestamp + (durationDays * 1 days);
        emit SeasonStarted(name, multiplier, seasonEndTime);
    }

    /**
     * @notice Manually end the active season before its scheduled end time.
     */
    function endSeason() external onlyOwner {
        emit SeasonEnded(seasonName);
        seasonMultiplier = 0;
        seasonEndTime    = 0;
        seasonName       = "";
    }

    /**
     * @notice Award a badge to a user (manual, admin-triggered).
     */
    function awardBadge(address user, uint256 id, string memory name, string memory description) external onlyAuthorized {
        _awardBadgeInternal(user, id, name, description);
    }

    /**
     * @notice Emergency withdraw — recover stuck ETH.  Only usable when contract is fully funded.
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert InvalidAddress();
        if (amount > address(this).balance) revert InsufficientBalance();
        if (address(this).balance - amount < totalPendingRewards) revert InsufficientBalance();
        (bool success,) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit EmergencyWithdraw(to, amount);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // PROTOCOL HEALTH
    // ════════════════════════════════════════════════════════════════════════════════════════

    function getProtocolHealth() external view override returns (
        ITreasuryManager.ProtocolStatus status,
        uint256 contractBalance,
        uint256 _totalPendingRewards,
        int256  deficit,
        bool    canPayRewards,
        uint256 healthPercentage
    ) {
        contractBalance      = address(this).balance;
        _totalPendingRewards = totalPendingRewards;

        if (contractBalance >= totalPendingRewards) {
            canPayRewards    = true;
            deficit          = 0;
            status           = _protocolHealth;
            healthPercentage = 100;
        } else {
            canPayRewards = false;
            deficit       = int256(totalPendingRewards) - int256(contractBalance);
            status        = (deficit > int256(UNSTABLE_THRESHOLD))
                ? ITreasuryManager.ProtocolStatus.CRITICAL
                : ITreasuryManager.ProtocolStatus.UNSTABLE;
            healthPercentage = (contractBalance * 100) / totalPendingRewards;
        }
    }

    function performHealthCheck() external override returns (ITreasuryManager.ProtocolStatus newStatus) {
        uint256 bal = address(this).balance;
        uint256 pending = totalPendingRewards;
        ITreasuryManager.ProtocolStatus prev = _protocolHealth;
        bool emergencyRequested;

        if (bal >= pending) {
            newStatus = ITreasuryManager.ProtocolStatus.HEALTHY;
        } else if (bal >= pending / 2) {
            newStatus = ITreasuryManager.ProtocolStatus.UNSTABLE;
        } else {
            newStatus = ITreasuryManager.ProtocolStatus.CRITICAL;
            if (address(treasuryManager) != address(0)) {
                uint256 deficit = pending - bal;
                try treasuryManager.requestEmergencyFunds(ITreasuryManager.TreasuryType.REWARDS, deficit)
                    returns (bool ok) {
                    emergencyRequested = true;
                    emit TreasuryNotificationSent(ok ? "EF_OK" : "EF_NO", deficit, block.timestamp);
                } catch {
                    emit TreasuryNotificationSent("EF_NO", deficit, block.timestamp);
                }
            }
        }

        if (newStatus != prev) {
            _protocolHealth = newStatus;
            emit ProtocolHealthStatusChanged(newStatus, block.timestamp, "");
            if (address(treasuryManager) != address(0)) {
                try treasuryManager.setProtocolStatus(ITreasuryManager.TreasuryType.REWARDS, newStatus) {} catch {}
            }
        }

        _lastHealthCheckTime = block.timestamp;
        emit HealthCheckPerformed(bal, pending, newStatus, emergencyRequested);
    }

    function reportCriticalStatus(uint256 requiredAmount) external override onlyAuthorized returns (bool notified) {
        if (address(treasuryManager) == address(0)) revert InvalidAddress();
        if (_protocolHealth != ITreasuryManager.ProtocolStatus.CRITICAL) revert InvalidParam();
        try treasuryManager.declareEmergency("Reward deficit") {
            emit TreasuryNotificationSent("CRIT_OK", requiredAmount, block.timestamp);
            return true;
        } catch {
            emit TreasuryNotificationSent("CRIT_NO", requiredAmount, block.timestamp);
            return false;
        }
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // XP & LEVELS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Award XP for a protocol action.
     * @param user       Target user.
     * @param actionType 0=stake, 1=compound, 2=quest, 3=achievement.
     * @param amount     Raw amount (POL for stake, dynamic XP for quest).
     */
    function updateUserXP(address user, uint8 actionType, uint256 amount) external override onlyAuthorized nonReentrant {
        _updateUserXP(user, actionType, amount);
    }

    /**
     * @notice Admin override: set a user's local XP and sync to LevelingSystem.
     */
    function setUserXP(address user, uint256 xp) external override onlyOwner {
        uint256 cappedXP = xp > MAX_XP_TOTAL ? MAX_XP_TOTAL : xp;
        _localXP[user] = cappedXP;
        if (levelingSystemAddress != address(0)) {
            (bool ok,) = levelingSystemAddress.call(
                abi.encodeWithSignature("adminSetUserXP(address,uint256)", user, cappedXP)
            );
            if (!ok) {}
        }
        emit XPUpdated(user, cappedXP, _levelFromXP(cappedXP));
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // QUESTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Record a completed quest and store its pending reward.
     * @param user          Recipient.
     * @param questId       Unique quest identifier.
     * @param rewardAmount  ETH reward (paid later by SmartStakingRewards via QuestRewardsPool).
     * @param questXP       Dynamic XP for this quest (10–25).
     * @param expirationDays Days until reward expires.
     */
    function completeQuest(
        address user,
        uint256 questId,
        uint256 rewardAmount,
        uint256 questXP,
        uint256 expirationDays
    ) external override onlyAuthorized nonReentrant {
        if (_questRewards[user][questId].amount != 0) revert AlreadyDone();
        if (questXP < MIN_QUEST_XP || questXP > MAX_QUEST_XP) revert InvalidParam();

        _questRewards[user][questId] = QuestReward({
            amount:         rewardAmount,
            expirationTime: block.timestamp + (expirationDays * 1 days),
            claimed:        false
        });
        _userQuestIds[user].push(questId);
        statTotalQuests++;

        _updateUserXP(user, 2, questXP);
        emit QuestCompleted(user, questId, rewardAmount);
    }

    /**
     * @notice Direct claim is disabled — rewards flow through SmartStakingRewards.
     * @dev Kept to satisfy the interface but always reverts.
     */
    function claimQuestReward(uint256) external pure override {
        revert NotAuthorized();
    }

    function setQuestClaimed(address user, uint256 questId) external override onlyAuthorized {
        QuestReward storage r = _questRewards[user][questId];
        if (r.amount == 0) revert NoReward();
        if (r.claimed) revert AlreadyDone();
        r.claimed = true;
    }

    /**
     * @notice Expire rewards past their deadline.
     */
    function expireQuestRewards(address user, uint256[] calldata questIds) external override onlyAuthorized {
        for (uint256 i; i < questIds.length; i++) {
            QuestReward storage r = _questRewards[user][questIds[i]];
            if (!r.claimed && block.timestamp > r.expirationTime && r.amount > 0) {
                uint256 expired = r.amount;
                r.amount = 0;
                emit RewardExpired(user, "q", expired);
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ACHIEVEMENTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Record an unlocked achievement and store its pending reward.
     */
    function unlockAchievement(
        address user,
        uint256 achievementId,
        uint256 rewardAmount,
        uint256 expirationDays
    ) external override onlyAuthorized nonReentrant {
        if (_achievementRewards[user][achievementId].amount != 0) revert AlreadyDone();

        _achievementRewards[user][achievementId] = AchievementReward({
            amount:         rewardAmount,
            expirationTime: block.timestamp + (expirationDays * 1 days),
            claimed:        false
        });
        _userAchievementIds[user].push(achievementId);
        statTotalAchievements++;

        _updateUserXP(user, 3, 0);
        emit AchievementUnlocked(user, achievementId, rewardAmount);
    }

    /**
     * @notice Direct claim is disabled — rewards flow through SmartStakingRewards.
     */
    function claimAchievementReward(uint256) external pure override {
        revert NotAuthorized();
    }

    /**
     * @notice Expire achievement rewards past their deadline.
     */
    function expireAchievementRewards(address user, uint256[] calldata achievementIds) external override onlyAuthorized {
        for (uint256 i; i < achievementIds.length; i++) {
            AchievementReward storage r = _achievementRewards[user][achievementIds[i]];
            if (!r.claimed && block.timestamp > r.expirationTime && r.amount > 0) {
                uint256 expired = r.amount;
                r.amount = 0;
                emit RewardExpired(user, "a", expired);
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // AUTO-COMPOUND
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Opt-in to automatic reward compounding.
     * @param minAmount Minimum pending reward (in wei) required to trigger a compound.
     */
    function enableAutoCompound(uint256 minAmount) external override {
        if (minAmount < MIN_COMPOUND_AMOUNT) revert InvalidParam();
        AutoCompoundConfig storage c = _autoCompoundConfigs[msg.sender];
        c.enabled          = true;
        c.minAmount        = minAmount;
        c.lastCompoundTime = block.timestamp;
        _addToAutoCompoundList(msg.sender);
        emit AutoCompoundEnabled(msg.sender, minAmount);
    }

    /**
     * @notice Opt-out of automatic compounding.
     */
    function disableAutoCompound() external override {
        _autoCompoundConfigs[msg.sender].enabled = false;
        _removeFromAutoCompoundList(msg.sender);
        emit AutoCompoundDisabled(msg.sender);
    }

    /**
     * @notice Check whether auto-compound should fire for a user.
     * @dev Queries the Core contract's `calculateRewards(address)` via a staticcall.
     */
    function checkAutoCompound(address user) external view override returns (bool shouldCompound, uint256 compoundAmount) {
        AutoCompoundConfig storage c = _autoCompoundConfigs[user];
        if (!c.enabled) return (false, 0);
        if (block.timestamp < c.lastCompoundTime + AUTO_COMPOUND_INTERVAL) return (false, 0);
        if (coreStakingContract == address(0)) return (false, 0);

        (bool success, bytes memory data) = coreStakingContract.staticcall(
            abi.encodeWithSignature("calculateRewards(address)", user)
        );
        if (!success || data.length == 0) return (false, 0);

        compoundAmount  = abi.decode(data, (uint256));
        shouldCompound  = compoundAmount >= c.minAmount;
    }

    /**
     * @notice Called by SmartStakingCore after completing the compound.
     *         Updates timestamp and awards compound XP.
     */
    function performAutoCompound(address user) external override onlyCore {
        AutoCompoundConfig storage c = _autoCompoundConfigs[user];
        if (!c.enabled) revert InvalidParam();
        c.lastCompoundTime = block.timestamp;
        _updateUserXP(user, 1, 0); // actionType 1 = compound
        emit AutoCompoundExecuted(user, 0);
    }

    /**
     * @notice Batch update timestamps for multiple users (Core-triggered).
     */
    function batchAutoCompound(address[] calldata users) external override onlyCore {
        if (users.length == 0 || users.length > BATCH_LIMIT) revert BatchSizeInvalid();
        for (uint256 i; i < users.length; i++) {
            AutoCompoundConfig storage c = _autoCompoundConfigs[users[i]];
            if (c.enabled) {
                c.lastCompoundTime = block.timestamp;
                emit AutoCompoundExecuted(users[i], 0);
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // DEFERRED REWARD CLAIMING
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Allow a user to pull their deferred level-up reward once the contract has funds.
     */
    function claimDeferredReward() external override nonReentrant {
        uint256 amount = deferredRewardAmount[msg.sender];
        if (amount == 0) revert NoReward();
        if (address(this).balance < amount) revert InsufficientBalance();

        deferredRewardAmount[msg.sender] = 0;
        deferredRewardTime[msg.sender]   = 0;

        // totalPendingRewards was already incremented when the reward was deferred
        if (totalPendingRewards >= amount) totalPendingRewards -= amount;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        statTotalRewardsPaid += amount;
        emit DeferredRewardClaimed(msg.sender, amount);
    }

    function settleDeferred(address user) external onlyOwner nonReentrant {
        uint256 amount = deferredRewardAmount[user];
        if (amount == 0) revert NoReward();
        if (address(this).balance < amount) revert InsufficientBalance();

        deferredRewardAmount[user] = 0;
        deferredRewardTime[user]   = 0;
        if (totalPendingRewards >= amount) totalPendingRewards -= amount;

        (bool success,) = payable(user).call{value: amount}("");
        if (!success) revert TransferFailed();

        statTotalRewardsPaid += amount;
        emit DeferredRewardClaimed(user, amount);
        emit RewardPaid(user, amount);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS — XP & LEVELS
    // ════════════════════════════════════════════════════════════════════════════════════════

    function getUserXPInfo(address user) external view override returns (
        uint256 xp,
        uint16  level,
        uint256 xpToNextLevel
    ) {
        if (levelingSystemAddress != address(0)) {
            try IXPHub(levelingSystemAddress).getUserXP(user) returns (uint256 totalXP, uint8 lvl) {
                xp    = totalXP;
                level = uint16(lvl);
            } catch {}
        } else {
            xp    = _localXP[user];
            level = _levelFromXP(xp);
        }

        uint16 nextLvl = level + 1;
        uint256 reqNext = level < MAX_LEVEL ? _xpPerLevel(nextLvl) : 0;
        uint256 cumulCurrent = level > 0 ? _cumulativeXPForLevel(level) : 0;
        uint256 xpInLevel = xp > cumulCurrent ? xp - cumulCurrent : 0;
        xpToNextLevel = reqNext > xpInLevel ? reqNext - xpInLevel : 0;
    }

    function calculateLevel(uint256 xp) external view override returns (uint16) {
        if (levelingSystemAddress != address(0)) {
            try IXPHub(levelingSystemAddress).getLevelFromXP(xp) returns (uint8 lvl) {
                return uint16(lvl);
            } catch {}
        }
        return _levelFromXP(xp);
    }

    function getXPForLevel(uint16 level) external pure override returns (uint256 cumul) {
        if (level == 0) {
            return 0;
        }
        if (level > MAX_LEVEL) {
            level = MAX_LEVEL;
        }
        return _cumulativeXPForLevel(level);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS — QUESTS & ACHIEVEMENTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    function getQuestReward(address user, uint256 questId) external view override returns (QuestReward memory) {
        return _questRewards[user][questId];
    }

    function getAchievementReward(address user, uint256 achievementId) external view override returns (AchievementReward memory) {
        return _achievementRewards[user][achievementId];
    }

    function getAllQuestRewards(address user) external view override returns (
        uint256[]     memory questIds,
        QuestReward[] memory rewards
    ) {
        questIds = _userQuestIds[user];
        rewards  = new QuestReward[](questIds.length);
        for (uint256 i; i < questIds.length; i++) rewards[i] = _questRewards[user][questIds[i]];
    }

    function getAllAchievementRewards(address user) external view override returns (
        uint256[]          memory achievementIds,
        AchievementReward[] memory rewards
    ) {
        achievementIds = _userAchievementIds[user];
        rewards        = new AchievementReward[](achievementIds.length);
        for (uint256 i; i < achievementIds.length; i++) rewards[i] = _achievementRewards[user][achievementIds[i]];
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS — AUTO-COMPOUND
    // ════════════════════════════════════════════════════════════════════════════════════════

    function getAutoCompoundConfig(address user) external view override returns (AutoCompoundConfig memory) {
        return _autoCompoundConfigs[user];
    }

    function getAutoCompoundUsersPage(uint256 offset, uint256 limit) external view override returns (
        address[]           memory users,
        AutoCompoundConfig[] memory configs,
        uint256              total
    ) {
        total = _autoCompoundUsers.length;
        if (offset >= total) return (new address[](0), new AutoCompoundConfig[](0), total);

        uint256 end = offset + limit;
        if (end > total) end = total;
        uint256 len = end - offset;

        users   = new address[](len);
        configs = new AutoCompoundConfig[](len);
        for (uint256 i; i < len; i++) {
            users[i]   = _autoCompoundUsers[offset + i];
            configs[i] = _autoCompoundConfigs[users[i]];
        }
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS — STREAKS & MULTIPLIERS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Return a user's daily streak data.
     */
    function getUserStreak(address user) external view returns (
        uint32  streak,
        uint32  longestStreak,
        uint256 lastActivityDay
    ) {
        StreakData storage s = _streaks[user];
        return (s.current, s.longest, s.lastActivityDay);
    }

    /**
     * @notice Return the effective XP multiplier currently active (considers season).
     * @return mult Multiplier in basis points (10000 = 1x).
     */
    function effectiveXpMultiplier() external view returns (uint256 mult) {
        return _effectiveMultiplier();
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS — BADGES
    // ════════════════════════════════════════════════════════════════════════════════════════

    function getUserBadges(address user) external view returns (Badge[] memory) {
        return _userBadges[user];
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS — PROTOCOL STATS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Return aggregate protocol statistics.
     */
    function getProtocolStats() external view returns (
        uint256 totalXP,
        uint256 totalRewards,
        uint32  totalLevelUps,
        uint32  totalQuests,
        uint32  totalAchievements
    ) {
        return (
            statTotalXPDistributed,
            statTotalRewardsPaid,
            statTotalLevelUps,
            statTotalQuests,
            statTotalAchievements
        );
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL — XP PIPELINE
    // ════════════════════════════════════════════════════════════════════════════════════════

    function _updateUserXP(address user, uint8 actionType, uint256 amount) internal {
        uint256 xpGained;
        IXPHub.XPSource source;

        if (actionType == 0) {
            xpGained = amount / (STAKING_XP_DIVISOR * 1 ether);
            if (xpGained == 0) return;
            source = IXPHub.XPSource.STAKING;
        } else if (actionType == 1) {
            xpGained = COMPOUND_XP;
            source   = IXPHub.XPSource.COMPOUND;
        } else if (actionType == 2) {
            if (amount < MIN_QUEST_XP || amount > MAX_QUEST_XP) revert InvalidParam();
            xpGained = amount;
            source   = IXPHub.XPSource.QUEST;
        } else if (actionType == 3) {
            xpGained = ACHIEVEMENT_XP;
            source   = IXPHub.XPSource.ACHIEVEMENT;
        } else {
            return;
        }

        // Apply streak + global/season multiplier
        uint256 mult = _effectiveMultiplier();
        uint256 streakMult = _updateAndGetStreakMultiplier(user);
        if (streakMult > mult) mult = streakMult;
        if (mult != BASIS_POINTS) {
            xpGained = (xpGained * mult) / BASIS_POINTS;
        }

        statTotalXPDistributed += xpGained;

        if (levelingSystemAddress != address(0)) {
            try IXPHub(levelingSystemAddress).awardXP(user, xpGained, source)
                returns (bool leveledUp, uint8 newLevel)
            {
                if (leveledUp) {
                    statTotalLevelUps++;
                    _distributeLevelUpReward(user, newLevel);
                    _checkAndAwardBadges(user, newLevel);
                    emit LevelUp(user, newLevel);
                }
            } catch { /* graceful degradation */ }
        } else {
            // Local fallback
            uint16 oldLevel = _levelFromXP(_localXP[user]);
            _localXP[user] += xpGained;
            uint16 newLevel = _levelFromXP(_localXP[user]);
            if (newLevel > oldLevel) {
                statTotalLevelUps++;
                _distributeLevelUpReward(user, uint8(newLevel));
                _checkAndAwardBadges(user, uint8(newLevel));
                emit LevelUp(user, uint8(newLevel));
            }
            emit XPUpdated(user, _localXP[user], newLevel);
        }
    }

    function _distributeLevelUpReward(address user, uint8 newLevel) internal {
        uint256 reward = _calculateLevelUpReward(newLevel);
        uint256 reservedBefore = totalPendingRewards;

        if (_hasRewardLiquidity(reward, reservedBefore)) {
            (bool ok,) = payable(user).call{value: reward}("");
            if (ok) {
                statTotalRewardsPaid += reward;
                emit RewardPaid(user, reward);
                return;
            }
        }

        // Try Treasury
        if (address(treasuryManager) != address(0)) {
            try treasuryManager.requestRewardFunds(reward) returns (bool funded) {
                if (funded && _hasRewardLiquidity(reward, reservedBefore)) {
                    (bool ok,) = payable(user).call{value: reward}("");
                    if (ok) {
                        statTotalRewardsPaid += reward;
                        emit RewardPaid(user, reward);
                        return;
                    }
                }
            } catch {}
        }

        // Defer
    totalPendingRewards = reservedBefore + reward;
        deferredRewardAmount[user] += reward;
        deferredRewardTime[user]    = block.timestamp;
        emit CriticalRewardDeficit(user, reward, totalPendingRewards, address(this).balance);
        emit RewardDeferred(user, newLevel, reward, "Liquidity");

        if (block.timestamp >= _lastHealthCheckTime + 1 hours) _quickHealthCheck();
    }

    function _calculateLevelUpReward(uint8 level) internal pure returns (uint256) {
        if (level == 0 || level > MAX_LEVEL) revert InvalidParam();

        uint256 rewardTier = ((uint256(level) - 1) / LEVELS_PER_BRACKET) + 1;
        uint256 rewardAmount = rewardTier * LEVEL_REWARD_STEP;
        if (rewardAmount > MAX_LEVEL_REWARD) {
            return MAX_LEVEL_REWARD;
        }
        if (rewardAmount < MIN_LEVEL_REWARD) {
            return MIN_LEVEL_REWARD;
        }
        return rewardAmount;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL — STREAK SYSTEM
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Update a user's streak and return the streak-based XP multiplier.
     * @dev Uses UTC day number (block.timestamp / 1 days) for day boundary detection.
     */
    function _updateAndGetStreakMultiplier(address user) internal returns (uint256 mult) {
        StreakData storage s = _streaks[user];
        uint40 today = uint40(block.timestamp / 1 days);

        if (s.lastActivityDay == 0) {
            // First ever activity
            s.current         = 1;
            s.longest         = 1;
            s.lastActivityDay = today;
        } else if (today == s.lastActivityDay + 1) {
            // Consecutive day
            s.current++;
            if (s.current > s.longest) s.longest = s.current;
            s.lastActivityDay = today;
        } else if (today > s.lastActivityDay + 1) {
            // Gap — reset streak
            s.current         = 1;
            s.lastActivityDay = today;
        }
        // today == s.lastActivityDay: same day, no change

        mult = _streakMultiplier(s.current);
        if (mult > BASIS_POINTS) emit StreakUpdated(user, s.current, mult);
    }

    function _streakMultiplier(uint32 streak) internal pure returns (uint256) {
        if (streak >= 30) return STREAK_30_MULT;
        if (streak >= 21) return STREAK_21_MULT;
        if (streak >= 14) return STREAK_14_MULT;
        if (streak >= 7)  return STREAK_7_MULT;
        return BASIS_POINTS; // 1x
    }

    function _effectiveMultiplier() internal view returns (uint256) {
        if (seasonEndTime > block.timestamp && seasonMultiplier > globalXpMultiplier) {
            return seasonMultiplier;
        }
        return globalXpMultiplier;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL — BADGES
    // ════════════════════════════════════════════════════════════════════════════════════════

    function _checkAndAwardBadges(address user, uint8 newLevel) internal {
        if (newLevel == 10  && !_userHasBadge[user][keccak256("LEVEL_10")])
            _awardBadgeInternal(user, 1, "Bronze", "L10");
        if (newLevel == 25  && !_userHasBadge[user][keccak256("LEVEL_25")])
            _awardBadgeInternal(user, 2, "Silver", "L25");
        if (newLevel == 50  && !_userHasBadge[user][keccak256("LEVEL_50")])
            _awardBadgeInternal(user, 3, "Gold", "L50");
        if (newLevel == 100 && !_userHasBadge[user][keccak256("LEVEL_100")])
            _awardBadgeInternal(user, 4, "Platinum", "L100");
        if (newLevel == 150 && !_userHasBadge[user][keccak256("LEVEL_150")])
            _awardBadgeInternal(user, 5, "Diamond", "L150");
        if (newLevel == 200 && !_userHasBadge[user][keccak256("LEVEL_200")])
            _awardBadgeInternal(user, 6, "Mythic", "L200");
        if (newLevel == 250 && !_userHasBadge[user][keccak256("LEVEL_250")])
            _awardBadgeInternal(user, 7, "Legend", "L250");

        uint256 quests = _userQuestIds[user].length;
        if (quests >= 10  && !_userHasBadge[user][keccak256("QUEST_MASTER")])
            _awardBadgeInternal(user, 10, "Quests I", "10 quests");
        if (quests >= 50  && !_userHasBadge[user][keccak256("QUEST_LEGEND")])
            _awardBadgeInternal(user, 11, "Quests II", "50 quests");

        uint256 ach = _userAchievementIds[user].length;
        if (ach >= 5  && !_userHasBadge[user][keccak256("ACHIEVER")])
            _awardBadgeInternal(user, 20, "Achv I", "5 unlocks");
        if (ach >= 20 && !_userHasBadge[user][keccak256("ACHIEVEMENT_HUNTER")])
            _awardBadgeInternal(user, 21, "Achv II", "20 unlocks");

        // Streak badges
        uint32 streak = _streaks[user].current;
        if (streak >= 7  && !_userHasBadge[user][keccak256("STREAK_WEEK")])
            _awardBadgeInternal(user, 30, "Streak I", "7 days");
        if (streak >= 30 && !_userHasBadge[user][keccak256("STREAK_MONTH")])
            _awardBadgeInternal(user, 31, "Streak II", "30 days");
    }

    function _awardBadgeInternal(address user, uint256 id, string memory name, string memory description) internal {
        bytes32 h = keccak256(bytes(name));
        if (_userHasBadge[user][h]) return;
        _userHasBadge[user][h] = true;
        _userBadges[user].push(Badge({ id: id, name: name, description: description, dateEarned: block.timestamp }));
        emit BadgeEarned(user, id, name);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL — AUTO-COMPOUND LIST
    // ════════════════════════════════════════════════════════════════════════════════════════

    function _addToAutoCompoundList(address user) internal {
        if (_isInAutoCompoundList[user]) return;
        _autoCompoundIndex[user] = _autoCompoundUsers.length;
        _autoCompoundUsers.push(user);
        _isInAutoCompoundList[user] = true;
    }

    function _removeFromAutoCompoundList(address user) internal {
        if (!_isInAutoCompoundList[user]) return;
        uint256 idx  = _autoCompoundIndex[user];
        uint256 last = _autoCompoundUsers.length - 1;
        if (idx != last) {
            address lastUser = _autoCompoundUsers[last];
            _autoCompoundUsers[idx]         = lastUser;
            _autoCompoundIndex[lastUser]    = idx;
        }
        _autoCompoundUsers.pop();
        _isInAutoCompoundList[user] = false;
        delete _autoCompoundIndex[user];
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL — PROTOCOL HEALTH (quick, non-external)
    // ════════════════════════════════════════════════════════════════════════════════════════

    function _quickHealthCheck() internal {
        uint256 bal     = address(this).balance;
        uint256 pending = totalPendingRewards;
        ITreasuryManager.ProtocolStatus ns;

        if (bal >= pending)       ns = ITreasuryManager.ProtocolStatus.HEALTHY;
        else if (bal >= pending/2) ns = ITreasuryManager.ProtocolStatus.UNSTABLE;
        else                       ns = ITreasuryManager.ProtocolStatus.CRITICAL;

        if (ns != _protocolHealth) {
            _protocolHealth = ns;
            emit ProtocolHealthStatusChanged(ns, block.timestamp, "");
            if (address(treasuryManager) != address(0)) {
                try treasuryManager.setProtocolStatus(ITreasuryManager.TreasuryType.REWARDS, ns) {} catch {}
            }
        }
        _lastHealthCheckTime = block.timestamp;
    }

    function _hasRewardLiquidity(uint256 reward, uint256 reservedBefore) internal view returns (bool) {
        return address(this).balance >= reservedBefore + reward;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL — XP MATH HELPERS (O(1))
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @dev XP required to complete a given level (not cumulative).
     * Each bracket of 25 levels increases the per-level XP cost by 50.
     */
    function _xpPerLevel(uint16 level) internal pure returns (uint256) {
        if (level == 0 || level > MAX_LEVEL) return 0;
        uint256 bracket = ((uint256(level) - 1) / LEVELS_PER_BRACKET) + 1;
        return bracket * XP_PER_BRACKET_STEP;
    }

    /**
     * @dev Level from cumulative XP — mirrors LevelingSystem.getLevelFromXP.
     */
    function _levelFromXP(uint256 xp) internal pure returns (uint16) {
        if (xp < XP_PER_BRACKET_STEP) return 0;

        uint256 remainingXP = xp > MAX_XP_TOTAL ? MAX_XP_TOTAL : xp;
        for (uint256 bracket = 1; bracket <= BRACKET_COUNT; bracket++) {
            uint256 xpPerLevel = bracket * XP_PER_BRACKET_STEP;
            uint256 bracketXP = xpPerLevel * LEVELS_PER_BRACKET;
            if (remainingXP <= bracketXP) {
                return uint16(((bracket - 1) * LEVELS_PER_BRACKET) + (remainingXP / xpPerLevel));
            }
            remainingXP -= bracketXP;
        }

        return MAX_LEVEL;
    }

    function _cumulativeXPForLevel(uint16 level) internal pure returns (uint256 cumulativeXP) {
        if (level == 0) {
            return 0;
        }
        if (level > MAX_LEVEL) {
            level = MAX_LEVEL;
        }

        uint256 bracket = ((uint256(level) - 1) / LEVELS_PER_BRACKET) + 1;
        uint256 completedBrackets = bracket - 1;
        uint256 levelsBeforeBracket = completedBrackets * LEVELS_PER_BRACKET;
        uint256 xpBeforeBracket = XP_PER_BRACKET_STEP * LEVELS_PER_BRACKET * completedBrackets * bracket / 2;
        uint256 levelsInCurrentBracket = uint256(level) - levelsBeforeBracket;

        return xpBeforeBracket + (levelsInCurrentBracket * bracket * XP_PER_BRACKET_STEP);
    }
}
