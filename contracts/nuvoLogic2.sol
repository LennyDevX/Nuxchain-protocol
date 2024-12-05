// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title NuvoLogic Staking Contract
/// @notice Secure staking contract with automatic reward calculation
/// @dev Implements security best practices and optimization patterns
contract NuvoLogic is Ownable, Pausable, ReentrancyGuard {
    using Address for address payable;
    using SafeMath for uint256;

    // Constants
    uint256 private constant HOURLY_ROI_PERCENTAGE = 200; // 0.02% per hour
    uint16 private constant MAX_ROI_PERCENTAGE = 12500; // 125%
    uint16 private constant COMMISSION_PERCENTAGE = 600; // 6% (in basis points)
    uint256 private constant MAX_DEPOSIT = 10000 ether;
    uint256 private constant MIN_DEPOSIT = 5 ether;
    uint16 private constant MAX_DEPOSITS_PER_USER = 300;
    uint256 private constant CONTRACT_VERSION = 1;
    uint256 private constant BASIS_POINTS = 10000;

    // State variables
    uint256 public uniqueUsersCount;
    address public treasury;
    uint256 public totalPoolBalance;
    bool public migrated;
    address public newContractAddress;

    // Structs
    struct Deposit {
        uint256 amount;
        uint256 timestamp;
    }

    struct User {
        Deposit[] deposits;
        uint256 lastWithdrawTime;
        uint256 totalDeposited;
    }

    struct UserInfo {
        uint256 totalDeposited;
        uint256 pendingRewards;
        uint256 lastWithdraw;
    }

    // Mappings
    mapping(address => User) private users;

    // Events
    event DepositMade(
        address indexed user,
        uint256 indexed depositId,
        uint256 amount,
        uint256 commission,
        uint256 timestamp
    );
    event WithdrawalMade(address indexed user, uint256 amount, uint256 commission);
    event ContractPaused(address indexed owner, uint256 timestamp);
    event ContractUnpaused(address indexed owner, uint256 timestamp);
    event BalanceAdded(uint256 amount, uint256 timestamp);
    event TreasuryAddressChanged(
        address indexed previousTreasury,
        address indexed newTreasury,
        uint256 timestamp
    );
    event EmergencyWithdraw(address indexed user, uint256 amount, uint256 timestamp);
    event ContractMigrated(address indexed newContract, uint256 timestamp);

    // Modifiers
    modifier notMigrated() {
        require(!migrated, "Contract has been migrated");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier sufficientDeposit(uint256 _amount) {
        require(_amount >= MIN_DEPOSIT, "Deposit below minimum");
        require(_amount <= MAX_DEPOSIT, "Deposit exceeds maximum");
        _;
    }

    /// @notice Contract constructor
    /// @param _treasury Address of the treasury
    constructor(address _treasury) validAddress(_treasury) {
        treasury = _treasury;
    }

    /// @notice Change treasury address
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

    /// @notice Deposit funds into the contract
    function deposit() 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        notMigrated 
        sufficientDeposit(msg.value) 
    {
        require(users[msg.sender].deposits.length < MAX_DEPOSITS_PER_USER, "Max deposits reached");

        uint256 commission = msg.value.mul(COMMISSION_PERCENTAGE).div(BASIS_POINTS);
        uint256 depositAmount = msg.value.sub(commission);

        if (users[msg.sender].deposits.length == 0) {
            uniqueUsersCount = uniqueUsersCount.add(1);
        }

        totalPoolBalance = totalPoolBalance.add(depositAmount);
        uint256 depositId = users[msg.sender].deposits.length;

        users[msg.sender].deposits.push(Deposit({
            amount: depositAmount,
            timestamp: block.timestamp
        }));
        users[msg.sender].totalDeposited = users[msg.sender].totalDeposited.add(depositAmount);

        payable(treasury).sendValue(commission);

        emit DepositMade(msg.sender, depositId, depositAmount, commission, block.timestamp);
    }

    /// @notice Calculate rewards for a user
    /// @param userAddress Address of the user
    /// @return Total rewards
    function calculateRewards(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];
        if (user.deposits.length == 0) return 0;

        uint256 totalRewards = 0;
        
        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            uint256 elapsedTime = block.timestamp.sub(userDeposit.timestamp).div(3600);
            
            uint256 reward = userDeposit.amount
                .mul(HOURLY_ROI_PERCENTAGE)
                .mul(elapsedTime)
                .div(1000000);

            uint256 maxReward = userDeposit.amount.mul(MAX_ROI_PERCENTAGE).div(BASIS_POINTS);
            reward = reward > maxReward ? maxReward : reward;

            uint256 timeBonus = calculateTimeBonus(block.timestamp.sub(userDeposit.timestamp));
            reward = reward.add(reward.mul(timeBonus).div(BASIS_POINTS));

            totalRewards = totalRewards.add(reward);
        }

        return totalRewards;
    }

    /// @notice Calculate time bonus for staking duration
    /// @param stakingTime Duration of staking in seconds
    /// @return Bonus percentage in basis points
    function calculateTimeBonus(uint256 stakingTime) internal pure returns (uint256) {
        if (stakingTime >= 365 days) return 500;     // 5%
        if (stakingTime >= 180 days) return 300;     // 3%
        if (stakingTime >= 90 days) return 100;      // 1%
        return 0;
    }

    /// @notice Withdraw rewards
    function withdraw() external nonReentrant whenNotPaused notMigrated {
        uint256 totalRewards = calculateRewards(msg.sender);
        require(totalRewards > 0, "No rewards to withdraw");

        uint256 commission = totalRewards.mul(COMMISSION_PERCENTAGE).div(BASIS_POINTS);
        uint256 netAmount = totalRewards.sub(commission);

        require(address(this).balance >= netAmount.add(commission), "Insufficient contract balance");

        // Reset reward calculation timestamp
        for (uint256 i = 0; i < users[msg.sender].deposits.length; i++) {
            users[msg.sender].deposits[i].timestamp = block.timestamp;
        }
        users[msg.sender].lastWithdrawTime = block.timestamp;

        payable(treasury).sendValue(commission);
        payable(msg.sender).sendValue(netAmount);

        emit WithdrawalMade(msg.sender, netAmount, commission);
    }

    /// @notice Emergency withdrawal for users during pause
    function emergencyUserWithdraw() external nonReentrant whenPaused {
        User storage user = users[msg.sender];
        require(user.totalDeposited > 0, "No deposits to withdraw");

        uint256 totalDeposit = user.totalDeposited;
        totalPoolBalance = totalPoolBalance.sub(totalDeposit);
        
        delete users[msg.sender];

        payable(msg.sender).sendValue(totalDeposit);

        emit EmergencyWithdraw(msg.sender, totalDeposit, block.timestamp);
    }

    /// @notice Emergency withdrawal for owner
    /// @param to Address to send funds to
    function emergencyWithdraw(address to) external onlyOwner whenPaused validAddress(to) {
        uint256 balance = address(this).balance;
        payable(to).sendValue(balance);
        emit EmergencyWithdraw(to, balance, block.timestamp);
    }

    /// @notice Withdraw all deposits and rewards
    function withdrawAll() external nonReentrant whenNotPaused notMigrated {
        User storage user = users[msg.sender];
        require(user.totalDeposited > 0, "No deposits to withdraw");
    
        uint256 totalRewards = calculateRewards(msg.sender);
        uint256 totalAmount = user.totalDeposited;
        uint256 commission = 0;
        
        if (totalRewards > 0) {
            commission = totalRewards.mul(COMMISSION_PERCENTAGE).div(BASIS_POINTS);
            totalAmount = totalAmount.add(totalRewards.sub(commission));
            
            require(address(this).balance >= totalAmount.add(commission), "Insufficient contract balance");
            payable(treasury).sendValue(commission);
        }
    
        totalPoolBalance = totalPoolBalance.sub(user.totalDeposited);
        delete users[msg.sender];
    
        payable(msg.sender).sendValue(totalAmount);
    
        emit WithdrawalMade(msg.sender, totalAmount, commission);
        emit EmergencyWithdraw(msg.sender, user.totalDeposited, block.timestamp);
    }

    /// @notice Get total deposits for a user
    /// @param userAddress Address of the user
    /// @return Total deposit amount
    function getTotalDeposit(address userAddress) public view returns (uint256) {
        return users[userAddress].totalDeposited;
    }

    /// @notice Get user deposits
    /// @param userAddress Address of the user
    /// @return Array of deposits
    function getUserDeposits(address userAddress) 
        external 
        view 
        validAddress(userAddress) 
        returns (Deposit[] memory) 
    {
        return users[userAddress].deposits;
    }

    /// @notice Get detailed user information
    /// @param userAddress Address of the user
    /// @return User information struct
    function getUserInfo(address userAddress) external view returns (UserInfo memory) {
        return UserInfo({
            totalDeposited: getTotalDeposit(userAddress),
            pendingRewards: calculateRewards(userAddress),
            lastWithdraw: users[userAddress].lastWithdrawTime
        });
    }

    /// @notice Add balance to the contract
    /// @dev Only owner can call this function
    function addBalance() external payable onlyOwner {
        require(msg.value > 0, "Amount must be greater than 0");
        totalPoolBalance = totalPoolBalance.add(msg.value);
        emit BalanceAdded(msg.value, block.timestamp);
    }

    /// @notice Pause the contract
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender, block.timestamp);
    }

    /// @notice Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender, block.timestamp);
    }

    /// @notice Get contract balance
    /// @return Contract balance
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Migrate to new contract
    /// @param _newContractAddress Address of new contract
    function migrateToNewContract(address _newContractAddress) 
        external 
        onlyOwner 
        validAddress(_newContractAddress) 
    {
        require(!migrated, "Already migrated");
        newContractAddress = _newContractAddress;
        migrated = true;
        emit ContractMigrated(_newContractAddress, block.timestamp);
    }

    receive() external payable {
        require(msg.sender == treasury, "Only treasury can send funds directly");
    }
}