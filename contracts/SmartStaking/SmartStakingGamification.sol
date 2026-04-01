// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISmartStakingGamification.sol";
import "../interfaces/ITreasuryManager.sol";
import "../interfaces/IStakingIntegration.sol";
import "../interfaces/IXPHub.sol";

/**
 * @title SmartStakingGamification
 * @notice Handles gamification features: XP, levels, quests, achievements, and auto-compound
 * @dev This module manages user progression and reward mechanics
 */
contract SmartStakingGamification is Ownable, ReentrancyGuard, ISmartStakingGamification {
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    /// @notice Base XP for level calculation (Exponential: XP = 50 * Level^2)
    uint256 private constant XP_BASE = 50;
    
    /// @notice Maximum Level Cap
    uint256 private constant MAX_LEVEL_CAP = 100;
    
    /// @notice Reward expiration period (30 days default)
    uint256 private constant REWARD_EXPIRATION = 30 days;
    
    /// @notice Auto-compound check interval (24 hours)
    uint256 private constant AUTO_COMPOUND_INTERVAL = 1 days;
    
    /// @notice Minimum compound amount (0.01 ether)
    uint256 private constant MIN_COMPOUND_AMOUNT = 0.01 ether;

    /// @notice Maximum users per batch operation (prevent OOG)
    uint256 private constant BATCH_LIMIT = 100;

    // ============================================
    // XP REWARDS - REDUCED FOR PLATFORM STABILITY
    // ============================================
    
    /// @notice Staking XP divisor: 1 XP per 2 POL (reduced from 1 per POL)
    uint256 private constant STAKING_XP_DIVISOR = 2;
    
    /// @notice Compound XP: 3 XP fixed (reduced from 5)
    uint256 private constant COMPOUND_XP = 3;
    
    /// @notice Quest XP minimum (dynamic range 10-25)
    uint256 private constant MIN_QUEST_XP = 10;
    
    /// @notice Quest XP maximum (dynamic range 10-25)
    uint256 private constant MAX_QUEST_XP = 25;
    
    /// @notice Achievement XP: 100 XP fixed (reduced from 200)
    uint256 private constant ACHIEVEMENT_XP = 100;

    struct Badge {
        uint256 id;
        string name;
        string description;
        uint256 dateEarned;
    }
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /// @notice Address of the marketplace contract (authorized caller)
    address public marketplaceContract;
    
    /// @notice Address of the core staking contract
    address public coreStakingContract;
    
    /// @notice Address of the leveling system contract (for dynamic level-up rewards)
    address public levelingSystemAddress;
    
    /// @notice Address of the Treasury Manager (for reward funding)
    ITreasuryManager public treasuryManager;
    
    /// @notice Tracks if user has earned specific badge (by name hash)
    mapping(address => mapping(bytes32 => bool)) private _userHasBadge;

    /// @notice Local XP fallback — used when levelingSystemAddress is not set.
    mapping(address => uint256) private _localXP;
    
    /// @notice Maps user to quest ID to quest reward
    mapping(address => mapping(uint256 => QuestReward)) private _questRewards;
    
    /// @notice Maps user to achievement ID to achievement reward
    mapping(address => mapping(uint256 => AchievementReward)) private _achievementRewards;
    
    /// @notice Maps user to their quest IDs
    mapping(address => uint256[]) private _userQuestIds;
    
    /// @notice Maps user to their achievement IDs
    mapping(address => uint256[]) private _userAchievementIds;
    
    /// @notice Maps user to auto-compound configuration
    mapping(address => AutoCompoundConfig) private _autoCompoundConfigs;
    
    /// @notice List of users with auto-compound enabled
    address[] private _autoCompoundUsers;
    
    /// @notice Maps user to index in auto-compound list
    mapping(address => uint256) private _autoCompoundIndex;
    
    /// @notice Maps user to whether they're in auto-compound list
    mapping(address => bool) private _isInAutoCompoundList;

    /// @notice Maps user to their badges
    mapping(address => Badge[]) private _userBadges;
    
    // ============================================
    // PROTOCOL HEALTH STATE
    // ============================================
    
    /// @notice Current protocol health status
    ITreasuryManager.ProtocolStatus private _protocolHealth;
    
    /// @notice Timestamp of last health check
    uint256 private _lastHealthCheckTime;
    
    /// @notice Minimum reserve required to maintain HEALTHY status (5 POL)
    uint256 private constant MIN_HEALTHY_RESERVE = 5 ether;
    
    /// @notice Deficit threshold for UNSTABLE status (10 pending rewards unpaid)
    uint256 private constant UNSTABLE_THRESHOLD = 10 ether;
    
    /// @notice Total pending rewards (sum of all unpaid level-up rewards)
    uint256 private _totalPendingRewards;
    
    /// @notice Track deferred rewards by user for analysis
    mapping(address => uint256) private _deferredRewardAmount;
    mapping(address => uint256) private _deferredRewardTime;

    event RewardPaid(address indexed user, uint256 amount);
    event RewardDeferred(address indexed user, uint16 level, uint256 amount, string reason);
    event BadgeEarned(address indexed user, uint256 badgeId, string name);
    event TreasuryManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event ProtocolHealthStatusChanged(ITreasuryManager.ProtocolStatus newStatus, uint256 timestamp, string reason);
    event CriticalRewardDeficit(address indexed user, uint256 rewardAmount, uint256 totalPendingRewards, uint256 contractBalance);
    event HealthCheckPerformed(uint256 contractBalance, uint256 totalPendingRewards, ITreasuryManager.ProtocolStatus status, bool emergencyFundsRequested);
    event TreasuryNotificationSent(string alertType, uint256 deficit, uint256 timestamp);
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    modifier onlyMarketplace() {
        require(msg.sender == marketplaceContract, "Only marketplace");
        _;
    }
    
    modifier onlyCore() {
        require(msg.sender == coreStakingContract, "Only core");
        _;
    }
    
    modifier onlyAuthorized() {
        require(
            msg.sender == marketplaceContract || msg.sender == coreStakingContract || msg.sender == owner(),
            "Not authorized"
        );
        _;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {}

    receive() external payable {}
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    /**
     * @notice Set the marketplace contract address
     * @param _marketplace The marketplace contract address
     */
    function setMarketplaceContract(address _marketplace) external onlyOwner {
        require(_marketplace != address(0), "Invalid address");
        marketplaceContract = _marketplace;
    }
    
    /**
     * @notice Set the core staking contract address
     * @param _coreStaking The core staking contract address
     */
    function setCoreStakingContract(address _coreStaking) external onlyOwner {
        require(_coreStaking != address(0), "Invalid address");
        coreStakingContract = _coreStaking;
    }
    
    /**
     * @notice Set the leveling system contract address
     * @param _levelingSystem The leveling system contract address
     */
    function setLevelingSystemAddress(address _levelingSystem) external onlyOwner {
        require(_levelingSystem != address(0), "Invalid address");
        levelingSystemAddress = _levelingSystem;
    }
    
    /**
     * @notice Set the treasury manager contract address
     * @param _treasuryManager The treasury manager contract address
     */
    function setTreasuryManager(address _treasuryManager) external onlyOwner {
        require(_treasuryManager != address(0), "Invalid address");
        address oldAddress = address(treasuryManager);
        treasuryManager = ITreasuryManager(_treasuryManager);
        emit TreasuryManagerUpdated(oldAddress, _treasuryManager);
    }
    
    // ============================================
    // PROTOCOL HEALTH CHECK FUNCTIONS
    // ============================================
    
    /**
     * @notice Get current protocol health status and metrics
     * @return status Current protocol status (HEALTHY/UNSTABLE/CRITICAL/EMERGENCY)
     * @return contractBalance Current balance in this contract
     * @return totalPendingRewards Sum of all unpaid rewards
     * @return deficit Negative difference if pending > balance
     * @return canPayRewards True if contract can pay all pending rewards
     * @return healthPercentage Percentage health (100% = fully funded)
     */
    function getProtocolHealth() external view override returns (
        ITreasuryManager.ProtocolStatus status,
        uint256 contractBalance,
        uint256 totalPendingRewards,
        int256 deficit,
        bool canPayRewards,
        uint256 healthPercentage
    ) {
        contractBalance = address(this).balance;
        totalPendingRewards = _totalPendingRewards;
        
        if (contractBalance >= totalPendingRewards) {
            canPayRewards = true;
            deficit = 0;
            status = _protocolHealth;
            healthPercentage = 100;
        } else {
            canPayRewards = false;
            deficit = int256(totalPendingRewards) - int256(contractBalance);
            
            // Determine severity based on deficit
            if (deficit > int256(UNSTABLE_THRESHOLD)) {
                status = ITreasuryManager.ProtocolStatus.CRITICAL;
                healthPercentage = (contractBalance * 100) / totalPendingRewards;
            } else {
                status = ITreasuryManager.ProtocolStatus.UNSTABLE;
                healthPercentage = (contractBalance * 100) / totalPendingRewards;
            }
        }
    }
    
    /**
     * @notice Perform health check and update protocol status
     * @dev Called periodically to monitor and report financial stability
     * @return newStatus The determined protocol status
     */
    function performHealthCheck() external override returns (ITreasuryManager.ProtocolStatus newStatus) {
        uint256 contractBalance = address(this).balance;
        uint256 totalPending = _totalPendingRewards;
        
        ITreasuryManager.ProtocolStatus previousStatus = _protocolHealth;
        bool emergencyRequested = false;
        
        // Determine new status
        if (contractBalance >= totalPending) {
            newStatus = ITreasuryManager.ProtocolStatus.HEALTHY;
        } else if (contractBalance >= (totalPending / 2)) {
            newStatus = ITreasuryManager.ProtocolStatus.UNSTABLE;
        } else {
            newStatus = ITreasuryManager.ProtocolStatus.CRITICAL;
            
            // Try to request emergency funds
            if (address(treasuryManager) != address(0)) {
                uint256 deficitAmount = totalPending - contractBalance;
                try treasuryManager.requestEmergencyFunds(
                    ITreasuryManager.TreasuryType.REWARDS, 
                    deficitAmount
                ) returns (bool success) {
                    emergencyRequested = true;
                    if (success) {
                        emit TreasuryNotificationSent("EMERGENCY_FUNDS_GRANTED", deficitAmount, block.timestamp);
                    }
                } catch {
                    // Emergency funds request failed
                    emit TreasuryNotificationSent("EMERGENCY_FUNDS_DENIED", deficitAmount, block.timestamp);
                }
            }
        }
        
        // Update status if changed
        if (newStatus != previousStatus) {
            _protocolHealth = newStatus;
            emit ProtocolHealthStatusChanged(newStatus, block.timestamp, _getStatusReason(newStatus));
            
            // Notify TreasuryManager of status change
            if (address(treasuryManager) != address(0)) {
                try treasuryManager.setProtocolStatus(
                    ITreasuryManager.TreasuryType.REWARDS,
                    newStatus
                ) {
                    // Status updated in Treasury
                } catch {
                    // Failed to notify Treasury
                }
            }
        }
        
        _lastHealthCheckTime = block.timestamp;
        
        emit HealthCheckPerformed(contractBalance, totalPending, newStatus, emergencyRequested);
        
        return newStatus;
    }
    
    /**
     * @notice Quick health check without full transaction overhead
     */
    function _performQuickHealthCheck() internal {
        ITreasuryManager.ProtocolStatus newStatus;
        uint256 contractBalance = address(this).balance;
        uint256 totalPending = _totalPendingRewards;
        
        if (contractBalance >= totalPending) {
            newStatus = ITreasuryManager.ProtocolStatus.HEALTHY;
        } else if (contractBalance >= (totalPending / 2)) {
            newStatus = ITreasuryManager.ProtocolStatus.UNSTABLE;
        } else {
            newStatus = ITreasuryManager.ProtocolStatus.CRITICAL;
        }
        
        if (newStatus != _protocolHealth) {
            _protocolHealth = newStatus;
            emit ProtocolHealthStatusChanged(newStatus, block.timestamp, _getStatusReason(newStatus));
            
            // Try to notify Treasury (non-blocking)
            if (address(treasuryManager) != address(0)) {
                try treasuryManager.setProtocolStatus(
                    ITreasuryManager.TreasuryType.REWARDS,
                    newStatus
                ) {} catch {}
            }
        }
        
        _lastHealthCheckTime = block.timestamp;
    }
    
    /**
     * @notice Get human-readable status reason
     * @param status The protocol status
     * @return reason Status description
     */
    function _getStatusReason(ITreasuryManager.ProtocolStatus status) 
        internal 
        pure 
        returns (string memory reason) 
    {
        if (status == ITreasuryManager.ProtocolStatus.HEALTHY) {
            return "Protocol fully funded and stable";
        } else if (status == ITreasuryManager.ProtocolStatus.UNSTABLE) {
            return "Protocol has insufficient reserves";
        } else if (status == ITreasuryManager.ProtocolStatus.CRITICAL) {
            return "Protocol critically underfunded";
        } else {
            return "Protocol in emergency mode";
        }
    }
    
    /**
     * @notice Report critical protocol status to TreasuryManager
     * @param requiredAmount Amount needed to restore health
     * @return notified True if TreasuryManager was successfully notified
     */
    function reportCriticalStatus(uint256 requiredAmount) 
        external 
        override 
        onlyAuthorized 
        returns (bool notified) 
    {
        require(address(treasuryManager) != address(0), "Treasury not configured");
        require(_protocolHealth == ITreasuryManager.ProtocolStatus.CRITICAL, "Status is not critical");
        
        // Notify Treasury of critical status
        try treasuryManager.declareEmergency(
            string(abi.encodePacked(
                "Gamification module requires funds for pending rewards"
            ))
        ) {
            emit TreasuryNotificationSent("CRITICAL_STATUS_REPORTED", requiredAmount, block.timestamp);
            return true;
        } catch {
            emit TreasuryNotificationSent("CRITICAL_STATUS_REPORT_FAILED", requiredAmount, block.timestamp);
            return false;
        }
    }
    
    // ============================================
    // XP & LEVEL FUNCTIONS
    // ============================================
    
    /**
     * @notice Update user XP and level based on action
     * @param user The user address
     * @param actionType The type of action (0=stake, 1=compound, 2=quest, 3=achievement)
     * @param amount The amount involved in the action
     */
    function updateUserXP(address user, uint8 actionType, uint256 amount) external override onlyAuthorized nonReentrant {
        _updateUserXP(user, actionType, amount);
    }

    // Delegates XP to LevelingSystem (IXPHub) and handles level-up rewards locally
    function _updateUserXP(address user, uint8 actionType, uint256 amount) internal {

        uint256 xpGained = 0;
        IXPHub.XPSource source;

        if (actionType == 0) {
            // Stake: 1 XP per 2 POL
            xpGained = amount / (STAKING_XP_DIVISOR * 1 ether);
            if (xpGained == 0) return;
            source = IXPHub.XPSource.STAKING;
        } else if (actionType == 1) {
            // Compound: 3 XP fixed
            xpGained = COMPOUND_XP;
            source = IXPHub.XPSource.COMPOUND;
        } else if (actionType == 2) {
            // Quest: dynamic 10-25 XP
            require(amount >= MIN_QUEST_XP && amount <= MAX_QUEST_XP, "Quest XP out of range (10-25)");
            xpGained = amount;
            source = IXPHub.XPSource.QUEST;
        } else if (actionType == 3) {
            // Achievement: 100 XP fixed
            xpGained = ACHIEVEMENT_XP;
            source = IXPHub.XPSource.ACHIEVEMENT;
        } else {
            return;
        }

        // Delegate to LevelingSystem — get back leveledUp signal
        if (levelingSystemAddress != address(0)) {
            try IXPHub(levelingSystemAddress).awardXP(user, xpGained, source)
                returns (bool leveledUp, uint8 newLevel)
            {
                if (leveledUp) {
                    _distributeLevelUpReward(user, newLevel);
                    _checkAndAwardBadges(user, newLevel);
                }
            } catch {
                // Graceful degradation if LevelingSystem is unreachable
            }
        } else {
            // Fallback: store locally and handle level-up
            uint16 oldLevel = _getLevelFromLocalXP(user);
            _localXP[user] += xpGained;
            uint16 newLevel = _getLevelFromLocalXP(user);
            if (newLevel > oldLevel) {
                _distributeLevelUpReward(user, uint8(newLevel));
                _checkAndAwardBadges(user, uint8(newLevel));
            }
        }
    }

    function _distributeLevelUpReward(address user, uint8 newLevel) internal {
        // Calculate reward based on LevelingSystem formula (1-5 POL per level)
        uint256 rewardAmount = _calculateLevelUpReward(newLevel);

        // Track pending reward
        _totalPendingRewards += rewardAmount;

        // Try to pay from contract balance first
        if (address(this).balance >= rewardAmount) {
            (bool success, ) = payable(user).call{value: rewardAmount}("");
            if (success) {
                _totalPendingRewards -= rewardAmount;
                emit RewardPaid(user, rewardAmount);
                return;
            }
        }
        
        // If contract balance insufficient, try to request from Treasury
        if (address(treasuryManager) != address(0)) {
            try treasuryManager.requestRewardFunds(rewardAmount) returns (bool funded) {
                if (funded && address(this).balance >= rewardAmount) {
                    (bool success, ) = payable(user).call{value: rewardAmount}("");
                    if (success) {
                        _totalPendingRewards -= rewardAmount;
                        emit RewardPaid(user, rewardAmount);
                        return;
                    }
                }
            } catch {
                // Treasury request failed
            }
        }
        
        // Reward deferred - insufficient funds
        // Track deferred reward for this user
        _deferredRewardAmount[user] += rewardAmount;
        _deferredRewardTime[user] = block.timestamp;
        
        // Emit critical deficit event
        emit CriticalRewardDeficit(user, rewardAmount, _totalPendingRewards, address(this).balance);
        
        emit RewardDeferred(user, newLevel, rewardAmount, "Insufficient funds in contract and treasury");
        
        // Attempt health check and emergency notification
        if (block.timestamp >= _lastHealthCheckTime + 1 hours) {
            _performQuickHealthCheck();
        }
    }
    
    /**
     * @dev Calculate dynamic level-up reward based on level (mirrors LevelingSystem logic)
     * Recompensas escaladas: 1-5 POL basado en nivel
     * Formula: min(5 POL, 1 POL + (nivel / 10))
     * 
     * Level 1-10:  1 POL
     * Level 11-20: 2 POL
     * Level 21-30: 3 POL
     * Level 31-40: 4 POL
     * Level 41-50: 5 POL (max cap)
     */
    function _calculateLevelUpReward(uint8 level) internal pure returns (uint256) {
        if (level <= 10) return 1 ether;
        if (level <= 20) return 2 ether;
        if (level <= 30) return 3 ether;
        if (level <= 40) return 4 ether;
        return 5 ether; // Max cap at level 41-50
    }
    
    /**
     * @notice Manually set XP for a user (admin only).
     * @dev Delegates to LevelingSystem since XP is no longer stored locally.
     */
    function setUserXP(address user, uint256 xp) external override onlyOwner {
        _localXP[user] = xp;
        if (levelingSystemAddress != address(0)) {
            try IXPHub(levelingSystemAddress).updateUserXP(user, xp, "admin_set") {} catch {}
        }
        emit XPUpdated(user, xp, 0);
    }

    function _getLevelFromLocalXP(address user) internal view returns (uint16) {
        uint256 xp = _localXP[user];
        if (xp == 0) return 0;
        uint256 cumul = 0;
        uint16 prevCumul = 0;
        for (uint16 i = 1; i <= 50; i++) {
            uint256 req;
            if (i <= 10) req = 50;
            else if (i <= 20) req = 100;
            else if (i <= 30) req = 150;
            else if (i <= 40) req = 200;
            else req = 250;
            prevCumul = uint16(cumul);
            cumul += req;
            if (xp <= cumul) {
                // If xp is exactly at the boundary, it means level i is reached.
                // But if xp < the cumul needed for i (not yet enough), return i-1.
                if (xp == cumul) return i;
                return i > 1 ? i - 1 : 0;
            }
        }
        return 50;
    }

    /**
     * @dev Internal square root function — REMOVED (no longer needed; XP delegated to LevelingSystem)
     * Keeping stub to avoid breaking any external references.
     */
    // _sqrt removed
    
    // ============================================
    // QUEST FUNCTIONS
    // ============================================
    
    /**
     * @notice Complete a quest with dynamic XP reward (10-25 XP)
     * @param user The user address
     * @param questId The quest identifier
     * @param rewardAmount The reward amount in tokens
     * @param questXP Dynamic XP reward (10-25 based on quest difficulty)
     * @param expirationDays Days until reward expires
     */
    function completeQuest(
        address user,
        uint256 questId,
        uint256 rewardAmount,
        uint256 questXP,
        uint256 expirationDays
    ) external override onlyAuthorized nonReentrant {
        require(_questRewards[user][questId].amount == 0, "Quest already completed");
        require(questXP >= MIN_QUEST_XP && questXP <= MAX_QUEST_XP, "Quest XP out of range (10-25)");
        
        _questRewards[user][questId] = QuestReward({
            amount: rewardAmount,
            expirationTime: block.timestamp + (expirationDays * 1 days),
            claimed: false
        });
        
        _userQuestIds[user].push(questId);
        
        // Award dynamic XP (10-25 based on quest difficulty)
        _updateUserXP(user, 2, questXP);
        
        emit QuestCompleted(user, questId, rewardAmount);
    }
    
    /**
     * @notice Claim a pending quest reward
     * @dev DEPRECATED: rewards must be claimed through SmartStakingRewards.claimQuestReward()
     *      Calling this directly will revert to prevent reward-burning without payment.
     */
    function claimQuestReward(uint256) external pure override {
        revert("Use SmartStakingRewards to claim quest rewards");
    }
    
    /**
     * @notice Mark a quest as claimed (Restricted to Rewards contract)
     * @param user The user address
     * @param questId The quest identifier
     */
    function setQuestClaimed(address user, uint256 questId) external override onlyAuthorized {
        QuestReward storage reward = _questRewards[user][questId];
        require(reward.amount > 0, "No reward");
        require(!reward.claimed, "Already claimed");
        
        reward.claimed = true;
    }
    
    /**
     * @notice Check and expire unclaimed quest rewards
     * @param user The user address
     * @param questIds Array of quest IDs to check
     */
    function expireQuestRewards(address user, uint256[] calldata questIds) external override onlyAuthorized {
        for (uint256 i = 0; i < questIds.length; i++) {
            QuestReward storage reward = _questRewards[user][questIds[i]];
            
            if (!reward.claimed && block.timestamp > reward.expirationTime && reward.amount > 0) {
                uint256 expiredAmount = reward.amount;
                reward.amount = 0;
                
                emit RewardExpired(user, "quest", expiredAmount);
            }
        }
    }
    
    // ============================================
    // ACHIEVEMENT FUNCTIONS
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
    ) external override onlyAuthorized nonReentrant {
        require(_achievementRewards[user][achievementId].amount == 0, "Achievement already unlocked");
        
        _achievementRewards[user][achievementId] = AchievementReward({
            amount: rewardAmount,
            expirationTime: block.timestamp + (expirationDays * 1 days),
            claimed: false
        });
        
        _userAchievementIds[user].push(achievementId);
        
        // Award XP
        _updateUserXP(user, 3, 0);
        
        emit AchievementUnlocked(user, achievementId, rewardAmount);
    }
    
    /**
     * @notice Claim a pending achievement reward
     * @dev DEPRECATED: rewards must be claimed through SmartStakingRewards.
     *      Calling this directly will revert to prevent reward-burning without payment.
     */
    function claimAchievementReward(uint256) external pure override {
        revert("Use SmartStakingRewards to claim achievement rewards");
    }
    
    /**
     * @notice Check and expire unclaimed achievement rewards
     * @param user The user address
     * @param achievementIds Array of achievement IDs to check
     */
    function expireAchievementRewards(address user, uint256[] calldata achievementIds) external override onlyAuthorized {
        for (uint256 i = 0; i < achievementIds.length; i++) {
            AchievementReward storage reward = _achievementRewards[user][achievementIds[i]];
            
            if (!reward.claimed && block.timestamp > reward.expirationTime && reward.amount > 0) {
                uint256 expiredAmount = reward.amount;
                reward.amount = 0;
                
                emit RewardExpired(user, "achievement", expiredAmount);
            }
        }
    }
    
    // ============================================
    // AUTO-COMPOUND FUNCTIONS
    // ============================================
    
    /**
     * @notice Enable auto-compound for caller
     * @param minAmount Minimum amount to trigger auto-compound
     */
    function enableAutoCompound(uint256 minAmount) external override {
        require(minAmount >= MIN_COMPOUND_AMOUNT, "Min amount too low");
        
        AutoCompoundConfig storage config = _autoCompoundConfigs[msg.sender];
        config.enabled = true;
        config.minAmount = minAmount;
        config.lastCompoundTime = block.timestamp;
        
        _addToAutoCompoundList(msg.sender);
        
        emit AutoCompoundEnabled(msg.sender, minAmount);
    }
    
    /**
     * @notice Disable auto-compound for caller
     */
    function disableAutoCompound() external override {
        AutoCompoundConfig storage config = _autoCompoundConfigs[msg.sender];
        config.enabled = false;
        
        _removeFromAutoCompoundList(msg.sender);
        
        emit AutoCompoundDisabled(msg.sender);
    }
    
    /**
     * @notice Check if auto-compound should be performed for a user
     * @param user The user address
     * @return shouldCompound True if auto-compound criteria are met
     * @return compoundAmount The amount that would be compounded
     */
    function checkAutoCompound(address user) external view override returns (bool shouldCompound, uint256 compoundAmount) {
        AutoCompoundConfig storage config = _autoCompoundConfigs[user];
        
        if (!config.enabled) {
            return (false, 0);
        }
        
        // Check if enough time has passed
        if (block.timestamp < config.lastCompoundTime + AUTO_COMPOUND_INTERVAL) {
            return (false, 0);
        }
        
        // Query current rewards from Core contract
        if (coreStakingContract != address(0)) {
            try IStakingIntegration(coreStakingContract).getUserPowerProfile(user) {
                // If we can reach the contract, query rewards using call
                (bool success, bytes memory data) = coreStakingContract.staticcall(
                    abi.encodeWithSignature("calculateRewards(address)", user)
                );
                if (success && data.length > 0) {
                    compoundAmount = abi.decode(data, (uint256));
                    shouldCompound = compoundAmount >= config.minAmount;
                    return (shouldCompound, compoundAmount);
                }
            } catch {
                // If query fails, return false
                return (false, 0);
            }
        }
        
        return (false, 0);
    }
    
    /**
     * @notice Perform auto-compound for a user (Chainlink Keeper compatible)
     * @param user The user address
     */
    function performAutoCompound(address user) external override onlyCore {
        AutoCompoundConfig storage config = _autoCompoundConfigs[user];
        
        require(config.enabled, "Auto-compound not enabled");
        
        // Update timestamp
        config.lastCompoundTime = block.timestamp;
        
        // Award XP for auto-compound action
        _updateUserXP(user, 1, 0); // actionType 1 = compound
        
        // Core contract handles the actual compounding
        emit AutoCompoundExecuted(user, 0); // Amount provided by Core
    }
    
    /**
     * @notice Batch perform auto-compound for multiple users
     * @param users Array of user addresses (max BATCH_LIMIT = 100)
     * @dev Prevents Out-of-Gas by limiting batch size
     */
    function batchAutoCompound(address[] calldata users) external override onlyCore {
        require(users.length > 0, "Empty user array");
        require(users.length <= BATCH_LIMIT, "Batch exceeds limit (max 100)");
        
        for (uint256 i = 0; i < users.length; i++) {
            if (_autoCompoundConfigs[users[i]].enabled) {
                _autoCompoundConfigs[users[i]].lastCompoundTime = block.timestamp;
                emit AutoCompoundExecuted(users[i], 0);
            }
        }
    }
    
    // ============================================
    // VIEW FUNCTIONS - XP & LEVELS
    // ============================================
    
    /**
     * @notice Get user XP and level info. Delegates to LevelingSystem.
     */
    function getUserXPInfo(address user) external view override returns (
        uint256 xp,
        uint16 level,
        uint256 xpToNextLevel
    ) {
        if (levelingSystemAddress != address(0)) {
            try IXPHub(levelingSystemAddress).getUserXP(user) returns (uint256 totalXP, uint8 lvl) {
                xp = totalXP;
                level = uint16(lvl);
            } catch {}
        } else {
            xp = _localXP[user];
            // Calculate level from local XP using tiered formula
            uint256 cumul = 0;
            for (uint16 i = 1; i <= 50; i++) {
                uint256 req;
                if (i <= 10) req = 50;
                else if (i <= 20) req = 100;
                else if (i <= 30) req = 150;
                else if (i <= 40) req = 200;
                else req = 250;
                cumul += req;
                if (xp == cumul) { level = i; break; }
                if (xp < cumul)  { level = i > 1 ? i - 1 : 0; break; }
                if (i == 50)     { level = 50; }
            }
        }
        // Estimate XP to next level using tiered formula (mirroring LevelingSystem)
        uint16 nextLvl = level + 1;
        uint256 nextLevelXPRequired;
        if (nextLvl <= 10) nextLevelXPRequired = 50;
        else if (nextLvl <= 20) nextLevelXPRequired = 100;
        else if (nextLvl <= 30) nextLevelXPRequired = 150;
        else if (nextLvl <= 40) nextLevelXPRequired = 200;
        else nextLevelXPRequired = 250;
        // Cumulative XP for current level
        uint256 cumulXP = 0;
        for (uint16 i = 1; i <= level; i++) {
            if (i <= 10) cumulXP += 50;
            else if (i <= 20) cumulXP += 100;
            else if (i <= 30) cumulXP += 150;
            else if (i <= 40) cumulXP += 200;
            else cumulXP += 250;
        }
        uint256 xpInCurrentLevel = xp > cumulXP ? xp - cumulXP : 0;
        xpToNextLevel = nextLevelXPRequired > xpInCurrentLevel ? nextLevelXPRequired - xpInCurrentLevel : 0;
    }
    
    /**
     * @notice Calculate level from XP. Delegates to LevelingSystem formula.
     */
    function calculateLevel(uint256 xp) external view override returns (uint16 level) {
        if (levelingSystemAddress != address(0)) {
            try IXPHub(levelingSystemAddress).getLevelFromXP(xp) returns (uint8 lvl) {
                return uint16(lvl);
            } catch {}
        }
        // Fallback: tiered formula
        uint256 cumul = 0;
        for (uint16 i = 1; i <= 50; i++) {
            uint256 req;
            if (i <= 10) req = 50;
            else if (i <= 20) req = 100;
            else if (i <= 30) req = 150;
            else if (i <= 40) req = 200;
            else req = 250;
            cumul += req;
            if (xp <= cumul) return i;
        }
        return 50;
    }
    
    /**
     * @notice Get XP required for a specific level (uses LevelingSystem tiered formula).
     */
    function getXPForLevel(uint16 level) external pure override returns (uint256 xp) {
        if (level == 0) return 0;
        uint256 cumul = 0;
        for (uint16 i = 1; i <= level && i <= 50; i++) {
            if (i <= 10) cumul += 50;
            else if (i <= 20) cumul += 100;
            else if (i <= 30) cumul += 150;
            else if (i <= 40) cumul += 200;
            else cumul += 250;
        }
        return cumul;
    }
    
    // ============================================
    // VIEW FUNCTIONS - QUESTS & ACHIEVEMENTS
    // ============================================
    
    /**
     * @notice Get pending quest reward
     * @param user The user address
     * @param questId The quest identifier
     * @return reward The quest reward details
     */
    function getQuestReward(address user, uint256 questId) external view override returns (QuestReward memory reward) {
        return _questRewards[user][questId];
    }
    
    /**
     * @notice Get pending achievement reward
     * @param user The user address
     * @param achievementId The achievement identifier
     * @return reward The achievement reward details
     */
    function getAchievementReward(address user, uint256 achievementId) external view override returns (AchievementReward memory reward) {
        return _achievementRewards[user][achievementId];
    }
    
    /**
     * @notice Get all pending quest rewards for a user
     * @param user The user address
     * @return questIds Array of quest IDs
     * @return rewards Array of quest rewards
     */
    function getAllQuestRewards(address user) external view override returns (
        uint256[] memory questIds,
        QuestReward[] memory rewards
    ) {
        questIds = _userQuestIds[user];
        rewards = new QuestReward[](questIds.length);
        
        for (uint256 i = 0; i < questIds.length; i++) {
            rewards[i] = _questRewards[user][questIds[i]];
        }
    }
    
    /**
     * @notice Get all pending achievement rewards for a user
     * @param user The user address
     * @return achievementIds Array of achievement IDs
     * @return rewards Array of achievement rewards
     */
    function getAllAchievementRewards(address user) external view override returns (
        uint256[] memory achievementIds,
        AchievementReward[] memory rewards
    ) {
        achievementIds = _userAchievementIds[user];
        rewards = new AchievementReward[](achievementIds.length);
        
        for (uint256 i = 0; i < achievementIds.length; i++) {
            rewards[i] = _achievementRewards[user][achievementIds[i]];
        }
    }
    
    // ============================================
    // VIEW FUNCTIONS - AUTO-COMPOUND
    // ============================================
    
    /**
     * @notice Get auto-compound configuration for a user
     * @param user The user address
     * @return config The auto-compound configuration
     */
    function getAutoCompoundConfig(address user) external view override returns (AutoCompoundConfig memory config) {
        return _autoCompoundConfigs[user];
    }
    
    /**
     * @notice Get all users with auto-compound enabled (paginated)
     * @param offset Starting index
     * @param limit Maximum number of users to return
     * @return users Array of user addresses
     * @return configs Array of auto-compound configurations
     * @return total Total number of users with auto-compound enabled
     */
    function getAutoCompoundUsersPage(uint256 offset, uint256 limit) external view override returns (
        address[] memory users,
        AutoCompoundConfig[] memory configs,
        uint256 total
    ) {
        total = _autoCompoundUsers.length;
        
        if (offset >= total) {
            return (new address[](0), new AutoCompoundConfig[](0), total);
        }
        
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        
        uint256 resultLength = end - offset;
        users = new address[](resultLength);
        configs = new AutoCompoundConfig[](resultLength);
        
        for (uint256 i = 0; i < resultLength; i++) {
            users[i] = _autoCompoundUsers[offset + i];
            configs[i] = _autoCompoundConfigs[users[i]];
        }
    }
    
    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================
    
    /**
     * @notice Add user to auto-compound list
     * @param user The user address
     */
    function _addToAutoCompoundList(address user) internal {
        if (!_isInAutoCompoundList[user]) {
            _autoCompoundIndex[user] = _autoCompoundUsers.length;
            _autoCompoundUsers.push(user);
            _isInAutoCompoundList[user] = true;
        }
    }
    
    /**
     * @notice Remove user from auto-compound list
     * @param user The user address
     */
    function _removeFromAutoCompoundList(address user) internal {
        if (_isInAutoCompoundList[user]) {
            uint256 index = _autoCompoundIndex[user];
            uint256 lastIndex = _autoCompoundUsers.length - 1;
            
            if (index != lastIndex) {
                address lastUser = _autoCompoundUsers[lastIndex];
                _autoCompoundUsers[index] = lastUser;
                _autoCompoundIndex[lastUser] = index;
            }
            
            _autoCompoundUsers.pop();
            _isInAutoCompoundList[user] = false;
            delete _autoCompoundIndex[user];
        }
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS (Inherited from ISmartStakingGamification)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    event LevelUp(address indexed user, uint8 newLevel);

    /**
     * @notice Award a badge to a user
     * @param user The user address
     * @param id The badge ID
     * @param name The badge name
     * @param description The badge description
     */
    function awardBadge(address user, uint256 id, string memory name, string memory description) external onlyAuthorized {
        _userBadges[user].push(Badge({
            id: id,
            name: name,
            description: description,
            dateEarned: block.timestamp
        }));
        emit BadgeEarned(user, id, name);
    }

    /**
     * @notice Get user badges
     * @param user The user address
     * @return badges Array of user badges
     */
    function getUserBadges(address user) external view returns (Badge[] memory) {
        return _userBadges[user];
    }
    
    // ============================================
    // INTERNAL BADGE AUTOMATION
    // ============================================
    
    /**
     * @notice Check and award milestone badges automatically
     * @param user The user address
     * @param newLevel The new level reached
     */
    function _checkAndAwardBadges(address user, uint8 newLevel) internal {
        // Level Milestone Badges (max level is 50 in LevelingSystem)
        if (newLevel == 10 && !_hasBadge(user, "LEVEL_10")) {
            _awardBadgeInternal(user, 1, "Level 10 Achieved", "Reached level 10 milestone");
        }
        if (newLevel == 25 && !_hasBadge(user, "LEVEL_25")) {
            _awardBadgeInternal(user, 2, "Level 25 Pro", "Reached level 25 milestone");
        }
        if (newLevel == 50 && !_hasBadge(user, "LEVEL_50")) {
            _awardBadgeInternal(user, 3, "Level 50 Legend", "Reached maximum level 50");
        }
        
        // Quest-based badges
        uint256 questCount = _userQuestIds[user].length;
        if (questCount >= 10 && !_hasBadge(user, "QUEST_MASTER")) {
            _awardBadgeInternal(user, 10, "Quest Master", "Completed 10 quests");
        }
        
        if (questCount >= 50 && !_hasBadge(user, "QUEST_LEGEND")) {
            _awardBadgeInternal(user, 11, "Quest Legend", "Completed 50 quests");
        }
        
        // Achievement-based badges
        uint256 achievementCount = _userAchievementIds[user].length;
        if (achievementCount >= 5 && !_hasBadge(user, "ACHIEVER")) {
            _awardBadgeInternal(user, 20, "Achiever", "Unlocked 5 achievements");
        }
        
        if (achievementCount >= 20 && !_hasBadge(user, "ACHIEVEMENT_HUNTER")) {
            _awardBadgeInternal(user, 21, "Achievement Hunter", "Unlocked 20 achievements");
        }
    }
    
    /**
     * @notice Check if user has a specific badge
     * @param user The user address
     * @param badgeName The badge name identifier
     * @return has True if user has the badge
     */
    function _hasBadge(address user, string memory badgeName) internal view returns (bool) {
        bytes32 badgeHash = keccak256(bytes(badgeName));
        return _userHasBadge[user][badgeHash];
    }
    
    /**
     * @notice Internal function to award badge
     * @param user The user address
     * @param id The badge ID
     * @param name The badge name
     * @param description The badge description
     */
    function _awardBadgeInternal(address user, uint256 id, string memory name, string memory description) internal {
        bytes32 badgeHash = keccak256(bytes(name));
        
        // Prevent duplicate badges
        if (_userHasBadge[user][badgeHash]) return;
        
        _userHasBadge[user][badgeHash] = true;
        
        _userBadges[user].push(Badge({
            id: id,
            name: name,
            description: description,
            dateEarned: block.timestamp
        }));
        
        emit BadgeEarned(user, id, name);
    }
    
    /**
     * @notice Get total badges count for a user
     * @param user The user address
     * @return count Total badges earned
     */
    function getUserBadgeCount(address user) external view returns (uint256) {
        return _userBadges[user].length;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // v7.0 INTERFACE STUBS (defined in ISmartStakingGamification v2.0)
    // These are no-op / view-only stubs; full logic lives in contracts/Gamification/Gamification.sol
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc ISmartStakingGamification
    function claimDeferredReward() external override {}

    /// @inheritdoc ISmartStakingGamification
    function getUserStreak(address /*user*/) external pure override returns (
        uint32 streak,
        uint32 longestStreak,
        uint256 lastActivityDay
    ) {
        return (0, 0, 0);
    }

    /// @inheritdoc ISmartStakingGamification
    function effectiveXpMultiplier() external pure override returns (uint256 mult) {
        return 10_000; // 1× baseline
    }

    /// @inheritdoc ISmartStakingGamification
    function getProtocolStats() external pure override returns (
        uint256 totalXP,
        uint256 totalRewards,
        uint32  totalLevelUps,
        uint32  totalQuests,
        uint32  totalAchievements
    ) {
        return (0, 0, 0, 0, 0);
    }
}
