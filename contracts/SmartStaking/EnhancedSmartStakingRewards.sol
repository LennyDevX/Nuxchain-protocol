// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEnhancedSmartStakingRewards.sol";

/**
 * @title EnhancedSmartStakingRewards
 * @notice Handles all reward calculation logic for the EnhancedSmartStaking system
 * @dev This module is stateless and performs pure calculations based on provided parameters
 */
contract EnhancedSmartStakingRewards is Ownable, IEnhancedSmartStakingRewards {
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    /// @notice Basis points denominator (100% = 10000)
    uint256 private constant BASIS_POINTS = 10000;
    
    /// @notice Maximum ROI percentage (125%)
    uint16 private constant MAX_ROI_PERCENTAGE = 12500;
    
    /// @notice Base hourly ROI for no lockup (0.005% per hour)
    uint256 private constant BASE_HOURLY_ROI = 50;
    
    /// @notice Hourly ROI for 30-day lockup (0.010% per hour)
    uint256 private constant ROI_30_DAYS = 100;
    
    /// @notice Hourly ROI for 90-day lockup (0.014% per hour)
    uint256 private constant ROI_90_DAYS = 140;
    
    /// @notice Hourly ROI for 180-day lockup (0.017% per hour)
    uint256 private constant ROI_180_DAYS = 170;
    
    /// @notice Hourly ROI for 365-day lockup (0.021% per hour)
    uint256 private constant ROI_365_DAYS = 210;
    
    /// @notice Maximum skill boost percentage (500%)
    uint16 private constant MAX_SKILL_BOOST = 5000;
    
    /// @notice Maximum fee discount (50%)
    uint8 private constant MAX_FEE_DISCOUNT = 50;
    
    /// @notice Fee discount per active skill (5% per skill)
    uint8 private constant FEE_DISCOUNT_PER_SKILL = 5;
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /// @notice Array of lockup period durations (in seconds)
    uint256[] private lockupPeriods;
    
    /// @notice Array of base APY percentages corresponding to lockup periods
    uint256[] private baseAPYs;
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        // Initialize lockup periods: 0, 30, 90, 180, 365 days
        lockupPeriods = [0, 30 days, 90 days, 180 days, 365 days];
        
        // Initialize base APYs: Calculate from hourly ROI
        // APY = (hourly_roi * 8760 hours) / 10000
        baseAPYs = [
            (BASE_HOURLY_ROI * 8760) / 100,    // ~438% APY for no lockup
            (ROI_30_DAYS * 8760) / 100,         // ~876% APY for 30 days
            (ROI_90_DAYS * 8760) / 100,         // ~1226.4% APY for 90 days
            (ROI_180_DAYS * 8760) / 100,        // ~1489.2% APY for 180 days
            (ROI_365_DAYS * 8760) / 100         // ~1839.6% APY for 365 days
        ];
    }
    
    // ============================================
    // PUBLIC VIEW FUNCTIONS - REWARD CALCULATIONS
    // ============================================
    
    /**
     * @notice Calculate base rewards without any boosts
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
    ) external view override returns (uint256 rewards) {
        require(lockupPeriodIndex < lockupPeriods.length, "Invalid lockup period");
        
        // Calculate elapsed hours
        uint256 elapsedHours = (block.timestamp - lastClaimTime) / 3600;
        if (elapsedHours == 0) return 0;
        
        // Get hourly ROI based on lockup period
        uint256 hourlyROI = _getHourlyROI(lockupPeriodIndex);
        
        // Calculate base reward: amount * hourly_roi * hours / 1000000
        rewards = (depositAmount * hourlyROI * elapsedHours) / 1000000;
        
        // Apply maximum ROI cap
        uint256 maxReward = (depositAmount * MAX_ROI_PERCENTAGE) / BASIS_POINTS;
        if (rewards > maxReward) {
            rewards = maxReward;
        }
        
        // Apply time bonus
        uint256 stakingDuration = block.timestamp - depositTime;
        uint256 timeBonus = _calculateTimeBonus(stakingDuration);
        if (timeBonus > 0) {
            rewards += (rewards * timeBonus) / BASIS_POINTS;
        }
    }
    
    /**
     * @notice Calculate rewards with skill boost applied
     * @param depositAmount The amount deposited
     * @param depositTime The timestamp of deposit
     * @param lastClaimTime The last time rewards were claimed
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @param totalBoost The total boost percentage from active skills (in basis points)
     * @return boostedRewards The calculated rewards with boost applied
     */
    function calculateBoostedRewards(
        uint256 depositAmount,
        uint256 depositTime,
        uint256 lastClaimTime,
        uint8 lockupPeriodIndex,
        uint16 totalBoost
    ) external view override returns (uint256 boostedRewards) {
        // Get base rewards
        boostedRewards = calculateRewards(
            depositAmount,
            depositTime,
            lastClaimTime,
            lockupPeriodIndex
        );
        
        // Apply skill boost
        if (totalBoost > 0) {
            // Cap boost at maximum
            uint16 cappedBoost = totalBoost > MAX_SKILL_BOOST ? MAX_SKILL_BOOST : totalBoost;
            boostedRewards += (boostedRewards * cappedBoost) / BASIS_POINTS;
        }
    }
    
    /**
     * @notice Calculate rewards with skill boost and rarity multiplier applied
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
    ) external view override returns (uint256 boostedRewards) {
        // Get boosted rewards
        boostedRewards = this.calculateBoostedRewards(
            depositAmount,
            depositTime,
            lastClaimTime,
            lockupPeriodIndex,
            totalBoost
        );
        
        // Apply rarity multiplier (100 = 1x, 500 = 5x)
        if (rarityMultiplier > 100) {
            boostedRewards = (boostedRewards * rarityMultiplier) / 100;
        }
    }
    
    /**
     * @notice Calculate fee discount based on active skill count
     * @param activeSkillCount The number of active skills
     * @return discountPercentage The discount percentage (0-50)
     */
    function calculateFeeDiscount(uint8 activeSkillCount) external pure override returns (uint8 discountPercentage) {
        discountPercentage = activeSkillCount * FEE_DISCOUNT_PER_SKILL;
        
        // Cap at maximum discount
        if (discountPercentage > MAX_FEE_DISCOUNT) {
            discountPercentage = MAX_FEE_DISCOUNT;
        }
    }
    
    /**
     * @notice Calculate boosted APY for a given lockup period and skill boost
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @param totalBoost The total boost percentage from active skills
     * @return apy The boosted APY percentage
     */
    function calculateBoostedAPY(uint8 lockupPeriodIndex, uint16 totalBoost) external view override returns (uint256 apy) {
        require(lockupPeriodIndex < baseAPYs.length, "Invalid lockup period");
        
        // Get base APY
        apy = baseAPYs[lockupPeriodIndex];
        
        // Apply skill boost
        if (totalBoost > 0) {
            uint16 cappedBoost = totalBoost > MAX_SKILL_BOOST ? MAX_SKILL_BOOST : totalBoost;
            apy += (apy * cappedBoost) / BASIS_POINTS;
        }
    }
    
    /**
     * @notice Get the base APY for a lockup period
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @return apy The base APY percentage
     */
    function getBaseAPY(uint8 lockupPeriodIndex) external view override returns (uint256 apy) {
        require(lockupPeriodIndex < baseAPYs.length, "Invalid lockup period");
        return baseAPYs[lockupPeriodIndex];
    }
    
    /**
     * @notice Get all lockup periods configuration
     * @return periods Array of lockup period durations
     * @return apys Array of corresponding APY rates
     */
    function getLockupPeriodsConfig() external view override returns (
        uint256[] memory periods,
        uint256[] memory apys
    ) {
        return (lockupPeriods, baseAPYs);
    }
    
    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================
    
    /**
     * @notice Get hourly ROI based on lockup period index
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @return hourlyROI The hourly ROI in basis points (per million)
     */
    function _getHourlyROI(uint8 lockupPeriodIndex) internal pure returns (uint256 hourlyROI) {
        if (lockupPeriodIndex == 0) return BASE_HOURLY_ROI;
        if (lockupPeriodIndex == 1) return ROI_30_DAYS;
        if (lockupPeriodIndex == 2) return ROI_90_DAYS;
        if (lockupPeriodIndex == 3) return ROI_180_DAYS;
        if (lockupPeriodIndex == 4) return ROI_365_DAYS;
        revert("Invalid lockup period index");
    }
    
    /**
     * @notice Calculate time bonus based on staking duration
     * @param stakingDuration The duration in seconds since deposit
     * @return bonus The bonus percentage in basis points
     */
    function _calculateTimeBonus(uint256 stakingDuration) internal pure returns (uint256 bonus) {
        if (stakingDuration >= 365 days) return 500;     // 5%
        if (stakingDuration >= 180 days) return 300;     // 3%
        if (stakingDuration >= 90 days) return 100;      // 1%
        if (stakingDuration >= 30 days) return 50;       // 0.5%
        return 0;
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    /**
     * @notice Update base APY for a specific lockup period (admin only)
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @param newAPY The new APY percentage
     */
    function updateBaseAPY(uint8 lockupPeriodIndex, uint256 newAPY) external onlyOwner {
        require(lockupPeriodIndex < baseAPYs.length, "Invalid lockup period");
        require(newAPY > 0 && newAPY <= 10000, "Invalid APY"); // Max 100x APY
        
        uint256 oldAPY = baseAPYs[lockupPeriodIndex];
        baseAPYs[lockupPeriodIndex] = newAPY;
        
        emit APYUpdated(lockupPeriodIndex, oldAPY, newAPY);
    }
    
    // ============================================
    // EVENTS
    // ============================================
    
    event APYUpdated(uint8 indexed lockupPeriodIndex, uint256 oldAPY, uint256 newAPY);
}
