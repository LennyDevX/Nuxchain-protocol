// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IStakingIntegration.sol";

/// @title SmartStakingViewCore
/// @notice Core view functions for user deposits, rewards and balances
/// @dev Part 1 of 3-part View contract split (Core, Stats, Skills)
contract SmartStakingViewCore {
    
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

    // ════════════════════════════════════════════════════════════════════════════════════════
    // v7.0 — CIRCUIT BREAKER, REINVESTMENT, TIER VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Returns daily-withdrawal circuit-breaker status for a user.
    /// @return limit          Protocol daily withdrawal cap (2 000 ether).
    /// @return usedToday      Amount the user has already withdrawn today.
    /// @return remaining      How much the user can still withdraw today.
    /// @return circuitActive  True when the global circuit breaker is enabled.
    function getDailyWithdrawalInfo(address _user) external view returns (
        uint256 limit,
        uint256 usedToday,
        uint256 remaining,
        bool    circuitActive
    ) {
        // Read DAILY_WITHDRAWAL_LIMIT constant via a public slot (2 000 ether)
        // The constant lives in Core — we read the scalar public vars via staticcall.
        (bool ok1, bytes memory d1) = stakingContract.staticcall(
            abi.encodeWithSignature("circuitBreakerEnabled()")
        );
        if (ok1 && d1.length >= 32) circuitActive = abi.decode(d1, (bool));

        // _dailyWithdrawalAmount is private, but Core exposes no getter.
        // We read it via a custom getter if available, otherwise return 0 gracefully.
        (bool ok2, bytes memory d2) = stakingContract.staticcall(
            abi.encodeWithSignature("getDailyWithdrawalUsed(address)", _user)
        );
        if (ok2 && d2.length >= 32) usedToday = abi.decode(d2, (uint256));

        limit = 2_000 ether;
        remaining = usedToday >= limit ? 0 : limit - usedToday;
    }

    /// @notice Returns a user's reinvestment (auto-compound) configuration.
    /// @return percentage   Basis points auto-compounded on each compound call (0-10000).
    /// @return description  Human-readable label (e.g. "50% reinvested").
    function getReinvestmentConfig(address _user) external view returns (
        uint256 percentage,
        string memory description
    ) {
        (bool ok, bytes memory d) = stakingContract.staticcall(
            abi.encodeWithSignature("reinvestmentPercentage(address)", _user)
        );
        if (ok && d.length >= 32) percentage = abi.decode(d, (uint256));

        if (percentage == 0)           description = "0% reinvested (full payout)";
        else if (percentage <= 2500)   description = "Partial reinvestment (<25%)";
        else if (percentage <= 5000)   description = "Moderate reinvestment (25-50%)";
        else if (percentage <= 7500)   description = "High reinvestment (50-75%)";
        else if (percentage < 10000)   description = "Aggressive reinvestment (75-99%)";
        else                           description = "100% auto-compound";
    }

    /// @notice Returns the user's staking tier, loyalty bonus, and days staked — via the Rewards module.
    /// @param _rewardsModule Address of the SmartStakingRewards contract.
    /// @return tierName      "Silver", "Gold", "Platinum", or "None".
    /// @return tierBonusBps  Tier APY bonus in basis points.
    /// @return loyaltyDays   Full days since first stake.
    /// @return loyaltyBps    Loyalty APY bonus in basis points.
    function getUserTierInfo(address _user, address _rewardsModule) external view returns (
        string memory tierName,
        uint256 tierBonusBps,
        uint256 loyaltyDays,
        uint256 loyaltyBps
    ) {
        if (_rewardsModule == address(0)) return ("None", 0, 0, 0);

        // getUserTier(totalDeposited)
        (, uint256 tDep, , ) = _getUserInfo(_user);
        (bool ok1, bytes memory d1) = _rewardsModule.staticcall(
            abi.encodeWithSignature("getUserTier(uint256)", tDep)
        );
        if (ok1 && d1.length >= 64) (tierName, tierBonusBps) = abi.decode(d1, (string, uint256));

        // getLoyaltyDays(user)
        (bool ok2, bytes memory d2) = _rewardsModule.staticcall(
            abi.encodeWithSignature("getLoyaltyDays(address)", _user)
        );
        if (ok2 && d2.length >= 32) loyaltyDays = abi.decode(d2, (uint256));

        // getLoyaltyBonus(user) returns uint16
        (bool ok3, bytes memory d3) = _rewardsModule.staticcall(
            abi.encodeWithSignature("getLoyaltyBonus(address)", _user)
        );
        if (ok3 && d3.length >= 32) loyaltyBps = abi.decode(d3, (uint256));
    }
}
