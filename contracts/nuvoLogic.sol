// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title Simplified Staking Contract
/// @notice This contract allows users to deposit and withdraw POL with automatic reward calculation
/// @dev Implements pausable and reentrancy protection
contract NuvoLogic is Ownable, Pausable, ReentrancyGuard {
    using Address for address payable;
    using SafeMath for uint256;
    using Address for address payable;

    uint256 public constant HOURLY_ROI_PERCENTAGE = 200; // 0.02% per hour
    uint16 public constant MAX_ROI_PERCENTAGE = 12500; // 125%
    uint16 public constant COMMISSION_PERCENTAGE = 6; // 6% 
    uint256 public constant MAX_DEPOSIT = 10000 ether; // 10000 POL
    uint256 public constant MIN_DEPOSIT = 5 ether; // 5 POL
    uint256 public constant MAX_DEPOSITS_PER_USER = 300;
    uint256 public constant CONTRACT_VERSION = 1;

    uint256 public uniqueUsersCount;
    address public treasury;
    uint256 public totalPoolBalance;

    struct Deposit {
        uint256 amount;
        uint256 timestamp;
    }

    struct User {
        Deposit[] deposits;
    }

    struct UserInfo {
    uint256 totalDeposited;
    uint256 pendingRewards;
    uint256 lastWithdraw;
}

    mapping(address => User) private users;
    mapping(address => uint256) public lastWithdrawTime;

    event DepositMade(
        address indexed user,
        uint256 indexed depositId,
        uint256 amount,
        uint256 commission,
        uint256 timestamp
    );
    event WithdrawalMade(address indexed user, uint256 amount);
    event ContractPaused(address indexed owner);
    event ContractUnpaused(address indexed owner);
    event BalanceAdded(uint256 amount);
    event TreasuryAddressChanged(address indexed previousTreasury, address indexed newTreasury);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    address public newContractAddress;
    bool public migrated;

    modifier notMigrated() {
        require(!migrated, "Contract has been migrated");
        _;
    }

    constructor(address _treasury) {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }

    function changeTreasuryAddress(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Invalid treasury address");
        address previousTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryAddressChanged(previousTreasury, _newTreasury);
    }

    function deposit() external payable nonReentrant whenNotPaused notMigrated {
        require(msg.value >= MIN_DEPOSIT, "Deposit below minimum");
        require(msg.value <= MAX_DEPOSIT, "Deposit amount exceeds maximum limit");
        require(users[msg.sender].deposits.length < MAX_DEPOSITS_PER_USER, "Max deposits reached");

        uint256 commission = (msg.value * 600) / 10000;
        uint256 depositAmount = msg.value - commission;

        if (users[msg.sender].deposits.length == 0) {
            uniqueUsersCount++;
        }

        totalPoolBalance += depositAmount;
        uint256 depositId = users[msg.sender].deposits.length;

        users[msg.sender].deposits.push(Deposit({
            amount: depositAmount,
            timestamp: block.timestamp
        }));

        payable(treasury).transfer(commission);

        emit DepositMade(msg.sender, depositId, depositAmount, commission, block.timestamp);
    }

    function getTotalDeposit(address user) public view returns (uint256) {
        User storage userStruct = users[user];
        uint256 total = 0;
        for (uint256 i = 0; i < userStruct.deposits.length; i++) {
            total += userStruct.deposits[i].amount;
        }
        return total;
    }

function getUserInfo(address user) external view returns (UserInfo memory) {
    return UserInfo({
        totalDeposited: getTotalDeposit(user),
        pendingRewards: calculateRewards(user),
        lastWithdraw: lastWithdrawTime[user]
    });
}

    function getUserDeposits(address user) external view returns (Deposit[] memory) {
        return users[user].deposits;
    }

        function calculateRewards(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];
        uint256 totalRewards = 0;
    
        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            uint256 elapsedTime = (block.timestamp - userDeposit.timestamp) / 3600;
            uint256 depositAmount = userDeposit.amount * HOURLY_ROI_PERCENTAGE * elapsedTime / 1000000;
    
            uint256 maxReward = userDeposit.amount * MAX_ROI_PERCENTAGE / 10000;
            if (depositAmount > maxReward) {
                depositAmount = maxReward;
            }
    
            // Calcular bonificación por tiempo
            uint256 stakingTime = block.timestamp - userDeposit.timestamp;
            uint256 timeBonus = calculateTimeBonus(stakingTime);
            depositAmount = depositAmount + (depositAmount * timeBonus / 10000);
    
            totalRewards += depositAmount;
        }
    
        return totalRewards;
    }
    function withdraw() external nonReentrant whenNotPaused notMigrated {
        uint256 totalRewards = calculateRewards(msg.sender);
        require(totalRewards > 0, "No rewards to withdraw");
        lastWithdrawTime[msg.sender] = block.timestamp;
        require(totalRewards > 0, "No rewards to withdraw");

        uint256 commission = (totalRewards * 600) / 10000;
        uint256 netAmount = totalRewards - commission;

        for (uint256 i = 0; i < users[msg.sender].deposits.length; i++) {
            users[msg.sender].deposits[i].timestamp = block.timestamp;
        }

        payable(treasury).transfer(commission);
        payable(msg.sender).transfer(netAmount);

        emit WithdrawalMade(msg.sender, netAmount);
    }

    function emergencyUserWithdraw() external nonReentrant whenPaused {
        uint256 totalDeposit = getTotalDeposit(msg.sender);
        require(totalDeposit > 0, "No deposits to withdraw");

        totalPoolBalance -= totalDeposit;
        delete users[msg.sender];

        payable(msg.sender).transfer(totalDeposit);

        emit EmergencyWithdraw(msg.sender, totalDeposit);
    }

    function emergencyWithdraw(address to) external onlyOwner whenPaused {
        require(to != address(0), "Invalid address");
        uint256 balance = address(this).balance;
        payable(to).transfer(balance);
        emit EmergencyWithdraw(to, balance);
    }


    function withdrawAll() external nonReentrant whenNotPaused notMigrated {
        uint256 totalDeposit = getTotalDeposit(msg.sender);
        uint256 totalRewards = calculateRewards(msg.sender);
        uint256 totalAmount = totalDeposit.add(totalRewards);
    
        require(totalAmount > 0, "No funds to withdraw");
    
        uint256 commission = totalRewards.mul(COMMISSION_PERCENTAGE).div(10000);
        uint256 netAmount = totalAmount.sub(commission);
    
        totalPoolBalance = totalPoolBalance.sub(totalDeposit);
        delete users[msg.sender];
    
        payable(treasury).sendValue(commission);
        payable(msg.sender).sendValue(netAmount);
    
        emit WithdrawalMade(msg.sender, netAmount);
        emit EmergencyWithdraw(msg.sender, totalDeposit); // Reusing event for full withdrawal
    }

    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    function addBalance() external payable onlyOwner {
        require(msg.value > 0, "Amount must be greater than 0");
        totalPoolBalance += msg.value;
        emit BalanceAdded(msg.value);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function migrateToNewContract(address _newContractAddress) external onlyOwner {
        require(_newContractAddress != address(0), "Invalid address");
        require(!migrated, "Already migrated");
        newContractAddress = _newContractAddress;
        migrated = true;
    }

    function calculateTimeBonus(uint256 stakingTime) internal pure returns (uint256) {
        if (stakingTime >= 365 days) return 500;     // +5%
        if (stakingTime >= 180 days) return 300;     // +3%
        if (stakingTime >= 90 days) return 100;      // +1%
        return 0;
    }

    modifier checkSolvency() {
        require(address(this).balance >= totalPoolBalance, 
                "Contract is underfunded");
        _;
    }

    receive() external payable {}
}