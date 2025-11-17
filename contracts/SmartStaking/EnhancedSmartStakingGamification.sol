// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEnhancedSmartStakingGamification.sol";

/**
 * @title EnhancedSmartStakingGamification
 * @notice Handles gamification features: XP, levels, quests, achievements, and auto-compound
 * @dev This module manages user progression and reward mechanics
 */
contract EnhancedSmartStakingGamification is Ownable, IEnhancedSmartStakingGamification {
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    /// @notice XP per level (every 1000 XP = 1 level)
    uint256 private constant XP_PER_LEVEL = 1000;
    
    /// @notice Maximum XP (1M = level 1000)
    uint256 private constant MAX_XP = 1000000;
    
    /// @notice Reward expiration period (30 days default)
    uint256 private constant REWARD_EXPIRATION = 30 days;
    
    /// @notice Auto-compound check interval (24 hours)
    uint256 private constant AUTO_COMPOUND_INTERVAL = 1 days;
    
    /// @notice Minimum compound amount (0.01 ether)
    uint256 private constant MIN_COMPOUND_AMOUNT = 0.01 ether;
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /// @notice Address of the marketplace contract (authorized caller)
    address public marketplaceContract;
    
    /// @notice Address of the core staking contract
    address public coreStakingContract;
    
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

        // Calculate XP based on action type
        if (actionType == 0) {
            // Stake: 1 XP per 0.1 ether
            xpGained = (amount * 10) / 1 ether;
        } else if (actionType == 1) {
            // Compound: 2 XP per 0.1 ether
            xpGained = (amount * 2) / 0.1 ether;
        } else if (actionType == 2) {
            // Quest: Fixed 100 XP
            xpGained = 100;
        } else if (actionType == 3) {
            // Achievement: Fixed 250 XP
            xpGained = 250;
        }

        // Add XP with cap
        uint256 newXP = _userXP[user] + xpGained;
        if (newXP > MAX_XP) {
            newXP = MAX_XP;
        }
        _userXP[user] = newXP;

        // Calculate new level
        uint16 newLevel = uint16(newXP / XP_PER_LEVEL);
        uint16 oldLevel = _userLevel[user];

        if (newLevel > oldLevel) {
            _userLevel[user] = newLevel;
        }

        emit XPUpdated(user, newXP, newLevel);
    }
    
    /**
     * @notice Manually set XP for a user (admin only)
     * @param user The user address
     * @param xp The XP amount to set
     */
    function setUserXP(address user, uint256 xp) external override onlyOwner {
        require(xp <= MAX_XP, "XP exceeds max");
        _userXP[user] = xp;
        _userLevel[user] = uint16(xp / XP_PER_LEVEL);
        
        emit XPUpdated(user, xp, _userLevel[user]);
    }
    
    // ============================================
    // QUEST FUNCTIONS
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
    ) external override onlyMarketplace {
        require(_questRewards[user][questId].amount == 0, "Quest already completed");
        
        _questRewards[user][questId] = QuestReward({
            amount: rewardAmount,
            expirationTime: block.timestamp + (expirationDays * 1 days),
            claimed: false
        });
        
        _userQuestIds[user].push(questId);
        
        // Award XP
        _updateUserXP(user, 2, 0);
        
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
        
        // Would need to query rewards from core contract
        // For now, return placeholder
        compoundAmount = 0; // Core would provide this
        shouldCompound = compoundAmount >= config.minAmount;
    }
    
    /**
     * @notice Perform auto-compound for a user (Chainlink Keeper compatible)
     * @param user The user address
     */
    function performAutoCompound(address user) external override onlyCore {
        AutoCompoundConfig storage config = _autoCompoundConfigs[user];
        
        require(config.enabled, "Auto-compound not enabled");
        
        config.lastCompoundTime = block.timestamp;
        
        // Core contract would handle the actual compounding
        // This just updates the timestamp
        
        emit AutoCompoundExecuted(user, 0); // Amount would come from core
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
        xpToNextLevel = ((level + 1) * XP_PER_LEVEL) - xp;
    }
    
    /**
     * @notice Calculate level from XP amount
     * @param xp The XP amount
     * @return level The calculated level
     */
    function calculateLevel(uint256 xp) external pure override returns (uint16 level) {
        return uint16(xp / XP_PER_LEVEL);
    }
    
    /**
     * @notice Get XP required for a specific level
     * @param level The target level
     * @return xp The XP required
     */
    function getXPForLevel(uint16 level) external pure override returns (uint256 xp) {
        return uint256(level) * XP_PER_LEVEL;
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
}
