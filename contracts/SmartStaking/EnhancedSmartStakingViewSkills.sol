// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IStakingIntegration.sol";

/// @title EnhancedSmartStakingViewSkills
/// @notice Skills and gamification view functions for staking
/// @dev Part 3 of 3-part View contract split (Core, Stats, Skills)
contract EnhancedSmartStakingViewSkills {
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS - SKILLS & GAMIFICATION
    // ════════════════════════════════════════════════════════════════════════════════════════
    
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
        uint16 stakingBoostTotal;
        uint16 feeDiscountTotal;
        bool hasAutoCompound;
    }
    
    struct SkillEffectiveness {
        IStakingIntegration.SkillType skillType;
        uint16 effectValue;
        IStakingIntegration.Rarity rarity;
        bool isActive;
        uint256 impactValue;
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
    // SKILLS & GAMIFICATION QUERIES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Get user info combined with active skills
    function getUserInfoWithSkills(address user) external view returns (UserInfoWithSkills memory) {
        (uint256 tDep, uint256 tRew, uint256 dCount, uint256 lastWith) = _getUserInfo(user);
        
        UserInfoWithSkills memory result;
        result.totalDeposited = tDep;
        result.totalRewards = tRew;
        result.depositCount = dCount;
        result.lastWithdrawTime = lastWith;
        
        // Get skill profile
        (bool successProfile, bytes memory dataProfile) = stakingContract.staticcall(
            abi.encodeWithSignature("getUserSkillProfile(address)", user)
        );
        require(successProfile, "View: getUserSkillProfile call failed");
        result.skillProfile = abi.decode(dataProfile, (IStakingIntegration.UserSkillProfile));
        
        // Get active skills
        (bool successSkills, bytes memory dataSkills) = stakingContract.staticcall(
            abi.encodeWithSignature("getActiveSkillCount(address)", user)
        );
        require(successSkills, "View: getActiveSkillCount call failed");
        if (successSkills) {
            result.activeSkills = abi.decode(dataSkills, (IStakingIntegration.NFTSkill[]));
        }
        
        return result;
    }
    
    /// @notice Get active skills with detailed information
    function getActiveSkillsWithDetails(address user) external view returns (SkillDetails[] memory) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("getActiveSkills(address)", user)
        );
        
        if (!success) {
            return new SkillDetails[](0);
        }
        
        IStakingIntegration.NFTSkill[] memory activeSkills = abi.decode(data, (IStakingIntegration.NFTSkill[]));
        SkillDetails[] memory details = new SkillDetails[](activeSkills.length);
        
        for (uint256 i = 0; i < activeSkills.length; i++) {
            details[i].skillType = activeSkills[i].skillType;
            details[i].effectValue = activeSkills[i].effectValue;
            details[i].rarity = activeSkills[i].rarity;
            details[i].activatedAt = activeSkills[i].activatedAt;
            details[i].cooldownEnds = activeSkills[i].cooldownEnds;
            details[i].isActive = activeSkills[i].isActive;
            details[i].rarityBoost = _getRarityBoost(activeSkills[i].rarity);
        }
        
        return details;
    }
    
    /// @notice Get available skill configuration
    function getAvailableSkillsConfiguration() external view returns (SkillConfig[] memory) {
        SkillConfig[] memory configs = new SkillConfig[](5);
        
        for (uint8 i = 0; i < 5; i++) {
            IStakingIntegration.SkillType skillType = IStakingIntegration.SkillType(i);
            (bool enabled, uint16 effect) = _getSkillConfig(skillType);
            
            string memory description;
            if (i == 0) description = "Staking Booster - Increases reward rate";
            else if (i == 1) description = "Fee Discount - Reduces commission fees";
            else if (i == 2) description = "Early Unlock - Reduces lockup period";
            else if (i == 3) description = "XP Multiplier - Increases experience gains";
            else if (i == 4) description = "Referral Bonus - Boosts referral rewards";
            
            configs[i] = SkillConfig({
                skillType: skillType,
                enabled: enabled,
                effectValue: effect,
                description: description
            });
        }
        
        return configs;
    }
    
    /// @notice Get rarity information for an NFT skill
    function getSkillRarity(uint256 nftId) external view returns (
        IStakingIntegration.Rarity rarity,
        uint16 rarityId,
        uint8 stars
    ) {
        rarity = _getNFTRarity(nftId);
        rarityId = uint16(rarity);
        stars = _rarityToStars(rarity);
        return (rarity, rarityId, stars);
    }
    
    /// @notice Get detailed user statistics
    function getUserDetailedStats(address user) external view returns (UserStats memory) {
        (uint256 tDep, uint256 tRew, uint256 dCount, uint256 lastWith) = _getUserInfo(user);
        
        UserStats memory stats;
        stats.totalDeposited = tDep;
        stats.totalRewards = tRew;
        stats.depositCount = dCount;
        stats.lastWithdrawTime = lastWith;
        
        // Get rewards (boosted by skills via CoreV2.calculateRewards which applies referral + skill boosts)
        (bool successBoosted, bytes memory dataBoosted) = stakingContract.staticcall(
            abi.encodeWithSignature("calculateRewards(address)", user)
        );
        if (successBoosted) {
            stats.boostedRewards = abi.decode(dataBoosted, (uint256));
        }
        stats.boostedRewardsWithRarity = stats.boostedRewards; // same source — rarity multiplier removed in v6.2
        
        // Get skill profile
        (bool successProfile, bytes memory dataProfile) = stakingContract.staticcall(
            abi.encodeWithSignature("getUserSkillProfile(address)", user)
        );
        require(successProfile, "View: getUserSkillProfile call failed");
        IStakingIntegration.UserSkillProfile memory profile = abi.decode(
            dataProfile, 
            (IStakingIntegration.UserSkillProfile)
        );
        stats.userLevel = profile.level;
        stats.userXP = profile.totalXP;
        stats.maxActiveSkills = profile.maxActiveSkills;
        stats.stakingBoostTotal = profile.stakingBoostTotal;
        stats.feeDiscountTotal = profile.feeDiscountTotal;
        stats.hasAutoCompound = profile.hasAutoCompound;
        
        return stats;
    }
    
    /// @notice Get skill effectiveness analysis
    function getSkillEffectiveness(address user) external view returns (SkillEffectiveness[] memory) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("getActiveSkills(address)", user)
        );
        
        require(success, "View: getActiveSkills call failed");        
        IStakingIntegration.NFTSkill[] memory activeSkills = abi.decode(data, (IStakingIntegration.NFTSkill[]));
        SkillEffectiveness[] memory effectiveness = new SkillEffectiveness[](activeSkills.length);
        
        for (uint256 i = 0; i < activeSkills.length; i++) {
            uint256 impact = uint256(activeSkills[i].effectValue) * _getRarityBoost(activeSkills[i].rarity) / 100;
            
            effectiveness[i] = SkillEffectiveness({
                skillType: activeSkills[i].skillType,
                effectValue: activeSkills[i].effectValue,
                rarity: activeSkills[i].rarity,
                isActive: activeSkills[i].isActive,
                impactValue: impact
            });
        }
        
        return effectiveness;
    }
    
    /// @notice Get user comparison metrics
    function getUserMetrics(address user) external view returns (UserMetrics memory) {
        (uint256 tDep, uint256 tRew, uint256 dCount, ) = _getUserInfo(user);
        
        UserMetrics memory metrics;
        metrics.totalDeposited = tDep;
        metrics.totalRewards = tRew;
        metrics.deposits = dCount;
        
        (bool successProfile, bytes memory dataProfile) = stakingContract.staticcall(
            abi.encodeWithSignature("getUserSkillProfile(address)", user)
        );
        if (successProfile) {
            IStakingIntegration.UserSkillProfile memory profile = abi.decode(
                dataProfile, 
                (IStakingIntegration.UserSkillProfile)
            );
            metrics.activeSkills = uint8(profile.activeNFTIds.length);
            metrics.level = profile.level;
            metrics.xp = profile.totalXP;
            metrics.boosts = profile.stakingBoostTotal;
        }
        
        return metrics;
    }
    
    /// @notice Get complete market statistics
    function getMarketStats() external view returns (MarketStats memory) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("getAutoCompoundUsers()")
        );
        
        uint256 autoCompoundCount = 0;
        if (success) {
            address[] memory autoCompoundUsers = abi.decode(data, (address[]));
            autoCompoundCount = autoCompoundUsers.length;
        }
        
        return MarketStats({
            autoCompoundUsersCount: autoCompoundCount,
            timestamp: block.timestamp
        });
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
    
    function _getNFTRarity(uint256 nftId) internal view returns (IStakingIntegration.Rarity) {
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("nftRarity(uint256)", nftId)
        );
        if (!success) {
            return IStakingIntegration.Rarity.COMMON;
        }
        return abi.decode(data, (IStakingIntegration.Rarity));
    }
    
    function _getSkillConfig(IStakingIntegration.SkillType skillType) internal view returns (bool enabled, uint16 effect) {
        // Check if skill is enabled
        (bool successEnabled, bytes memory dataEnabled) = stakingContract.staticcall(
            abi.encodeWithSignature("skillEnabled(uint8)", uint8(skillType))
        );
        if (successEnabled) {
            enabled = abi.decode(dataEnabled, (bool));
        }
        
        // Get default effect value
        (bool successEffect, bytes memory dataEffect) = stakingContract.staticcall(
            abi.encodeWithSignature("skillDefaultEffects(uint8)", uint8(skillType))
        );
        if (successEffect) {
            effect = abi.decode(dataEffect, (uint16));
        }
        
        return (enabled, effect);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPER FUNCTIONS
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
        if (rarity == IStakingIntegration.Rarity.COMMON) return 100;
        if (rarity == IStakingIntegration.Rarity.UNCOMMON) return 110;
        if (rarity == IStakingIntegration.Rarity.RARE) return 120;
        if (rarity == IStakingIntegration.Rarity.EPIC) return 140;
        if (rarity == IStakingIntegration.Rarity.LEGENDARY) return 180;
        return 100;
    }
}
