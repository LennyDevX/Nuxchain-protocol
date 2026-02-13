// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/ITreasuryManager.sol";
import "../interfaces/IBadgeManager.sol";

/**
 * @title CollaboratorBadgeRewards
 * @notice Manages quest rewards and commission pool for Collaborator Badge holders.
 * @dev Receives 25% of ALL protocol revenue (staking + marketplace + quest fees) via TreasuryManager.
 *      Badge holders earn passive income from entire ecosystem activity through automatic distributions.
 *      Quest rewards are funded by this integrated revenue stream for sustainable growth.
 * @custom:security-contact security@nuvo.com
 */
contract CollaboratorBadgeRewards is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    struct CollaboratorQuest {
        string description;
        uint256 rewardAmount;       // POL reward per completion
        uint256 startTime;
        uint256 endTime;
        bool active;
        uint256 completionCount;    // Track total completions
        uint256 maxCompletions;     // 0 = unlimited
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Quest wallet for admin-funded quest rewards
    address public questWallet;

    /// @notice Total commission received from NFT sales
    uint256 public totalCommissionReceived;

    /// @notice Total treasury allocation received
    uint256 public totalTreasuryReceived;

    /// @notice Total rewards paid out
    uint256 public totalRewardsPaid;

    /// @notice Active badge holder count
    uint256 public totalBadgeHolders;

    /// @notice Quest definitions
    mapping(uint256 => CollaboratorQuest) public quests;

    /// @notice User quest completion tracking
    mapping(address => mapping(uint256 => bool)) public questCompleted;

    /// @notice Claimable reward balance per user
    mapping(address => uint256) public pendingRewards;

    /// @notice Active quest IDs
    uint256[] public activeQuestIds;

    /// @notice Quest counter
    uint256 public nextQuestId;

    /// @notice Admin addresses that can manage quests
    mapping(address => bool) public questAdmins;

    /// @notice Treasury manager interface for fee distribution
    ITreasuryManager public treasuryManager;

    /// @notice Total rewards pending to be claimed (debt monitoring)
    uint256 public totalPendingRewards;

    /// @notice Max rewards allowed per quest completion to prevent misconfiguration
    uint256 public maxRewardLimit;

    /// @notice Max balance the contract should hold for security
    uint256 public maxBalanceLimit;

    /// @notice Badge manager for dynamic badge holder validation
    IBadgeManager public badgeManager;

    /// @notice Claim fee percentage (adjustable)
    uint256 public claimFeePercent;

    /// @notice Max pending rewards per user to prevent accumulation
    uint256 public maxPendingRewardsPerUser;

    /// @notice Track user contribution volume for tiered rewards
    mapping(address => uint256) public userContributionVolume;

    /// @notice Commission tier rates (volume threshold => fee BPS)
    mapping(uint256 => uint256) public commissionTiers;
    uint256[] public tierThresholds;

    /// @notice Constants for safety and fees
    uint256 public constant BATCH_LIMIT = 100;
    uint256 public constant MAX_BATCH_SIZE = 100;  // Alias for clarity
    uint256 public constant MAX_QUEST_DURATION = 365 days;
    uint256 private constant BPS_DENOMINATOR = 10000;
    uint256 private constant DEFAULT_CLAIM_FEE_BPS = 200; // 2%

    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    event QuestCreated(uint256 indexed questId, string description, uint256 reward, uint256 start, uint256 end);
    event QuestCompleted(address indexed user, uint256 indexed questId, uint256 reward);
    event QuestDeactivated(uint256 indexed questId);
    event RewardsClaimed(address indexed user, uint256 grossAmount, uint256 netAmount, uint256 fee);
    event CommissionReceived(uint256 amount);
    event TreasuryReceived(uint256 amount);
    event QuestWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event QuestAdminUpdated(address indexed admin, bool authorized);
    event BadgeHolderCountUpdated(uint256 newCount);
    event TreasuryManagerUpdated(address indexed newManager);
    event LimitsUpdated(uint256 maxReward, uint256 maxBalance);
    event BadgeManagerUpdated(address indexed newManager);
    event ClaimFeeUpdated(uint256 oldFee, uint256 newFee);
    event MaxPendingRewardsUpdated(uint256 newLimit);
    event CommissionTierUpdated(uint256 threshold, uint256 feeRate);
    event ContributionRecorded(address indexed user, uint256 volume);

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ════════════════════════════════════════════════════════════════════════════════════════

    error NotQuestAdmin();
    error QuestNotActive();
    error QuestAlreadyCompleted();
    error QuestExpired();
    error QuestNotStarted();
    error QuestMaxCompletions();
    error NoPendingRewards();
    error InsufficientBalance();
    error InvalidAddress();
    error TransferFailed();
    error InvalidBatchSize();
    error ExceedsMaxReward();
    error ExceedsMaxBalance();
    error QuestNotFound();
    error ExceedsMaxPendingRewards();
    error InvalidDuration();
    error InvalidTimestamp();
    error BadgeManagerNotSet();
    error QuestDurationTooLong();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ════════════════════════════════════════════════════════════════════════════════════════

    modifier onlyQuestAdmin() {
        if (!questAdmins[msg.sender] && msg.sender != owner()) revert NotQuestAdmin();
        _;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        questAdmins[msg.sender] = true;
        
        // Initial security limits (can be adjusted by owner)
        maxRewardLimit = 500 ether;
        maxBalanceLimit = 10000 ether;
        maxPendingRewardsPerUser = 1000 ether;
        claimFeePercent = DEFAULT_CLAIM_FEE_BPS;
        
        // Default commission tiers
        _setCommissionTier(0, 200);      // 0-10 ETH: 2%
        _setCommissionTier(10 ether, 150);   // 10+ ETH: 1.5%
        _setCommissionTier(50 ether, 100);   // 50+ ETH: 1%
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Receive ETH/POL from NFT sales commission or treasury
    receive() external payable {
        if (maxBalanceLimit > 0 && address(this).balance > maxBalanceLimit) revert ExceedsMaxBalance();
        totalCommissionReceived += msg.value;
        emit CommissionReceived(msg.value);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // QUEST MANAGEMENT (Admin)
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Create a new collaborator quest
     * @param _description Quest description
     * @param _rewardAmount Reward in POL per completion
     * @param _startTime Quest start timestamp
     * @param _endTime Quest end timestamp
     * @param _maxCompletions Max completions (0 = unlimited)
     */
    function createQuest(
        string calldata _description,
        uint256 _rewardAmount,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxCompletions
    ) external onlyQuestAdmin returns (uint256 questId) {
        // Strict timestamp validations
        if (_startTime < block.timestamp) revert InvalidTimestamp();
        if (_endTime <= _startTime) revert InvalidTimestamp();
        if ((_endTime - _startTime) > MAX_QUEST_DURATION) revert QuestDurationTooLong();
        
        require(_rewardAmount > 0, "Reward must be > 0");
        if (maxRewardLimit > 0 && _rewardAmount > maxRewardLimit) revert ExceedsMaxReward();

        questId = nextQuestId++;

        quests[questId] = CollaboratorQuest({
            description: _description,
            rewardAmount: _rewardAmount,
            startTime: _startTime,
            endTime: _endTime,
            active: true,
            completionCount: 0,
            maxCompletions: _maxCompletions
        });

        activeQuestIds.push(questId);

        emit QuestCreated(questId, _description, _rewardAmount, _startTime, _endTime);
    }

    /**
     * @notice Mark a quest as completed for a user (admin validates off-chain)
     * @param _user Badge holder address
     * @param _questId Quest ID to complete
     */
    function completeQuestForUser(
        address _user,
        uint256 _questId
    ) external onlyQuestAdmin {
        if (_user == address(0)) revert InvalidAddress();
        
        CollaboratorQuest storage quest = quests[_questId];
        
        // Validate quest exists (startTime > 0 means quest was created)
        if (quest.startTime == 0) revert QuestNotFound();
        if (!quest.active) revert QuestNotActive();
        if (questCompleted[_user][_questId]) revert QuestAlreadyCompleted();
        if (block.timestamp < quest.startTime) revert QuestNotStarted();
        if (block.timestamp > quest.endTime) revert QuestExpired();
        if (quest.maxCompletions > 0 && quest.completionCount >= quest.maxCompletions) {
            revert QuestMaxCompletions();
        }
        
        // Check max pending rewards per user
        uint256 newPending = pendingRewards[_user] + quest.rewardAmount;
        if (maxPendingRewardsPerUser > 0 && newPending > maxPendingRewardsPerUser) {
            revert ExceedsMaxPendingRewards();
        }

        questCompleted[_user][_questId] = true;
        quest.completionCount++;
        pendingRewards[_user] = newPending;
        totalPendingRewards += quest.rewardAmount;
        
        // Track contribution volume for tiered rewards
        userContributionVolume[_user] += quest.rewardAmount;
        emit ContributionRecorded(_user, userContributionVolume[_user]);

        emit QuestCompleted(_user, _questId, quest.rewardAmount);
    }

    /**
     * @notice Batch complete a quest for multiple users
     * @param _users Array of badge holder addresses
     * @param _questId Quest ID to complete
     */
    function batchCompleteQuest(
        address[] calldata _users,
        uint256 _questId
    ) external onlyQuestAdmin {
        if (_users.length == 0 || _users.length > BATCH_LIMIT) revert InvalidBatchSize();
        
        CollaboratorQuest storage quest = quests[_questId];
        
        // Validate quest exists
        if (quest.startTime == 0) revert QuestNotFound();
        if (!quest.active) revert QuestNotActive();
        if (block.timestamp < quest.startTime) revert QuestNotStarted();
        if (block.timestamp > quest.endTime) revert QuestExpired();

        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            if (user == address(0) || questCompleted[user][_questId]) continue;
            
            if (quest.maxCompletions > 0 && quest.completionCount >= quest.maxCompletions) {
                break;
            }
            
            // Check max pending rewards per user
            uint256 newPending = pendingRewards[user] + quest.rewardAmount;
            if (maxPendingRewardsPerUser > 0 && newPending > maxPendingRewardsPerUser) {
                continue; // Skip this user instead of reverting entire batch
            }
            
            questCompleted[user][_questId] = true;
            quest.completionCount++;
            pendingRewards[user] = newPending;
            totalPendingRewards += quest.rewardAmount;
            
            // Track contribution volume
            userContributionVolume[user] += quest.rewardAmount;
            emit ContributionRecorded(user, userContributionVolume[user]);

            emit QuestCompleted(user, _questId, quest.rewardAmount);
        }
    }

    /**
     * @notice Deactivate a quest
     * @param _questId Quest ID to deactivate
     */
    function deactivateQuest(uint256 _questId) external onlyQuestAdmin {
        quests[_questId].active = false;
        emit QuestDeactivated(_questId);
    }

    /**
     * @notice Update quest reward amount (for weekly adjustment)
     * @param _questId Quest ID
     * @param _newRewardAmount New reward amount
     */
    function updateQuestReward(uint256 _questId, uint256 _newRewardAmount) external onlyQuestAdmin {
        require(_newRewardAmount > 0, "Reward must be > 0");
        if (maxRewardLimit > 0 && _newRewardAmount > maxRewardLimit) revert ExceedsMaxReward();
        quests[_questId].rewardAmount = _newRewardAmount;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // USER FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Claim all pending rewards with tiered fee sent to Treasury
     */
    function claimRewards() external nonReentrant {
        uint256 grossAmount = pendingRewards[msg.sender];
        if (grossAmount == 0) revert NoPendingRewards();
        if (address(this).balance < grossAmount) revert InsufficientBalance();

        // Calculate fee based on user's contribution tier
        uint256 feeRate = _calculateCommissionTier(msg.sender);
        uint256 fee = (grossAmount * feeRate) / BPS_DENOMINATOR;
        uint256 netAmount = grossAmount - fee;

        // Effects
        pendingRewards[msg.sender] = 0;
        totalPendingRewards -= grossAmount;
        totalRewardsPaid += netAmount;

        // Interactions
        // 1. Send fee to TreasuryManager
        if (fee > 0 && address(treasuryManager) != address(0)) {
            try treasuryManager.receiveRevenue{value: fee}("quest_claim_fee") {
                // Fee successfully routed
            } catch {
                // If treasury fails, we revert to maintain accounting integrity
                revert TransferFailed();
            }
        }

        // 2. Send rewards to user
        (bool success, ) = payable(msg.sender).call{value: netAmount}("");
        if (!success) revert TransferFailed();

        emit RewardsClaimed(msg.sender, grossAmount, netAmount, fee);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    function setTreasuryManager(address _treasuryManager) external onlyOwner {
        if (_treasuryManager == address(0)) revert InvalidAddress();
        treasuryManager = ITreasuryManager(_treasuryManager);
        emit TreasuryManagerUpdated(_treasuryManager);
    }

    function setBadgeManager(address _badgeManager) external onlyOwner {
        if (_badgeManager == address(0)) revert InvalidAddress();
        badgeManager = IBadgeManager(_badgeManager);
        emit BadgeManagerUpdated(_badgeManager);
    }

    function setLimits(uint256 _maxReward, uint256 _maxBalance) external onlyOwner {
        maxRewardLimit = _maxReward;
        maxBalanceLimit = _maxBalance;
        emit LimitsUpdated(_maxReward, _maxBalance);
    }

    function setClaimFeePercent(uint256 _newFeePercent) external onlyOwner {
        require(_newFeePercent <= 1000, "Fee too high"); // Max 10%
        uint256 oldFee = claimFeePercent;
        claimFeePercent = _newFeePercent;
        emit ClaimFeeUpdated(oldFee, _newFeePercent);
    }

    function setMaxPendingRewardsPerUser(uint256 _newLimit) external onlyOwner {
        maxPendingRewardsPerUser = _newLimit;
        emit MaxPendingRewardsUpdated(_newLimit);
    }

    function setCommissionTier(uint256 threshold, uint256 feeRate) external onlyOwner {
        require(feeRate <= 1000, "Fee too high"); // Max 10%
        _setCommissionTier(threshold, feeRate);
        emit CommissionTierUpdated(threshold, feeRate);
    }

    /**
     * @notice Sync badge holder count from BadgeManager
     */
    function syncBadgeHolders() external onlyOwner {
        if (address(badgeManager) == address(0)) revert BadgeManagerNotSet();
        totalBadgeHolders = badgeManager.getTotalBadgeHolders();
        emit BadgeHolderCountUpdated(totalBadgeHolders);
    }

    /**
     * @notice Set quest wallet address for funding
     * @param _questWallet New quest wallet address
     */
    function setQuestWallet(address _questWallet) external onlyOwner {
        if (_questWallet == address(0)) revert InvalidAddress();
        address old = questWallet;
        questWallet = _questWallet;
        emit QuestWalletUpdated(old, _questWallet);
    }

    /**
     * @notice Set quest admin authorization
     * @param _admin Admin address
     * @param _authorized True to authorize
     */
    function setQuestAdmin(address _admin, bool _authorized) external onlyOwner {
        if (_admin == address(0)) revert InvalidAddress();
        questAdmins[_admin] = _authorized;
        emit QuestAdminUpdated(_admin, _authorized);
    }

    /**
     * @notice Update badge holder count (called by CoreV1 or admin)
     * @param _count New count
     */
    function updateBadgeHolderCount(uint256 _count) external onlyOwner {
        totalBadgeHolders = _count;
        emit BadgeHolderCountUpdated(_count);
    }

    /**
     * @notice Record treasury deposit (labeled)
     */
    function depositFromTreasury() external payable {
        if (maxBalanceLimit > 0 && address(this).balance > maxBalanceLimit) revert ExceedsMaxBalance();
        totalTreasuryReceived += msg.value;
        emit TreasuryReceived(msg.value);
    }

    /**
     * @notice Emergency withdraw by owner
     * @param _to Recipient address
     * @param _amount Amount to withdraw
     */
    function emergencyWithdraw(address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert InvalidAddress();
        require(_amount <= address(this).balance, "Insufficient balance");

        (bool success, ) = payable(_to).call{value: _amount}("");
        if (!success) revert TransferFailed();
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Calculate commission tier based on user's contribution volume
     * @param user User address
     * @return Fee rate in basis points
     */
    function _calculateCommissionTier(address user) internal view returns (uint256) {
        uint256 volume = userContributionVolume[user];
        
        // Find the highest tier the user qualifies for
        uint256 applicableFee = claimFeePercent;
        for (uint256 i = tierThresholds.length; i > 0; i--) {
            uint256 threshold = tierThresholds[i - 1];
            if (volume >= threshold) {
                applicableFee = commissionTiers[threshold];
                break;
            }
        }
        
        return applicableFee;
    }

    /**
     * @notice Internal function to set commission tier
     * @param threshold Volume threshold in wei
     * @param feeRate Fee rate in basis points
     */
    function _setCommissionTier(uint256 threshold, uint256 feeRate) internal {
        if (commissionTiers[threshold] == 0 && feeRate > 0) {
            // New tier, add to array
            tierThresholds.push(threshold);
            // Sort thresholds (simple bubble sort for small arrays)
            for (uint256 i = 0; i < tierThresholds.length - 1; i++) {
                for (uint256 j = 0; j < tierThresholds.length - i - 1; j++) {
                    if (tierThresholds[j] > tierThresholds[j + 1]) {
                        uint256 temp = tierThresholds[j];
                        tierThresholds[j] = tierThresholds[j + 1];
                        tierThresholds[j + 1] = temp;
                    }
                }
            }
        }
        commissionTiers[threshold] = feeRate;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Get reward summary for a badge holder
     * @param _user User address
     * @return pending Claimable amount
     * @return poolBalance Current contract balance
     * @return totalCommission Total commission from NFT sales
     * @return totalTreasury Total received from treasury
     */
    function getBadgeHolderRewardsSummary(address _user)
        external
        view
        returns (
            uint256 pending,
            uint256 poolBalance,
            uint256 totalCommission,
            uint256 totalTreasury
        )
    {
        return (
            pendingRewards[_user],
            address(this).balance,
            totalCommissionReceived,
            totalTreasuryReceived
        );
    }

    /**
     * @notice Get quest details
     * @param _questId Quest ID
     * @return Quest info
     */
    function getQuest(uint256 _questId) external view returns (CollaboratorQuest memory) {
        return quests[_questId];
    }

    /**
     * @notice Get all active quests
     * @return questIds Array of active quest IDs
     * @return questData Array of quest details
     */
    function getActiveQuests()
        external
        view
        returns (uint256[] memory questIds, CollaboratorQuest[] memory questData)
    {
        // Count active quests
        uint256 activeCount = 0;
        for (uint256 i = 0; i < activeQuestIds.length; i++) {
            if (quests[activeQuestIds[i]].active) {
                activeCount++;
            }
        }

        questIds = new uint256[](activeCount);
        questData = new CollaboratorQuest[](activeCount);

        uint256 idx = 0;
        for (uint256 i = 0; i < activeQuestIds.length; i++) {
            if (quests[activeQuestIds[i]].active) {
                questIds[idx] = activeQuestIds[i];
                questData[idx] = quests[activeQuestIds[i]];
                idx++;
            }
        }
    }

    /**
     * @notice Check if user completed a specific quest
     * @param _user User address
     * @param _questId Quest ID
     * @return True if completed
     */
    function hasCompletedQuest(address _user, uint256 _questId) external view returns (bool) {
        return questCompleted[_user][_questId];
    }

    /**
     * @notice Get contract stats summary
     */
    function getStats()
        external
        view
        returns (
            uint256 balance,
            uint256 pendingDebt,
            uint256 commission,
            uint256 treasury,
            uint256 paid,
            uint256 holders,
            uint256 questCount
        )
    {
        return (
            address(this).balance,
            totalPendingRewards,
            totalCommissionReceived,
            totalTreasuryReceived,
            totalRewardsPaid,
            totalBadgeHolders,
            nextQuestId
        );
    }

    /**
     * @notice Get user's contribution volume
     * @param user User address
     * @return Total contribution volume
     */
    function getUserContributionVolume(address user) external view returns (uint256) {
        return userContributionVolume[user];
    }

    /**
     * @notice Get contract health metrics
     * @return solvencyRatio Ratio of balance to pending debt (in BPS, 10000 = 100%)
     * @return isHealthy True if contract has sufficient funds
     * @return deficit Amount needed to cover all pending rewards (0 if healthy)
     */
    function getContractHealth() 
        external 
        view 
        returns (
            uint256 solvencyRatio,
            bool isHealthy,
            uint256 deficit
        ) 
    {
        uint256 balance = address(this).balance;
        uint256 pending = totalPendingRewards;
        
        if (pending == 0) {
            return (BPS_DENOMINATOR, true, 0);
        }
        
        solvencyRatio = (balance * BPS_DENOMINATOR) / pending;
        isHealthy = balance >= pending;
        deficit = isHealthy ? 0 : pending - balance;
    }

    /**
     * @notice Get the claim fee that would be charged for a user
     * @param user User address
     * @return Fee rate in basis points
     */
    function getClaimFeeForUser(address user) external view returns (uint256) {
        return _calculateCommissionTier(user);
    }

    /**
     * @notice Get all commission tier thresholds and rates
     * @return thresholds Array of volume thresholds
     * @return rates Array of corresponding fee rates in BPS
     */
    function getAllCommissionTiers() 
        external 
        view 
        returns (
            uint256[] memory thresholds,
            uint256[] memory rates
        ) 
    {
        thresholds = tierThresholds;
        rates = new uint256[](tierThresholds.length);
        
        for (uint256 i = 0; i < tierThresholds.length; i++) {
            rates[i] = commissionTiers[tierThresholds[i]];
        }
    }

    /// @dev Adjusted storage gap (original 50 - 14 new slots = 36)
    /// New variables: treasuryManager, totalPendingRewards, maxRewardLimit, maxBalanceLimit,
    /// badgeManager, claimFeePercent, maxPendingRewardsPerUser, userContributionVolume (mapping),
    /// commissionTiers (mapping), tierThresholds (array)
    /// Note: Mappings don't consume sequential slots, but we account for state variables
    uint256[36] private __gap;
}
