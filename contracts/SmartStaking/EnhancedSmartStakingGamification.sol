// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEnhancedSmartStakingGamification.sol";
import "../interfaces/ITreasuryManager.sol";
import "../interfaces/IStakingIntegration.sol";

/**
 * @title EnhancedSmartStakingGamification
 * @notice Handles gamification features: XP, levels, quests, achievements, and auto-compound
 * @dev This module manages user progression and reward mechanics
 */
contract EnhancedSmartStakingGamification is Ownable, IEnhancedSmartStakingGamification {
    
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
    
    /// @notice Maps user address to their XP
    mapping(address => uint256) private _userXP;
    
    /// @notice Maps user address to their level
    mapping(address => uint16) private _userLevel;
    
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

    event RewardPaid(address indexed user, uint256 amount);
    event RewardDeferred(address indexed user, uint16 level, uint256 amount, string reason);
    event BadgeEarned(address indexed user, uint256 badgeId, string name);
    event TreasuryManagerUpdated(address indexed oldAddress, address indexed newAddress);
    
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
    // XP & LEVEL FUNCTIONS
    // ============================================
    
    /**
     * @notice Update user XP and level based on action
     * @param user The user address
     * @param actionType The type of action (0=stake, 1=compound, 2=quest, 3=achievement)
     * @param amount The amount involved in the action
     */
    function updateUserXP(address user, uint8 actionType, uint256 amount) external override onlyAuthorized {
        _updateUserXP(user, actionType, amount);
    }

    // Internal helper to update XP (used by external and internal callers)
    function _updateUserXP(address user, uint8 actionType, uint256 amount) internal {
        uint256 xpGained = 0;

        // Calculate XP based on action type - REDUCED RATES FOR STABILITY
        if (actionType == 0) {
            // Stake: 1 XP per 2 POL (reduced for stability, motivates larger deposits)
            xpGained = amount / (STAKING_XP_DIVISOR * 1 ether);
            require(xpGained > 0, "Stake amount too small for XP");
        } else if (actionType == 1) {
            // Compound: 3 XP fixed (reduced from 5)
            xpGained = COMPOUND_XP;
        } else if (actionType == 2) {
            // Quest: Dynamic 10-25 XP (passed via amount parameter)
            require(amount >= MIN_QUEST_XP && amount <= MAX_QUEST_XP, "Quest XP out of range (10-25)");
            xpGained = amount;
        } else if (actionType == 3) {
            // Achievement: Fixed 100 XP (reduced from 200)
            xpGained = ACHIEVEMENT_XP;
        }

        // Add XP
        uint256 newXP = _userXP[user] + xpGained;
        _userXP[user] = newXP;

        // Calculate new level using Exponential Formula: Level = Sqrt(XP / 50)
        uint16 newLevel = 0;
        if (newXP >= XP_BASE) {
            newLevel = uint16(_sqrt(newXP / XP_BASE));
        }
        
        if (newLevel > MAX_LEVEL_CAP) {
            newLevel = uint16(MAX_LEVEL_CAP);
        }

        uint16 oldLevel = _userLevel[user];

        if (newLevel > oldLevel) {
            _userLevel[user] = newLevel;
            emit LevelUp(user, newLevel);
            _distributeLevelUpReward(user, newLevel);
            
            // Award milestone badges automatically
            _checkAndAwardBadges(user, newLevel);
        }

        emit XPUpdated(user, newXP, newLevel);
    }

    function _distributeLevelUpReward(address user, uint16 newLevel) internal {
        // Calculate reward based on LevelingSystem formula (1-5 POL per level)
        uint256 rewardAmount = _calculateLevelUpReward(newLevel);

        // Try to pay from contract balance first
        if (address(this).balance >= rewardAmount) {
            (bool success, ) = payable(user).call{value: rewardAmount}("");
            if (success) {
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
                        emit RewardPaid(user, rewardAmount);
                        return;
                    }
                }
            } catch {
                // Treasury request failed
            }
        }
        
        // Reward deferred - insufficient funds
        emit RewardDeferred(user, newLevel, rewardAmount, "Insufficient funds in contract and treasury");
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
    function _calculateLevelUpReward(uint16 level) internal pure returns (uint256) {
        if (level <= 10) return 1 ether;
        if (level <= 20) return 2 ether;
        if (level <= 30) return 3 ether;
        if (level <= 40) return 4 ether;
        return 5 ether; // Max cap at level 41-50
    }
    
    /**
     * @notice Manually set XP for a user (admin only)
     * @param user The user address
     * @param xp The XP amount to set
     */
    function setUserXP(address user, uint256 xp) external override onlyOwner {
        _userXP[user] = xp;
        
        uint16 newLevel = 0;
        if (xp >= XP_BASE) {
            newLevel = uint16(_sqrt(xp / XP_BASE));
        }
        if (newLevel > MAX_LEVEL_CAP) {
            newLevel = uint16(MAX_LEVEL_CAP);
        }
        
        _userLevel[user] = newLevel;
        
        emit XPUpdated(user, xp, newLevel);
    }

    /**
     * @dev Internal square root function
     */
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    
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
    ) external override onlyMarketplace {
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
     * @param questId The quest identifier
     */
    function claimQuestReward(uint256 questId) external override {
        QuestReward storage reward = _questRewards[msg.sender][questId];
        
        require(reward.amount > 0, "No reward");
        require(!reward.claimed, "Already claimed");
        require(block.timestamp <= reward.expirationTime, "Reward expired");
        
        reward.claimed = true;
        
        // Transfer would be handled by core contract
        // This just marks as claimed
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
    ) external override onlyMarketplace {
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
     * @param achievementId The achievement identifier
     */
    function claimAchievementReward(uint256 achievementId) external override {
        AchievementReward storage reward = _achievementRewards[msg.sender][achievementId];
        
        require(reward.amount > 0, "No reward");
        require(!reward.claimed, "Already claimed");
        require(block.timestamp <= reward.expirationTime, "Reward expired");
        
        reward.claimed = true;
        
        // Transfer would be handled by core contract
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
            try IStakingIntegration(coreStakingContract).getUserSkillProfile(user) {
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
     * @param users Array of user addresses
     */
    function batchAutoCompound(address[] calldata users) external override onlyCore {
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
     * @notice Get user XP and level
     * @param user The user address
     * @return xp Current XP
     * @return level Current level
     * @return xpToNextLevel XP needed for next level
     */
    function getUserXPInfo(address user) external view override returns (
        uint256 xp,
        uint16 level,
        uint256 xpToNextLevel
    ) {
        xp = _userXP[user];
        level = _userLevel[user];
        
        // Next level XP = 50 * (level + 1)^2
        uint256 nextLevel = level + 1;
        uint256 nextLevelXP = XP_BASE * (nextLevel * nextLevel);
        
        if (xp >= nextLevelXP) {
            xpToNextLevel = 0;
        } else {
            xpToNextLevel = nextLevelXP - xp;
        }
    }
    
    /**
     * @notice Calculate level from XP amount
     * @param xp The XP amount
     * @return level The calculated level
     */
    function calculateLevel(uint256 xp) external pure override returns (uint16 level) {
        if (xp < XP_BASE) return 0;
        level = uint16(_sqrt(xp / XP_BASE));
        if (level > MAX_LEVEL_CAP) level = uint16(MAX_LEVEL_CAP);
        return level;
    }
    
    /**
     * @notice Get XP required for a specific level
     * @param level The target level
     * @return xp The XP required
     */
    function getXPForLevel(uint16 level) external pure override returns (uint256 xp) {
        return XP_BASE * (uint256(level) * uint256(level));
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
    // EVENTS (Inherited from IEnhancedSmartStakingGamification)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    event LevelUp(address indexed user, uint16 newLevel);

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
    function _checkAndAwardBadges(address user, uint16 newLevel) internal {
        // Level Milestone Badges
        if (newLevel == 10 && !_hasBadge(user, "LEVEL_10")) {
            _awardBadgeInternal(user, 1, "Level 10 Achieved", "Reached level 10 milestone");
        }
        
        if (newLevel == 25 && !_hasBadge(user, "LEVEL_25")) {
            _awardBadgeInternal(user, 2, "Level 25 Pro", "Reached level 25 milestone");
        }
        
        if (newLevel == 50 && !_hasBadge(user, "LEVEL_50")) {
            _awardBadgeInternal(user, 3, "Level 50 Legend", "Reached maximum level 50");
        }
        
        if (newLevel == 100 && !_hasBadge(user, "LEVEL_100")) {
            _awardBadgeInternal(user, 4, "Level 100 Master", "Reached ultimate level 100");
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
}
