// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IXPHub.sol";

/**
 * @title LevelingSystem
 * @dev Singleton XP hub for the entire Nuxchain Protocol (implements IXPHub).
 * - 250 levels split into 10 progression brackets of 25 levels each
 * - XP per level scales by bracket: 50, 100, 150 ... 500 XP
 * - Total: 68 750 XP to reach Level 250
 * - Native rewards scale conservatively from 0.05 POL to 0.5 POL
 * - Tracks per-source XP breakdown for frontend dashboards
 * - All protocol contracts call awardXP() (REPORTER_ROLE) or updateUserXP() (MARKETPLACE_ROLE)
 */
contract LevelingSystem is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IXPHub {
    bytes32 public constant ADMIN_ROLE       = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE    = keccak256("UPGRADER_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");
    /// @notice Granted to SmartStakingGamification, Auction, NuxPower, Referral, etc.
    bytes32 public constant REPORTER_ROLE    = keccak256("REPORTER_ROLE");

    // XP and level constants
    uint8 private constant MAX_LEVEL = 250;
    uint8 private constant LEVELS_PER_BRACKET = 25;
    uint8 private constant BRACKET_COUNT = 10;
    uint256 private constant XP_PER_BRACKET_STEP = 50;
    uint256 private constant MAX_XP_TOTAL = 68_750;
    
    // Dynamic level-up reward system.
    // Reward tier increases every 25 levels and remains conservatively capped.
    uint256 private constant MIN_LEVEL_REWARD = 0.05 ether;
    uint256 private constant MAX_LEVEL_REWARD = 0.5 ether;
    uint256 private constant LEVEL_REWARD_STEP = 0.05 ether;
    
    // Batch NFT Creation XP Constants
    uint256 private constant BASE_NFT_XP = 10;
    uint256 private constant MAX_BATCH_XP = 250; // Cap per batch
    uint256 private constant DAILY_XP_CAP = 1000; // Daily limit per user
    uint256 private constant BATCH_SCALE_DIVISOR = 500; // For scaling formula

    struct Badge {
        uint256 id;
        string name;
        string description;
        uint256 dateEarned;
    }

    mapping(address => UserProfile) public userProfiles;
    mapping(address => uint256) public dailyXPGained;
    mapping(address => uint256) public lastXPDay;
    mapping(address => Badge[]) public userBadges;
    mapping(address => uint256) public deferredRewardAmount;
    mapping(address => uint256) public deferredRewardTime;

    /// @notice Per-user XP breakdown by source (indexed by uint8(IXPHub.XPSource)).
    mapping(address => uint256[15]) private _xpBySource;

    uint256 public totalPendingRewards;

    event XPGained(address indexed user, uint256 amount, string reason);  // backward-compat
    event LevelUp(address indexed user, uint8 newLevel);
    event RewardPaid(address indexed user, uint256 amount);
    event RewardDeferred(address indexed user, uint8 level, uint256 amount, string reason);
    event DeferredRewardClaimed(address indexed user, uint256 amount);
    event BadgeEarned(address indexed user, uint256 badgeId, string name);
    event NFTCreated(address indexed creator);
    event NFTOwned(address indexed owner);
    event NFTSold(address indexed seller);
    event NFTBought(address indexed buyer);
    // IXPHub.XPAwarded is inherited — emitted by awardXP() path

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    function initialize(address platformAdmin) public initializer {
        require(platformAdmin != address(0), "Invalid platform admin");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, platformAdmin);
        _grantRole(ADMIN_ROLE, platformAdmin);
        _grantRole(UPGRADER_ROLE, platformAdmin);
        _grantRole(MARKETPLACE_ROLE, platformAdmin);
        _grantRole(REPORTER_ROLE, platformAdmin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function _calculateLevelUpReward(uint8 level) internal pure returns (uint256) {
        return getRewardForLevel(level);
    }

    /// @inheritdoc IXPHub
    function getXPRequiredForLevel(uint8 _level) public pure returns (uint256) {
        require(_level >= 1 && _level <= MAX_LEVEL, "Invalid level");

        uint256 bracket = ((uint256(_level) - 1) / LEVELS_PER_BRACKET) + 1;
        return bracket * XP_PER_BRACKET_STEP;
    }

    /// @inheritdoc IXPHub
    function getCumulativeXPForLevel(uint8 _level) public pure returns (uint256 cumulativeXP) {
        require(_level <= MAX_LEVEL, "Invalid level");
        if (_level == 0) {
            return 0;
        }

        uint256 bracket = ((uint256(_level) - 1) / LEVELS_PER_BRACKET) + 1;
        uint256 completedBrackets = bracket - 1;
        uint256 levelsBeforeBracket = completedBrackets * LEVELS_PER_BRACKET;
        uint256 xpBeforeBracket = XP_PER_BRACKET_STEP * LEVELS_PER_BRACKET * completedBrackets * bracket / 2;
        uint256 levelsInCurrentBracket = uint256(_level) - levelsBeforeBracket;

        return xpBeforeBracket + (levelsInCurrentBracket * bracket * XP_PER_BRACKET_STEP);
    }

    /// @inheritdoc IXPHub
    function getRewardForLevel(uint8 level) public pure returns (uint256 rewardAmount) {
        require(level >= 1 && level <= MAX_LEVEL, "Invalid level");

        uint256 rewardTier = ((uint256(level) - 1) / LEVELS_PER_BRACKET) + 1;
        rewardAmount = rewardTier * LEVEL_REWARD_STEP;
        if (rewardAmount > MAX_LEVEL_REWARD) {
            rewardAmount = MAX_LEVEL_REWARD;
        }
        if (rewardAmount < MIN_LEVEL_REWARD) {
            rewardAmount = MIN_LEVEL_REWARD;
        }
    }

    /**
     * @dev Calculate level from total XP.
     * Returns level 0-250 based on cumulative XP.
     */
    function getLevelFromXP(uint256 _totalXP) public pure returns (uint8) {
        if (_totalXP < XP_PER_BRACKET_STEP) return 0;

        uint256 remainingXP = _totalXP;
        for (uint256 bracket = 1; bracket <= BRACKET_COUNT; bracket++) {
            uint256 xpPerLevel = bracket * XP_PER_BRACKET_STEP;
            uint256 bracketXP = xpPerLevel * LEVELS_PER_BRACKET;
            if (remainingXP <= bracketXP) {
                return uint8(((bracket - 1) * LEVELS_PER_BRACKET) + (remainingXP / xpPerLevel));
            }
            remainingXP -= bracketXP;
        }

        return MAX_LEVEL;
    }

    /**
     * @dev Internal function to update user XP and emit events.
     * @param user           Recipient.
     * @param xpAmount       XP to award.
     * @param reason         String reason (for backward-compat XPGained event).
     * @param source         XP source index (255 = untracked/legacy).
     * @param distributeReward  Whether to trigger POL level-up reward payout.
     * @return leveledUp     True if user reached a new level.
     * @return newLvl        The new level (0 if no level-up).
     */
    function _updateUserXP(
        address user,
        uint256 xpAmount,
        string memory reason,
        uint8 source,
        bool distributeReward
    ) internal returns (bool leveledUp, uint8 newLvl) {
        require(user != address(0), "Invalid user");
        require(xpAmount > 0, "Invalid XP amount");

        UserProfile storage profile = userProfiles[user];
        uint8 oldLevel = profile.level;

        // Add XP, capped at MAX_XP_TOTAL
        uint256 newTotalXP = profile.totalXP + xpAmount;
        if (newTotalXP > MAX_XP_TOTAL) {
            newTotalXP = MAX_XP_TOTAL;
        }
        profile.totalXP = newTotalXP;

        // Track per-source breakdown (only for known sources)
        if (source < 15) {
            _xpBySource[user][source] += xpAmount;
        }

        // Calculate new level
        uint8 newLevel = getLevelFromXP(newTotalXP);
        profile.level = newLevel;

        // Emit appropriate event
        if (source < 15) {
            emit XPAwarded(user, xpAmount, source, newTotalXP, block.timestamp);
        } else {
            emit XPGained(user, xpAmount, reason);
        }

        if (newLevel > oldLevel) {
            emit LevelUp(user, newLevel);
            if (distributeReward) {
                _distributeLevelUpReward(user, newLevel);
            }
            return (true, newLevel);
        }
        return (false, 0);
    }

    /// @dev 3-arg convenience overload — source=255 (untracked), distributeReward=true
    function _updateUserXP(address user, uint256 xpAmount, string memory reason)
        internal returns (bool leveledUp, uint8 newLvl)
    {
        return _updateUserXP(user, xpAmount, reason, 255, true);
    }

    function _distributeLevelUpReward(address user, uint8 newLevel) internal {
        // Calculate reward based on new level reached
        uint256 levelReward = _calculateLevelUpReward(newLevel);
        if (address(this).balance >= totalPendingRewards + levelReward) {
            (bool success, ) = payable(user).call{value: levelReward}("");
            if (success) {
                emit RewardPaid(user, levelReward);
                return;
            }

            _deferLevelUpReward(user, newLevel, levelReward, "Transfer failed");
            return;
        }

        _deferLevelUpReward(user, newLevel, levelReward, "Insufficient funds");
    }

    function claimDeferredReward() external {
        uint256 amount = deferredRewardAmount[msg.sender];
        require(amount > 0, "LevelingSystem: no deferred reward");
        require(address(this).balance >= amount, "LevelingSystem: insufficient balance");

        deferredRewardAmount[msg.sender] = 0;
        deferredRewardTime[msg.sender] = 0;
        totalPendingRewards -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            deferredRewardAmount[msg.sender] = amount;
            deferredRewardTime[msg.sender] = block.timestamp;
            totalPendingRewards += amount;
            revert("LevelingSystem: reward transfer failed");
        }

        emit DeferredRewardClaimed(msg.sender, amount);
        emit RewardPaid(msg.sender, amount);
    }

    /**
     * @dev External function to update user XP (backward-compatible, MARKETPLACE_ROLE).
     *      Triggers level-up POL reward distribution.
     */
    function updateUserXP(address user, uint256 xpAmount, string calldata reason)
        external
        onlyRole(MARKETPLACE_ROLE)
    {
        _updateUserXP(user, xpAmount, reason, 255, true); // 255 = untracked source
    }

    /// @inheritdoc IXPHub
    function adminSetUserXP(address user, uint256 totalXP) external onlyRole(ADMIN_ROLE) {
        require(user != address(0), "LevelingSystem: zero address");

        UserProfile storage profile = userProfiles[user];
        uint8 oldLevel = profile.level;
        uint256 cappedXP = totalXP > MAX_XP_TOTAL ? MAX_XP_TOTAL : totalXP;
        uint8 newLevel = getLevelFromXP(cappedXP);

        profile.totalXP = cappedXP;
        profile.level = newLevel;

        emit XPGained(user, cappedXP, "ADMIN_SET_XP");
        if (newLevel > oldLevel) {
            emit LevelUp(user, newLevel);
        }
    }

    /**
     * @dev Get user profile
     */
    function getUserProfile(address user) 
        external 
        view 
        returns (UserProfile memory) 
    {
        return userProfiles[user];
    }

    /**
     * @dev Get user profile with current level calculation
     */
    function getUserProfileDetailed(address user) 
        external 
        view 
        returns (
            uint256 totalXP,
            uint8 level,
            uint256 nftsCreated,
            uint256 nftsOwned,
            uint32 nftsSold,
            uint32 nftsBought,
            uint256 xpForCurrentLevel,
            uint256 xpForNextLevel
        ) 
    {
        UserProfile memory profile = userProfiles[user];
        uint256 currentLevelXP = profile.level > 1 ? getCumulativeXPForLevel(profile.level - 1) : 0;
        uint256 nextLevelXP = profile.level < MAX_LEVEL ? getCumulativeXPForLevel(profile.level + 1) : currentLevelXP;
        
        return (
            profile.totalXP,
            profile.level,
            profile.nftsCreated,
            profile.nftsOwned,
            profile.nftsSold,
            profile.nftsBought,
            currentLevelXP,
            nextLevelXP
        );
    }

    /**
     * @dev Record NFT created (single)
     */
    function recordNFTCreated(address creator) external onlyRole(MARKETPLACE_ROLE) {
        require(creator != address(0), "Invalid creator");
        userProfiles[creator].nftsCreated++;
        _updateUserXP(creator, BASE_NFT_XP, "NFT_CREATED", uint8(IXPHub.XPSource.NFT_CREATE), true);
        emit NFTCreated(creator);
    }

    /**
     * @dev Record batch NFT creation with scaled XP rewards
     * @param creator Address of the NFT creator
     * @param count Number of NFTs created in the batch
     * @return xpAwarded Total XP awarded for this batch
     * 
     * Formula: baseXP * count * min(1.5, 1 + count/500)
     * - Encourages batch creation with diminishing returns
     * - Cap: 250 XP per batch (prevents abuse)
     * - Daily Cap: 1000 XP per user (anti-farming)
     * 
     * Examples:
     * - 1 NFT: 10 XP (same as single)
     * - 50 NFTs: 10 * 50 * 1.1 = 550 → capped to 250 XP
     * - 250 NFTs: 10 * 250 * 1.5 = 3750 → capped to 250 XP
     * - 500 NFTs: 10 * 500 * 2.0 = 10000 → capped to 250 XP
     */
    function recordNFTCreatedBatch(address creator, uint256 count) 
        external 
        onlyRole(MARKETPLACE_ROLE) 
        returns (uint256) 
    {
        require(creator != address(0), "Invalid creator");
        require(count > 0 && count <= 500, "Invalid count");
        
        // Reset daily tracking if new day
        uint256 currentDay = block.timestamp / 1 days;
        if (lastXPDay[creator] != currentDay) {
            dailyXPGained[creator] = 0;
            lastXPDay[creator] = currentDay;
        }
        
        // Calculate scaled XP with formula: baseXP * count * scaleFactor
        // scaleFactor = min(1.5, 1 + count/500)
        uint256 scaleFactor = 10000 + (count * 10000) / BATCH_SCALE_DIVISOR; // In basis points
        if (scaleFactor > 15000) scaleFactor = 15000; // Cap at 1.5x
        
        uint256 rawXP = (BASE_NFT_XP * count * scaleFactor) / 10000;
        
        // Apply batch cap
        uint256 batchXP = rawXP > MAX_BATCH_XP ? MAX_BATCH_XP : rawXP;
        
        // Check daily cap
        uint256 availableDailyXP = dailyXPGained[creator] < DAILY_XP_CAP 
            ? DAILY_XP_CAP - dailyXPGained[creator] 
            : 0;
            
        uint256 xpToAward = batchXP > availableDailyXP ? availableDailyXP : batchXP;
        
        // If XP is being capped, still allow at least BASE_NFT_XP
        if (xpToAward == 0 && availableDailyXP > 0) {
            xpToAward = availableDailyXP >= BASE_NFT_XP ? BASE_NFT_XP : availableDailyXP;
        }
        
        // Update profile and daily tracking
        if (xpToAward > 0) {
            userProfiles[creator].nftsCreated += count;
            dailyXPGained[creator] += xpToAward;
            _updateUserXP(creator, xpToAward, "NFT_CREATED_BATCH", uint8(IXPHub.XPSource.NFT_CREATE), true);
        }
        
        emit NFTCreated(creator);
        return xpToAward;
    }

    /**
     * @dev Record NFT owned (transfer)
     */
    function recordNFTOwned(address owner) external onlyRole(MARKETPLACE_ROLE) {
        require(owner != address(0), "Invalid owner");
        userProfiles[owner].nftsOwned++;
        emit NFTOwned(owner);
    }

    /**
     * @dev Record NFT sold
     */
    function recordNFTSold(address seller) external onlyRole(MARKETPLACE_ROLE) {
        require(seller != address(0), "Invalid seller");
        userProfiles[seller].nftsSold++;
        _updateUserXP(seller, 20, "NFT_SOLD", uint8(IXPHub.XPSource.MARKETPLACE_SELL), true);
        emit NFTSold(seller);
    }

    /**
     * @dev Record NFT bought
     */
    function recordNFTBought(address buyer) external onlyRole(MARKETPLACE_ROLE) {
        require(buyer != address(0), "Invalid buyer");
        userProfiles[buyer].nftsBought++;
        _updateUserXP(buyer, 15, "NFT_BOUGHT", uint8(IXPHub.XPSource.MARKETPLACE_BUY), true);
        emit NFTBought(buyer);
    }

    /**
     * @dev Directly update profile stats (for market operations)
     */
    function incrementNftsOwned(address user) external onlyRole(MARKETPLACE_ROLE) {
        require(user != address(0), "Invalid user");
        userProfiles[user].nftsOwned++;
    }

    /**
     * @dev Simple XP addition (MiniGame / legacy callers). Tracked as AGENT_TASK source.
     */
    function addXP(address user, uint256 amount) external onlyRole(MARKETPLACE_ROLE) {
        require(user != address(0), "Invalid user");
        require(amount > 0, "Invalid amount");
        _updateUserXP(user, amount, "DIRECT_XP", uint8(IXPHub.XPSource.AGENT_TASK), true);
    }

    // ════════════════════════════════════════════════════════════════════════════════════
    // IXPHub IMPLEMENTATION
    // ════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Award XP with source tracking (REPORTER_ROLE callers: Staking, Auction, etc).
     *         Does NOT trigger level-up POL reward — caller is responsible.
     */
    function awardXP(address user, uint256 amount, IXPHub.XPSource source)
        external
        onlyRole(REPORTER_ROLE)
        returns (bool leveledUp, uint8 newLevel)
    {
        require(user != address(0), "LevelingSystem: zero address");
        require(amount > 0, "LevelingSystem: zero XP");
        return _updateUserXP(user, amount, "", uint8(source), false);
    }

    /// @inheritdoc IXPHub
    function getUserXP(address user) external view returns (uint256 totalXP, uint8 level) {
        UserProfile storage p = userProfiles[user];
        return (p.totalXP, p.level);
    }

    /// @inheritdoc IXPHub
    function getUserXPBreakdown(address user)
        external
        view
        returns (uint256[15] memory xpBySource)
    {
        return _xpBySource[user];
    }

    /**
     * @dev Award a badge to a user
     */
    function awardBadge(address user, uint256 id, string memory name, string memory description) external onlyRole(MARKETPLACE_ROLE) {
        userBadges[user].push(Badge({
            id: id,
            name: name,
            description: description,
            dateEarned: block.timestamp
        }));
        emit BadgeEarned(user, id, name);
    }

    /**
     * @dev Get user badges
     */
    function getUserBadges(address user) external view returns (Badge[] memory) {
        return userBadges[user];
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // DASHBOARD & FRONTEND VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @dev Get user's XP progress percentage for current level
     */
    function getUserLevelProgress(address _user) external view returns (
        uint8 currentLevel,
        uint256 currentLevelXP,
        uint256 xpInCurrentLevel,
        uint256 xpNeededForNext,
        uint256 progressPercentage
    ) {
        UserProfile memory profile = userProfiles[_user];
        currentLevel = profile.level;
        
        // Calculate cumulative XP for current level
        currentLevelXP = 0;
        currentLevelXP = currentLevel > 1 ? getCumulativeXPForLevel(currentLevel - 1) : 0;
        
        // Calculate XP within current level
        xpInCurrentLevel = profile.totalXP > currentLevelXP ? profile.totalXP - currentLevelXP : 0;
        
        // XP needed for next level
        xpNeededForNext = currentLevel < MAX_LEVEL ? getXPRequiredForLevel(currentLevel + 1) : 0;
        
        // Progress percentage
        progressPercentage = xpNeededForNext > 0 ? (xpInCurrentLevel * 100) / xpNeededForNext : 100;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // NFT AGENT INTEGRATION
    // ════════════════════════════════════════════════════════════════════════════════════════

    // XP rewards for AI Agent NFT activities
    uint256 private constant AGENT_MINT_XP       = 50;   // Mint a new agent NFT
    uint256 private constant AGENT_UPGRADE_XP    = 20;   // Equip a NuxPower upgrade
    uint256 private constant AGENT_TASK_XP       = 10;   // Agent completes a task
    uint256 private constant AGENT_RENTAL_XP     = 15;   // List agent for rental
    uint256 private constant AGENT_LEASE_XP      = 10;   // Rent someone else's agent

    // Per-user agent tracking
    mapping(address => uint32) public agentsMinted;      // How many agent NFTs created
    mapping(address => uint32) public agentTasksDone;    // Total tasks completed via agents
    mapping(address => uint32) public agentUpgrades;     // Total NuxPower upgrades applied

    event AgentMinted(address indexed creator, uint32 totalAgents);
    event AgentTaskCompleted(address indexed user, uint32 totalTasks);
    event AgentUpgradeApplied(address indexed user, uint32 totalUpgrades);

    /**
     * @dev Record AI Agent NFT mint — awards AGENT_MINT_XP to creator
     * Called by NuxAgentNFTBase categories on mint
     */
    function recordAgentMinted(address creator) external onlyRole(MARKETPLACE_ROLE) {
        require(creator != address(0), "Invalid creator");
        userProfiles[creator].nftsCreated++;
        agentsMinted[creator]++;
        _updateUserXP(creator, AGENT_MINT_XP, "AGENT_MINTED", uint8(IXPHub.XPSource.AGENT_MINT), true);
        emit AgentMinted(creator, agentsMinted[creator]);
    }

    /**
     * @dev Record a NuxPower upgrade equipped to an agent — awards AGENT_UPGRADE_XP
     * Called by AgentNuxPower on purchasePower
     */
    function recordAgentUpgrade(address user) external onlyRole(MARKETPLACE_ROLE) {
        require(user != address(0), "Invalid user");
        agentUpgrades[user]++;
        _updateUserXP(user, AGENT_UPGRADE_XP, "AGENT_UPGRADE", uint8(IXPHub.XPSource.AGENT_UPGRADE), true);
        emit AgentUpgradeApplied(user, agentUpgrades[user]);
    }

    /**
     * @dev Record a task completion by an agent — awards AGENT_TASK_XP
     * Called by NuxAgentMiniGame._approveSubmission
     */
    function recordAgentTask(address user) external onlyRole(MARKETPLACE_ROLE) {
        require(user != address(0), "Invalid user");
        agentTasksDone[user]++;
        _updateUserXP(user, AGENT_TASK_XP, "AGENT_TASK", uint8(IXPHub.XPSource.AGENT_TASK), true);
        emit AgentTaskCompleted(user, agentTasksDone[user]);
    }

    /**
     * @dev Record agent listed for rental — awards AGENT_RENTAL_XP
     */
    function recordAgentRentalListed(address owner) external onlyRole(MARKETPLACE_ROLE) {
        require(owner != address(0), "Invalid owner");
        _updateUserXP(owner, AGENT_RENTAL_XP, "AGENT_RENTAL_LISTED", uint8(IXPHub.XPSource.AGENT_MINT), true);
    }

    /**
     * @dev Record agent rented by a user — awards AGENT_LEASE_XP to renter
     */
    function recordAgentLeased(address renter) external onlyRole(MARKETPLACE_ROLE) {
        require(renter != address(0), "Invalid renter");
        _updateUserXP(renter, AGENT_LEASE_XP, "AGENT_LEASED", uint8(IXPHub.XPSource.AGENT_TASK), true);
    }

    /**
     * @dev Full agent profile view for a user
     */
    function getAgentProfile(address user) external view returns (
        uint32 totalAgentsMinted,
        uint32 totalTasksDone,
        uint32 totalUpgrades,
        uint8  userLevel,
        uint256 totalXP
    ) {
        UserProfile memory p = userProfiles[user];
        return (agentsMinted[user], agentTasksDone[user], agentUpgrades[user], p.level, p.totalXP);
    }

    function _deferLevelUpReward(address user, uint8 newLevel, uint256 amount, string memory reason) internal {
        deferredRewardAmount[user] += amount;
        deferredRewardTime[user] = block.timestamp;
        totalPendingRewards += amount;

        emit RewardDeferred(user, newLevel, amount, reason);
    }
}
