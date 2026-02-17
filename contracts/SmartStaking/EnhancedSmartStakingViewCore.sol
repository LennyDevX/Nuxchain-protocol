// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IStakingIntegration.sol";

/// @title EnhancedSmartStakingViewCore
/// @notice Core view functions for user deposits, rewards and balances
/// @dev Part 1 of 3-part View contract split (Core, Stats, Skills)
contract EnhancedSmartStakingViewCore {
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS - CORE VIEW DATA
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    struct DepositDetails {
        uint256 depositIndex;
        uint256 amount;
        uint256 currentRewards;
        uint256 timestamp;
        uint256 lastClaimTime;
        uint256 lockupDuration;
        uint256 unlockTime;
        string lockupType; // "Flexible", "30 Days", "90 Days", "180 Days", "365 Days"
        bool isLocked;
        bool isWithdrawable;
    }
    
    struct UserPortfolio {
        uint256 totalDeposited;
        uint256 totalRewards;
        uint256 totalPortfolioValue;
        uint256 depositCount;
        uint256 flexibleBalance;
        uint256 lockedBalance;
        uint256 unlockedBalance;
        uint256 lastWithdrawTime;
        DepositDetails[] deposits;
    }
    
    struct UserDepositInfo {
        uint256 totalDeposited;
        uint256 totalRewards;
        uint256 depositCount;
        uint256 lastWithdrawTime;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    address public stakingContract;
    address public owner;
    
    event StakingContractUpdated(address indexed newAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor(address _stakingContract) {
        require(_stakingContract != address(0), "Invalid staking contract");
        stakingContract = _stakingContract;
        owner = msg.sender;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid staking contract");
        stakingContract = _stakingContract;
        emit StakingContractUpdated(_stakingContract);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CORE DEPOSIT QUERIES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Get total deposited amount for a user
    function getTotalDeposit(address user) external view returns (uint256) {
        (uint256 totalDep, , , ) = _getUserInfo(user);
        return totalDep;
    }
    
    /// @notice Get user detailed deposit information
    function getUserDeposits(address user) external view returns (UserDepositInfo memory) {
        (uint256 totalDep, uint256 totalRew, uint256 depCount, uint256 lastWith) = _getUserInfo(user);
        return UserDepositInfo({
            totalDeposited: totalDep,
            totalRewards: totalRew,
            depositCount: depCount,
            lastWithdrawTime: lastWith
        });
    }
    
    /// @notice Get single deposit details by index
    function getDepositDetails(address _user, uint256 _depositIndex) external view returns (DepositDetails memory) {
        return _getDepositDetailsInternal(_user, _depositIndex);
    }
    
    /// @notice Get contract balance information
    function getContractBalance() external view returns (
        uint256 contractBalance,
        uint256 totalPoolBalance_,
        uint256 availableForRewards
    ) {
        contractBalance = _getContractBalance();
        totalPoolBalance_ = _getTotalPoolBalance();
        availableForRewards = contractBalance >= totalPoolBalance_ ? contractBalance - totalPoolBalance_ : 0;
    }
    
    /// @notice Get summary of all deposits by lockup type
    function getDepositSummaryByType(address _user) external view returns (uint256[] memory summaries) {
        (, , uint256 depCount, ) = _getUserInfo(_user);
        summaries = new uint256[](5); // [flexible, 30d, 90d, 180d, 365d]
        
        for (uint256 i = 0; i < depCount; i++) {
            (uint128 amount, , , uint64 lockupDuration) = _getUserDeposit(_user, i);
            
            if (lockupDuration == 0) {
                summaries[0] += uint256(amount);
            } else if (lockupDuration == 30 days) {
                summaries[1] += uint256(amount);
            } else if (lockupDuration == 90 days) {
                summaries[2] += uint256(amount);
            } else if (lockupDuration == 180 days) {
                summaries[3] += uint256(amount);
            } else if (lockupDuration == 365 days) {
                summaries[4] += uint256(amount);
            }
        }
        
        return summaries;
    }
    
    /// @notice Check if user has any locked deposits
    function getLockedDepositInfo(address _user) external view returns (bool hasLocked, uint256 lockedAmount) {
        (, , uint256 depCount, ) = _getUserInfo(_user);
        
        for (uint256 i = 0; i < depCount; i++) {
            (uint128 amount, uint64 timestamp, , uint64 lockupDuration) = _getUserDeposit(_user, i);
            if (lockupDuration > 0 && block.timestamp < uint256(timestamp) + uint256(lockupDuration)) {
                hasLocked = true;
                lockedAmount += uint256(amount);
            }
        }
        
        return (hasLocked, lockedAmount);
    }
    
    /// @notice Check which deposits are withdrawable
    function getWithdrawableDeposits(address _user) external view returns (uint256[] memory withdrawableIndices, uint256 withdrawableAmount) {
        (, , uint256 depCount, ) = _getUserInfo(_user);
        uint256[] memory tempIndices = new uint256[](depCount);
        uint256 count = 0;
        
        for (uint256 i = 0; i < depCount; i++) {
            (uint128 amount, uint64 timestamp, , uint64 lockupDuration) = _getUserDeposit(_user, i);
            if (lockupDuration == 0 || block.timestamp >= uint256(timestamp) + uint256(lockupDuration)) {
                tempIndices[count] = i;
                withdrawableAmount += uint256(amount);
                count++;
            }
        }
        
        // Resize array
        withdrawableIndices = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            withdrawableIndices[i] = tempIndices[i];
        }
        
        return (withdrawableIndices, withdrawableAmount);
    }
    
    /// @notice Get time remaining until next deposit is unlocked
    function getNextUnlockTime(address _user) external view returns (uint256 secondsUntilUnlock, uint256 nextUnlockTime) {
        (, , uint256 depCount, ) = _getUserInfo(_user);
        uint256 earliestUnlock = type(uint256).max;
        
        for (uint256 i = 0; i < depCount; i++) {
            (,uint64 timestamp,,uint64 lockupDuration) = _getUserDeposit(_user, i);
            if (lockupDuration > 0) {
                uint256 unlockTime = uint256(timestamp) + uint256(lockupDuration);
                if (unlockTime > block.timestamp && unlockTime < earliestUnlock) {
                    earliestUnlock = unlockTime;
                }
            }
        }
        
        if (earliestUnlock == type(uint256).max) {
            return (0, 0);
        }
        
        return (earliestUnlock - block.timestamp, earliestUnlock);
    }
    
    /// @notice Get dashboard summary for a single user
    function getDashboardUserSummary(address _user) external view returns (
        uint256 userStaked,
        uint256 userPendingRewards,
        uint256 userDepositCount,
        uint256 userFlexibleBalance,
        uint256 userLockedBalance,
        uint256 userUnlockedBalance
    ) {
        (uint256 tDep, uint256 tRew, uint256 dCount, ) = _getUserInfo(_user);
        userDepositCount = dCount;
        userStaked = tDep;
        userPendingRewards = tRew;
        
        // Get balance breakdown by type
        for (uint256 i = 0; i < dCount; i++) {
            (uint128 amount, uint64 timestamp, , uint64 lockupDuration) = _getUserDeposit(_user, i);
            uint256 unlockTime = uint256(timestamp) + uint256(lockupDuration);
            bool isLocked = block.timestamp < unlockTime && lockupDuration > 0;
            
            if (lockupDuration == 0) {
                userFlexibleBalance += uint256(amount);
            } else if (isLocked) {
                userLockedBalance += uint256(amount);
            } else {
                userUnlockedBalance += uint256(amount);
            }
        }
        
        return (userStaked, userPendingRewards, userDepositCount, userFlexibleBalance, userLockedBalance, userUnlockedBalance);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL DELEGATION FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function _getUserInfo(address user) internal view returns (uint256, uint256, uint256, uint256) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("getUserInfo(address)", user)
        );
        require(success, "getUserInfo failed");
        return abi.decode(data, (uint256, uint256, uint256, uint256));
    }
    
    function _getUserDeposit(address user, uint256 index) internal view returns (uint128, uint64, uint64, uint64) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("getUserDeposit(address,uint256)", user, index)
        );
        require(success, "getUserDeposit failed");
        return abi.decode(data, (uint128, uint64, uint64, uint64));
    }
    
    function _getContractBalance() internal view returns (uint256) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("getContractBalance()")
        );
        require(success, "getContractBalance failed");
        return abi.decode(data, (uint256));
    }
    
    function _getTotalPoolBalance() internal view returns (uint256) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("totalPoolBalance()")
        );
        require(success, "totalPoolBalance failed");
        return abi.decode(data, (uint256));
    }
    
    function _calculateRewards(address user) internal view returns (uint256) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("calculateRewards(address)", user)
        );
        require(success, "calculateRewards failed");
        return abi.decode(data, (uint256));
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPER FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function _getDepositDetailsInternal(address _user, uint256 _index) internal view returns (DepositDetails memory) {
        (uint128 amount, uint64 timestamp, uint64 lastClaimTime, uint64 lockupDuration) = _getUserDeposit(_user, _index);
        
        uint256 unlockTime = uint256(timestamp) + uint256(lockupDuration);
        bool isLocked = block.timestamp < unlockTime && lockupDuration > 0;
        
        string memory lockupType;
        if (lockupDuration == 0) {
            lockupType = "Flexible";
        } else if (lockupDuration == 30 days) {
            lockupType = "30 Days";
        } else if (lockupDuration == 90 days) {
            lockupType = "90 Days";
        } else if (lockupDuration == 180 days) {
            lockupType = "180 Days";
        } else if (lockupDuration == 365 days) {
            lockupType = "365 Days";
        }
        
        return DepositDetails({
            depositIndex: _index,
            amount: uint256(amount),
            currentRewards: _calculateRewards(_user),
            timestamp: uint256(timestamp),
            lastClaimTime: uint256(lastClaimTime),
            lockupDuration: uint256(lockupDuration),
            unlockTime: unlockTime,
            lockupType: lockupType,
            isLocked: isLocked,
            isWithdrawable: !isLocked
        });
    }
}
