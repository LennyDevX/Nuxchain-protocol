// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title SmartStakingViewStats
/// @notice Statistics and analytics view functions for staking pool
/// @dev Part 2 of 3-part View contract split (Core, Stats, Skills)
contract SmartStakingViewStats {
    
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
    /// @notice SmartStakingRewards module — used to read live APY values.
    address public rewardsModule;
    address public owner;
    
    event StakingContractUpdated(address indexed newAddress);
    event RewardsModuleUpdated(address indexed newAddress);
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

    function setRewardsModule(address _rewardsModule) external onlyOwner {
        require(_rewardsModule != address(0), "Invalid address");
        rewardsModule = _rewardsModule;
        emit RewardsModuleUpdated(_rewardsModule);
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
    
    /// @notice Get APY rates for different lockup periods.
    /// @dev Reads live values from SmartStakingRewards when configured; falls back to
    ///      v6.3.0 constants so the view is always usable without a Rewards module.
    function getAPYRates() external view returns (
        uint256 flexibleAPY,
        uint256 locked30APY,
        uint256 locked90APY,
        uint256 locked180APY,
        uint256 locked365APY
    ) {
        if (rewardsModule != address(0)) {
            (bool ok, bytes memory data) = rewardsModule.staticcall(
                abi.encodeWithSignature("getBaseAPYs()")
            );
            if (ok && data.length >= 5 * 32) {
                uint256[] memory apys = abi.decode(data, (uint256[]));
                if (apys.length >= 5) {
                    return (apys[0], apys[1], apys[2], apys[3], apys[4]);
                }
            }
        }
        // Fallback: v6.3.0 constants
        return (86, 146, 193, 242, 255);
    }
    
    /// @notice Get hourly ROI rates for different lockup periods (v6.3.0)
    /// @dev Derived from APY bps: APY / 8760 = hourly bps (rounded)
    function getHourlyROIRates() external pure returns (uint256[5] memory rates) {
        rates[0] = 1;     // Flexible:  ~8.60% APY  ( 86 / 8760 ≈ 0.010% ≈ 1 bps)
        rates[1] = 2;     // 30-day:   ~14.60% APY  (146 / 8760 ≈ 0.017% ≈ 2 bps)
        rates[2] = 2;     // 90-day:   ~19.30% APY  (193 / 8760 ≈ 0.022% ≈ 2 bps)
        rates[3] = 3;     // 180-day:  ~24.20% APY  (242 / 8760 ≈ 0.028% ≈ 3 bps)
        rates[4] = 3;     // 365-day:  ~25.50% APY  (255 / 8760 ≈ 0.029% ≈ 3 bps)
        return rates;
    }
    
    /// @notice Get comprehensive staking rates info for frontend display.
    /// @dev Reads live APY from Rewards module when configured; v6.3.0 fallback otherwise.
    function getStakingRatesInfo() external view returns (StakingRatesInfo memory info) {
        info.lockupPeriods = [uint256(0), 30, 90, 180, 365];
        info.periodNames   = ["Flexible", "30 Days", "90 Days", "180 Days", "365 Days"];

        if (rewardsModule != address(0)) {
            (bool ok, bytes memory data) = rewardsModule.staticcall(
                abi.encodeWithSignature("getBaseAPYs()")
            );
            if (ok && data.length >= 5 * 32) {
                uint256[] memory apys = abi.decode(data, (uint256[]));
                if (apys.length >= 5) {
                    for (uint256 i; i < 5; i++) info.annualAPY[i] = apys[i];
                    // Hourly = APY / 8760 (rounded), minimum 1 bps
                    for (uint256 i; i < 5; i++) {
                        uint256 h = apys[i] / 8760;
                        info.hourlyROI[i] = h == 0 ? 1 : h;
                    }
                    return info;
                }
            }
        }
        // Fallback: v6.3.0 constants
        info.hourlyROI  = [uint256(1), 2, 2, 3, 3];
        info.annualAPY  = [uint256(86), 146, 193, 242, 255];
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
    // v6.2.0 — EXPIRY ALERTS & REFERRAL VIEW (delegated from CoreV2)
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Returns deposits expiring within `window` seconds for a user
     * @dev Read-only delegation of CoreV2.getExpiringDeposits
     * @param user The staker address
     * @param window Seconds window (e.g. 259200 = 3 days)
     * @return indices Deposit indices expiring in the window
     * @return unlockTimes Corresponding unlock timestamps
     * @return amounts Corresponding deposit amounts in wei
     */
    function getExpiringDeposits(
        address user,
        uint256 window
    ) external view returns (
        uint256[] memory indices,
        uint256[] memory unlockTimes,
        uint256[] memory amounts
    ) {
        (,,uint256 depCount,) = _getUserInfo(user);
        if (depCount == 0) {
            return (new uint256[](0), new uint256[](0), new uint256[](0));
        }

        uint256 deadline = block.timestamp + window;
        uint256 count = 0;

        // First pass: count matching deposits
        for (uint256 i = 0; i < depCount; i++) {
            (, uint64 ts,, uint64 dur) = _getUserDeposit(user, i);
            if (dur == 0) continue;
            uint256 unlockTime = uint256(ts) + uint256(dur);
            if (unlockTime > block.timestamp && unlockTime <= deadline) count++;
        }

        indices    = new uint256[](count);
        unlockTimes = new uint256[](count);
        amounts    = new uint256[](count);

        // Second pass: fill
        uint256 j = 0;
        for (uint256 i = 0; i < depCount; i++) {
            (uint128 amt, uint64 ts,, uint64 dur) = _getUserDeposit(user, i);
            if (dur == 0) continue;
            uint256 unlockTime = uint256(ts) + uint256(dur);
            if (unlockTime > block.timestamp && unlockTime <= deadline) {
                indices[j]     = i;
                unlockTimes[j] = unlockTime;
                amounts[j]     = uint256(amt);
                j++;
            }
        }
    }

    /**
     * @notice Returns referral status for a user
     * @dev Reads public state from CoreV2 via staticcall
     * @param user The address to query
     * @return referrer The address that referred this user (address(0) if none)
     * @return totalReferralsMade How many users this user has referred
     * @return boostEndTime Timestamp when referral APY boost expires
     * @return boostActive True if boost is currently active
     * @return currentBoostBps Active referral boost in basis points (0 if inactive)
     */
    function getReferralInfo(address user) external view returns (
        address referrer,
        uint256 totalReferralsMade,
        uint256 boostEndTime,
        bool    boostActive,
        uint256 currentBoostBps
    ) {
        (bool ok1, bytes memory d1) = stakingContract.staticcall(
            abi.encodeWithSignature("referrers(address)", user)
        );
        if (ok1 && d1.length >= 32) referrer = abi.decode(d1, (address));

        (bool ok2, bytes memory d2) = stakingContract.staticcall(
            abi.encodeWithSignature("referralCount(address)", user)
        );
        if (ok2 && d2.length >= 32) totalReferralsMade = abi.decode(d2, (uint256));

        (bool ok3, bytes memory d3) = stakingContract.staticcall(
            abi.encodeWithSignature("referralBoostEndTime(address)", user)
        );
        if (ok3 && d3.length >= 32) boostEndTime = abi.decode(d3, (uint256));

        (bool ok4, bytes memory d4) = stakingContract.staticcall(
            abi.encodeWithSignature("referralBoostBps()")
        );
        uint256 bps = 0;
        if (ok4 && d4.length >= 32) bps = abi.decode(d4, (uint256));

        boostActive     = boostEndTime > block.timestamp;
        currentBoostBps = boostActive ? bps : 0;
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
