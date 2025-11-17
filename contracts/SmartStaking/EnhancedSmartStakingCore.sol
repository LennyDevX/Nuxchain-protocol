// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IStakingIntegration.sol";
import "../interfaces/IEnhancedSmartStakingRewards.sol";
import "../interfaces/IEnhancedSmartStakingSkills.sol";
import "../interfaces/IEnhancedSmartStakingGamification.sol";

/// @title EnhancedSmartStaking Core - Modular Architecture
/// @notice Core orchestration contract for modular staking system
/// @dev Delegates to specialized modules: Rewards, Skills, Gamification
/// @custom:security-contact security@nuvo.com
/// @custom:version 5.0.0 - Modular
/// @custom:solc-version 0.8.28
contract EnhancedSmartStaking is Ownable, Pausable, ReentrancyGuard, IStakingIntegration {
    using Address for address payable;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    uint16 private constant COMMISSION_PERCENTAGE = 600; // 6%
    uint256 private constant MAX_DEPOSIT = 10000 ether;
    uint256 private constant MIN_DEPOSIT = 10 ether;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant DAILY_WITHDRAWAL_LIMIT = 1000 ether;
    uint256 private constant WITHDRAWAL_LIMIT_PERIOD = 1 days;
    uint16 private constant MAX_DEPOSITS_PER_USER = 300;
    uint8 private constant MAX_ACTIVE_SKILL_SLOTS = 10;
    
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
    uint256 public totalPoolBalance;
    uint256 public uniqueUsersCount;
    bool public migrated;
    address public newContractAddress;
    
    mapping(address => User) private users;
    mapping(address => uint256) private _dailyWithdrawalAmount;
    mapping(address => uint256) private _lastWithdrawalDay;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - MODULE REFERENCES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    address public marketplaceContract;
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
        if (msg.sender != marketplaceContract) revert OnlyMarketplace();
        _;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    constructor(address _treasury) {
        if (_treasury == address(0)) revert InvalidAddress();
        treasury = _treasury;
        _initializeSkillFlags();
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MODULE SETUP
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function setRewardsModule(address _rewardsModule) external onlyOwner validAddress(_rewardsModule) {
        address old = address(rewardsModule);
        rewardsModule = IEnhancedSmartStakingRewards(_rewardsModule);
        emit ModuleUpdated("Rewards", old, _rewardsModule);
    }
    
    function setSkillsModule(address _skillsModule) external onlyOwner validAddress(_skillsModule) {
        address old = address(skillsModule);
        skillsModule = IEnhancedSmartStakingSkills(_skillsModule);
        emit ModuleUpdated("Skills", old, _skillsModule);
    }
    
    function setGamificationModule(address _gamificationModule) external onlyOwner validAddress(_gamificationModule) {
        address old = address(gamificationModule);
        gamificationModule = IEnhancedSmartStakingGamification(_gamificationModule);
        emit ModuleUpdated("Gamification", old, _gamificationModule);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CORE STAKING FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
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
        
        uint64 currentTime = uint64(block.timestamp);
        uint64 lockupDurationSeconds = _lockupDuration * 1 days;

        user.deposits.push(Deposit({
            amount: uint128(depositAmount),
            timestamp: currentTime,
            lastClaimTime: currentTime,
            lockupDuration: lockupDurationSeconds
        }));

        _transferCommission(commission);
        
        // Update XP via Gamification module
        if (address(gamificationModule) != address(0)) {
            gamificationModule.updateUserXP(msg.sender, 0, depositAmount); // actionType 0 = stake
        }
        
        emit Deposited(msg.sender, depositAmount, _lockupDuration);
    }
    
    function calculateRewards(address userAddress) public view returns (uint256 totalRewards) {
        if (address(rewardsModule) == address(0)) revert ModuleNotSet("Rewards");
        
        User storage user = users[userAddress];
        if (user.deposits.length == 0) return 0;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            
            // Get lockup period index
            uint8 lockupIndex = _getLockupIndex(userDeposit.lockupDuration);
            
            // Delegate to Rewards module
            uint256 reward = rewardsModule.calculateRewards(
                uint256(userDeposit.amount),
                uint256(userDeposit.timestamp),
                uint256(userDeposit.lastClaimTime),
                lockupIndex
            );
            
            totalRewards += reward;
        }
    }
    
    function calculateBoostedRewards(address userAddress) public view returns (uint256 totalRewards) {
        if (address(rewardsModule) == address(0)) revert ModuleNotSet("Rewards");
        if (address(skillsModule) == address(0)) revert ModuleNotSet("Skills");
        
        User storage user = users[userAddress];
        if (user.deposits.length == 0) return 0;

        // Get user's skill boosts
        (uint16 totalBoost, uint16 rarityMultiplier,) = skillsModule.getUserBoosts(userAddress);

        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            uint8 lockupIndex = _getLockupIndex(userDeposit.lockupDuration);
            
            // Delegate to Rewards module with boosts
            uint256 reward = rewardsModule.calculateBoostedRewardsWithRarityMultiplier(
                uint256(userDeposit.amount),
                uint256(userDeposit.timestamp),
                uint256(userDeposit.lastClaimTime),
                lockupIndex,
                totalBoost,
                rarityMultiplier
            );
            
            totalRewards += reward;
        }
    }

    function calculateBoostedRewardsWithRarityMultiplier(address userAddress) public view returns (uint256) {
        return calculateBoostedRewards(userAddress);
    }
    
    function withdraw() external nonReentrant whenNotPaused notMigrated {
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

        _transferCommission(commission);
        payable(msg.sender).sendValue(netAmount);

        emit Withdrawn(msg.sender, netAmount);
    }
    
    function withdrawBoosted() external nonReentrant whenNotPaused notMigrated {
        User storage user = users[msg.sender];

        if (block.timestamp / WITHDRAWAL_LIMIT_PERIOD > _lastWithdrawalDay[msg.sender]) {
            _dailyWithdrawalAmount[msg.sender] = 0;
            _lastWithdrawalDay[msg.sender] = uint64(block.timestamp / WITHDRAWAL_LIMIT_PERIOD);
        }

        uint256 totalRewards = calculateBoostedRewards(msg.sender);
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
        
        // Update XP via Gamification module
        if (address(gamificationModule) != address(0)) {
            gamificationModule.updateUserXP(msg.sender, 1, rewards); // actionType 1 = compound
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
        gamificationModule.updateUserXP(user, 2, xpGained); // actionType 2 = quest/external
    }

    function notifyQuestCompletion(address user, uint256 questId, uint256 rewardAmount)
        external
        override
        onlyMarketplace
    {
        if (address(gamificationModule) == address(0)) revert ModuleNotSet("Gamification");
        gamificationModule.completeQuest(user, questId, rewardAmount, 30);
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
    // VIEW FUNCTIONS (Delegates to Modules)
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
        
        uint256 rewards = calculateBoostedRewards(user);
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
    
    function setMarketplaceAddress(address _marketplace) external override onlyOwner {
        if (_marketplace == address(0)) revert InvalidAddress();
        marketplaceContract = _marketplace;
    }
    
    function setStakingAddress(address) external pure override {
        revert("Not applicable");
    }
    
    function setSkillEnabled(SkillType skillType, bool enabled) external override onlyOwner {
        if (skillType == SkillType.NONE) revert("Invalid skill");
        _skillEnabled[skillType] = enabled;
    }
    
    function updateSkillEffect(SkillType skillType, uint16 newEffectValue) external override onlyOwner {
        if (address(skillsModule) == address(0)) revert ModuleNotSet("Skills");
        skillsModule.updateSkillBoost(skillType, newEffectValue);
    }
    
    function changeTreasuryAddress(address _newTreasury) external onlyOwner validAddress(_newTreasury) {
        address previousTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryUpdated(previousTreasury, _newTreasury);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function emergencyWithdraw(uint256 _amount) external onlyOwner {
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
    
    receive() external payable {
        emit CommissionPaid(msg.sender, msg.value, block.timestamp);
    }
}
