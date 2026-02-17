// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title EnhancedSmartStakingViewStats
/// @notice Statistics and analytics view functions for staking pool
/// @dev Part 2 of 3-part View contract split (Core, Stats, Skills)
contract EnhancedSmartStakingViewStats {
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS - STATS & ANALYTICS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    struct StakingRatesInfo {
        uint256[5] lockupPeriods;     // [0, 30, 90, 180, 365] days
        uint256[5] hourlyROI;          // Hourly ROI in basis points
        uint256[5] annualAPY;          // Annual APY in basis points
        string[5] periodNames;         // Human readable names
    }
    
    struct GlobalStakingStats {
        uint256 totalValueLocked;
        uint256 totalUniqueUsers;
        uint256 contractBalance;
        uint256 availableRewards;
        uint8 healthStatus;
        uint256 timestamp;
    }
    
    struct UserRewardsProjection {
        uint256 hourlyRewards;
        uint256 dailyRewards;
        uint256 weeklyRewards;
        uint256 monthlyRewards;
        uint256 yearlyRewards;
        uint256 currentPendingRewards;
    }
    
    struct LockupAnalysis {
        uint256 totalFlexible;
        uint256 totalLocked30;
        uint256 totalLocked90;
        uint256 totalLocked180;
        uint256 totalLocked365;
        uint256 nextUnlockAmount;
        uint256 nextUnlockTime;
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
    // POOL STATISTICS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Get pool statistics for dashboard display
    function getPoolStats() external view returns (
        uint256 totalPoolValue,
        uint256 totalRewards,
        uint256 activeUsersCount,
        uint256 totalDeposits,
        uint256 contractBalanceValue
    ) {
        totalPoolValue = _getTotalPoolBalance();
        activeUsersCount = _getUniqueUsersCount();
        contractBalanceValue = _getContractBalance();
        
        totalDeposits = 0; // Would need to aggregate from deposits
        totalRewards = 0; // Would need to aggregate from all user rewards
        
        return (totalPoolValue, totalRewards, activeUsersCount, totalDeposits, contractBalanceValue);
    }
    
    /// @notice Get stake distribution statistics
    function getStakeDistribution() external pure returns (
        uint256 flexibleTotal,
        uint256 locked30Total,
        uint256 locked90Total,
        uint256 locked180Total,
        uint256 locked365Total,
        uint256 totalLockedValue,
        uint256 totalFlexibleValue
    ) {
        // Return placeholder values - would need aggregation
        return (0, 0, 0, 0, 0, 0, 0);
    }
    
    /// @notice Get recommended APY rates for different lockup periods
    function getAPYRates() external pure returns (
        uint256 flexibleAPY,
        uint256 locked30APY,
        uint256 locked90APY,
        uint256 locked180APY,
        uint256 locked365APY
    ) {
        // APY in basis points (100 = 1%)
        return (
            263,   // 2.63% flexible
            438,   // 4.38% 30-day
            788,   // 7.88% 90-day
            1051,  // 10.51% 180-day
            1577   // 15.77% 365-day
        );
    }
    
    /// @notice Get hourly ROI rates for different lockup periods
    function getHourlyROIRates() external pure returns (uint256[5] memory rates) {
        // Hourly rates derived from APY (APY / 365 / 24)
        rates[0] = 3;     // Flexible: ~2.63% APY
        rates[1] = 5;     // 30-day: ~4.38% APY
        rates[2] = 9;     // 90-day: ~7.88% APY
        rates[3] = 12;    // 180-day: ~10.51% APY
        rates[4] = 18;    // 365-day: ~15.77% APY
        return rates;
    }
    
    /// @notice Get comprehensive staking rates info for frontend display
    function getStakingRatesInfo() external pure returns (StakingRatesInfo memory info) {
        info.lockupPeriods = [uint256(0), 30, 90, 180, 365];
        info.hourlyROI = [uint256(3), 5, 9, 12, 18];
        info.annualAPY = [uint256(263), 438, 788, 1051, 1577];
        info.periodNames = ["Flexible", "30 Days", "90 Days", "180 Days", "365 Days"];
        return info;
    }
    
    /// @notice Get global staking statistics for dashboard
    function getGlobalStats() external view returns (GlobalStakingStats memory stats) {
        stats.totalValueLocked = _getTotalPoolBalance();
        stats.totalUniqueUsers = _getUniqueUsersCount();
        stats.contractBalance = _getContractBalance();
        stats.availableRewards = stats.contractBalance >= stats.totalValueLocked 
            ? stats.contractBalance - stats.totalValueLocked 
            : 0;
        (stats.healthStatus, , , ) = this.getPoolHealth();
        stats.timestamp = block.timestamp;
        return stats;
    }
    
    /// @notice Get pool health status based on various metrics
    function getPoolHealth() external view returns (
        uint8 healthStatus,
        string memory statusMessage,
        uint256 reserveRatio,
        string memory description
    ) {
        uint256 poolBalance = _getTotalPoolBalance();
        if (poolBalance == 0) {
            return (3, "Empty", 10000, "No deposits in pool");
        }
        
        uint256 currentBalance = _getContractBalance();
        
        // Calculate reserve ratio (in basis points: 10000 = 100%)
        reserveRatio = (currentBalance * 10000) / poolBalance;
        
        // Determine health status based on reserve ratio
        if (reserveRatio >= 15000) {
            healthStatus = 4;
            statusMessage = "Excellent";
            description = "Pool has abundant reserves for all rewards";
        } else if (reserveRatio >= 10000) {
            healthStatus = 3;
            statusMessage = "Healthy";
            description = "Pool has sufficient reserves";
        } else if (reserveRatio >= 5000) {
            healthStatus = 2;
            statusMessage = "Moderate";
            description = "Pool reserves are adequate but watch liquidity";
        } else if (reserveRatio >= 2000) {
            healthStatus = 1;
            statusMessage = "Low Funds";
            description = "Pool reserves are low, may struggle with rewards";
        } else {
            healthStatus = 0;
            statusMessage = "Critical";
            description = "Pool reserves critically low, rewards at risk";
        }
        
        return (healthStatus, statusMessage, reserveRatio, description);
    }
    
    /// @notice Get complete dashboard data in one call
    function getDashboardData(address _user) external view returns (
        uint256 poolTotalValue,
        uint256 poolActiveUsers,
        uint256 poolContractBalance,
        uint8 poolHealthStatus,
        uint256 userStaked,
        uint256 userRewards,
        uint256 userDeposits,
        uint256 userFlexible,
        uint256 userLocked
    ) {
        poolTotalValue = _getTotalPoolBalance();
        poolActiveUsers = _getUniqueUsersCount();
        poolContractBalance = _getContractBalance();
        
        (poolHealthStatus, , , ) = this.getPoolHealth();
        
        (uint256 tDep, uint256 tRew, uint256 dCount, ) = _getUserInfo(_user);
        userStaked = tDep;
        userRewards = tRew;
        userDeposits = dCount;
        
        // Calculate balance breakdown
        for (uint256 i = 0; i < dCount; i++) {
            (uint128 amount, uint64 timestamp, , uint64 lockupDuration) = _getUserDeposit(_user, i);
            uint256 unlockTime = uint256(timestamp) + uint256(lockupDuration);
            bool isLocked = block.timestamp < unlockTime && lockupDuration > 0;
            
            if (lockupDuration == 0) {
                userFlexible += uint256(amount);
            } else if (isLocked) {
                userLocked += uint256(amount);
            }
        }
        
        return (poolTotalValue, poolActiveUsers, poolContractBalance, poolHealthStatus, userStaked, userRewards, userDeposits, userFlexible, userLocked);
    }
    
    /// @notice Get user's projected rewards over different time periods
    function getUserRewardsProjection(address _user) external view returns (UserRewardsProjection memory projection) {
        uint256 totalRewards = _calculateRewards(_user);
        
        // Get average time for deposits to calculate daily rate
        (,,uint256 depCount,) = _getUserInfo(_user);
        if (depCount == 0) {
            return projection;
        }
        
        uint256 totalTimeLapsed;
        uint256 activeDepositCount;
        
        for (uint256 i = 0; i < depCount; i++) {
            (,uint64 timestamp,,) = _getUserDeposit(_user, i);
            if (uint256(timestamp) < block.timestamp) {
                totalTimeLapsed += (block.timestamp - uint256(timestamp));
                activeDepositCount++;
            }
        }
        
        if (activeDepositCount == 0 || totalTimeLapsed == 0) {
            return projection;
        }
        
        uint256 avgTimeLapsed = totalTimeLapsed / activeDepositCount;
        if (avgTimeLapsed == 0) avgTimeLapsed = 1 days;
        
        projection.dailyRewards = (totalRewards * 1 days) / avgTimeLapsed;
        projection.hourlyRewards = projection.dailyRewards / 24;
        projection.weeklyRewards = projection.dailyRewards * 7;
        projection.monthlyRewards = projection.dailyRewards * 30;
        projection.yearlyRewards = projection.dailyRewards * 365;
        projection.currentPendingRewards = totalRewards;
        
        return projection;
    }
    
    /// @notice Get detailed lockup analysis for a user
    function getUserLockupAnalysis(address _user) external view returns (LockupAnalysis memory analysis) {
        (, , uint256 depCount, ) = _getUserInfo(_user);
        uint256 earliestUnlock = type(uint256).max;
        
        for (uint256 i = 0; i < depCount; i++) {
            (uint128 amount, uint64 timestamp, , uint64 lockupDuration) = _getUserDeposit(_user, i);
            uint256 unlockTime = uint256(timestamp) + uint256(lockupDuration);
            
            if (lockupDuration == 0) {
                analysis.totalFlexible += uint256(amount);
            } else if (lockupDuration == 30 days) {
                analysis.totalLocked30 += uint256(amount);
            } else if (lockupDuration == 90 days) {
                analysis.totalLocked90 += uint256(amount);
            } else if (lockupDuration == 180 days) {
                analysis.totalLocked180 += uint256(amount);
            } else if (lockupDuration == 365 days) {
                analysis.totalLocked365 += uint256(amount);
            }
            
            if (unlockTime > block.timestamp && unlockTime < earliestUnlock) {
                earliestUnlock = unlockTime;
                analysis.nextUnlockAmount = uint256(amount);
            }
        }
        
        analysis.nextUnlockTime = earliestUnlock == type(uint256).max ? 0 : earliestUnlock;
        return analysis;
    }
    
    /// @notice Estimate earnings breakdown for a user
    function getEarningsBreakdown(address _user) external view returns (
        uint256 dailyEarnings,
        uint256 monthlyEarnings,
        uint256 annualEarnings
    ) {
        (,,uint256 depCount,) = _getUserInfo(_user);
        if (depCount == 0) {
            return (0, 0, 0);
        }
        
        uint256 totalRewards = _calculateRewards(_user);
        uint256 totalTimeLapsed;
        uint256 activeDepositCount;
        
        for (uint256 i = 0; i < depCount; i++) {
            (,uint64 timestamp,,) = _getUserDeposit(_user, i);
            if (uint256(timestamp) < block.timestamp) {
                totalTimeLapsed += (block.timestamp - uint256(timestamp));
                activeDepositCount++;
            }
        }
        
        if (activeDepositCount == 0 || totalTimeLapsed == 0) {
            return (0, 0, 0);
        }
        
        uint256 avgTimeLapsed = totalTimeLapsed / activeDepositCount;
        if (avgTimeLapsed == 0) avgTimeLapsed = 1 days;
        
        dailyEarnings = (totalRewards * 1 days) / avgTimeLapsed;
        monthlyEarnings = (dailyEarnings * 30);
        annualEarnings = (dailyEarnings * 365);
        
        return (dailyEarnings, monthlyEarnings, annualEarnings);
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
    
    function _getUniqueUsersCount() internal view returns (uint256) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("uniqueUsersCount()")
        );
        require(success, "uniqueUsersCount failed");
        return abi.decode(data, (uint256));
    }
    
    function _calculateRewards(address user) internal view returns (uint256) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("calculateRewards(address)", user)
        );
        require(success, "calculateRewards failed");
        return abi.decode(data, (uint256));
    }
}
