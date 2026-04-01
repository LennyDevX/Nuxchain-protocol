// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "../interfaces/IStakingIntegration.sol";
import "../interfaces/ISmartStakingPower.sol";
import "../interfaces/ISmartStakingGamification.sol";

/// @title SkillViewLib
/// @notice External library containing skill-related view logic for SmartStakingCore
/// @dev Deployed as a separate contract to keep Core bytecode under EIP-170 limit (24,576 bytes).
///      Called via STATICCALL from Core view functions (safe — no storage in library).
/// @custom:version 6.2.0
library SkillViewLib {

    uint256 private constant BASIS_POINTS = 10000;

    // ════════════════════════════════════════════════════════════════════════════════════
    // EXTERNAL VIEW FUNCTIONS (called from CoreV2 stubs)
    // ════════════════════════════════════════════════════════════════════════════════════

    /// @notice Returns active NFT powers for a user converted to the IStakingIntegration format
    function getActiveSkills(
        address skillsMod,
        address user
    ) external view returns (IStakingIntegration.NFTPower[] memory skills) {
        if (skillsMod == address(0)) return new IStakingIntegration.NFTPower[](0);

        ISmartStakingPower.PowerInfo[] memory infos =
            ISmartStakingPower(skillsMod).getActivePowersWithDetails(user);

        skills = new IStakingIntegration.NFTPower[](infos.length);
        for (uint256 i = 0; i < infos.length; i++) {
            skills[i] = IStakingIntegration.NFTPower({
                powerType:    infos[i].powerType,
                effectValue:  infos[i].boost,
                rarity:       IStakingIntegration.Rarity(uint8(infos[i].rarity)),
                activatedAt:  infos[i].activatedAt,
                cooldownEnds: infos[i].cooldownEnds,
                isActive:     infos[i].isActive
            });
        }
    }

    /// @notice Returns the full power + gamification profile for a user
    function getUserSkillProfile(
        address skillsMod,
        address gamMod,
        address user
    ) external view returns (IStakingIntegration.UserPowerProfile memory profile) {
        profile.maxActiveSkills = 5; // MAX_ACTIVE_SKILL_SLOTS
        profile.activeNFTIds = new uint256[](0);

        uint16 feeDiscountBps;
        bool hasAutoCompoundSkill;

        if (skillsMod != address(0)) {
            ISmartStakingPower.UserPowerProfile memory sp =
                ISmartStakingPower(skillsMod).getUserPowerProfile(user);
            profile.activeNFTIds    = sp.activeSkillNFTIds;
            profile.stakingBoostTotal = sp.totalBoost;

            ISmartStakingPower.PowerInfo[] memory infos =
                ISmartStakingPower(skillsMod).getActivePowersWithDetails(user);
            (feeDiscountBps, , hasAutoCompoundSkill) = _summarizePowerEffects(infos);
            profile.feeDiscountTotal = feeDiscountBps;
        }

        if (gamMod != address(0)) {
            (uint256 xp, uint16 level,) = ISmartStakingGamification(gamMod).getUserXPInfo(user);
            profile.totalXP = xp;
            profile.level   = level;
            if (ISmartStakingGamification(gamMod).getAutoCompoundConfig(user).enabled) {
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
        (uint16 totalBoost,,) = ISmartStakingPower(skillsMod).getUserBoosts(user);
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

        ISmartStakingPower.PowerInfo[] memory infos =
            ISmartStakingPower(skillsMod).getActivePowersWithDetails(user);
        (, uint16 lockReducerBps,) = _summarizePowerEffects(infos);

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

        ISmartStakingPower.PowerInfo[] memory infos =
            ISmartStakingPower(skillsMod).getActivePowersWithDetails(user);
        (uint16 feeDiscountBps,,) = _summarizePowerEffects(infos);

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
            ISmartStakingGamification(gamMod).getAutoCompoundConfig(user).enabled) {
            return true;
        }
        if (skillsMod == address(0)) return false;

        ISmartStakingPower.PowerInfo[] memory infos =
            ISmartStakingPower(skillsMod).getActivePowersWithDetails(user);
        (,, bool result) = _summarizePowerEffects(infos);
        return result;
    }

    /// @notice Returns NFT rarity converted to IStakingIntegration.Rarity
    function nftRarity(
        address skillsMod,
        uint256 nftId
    ) external view returns (IStakingIntegration.Rarity) {
        if (skillsMod == address(0)) return IStakingIntegration.Rarity.COMMON;
        (ISmartStakingPower.PowerRarity rarity,) =
            ISmartStakingPower(skillsMod).getPowerRarity(nftId);
        return IStakingIntegration.Rarity(uint8(rarity));
    }

    /// @notice Checks if auto-compound should run for a user (Chainlink Automation compatible)
    function checkAutoCompound(
        address gamMod,
        address user
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        if (gamMod == address(0)) return (false, "");
        (bool shouldCompound,) = ISmartStakingGamification(gamMod).checkAutoCompound(user);
        return (shouldCompound, shouldCompound ? abi.encode(user) : bytes(""));
    }

    /// @notice Returns all addresses that have auto-compound enabled
    function getAutoCompoundUsers(address gamMod) external view returns (address[] memory autoUsers) {
        if (gamMod == address(0)) return new address[](0);
        (, , uint256 total) = ISmartStakingGamification(gamMod).getAutoCompoundUsersPage(0, 1);
        if (total == 0) return new address[](0);
        (autoUsers,,) = ISmartStakingGamification(gamMod).getAutoCompoundUsersPage(0, total);
    }

    // ════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL PURE HELPERS
    // ════════════════════════════════════════════════════════════════════════════════════

    function _summarizePowerEffects(
        ISmartStakingPower.PowerInfo[] memory powers
    ) internal pure returns (uint16 feeDiscountBps, uint16 lockReducerBps, bool hasAutoCompoundSkill) {
        uint256 feeAcc;
        uint256 lockAcc;

        for (uint256 i = 0; i < powers.length; i++) {
            if (!powers[i].isActive) continue;

            IStakingIntegration.PowerType pt = powers[i].powerType;
            uint16 boost = powers[i].boost;

            if (pt == IStakingIntegration.PowerType.FEE_REDUCER_I ||
                pt == IStakingIntegration.PowerType.FEE_REDUCER_II) {
                feeAcc += boost;
            }
            if (pt == IStakingIntegration.PowerType.LOCK_REDUCER) {
                lockAcc += boost;
            }
            if (!hasAutoCompoundSkill && pt == IStakingIntegration.PowerType.AUTO_COMPOUND) {
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
