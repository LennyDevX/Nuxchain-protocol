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
    
    // Skills and Gamification
    function getUserSkillProfile(address user) external view returns (IStakingIntegration.UserSkillProfile memory);
    function getActiveSkills(address user) external view returns (IStakingIntegration.NFTSkill[] memory);
    function calculateBoostedRewards(address user) external view returns (uint256);
    function calculateBoostedRewardsWithRarityMultiplier(address user) external view returns (uint256);
    function nftRarity(uint256 nftId) external view returns (IStakingIntegration.Rarity);
    function skillEnabled(IStakingIntegration.SkillType skillType) external view returns (bool);
    function skillDefaultEffects(IStakingIntegration.SkillType skillType) external view returns (uint16);
    function getAutoCompoundUsers() external view returns (address[] memory);
}

/// @title EnhancedSmartStakingView
/// @notice View functions module for querying staking contract data
/// @dev Separate contract to keep main staking contract under size limit
/// @custom:security-contact security@nuvo.com
/// @custom:version 1.0.0
contract EnhancedSmartStakingView {
    
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
        string lockupType; // "Flexible", "30 Days", "90 Days", "180 Days", "365 Days"
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
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor(address _stakingContract) {
        require(_stakingContract != address(0), "Invalid staking contract");
        stakingContract = IStakingViewData(_stakingContract);
        owner = msg.sender;
    }
    
    /// @notice Update staking contract reference
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid staking contract");
        stakingContract = IStakingViewData(_stakingContract);
        emit StakingContractUpdated(_stakingContract);
    }
    
    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
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
        IStakingIntegration.UserSkillProfile memory skillProfile = stakingContract.getUserSkillProfile(user);
        IStakingIntegration.NFTSkill[] memory activeSkills = stakingContract.getActiveSkills(user);
        
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
        IStakingIntegration.NFTSkill[] memory skills = stakingContract.getActiveSkills(user);
        SkillDetails[] memory details = new SkillDetails[](skills.length);
        
        for (uint256 i = 0; i < skills.length; i++) {
            details[i] = SkillDetails({
                skillType: skills[i].skillType,
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
        
        configs[0] = _createSkillConfig(
            IStakingIntegration.SkillType.STAKE_BOOST_I,
            "+5% APY"
        );
        configs[1] = _createSkillConfig(
            IStakingIntegration.SkillType.STAKE_BOOST_II,
            "+10% APY"
        );
        configs[2] = _createSkillConfig(
            IStakingIntegration.SkillType.STAKE_BOOST_III,
            "+20% APY"
        );
        configs[3] = _createSkillConfig(
            IStakingIntegration.SkillType.AUTO_COMPOUND,
            "Automatic compounding"
        );
        configs[4] = _createSkillConfig(
            IStakingIntegration.SkillType.LOCK_REDUCER,
            "-25% lock time"
        );
        configs[5] = _createSkillConfig(
            IStakingIntegration.SkillType.FEE_REDUCER_I,
            "-10% platform fees"
        );
        configs[6] = _createSkillConfig(
            IStakingIntegration.SkillType.FEE_REDUCER_II,
            "-25% platform fees"
        );
        
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
        IStakingIntegration.UserSkillProfile memory skillProfile = stakingContract.getUserSkillProfile(user);
        IStakingIntegration.NFTSkill[] memory activeSkills = stakingContract.getActiveSkills(user);
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
        require(page < totalPages || totalUsers == 0, "Page out of range");
        
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

    /// @notice Get estimated rewards after X time
    function getEstimatedRewards(address user, uint256 daysFromNow) external view returns (
        uint256 baseEstimate,
        uint256 boostedEstimate,
        uint256 activeSkillsCount
    ) {
        uint256 currentRewards = stakingContract.calculateBoostedRewards(user);
        uint256 boostedWithRarity = stakingContract.calculateBoostedRewardsWithRarityMultiplier(user);
        IStakingIntegration.NFTSkill[] memory activeSkills = stakingContract.getActiveSkills(user);
        
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
        IStakingIntegration.UserSkillProfile memory skillProfile = stakingContract.getUserSkillProfile(user);
        IStakingIntegration.NFTSkill[] memory activeSkills = stakingContract.getActiveSkills(user);
        
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
        IStakingIntegration.NFTSkill[] memory skills = stakingContract.getActiveSkills(user);
        SkillEffectiveness[] memory effectiveness = new SkillEffectiveness[](skills.length);
        
        uint256 baseRewards = stakingContract.calculateBoostedRewards(user);
        
        for (uint256 i = 0; i < skills.length; i++) {
            effectiveness[i] = SkillEffectiveness({
                skillType: skills[i].skillType,
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
    
    /// @notice Get deposits by lockup type classification
    /// @param _user Address of the user
    /// @return flexible Array of flexible deposits
    /// @return locked30 Array of locked 30-day deposits
    /// @return locked90 Array of locked 90-day deposits
    /// @return locked180 Array of locked 180-day deposits
    /// @return locked365 Array of locked 365-day deposits
    function getUserDepositsByType(address _user) 
        external 
        view 
        returns (
            DepositDetails[] memory flexible,
            DepositDetails[] memory locked30,
            DepositDetails[] memory locked90,
            DepositDetails[] memory locked180,
            DepositDetails[] memory locked365
        ) 
    {
        (,,uint256 depCount,) = stakingContract.getUserInfo(_user);
        
        uint256[] memory flexibleIndices = new uint256[](depCount);
        uint256[] memory locked30Indices = new uint256[](depCount);
        uint256[] memory locked90Indices = new uint256[](depCount);
        uint256[] memory locked180Indices = new uint256[](depCount);
        uint256[] memory locked365Indices = new uint256[](depCount);
        
        uint256 flexibleCount;
        uint256 locked30Count;
        uint256 locked90Count;
        uint256 locked180Count;
        uint256 locked365Count;
        
        for (uint256 i = 0; i < depCount; i++) {
            (, , , uint64 lockupDuration) = stakingContract.getUserDeposit(_user, i);
            
            if (lockupDuration == 0) {
                flexibleIndices[flexibleCount++] = i;
            } else if (lockupDuration == 30 days) {
                locked30Indices[locked30Count++] = i;
            } else if (lockupDuration == 90 days) {
                locked90Indices[locked90Count++] = i;
            } else if (lockupDuration == 180 days) {
                locked180Indices[locked180Count++] = i;
            } else if (lockupDuration == 365 days) {
                locked365Indices[locked365Count++] = i;
            }
        }
        
        flexible = _buildDepositDetailsArray(_user, flexibleIndices, flexibleCount);
        locked30 = _buildDepositDetailsArray(_user, locked30Indices, locked30Count);
        locked90 = _buildDepositDetailsArray(_user, locked90Indices, locked90Count);
        locked180 = _buildDepositDetailsArray(_user, locked180Indices, locked180Count);
        locked365 = _buildDepositDetailsArray(_user, locked365Indices, locked365Count);
        
        return (flexible, locked30, locked90, locked180, locked365);
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
        contractBalanceValue = address(stakingContract).balance;
        
        // totalRewards and totalDeposits would need to iterate through all users
        // This is kept for interface compatibility but frontend should use per-user data
        totalDeposits = 0;
        totalRewards = 0;
    }
    
    /// @notice Get stake distribution statistics
    /// @return flexibleTotal Total amount in flexible stakes
    /// @return locked30Total Total amount in 30-day locked stakes
    /// @return locked90Total Total amount in 90-day locked stakes
    /// @return locked180Total Total amount in 180-day locked stakes
    /// @return locked365Total Total amount in 365-day locked stakes
    /// @return totalLockedValue Total in all locked deposits
    /// @return totalFlexibleValue Total in all flexible deposits
    function getStakeDistribution() external pure returns (
        uint256 flexibleTotal,
        uint256 locked30Total,
        uint256 locked90Total,
        uint256 locked180Total,
        uint256 locked365Total,
        uint256 totalLockedValue,
        uint256 totalFlexibleValue
    ) {
        // These would require iterating all users - returning structure for reference
        // Frontend should aggregate from individual user calls to getDepositSummaryByType
        return (0, 0, 0, 0, 0, 0, 0);
    }
    
    /// @notice Get recommended APY rates for different lockup periods
    /// @return flexibleAPY Annual percentage yield for flexible deposits
    /// @return locked30APY APY for 30-day lock
    /// @return locked90APY APY for 90-day lock
    /// @return locked180APY APY for 180-day lock
    /// @return locked365APY APY for 365-day lock
    function getAPYRates() external pure returns (
        uint256 flexibleAPY,
        uint256 locked30APY,
        uint256 locked90APY,
        uint256 locked180APY,
        uint256 locked365APY
    ) {
        // Return base APY values (can be customized based on reward module implementation)
        // Typical values in basis points (100 = 1%)
        return (
            0,      // Flexible - 0% base APY
            365,    // 30-day - ~3.65% APY
            912,    // 90-day - ~9.12% APY
            1825,   // 180-day - ~18.25% APY
            3650    // 365-day - ~36.50% APY
        );
    }
    
    /// @notice Get pool health status based on various metrics
    /// @return healthStatus 0=Critical, 1=Low, 2=Moderate, 3=Healthy, 4=Excellent
    /// @return statusMessage Human readable status
    /// @return reserveRatio Ratio of available balance to total deposits
    /// @return description Detailed description of pool health
    function getPoolHealth() external view returns (
        uint8 healthStatus,
        string memory statusMessage,
        uint256 reserveRatio,
        string memory description
    ) {
        uint256 poolBalance = stakingContract.totalPoolBalance();
        if (poolBalance == 0) {
            return (3, "Empty", 10000, "No deposits in pool");
        }
        
        uint256 currentBalance = address(stakingContract).balance;
        
        // Calculate reserve ratio (in basis points: 10000 = 100%)
        reserveRatio = (currentBalance * 10000) / poolBalance;
        
        // Determine health status based on reserve ratio
        if (reserveRatio >= 15000) {
            // More than 150% reserved
            healthStatus = 4;
            statusMessage = "Excellent";
            description = "Pool has abundant reserves for all rewards";
        } else if (reserveRatio >= 10000) {
            // 100% to 150%
            healthStatus = 3;
            statusMessage = "Healthy";
            description = "Pool has sufficient reserves";
        } else if (reserveRatio >= 5000) {
            // 50% to 100%
            healthStatus = 2;
            statusMessage = "Moderate";
            description = "Pool reserves are adequate but watch liquidity";
        } else if (reserveRatio >= 2000) {
            // 20% to 50%
            healthStatus = 1;
            statusMessage = "Low Funds";
            description = "Pool reserves are low, may struggle with rewards";
        } else {
            // Less than 20%
            healthStatus = 0;
            statusMessage = "Critical";
            description = "Pool reserves critically low, rewards at risk";
        }
        
        return (healthStatus, statusMessage, reserveRatio, description);
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
        poolContractBalance = address(stakingContract).balance;
        
        (poolHealthStatus, , , ) = this.getPoolHealth();
        
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
        
        // For now, getting basic details - reward calculation would need module access
        return DepositDetails({
            depositIndex: _index,
            amount: uint256(amount),
            currentRewards: 0, // Would need rewardsModule access from core
            timestamp: uint256(timestamp),
            lastClaimTime: uint256(lastClaimTime),
            lockupDuration: uint256(lockupDuration),
            unlockTime: unlockTime,
            lockupType: lockupType,
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
        IStakingIntegration.SkillType skillType,
        string memory description
    ) internal view returns (SkillConfig memory) {
        return SkillConfig({
            skillType: skillType,
            enabled: stakingContract.skillEnabled(skillType),
            effectValue: stakingContract.skillDefaultEffects(skillType),
            description: description
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
        IStakingIntegration.UserSkillProfile skillProfile;
        IStakingIntegration.NFTSkill[] activeSkills;
    }
    
    struct SkillDetails {
        IStakingIntegration.SkillType skillType;
        uint16 effectValue;
        IStakingIntegration.Rarity rarity;
        uint64 activatedAt;
        uint64 cooldownEnds;
        bool isActive;
        uint256 rarityBoost;
    }
    
    struct SkillConfig {
        IStakingIntegration.SkillType skillType;
        bool enabled;
        uint16 effectValue;
        string description;
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
        IStakingIntegration.SkillType skillType;
        uint16 effectValue;
        IStakingIntegration.Rarity rarity;
        bool isActive;
        uint256 impactValue;
    }
}

