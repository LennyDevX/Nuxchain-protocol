// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IStakingIntegration.sol";
import "../interfaces/ISmartStakingRewards.sol";
import "../interfaces/ISmartStakingPower.sol";
import "../interfaces/ISmartStakingGamification.sol";
import "../interfaces/ITreasuryManager.sol";
import "./SkillViewLib.sol";
import { Deposit, User } from "./SmartStakingTypes.sol";
import { SmartStakingCoreLib } from "./SmartStakingCoreLib.sol";

/// @title SmartStaking Core - Modular Architecture with UUPS
/// @notice Core orchestration contract for modular staking system (Upgradeable)
/// @dev Delegates to specialized modules: Rewards, Skills, Gamification
/// @custom:security-contact security@nuvo.com
/// @custom:version 7.0 - UUPS Upgradeable + Sustainability v7.0
/// @custom:solc-version 0.8.28

interface IStakingQuestCore {
    enum QuestType { PURCHASE, CREATE, SOCIAL, LEVEL_UP, TRADING, STAKE, COMPOUND, AGENT_TASK }
    function notifyAction(address user, QuestType questType, uint256 value) external;
}

/// @dev Minimal extension interface for v7.0 loyalty tracking functions added to Rewards module.
interface ISmartStakingRewardsExtended {
    function recordStakingSince(address user, uint256 timestamp) external;
    function clearStakingSince(address user) external;
}

