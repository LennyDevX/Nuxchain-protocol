// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingContract is Ownable, Pausable {
    using SafeMath for uint256;

    uint256 public constant HOURLY_ROI_PERCENTAGE = 190; // 0.0190% per hour
    uint16 public constant MAX_ROI_PERCENTAGE = 13000; // 125%
    uint16 public constant COMMISSION_PERCENTAGE = 510; // 5.1% 
    uint256 public constant MAX_DEPOSIT = 6000 ether; // 6000 Matic

    uint256 public uniqueUsersCount;
    address public treasury;
    uint256 public totalPoolBalance;

    struct Deposit {
        uint256 amount;
        uint256 timestamp;
    }

    struct User {
        Deposit[] deposits;
        uint256 lastClaimTime;
        uint256 totalClaimedRewards; // Total de recompensas reclamadas por el usuario
    }

    mapping(address => User) private users;

    event DepositMade(address indexed user, uint256 amount, uint256 commission);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardWithdrawn(address indexed user, uint256 amount);
    event ContractPaused(address indexed owner);
    event ContractUnpaused(address indexed owner);
    event BalanceAdded(uint256 amount);
    event TreasuryAddressChanged(address indexed previousTreasury, address indexed newTreasury);


    address public newContractAddress;
    bool public migrated;

    constructor(address _treasury) Pausable() Ownable() {
        treasury = _treasury;
    }

   

    // Función para cambiar la dirección de la tesorería, solo puede ser llamada por el propietario
    function changeTreasuryAddress(address _newTreasury) public onlyOwner {
        require(_newTreasury != address(0), "Invalid treasury address");
        address previousTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryAddressChanged(previousTreasury, _newTreasury);
    }

    function deposit() public payable whenNotPaused {
        require(msg.value <= MAX_DEPOSIT, "Deposit exceeds the maximum");

        uint256 commission = msg.value.mul(COMMISSION_PERCENTAGE).div(10000);
        uint256 depositAmount = msg.value.sub(commission);

        if (users[msg.sender].deposits.length == 0) {
            uniqueUsersCount++;
        }

        totalPoolBalance = totalPoolBalance.add(depositAmount);
        users[msg.sender].deposits.push(Deposit({
            amount: depositAmount,
            timestamp: block.timestamp
        }));
        users[msg.sender].lastClaimTime = block.timestamp;

        (bool success, ) = payable(treasury).call{value: commission}("");
        require(success, "Failed to transfer commission");

        emit DepositMade(msg.sender, depositAmount, commission);
    }

    function getTotalDeposit(address user) public view returns (uint256) {
        User storage userStruct = users[user];
        uint256 total = 0;
        for (uint256 i = 0; i < userStruct.deposits.length; i++) {
            total = total.add(userStruct.deposits[i].amount);
        }
        return total;
    }

    function getLastClaimTime(address user) public view returns (uint256) {
        return users[user].lastClaimTime;
    }

    function calculateRewards(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];

            // Calcula el tiempo transcurrido desde el último reclamo en horas
            uint256 elapsedTime = (block.timestamp - userDeposit.timestamp) / 3600;

            // Calcula las recompensas para este depósito basadas en el tiempo transcurrido desde el último reclamo específico del depósito
            uint256 depositAmount = userDeposit.amount * HOURLY_ROI_PERCENTAGE * elapsedTime / 1000000;

            // Aplica el límite máximo de ROI basado en el tiempo transcurrido desde el último reclamo específico del depósito
            uint256 maxReward = userDeposit.amount * MAX_ROI_PERCENTAGE / 10000;
            uint256 rewardsSinceLastClaim = depositAmount + user.totalClaimedRewards;
            if (rewardsSinceLastClaim > maxReward) {
                depositAmount = maxReward - user.totalClaimedRewards;
            }

            totalRewards += depositAmount;
        }

        return totalRewards;
    }

    function claimRewards() public whenNotPaused {
        User storage user = users[msg.sender];
        uint256 totalRewards = calculateRewards(msg.sender);

        // Calcula la comisión
        uint256 commission = totalRewards * COMMISSION_PERCENTAGE / 10000;
        require(totalPoolBalance >= totalRewards + commission, "Not enough funds in the pool");
        require(totalRewards > 0, "No rewards to claim");
        require(totalRewards + getTotalDeposit(msg.sender) <= MAX_DEPOSIT, "Claimed rewards exceed maximum deposit limit");

        totalRewards -= commission;
        totalPoolBalance -= totalRewards + commission;

        // Actualiza el tiempo del último reclamo DESPUÉS de sumar las recompensas
        user.lastClaimTime = block.timestamp; 

        // Transfiere la comisión al tesoro
        (bool success, ) = payable(treasury).call{value: commission}("");
        require(success, "Failed to transfer commission");

        // Agrega las recompensas al saldo del usuario
        user.totalClaimedRewards += totalRewards;

        emit RewardClaimed(msg.sender, totalRewards);
    }

    function totalRewardsClaimed(address user) public view returns (uint256) {
    return users[user].totalClaimedRewards;
    }


    function withdrawRewards() public whenNotPaused {
        uint256 claimedRewards = users[msg.sender].totalClaimedRewards; // Obtiene las recompensas reclamadas del usuario
        require(claimedRewards > 0, "No claimed rewards to withdraw"); // Verifica que haya recompensas reclamadas para retirar
        
        users[msg.sender].totalClaimedRewards = 0; // Establece las recompensas reclamadas del usuario a cero
        
        (bool success, ) = payable(msg.sender).call{value: claimedRewards}(""); // Transfiere las recompensas reclamadas al usuario
        require(success, "Failed to transfer rewards");
        
        emit RewardWithdrawn(msg.sender, claimedRewards); // Emite el evento de retirada de recompensas
    }

    function emergencyWithdraw(address to) public onlyOwner whenNotPaused {
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "Emergency withdraw failed");
    }

    function pause() public onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }

    function unpause() public onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    function addBalance() public payable onlyOwner {
        require(msg.value > 0, "Amount must be greater than 0");
        totalPoolBalance = totalPoolBalance.add(msg.value);
        emit BalanceAdded(msg.value);
    }

    receive() external payable {}

    function migrateToNewContract(address _newContractAddress) public onlyOwner {
        require(!migrated, "Migration has already been done");
        newContractAddress = _newContractAddress;
        migrated = true;
    }
}