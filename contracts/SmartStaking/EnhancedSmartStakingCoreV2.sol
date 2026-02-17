// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IStakingIntegration.sol";
import "../interfaces/IEnhancedSmartStakingRewards.sol";
import "../interfaces/IEnhancedSmartStakingSkills.sol";
import "../interfaces/IEnhancedSmartStakingGamification.sol";
import "../interfaces/ITreasuryManager.sol";

/// @title EnhancedSmartStaking Core V2 - Modular Architecture with UUPS
/// @notice Core orchestration contract for modular staking system (Upgradeable)
/// @dev Delegates to specialized modules: Rewards, Skills, Gamification
/// @custom:security-contact security@nuvo.com
/// @custom:version 6.0.0 - UUPS Upgradeable
/// @custom:solc-version 0.8.28
contract EnhancedSmartStakingCoreV2 is 
    Initializable,
    AccessControlUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IStakingIntegration 
{
    using Address for address payable;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ROLES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    uint16 private constant COMMISSION_PERCENTAGE = 600; // 6%
    uint256 private constant MAX_DEPOSIT = 100000 ether;
    uint256 private constant MIN_DEPOSIT = 10 ether;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant DAILY_WITHDRAWAL_LIMIT = 2000 ether;
    uint256 private constant WITHDRAWAL_LIMIT_PERIOD = 1 days;
    uint16 private constant MAX_DEPOSITS_PER_USER = 400;
    uint8 private constant MAX_ACTIVE_SKILL_SLOTS = 5;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    struct Deposit {
        uint128 amount;
        uint64 timestamp;
        uint64 lastClaimTime;
        uint64 lockupDuration;
    }
    
    struct User {
        Deposit[] deposits;
        uint128 totalDeposited;
        uint64 lastWithdrawTime;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - CORE
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    address public treasury;
    ITreasuryManager public treasuryManager;
    uint256 public totalPoolBalance;
    uint256 public uniqueUsersCount;
    bool public migrated;
    address public newContractAddress;
    
    mapping(address => User) private users;
    mapping(address => uint256) private _dailyWithdrawalAmount;
    mapping(address => uint256) private _lastWithdrawalDay;
    mapping(address => uint256) public totalRewardsClaimed;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - MODULE REFERENCES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    mapping(address => bool) public authorizedMarketplaces;
    IEnhancedSmartStakingRewards public rewardsModule;
    IEnhancedSmartStakingSkills public skillsModule;
    IEnhancedSmartStakingGamification public gamificationModule;
    mapping(SkillType => bool) private _skillEnabled;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    event Deposited(address indexed user, uint256 amount, uint256 lockupDuration);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawAll(address indexed user, uint256 totalAmount);
    event Compounded(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event CommissionPaid(address indexed receiver, uint256 amount, uint256 timestamp);
    event ModuleUpdated(string indexed moduleName, address indexed oldModule, address indexed newModule);
    event MarketplaceAuthorizationUpdated(address indexed marketplace, bool isAuthorized);
    event TreasuryManagerUpdated(address indexed newManager);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    error OnlyMarketplace();
    error DepositTooLow(uint256 provided, uint256 minimum);
    error DepositTooHigh(uint256 provided, uint256 maximum);
    error MaxDepositsReached(address user, uint16 maxDeposits);
    error InvalidAddress();
    error ContractIsMigrated();
    error NoRewardsAvailable();
    error InsufficientBalance();
    error NoDepositsFound();
    error InvalidLockupDuration();
    error FundsAreLocked();
    error DailyWithdrawalLimitExceeded(uint256 availableToWithdraw);
    error CommissionTransferFailed(address treasury, uint256 amount);
    error ModuleNotSet(string moduleName);
    error SkillDisabled(SkillType skillType);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    modifier notMigrated() {
        if (migrated) revert ContractIsMigrated();
        _;
    }
    
    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }
    
    modifier sufficientDeposit(uint256 _amount) {
        if (_amount < MIN_DEPOSIT) revert DepositTooLow(_amount, MIN_DEPOSIT);
        if (_amount > MAX_DEPOSIT) revert DepositTooHigh(_amount, MAX_DEPOSIT);
        _;
    }
    
    modifier onlyMarketplace() {
        if (!authorizedMarketplaces[msg.sender]) revert OnlyMarketplace();
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INITIALIZER
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function initialize(address _treasury) public initializer {
        if (_treasury == address(0)) revert InvalidAddress();
        
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        treasury = _treasury;
        _initializeSkillFlags();
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // UUPS UPGRADE AUTHORIZATION
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MODULE SETUP
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function setRewardsModule(address _rewardsModule) external onlyRole(ADMIN_ROLE) validAddress(_rewardsModule) {
        address old = address(rewardsModule);
        rewardsModule = IEnhancedSmartStakingRewards(_rewardsModule);
        emit ModuleUpdated("Rewards", old, _rewardsModule);
    }
    
    function setSkillsModule(address _skillsModule) external onlyRole(ADMIN_ROLE) validAddress(_skillsModule) {
        address old = address(skillsModule);
        skillsModule = IEnhancedSmartStakingSkills(_skillsModule);
        emit ModuleUpdated("Skills", old, _skillsModule);
    }
    
    function setGamificationModule(address _gamificationModule) external onlyRole(ADMIN_ROLE) validAddress(_gamificationModule) {
        address old = address(gamificationModule);
        gamificationModule = IEnhancedSmartStakingGamification(_gamificationModule);
        emit ModuleUpdated("Gamification", old, _gamificationModule);
    }
    
    // [REST OF THE IMPLEMENTATION FOLLOWS THE SAME as V1...]
    // Due to length constraints, I'm including the critical UUPS-specific changes
    // The remaining functions (deposit, withdraw, compound, etc.) remain identical 
    // to V1, only replacing onlyOwner with onlyRole(ADMIN_ROLE)
    
    function deposit(uint64 _lockupDuration) 
        public
        payable 
        nonReentrant 
        whenNotPaused 
        notMigrated 
        sufficientDeposit(msg.value) 
    {
        if (_lockupDuration != 0 && _lockupDuration != 30 && _lockupDuration != 90 && _lockupDuration != 180 && _lockupDuration != 365) {
            revert InvalidLockupDuration();
        }

        User storage user = users[msg.sender];
        
        if (user.deposits.length >= MAX_DEPOSITS_PER_USER) {
            revert MaxDepositsReached(msg.sender, MAX_DEPOSITS_PER_USER);
        }

        uint256 commission = (msg.value * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 depositAmount = msg.value - commission;

        if (user.deposits.length == 0) {
            unchecked { ++uniqueUsersCount; }
        }

        totalPoolBalance += depositAmount;
        user.totalDeposited += uint128(depositAmount);
        
        _syncTVLToRewards();
        
        uint64 currentTime = uint64(block.timestamp);
        uint64 lockupDurationSeconds = _lockupDuration * 1 days;

        user.deposits.push(Deposit({
            amount: uint128(depositAmount),
            timestamp: currentTime,
            lastClaimTime: currentTime,
            lockupDuration: lockupDurationSeconds
        }));

        _transferCommission(commission);
        
        if (address(gamificationModule) != address(0)) {
            gamificationModule.updateUserXP(msg.sender, 0, depositAmount);
        }
        
        emit Deposited(msg.sender, depositAmount, _lockupDuration);
    }
    
    function calculateRewards(address userAddress) public view returns (uint256 totalRewards) {
        if (address(rewardsModule) == address(0)) revert ModuleNotSet("Rewards");
        
        User storage user = users[userAddress];
        if (user.deposits.length == 0) return 0;

        uint16 stakingBoostTotal = 0;
        if (address(skillsModule) != address(0)) {
            (stakingBoostTotal,,) = skillsModule.getUserBoosts(userAddress);
        }

        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            uint8 lockupIndex = _getLockupIndex(userDeposit.lockupDuration);
            
            uint256 reward = rewardsModule.calculateStakingRewards(
                uint256(userDeposit.amount),
                uint256(userDeposit.timestamp),
                uint256(userDeposit.lastClaimTime),
                lockupIndex,
                stakingBoostTotal
            );
            
            totalRewards += reward;
        }
    }
    
    function calculateBoostedRewards(address userAddress) public view returns (uint256 totalRewards) {
        return calculateRewards(userAddress);
    }

    function calculateBoostedRewardsWithRarityMultiplier(address userAddress) public view returns (uint256) {
        return calculateRewards(userAddress);
    }
    
    function withdrawBoosted() external nonReentrant whenNotPaused notMigrated {
        _withdraw();
    }
    
    function withdraw() external nonReentrant whenNotPaused notMigrated {
        _withdraw();
    }

    function _withdraw() internal {
        User storage user = users[msg.sender];

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
        
        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            if (userDeposit.lockupDuration > 0 && block.timestamp < userDeposit.timestamp + userDeposit.lockupDuration) {
                revert FundsAreLocked();
            }
        }
        
        uint256 commission = (totalRewards * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 netAmount = totalRewards - commission;

        if (address(this).balance < netAmount + commission) {
            revert InsufficientBalance();
        }

        uint64 currentTime = uint64(block.timestamp);
        for (uint256 i = 0; i < user.deposits.length; i++) {
            user.deposits[i].lastClaimTime = currentTime;
        }
        user.lastWithdrawTime = currentTime;

        totalRewardsClaimed[msg.sender] += netAmount;

        _transferCommission(commission);
        payable(msg.sender).sendValue(netAmount);

        emit Withdrawn(msg.sender, netAmount);
    }
    
    function withdrawAll() external nonReentrant whenNotPaused notMigrated {
        User storage user = users[msg.sender];
        if (user.totalDeposited == 0) revert NoDepositsFound();
        
        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            if (userDeposit.lockupDuration > 0 && block.timestamp < userDeposit.timestamp + userDeposit.lockupDuration) {
                revert FundsAreLocked();
            }
        }
        
        uint256 rewards = calculateRewards(msg.sender);
        uint256 totalAmount = user.totalDeposited + rewards;
        uint256 commission = (rewards * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 netAmount = totalAmount - commission;

        if (address(this).balance < netAmount + commission) {
            revert InsufficientBalance();
        }
        
        user.totalDeposited = 0;
        user.lastWithdrawTime = uint64(block.timestamp);
        delete user.deposits;
        
        totalPoolBalance -= totalAmount;
        if (uniqueUsersCount > 0) {
            unchecked { --uniqueUsersCount; }
        }
        
        _syncTVLToRewards();
        
        _transferCommission(commission);
        payable(msg.sender).sendValue(netAmount);
        
        emit WithdrawAll(msg.sender, netAmount);
    }
    
    function compound() public nonReentrant whenNotPaused notMigrated {
        User storage userStruct = users[msg.sender];
        uint256 rewards = calculateRewards(msg.sender);

        if (rewards == 0) revert NoRewardsAvailable();

        userStruct.totalDeposited += uint128(rewards);

        uint64 currentTime = uint64(block.timestamp);
        userStruct.deposits.push(Deposit({
            amount: uint128(rewards),
            timestamp: currentTime,
            lastClaimTime: currentTime,
            lockupDuration: 0
        }));

        for (uint256 i = 0; i < userStruct.deposits.length; i++) {
            userStruct.deposits[i].lastClaimTime = currentTime;
        }
        
        if (address(gamificationModule) != address(0)) {
            gamificationModule.updateUserXP(msg.sender, 1, rewards);
        }

        emit Compounded(msg.sender, rewards);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // SKILL INTEGRATION (Delegates to Skills Module)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function notifySkillActivation(
        address user,
        uint256 nftId,
        SkillType skillType,
        uint16 effectValue
    ) external override onlyMarketplace {
        if (address(skillsModule) == address(0)) revert ModuleNotSet("Skills");
        if (!_skillEnabled[skillType]) revert SkillDisabled(skillType);
        skillsModule.notifySkillActivation(user, nftId, skillType, effectValue);
    }
    
    function notifySkillDeactivation(address user, uint256 nftId) external override onlyMarketplace {
        if (address(skillsModule) == address(0)) revert ModuleNotSet("Skills");
        skillsModule.notifySkillDeactivation(user, nftId);
    }
    
    function updateUserXP(address user, uint256 xpGained) external override onlyMarketplace {
        if (address(gamificationModule) == address(0)) revert ModuleNotSet("Gamification");
        gamificationModule.updateUserXP(user, 2, xpGained);
    }

    function notifyQuestCompletion(address user, uint256 questId, uint256 rewardAmount)
        external
        override
        onlyMarketplace
    {
        if (address(gamificationModule) == address(0)) revert ModuleNotSet("Gamification");
        gamificationModule.completeQuest(user, questId, rewardAmount, 15, 30);
    }

    function notifyAchievementUnlocked(address user, uint256 achievementId, uint256 rewardAmount)
        external
        override
        onlyMarketplace
    {
        if (address(gamificationModule) == address(0)) revert ModuleNotSet("Gamification");
        gamificationModule.unlockAchievement(user, achievementId, rewardAmount, 30);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
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
    
    function getTotalClaimedRewards(address userAddress) external view returns (uint256) {
        return totalRewardsClaimed[userAddress];
    }
    
    function getUser(address user) external view returns (address[] memory, uint256, uint64) {
        User storage userData = users[user];
        address[] memory emptyArray = new address[](0);
        return (emptyArray, uint256(userData.totalDeposited), userData.lastWithdrawTime);
    }
    
    function getUserDeposit(address user, uint256 index) external view returns (uint128, uint64, uint64, uint64) {
        User storage userData = users[user];
        require(index < userData.deposits.length, "Invalid deposit index");
        Deposit storage dep = userData.deposits[index];
        return (dep.amount, dep.timestamp, dep.lastClaimTime, dep.lockupDuration);
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function getActiveSkills(address user) external view override returns (NFTSkill[] memory) {
        if (address(skillsModule) == address(0)) {
            return new NFTSkill[](0);
        }

        IEnhancedSmartStakingSkills.SkillInfo[] memory skillInfos = skillsModule.getActiveSkillsWithDetails(user);
        NFTSkill[] memory skills = new NFTSkill[](skillInfos.length);

        for (uint256 i = 0; i < skillInfos.length; i++) {
            skills[i] = NFTSkill({
                skillType: skillInfos[i].skillType,
                effectValue: skillInfos[i].boost,
                rarity: _convertRarity(skillInfos[i].rarity),
                activatedAt: skillInfos[i].activatedAt,
                cooldownEnds: skillInfos[i].cooldownEnds,
                isActive: skillInfos[i].isActive
            });
        }

        return skills;
    }
    
    function getUserSkillProfile(address user) external view override returns (UserSkillProfile memory profile) {
        profile.maxActiveSkills = MAX_ACTIVE_SKILL_SLOTS;
        profile.activeNFTIds = new uint256[](0);

        uint16 feeDiscountBps;
        bool hasAutoCompoundSkill;

        if (address(skillsModule) != address(0)) {
            IEnhancedSmartStakingSkills.UserSkillProfile memory skillsProfile = skillsModule.getUserSkillProfile(user);
            profile.activeNFTIds = skillsProfile.activeSkillNFTIds;
            profile.stakingBoostTotal = skillsProfile.totalBoost;

            IEnhancedSmartStakingSkills.SkillInfo[] memory skillInfos = skillsModule.getActiveSkillsWithDetails(user);
            (feeDiscountBps, , hasAutoCompoundSkill) = _summarizeSkillEffects(skillInfos);
            profile.feeDiscountTotal = feeDiscountBps;
        }

        if (address(gamificationModule) != address(0)) {
            (uint256 xp, uint16 level,) = gamificationModule.getUserXPInfo(user);
            profile.totalXP = xp;
            profile.level = level;
            if (gamificationModule.getAutoCompoundConfig(user).enabled) {
                profile.hasAutoCompound = true;
            }
        }

        if (!profile.hasAutoCompound && hasAutoCompoundSkill) {
            profile.hasAutoCompound = true;
        }
    }
    
    function calculateBoostedAPY(address user, uint256 baseAPY) external view override returns (uint256) {
        if (address(skillsModule) == address(0)) return baseAPY;
        
        (uint16 totalBoost,,) = skillsModule.getUserBoosts(user);
        if (totalBoost == 0) return baseAPY;
        
        return baseAPY + (baseAPY * totalBoost / 10000);
    }
    
    function calculateReducedLockTime(address user, uint256 baseLockTime) external view override returns (uint256) {
        if (address(skillsModule) == address(0) || baseLockTime == 0) {
            return baseLockTime;
        }

        IEnhancedSmartStakingSkills.SkillInfo[] memory skillInfos = skillsModule.getActiveSkillsWithDetails(user);
        (, uint16 lockReducerBps,) = _summarizeSkillEffects(skillInfos);

        if (lockReducerBps == 0) {
            return baseLockTime;
        }

        if (lockReducerBps > BASIS_POINTS) {
            lockReducerBps = uint16(BASIS_POINTS);
        }

        uint256 reduction = (baseLockTime * lockReducerBps) / BASIS_POINTS;
        return baseLockTime > reduction ? baseLockTime - reduction : 0;
    }
    
    function hasAutoCompound(address user) external view override returns (bool) {
        if (address(gamificationModule) != address(0) && gamificationModule.getAutoCompoundConfig(user).enabled) {
            return true;
        }

        if (address(skillsModule) == address(0)) {
            return false;
        }

        IEnhancedSmartStakingSkills.SkillInfo[] memory skillInfos = skillsModule.getActiveSkillsWithDetails(user);
        (,, bool hasAutoCompoundSkill) = _summarizeSkillEffects(skillInfos);
        return hasAutoCompoundSkill;
    }
    
    function calculateFeeDiscount(address user, uint256 baseFee) external view override returns (uint256) {
        if (address(skillsModule) == address(0) || baseFee == 0) {
            return baseFee;
        }

        IEnhancedSmartStakingSkills.SkillInfo[] memory skillInfos = skillsModule.getActiveSkillsWithDetails(user);
        (uint16 feeDiscountBps,,) = _summarizeSkillEffects(skillInfos);

        if (feeDiscountBps == 0) {
            return baseFee;
        }

        if (feeDiscountBps > BASIS_POINTS) {
            feeDiscountBps = uint16(BASIS_POINTS);
        }

        uint256 discountAmount = (baseFee * feeDiscountBps) / BASIS_POINTS;
        return baseFee > discountAmount ? baseFee - discountAmount : 0;
    }
    
    function getAutoCompoundUsers() external view returns (address[] memory autoUsers) {
        if (address(gamificationModule) == address(0)) {
            return new address[](0);
        }

        (, , uint256 total) = gamificationModule.getAutoCompoundUsersPage(0, 1);
        if (total == 0) {
            return new address[](0);
        }

        (autoUsers,,) = gamificationModule.getAutoCompoundUsersPage(0, total);
    }

    function nftRarity(uint256 nftId) external view returns (Rarity) {
        if (address(skillsModule) == address(0)) {
            return Rarity.COMMON;
        }

        (IEnhancedSmartStakingSkills.SkillRarity rarity,) = skillsModule.getSkillRarity(nftId);
        return _convertRarity(rarity);
    }

    function skillEnabled(SkillType skillType) external view returns (bool) {
        return _skillEnabled[skillType];
    }

    function skillDefaultEffects(SkillType skillType) external view returns (uint16) {
        if (address(skillsModule) == address(0)) {
            return 0;
        }
        return skillsModule.getSkillBoost(skillType);
    }

    function checkAutoCompound(address user) external view override returns (bool, bytes memory) {
        if (address(gamificationModule) == address(0)) return (false, "");
        
        (bool shouldCompound,) = gamificationModule.checkAutoCompound(user);
        return (shouldCompound, shouldCompound ? abi.encode(user) : bytes(""));
    }
    
    function performAutoCompound(bytes calldata performData) external override {
        address user = abi.decode(performData, (address));
        
        if (address(gamificationModule) == address(0)) revert ModuleNotSet("Gamification");
        
        uint256 rewards = calculateRewards(user);
        if (rewards == 0) revert NoRewardsAvailable();
        
        User storage userStruct = users[user];
        userStruct.totalDeposited += uint128(rewards);
        
        uint64 currentTime = uint64(block.timestamp);
        userStruct.deposits.push(Deposit({
            amount: uint128(rewards),
            timestamp: currentTime,
            lastClaimTime: currentTime,
            lockupDuration: 0
        }));
        
        for (uint256 i = 0; i < userStruct.deposits.length; i++) {
            userStruct.deposits[i].lastClaimTime = currentTime;
        }
        
        gamificationModule.performAutoCompound(user);
        
        emit Compounded(user, rewards);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function setMarketplaceAddress(address _marketplace) external override onlyRole(ADMIN_ROLE) {
        if (_marketplace == address(0)) revert InvalidAddress();
        authorizedMarketplaces[_marketplace] = true;
        emit MarketplaceAuthorizationUpdated(_marketplace, true);
    }

    function setMarketplaceAuthorization(address _marketplace, bool _isAuthorized) external onlyRole(ADMIN_ROLE) {
        if (_marketplace == address(0)) revert InvalidAddress();
        authorizedMarketplaces[_marketplace] = _isAuthorized;
        emit MarketplaceAuthorizationUpdated(_marketplace, _isAuthorized);
    }
    
    function setStakingAddress(address) external pure override {
        revert("Not applicable");
    }
    
    function setSkillEnabled(SkillType skillType, bool enabled) external override onlyRole(ADMIN_ROLE) {
        if (skillType == SkillType.NONE) revert("Invalid skill");
        _skillEnabled[skillType] = enabled;
    }
    
    function updateSkillEffect(SkillType skillType, uint16 newEffectValue) external override onlyRole(ADMIN_ROLE) {
        if (address(skillsModule) == address(0)) revert ModuleNotSet("Skills");
        skillsModule.updateSkillBoost(skillType, newEffectValue);
    }
    
    function changeTreasuryAddress(address _newTreasury) external onlyRole(ADMIN_ROLE) validAddress(_newTreasury) {
        address previousTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryUpdated(previousTreasury, _newTreasury);
    }
    
    function setTreasuryManager(address _treasuryManager) external onlyRole(ADMIN_ROLE) validAddress(_treasuryManager) {
        treasuryManager = ITreasuryManager(_treasuryManager);
        emit TreasuryManagerUpdated(_treasuryManager);
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function emergencyWithdrawStake() external nonReentrant {
        User storage user = users[msg.sender];
        uint256 stakeAmount = user.totalDeposited;
        if (stakeAmount == 0) revert NoDepositsFound();

        if (address(this).balance < stakeAmount) {
            revert InsufficientBalance();
        }

        user.totalDeposited = 0;
        user.lastWithdrawTime = uint64(block.timestamp);
        delete user.deposits;

        totalPoolBalance -= stakeAmount;
        if (uniqueUsersCount > 0) {
            unchecked { --uniqueUsersCount; }
        }

        _syncTVLToRewards();

        payable(msg.sender).sendValue(stakeAmount);

        emit EmergencyWithdrawal(msg.sender, stakeAmount);
    }

    function emergencyWithdraw(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        if (_amount == 0 || _amount > address(this).balance) revert InvalidAddress();
        if (treasury == address(0)) revert InvalidAddress();
        
        (bool success, ) = payable(treasury).call{value: _amount}("");
        if (!success) revert CommissionTransferFailed(treasury, _amount);
        
        emit EmergencyWithdrawal(msg.sender, _amount);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPERS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function _transferCommission(uint256 commission) internal {
        if (address(treasuryManager) != address(0)) {
            try treasuryManager.receiveRevenue{value: commission}("staking_commission") {
                emit CommissionPaid(address(treasuryManager), commission, block.timestamp);
                return;
            } catch {
                // Fallback to old treasury
            }
        }
        
        if (treasury == address(0)) revert InvalidAddress();
        
        (bool sent, ) = payable(treasury).call{value: commission}("");
        if (!sent) {
            revert CommissionTransferFailed(treasury, commission);
        }
        emit CommissionPaid(treasury, commission, block.timestamp);
    }
    
    function _getLockupIndex(uint64 lockupDuration) internal pure returns (uint8) {
        if (lockupDuration == 0) return 0;
        if (lockupDuration == 30 days) return 1;
        if (lockupDuration == 90 days) return 2;
        if (lockupDuration == 180 days) return 3;
        if (lockupDuration == 365 days) return 4;
        return 0;
    }

    function _convertRarity(IEnhancedSmartStakingSkills.SkillRarity rarity) internal pure returns (Rarity) {
        return Rarity(uint8(rarity));
    }

    function _summarizeSkillEffects(
        IEnhancedSmartStakingSkills.SkillInfo[] memory skills
    )
        internal
        pure
        returns (uint16 feeDiscountBps, uint16 lockReducerBps, bool hasAutoCompoundSkill)
    {
        uint256 feeAccumulator;
        uint256 lockAccumulator;

        for (uint256 i = 0; i < skills.length; i++) {
            if (!skills[i].isActive) {
                continue;
            }

            SkillType skillType = skills[i].skillType;
            uint16 boost = skills[i].boost;

            if (skillType == SkillType.FEE_REDUCER_I || skillType == SkillType.FEE_REDUCER_II) {
                feeAccumulator += boost;
            }

            if (skillType == SkillType.LOCK_REDUCER) {
                lockAccumulator += boost;
            }

            if (!hasAutoCompoundSkill && skillType == SkillType.AUTO_COMPOUND) {
                hasAutoCompoundSkill = true;
            }
        }

        uint256 maxValue = type(uint16).max;
        if (feeAccumulator > maxValue) {
            feeAccumulator = maxValue;
        }
        if (lockAccumulator > maxValue) {
            lockAccumulator = maxValue;
        }

        feeDiscountBps = uint16(feeAccumulator);
        lockReducerBps = uint16(lockAccumulator);
    }
    
    function _initializeSkillFlags() internal {
        for (uint8 i = 1; i <= uint8(type(SkillType).max); i++) {
            _skillEnabled[SkillType(i)] = true;
        }
    }
    
    function _syncTVLToRewards() internal {
        if (address(rewardsModule) != address(0)) {
            try rewardsModule.updateCurrentTVL(totalPoolBalance) {
                // TVL synced successfully
            } catch {
                // Fail silently
            }
        }
    }
    
    receive() external payable {
        emit CommissionPaid(msg.sender, msg.value, block.timestamp);
    }
}