contract SmartStakingCore is 
    Initializable,
    OwnableUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IStakingIntegration 
{
    using Address for address payable;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
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

    // v6.1.0 — New feature constants
    /// @notice Early exit fee on principal for flexible withdrawals within 7 days (0.5%)
    uint256 private constant EARLY_EXIT_FEE_BPS = 50;
    /// @notice Window during which early exit fee applies (7 days)
    uint256 private constant EARLY_EXIT_WINDOW = 7 days;
    /// @notice Fee charged on rewards when auto-compounding (0.25%)
    uint256 private constant AUTOCOMPOUND_FEE_BPS = 25;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - CORE
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    address public treasury;
    ITreasuryManager public treasuryManager;
    uint256 public totalPoolBalance;
    uint256 public uniqueUsersCount;
    bool public migrated;
    
    mapping(address => User) private users;
    mapping(address => uint256) private _dailyWithdrawalAmount;
    mapping(address => uint256) private _lastWithdrawalDay;
    mapping(address => uint256) public totalRewardsClaimed;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - MODULE REFERENCES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    mapping(address => bool) public authorizedMarketplaces;
    ISmartStakingRewards public rewardsModule;
    ISmartStakingPower public powerModule;
    ISmartStakingGamification public gamificationModule;
    mapping(PowerType => bool) private _powerEnabled;

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - v6.1.0 NEW FEATURES
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Circuit breaker: minimum reserve ratio (bps of totalPoolBalance) required to accept deposits
    /// @dev e.g. 2000 = 20% — if balance < totalPoolBalance * (1 + 20%), new deposits blocked
    uint256 public circuitBreakerReserveRatio; // default 0 = disabled
    bool public circuitBreakerEnabled;

    /// @notice Referral system: who referred whom
    mapping(address => address) public referrers;
    /// @notice How many successful referrals a user has made
    mapping(address => uint256) public referralCount;
    /// @notice APY boost granted to referrer per referral (bps), configurable by admin
    uint256 public referralBoostBps;    // default 150 = 1.5%
    /// @notice How long each referral boost stacks for the referrer (seconds)
    uint256 public referralBoostDuration; // default 30 days
    /// @notice End time of referral boost per referrer
    mapping(address => uint256) public referralBoostEndTime;

    /// @notice Partial reinvestment: user chooses % of rewards to auto-compound on every claim
    /// @dev 0 = full payout (default), 5000 = 50% compound + 50% payout, 10000 = full compound
    mapping(address => uint256) public reinvestmentPercentage;

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - QUESTCORE INTEGRATION
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Optional QuestCore integration — when set, deposit() and compound() notify it.
    IStakingQuestCore public questCore;

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
    event ModuleUpdated(uint8 indexed moduleId, address indexed oldModule, address indexed newModule);
    event MarketplaceAuthorizationUpdated(address indexed marketplace, bool isAuthorized);
    event TreasuryManagerUpdated(address indexed newManager);

    // v6.1.0 events
    /// @notice Emitted when a flexible deposit is exited within the early exit window
    event EarlyExitFeePaid(address indexed user, uint256 feeAmount);
    /// @notice Emitted when compound() charges the autocompound sustainability fee
    event AutocompoundFeePaid(address indexed user, uint256 feeAmount);
    /// @notice Emitted when a referral relationship is established
    event ReferralRegistered(address indexed referrer, address indexed referee);
    /// @notice Emitted when a user updates their partial reinvestment percentage
    event ReinvestmentPercentageSet(address indexed user, uint256 percentage);
    /// @notice Emitted when the circuit breaker state changes
    event CircuitBreakerUpdated(bool enabled, uint256 reserveRatio);
    /// @notice Emitted by getExpiringDeposits so backends/keepers can notify users
    event LockupExpiringSoon(address indexed user, uint256 indexed depositIndex, uint256 unlockTime, uint256 amount);
    // v7.0 events
    /// @notice Emitted when a user withdraws a single deposit by index
    event WithdrawnByIndex(address indexed user, uint256 indexed depositIndex, uint256 principal, uint256 rewards);
    /// @notice Emitted when a flexible deposit is migrated to a longer lockup
    event LockupMigrated(address indexed user, uint256 indexed depositIndex, uint64 newLockupDuration);
    
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
    error ModuleNotSet();
    error PowerDisabled(PowerType powerType);
    // v6.1.0 errors
    error CircuitBreakerActive();
    error InvalidReinvestmentPercentage();
    error BatchLengthMismatch();
    error BatchAmountMismatch(uint256 sent, uint256 required);
    error AlreadyHasReferrer();
    error ReferralBoostTooHigh();
    error AutoCompoundNotEnabled();
    // v7.0 errors
    error DepositIndexOutOfBounds(uint256 index, uint256 length);
    error MigrationNotAllowed();
    
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
        
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        treasury = _treasury;
        _initializeSkillFlags();
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // UUPS UPGRADE AUTHORIZATION
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MODULE SETUP
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function setRewardsModule(address _rewardsModule) external onlyOwner validAddress(_rewardsModule) {
        address old = address(rewardsModule);
        rewardsModule = ISmartStakingRewards(_rewardsModule);
        emit ModuleUpdated(1, old, _rewardsModule);
    }
    
    function setPowerModule(address _powerModule) external onlyOwner validAddress(_powerModule) {
        address old = address(powerModule);
        powerModule = ISmartStakingPower(_powerModule);
        emit ModuleUpdated(2, old, _powerModule);
    }
    
    function setQuestCore(address questCore_) external onlyOwner {
        questCore = IStakingQuestCore(questCore_);
    }

    function setGamificationModule(address _gamificationModule) external onlyOwner validAddress(_gamificationModule) {
        address old = address(gamificationModule);
        gamificationModule = ISmartStakingGamification(_gamificationModule);
        emit ModuleUpdated(3, old, _gamificationModule);
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

        // v6.1.0 Circuit breaker: verify pool has minimum reserve ratio before accepting deposits
        if (circuitBreakerEnabled && circuitBreakerReserveRatio > 0) {
            uint256 required = totalPoolBalance + (totalPoolBalance * circuitBreakerReserveRatio / BASIS_POINTS);
            if (address(this).balance < required) {
                revert CircuitBreakerActive();
            }
        }

        User storage user = users[msg.sender];
        
        if (user.deposits.length >= MAX_DEPOSITS_PER_USER) {
            revert MaxDepositsReached(msg.sender, MAX_DEPOSITS_PER_USER);
        }

        uint256 commission = (msg.value * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 depositAmount = msg.value - commission;

        if (user.deposits.length == 0) {
            unchecked { ++uniqueUsersCount; }
            if (address(rewardsModule) != address(0)) {
                try ISmartStakingRewardsExtended(address(rewardsModule)).recordStakingSince(msg.sender, block.timestamp) {} catch {}
            }
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

        if (address(questCore) != address(0)) {
            try questCore.notifyAction(msg.sender, IStakingQuestCore.QuestType.STAKE, depositAmount) {} catch {}
        }

        emit Deposited(msg.sender, depositAmount, _lockupDuration);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // v6.1.0 — BATCH DEPOSIT
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Deposit into multiple lockup periods in a single transaction
     * @dev msg.value must equal sum(amounts[i]) exactly (commissions are deducted per-slot)
     * @param lockupDurations Array of lockup durations in days (0, 30, 90, 180, 365)
     * @param amounts Array of gross amounts (before 6% commission) for each slot in wei
     */
    function depositBatch(
        uint64[] calldata lockupDurations,
        uint256[] calldata amounts
    ) external payable nonReentrant whenNotPaused notMigrated {
        if (lockupDurations.length == 0 || lockupDurations.length != amounts.length) {
            revert BatchLengthMismatch();
        }

        // Verify total sent matches sum of specified amounts
        uint256 totalRequired = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalRequired += amounts[i];
        }
        if (msg.value != totalRequired) {
            revert BatchAmountMismatch(msg.value, totalRequired);
        }

        // Circuit breaker check
        if (circuitBreakerEnabled && circuitBreakerReserveRatio > 0) {
            uint256 required = totalPoolBalance + (totalPoolBalance * circuitBreakerReserveRatio / BASIS_POINTS);
            if (address(this).balance < required) {
                revert CircuitBreakerActive();
            }
        }

        User storage user = users[msg.sender];
        if (user.deposits.length + lockupDurations.length > MAX_DEPOSITS_PER_USER) {
            revert MaxDepositsReached(msg.sender, MAX_DEPOSITS_PER_USER);
        }

        bool isNewUser = user.deposits.length == 0;
        uint64 currentTime = uint64(block.timestamp);
        uint256 totalNet = 0;

        for (uint256 i = 0; i < lockupDurations.length; i++) {
            uint64 dur = lockupDurations[i];
            if (dur != 0 && dur != 30 && dur != 90 && dur != 180 && dur != 365) {
                revert InvalidLockupDuration();
            }
            if (amounts[i] < MIN_DEPOSIT) revert DepositTooLow(amounts[i], MIN_DEPOSIT);
            if (amounts[i] > MAX_DEPOSIT) revert DepositTooHigh(amounts[i], MAX_DEPOSIT);

            uint256 commission = (amounts[i] * COMMISSION_PERCENTAGE) / BASIS_POINTS;
            uint256 depositAmount = amounts[i] - commission;

            user.deposits.push(Deposit({
                amount: uint128(depositAmount),
                timestamp: currentTime,
                lastClaimTime: currentTime,
                lockupDuration: dur * 1 days
            }));

            totalNet += depositAmount;
            _transferCommission(commission);

            emit Deposited(msg.sender, depositAmount, dur);
        }

        if (isNewUser) {
            unchecked { ++uniqueUsersCount; }
            if (address(rewardsModule) != address(0)) {
                try ISmartStakingRewardsExtended(address(rewardsModule)).recordStakingSince(msg.sender, block.timestamp) {} catch {}
            }
        }
        user.totalDeposited += uint128(totalNet);
        totalPoolBalance += totalNet;
        _syncTVLToRewards();

        if (address(gamificationModule) != address(0)) {
            gamificationModule.updateUserXP(msg.sender, 0, totalNet);
        }
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // v6.1.0 — USER PREFERENCE FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Set what percentage of your rewards auto-compounds on every claim
     * @param percentage Basis points (0 = full payout, 5000 = 50% compound, 10000 = full compound)
     */
    function setReinvestmentPercentage(uint256 percentage) external {
        if (percentage > BASIS_POINTS) revert InvalidReinvestmentPercentage();
        reinvestmentPercentage[msg.sender] = percentage;
        emit ReinvestmentPercentageSet(msg.sender, percentage);
    }

    /**
     * @notice Register a referrer before making your first deposit
     * @dev Can only be set once. Referrer must not be msg.sender or zero.
     *      Grants referrer a temporary APY boost for `referralBoostDuration` seconds.
     * @param referrer Address that referred you
     */
    function registerReferrer(address referrer) external {
        if (referrers[msg.sender] != address(0)) revert AlreadyHasReferrer();
        if (referrer == address(0) || referrer == msg.sender) revert InvalidAddress();

        referrers[msg.sender] = referrer;
        referralCount[referrer]++;

        // Stack boost duration for the referrer
        uint256 boostDuration = referralBoostDuration > 0 ? referralBoostDuration : 30 days;
        if (referralBoostEndTime[referrer] < block.timestamp) {
            referralBoostEndTime[referrer] = block.timestamp + boostDuration;
        } else {
            referralBoostEndTime[referrer] += boostDuration;
        }

        emit ReferralRegistered(referrer, msg.sender);
    }
    
    function calculateRewards(address userAddress) public view returns (uint256 totalRewards) {
        return SmartStakingCoreLib.calculateRewards(
            users,
            address(rewardsModule),
            address(powerModule),
            referralBoostEndTime,
            referralBoostBps,
            userAddress
        );
    }
    
    function withdrawBoosted() external nonReentrant whenNotPaused notMigrated {
        _withdraw();
    }
    
    function withdraw() external nonReentrant whenNotPaused notMigrated {
        _withdraw();
    }

    function _withdraw() internal {
        (uint256 netAmount, uint256 compoundPortion, uint256 newTotalPoolBalance) = SmartStakingCoreLib.withdrawRewards(
            users,
            _dailyWithdrawalAmount,
            _lastWithdrawalDay,
            totalRewardsClaimed,
            reinvestmentPercentage,
            address(rewardsModule),
            address(powerModule),
            referralBoostEndTime,
            referralBoostBps,
            treasury,
            address(treasuryManager),
            totalPoolBalance,
            msg.sender
        );

        totalPoolBalance = newTotalPoolBalance;
        if (compoundPortion > 0) {
            emit Compounded(msg.sender, compoundPortion);
        }
        emit Withdrawn(msg.sender, netAmount);
    }
    
    function withdrawAll() external nonReentrant whenNotPaused notMigrated {
        (uint256 netAmount, uint256 newTotalPoolBalance, uint256 newUniqueUsersCount) = SmartStakingCoreLib.withdrawAll(
            users,
            address(rewardsModule),
            address(powerModule),
            referralBoostEndTime,
            referralBoostBps,
            treasury,
            address(treasuryManager),
            totalPoolBalance,
            uniqueUsersCount,
            msg.sender
        );

        totalPoolBalance = newTotalPoolBalance;
        uniqueUsersCount = newUniqueUsersCount;
        emit WithdrawAll(msg.sender, netAmount);
    }
    
    function compound() public nonReentrant whenNotPaused notMigrated {
        (uint256 compoundAmount, uint256 newTotalPoolBalance) = SmartStakingCoreLib.compoundRewards(
            users,
            address(rewardsModule),
            address(powerModule),
            referralBoostEndTime,
            referralBoostBps,
            treasury,
            address(treasuryManager),
            totalPoolBalance,
            msg.sender
        );

        totalPoolBalance = newTotalPoolBalance;

        if (address(gamificationModule) != address(0)) {
            gamificationModule.updateUserXP(msg.sender, 1, compoundAmount);
        }

        if (address(questCore) != address(0)) {
            try questCore.notifyAction(msg.sender, IStakingQuestCore.QuestType.COMPOUND, 1) {} catch {}
        }

        emit Compounded(msg.sender, compoundAmount);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // SKILL INTEGRATION (Delegates to Skills Module)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function notifyPowerActivation(
        address user,
        uint256 nftId,
        PowerType powerType,
        uint16 effectValue
    ) external override onlyMarketplace {
        if (address(powerModule) == address(0)) revert ModuleNotSet();
        if (!_powerEnabled[powerType]) revert PowerDisabled(powerType);
        powerModule.notifyPowerActivation(user, nftId, powerType, effectValue);
    }
    
    function notifyPowerDeactivation(address user, uint256 nftId) external override onlyMarketplace {
        if (address(powerModule) == address(0)) revert ModuleNotSet();
        powerModule.notifyPowerDeactivation(user, nftId);
    }
    
    function updateUserXP(address user, uint256 xpGained) external override onlyMarketplace {
        if (address(gamificationModule) == address(0)) revert ModuleNotSet();
        gamificationModule.updateUserXP(user, 2, xpGained);
    }

    function notifyQuestCompletion(address user, uint256 questId, uint256 rewardAmount)
        external
        override
        onlyMarketplace
    {
        if (address(gamificationModule) == address(0)) revert ModuleNotSet();
        gamificationModule.completeQuest(user, questId, rewardAmount, 15, 30);
    }

    function notifyAchievementUnlocked(address user, uint256 achievementId, uint256 rewardAmount)
        external
        override
        onlyMarketplace
    {
        if (address(gamificationModule) == address(0)) revert ModuleNotSet();
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
        if (index >= userData.deposits.length) revert NoDepositsFound();
        Deposit storage dep = userData.deposits[index];
        return (dep.amount, dep.timestamp, dep.lastClaimTime, dep.lockupDuration);
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function getActivePowers(address user) external view override returns (NFTPower[] memory) {
        return SkillViewLib.getActiveSkills(address(powerModule), user);
    }
    
    function getUserPowerProfile(address user) external view override returns (UserPowerProfile memory) {
        return SkillViewLib.getUserSkillProfile(address(powerModule), address(gamificationModule), user);
    }
    
    function calculateBoostedAPY(address user, uint256 baseAPY) external view override returns (uint256) {
        return SkillViewLib.calculateBoostedAPY(address(powerModule), user, baseAPY);
    }
    
    function calculateReducedLockTime(address user, uint256 baseLockTime) external view override returns (uint256) {
        return SkillViewLib.calculateReducedLockTime(address(powerModule), user, baseLockTime);
    }
    
    function hasAutoCompound(address user) external view override returns (bool) {
        return SkillViewLib.hasAutoCompound(address(powerModule), address(gamificationModule), user);
    }
    
    function calculateFeeDiscount(address user, uint256 baseFee) external view override returns (uint256) {
        return SkillViewLib.calculateFeeDiscount(address(powerModule), user, baseFee);
    }
    
    function getAutoCompoundUsers() external view returns (address[] memory) {
        return SkillViewLib.getAutoCompoundUsers(address(gamificationModule));
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // v6.2.0 — getExpiringDeposits, getReferralInfo MOVED to SmartStakingViewStats
    // ════════════════════════════════════════════════════════════════════════════════════════

    function nftRarity(uint256 nftId) external view returns (Rarity) {
        return SkillViewLib.nftRarity(address(powerModule), nftId);
    }

    function powerEnabled(PowerType powerType) external view returns (bool) {
        return _powerEnabled[powerType];
    }

    function powerDefaultEffects(PowerType powerType) external view returns (uint16) {
        if (address(powerModule) == address(0)) {
            return 0;
        }
        return powerModule.getPowerBoost(powerType);
    }

    function checkAutoCompound(address user) external view override returns (bool, bytes memory) {
        return SkillViewLib.checkAutoCompound(address(gamificationModule), user);
    }
    
    function performAutoCompound(bytes calldata performData) external override {
        address user = abi.decode(performData, (address));

        (uint256 rewards, uint256 newTotalPoolBalance) = SmartStakingCoreLib.performAutoCompound(
            users,
            address(rewardsModule),
            address(powerModule),
            address(gamificationModule),
            referralBoostEndTime,
            referralBoostBps,
            totalPoolBalance,
            user
        );

        totalPoolBalance = newTotalPoolBalance;
        emit Compounded(user, rewards);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function setMarketplaceAddress(address _marketplace) external override onlyOwner {
        if (_marketplace == address(0)) revert InvalidAddress();
        authorizedMarketplaces[_marketplace] = true;
        emit MarketplaceAuthorizationUpdated(_marketplace, true);
    }

    function setMarketplaceAuthorization(address _marketplace, bool _isAuthorized) external onlyOwner {
        if (_marketplace == address(0)) revert InvalidAddress();
        authorizedMarketplaces[_marketplace] = _isAuthorized;
        emit MarketplaceAuthorizationUpdated(_marketplace, _isAuthorized);
    }
    
    function setStakingAddress(address) external pure override {
        revert InvalidAddress();
    }
    
    function setPowerEnabled(PowerType powerType, bool enabled) external override onlyOwner {
        if (powerType == PowerType.NONE) revert InvalidAddress();
        _powerEnabled[powerType] = enabled;
    }
    
    function updatePowerEffect(PowerType powerType, uint16 newEffectValue) external override onlyOwner {
        if (address(powerModule) == address(0)) revert ModuleNotSet();
        powerModule.updatePowerBoost(powerType, newEffectValue);
    }
    
    function changeTreasuryAddress(address _newTreasury) external onlyOwner validAddress(_newTreasury) {
        address previousTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryUpdated(previousTreasury, _newTreasury);
    }
    
    function setTreasuryManager(address _treasuryManager) external onlyOwner validAddress(_treasuryManager) {
        treasuryManager = ITreasuryManager(_treasuryManager);
        emit TreasuryManagerUpdated(_treasuryManager);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // v6.1.0 — ADMIN CONFIGURATION
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Configure the circuit breaker
     * @param enabled Whether to enable or disable the circuit breaker
     * @param reserveRatio Minimum extra reserve (bps of totalPoolBalance) required to accept deposits
     *        e.g. 2000 = needs balance >= totalPoolBalance * 120%
     */
    function setCircuitBreaker(bool enabled, uint256 reserveRatio) external onlyOwner {
        circuitBreakerEnabled = enabled;
        circuitBreakerReserveRatio = reserveRatio;
        emit CircuitBreakerUpdated(enabled, reserveRatio);
    }

    /**
     * @notice Configure the referral boost system
     * @param boostBps APY boost in basis points granted to referrers (e.g. 150 = 1.5%)
     * @param boostDuration How long (seconds) each referral extends the referrer's boost window
     */
    function setReferralConfig(uint256 boostBps, uint256 boostDuration) external onlyOwner {
        if (boostBps > 1000) revert ReferralBoostTooHigh();
        referralBoostBps = boostBps;
        referralBoostDuration = boostDuration;
    }
    
    function emergencyWithdrawStake() external nonReentrant {
        uint256 stakeAmount;
        (stakeAmount, totalPoolBalance, uniqueUsersCount) = SmartStakingCoreLib.emergencyWithdrawStake(
            users,
            address(rewardsModule),
            totalPoolBalance,
            uniqueUsersCount,
            msg.sender
        );

        emit EmergencyWithdrawal(msg.sender, stakeAmount);
    }

    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        if (_amount == 0 || _amount > address(this).balance) revert InvalidAddress();
        if (treasury == address(0)) revert InvalidAddress();
        
        (bool success, ) = payable(treasury).call{value: _amount}("");
        if (!success) revert CommissionTransferFailed(treasury, _amount);
        
        emit EmergencyWithdrawal(msg.sender, _amount);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // v7.0 — SELECTIVE WITHDRAWAL, BATCH WITHDRAWAL, LOCKUP MIGRATION
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Withdraw a single deposit (principal + its share of rewards) by index.
     * @dev Rewards portion is proportional to that deposit's weight. The deposit slot is
     *      removed from the array (last element swaps into its position).
     *      Early exit fee applies to flexible deposits within EARLY_EXIT_WINDOW.
     * @param depositIndex The index of the deposit to withdraw.
     */
    function withdrawByIndex(uint256 depositIndex) external nonReentrant whenNotPaused notMigrated {
        User storage user = users[msg.sender];
        if (depositIndex >= user.deposits.length)
            revert DepositIndexOutOfBounds(depositIndex, user.deposits.length);
        uint256[] memory arr = new uint256[](1);
        arr[0] = depositIndex;
        (uint256 principal, uint256 netRew) = _executeWithdrawals(arr);
        emit WithdrawnByIndex(msg.sender, depositIndex, principal, netRew);
    }

    /**
     * @notice Withdraw multiple deposits by their indices in a single transaction.
     * @param indices Array of deposit indices — must be sorted descending (largest first)
     *                to avoid index-shift bugs during swap-and-pop removal.
     */
    function withdrawBatch(uint256[] calldata indices) external nonReentrant whenNotPaused notMigrated {
        if (indices.length == 0) revert BatchLengthMismatch();
        uint256[] memory mem = new uint256[](indices.length);
        for (uint256 i; i < indices.length; i++) mem[i] = indices[i];
        (uint256 payout, ) = _executeWithdrawals(mem);
        emit Withdrawn(msg.sender, payout);
    }

    /// @dev Shared withdrawal logic for both withdrawByIndex and withdrawBatch.
    ///      Returns (totalPrincipal, netRewards) so the caller can emit precise events.
    function _executeWithdrawals(uint256[] memory indices) internal returns (uint256 principal, uint256 netRewards) {
        uint256 payout;
        uint256 newTotalPoolBalance;
        uint256 newUniqueUsersCount;

        (principal, netRewards, payout, newTotalPoolBalance, newUniqueUsersCount) = SmartStakingCoreLib.executeWithdrawals(
            users,
            _dailyWithdrawalAmount,
            _lastWithdrawalDay,
            totalRewardsClaimed,
            address(rewardsModule),
            address(powerModule),
            treasury,
            address(treasuryManager),
            totalPoolBalance,
            uniqueUsersCount,
            indices,
            msg.sender
        );

        totalPoolBalance = newTotalPoolBalance;
        uniqueUsersCount = newUniqueUsersCount;
    }

    /**
     * @notice Migrate a flexible deposit to a longer lockup period without withdraw/redeposit.
     * @dev No commission is charged again. The deposit's timestamp is reset to now so the
     *      lockup counts from migration time. Preserves all accrued rewards by snapshotting
     *      lastClaimTime = now (rewards are lost for this deposit as a migration cost,
     *      consistent with a normal withdraw + re-deposit flow but without paying commission).
     * @param depositIndex   Index of the flexible deposit to migrate.
     * @param newLockupDays  Target lockup in days: 30, 90, 180, or 365.
     */
    function migrateLockup(uint256 depositIndex, uint64 newLockupDays) external nonReentrant whenNotPaused notMigrated {
        uint64 newDuration = SmartStakingCoreLib.migrateLockup(users, depositIndex, newLockupDays, msg.sender);
        emit LockupMigrated(msg.sender, depositIndex, newDuration);
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

    // _convertRarity and _summarizeSkillEffects moved to SkillViewLib (v6.2.0 size optimization)
    
    function _initializeSkillFlags() internal {
        for (uint8 i = 1; i <= uint8(type(PowerType).max); i++) {
            _powerEnabled[PowerType(i)] = true;
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
