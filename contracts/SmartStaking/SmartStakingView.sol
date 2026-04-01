// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "../interfaces/IStakingIntegration.sol";

/// @title IStakingViewData
/// @notice Interface for view data access from staking contract
interface IStakingViewData {
    // Core user info
    function getUserInfo(address user) external view returns (uint256, uint256, uint256, uint256);
    function calculateRewards(address user) external view returns (uint256);
    
    // User deposits access
    function getUser(address user) external view returns (address[] memory, uint256, uint64);
    function getUserDeposit(address user, uint256 index) external view returns (uint128, uint64, uint64, uint64);
    
    // State variables
    function totalPoolBalance() external view returns (uint256);
    function uniqueUsersCount() external view returns (uint256);
    function getContractBalance() external view returns (uint256);
    
    // Skills and Gamification
    function getUserPowerProfile(address user) external view returns (IStakingIntegration.UserPowerProfile memory);
    function getActivePowers(address user) external view returns (IStakingIntegration.NFTPower[] memory);
    function calculateBoostedRewards(address user) external view returns (uint256);
    function calculateBoostedRewardsWithRarityMultiplier(address user) external view returns (uint256);
    function nftRarity(uint256 nftId) external view returns (IStakingIntegration.Rarity);
    function powerEnabled(IStakingIntegration.PowerType powerType) external view returns (bool);
    function powerDefaultEffects(IStakingIntegration.PowerType powerType) external view returns (uint16);
    function getAutoCompoundUsers() external view returns (address[] memory);
    // v6.2.0 — skill calculation wrappers exposed to View
    function calculateBoostedAPY(address user, uint256 baseAPY) external view returns (uint256);
    function calculateReducedLockTime(address user, uint256 baseLockTime) external view returns (uint256);
    function calculateFeeDiscount(address user, uint256 baseFee) external view returns (uint256);
}

