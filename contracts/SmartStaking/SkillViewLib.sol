// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "../interfaces/IStakingIntegration.sol";
import "../interfaces/IEnhancedSmartStakingSkills.sol";
import "../interfaces/IEnhancedSmartStakingGamification.sol";

/// @title SkillViewLib
/// @notice External library containing skill-related view logic for EnhancedSmartStakingCoreV2
/// @dev Deployed as a separate contract to keep CoreV2 bytecode under EIP-170 limit (24,576 bytes).
///      Called via STATICCALL from CoreV2 view functions (safe — no storage in library).
/// @custom:version 6.2.0
library SkillViewLib {

    uint256 private constant BASIS_POINTS = 10000;

    // ════════════════════════════════════════════════════════════════════════════════════
    // EXTERNAL VIEW FUNCTIONS (called from CoreV2 stubs)
    // ════════════════════════════════════════════════════════════════════════════════════

    /// @notice Returns active NFT skills for a user converted to the IStakingIntegration format
    function getActiveSkills(
        address skillsMod,
        address user
    ) external view returns (IStakingIntegration.NFTSkill[] memory skills) {
        if (skillsMod == address(0)) return new IStakingIntegration.NFTSkill[](0);

        IEnhancedSmartStakingSkills.SkillInfo[] memory infos =
            IEnhancedSmartStakingSkills(skillsMod).getActiveSkillsWithDetails(user);

        skills = new IStakingIntegration.NFTSkill[](infos.length);
        for (uint256 i = 0; i < infos.length; i++) {
            skills[i] = IStakingIntegration.NFTSkill({
                skillType:    infos[i].skillType,
                effectValue:  infos[i].boost,
                rarity:       IStakingIntegration.Rarity(uint8(infos[i].rarity)),
                activatedAt:  infos[i].activatedAt,
                cooldownEnds: infos[i].cooldownEnds,
                isActive:     infos[i].isActive
            });
        }
    }

    /// @notice Returns the full skill + gamification profile for a user
    function getUserSkillProfile(
        address skillsMod,
        address gamMod,
        address user
    ) external view returns (IStakingIntegration.UserSkillProfile memory profile) {
        profile.maxActiveSkills = 5; // MAX_ACTIVE_SKILL_SLOTS
        profile.activeNFTIds = new uint256[](0);

        uint16 feeDiscountBps;
        bool hasAutoCompoundSkill;

        if (skillsMod != address(0)) {
            IEnhancedSmartStakingSkills.UserSkillProfile memory sp =
                IEnhancedSmartStakingSkills(skillsMod).getUserSkillProfile(user);
            profile.activeNFTIds    = sp.activeSkillNFTIds;
            profile.stakingBoostTotal = sp.totalBoost;

            IEnhancedSmartStakingSkills.SkillInfo[] memory infos =
                IEnhancedSmartStakingSkills(skillsMod).getActiveSkillsWithDetails(user);
            (feeDiscountBps, , hasAutoCompoundSkill) = _summarizeSkillEffects(infos);
            profile.feeDiscountTotal = feeDiscountBps;
        }

        if (gamMod != address(0)) {
            (uint256 xp, uint16 level,) = IEnhancedSmartStakingGamification(gamMod).getUserXPInfo(user);
            profile.totalXP = xp;
            profile.level   = level;
            if (IEnhancedSmartStakingGamification(gamMod).getAutoCompoundConfig(user).enabled) {
                profile.hasAutoCompound = true;
            }
        }

        if (!profile.hasAutoCompound && hasAutoCompoundSkill) {
            profile.hasAutoCompound = true;
        }
    }

    /// @notice Returns APY boosted by the user's active staking skills
    function calculateBoostedAPY(
        address skillsMod,
        address user,
        uint256 baseAPY
    ) external view returns (uint256) {
        if (skillsMod == address(0)) return baseAPY;
        (uint16 totalBoost,,) = IEnhancedSmartStakingSkills(skillsMod).getUserBoosts(user);
        if (totalBoost == 0) return baseAPY;
        return baseAPY + (baseAPY * totalBoost / BASIS_POINTS);
    }

    /// @notice Returns lockup time reduced by the user's LOCK_REDUCER skill
    function calculateReducedLockTime(
        address skillsMod,
        address user,
        uint256 baseLockTime
    ) external view returns (uint256) {
        if (skillsMod == address(0) || baseLockTime == 0) return baseLockTime;

        IEnhancedSmartStakingSkills.SkillInfo[] memory infos =
            IEnhancedSmartStakingSkills(skillsMod).getActiveSkillsWithDetails(user);
        (, uint16 lockReducerBps,) = _summarizeSkillEffects(infos);

        if (lockReducerBps == 0) return baseLockTime;
        if (lockReducerBps > BASIS_POINTS) lockReducerBps = uint16(BASIS_POINTS);

        uint256 reduction = (baseLockTime * lockReducerBps) / BASIS_POINTS;
        return baseLockTime > reduction ? baseLockTime - reduction : 0;
    }

    /// @notice Returns fee reduced by the user's FEE_REDUCER skill(s)
    function calculateFeeDiscount(
        address skillsMod,
        address user,
        uint256 baseFee
    ) external view returns (uint256) {
        if (skillsMod == address(0) || baseFee == 0) return baseFee;

        IEnhancedSmartStakingSkills.SkillInfo[] memory infos =
            IEnhancedSmartStakingSkills(skillsMod).getActiveSkillsWithDetails(user);
        (uint16 feeDiscountBps,,) = _summarizeSkillEffects(infos);

        if (feeDiscountBps == 0) return baseFee;
        if (feeDiscountBps > BASIS_POINTS) feeDiscountBps = uint16(BASIS_POINTS);

        uint256 discountAmount = (baseFee * feeDiscountBps) / BASIS_POINTS;
        return baseFee > discountAmount ? baseFee - discountAmount : 0;
    }

    /// @notice Returns whether a user has an active AUTO_COMPOUND skill or config
    function hasAutoCompound(
        address skillsMod,
        address gamMod,
        address user
    ) external view returns (bool) {
        if (gamMod != address(0) &&
            IEnhancedSmartStakingGamification(gamMod).getAutoCompoundConfig(user).enabled) {
            return true;
        }
        if (skillsMod == address(0)) return false;

        IEnhancedSmartStakingSkills.SkillInfo[] memory infos =
            IEnhancedSmartStakingSkills(skillsMod).getActiveSkillsWithDetails(user);
        (,, bool result) = _summarizeSkillEffects(infos);
        return result;
    }

    /// @notice Returns NFT rarity converted to IStakingIntegration.Rarity
    function nftRarity(
        address skillsMod,
        uint256 nftId
    ) external view returns (IStakingIntegration.Rarity) {
        if (skillsMod == address(0)) return IStakingIntegration.Rarity.COMMON;
        (IEnhancedSmartStakingSkills.SkillRarity rarity,) =
            IEnhancedSmartStakingSkills(skillsMod).getSkillRarity(nftId);
        return IStakingIntegration.Rarity(uint8(rarity));
    }

    /// @notice Checks if auto-compound should run for a user (Chainlink Automation compatible)
    function checkAutoCompound(
        address gamMod,
        address user
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        if (gamMod == address(0)) return (false, "");
        (bool shouldCompound,) = IEnhancedSmartStakingGamification(gamMod).checkAutoCompound(user);
        return (shouldCompound, shouldCompound ? abi.encode(user) : bytes(""));
    }

    /// @notice Returns all addresses that have auto-compound enabled
    function getAutoCompoundUsers(address gamMod) external view returns (address[] memory autoUsers) {
        if (gamMod == address(0)) return new address[](0);
        (, , uint256 total) = IEnhancedSmartStakingGamification(gamMod).getAutoCompoundUsersPage(0, 1);
        if (total == 0) return new address[](0);
        (autoUsers,,) = IEnhancedSmartStakingGamification(gamMod).getAutoCompoundUsersPage(0, total);
    }

    // ════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL PURE HELPERS
    // ════════════════════════════════════════════════════════════════════════════════════

    function _summarizeSkillEffects(
        IEnhancedSmartStakingSkills.SkillInfo[] memory skills
    ) internal pure returns (uint16 feeDiscountBps, uint16 lockReducerBps, bool hasAutoCompoundSkill) {
        uint256 feeAcc;
        uint256 lockAcc;

        for (uint256 i = 0; i < skills.length; i++) {
            if (!skills[i].isActive) continue;

            IStakingIntegration.SkillType st = skills[i].skillType;
            uint16 boost = skills[i].boost;

            if (st == IStakingIntegration.SkillType.FEE_REDUCER_I ||
                st == IStakingIntegration.SkillType.FEE_REDUCER_II) {
                feeAcc += boost;
            }
            if (st == IStakingIntegration.SkillType.LOCK_REDUCER) {
                lockAcc += boost;
            }
            if (!hasAutoCompoundSkill && st == IStakingIntegration.SkillType.AUTO_COMPOUND) {
                hasAutoCompoundSkill = true;
            }
        }

        uint256 maxVal = type(uint16).max;
        if (feeAcc > maxVal)  feeAcc  = maxVal;
        if (lockAcc > maxVal) lockAcc = maxVal;

        feeDiscountBps = uint16(feeAcc);
        lockReducerBps = uint16(lockAcc);
    }
}
