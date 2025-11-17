// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IEnhancedSmartStakingRewards
 * @notice Interface for reward calculation logic in the EnhancedSmartStaking system
 * @dev This module handles all reward computations including base rewards, skill boosts, and APY calculations
 */
interface IEnhancedSmartStakingRewards {
    
    // ============================================
    // STRUCTS
    // ============================================
    
    struct UserDeposit {
        uint256 amount;
        uint256 depositTime;
        uint256 lastClaimTime;
        uint256 lockEndTime;
        uint8 lockupPeriodIndex;
        bool isActive;
    }
    
    struct SkillBoost {
        uint16 totalBoost;
        uint16 rarityMultiplier;
        uint8 activeSkillCount;
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @notice Calculate base rewards for a user deposit
     * @param depositAmount The amount deposited
     * @param depositTime The timestamp of deposit
     * @param lastClaimTime The last time rewards were claimed
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @return rewards The calculated base rewards
     */
    function calculateRewards(
        uint256 depositAmount,
        uint256 depositTime,
        uint256 lastClaimTime,
        uint8 lockupPeriodIndex
    ) external view returns (uint256 rewards);
    
    /**
     * @notice Calculate rewards with skill boosts applied
     * @param depositAmount The amount deposited
     * @param depositTime The timestamp of deposit
     * @param lastClaimTime The last time rewards were claimed
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @param totalBoost The total boost percentage from active skills
     * @return boostedRewards The calculated rewards with boosts applied
     */
    function calculateBoostedRewards(
        uint256 depositAmount,
        uint256 depositTime,
        uint256 lastClaimTime,
        uint8 lockupPeriodIndex,
        uint16 totalBoost
    ) external view returns (uint256 boostedRewards);
    
    /**
     * @notice Calculate rewards with skill boosts and rarity multiplier applied
     * @param depositAmount The amount deposited
     * @param depositTime The timestamp of deposit
     * @param lastClaimTime The last time rewards were claimed
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @param totalBoost The total boost percentage from active skills
     * @param rarityMultiplier The rarity multiplier (100-500 for Common-Legendary)
     * @return boostedRewards The calculated rewards with all multipliers applied
     */
    function calculateBoostedRewardsWithRarityMultiplier(
        uint256 depositAmount,
        uint256 depositTime,
        uint256 lastClaimTime,
        uint8 lockupPeriodIndex,
        uint16 totalBoost,
        uint16 rarityMultiplier
    ) external view returns (uint256 boostedRewards);
    
    /**
     * @notice Calculate fee discount based on active skill count
     * @param activeSkillCount The number of active skills
     * @return discountPercentage The discount percentage (0-50)
     */
    function calculateFeeDiscount(uint8 activeSkillCount) external pure returns (uint8 discountPercentage);
    
    /**
     * @notice Calculate boosted APY for a given lockup period and skill boost
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @param totalBoost The total boost percentage from active skills
     * @return apy The boosted APY percentage
     */
    function calculateBoostedAPY(uint8 lockupPeriodIndex, uint16 totalBoost) external view returns (uint256 apy);
    
    /**
     * @notice Get the base APY for a lockup period
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @return apy The base APY percentage
     */
    function getBaseAPY(uint8 lockupPeriodIndex) external view returns (uint256 apy);
    
    /**
     * @notice Get all lockup periods configuration
     * @return periods Array of lockup period durations
     * @return apys Array of corresponding APY rates
     */
    function getLockupPeriodsConfig() external view returns (
        uint256[] memory periods,
        uint256[] memory apys
    );
}