/// @title SmartStakingView
/// @notice View functions module for querying staking contract data
/// @dev Separate contract to keep main staking contract under size limit
/// @custom:security-contact security@nuvo.com
/// @custom:version 6.2.0 - Skill wrappers + v6.2 APY
contract SmartStakingView {
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS - DEPOSIT & PORTFOLIO
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @dev Detailed deposit information for frontend display
    struct DepositDetails {
        uint256 depositIndex;
        uint256 amount;
        uint256 currentRewards;
        uint256 timestamp;
        uint256 lastClaimTime;
        uint256 lockupDuration;
        uint256 unlockTime;
        uint8 lockupTypeId; // 0=Flexible, 1=30d, 2=90d, 3=180d, 4=365d
        bool isLocked;
        bool isWithdrawable;
    }
    
    /// @dev User portfolio summary for frontend dashboard
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
    
    IStakingViewData public stakingContract;
    address public owner;
    
    event StakingContractUpdated(address indexed newAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert();
        _;
    }
    
    constructor(address _stakingContract) {
        if (_stakingContract == address(0)) revert();
        stakingContract = IStakingViewData(_stakingContract);
        owner = msg.sender;
    }
    
    /// @notice Update staking contract reference
    function setStakingContract(address _stakingContract) external onlyOwner {
        if (_stakingContract == address(0)) revert();
        stakingContract = IStakingViewData(_stakingContract);
        emit StakingContractUpdated(_stakingContract);
    }
    
    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // USER DEPOSIT QUERIES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Get total deposited amount for a user
    function getTotalDeposit(address user) external view returns (uint256) {
        (uint256 totalDeposited, , , ) = stakingContract.getUserInfo(user);
        return totalDeposited;
    }
    
    /// @notice Get user detailed information
    function getUserDeposits(address user) external view returns (UserDepositInfo memory) {
        (uint256 totalDeposited, uint256 totalRewards, uint256 depositCount, uint256 lastWithdraw) = stakingContract.getUserInfo(user);
        return UserDepositInfo({
            totalDeposited: totalDeposited,
            totalRewards: totalRewards,
            depositCount: depositCount,
            lastWithdrawTime: lastWithdraw
        });
    }
    
    /// @notice Get user info combined with active skills
    function getUserInfoWithSkills(address user) external view returns (UserInfoWithSkills memory) {
        (uint256 totalDeposited, uint256 totalRewards, uint256 depositCount, uint256 lastWithdraw) = stakingContract.getUserInfo(user);
        IStakingIntegration.UserPowerProfile memory skillProfile = stakingContract.getUserPowerProfile(user);
        IStakingIntegration.NFTPower[] memory activeSkills = stakingContract.getActivePowers(user);
        
        return UserInfoWithSkills({
            totalDeposited: totalDeposited,
            totalRewards: totalRewards,
            depositCount: depositCount,
            lastWithdrawTime: lastWithdraw,
            skillProfile: skillProfile,
            activeSkills: activeSkills
        });
    }
    
    /// @notice Get active skills with detailed information
    function getActiveSkillsWithDetails(address user) external view returns (SkillDetails[] memory) {
        IStakingIntegration.NFTPower[] memory skills = stakingContract.getActivePowers(user);
        SkillDetails[] memory details = new SkillDetails[](skills.length);
        
        for (uint256 i = 0; i < skills.length; i++) {
            details[i] = SkillDetails({
                powerType: skills[i].powerType,
                effectValue: skills[i].effectValue,
                rarity: skills[i].rarity,
                activatedAt: skills[i].activatedAt,
                cooldownEnds: skills[i].cooldownEnds,
                isActive: skills[i].isActive,
                rarityBoost: _getRarityBoost(skills[i].rarity)
            });
        }
        return details;
    }
    
    /// @notice Get available skill configuration
    function getAvailableSkillsConfiguration() external view returns (SkillConfig[] memory) {
        SkillConfig[] memory configs = new SkillConfig[](7);
        configs[0] = _createSkillConfig(IStakingIntegration.PowerType.STAKE_BOOST_I,   keccak256("+5% APY"));
        configs[1] = _createSkillConfig(IStakingIntegration.PowerType.STAKE_BOOST_II,  keccak256("+10% APY"));
        configs[2] = _createSkillConfig(IStakingIntegration.PowerType.STAKE_BOOST_III, keccak256("+20% APY"));
        configs[3] = _createSkillConfig(IStakingIntegration.PowerType.AUTO_COMPOUND,   keccak256("Auto compound"));
        configs[4] = _createSkillConfig(IStakingIntegration.PowerType.LOCK_REDUCER,    keccak256("-25% lock time"));
        configs[5] = _createSkillConfig(IStakingIntegration.PowerType.FEE_REDUCER_I,   keccak256("-10% fees"));
        configs[6] = _createSkillConfig(IStakingIntegration.PowerType.FEE_REDUCER_II,  keccak256("-25% fees"));
        return configs;
    }
    
    /// @notice Get rarity information for an NFT skill
    function getSkillRarity(uint256 nftId) external view returns (
        IStakingIntegration.Rarity rarity,
        uint256 rarityBoost,
        uint8 stars
    ) {
        rarity = stakingContract.nftRarity(nftId);
        rarityBoost = _getRarityBoost(rarity);
        stars = _rarityToStars(rarity);
    }
    
    /// @notice Get detailed user statistics
    function getUserDetailedStats(address user) external view returns (UserStats memory) {
        (uint256 totalDeposited, uint256 totalRewards, uint256 depositCount, uint256 lastWithdraw) = stakingContract.getUserInfo(user);
        IStakingIntegration.UserPowerProfile memory skillProfile = stakingContract.getUserPowerProfile(user);
        IStakingIntegration.NFTPower[] memory activeSkills = stakingContract.getActivePowers(user);
        uint256 boostedRewards = stakingContract.calculateBoostedRewards(user);
        uint256 boostedWithRarity = stakingContract.calculateBoostedRewardsWithRarityMultiplier(user);
        
        return UserStats({
            totalDeposited: totalDeposited,
            totalRewards: totalRewards,
            boostedRewards: boostedRewards,
            boostedRewardsWithRarity: boostedWithRarity,
            depositCount: depositCount,
            lastWithdrawTime: lastWithdraw,
            userLevel: skillProfile.level,
            userXP: skillProfile.totalXP,
            maxActiveSkills: skillProfile.maxActiveSkills,
            activeSkillsCount: uint8(activeSkills.length),
            stakingBoostTotal: skillProfile.stakingBoostTotal,
            feeDiscountTotal: skillProfile.feeDiscountTotal,
            hasAutoCompound: skillProfile.hasAutoCompound
        });
    }
    
    /// @notice Get auto-compound users paginated
    function getAutoCompoundUsersPage(
        uint256 page,
        uint256 pageSize
    ) external view returns (
        address[] memory users,
        uint256 totalPages,
        uint256 currentPage
    ) {
        address[] memory allUsers = stakingContract.getAutoCompoundUsers();
        uint256 totalUsers = allUsers.length;
        
        totalPages = (totalUsers + pageSize - 1) / pageSize;
        if (!(page < totalPages || totalUsers == 0)) revert();
        
        uint256 startIdx = page * pageSize;
        uint256 endIdx = startIdx + pageSize;
        if (endIdx > totalUsers) {
            endIdx = totalUsers;
        }
        
        uint256 resultSize = endIdx - startIdx;
        users = new address[](resultSize);
        
        for (uint256 i = 0; i < resultSize; i++) {
            users[i] = allUsers[startIdx + i];
        }
        
        return (users, totalPages, page);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADDITIONAL VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Get portfolio value summary
    function getPortfolioSummary(address user) external view returns (PortfolioSummary memory) {
        (uint256 totalDeposited, , uint256 depositCount, ) = stakingContract.getUserInfo(user);
        uint256 boostedRewards = stakingContract.calculateBoostedRewards(user);
        uint256 totalValue = totalDeposited + boostedRewards;
        
        return PortfolioSummary({
            totalDeposited: totalDeposited,
            pendingRewards: boostedRewards,
            totalValue: totalValue,
            depositCount: depositCount,
            rewardEfficiency: totalDeposited > 0 ? (boostedRewards * 100) / totalDeposited : 0
        });
    }

    /// @notice Check if user has any assets staked
    function hasActiveStake(address user) external view returns (bool) {
        (uint256 totalDeposited, , , ) = stakingContract.getUserInfo(user);
        return totalDeposited > 0;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // v6.2.0 — SKILL CALCULATION WRAPPERS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Calculate effective APY for a user after applying their skill boosts
    /// @param user The staker address
    /// @param baseAPY Base APY in basis points (e.g. 96 for 9.6%)
    /// @return Boosted APY in basis points
    function calculateBoostedAPY(address user, uint256 baseAPY) external view returns (uint256) {
        return stakingContract.calculateBoostedAPY(user, baseAPY);
    }

    /// @notice Calculate effective lock time after applying LOCK_REDUCER skill
    /// @param user The staker address
    /// @param baseLockTime Original lock time in seconds
    /// @return Reduced lock time in seconds
    function calculateReducedLockTime(address user, uint256 baseLockTime) external view returns (uint256) {
        return stakingContract.calculateReducedLockTime(user, baseLockTime);
    }

    /// @notice Calculate effective fee after applying FEE_REDUCER skill(s)
    /// @param user The staker address
    /// @param baseFee Base fee in wei
    /// @return Discounted fee in wei
    function calculateFeeDiscount(address user, uint256 baseFee) external view returns (uint256) {
        return stakingContract.calculateFeeDiscount(user, baseFee);
    }

    /// @notice Get a full skill summary for a user: boosted APY per period + fee discount + reduced lock times
    /// @param user The staker address
    /// @return boostedAPYs Array of effective APY per lockup period [flex,30d,90d,180d,365d] in bps
    /// @return effectiveFeeDiscount The user's effective fee discount in bps (already applied to 6% base)
    /// @return reducedLockTimes Effective lock durations in seconds [0,30d,90d,180d,365d] after reductions
    function getUserSkillSummary(address user) external view returns (
        uint256[5] memory boostedAPYs,
        uint256 effectiveFeeDiscount,
        uint256[5] memory reducedLockTimes
    ) {
        uint256[5] memory basePeriods = [uint256(0), 30 days, 90 days, 180 days, 365 days];
        uint256[5] memory baseAPYList = [uint256(96), 172, 227, 303, 319]; // v6.2.0

        for (uint256 i = 0; i < 5; i++) {
            boostedAPYs[i]      = stakingContract.calculateBoostedAPY(user, baseAPYList[i]);
            reducedLockTimes[i] = stakingContract.calculateReducedLockTime(user, basePeriods[i]);
        }

        // Fee discount: what fraction of the 6% commission is reduced?
        // Pass 600 (6% in bps) and get back discounted fee bps
        uint256 discountedFee = stakingContract.calculateFeeDiscount(user, 600);
        effectiveFeeDiscount  = discountedFee < 600 ? 600 - discountedFee : 0;
    }

    /// @notice Get estimated rewards after X time
    function getEstimatedRewards(address user, uint256 daysFromNow) external view returns (
        uint256 baseEstimate,
        uint256 boostedEstimate,
        uint256 activeSkillsCount
    ) {
        uint256 currentRewards = stakingContract.calculateBoostedRewards(user);
        uint256 boostedWithRarity = stakingContract.calculateBoostedRewardsWithRarityMultiplier(user);
        IStakingIntegration.NFTPower[] memory activeSkills = stakingContract.getActivePowers(user);
        
        // Simple linear extrapolation (note: actual APY calculation would be more complex)
        uint256 dailyReward = daysFromNow > 0 ? currentRewards / 1 : 0;
        baseEstimate = currentRewards + (dailyReward * daysFromNow);
        boostedEstimate = boostedWithRarity + ((boostedWithRarity / 1) * daysFromNow);
        activeSkillsCount = activeSkills.length;
    }

    /// @notice Get complete market statistics
    function getMarketStats() external view returns (MarketStats memory) {
        address[] memory autoUsers = stakingContract.getAutoCompoundUsers();
        
        return MarketStats({
            autoCompoundUsersCount: autoUsers.length,
            timestamp: block.timestamp
        });
    }

    /// @notice Get user comparison metrics
    function getUserMetrics(address user) external view returns (UserMetrics memory) {
        (uint256 totalDeposited, uint256 totalRewards, uint256 depositCount, ) = stakingContract.getUserInfo(user);
        IStakingIntegration.UserPowerProfile memory skillProfile = stakingContract.getUserPowerProfile(user);
        IStakingIntegration.NFTPower[] memory activeSkills = stakingContract.getActivePowers(user);
        
        return UserMetrics({
            totalDeposited: totalDeposited,
            totalRewards: totalRewards,
            deposits: depositCount,
            activeSkills: uint8(activeSkills.length),
            level: skillProfile.level,
            xp: skillProfile.totalXP,
            boosts: skillProfile.stakingBoostTotal
        });
    }

    /// @notice Get skill effectiveness analysis
    function getSkillEffectiveness(address user) external view returns (SkillEffectiveness[] memory) {
        IStakingIntegration.NFTPower[] memory skills = stakingContract.getActivePowers(user);
        SkillEffectiveness[] memory effectiveness = new SkillEffectiveness[](skills.length);
        
        uint256 baseRewards = stakingContract.calculateBoostedRewards(user);
        
        for (uint256 i = 0; i < skills.length; i++) {
            effectiveness[i] = SkillEffectiveness({
                powerType: skills[i].powerType,
                effectValue: skills[i].effectValue,
                rarity: skills[i].rarity,
                isActive: skills[i].isActive,
                impactValue: (baseRewards * skills[i].effectValue) / 10000
            });
        }
        
        return effectiveness;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // DEPOSIT & PORTFOLIO FUNCTIONS - Moved from Core Contract
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Get detailed information about all user deposits with lockup types
    /// @param _user Address of the user
    /// @return portfolio Complete user portfolio with all deposit details
    function getUserPortfolio(address _user) external view returns (UserPortfolio memory portfolio) {
        (uint256 totalDep, uint256 totalRew, uint256 depCount, uint256 lastWith) = stakingContract.getUserInfo(_user);
        
        portfolio.totalDeposited = totalDep;
        portfolio.totalRewards = totalRew;
        portfolio.depositCount = depCount;
        portfolio.lastWithdrawTime = lastWith;
        portfolio.totalPortfolioValue = portfolio.totalDeposited + portfolio.totalRewards;
        portfolio.flexibleBalance = 0;
        portfolio.lockedBalance = 0;
        portfolio.unlockedBalance = 0;
        
        if (depCount == 0) {
            portfolio.deposits = new DepositDetails[](0);
            return portfolio;
        }
        
        portfolio.deposits = new DepositDetails[](depCount);
        
        for (uint256 i = 0; i < depCount; i++) {
            DepositDetails memory dpDetail = _getDepositDetailsInternal(_user, i);
            portfolio.deposits[i] = dpDetail;
            
            // Categorize balance by type
            if (dpDetail.lockupDuration == 0) {
                portfolio.flexibleBalance += dpDetail.amount;
            } else if (!dpDetail.isLocked) {
                portfolio.unlockedBalance += dpDetail.amount;
            } else {
                portfolio.lockedBalance += dpDetail.amount;
            }
        }
        
        return portfolio;
    }
    
    /// @notice Get single deposit details by index
    /// @param _user Address of the user
    /// @param _depositIndex Index of the deposit
    /// @return DepositDetails for the specific deposit
    function getDepositDetails(address _user, uint256 _depositIndex) 
        external 
        view 
        returns (DepositDetails memory) 
    {
        return _getDepositDetailsInternal(_user, _depositIndex);
    }
    
    /// @notice Get contract balance information
    /// @return contractBalance Current contract balance in wei
    /// @return totalPoolBalance_ Total amount deposited in pool
    /// @return availableForRewards Available amount for rewards
    function getContractBalance() external view returns (
        uint256 contractBalance,
        uint256 totalPoolBalance_,
        uint256 availableForRewards
    ) {
        uint256 poolBalance = stakingContract.totalPoolBalance();
        uint256 ethBalance = address(stakingContract).balance;
        return (
            ethBalance,
            poolBalance,
            ethBalance > poolBalance ? ethBalance - poolBalance : 0
        );
    }
    
    /// @notice Get summary of all deposits by lockup type
    /// @param _user Address of the user
    /// @return summaries Array with totals for each lockup type: [flexible, 30d, 90d, 180d, 365d]
    function getDepositSummaryByType(address _user) 
        external 
        view 
        returns (uint256[] memory summaries) 
    {
        (,,uint256 depCount,) = stakingContract.getUserInfo(_user);
        summaries = new uint256[](5); // [flexible, 30d, 90d, 180d, 365d]
        
        for (uint256 i = 0; i < depCount; i++) {
            (uint128 amount, , , uint64 lockupDuration) = stakingContract.getUserDeposit(_user, i);
            
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
    /// @param _user Address of the user
    /// @return hasLocked True if user has any locked deposits
    /// @return lockedAmount Total amount in locked deposits
    function getLockedDepositInfo(address _user) external view returns (bool hasLocked, uint256 lockedAmount) {
        (,,uint256 depCount,) = stakingContract.getUserInfo(_user);
        uint256 totalLocked;
        
        for (uint256 i = 0; i < depCount; i++) {
            (uint128 amount, uint64 timestamp, , uint64 lockupDuration) = stakingContract.getUserDeposit(_user, i);
            uint256 unlockTime = uint256(timestamp) + uint256(lockupDuration);
            
            if (block.timestamp < unlockTime && lockupDuration > 0) {
                totalLocked += uint256(amount);
            }
        }
        
        return (totalLocked > 0, totalLocked);
    }
    
    /// @notice Check which deposits are withdrawable
    /// @param _user Address of the user
    /// @return withdrawableIndices Array of withdrawable deposit indices
    /// @return withdrawableAmount Total amount available for withdrawal
    function getWithdrawableDeposits(address _user) 
        external 
        view 
        returns (uint256[] memory withdrawableIndices, uint256 withdrawableAmount) 
    {
        (,,uint256 depCount,) = stakingContract.getUserInfo(_user);
        uint256[] memory tempIndices = new uint256[](depCount);
        uint256 count;
        uint256 totalAmount;
        
        for (uint256 i = 0; i < depCount; i++) {
            (uint128 amount, uint64 timestamp, , uint64 lockupDuration) = stakingContract.getUserDeposit(_user, i);
            uint256 unlockTime = uint256(timestamp) + uint256(lockupDuration);
            
            if (block.timestamp >= unlockTime || lockupDuration == 0) {
                tempIndices[count++] = i;
                totalAmount += uint256(amount);
            }
        }
        
        withdrawableIndices = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            withdrawableIndices[i] = tempIndices[i];
        }
        
        return (withdrawableIndices, totalAmount);
    }
    
    /// @notice Get time remaining until next deposit is unlocked
    /// @param _user Address of the user
    /// @return secondsUntilUnlock Seconds until next unlock (0 if none locked)
    /// @return nextUnlockTime Timestamp of next unlock
    function getNextUnlockTime(address _user) 
        external 
        view 
        returns (uint256 secondsUntilUnlock, uint256 nextUnlockTime) 
    {
        (,,uint256 depCount,) = stakingContract.getUserInfo(_user);
        nextUnlockTime = type(uint256).max;
        
        for (uint256 i = 0; i < depCount; i++) {
            (, uint64 timestamp, , uint64 lockupDuration) = stakingContract.getUserDeposit(_user, i);
            if (lockupDuration > 0) {
                uint256 unlockTimeVal = uint256(timestamp) + uint256(lockupDuration);
                if (unlockTimeVal < nextUnlockTime && unlockTimeVal > block.timestamp) {
                    nextUnlockTime = unlockTimeVal;
                }
            }
        }
        
        if (nextUnlockTime == type(uint256).max) {
            return (0, 0);
        }
        
        secondsUntilUnlock = nextUnlockTime > block.timestamp ? nextUnlockTime - block.timestamp : 0;
        return (secondsUntilUnlock, nextUnlockTime);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // DASHBOARD STATS FUNCTIONS - Moved from Core Contract
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Get pool statistics for dashboard display
    /// @return totalPoolValue Total value locked in pool (in wei)
    /// @return totalRewards Total pending rewards across all users (in wei)
    /// @return activeUsersCount Number of users with deposits
    /// @return totalDeposits Total number of deposits
    /// @return contractBalanceValue Current contract balance
    function getPoolStats() external view returns (
        uint256 totalPoolValue,
        uint256 totalRewards,
        uint256 activeUsersCount,
        uint256 totalDeposits,
        uint256 contractBalanceValue
    ) {
        totalPoolValue = stakingContract.totalPoolBalance();
        activeUsersCount = stakingContract.uniqueUsersCount();
        contractBalanceValue = stakingContract.getContractBalance();
        
        // totalRewards and totalDeposits would need to iterate through all users
        // This is kept for interface compatibility but frontend should use per-user data
        totalDeposits = 0;
        totalRewards = 0;
    }
    
    /// @notice Get recommended APY rates for different lockup periods
    /// @return flexibleAPY Annual percentage yield for flexible deposits (basis points)
    /// @return locked30APY APY for 30-day lock (basis points)
    /// @return locked90APY APY for 90-day lock (basis points)
    /// @return locked180APY APY for 180-day lock (basis points)
    /// @return locked365APY APY for 365-day lock (basis points)
    function getAPYRates() external pure returns (
        uint256 flexibleAPY,
        uint256 locked30APY,
        uint256 locked90APY,
        uint256 locked180APY,
        uint256 locked365APY
    ) {
        // APY values in basis points (100 = 1%)
        // Based on hourly ROI: 0.003%, 0.005%, 0.009%, 0.012%, 0.018%
        return (
            263,    // 26.3% APY (No Lock)     - 0.003% per hour
            438,    // 43.8% APY (30 Days)     - 0.005% per hour
            788,    // 78.8% APY (90 Days)     - 0.009% per hour
            1051,   // 105.12% APY (180 Days)  - 0.012% per hour
            1577    // 157.68% APY (365 Days)  - 0.018% per hour
        );
    }
    
    /// @notice Get hourly ROI rates for different lockup periods
    /// @dev Returns rates in basis points where 10000 = 100% = 1.0
    /// @return rates Array of hourly ROI rates [flexible, 30d, 90d, 180d, 365d]
    function getHourlyROIRates() external pure returns (uint256[5] memory rates) {
        // Hourly ROI in basis points (30 = 0.003%)
        return [
            uint256(30),    // 0.003% per hour (No Lock)
            uint256(50),    // 0.005% per hour (30 Days)
            uint256(90),    // 0.009% per hour (90 Days)
            uint256(120),   // 0.012% per hour (180 Days)
            uint256(180)    // 0.018% per hour (365 Days)
        ];
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // NEW VIEW FUNCTIONS FOR FRONTEND
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Get global staking statistics for dashboard
    /// @return stats Global platform statistics
    function getGlobalStats() external view returns (GlobalStakingStats memory stats) {
        stats.totalValueLocked = stakingContract.totalPoolBalance();
        stats.totalUniqueUsers = stakingContract.uniqueUsersCount();
        stats.contractBalance = stakingContract.getContractBalance();
        stats.availableRewards = stats.contractBalance > stats.totalValueLocked 
            ? stats.contractBalance - stats.totalValueLocked 
            : 0;
        (stats.healthStatus, ) = this.getPoolHealth();
        stats.timestamp = block.timestamp;
    }
    
    /// @notice Get user's projected rewards over different time periods
    /// @param _user User address
    /// @return projection Rewards projection breakdown
    function getUserRewardsProjection(address _user) external view returns (UserRewardsProjection memory projection) {
        (uint256 dailyEst, uint256 monthlyEst, uint256 annualEst) = this.getEarningsBreakdown(_user);
        
        projection.currentPendingRewards = stakingContract.calculateRewards(_user);
        projection.dailyRewards = dailyEst;
        projection.hourlyRewards = dailyEst / 24;
        projection.weeklyRewards = dailyEst * 7;
        projection.monthlyRewards = monthlyEst;
        projection.yearlyRewards = annualEst;
    }
    
    /// @notice Calculate potential earnings for a hypothetical deposit
    /// @param amount Amount to deposit in wei
    /// @param lockupPeriodIndex Lockup period (0=flexible, 1=30d, 2=90d, 3=180d, 4=365d)
    /// @param daysToProject Number of days to project earnings
    /// @return projectedEarnings Estimated earnings in wei
    /// @return effectiveAPY The APY applied (in basis points)
    function calculatePotentialEarnings(
        uint256 amount,
        uint8 lockupPeriodIndex,
        uint256 daysToProject
    ) external pure returns (uint256 projectedEarnings, uint256 effectiveAPY) {
        if (lockupPeriodIndex >= 5) revert();
        
        uint256[5] memory apyRates = [uint256(263), 438, 788, 1051, 1577];
        effectiveAPY = apyRates[lockupPeriodIndex];
        
        // Calculate: amount * APY * days / (365 * 10000)
        projectedEarnings = (amount * effectiveAPY * daysToProject) / (365 * 10000);
    }
    
    /// @notice Get user's staking efficiency metrics
    /// @param _user User address
    /// @return efficiency Percentage of optimal staking (0-100)
    /// @return suggestionCount Number of improvement suggestions available
    function getStakingEfficiency(address _user) external view returns (
        uint256 efficiency,
        uint8 suggestionCount
    ) {
        (uint256 totalDep, , uint256 depCount, ) = stakingContract.getUserInfo(_user);
        
        if (totalDep == 0) {
            return (0, 3);
        }
        
        uint256[] memory summaries = this.getDepositSummaryByType(_user);
        
        // Calculate efficiency based on lockup distribution
        // Higher lockups = higher efficiency
        uint256 weightedScore = 
            (summaries[0] * 1) +   // Flexible = 1x weight
            (summaries[1] * 2) +   // 30d = 2x weight
            (summaries[2] * 3) +   // 90d = 3x weight
            (summaries[3] * 4) +   // 180d = 4x weight
            (summaries[4] * 5);    // 365d = 5x weight
        
        // Max possible score is totalDep * 5 (if all in 365d)
        efficiency = (weightedScore * 100) / (totalDep * 5);
        
        uint8 suggestionCount_ = 0;
        if (summaries[0] > totalDep / 2) suggestionCount_++;
        if (summaries[4] == 0) suggestionCount_++;
        if (depCount > 10) suggestionCount_++;
        suggestionCount = suggestionCount_;
    }
    
    /// @notice Check if user can withdraw and get details
    /// @param _user User address
    /// @return canWithdraw True if user has withdrawable rewards
    /// @return withdrawableRewards Amount of withdrawable rewards
    /// @return lockedUntil Timestamp when locked funds become available (0 if none locked)
    /// @return dailyLimitRemaining Remaining daily withdrawal limit
    function getWithdrawalStatus(address _user) external view returns (
        bool canWithdraw,
        uint256 withdrawableRewards,
        uint256 lockedUntil,
        uint256 dailyLimitRemaining
    ) {
        withdrawableRewards = stakingContract.calculateRewards(_user);
        canWithdraw = withdrawableRewards > 0;
        
        // Check for locked deposits
        (,,uint256 depCount,) = stakingContract.getUserInfo(_user);
        uint256 earliestUnlock = type(uint256).max;
        
        for (uint256 i = 0; i < depCount; i++) {
            (, uint64 timestamp, , uint64 lockupDuration) = stakingContract.getUserDeposit(_user, i);
            if (lockupDuration > 0) {
                uint256 unlockTime = uint256(timestamp) + uint256(lockupDuration);
                if (unlockTime > block.timestamp && unlockTime < earliestUnlock) {
                    earliestUnlock = unlockTime;
                    canWithdraw = false; // Has locked deposits
                }
            }
        }
        
        lockedUntil = earliestUnlock == type(uint256).max ? 0 : earliestUnlock;
        dailyLimitRemaining = 1000 ether; // DAILY_WITHDRAWAL_LIMIT - would need to track actual usage
    }
    
    /// @notice Get time-based reward breakdown for a specific deposit
    /// @param _user User address
    /// @param _depositIndex Index of the deposit
    /// @return hourlyRate Rewards per hour
    /// @return dailyRate Rewards per day
    /// @return monthlyRate Rewards per month
    /// @return totalAccrued Total rewards accrued so far
    function getDepositRewardRates(address _user, uint256 _depositIndex) external view returns (
        uint256 hourlyRate,
        uint256 dailyRate,
        uint256 monthlyRate,
        uint256 totalAccrued
    ) {
        (uint128 amount, , uint64 lastClaimTime, uint64 lockupDuration) = stakingContract.getUserDeposit(_user, _depositIndex);
        
        uint8 lockupIndex;
        if (lockupDuration == 0) lockupIndex = 0;
        else if (lockupDuration == 30 days) lockupIndex = 1;
        else if (lockupDuration == 90 days) lockupIndex = 2;
        else if (lockupDuration == 180 days) lockupIndex = 3;
        else if (lockupDuration == 365 days) lockupIndex = 4;
        
        uint256[5] memory apyRates = [uint256(263), 438, 788, 1051, 1577];
        uint256 apy = apyRates[lockupIndex];
        
        // Calculate rates
        // Annual: amount * APY / 10000
        // Monthly: annual / 12
        // Daily: annual / 365
        // Hourly: daily / 24
        uint256 annualRate = (uint256(amount) * apy) / 10000;
        dailyRate = annualRate / 365;
        hourlyRate = dailyRate / 24;
        monthlyRate = annualRate / 12;
        
        // Calculate total accrued
        uint256 timeElapsed = block.timestamp - uint256(lastClaimTime);
        totalAccrued = (uint256(amount) * apy * timeElapsed) / (365 days * 10000);
    }
    
    /// @notice Get pool health status based on various metrics
    /// @return healthStatus 0=Critical, 1=Low, 2=Moderate, 3=Healthy, 4=Excellent
    /// @return reserveRatio Ratio of available balance to total deposits (basis points)
    function getPoolHealth() external view returns (
        uint8 healthStatus,
        uint256 reserveRatio
    ) {
        uint256 poolBalance = stakingContract.totalPoolBalance();
        if (poolBalance == 0) {
            return (3, 10000);
        }
        
        uint256 currentBalance = stakingContract.getContractBalance();
        reserveRatio = (currentBalance * 10000) / poolBalance;
        
        if (reserveRatio >= 15000) healthStatus = 4;
        else if (reserveRatio >= 10000) healthStatus = 3;
        else if (reserveRatio >= 5000) healthStatus = 2;
        else if (reserveRatio >= 2000) healthStatus = 1;
        else healthStatus = 0;
    }
    
    /// @notice Get dashboard summary for a single user
    /// @param _user User address
    /// @return userStaked Total amount staked by user
    /// @return userPendingRewards Pending rewards for user
    /// @return userDepositCount Number of deposits
    /// @return userFlexibleBalance Balance in flexible deposits
    /// @return userLockedBalance Balance in currently locked deposits
    /// @return userUnlockedBalance Balance in unlocked deposits
    function getDashboardUserSummary(address _user) external view returns (
        uint256 userStaked,
        uint256 userPendingRewards,
        uint256 userDepositCount,
        uint256 userFlexibleBalance,
        uint256 userLockedBalance,
        uint256 userUnlockedBalance
    ) {
        (uint256 tDep, uint256 tRew, uint256 dCount, ) = stakingContract.getUserInfo(_user);
        userDepositCount = dCount;
        userStaked = tDep;
        userPendingRewards = tRew;
        
        // Get balance breakdown by type
        for (uint256 i = 0; i < dCount; i++) {
            (uint128 amount, uint64 timestamp, , uint64 lockupDuration) = stakingContract.getUserDeposit(_user, i);
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
    
    /// @notice Get complete dashboard data in one call
    /// @param _user User address
    /// @return poolTotalValue Total value in pool
    /// @return poolActiveUsers Number of active users
    /// @return poolContractBalance Current contract balance
    /// @return poolHealthStatus Health status (0-4)
    /// @return userStaked User's total stake
    /// @return userRewards User's pending rewards
    /// @return userDeposits User's deposit count
    /// @return userFlexible User's flexible balance
    /// @return userLocked User's locked balance
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
        poolTotalValue = stakingContract.totalPoolBalance();
        poolActiveUsers = stakingContract.uniqueUsersCount();
        poolContractBalance = stakingContract.getContractBalance();
        
        (poolHealthStatus, ) = this.getPoolHealth();
        
        (uint256 tDep, uint256 tRew, uint256 dCount, ) = stakingContract.getUserInfo(_user);
        userStaked = tDep;
        userRewards = tRew;
        userDeposits = dCount;
        
        // Calculate balance breakdown
        for (uint256 i = 0; i < dCount; i++) {
            (uint128 amount, uint64 timestamp, , uint64 lockupDuration) = stakingContract.getUserDeposit(_user, i);
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
    
    /// @notice Estimate earnings breakdown for a user
    /// @param _user User address
    /// @return dailyEarnings Estimated daily earnings (in wei)
    /// @return monthlyEarnings Estimated monthly earnings (in wei)
    /// @return annualEarnings Estimated annual earnings (in wei)
    function getEarningsBreakdown(address _user) external view returns (
        uint256 dailyEarnings,
        uint256 monthlyEarnings,
        uint256 annualEarnings
    ) {
        (,,uint256 depCount,) = stakingContract.getUserInfo(_user);
        if (depCount == 0) {
            return (0, 0, 0);
        }
        
        // Calculate total potential earnings based on current rewards rate
        uint256 totalRewards = stakingContract.calculateRewards(_user);
        
        // Get average time for deposits
        uint256 totalTimeLapsed;
        uint256 activeDepositCount;
        
        for (uint256 i = 0; i < depCount; i++) {
            (,uint64 timestamp,,) = stakingContract.getUserDeposit(_user, i);
            if (uint256(timestamp) < block.timestamp) {
                totalTimeLapsed += (block.timestamp - uint256(timestamp));
                activeDepositCount++;
            }
        }
        
        if (activeDepositCount == 0 || totalTimeLapsed == 0) {
            return (0, 0, 0);
        }
        
        // Average time per deposit
        uint256 avgTimeLapsed = totalTimeLapsed / activeDepositCount;
        
        // Avoid division by zero
        if (avgTimeLapsed == 0) {
            avgTimeLapsed = 1 days;
        }
        
        // Estimate daily earnings
        dailyEarnings = (totalRewards * 1 days) / avgTimeLapsed;
        
        // Estimate monthly and annual
        monthlyEarnings = (dailyEarnings * 30);
        annualEarnings = (dailyEarnings * 365);
        
        return (dailyEarnings, monthlyEarnings, annualEarnings);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPERS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @dev Helper to get deposit details with all calculations
    function _getDepositDetailsInternal(address _user, uint256 _index) internal view returns (DepositDetails memory) {
        (uint128 amount, uint64 timestamp, uint64 lastClaimTime, uint64 lockupDuration) = stakingContract.getUserDeposit(_user, _index);
        
        uint256 unlockTime = uint256(timestamp) + uint256(lockupDuration);
        bool isLocked = block.timestamp < unlockTime && lockupDuration > 0;
        
        uint8 lockupTypeId;
        if (lockupDuration == 0) lockupTypeId = 0;
        else if (lockupDuration == 30 days) lockupTypeId = 1;
        else if (lockupDuration == 90 days) lockupTypeId = 2;
        else if (lockupDuration == 180 days) lockupTypeId = 3;
        else if (lockupDuration == 365 days) lockupTypeId = 4;
        
        return DepositDetails({
            depositIndex: _index,
            amount: uint256(amount),
            currentRewards: 0,
            timestamp: uint256(timestamp),
            lastClaimTime: uint256(lastClaimTime),
            lockupDuration: uint256(lockupDuration),
            unlockTime: unlockTime,
            lockupTypeId: lockupTypeId,
            isLocked: isLocked,
            isWithdrawable: !isLocked
        });
    }
    
    /// @dev Helper function to build DepositDetails array from indices
    function _buildDepositDetailsArray(
        address _user,
        uint256[] memory indices,
        uint256 count
    ) internal view returns (DepositDetails[] memory) {
        DepositDetails[] memory details = new DepositDetails[](count);
        
        for (uint256 i = 0; i < count; i++) {
            details[i] = _getDepositDetailsInternal(_user, indices[i]);
        }
        
        return details;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPERS - ORIGINAL
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function _rarityToStars(IStakingIntegration.Rarity rarity) internal pure returns (uint8) {
        if (rarity == IStakingIntegration.Rarity.COMMON) return 3;
        if (rarity == IStakingIntegration.Rarity.UNCOMMON) return 5;
        if (rarity == IStakingIntegration.Rarity.RARE) return 7;
        if (rarity == IStakingIntegration.Rarity.EPIC) return 9;
        if (rarity == IStakingIntegration.Rarity.LEGENDARY) return 10;
        return 0;
    }
    
    function _getRarityBoost(IStakingIntegration.Rarity rarity) internal pure returns (uint256) {
        if (rarity == IStakingIntegration.Rarity.COMMON) return 0;
        if (rarity == IStakingIntegration.Rarity.UNCOMMON) return 1000;
        if (rarity == IStakingIntegration.Rarity.RARE) return 2000;
        if (rarity == IStakingIntegration.Rarity.EPIC) return 4000;
        if (rarity == IStakingIntegration.Rarity.LEGENDARY) return 8000;
        return 0;
    }
    
    function _createSkillConfig(
        IStakingIntegration.PowerType powerType,
        bytes32 descriptionHash
    ) internal view returns (SkillConfig memory) {
        return SkillConfig({
            powerType: powerType,
            enabled: stakingContract.powerEnabled(powerType),
            effectValue: stakingContract.powerDefaultEffects(powerType),
            descriptionHash: descriptionHash
        });
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    struct UserDepositInfo {
        uint256 totalDeposited;
        uint256 totalRewards;
        uint256 depositCount;
        uint256 lastWithdrawTime;
    }
    
    struct UserInfoWithSkills {
        uint256 totalDeposited;
        uint256 totalRewards;
        uint256 depositCount;
        uint256 lastWithdrawTime;
        IStakingIntegration.UserPowerProfile skillProfile;
        IStakingIntegration.NFTPower[] activeSkills;
    }
    
    struct SkillDetails {
        IStakingIntegration.PowerType powerType;
        uint16 effectValue;
        IStakingIntegration.Rarity rarity;
        uint64 activatedAt;
        uint64 cooldownEnds;
        bool isActive;
        uint256 rarityBoost;
    }
    
    struct SkillConfig {
        IStakingIntegration.PowerType powerType;
        bool enabled;
        uint16 effectValue;
        bytes32 descriptionHash; // keccak256 of description string — use off-chain lookup
    }
    
    struct UserStats {
        uint256 totalDeposited;
        uint256 totalRewards;
        uint256 boostedRewards;
        uint256 boostedRewardsWithRarity;
        uint256 depositCount;
        uint256 lastWithdrawTime;
        uint16 userLevel;
        uint256 userXP;
        uint8 maxActiveSkills;
        uint8 activeSkillsCount;
        uint16 stakingBoostTotal;
        uint16 feeDiscountTotal;
        bool hasAutoCompound;
    }
    
    struct PortfolioSummary {
        uint256 totalDeposited;
        uint256 pendingRewards;
        uint256 totalValue;
        uint256 depositCount;
        uint256 rewardEfficiency;
    }
    
    struct QuestRewardData {
        uint256 questId;
        uint256 amount;
        uint256 expirationTime;
        bool claimed;
    }
    
    struct AchievementRewardData {
        uint256 achievementId;
        uint256 amount;
        uint256 expirationTime;
        bool claimed;
    }
    
    struct MarketStats {
        uint256 autoCompoundUsersCount;
        uint256 timestamp;
    }
    
    struct UserMetrics {
        uint256 totalDeposited;
        uint256 totalRewards;
        uint256 deposits;
        uint8 activeSkills;
        uint16 level;
        uint256 xp;
        uint16 boosts;
    }
    
    struct SkillEffectiveness {
        IStakingIntegration.PowerType powerType;
        uint16 effectValue;
        IStakingIntegration.Rarity rarity;
        bool isActive;
        uint256 impactValue;
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
    
}

