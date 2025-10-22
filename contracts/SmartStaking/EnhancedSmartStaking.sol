// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IStakingIntegration.sol";

/// @title EnhancedSmartStaking with NFT Skills Integration
/// @notice Enhanced staking protocol with NFT skill boosts and marketplace synchronization
/// @dev Independent contract with gamification features and cross-contract communication
/// @custom:security-contact security@nuvo.com
/// @custom:version 4.0.0
/// @custom:solc-version 0.8.28
contract EnhancedSmartStaking is Ownable, Pausable, ReentrancyGuard, IStakingIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Address for address payable;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    uint256 private constant HOURLY_ROI_PERCENTAGE = 100; // 0.01% per hour
    uint16 private constant MAX_ROI_PERCENTAGE = 12500; // 125%
    uint16 private constant COMMISSION_PERCENTAGE = 600; // 6%
    uint256 private constant MAX_DEPOSIT = 10000 ether;
    uint256 private constant MIN_DEPOSIT = 5 ether;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant DAILY_WITHDRAWAL_LIMIT = 1000 ether;
    uint256 private constant WITHDRAWAL_LIMIT_PERIOD = 1 days;
    
    // Lock-up ROI percentages
    uint256 private constant ROI_30_DAYS_LOCKUP = 120;
    uint256 private constant ROI_90_DAYS_LOCKUP = 160;
    uint256 private constant ROI_180_DAYS_LOCKUP = 200;
    uint256 private constant ROI_365_DAYS_LOCKUP = 300;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Structure representing a user deposit
    struct Deposit {
        uint128 amount;
        uint64 timestamp;
        uint64 lastClaimTime;
        uint64 lockupDuration;
    }
    
    /// @notice Structure representing user data
    struct User {
        Deposit[] deposits;
        uint128 totalDeposited;
        uint64 lastWithdrawTime;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Treasury address for commission
    address public treasury;
    
    /// @notice Total balance in pool
    uint256 public totalPoolBalance;
    
    /// @notice Count of unique users
    uint256 public uniqueUsersCount;
    
    /// @notice Whether contract is migrated
    bool public migrated;
    
    /// @notice New contract address for migration
    address public newContractAddress;
    
    /// @notice Mapping to store user data
    mapping(address => User) private users;
    
    /// @notice Mapping to track daily withdrawal amount
    mapping(address => uint256) private _dailyWithdrawalAmount;
    
    /// @notice Mapping to track last withdrawal day
    mapping(address => uint256) private _lastWithdrawalDay;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - NFT Skills Integration
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Address of the marketplace contract
    address public marketplaceContract;
    
    /// @notice Maps user address to their active NFT skill IDs
    mapping(address => EnumerableSet.UintSet) private _userActiveSkillNFTs;
    
    /// @notice Maps user address to their skill profile
    mapping(address => UserSkillProfile) public userSkillProfiles;
    
    /// @notice Maps NFT ID to its skill details
    mapping(uint256 => NFTSkill) public nftSkills;
    
    /// @notice Maps skill type to whether it's enabled
    mapping(SkillType => bool) public skillEnabled;
    
    /// @notice Maps skill type to its default effect value
    mapping(SkillType => uint16) public skillDefaultEffects;
    
    /// @notice List of users with auto-compound enabled
    address[] private _autoCompoundUsers;
    
    /// @notice Mapping to track if user is in auto-compound list
    mapping(address => bool) private _isInAutoCompoundList;
    
    /// @notice Last auto-compound execution timestamp
    uint64 public lastAutoCompoundExecution;
    
    /// @notice Auto-compound interval (24 hours)
    uint64 public constant AUTO_COMPOUND_INTERVAL = 1 days;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - RARITY & SKILL TRACKING
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Maps NFT ID to its rarity for enhanced boost calculations
    mapping(uint256 => IStakingIntegration.Rarity) public nftRarity;
    
    /// @notice Maps user to their quest rewards tracking
    mapping(address => mapping(uint256 => uint256)) public userQuestRewards;
    
    /// @notice Maps user to their achievement rewards tracking
    mapping(address => mapping(uint256 => uint256)) public userAchievementRewards;
    
    /// @notice Total quest rewards per user (for temporal boosts)
    mapping(address => uint256) public totalQuestRewards;
    
    /// @notice Total achievement rewards per user (for temporal boosts)
    mapping(address => uint256) public totalAchievementRewards;
    
    /// @notice Quest reward expiration time (30 days default)
    uint256 public questRewardExpirationTime = 30 days;
    
    /// @notice Achievement reward expiration time (30 days default)
    uint256 public achievementRewardExpirationTime = 30 days;
    
    /// @notice Maps user to last quest completion time
    mapping(address => uint256) public lastQuestCompletionTime;
    
    /// @notice Maps user to last achievement unlock time
    mapping(address => uint256) public lastAchievementUnlockTime;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS - Base Staking
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    event Deposited(address indexed user, uint256 amount, uint256 lockupDuration);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawAll(address indexed user, uint256 totalAmount);
    event Compounded(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event MigrationInitiated(address indexed newContract);
    event CommissionPaid(address indexed receiver, uint256 amount, uint256 timestamp);
    event WithdrawalMade(address indexed user, uint256 amount, uint256 commission, uint256 timestamp, uint256 depositId);
    event RewardsCompounded(address indexed user, uint256 amount);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS - Skills & NFT
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    event SkillApplied(address indexed user, uint256 indexed tokenId, SkillType skillType, uint8 skillLevel);
    event SkillRemoved(address indexed user, uint256 indexed tokenId, SkillType skillType);
    event AutoCompounded(address indexed user, uint256 amount);
    event EmergencyRewardClaimed(address indexed user, uint256 amount);
    event NFTStaked(address indexed user, uint256 indexed tokenId);
    event NFTUnstaked(address indexed user, uint256 indexed tokenId);
    event MarketplaceUpdated(address indexed oldMarketplace, address indexed newMarketplace);
    event QuestRewardObtained(address indexed user, uint256 questId, uint256 rewardAmount, uint256 timestamp);
    event AchievementRewardObtained(address indexed user, uint256 achievementId, uint256 rewardAmount, uint256 timestamp);
    event SkillUpgraded(address indexed user, uint256 indexed tokenId, IStakingIntegration.Rarity newRarity, uint256 upgradeReward);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    error OnlyMarketplace();
    error SkillAlreadyActive();
    error SkillNotActive();
    error SkillTypeDisabled();
    error InvalidEffectValue();
    error AutoCompoundNotActive();
    error DepositTooLow(uint256 provided, uint256 minimum);
    error DepositTooHigh(uint256 provided, uint256 maximum);
    error MaxDepositsReached(address user, uint16 maxDeposits);
    error InvalidAddress();
    error ContractIsMigrated();
    error NoRewardsAvailable();
    error InsufficientBalance();
    error NoDepositsFound();
    error AlreadyMigrated();
    error NoPendingCommission();
    error UnauthorizedSender();
    error InvalidLockupDuration();
    error FundsAreLocked();
    error DailyWithdrawalLimitExceeded(uint256 availableToWithdraw);
    error InsufficientSkillNFTs();
    error LevelUpNotEligible();
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Ensures contract is not migrated
    modifier notMigrated() {
        if (migrated) revert ContractIsMigrated();
        _;
    }
    
    /// @notice Validates address is not zero
    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }
    
    /// @notice Validates deposit amount against minimum and maximum limits
    modifier sufficientDeposit(uint256 _amount) {
        if (_amount < MIN_DEPOSIT) revert DepositTooLow(_amount, MIN_DEPOSIT);
        if (_amount > MAX_DEPOSIT) revert DepositTooHigh(_amount, MAX_DEPOSIT);
        _;
    }
    
    /// @notice Restricts function access to marketplace contract only
    modifier onlyMarketplace() {
        if (msg.sender != marketplaceContract) revert OnlyMarketplace();
        _;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    constructor(address _treasury) {
        if (_treasury == address(0)) revert InvalidAddress();
        treasury = _treasury;
        
        // Initialize default skill effects
        _initializeSkillEffects();
        lastAutoCompoundExecution = uint64(block.timestamp);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // SKILL MANAGEMENT (Called by Marketplace)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Notifies staking contract that a skill has been activated
    /// @inheritdoc IStakingIntegration
    function notifySkillActivation(
        address user,
        uint256 nftId,
        SkillType skillType,
        uint16 effectValue
    ) external override onlyMarketplace {
        if (!skillEnabled[skillType]) revert SkillTypeDisabled();
        if (_userActiveSkillNFTs[user].contains(nftId)) revert SkillAlreadyActive();
        
        // Register skill with rarity tracking (initialized as COMMON, updated by marketplace)
        nftSkills[nftId] = NFTSkill({
            skillType: skillType,
            effectValue: effectValue,
            rarity: Rarity.COMMON, // Updated by marketplace call to setSkillRarity
            activatedAt: uint64(block.timestamp),
            cooldownEnds: 0,
            isActive: true
        });
        
        _userActiveSkillNFTs[user].add(nftId);
        
        // Update user's skill profile with rarity-based boost multiplier
        _updateSkillProfile(user, skillType, effectValue, true);
        
        // If auto-compound, add to list
        if (skillType == SkillType.AUTO_COMPOUND) {
            _addToAutoCompoundList(user);
        }
        
        emit SkillApplied(user, nftId, skillType, 1);
    }
    
    /// @notice Notifies staking contract that a skill has been deactivated
    /// @inheritdoc IStakingIntegration
    function notifySkillDeactivation(address user, uint256 nftId) external override onlyMarketplace {
        if (!_userActiveSkillNFTs[user].contains(nftId)) revert SkillNotActive();
        
        NFTSkill storage skill = nftSkills[nftId];
        SkillType skillType = skill.skillType;
        uint16 effectValue = skill.effectValue;
        
        // Deactivate skill
        skill.isActive = false;
        _userActiveSkillNFTs[user].remove(nftId);
        
        // Update user's skill profile
        _updateSkillProfile(user, skillType, effectValue, false);
        
        // If auto-compound, remove from list
        if (skillType == SkillType.AUTO_COMPOUND) {
            _removeFromAutoCompoundList(user);
        }
        
        emit SkillRemoved(user, nftId, skillType);
    }
    
    /// @notice Actualizaciones avanzadas que el marketplace debe llamar para sincronización
    /// Permite que el staking obtenga recompensas de quests completados
    function notifyQuestCompletion(address user, uint256 questId, uint256 rewardAmount) external onlyMarketplace {
        userQuestRewards[user][questId] = rewardAmount;
        totalQuestRewards[user] += rewardAmount;
        lastQuestCompletionTime[user] = block.timestamp;
        
        emit QuestRewardObtained(user, questId, rewardAmount, block.timestamp);
    }
    
    /// @notice Permite que el marketplace notifique al staking de achievement completos
    function notifyAchievementUnlocked(address user, uint256 achievementId, uint256 rewardAmount) external onlyMarketplace {
        userAchievementRewards[user][achievementId] = rewardAmount;
        totalAchievementRewards[user] += rewardAmount;
        lastAchievementUnlockTime[user] = block.timestamp;
        
        emit AchievementRewardObtained(user, achievementId, rewardAmount, block.timestamp);
    }
    
    /// @notice Permite al marketplace establecer la rareza del NFT skill después de mintear
    function setSkillRarity(uint256 nftId, IStakingIntegration.Rarity rarity) external onlyMarketplace {
        nftRarity[nftId] = rarity;
        if (nftSkills[nftId].isActive) {
            nftSkills[nftId].rarity = rarity;
        }
    }
    
    /// @notice Permite upgrade de skills (dos skills de misma rareza = uno de rareza superior)
    /// Solo el marketplace puede llamar esta función
    function notifySkillUpgrade(
        address user, 
        uint256 oldSkillId1, 
        uint256 oldSkillId2, 
        uint256 newSkillId,
        IStakingIntegration.Rarity newRarity
    ) external onlyMarketplace {
        // Deactivate old skills if they are active
        if (nftSkills[oldSkillId1].isActive && _userActiveSkillNFTs[user].contains(oldSkillId1)) {
            nftSkills[oldSkillId1].isActive = false;
            _userActiveSkillNFTs[user].remove(oldSkillId1);
        }
        if (nftSkills[oldSkillId2].isActive && _userActiveSkillNFTs[user].contains(oldSkillId2)) {
            nftSkills[oldSkillId2].isActive = false;
            _userActiveSkillNFTs[user].remove(oldSkillId2);
        }
        
        // Set new skill with higher rarity
        nftRarity[newSkillId] = newRarity;
        
        // Award bonus rewards for upgrade
        uint256 upgradeBonus = 100; // 1% bonus per rarity level upgrade
        
        emit SkillUpgraded(user, newSkillId, newRarity, upgradeBonus);
    }
    
    /// @notice Updates user's XP and level
    /// @inheritdoc IStakingIntegration
    function updateUserXP(address user, uint256 xpGained) external override onlyMarketplace {
        UserSkillProfile storage profile = userSkillProfiles[user];
        profile.totalXP += xpGained;
        
        // Calculate new level (every 1000 XP = 1 level)
        uint8 newLevel = uint8(profile.totalXP / 1000);
        if (newLevel > profile.level) {
            profile.level = newLevel;
            profile.maxActiveSkills = 3 + (newLevel / 10); // +1 slot every 10 levels
            
            emit SkillProfileUpdated(user, newLevel, profile.maxActiveSkills, profile.stakingBoostTotal);
        }
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // BASE STAKING FUNCTIONS (Copied from SmartStaking)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Allows users to stake tokens with an optional lock-up period
    /// @param _lockupDuration The desired lock-up duration in days (0 for no lock-up)
    function deposit(uint64 _lockupDuration) 
        public
        payable 
        nonReentrant 
        whenNotPaused 
        notMigrated 
        sufficientDeposit(msg.value) 
    {
        // Validate lock-up duration
        if (_lockupDuration != 0 && _lockupDuration != 30 && _lockupDuration != 90 && _lockupDuration != 180 && _lockupDuration != 365) {
             revert InvalidLockupDuration();
         }

        User storage user = users[msg.sender];
        
        if (user.deposits.length >= 300) { // MAX_DEPOSITS_PER_USER
            revert MaxDepositsReached(msg.sender, 300);
        }

        // Calculate commission and deposit amount
        uint256 commission = (msg.value * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 depositAmount = msg.value - commission;

        // Update user count for new users
        if (user.deposits.length == 0) {
            unchecked {
                ++uniqueUsersCount;
             }
        }

        // Update balances
        totalPoolBalance += depositAmount;
        user.totalDeposited += uint128(depositAmount);
        
        uint64 currentTime = uint64(block.timestamp);
        uint64 lockupDurationSeconds = _lockupDuration * 1 days;

        // Add new deposit
        user.deposits.push(Deposit({
            amount: uint128(depositAmount),
            timestamp: currentTime,
            lastClaimTime: currentTime,
            lockupDuration: lockupDurationSeconds
        }));

        // Handle commission transfer with fallback
        _transferCommission(commission);
        
        emit Deposited(msg.sender, depositAmount, _lockupDuration);
    }
    
    /// @notice Calculates total rewards for a user
    /// @param userAddress Address of the user
    /// @return totalRewards Total accumulated rewards
    function calculateRewards(address userAddress) public view returns (uint256 totalRewards) {
        User storage user = users[userAddress];
        uint256 depositsLength = user.deposits.length;
        
        if (depositsLength == 0) return 0;

        for (uint256 i; i < depositsLength;) {
            Deposit storage userDeposit = user.deposits[i];
            
            // Calculate elapsed hours for rewards
            uint224 elapsedHours = uint224((block.timestamp - userDeposit.lastClaimTime) / 3600);
            
            if (elapsedHours > 0) {
                uint256 currentHourlyROI = HOURLY_ROI_PERCENTAGE;
                
                // Apply specific ROI for lock-up periods
                if (userDeposit.lockupDuration == 30 days) {
                    currentHourlyROI = ROI_30_DAYS_LOCKUP;
                } else if (userDeposit.lockupDuration == 90 days) {
                    currentHourlyROI = ROI_90_DAYS_LOCKUP;
                } else if (userDeposit.lockupDuration == 180 days) {
                    currentHourlyROI = ROI_180_DAYS_LOCKUP;
                } else if (userDeposit.lockupDuration == 365 days) {
                    currentHourlyROI = ROI_365_DAYS_LOCKUP;
                }

                // Base reward calculation
                uint256 reward = (uint256(userDeposit.amount) * currentHourlyROI * elapsedHours) / 1000000;
                
                // Apply maximum reward cap
                uint256 maxReward = (uint256(userDeposit.amount) * MAX_ROI_PERCENTAGE) / BASIS_POINTS;
                if (reward > maxReward) reward = maxReward;
                
                // Apply time bonus
                uint256 timeBonus = _calculateTimeBonus(block.timestamp - userDeposit.timestamp);
                if (timeBonus > 0) {
                    reward += (reward * timeBonus) / BASIS_POINTS;
                }
                
                totalRewards += reward;
            }
            
            unchecked { ++i; }
        }
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS FROM ORIGINAL SMARTSTAKING FOR FRONTEND COMPATIBILITY
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Obtiene el total depositado por un usuario (from original SmartStaking)
     * @param userAddress Dirección del usuario
     * @return Total depositado en wei
     */
    function getTotalDeposit(address userAddress) 
        external 
        view 
        returns (uint256) 
    {
        return users[userAddress].totalDeposited;
    }
    
    /**
     * @notice Obtiene los depósitos de un usuario (from original SmartStaking)
     * @param userAddress Dirección del usuario
     * @return Array de depósitos
     */
    function getUserDeposits(address userAddress) 
        external 
        view 
        returns (Deposit[] memory) 
    {
        return users[userAddress].deposits;
    }
    
    /**
     * @notice Obtiene información completa del usuario (from original SmartStaking)
     * @param userAddress Dirección del usuario
     * @return totalDeposited Total depositado
     * @return totalRewards Recompensas totales disponibles
     * @return depositCount Número de depósitos
     * @return lastWithdrawTime Último retiro
     */
    function getUserInfo(address userAddress) 
        external 
        view 
        returns (
            uint256 totalDeposited,
            uint256 totalRewards,
            uint256 depositCount,
            uint256 lastWithdrawTime
        ) 
    {
        User storage user = users[userAddress];
        return (
            user.totalDeposited,
            calculateRewards(userAddress),
            user.deposits.length,
            user.lastWithdrawTime
        );
    }
    
    /**
     * @notice Obtiene el balance disponible del contrato (from original SmartStaking)
     * @return Balance en wei
     */
    function getContractBalance() 
        external 
        view 
        returns (uint256) 
    {
        return address(this).balance;
    }
    
    /// @notice Transfers the calculated commission amount to the treasury address
    /// @param commission The amount of commission to be transferred
    function _transferCommission(uint256 commission) internal {
        (bool sent, ) = payable(treasury).call{value: commission}("");
        if (!sent) {
            // Commission held for later withdrawal if transfer fails
        }
        emit CommissionPaid(treasury, commission, block.timestamp);
    }
    
    /// @notice Calculates the time bonus percentage based on staking duration
    /// @param stakingTime The duration in seconds since the initial deposit
    /// @return The bonus percentage in basis points
    function _calculateTimeBonus(uint256 stakingTime) internal pure returns (uint256) {
        if (stakingTime >= 365 days) return 500;     // 5%
        if (stakingTime >= 180 days) return 300;     // 3%
        if (stakingTime >= 90 days) return 100;      // 1%
        if (stakingTime >= 30 days) return 50;       // 0.5%
        return 0;
    }
    
    /// @notice Withdraws accumulated rewards
    function withdraw() external nonReentrant whenNotPaused notMigrated {
        User storage user = users[msg.sender];

        // Check and enforce daily withdrawal limit
        if (block.timestamp / WITHDRAWAL_LIMIT_PERIOD > _lastWithdrawalDay[msg.sender]) {
            _dailyWithdrawalAmount[msg.sender] = 0;
            _lastWithdrawalDay[msg.sender] = uint64(block.timestamp / WITHDRAWAL_LIMIT_PERIOD);
        }

        uint256 totalRewards = calculateRewards(msg.sender);
        if (totalRewards == 0) revert NoRewardsAvailable();

        if (_dailyWithdrawalAmount[msg.sender] + totalRewards > DAILY_WITHDRAWAL_LIMIT) {
            revert DailyWithdrawalLimitExceeded(DAILY_WITHDRAWAL_LIMIT - _dailyWithdrawalAmount[msg.sender]);
        }

        _dailyWithdrawalAmount[msg.sender] += totalRewards;
        
        for (uint256 i; i < user.deposits.length;) {
            Deposit storage userDeposit = user.deposits[i];
            if (userDeposit.lockupDuration > 0 && block.timestamp < userDeposit.timestamp + userDeposit.lockupDuration) {
                revert FundsAreLocked();
            }
            unchecked { ++i; }
        }
        
        uint256 commission = (totalRewards * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 netAmount = totalRewards - commission;

        if (address(this).balance < netAmount + commission) {
            revert InsufficientBalance();
        }

        // Update claim times
        uint64 currentTime = uint64(block.timestamp);
        
        for (uint256 i; i < user.deposits.length;) {
            user.deposits[i].lastClaimTime = currentTime;
            unchecked { ++i; }
        }
        user.lastWithdrawTime = currentTime;

        // Handle transfers
        _transferCommission(commission);
        payable(msg.sender).sendValue(netAmount);

        emit Withdrawn(msg.sender, netAmount);
    }
    
    /**
     * @notice Retira todos los depósitos y recompensas (from original SmartStaking)
     * @dev Solo si el usuario tiene depósitos activos
     */
    function withdrawAll() 
        external 
        nonReentrant 
        whenNotPaused 
        notMigrated
    {
        User storage user = users[msg.sender];
        require(user.totalDeposited > 0, "No deposits");
        
        // Check lockup periods
        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            if (userDeposit.lockupDuration > 0 && block.timestamp < userDeposit.timestamp + userDeposit.lockupDuration) {
                revert FundsAreLocked();
            }
        }
        
        uint256 rewards = calculateRewards(msg.sender);
        uint256 totalAmount = user.totalDeposited + rewards;
        
        // Calculate commission on rewards
        uint256 commission = (rewards * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 netAmount = totalAmount - commission;
        
        require(address(this).balance >= netAmount + commission, "Insufficient balance");
        
        // Clear user state
        user.totalDeposited = 0;
        user.lastWithdrawTime = uint64(block.timestamp);
        delete user.deposits;
        
        // Update pool balance
        totalPoolBalance -= totalAmount;
        if (uniqueUsersCount > 0) {
            uniqueUsersCount--;
        }
        
        // Transfer funds
        _transferCommission(commission);
        payable(msg.sender).sendValue(netAmount);
        
        emit WithdrawAll(msg.sender, netAmount);
    }
    
    /// @notice Allows users to reinvest their accumulated rewards
    function compound() public nonReentrant whenNotPaused notMigrated {
        User storage userStruct = users[msg.sender];
        uint256 rewards = calculateRewards(msg.sender);

        if (rewards == 0) {
            revert NoRewardsAvailable();
        }

        // Add rewards to total deposited amount
        userStruct.totalDeposited += uint128(rewards);

        // Create a new deposit for the compounded rewards
        uint64 currentTime = uint64(block.timestamp);
        userStruct.deposits.push(Deposit({
            amount: uint128(rewards),
            timestamp: currentTime,
            lastClaimTime: currentTime,
            lockupDuration: 0
        }));

        // Update lastClaimTime for all existing deposits
        for (uint256 i = 0; i < userStruct.deposits.length; i++) {
            userStruct.deposits[i].lastClaimTime = currentTime;
        }

        emit Compounded(msg.sender, rewards);
    }
    
    /// @notice Changes the treasury address
    /// @param _newTreasury The new address for the treasury
    function changeTreasuryAddress(address _newTreasury) 
        external 
        onlyOwner 
        validAddress(_newTreasury) 
    {
        address previousTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryUpdated(previousTreasury, _newTreasury);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ENHANCED DEPOSIT WITH SKILLS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Enhanced deposit function that applies skill boosts
    /// @param _lockupDuration Lock-up duration in days (0, 30, 90, 180, 365)
    function depositWithBoosts(uint64 _lockupDuration)
        external
        payable
        nonReentrant
        whenNotPaused
        notMigrated
        sufficientDeposit(msg.value)
    {
        // Apply lock reducer skill if active
        uint64 adjustedLockup = _applyLockReducer(msg.sender, _lockupDuration);
        
        // Call base deposit
        deposit(adjustedLockup);
        
        // If user has auto-compound active, ensure they're in the list
        if (userSkillProfiles[msg.sender].hasAutoCompound && !_isInAutoCompoundList[msg.sender]) {
            _addToAutoCompoundList(msg.sender);
        }
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // BOOSTED REWARD CALCULATION
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Calculates rewards with skill boosts applied
    /// @param userAddress Address of the user
    /// @return totalRewards Boosted total rewards
    function calculateBoostedRewards(address userAddress) public view returns (uint256 totalRewards) {
        // Get base rewards from parent contract
        uint256 baseRewards = calculateRewards(userAddress);
        
        if (baseRewards == 0) return 0;
        
        // Apply staking boost from skills
        UserSkillProfile storage profile = userSkillProfiles[userAddress];
        if (profile.stakingBoostTotal > 0) {
            uint256 boost = (baseRewards * profile.stakingBoostTotal) / 10000;
            totalRewards = baseRewards + boost;
        } else {
            totalRewards = baseRewards;
        }
        
        return totalRewards;
    }
    
    /// @notice Override parent withdraw to use boosted rewards
    function withdrawBoosted() external nonReentrant whenNotPaused notMigrated {
        User storage user = users[msg.sender];
        
        // Check daily withdrawal limits (from parent)
        if (block.timestamp / WITHDRAWAL_LIMIT_PERIOD > _lastWithdrawalDay[msg.sender]) {
            _dailyWithdrawalAmount[msg.sender] = 0;
            _lastWithdrawalDay[msg.sender] = uint64(block.timestamp / WITHDRAWAL_LIMIT_PERIOD);
        }
        
        // Calculate boosted rewards
        uint256 totalRewards = calculateBoostedRewards(msg.sender);
        if (totalRewards == 0) revert NoRewardsAvailable();
        
        if (_dailyWithdrawalAmount[msg.sender] + totalRewards > DAILY_WITHDRAWAL_LIMIT) {
            revert DailyWithdrawalLimitExceeded(DAILY_WITHDRAWAL_LIMIT - _dailyWithdrawalAmount[msg.sender]);
        }
        
        _dailyWithdrawalAmount[msg.sender] += totalRewards;
        
        // Check lock-up periods
        for (uint256 i; i < user.deposits.length;) {
            Deposit storage userDeposit = user.deposits[i];
            if (userDeposit.lockupDuration > 0 && block.timestamp < userDeposit.timestamp + userDeposit.lockupDuration) {
                revert FundsAreLocked();
            }
            unchecked { ++i; }
        }
        
        uint256 commission = (totalRewards * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 netAmount = totalRewards - commission;
        
        if (address(this).balance < netAmount + commission) {
            revert InsufficientBalance();
        }
        
        // Update claim times
        uint64 currentTime = uint64(block.timestamp);
        for (uint256 i; i < user.deposits.length;) {
            user.deposits[i].lastClaimTime = currentTime;
            unchecked { ++i; }
        }
        user.lastWithdrawTime = currentTime;
        
        // Handle transfers
        _transferCommission(commission);
        payable(msg.sender).sendValue(netAmount);
        
        emit WithdrawalMade(msg.sender, netAmount, commission, block.timestamp, 0);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // AUTO-COMPOUND SYSTEM
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Checks if auto-compound should be triggered (for Chainlink Keepers)
    /// @inheritdoc IStakingIntegration
    function checkAutoCompound(address user)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (!userSkillProfiles[user].hasAutoCompound) {
            return (false, "");
        }
        
        uint256 rewards = calculateBoostedRewards(user);
        
        // Trigger if rewards > 0.01 ETH and 24h passed since last compound
        if (rewards >= 0.01 ether && block.timestamp >= lastAutoCompoundExecution + AUTO_COMPOUND_INTERVAL) {
            upkeepNeeded = true;
            performData = abi.encode(user);
        }
    }
    
    /// @notice Executes auto-compound for eligible users
    /// @inheritdoc IStakingIntegration
    function performAutoCompound(bytes calldata performData) external override {
        address user = abi.decode(performData, (address));
        
        if (!userSkillProfiles[user].hasAutoCompound) revert AutoCompoundNotActive();
        
        // Calculate rewards
        uint256 rewards = calculateBoostedRewards(user);
        if (rewards == 0) revert NoRewardsAvailable();
        
        // Perform compound (reuse parent logic)
        User storage userStruct = users[user];
        
        // Add rewards to total deposited
        userStruct.totalDeposited += uint128(rewards);
        
        // Create new deposit
        uint64 currentTime = uint64(block.timestamp);
        userStruct.deposits.push(Deposit({
            amount: uint128(rewards),
            timestamp: currentTime,
            lastClaimTime: currentTime,
            lockupDuration: 0
        }));
        
        // Update lastClaimTime for existing deposits
        for (uint256 i = 0; i < userStruct.deposits.length; i++) {
            userStruct.deposits[i].lastClaimTime = currentTime;
        }
        
        lastAutoCompoundExecution = currentTime;
        
        emit AutoCompoundTriggered(user, rewards);
        emit RewardsCompounded(user, rewards);
    }
    
    /// @notice Batch auto-compound for multiple users
    /// @param userAddresses Array of user addresses to compound for
    function batchAutoCompound(address[] calldata userAddresses) external onlyOwner {
        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (userSkillProfiles[userAddresses[i]].hasAutoCompound) {
                uint256 rewards = calculateBoostedRewards(userAddresses[i]);
                if (rewards >= 0.01 ether) {
                    bytes memory performData = abi.encode(userAddresses[i]);
                    this.performAutoCompound(performData);
                }
            }
        }
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // SKILL QUERY FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @inheritdoc IStakingIntegration
    function getActiveSkills(address user) external view override returns (NFTSkill[] memory) {
        uint256[] memory nftIds = _userActiveSkillNFTs[user].values();
        NFTSkill[] memory skills = new NFTSkill[](nftIds.length);
        
        for (uint256 i = 0; i < nftIds.length; i++) {
            skills[i] = nftSkills[nftIds[i]];
        }
        
        return skills;
    }
    
    /// @inheritdoc IStakingIntegration
    function getUserSkillProfile(address user) external view override returns (UserSkillProfile memory) {
        return userSkillProfiles[user];
    }
    
    /// @inheritdoc IStakingIntegration
    function calculateBoostedAPY(address user, uint256 baseAPY) external view override returns (uint256) {
        UserSkillProfile storage profile = userSkillProfiles[user];
        if (profile.stakingBoostTotal == 0) return baseAPY;
        
        return baseAPY + (baseAPY * profile.stakingBoostTotal / 10000);
    }
    
    /// @inheritdoc IStakingIntegration
    function calculateReducedLockTime(address user, uint256 baseLockTime) external view override returns (uint256) {
        // Check for lock reducer skill (-25%)
        uint256[] memory nftIds = _userActiveSkillNFTs[user].values();
        
        for (uint256 i = 0; i < nftIds.length; i++) {
            if (nftSkills[nftIds[i]].skillType == SkillType.LOCK_REDUCER) {
                return (baseLockTime * 75) / 100; // -25%
            }
        }
        
        return baseLockTime;
    }
    
    /// @inheritdoc IStakingIntegration
    function hasAutoCompound(address user) external view override returns (bool) {
        return userSkillProfiles[user].hasAutoCompound;
    }
    
    /// @inheritdoc IStakingIntegration
    function calculateFeeDiscount(address user, uint256 baseFee) external view override returns (uint256) {
        UserSkillProfile storage profile = userSkillProfiles[user];
        if (profile.feeDiscountTotal == 0) return baseFee;
        
        uint256 discount = (baseFee * profile.feeDiscountTotal) / 10000;
        return baseFee > discount ? baseFee - discount : 0;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @inheritdoc IStakingIntegration
    function setMarketplaceAddress(address _marketplace) external override onlyOwner {
        if (_marketplace == address(0)) revert InvalidAddress();
        marketplaceContract = _marketplace;
    }
    
    /// @inheritdoc IStakingIntegration
    function setStakingAddress(address) external view override onlyOwner {
        // Not applicable for this contract (we are the staking contract)
        revert("Not applicable");
    }
    
    /// @inheritdoc IStakingIntegration
    function setSkillEnabled(SkillType skillType, bool enabled) external override onlyOwner {
        skillEnabled[skillType] = enabled;
    }
    
    /// @inheritdoc IStakingIntegration
    function updateSkillEffect(SkillType skillType, uint16 newEffectValue) external override onlyOwner {
        if (newEffectValue > 10000) revert InvalidEffectValue();
        skillDefaultEffects[skillType] = newEffectValue;
    }
    
    /// @notice Gets auto-compound user list
    function getAutoCompoundUsers() external view returns (address[] memory) {
        return _autoCompoundUsers;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPER FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Updates user's skill profile when skill is activated/deactivated
     */
    function _updateSkillProfile(
        address user,
        SkillType skillType,
        uint16 effectValue,
        bool isActivating
    ) internal {
        UserSkillProfile storage profile = userSkillProfiles[user];
        
        if (isActivating) {
            profile.activeNFTIds.push(0); // Placeholder, actual ID managed by marketplace
            
            // Update skill effects
            if (skillType == SkillType.STAKE_BOOST_I || 
                skillType == SkillType.STAKE_BOOST_II || 
                skillType == SkillType.STAKE_BOOST_III) {
                profile.stakingBoostTotal += effectValue;
            } else if (skillType == SkillType.FEE_REDUCER_I || skillType == SkillType.FEE_REDUCER_II) {
                profile.feeDiscountTotal += effectValue;
            } else if (skillType == SkillType.AUTO_COMPOUND) {
                profile.hasAutoCompound = true;
            }
        } else {
            // Deactivating
            if (skillType == SkillType.STAKE_BOOST_I || 
                skillType == SkillType.STAKE_BOOST_II || 
                skillType == SkillType.STAKE_BOOST_III) {
                profile.stakingBoostTotal = profile.stakingBoostTotal > effectValue ? 
                    profile.stakingBoostTotal - effectValue : 0;
            } else if (skillType == SkillType.FEE_REDUCER_I || skillType == SkillType.FEE_REDUCER_II) {
                profile.feeDiscountTotal = profile.feeDiscountTotal > effectValue ?
                    profile.feeDiscountTotal - effectValue : 0;
            } else if (skillType == SkillType.AUTO_COMPOUND) {
                profile.hasAutoCompound = false;
            }
        }
    }
    
    /**
     * @dev Applies lock reducer skill effect
     */
    function _applyLockReducer(address user, uint64 baseLockup) internal view returns (uint64) {
        uint256[] memory nftIds = _userActiveSkillNFTs[user].values();
        
        for (uint256 i = 0; i < nftIds.length; i++) {
            if (nftSkills[nftIds[i]].skillType == SkillType.LOCK_REDUCER) {
                // Reduce lock time by 25%
                return (baseLockup * 75) / 100;
            }
        }
        
        return baseLockup;
    }
    
    /**
     * @dev Adds user to auto-compound list
     */
    function _addToAutoCompoundList(address user) internal {
        if (!_isInAutoCompoundList[user]) {
            _autoCompoundUsers.push(user);
            _isInAutoCompoundList[user] = true;
        }
    }
    
    /**
     * @dev Removes user from auto-compound list
     */
    function _removeFromAutoCompoundList(address user) internal {
        if (_isInAutoCompoundList[user]) {
            for (uint256 i = 0; i < _autoCompoundUsers.length; i++) {
                if (_autoCompoundUsers[i] == user) {
                    _autoCompoundUsers[i] = _autoCompoundUsers[_autoCompoundUsers.length - 1];
                    _autoCompoundUsers.pop();
                    break;
                }
            }
            _isInAutoCompoundList[user] = false;
        }
    }
    
    /**
     * @dev Initializes default skill effect values
     */
    function _initializeSkillEffects() internal {
        // Enable all skills by default
        skillEnabled[SkillType.STAKE_BOOST_I] = true;
        skillEnabled[SkillType.STAKE_BOOST_II] = true;
        skillEnabled[SkillType.STAKE_BOOST_III] = true;
        skillEnabled[SkillType.AUTO_COMPOUND] = true;
        skillEnabled[SkillType.LOCK_REDUCER] = true;
        skillEnabled[SkillType.FEE_REDUCER_I] = true;
        skillEnabled[SkillType.FEE_REDUCER_II] = true;
        
        // Set default effect values (in basis points)
        skillDefaultEffects[SkillType.STAKE_BOOST_I] = 500;    // +5%
        skillDefaultEffects[SkillType.STAKE_BOOST_II] = 1000;  // +10%
        skillDefaultEffects[SkillType.STAKE_BOOST_III] = 2000; // +20%
        skillDefaultEffects[SkillType.FEE_REDUCER_I] = 1000;   // -10%
        skillDefaultEffects[SkillType.FEE_REDUCER_II] = 2500;  // -25%
        skillDefaultEffects[SkillType.LOCK_REDUCER] = 2500;    // -25%
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS - Enhanced Statistics
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Gets comprehensive user info with skill boosts
     */
    function getUserInfoWithSkills(address userAddress) external view returns (
        uint256 totalDeposited,
        uint256 baseRewards,
        uint256 boostedRewards,
        uint256 lastWithdraw,
        uint16 stakingBoost,
        bool hasAutoCompound_,
        uint8 level,
        uint8 activeSkillCount
    ) {
        User storage user = users[userAddress];
        UserSkillProfile storage profile = userSkillProfiles[userAddress];
        
        totalDeposited = user.totalDeposited;
        baseRewards = calculateRewards(userAddress);
        boostedRewards = calculateBoostedRewards(userAddress);
        lastWithdraw = user.lastWithdrawTime;
        stakingBoost = profile.stakingBoostTotal;
        hasAutoCompound_ = profile.hasAutoCompound;
        level = profile.level;
        activeSkillCount = uint8(_userActiveSkillNFTs[userAddress].length());
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADVANCED VIEW FUNCTIONS - RARITY & SKILL DETAILS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Obtiene detalles completos de todos los skills activos con rareza
    function getActiveSkillsWithDetails(address user) external view returns (
        uint256[] memory nftIds,
        SkillType[] memory skillTypes,
        IStakingIntegration.Rarity[] memory rarities,
        uint16[] memory effectValues,
        uint8[] memory rarityStars
    ) {
        uint256[] memory activeNfts = _userActiveSkillNFTs[user].values();
        uint256 count = activeNfts.length;
        
        nftIds = new uint256[](count);
        skillTypes = new SkillType[](count);
        rarities = new IStakingIntegration.Rarity[](count);
        effectValues = new uint16[](count);
        rarityStars = new uint8[](count);
        
        for (uint256 i = 0; i < count; i++) {
            uint256 nftId = activeNfts[i];
            NFTSkill storage skill = nftSkills[nftId];
            IStakingIntegration.Rarity rarity = nftRarity[nftId];
            
            nftIds[i] = nftId;
            skillTypes[i] = skill.skillType;
            rarities[i] = rarity;
            effectValues[i] = skill.effectValue;
            rarityStars[i] = _rarityToStars(rarity);
        }
        
        return (nftIds, skillTypes, rarities, effectValues, rarityStars);
    }
    
    /// @notice Calcula el boost total incluyendo multiplicador por rareza
    function calculateBoostedRewardsWithRarityMultiplier(address user) external view returns (uint256 totalBoosted) {
        uint256 baseRewards = calculateRewards(user);
        if (baseRewards == 0) return 0;
        
        UserSkillProfile storage profile = userSkillProfiles[user];
        uint256[] memory activeNfts = _userActiveSkillNFTs[user].values();
        
        uint256 totalRarityBoost = 0;
        
        // Calculate rarity multiplier
        for (uint256 i = 0; i < activeNfts.length; i++) {
            IStakingIntegration.Rarity rarity = nftRarity[activeNfts[i]];
            // Rarity multiplier: COMMON=1, UNCOMMON=1.1, RARE=1.2, EPIC=1.4, LEGENDARY=1.8
            if (rarity == IStakingIntegration.Rarity.UNCOMMON) totalRarityBoost += 1000; // +10%
            else if (rarity == IStakingIntegration.Rarity.RARE) totalRarityBoost += 2000; // +20%
            else if (rarity == IStakingIntegration.Rarity.EPIC) totalRarityBoost += 4000; // +40%
            else if (rarity == IStakingIntegration.Rarity.LEGENDARY) totalRarityBoost += 8000; // +80%
        }
        
        // Apply profile boost + rarity boost
        uint256 totalBoost = profile.stakingBoostTotal + (totalRarityBoost / uint256(activeNfts.length > 0 ? activeNfts.length : 1));
        if (totalBoost > 0) {
            totalBoosted = baseRewards + (baseRewards * totalBoost / 10000);
        } else {
            totalBoosted = baseRewards;
        }
    }
    
    /// @notice Obtiene estadísticas detalladas por usuario incluyendo quests y achievements
    function getUserDetailedStats(address user) external view returns (
        uint256 totalStaked,
        uint256 baseRewards,
        uint256 boostedRewards,
        uint256 questRewards,
        uint256 achievementRewards,
        uint8 skillLevel,
        uint8 activeSkillsCount,
        bool hasAutoCompoundSkill
    ) {
        User storage userStruct = users[user];
        UserSkillProfile storage profile = userSkillProfiles[user];
        
        totalStaked = userStruct.totalDeposited;
        baseRewards = calculateRewards(user);
        boostedRewards = calculateBoostedRewards(user);
        questRewards = totalQuestRewards[user];
        achievementRewards = totalAchievementRewards[user];
        skillLevel = profile.level;
        activeSkillsCount = uint8(_userActiveSkillNFTs[user].length());
        hasAutoCompoundSkill = profile.hasAutoCompound;
    }
    
    /// @notice Retorna la rareza de un skill NFT específico
    function getSkillRarity(uint256 nftId) external view returns (IStakingIntegration.Rarity) {
        return nftRarity[nftId];
    }
    
    /// @notice Retorna todos los tipos de skills disponibles y sus efectos por defecto
    function getAvailableSkillsConfiguration() external view returns (
        SkillType[] memory skillTypes,
        uint16[] memory defaultEffects,
        bool[] memory enabled
    ) {
        SkillType[] memory allSkills = new SkillType[](7);
        uint16[] memory effects = new uint16[](7);
        bool[] memory isEnabled = new bool[](7);
        
        allSkills[0] = SkillType.STAKE_BOOST_I;
        allSkills[1] = SkillType.STAKE_BOOST_II;
        allSkills[2] = SkillType.STAKE_BOOST_III;
        allSkills[3] = SkillType.AUTO_COMPOUND;
        allSkills[4] = SkillType.LOCK_REDUCER;
        allSkills[5] = SkillType.FEE_REDUCER_I;
        allSkills[6] = SkillType.FEE_REDUCER_II;
        
        for (uint256 i = 0; i < 7; i++) {
            effects[i] = skillDefaultEffects[allSkills[i]];
            isEnabled[i] = skillEnabled[allSkills[i]];
        }
        
        return (allSkills, effects, isEnabled);
    }
    
    /// @notice Helper para convertir rareza a número de estrellas
    function _rarityToStars(IStakingIntegration.Rarity rarity) internal pure returns (uint8) {
        if (rarity == IStakingIntegration.Rarity.LEGENDARY) return 5;
        if (rarity == IStakingIntegration.Rarity.EPIC) return 4;
        if (rarity == IStakingIntegration.Rarity.RARE) return 3;
        if (rarity == IStakingIntegration.Rarity.UNCOMMON) return 2;
        return 1; // COMMON
    }
}