// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @title NuvoLogic Staking Contract v3.0
/// @notice A staking protocol that allows users to earn rewards based on time and amount staked
/// @dev Implements security measures including reentrancy protection, pausability, and ownership controls
/// @custom:security-contact security@nuvo.com
/// @custom:version 3.0.0
/// @custom:solc-version 0.8.30
contract SmartStaking is Ownable, Pausable, ReentrancyGuard {
    using Address for address payable;

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS (Gas optimized - immutable where possible)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    uint256 private constant HOURLY_ROI_PERCENTAGE = 100; // 0.01% per hour
    uint16 private constant MAX_ROI_PERCENTAGE = 12500; // 125%
    uint16 private constant COMMISSION_PERCENTAGE = 600; // 6% (in basis points)
    uint256 private constant MAX_DEPOSIT = 10000 ether;
    uint256 private constant MIN_DEPOSIT = 5 ether;
    uint16 private constant MAX_DEPOSITS_PER_USER = 300;
    uint256 private constant CONTRACT_VERSION = 3;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant SECONDS_PER_HOUR = 3600;
    uint256 private constant REWARD_PRECISION = 1000000;

    // Time constants for bonuses (gas optimization)
    uint256 private constant THIRTY_DAYS = 30 days;
    uint256 private constant NINETY_DAYS = 90 days;
    uint256 private constant ONE_HUNDRED_EIGHTY_DAYS = 180 days;
    uint256 private constant THREE_HUNDRED_SIXTY_FIVE_DAYS = 365 days;

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES (Optimized packing)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Address of the treasury wallet
    address public treasury;
    
    /// @notice Address of the new contract for migration
    address public newContractAddress;
    
    /// @notice Total balance in the staking pool
    uint256 public totalPoolBalance;
    
    /// @notice Accumulated commission if transfer fails
    uint256 public pendingCommission;
    
    /// @notice Count of unique users who have staked
    uint256 public uniqueUsersCount;
    
    /// @notice Whether the contract has been migrated
    bool public migrated;

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS (Optimized for storage)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Structure representing a user deposit
    /// @dev Packed to optimize storage slots
    struct Deposit {
        uint128 amount;          // Sufficient for max deposit (10k ETH)
        uint64 timestamp;        // Unix timestamp fits in uint64 until year 584,942,417,355
        uint64 lastClaimTime;    // Same as above
    }

    /// @notice Structure representing user data
    struct User {
        Deposit[] deposits;      // Dynamic array of deposits
        uint128 totalDeposited;  // Total amount deposited by user
        uint64 lastWithdrawTime; // Last withdrawal timestamp
    }

    /// @notice Structure for external user information queries
    struct UserInfo {
        uint256 totalDeposited;
        uint256 pendingRewards;
        uint256 lastWithdraw;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // MAPPINGS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Maps user addresses to their staking data
    mapping(address => User) private users;

    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS (Enhanced with indexed parameters)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Emitted when a user makes a deposit
    event DepositMade(
        address indexed user,
        uint256 indexed depositId,
        uint256 amount,
        uint256 commission,
        uint256 indexed timestamp
    );
    
    /// @notice Emitted when a user withdraws rewards
    event WithdrawalMade(
        address indexed user, 
        uint256 amount, 
        uint256 commission,
        uint256 indexed timestamp
    );
    
    /// @notice Emitted when contract is paused
    event ContractPaused(address indexed owner, uint256 indexed timestamp);
    
    /// @notice Emitted when contract is unpaused
    event ContractUnpaused(address indexed owner, uint256 indexed timestamp);
    
    /// @notice Emitted when balance is added to contract
    event BalanceAdded(uint256 amount, uint256 indexed timestamp);
    
    /// @notice Emitted when treasury address changes
    event TreasuryAddressChanged(
        address indexed previousTreasury,
        address indexed newTreasury,
        uint256 indexed timestamp
    );
    
    /// @notice Emitted when user makes emergency withdrawal
    event EmergencyWithdrawUser(
        address indexed user, 
        uint256 amount, 
        uint256 indexed timestamp
    );
    
    /// @notice Emitted when owner makes emergency withdrawal
    event EmergencyWithdrawOwner(
        address indexed owner, 
        address indexed to, 
        uint256 amount, 
        uint256 indexed timestamp
    );
    
    /// @notice Emitted when contract is migrated
    event ContractMigrated(address indexed newContract, uint256 indexed timestamp);
    
    /// @notice Emitted when commission is paid
    event CommissionPaid(
        address indexed receiver, 
        uint256 amount, 
        uint256 indexed timestamp
    );

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CUSTOM ERRORS (Gas efficient error handling)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Thrown when deposit is below minimum
    error DepositTooLow(uint256 provided, uint256 minimum);
    
    /// @notice Thrown when deposit exceeds maximum
    error DepositTooHigh(uint256 provided, uint256 maximum);
    
    /// @notice Thrown when user reaches maximum deposits
    error MaxDepositsReached(address user, uint16 maxDeposits);
    
    /// @notice Thrown when address is zero
    error InvalidAddress();
    
    /// @notice Thrown when contract is migrated
    error ContractIsMigrated();
    
    /// @notice Thrown when no rewards available
    error NoRewardsAvailable();
    
    /// @notice Thrown when insufficient balance
    error InsufficientBalance();
    
    /// @notice Thrown when no deposits found
    error NoDepositsFound();
    
    /// @notice Thrown when already migrated
    error AlreadyMigrated();
    
    /// @notice Thrown when no pending commission
    error NoPendingCommission();
    
    /// @notice Thrown when unauthorized sender
    error UnauthorizedSender();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // MODIFIERS (Enhanced with custom errors)
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

    /// @notice Validates deposit amount
    modifier sufficientDeposit(uint256 _amount) {
        if (_amount < MIN_DEPOSIT) revert DepositTooLow(_amount, MIN_DEPOSIT);
        if (_amount > MAX_DEPOSIT) revert DepositTooHigh(_amount, MAX_DEPOSIT);
        _;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Initializes the contract with treasury address
    /// @param _treasury Address of the treasury wallet
    constructor(address _treasury) validAddress(_treasury) {
        treasury = _treasury;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Changes the treasury address
    /// @param _newTreasury New treasury address
    function changeTreasuryAddress(address _newTreasury) 
        external 
        onlyOwner 
        validAddress(_newTreasury) 
    {
        address previousTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryAddressChanged(previousTreasury, _newTreasury, block.timestamp);
    }

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender, block.timestamp);
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender, block.timestamp);
    }

    /// @notice Adds balance to the contract (owner only)
    function addBalance() external payable onlyOwner {
        if (msg.value == 0) revert DepositTooLow(0, 1);
        
        totalPoolBalance += msg.value;
        emit BalanceAdded(msg.value, block.timestamp);
    }

    /// @notice Migrates to a new contract
    /// @param _newContractAddress Address of the new contract
    function migrateToNewContract(address _newContractAddress) 
        external 
        onlyOwner 
        validAddress(_newContractAddress) 
    {
        if (migrated) revert AlreadyMigrated();
        
        newContractAddress = _newContractAddress;
        migrated = true;
        emit ContractMigrated(_newContractAddress, block.timestamp);
    }

    /// @notice Withdraws accumulated pending commissions
    function withdrawPendingCommission() external onlyOwner {
        if (pendingCommission == 0) revert NoPendingCommission();
        
        uint256 amount = pendingCommission;
        pendingCommission = 0;
        
        (bool sent, ) = payable(treasury).call{value: amount}("");
        if (!sent) revert InsufficientBalance();
        
        emit CommissionPaid(treasury, amount, block.timestamp);
    }

    /// @notice Emergency withdrawal for owner during pause
    /// @param to Address to send funds to
    function emergencyWithdraw(address to) 
        external 
        onlyOwner 
        whenPaused 
        validAddress(to) 
    {
        uint256 balance = address(this).balance;
        payable(to).sendValue(balance);
        emit EmergencyWithdrawOwner(msg.sender, to, balance, block.timestamp);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // USER FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Allows users to stake tokens
    /// @dev Implements commission calculation and fallback mechanism
    function deposit() 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        notMigrated 
        sufficientDeposit(msg.value) 
    {
        User storage user = users[msg.sender];
        
        if (user.deposits.length >= MAX_DEPOSITS_PER_USER) {
            revert MaxDepositsReached(msg.sender, MAX_DEPOSITS_PER_USER);
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
        
        uint256 depositId = user.deposits.length;
        uint64 currentTime = uint64(block.timestamp);

        // Add new deposit
        user.deposits.push(Deposit({
            amount: uint128(depositAmount),
            timestamp: currentTime,
            lastClaimTime: currentTime
        }));

        // Handle commission transfer with fallback
        _transferCommission(commission);
        
        emit DepositMade(msg.sender, depositId, depositAmount, commission, block.timestamp);
    }

    /// @notice Withdraws accumulated rewards
    function withdraw() external nonReentrant whenNotPaused notMigrated {
        uint256 totalRewards = calculateRewards(msg.sender);
        if (totalRewards == 0) revert NoRewardsAvailable();

        uint256 commission = (totalRewards * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 netAmount = totalRewards - commission;

        if (address(this).balance < netAmount + commission) {
            revert InsufficientBalance();
        }

        // Update claim times
        User storage user = users[msg.sender];
        uint64 currentTime = uint64(block.timestamp);
        
        for (uint256 i; i < user.deposits.length;) {
            user.deposits[i].lastClaimTime = currentTime;
            unchecked { ++i; }
        }
        user.lastWithdrawTime = currentTime;

        // Handle transfers
        _transferCommission(commission);
        payable(msg.sender).sendValue(netAmount);

        emit WithdrawalMade(msg.sender, netAmount, commission, block.timestamp);
    }

    /// @notice Withdraws all deposits and accumulated rewards
    function withdrawAll() external nonReentrant whenNotPaused notMigrated {
        User storage user = users[msg.sender];
        if (user.totalDeposited == 0) revert NoDepositsFound();

        uint256 totalRewards = calculateRewards(msg.sender);
        uint256 totalAmount = user.totalDeposited;
        uint256 commission = 0;

        if (totalRewards > 0) {
            commission = (totalRewards * COMMISSION_PERCENTAGE) / BASIS_POINTS;
            totalAmount += totalRewards - commission;
        }

        if (address(this).balance < totalAmount + commission) {
            revert InsufficientBalance();
        }

        // Update pool balance
        totalPoolBalance -= user.totalDeposited;

        // Transfer funds
        if (commission > 0) {
            _transferCommission(commission);
        }
        payable(msg.sender).sendValue(totalAmount);

        // Clear user data
        delete users[msg.sender];

        emit WithdrawalMade(msg.sender, totalAmount, commission, block.timestamp);
        emit EmergencyWithdrawUser(msg.sender, user.totalDeposited, block.timestamp);
    }

    /// @notice Emergency withdrawal for users during pause
    function emergencyUserWithdraw() external nonReentrant whenPaused {
        User storage user = users[msg.sender];
        if (user.totalDeposited == 0) revert NoDepositsFound();

        uint256 totalDeposit = user.totalDeposited;
        totalPoolBalance -= totalDeposit;
        
        delete users[msg.sender];
        payable(msg.sender).sendValue(totalDeposit);

        emit EmergencyWithdrawUser(msg.sender, totalDeposit, block.timestamp);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS (Gas optimized)
    // ════════════════════════════════════════════════════════════════════════════════════════

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
            uint256 elapsedHours = (block.timestamp - userDeposit.lastClaimTime) / SECONDS_PER_HOUR;
            
            if (elapsedHours > 0) {
                // Base reward calculation
                uint256 reward = (uint256(userDeposit.amount) * HOURLY_ROI_PERCENTAGE * elapsedHours) / REWARD_PRECISION;
                
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

    /// @notice Gets total deposits for a user
    /// @param userAddress Address of the user
    /// @return Total deposited amount
    function getTotalDeposit(address userAddress) external view returns (uint256) {
        return users[userAddress].totalDeposited;
    }

    /// @notice Gets all deposits for a user
    /// @param userAddress Address of the user
    /// @return Array of user deposits
    function getUserDeposits(address userAddress) 
        external 
        view 
        validAddress(userAddress) 
        returns (Deposit[] memory) 
    {
        return users[userAddress].deposits;
    }

    /// @notice Gets comprehensive user information
    /// @param userAddress Address of the user
    /// @return UserInfo struct with user data
    function getUserInfo(address userAddress) external view returns (UserInfo memory) {
        User storage user = users[userAddress];
        return UserInfo({
            totalDeposited: user.totalDeposited,
            pendingRewards: calculateRewards(userAddress),
            lastWithdraw: user.lastWithdrawTime
        });
    }

    /// @notice Gets contract balance
    /// @return Current contract balance
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Gets contract version
    /// @return Contract version number
    function getContractVersion() external pure returns (uint256) {
        return CONTRACT_VERSION;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS (Gas optimized)
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Calculates time bonus based on staking duration
    /// @param stakingTime Duration of staking in seconds
    /// @return Bonus percentage in basis points
    function _calculateTimeBonus(uint256 stakingTime) internal pure returns (uint256) {
        if (stakingTime >= THREE_HUNDRED_SIXTY_FIVE_DAYS) return 500;     // 5%
        if (stakingTime >= ONE_HUNDRED_EIGHTY_DAYS) return 300;           // 3%
        if (stakingTime >= NINETY_DAYS) return 100;                      // 1%
        if (stakingTime >= THIRTY_DAYS) return 50;                       // 0.5%
        return 0;
    }

    /// @notice Handles commission transfer with fallback mechanism
    /// @param commission Amount of commission to transfer
    function _transferCommission(uint256 commission) internal {
        (bool sent, ) = payable(treasury).call{value: commission}("");
        if (!sent) {
            pendingCommission += commission;
        }
        emit CommissionPaid(treasury, commission, block.timestamp);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // RECEIVE FUNCTION (Restricted)
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Restricted receive function - only treasury can send funds
    receive() external payable {
        if (msg.sender != treasury) revert UnauthorizedSender();
    }
}