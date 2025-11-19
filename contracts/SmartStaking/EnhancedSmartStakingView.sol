// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "../interfaces/IStakingIntegration.sol";

/// @title IStakingViewData
/// @notice Interface for view data access from staking contract
interface IStakingViewData {
    function getUserInfo(address user) external view returns (uint256, uint256, uint256, uint256);
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
    // INTERNAL HELPERS
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

