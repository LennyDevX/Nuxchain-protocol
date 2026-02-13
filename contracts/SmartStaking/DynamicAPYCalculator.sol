// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DynamicAPYCalculator
 * @notice Calculates dynamic APY rates based on Total Value Locked (TVL)
 * @dev Implements inverse square root formula: APY scales down as TVL increases
 * 
 * FORMULA: dynamicAPY = baseAPY × sqrt(targetTVL / currentTVL)
 * 
 * DESIGN RATIONALE:
 * - As TVL grows, APY decreases to maintain sustainable reward payouts
 * - Prevents exponential reward inflation at scale
 * - Smooth curve prevents sudden APY drops
 * 
 * EXAMPLE SCALING:
 * - TVL at target ($1M): APY = 100% of base rate
 * - TVL doubles ($2M): APY = 70.7% of base rate (√(1/2) ≈ 0.707)
 * - TVL 4x ($4M): APY = 50% of base rate (√(1/4) = 0.5)
 * - TVL 10x ($10M): APY = 31.6% of base rate (√(1/10) ≈ 0.316)
 * 
 * CONFIGURATION:
 * - targetTVL: Reference point where APY = baseRate (default: $1M = 1e24 wei)
 * - minAPYMultiplier: Floor to prevent APY from going too low (default: 30% = 3000 bps)
 * - maxAPYMultiplier: Ceiling when TVL is very low (default: 100% = 10000 bps)
 * 
 * @custom:security-contact security@nuvo.com
 * @custom:version 1.0.0
 */
contract DynamicAPYCalculator is Ownable {
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    uint256 private constant BASIS_POINTS = 10000; // 100%
    uint256 private constant PRECISION = 1e18;     // For sqrt calculations
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /// @notice Target TVL at which APY = base rate (in wei, default 1M POL = 1e24)
    uint256 public targetTVL;
    
    /// @notice Minimum APY multiplier (basis points, default 3000 = 30%)
    uint256 public minAPYMultiplier;
    
    /// @notice Maximum APY multiplier (basis points, default 10000 = 100%)
    uint256 public maxAPYMultiplier;
    
    /// @notice Enable/disable dynamic APY (can revert to static base rates)
    bool public dynamicAPYEnabled;
    
    // ============================================
    // EVENTS
    // ============================================
    
    event TargetTVLUpdated(uint256 oldTarget, uint256 newTarget);
    event APYMultiplierBoundsUpdated(uint256 newMin, uint256 newMax);
    event DynamicAPYToggled(bool enabled);
    event APYCalculated(uint256 currentTVL, uint256 baseAPY, uint256 dynamicAPY, uint256 multiplier);
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        targetTVL = 1_000_000 ether;         // 1M POL default target
        minAPYMultiplier = 3000;              // 30% minimum (prevents APY from dropping too low)
        maxAPYMultiplier = 10000;             // 100% maximum (base rate when TVL is at or below target)
        dynamicAPYEnabled = true;
    }
    
    // ============================================
    // CORE LOGIC - DYNAMIC APY CALCULATION
    // ============================================
    
    /**
     * @notice Calculate dynamic APY based on current TVL
     * @param baseAPY Base APY rate in basis points (e.g., 1183 = 118.3%)
     * @param currentTVL Current total value locked in the protocol (in wei)
     * @return dynamicAPY Adjusted APY rate in basis points
     * 
     * @dev Uses inverse square root scaling:
     *      multiplier = sqrt(targetTVL / currentTVL)
     *      dynamicAPY = baseAPY × multiplier
     *      
     *      Clamped between minAPYMultiplier and maxAPYMultiplier
     */
    function calculateDynamicAPY(
        uint256 baseAPY,
        uint256 currentTVL
    ) public view returns (uint256 dynamicAPY) {
        
        // If dynamic APY is disabled, return base rate
        if (!dynamicAPYEnabled) {
            return baseAPY;
        }
        
        // Edge case: if TVL is 0 or very low, return max multiplier
        if (currentTVL < 1 ether) {
            return (baseAPY * maxAPYMultiplier) / BASIS_POINTS;
        }
        
        // If TVL <= target, return base APY (100% multiplier)
        if (currentTVL <= targetTVL) {
            return baseAPY;
        }
        
        // Calculate multiplier using square root scaling
        // multiplier = sqrt(targetTVL / currentTVL)
        uint256 ratio = (targetTVL * PRECISION) / currentTVL;
        uint256 sqrtRatio = sqrt(ratio);
        
        // Convert to basis points (sqrtRatio is in PRECISION, need BASIS_POINTS)
        uint256 multiplier = (sqrtRatio * BASIS_POINTS) / PRECISION;
        
        // Clamp multiplier between min and max bounds
        if (multiplier < minAPYMultiplier) {
            multiplier = minAPYMultiplier;
        }
        if (multiplier > maxAPYMultiplier) {
            multiplier = maxAPYMultiplier;
        }
        
        // Apply multiplier to base APY
        dynamicAPY = (baseAPY * multiplier) / BASIS_POINTS;
        
        return dynamicAPY;
    }
    
    /**
     * @notice Batch calculate dynamic APY for multiple lock periods
     * @param baseAPYs Array of base APY rates for different lock periods
     * @param currentTVL Current total value locked
     * @return dynamicAPYs Array of adjusted APY rates
     */
    function calculateDynamicAPYBatch(
        uint256[] memory baseAPYs,
        uint256 currentTVL
    ) external view returns (uint256[] memory dynamicAPYs) {
        dynamicAPYs = new uint256[](baseAPYs.length);
        
        for (uint256 i = 0; i < baseAPYs.length; i++) {
            dynamicAPYs[i] = calculateDynamicAPY(baseAPYs[i], currentTVL);
        }
        
        return dynamicAPYs;
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    /**
     * @notice Update target TVL reference point
     * @param _targetTVL New target TVL in wei
     */
    function setTargetTVL(uint256 _targetTVL) external onlyOwner {
        require(_targetTVL > 0, "Target TVL must be positive");
        
        uint256 oldTarget = targetTVL;
        targetTVL = _targetTVL;
        
        emit TargetTVLUpdated(oldTarget, _targetTVL);
    }
    
    /**
     * @notice Update APY multiplier bounds
     * @param _minMultiplier Minimum multiplier in basis points (e.g., 3000 = 30%)
     * @param _maxMultiplier Maximum multiplier in basis points (e.g., 10000 = 100%)
     */
    function setAPYMultiplierBounds(
        uint256 _minMultiplier,
        uint256 _maxMultiplier
    ) external onlyOwner {
        require(_minMultiplier > 0, "Min multiplier must be positive");
        require(_maxMultiplier >= _minMultiplier, "Max must be >= min");
        require(_maxMultiplier <= BASIS_POINTS, "Max cannot exceed 100%");
        
        minAPYMultiplier = _minMultiplier;
        maxAPYMultiplier = _maxMultiplier;
        
        emit APYMultiplierBoundsUpdated(_minMultiplier, _maxMultiplier);
    }
    
    /**
     * @notice Enable or disable dynamic APY calculation
     * @param _enabled True to enable, false to use static base rates
     */
    function setDynamicAPYEnabled(bool _enabled) external onlyOwner {
        dynamicAPYEnabled = _enabled;
        emit DynamicAPYToggled(_enabled);
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @notice Get current multiplier for given TVL
     * @param currentTVL Current TVL to calculate multiplier for
     * @return multiplier Current APY multiplier in basis points
     */
    function getCurrentMultiplier(uint256 currentTVL) external view returns (uint256 multiplier) {
        if (!dynamicAPYEnabled || currentTVL <= targetTVL) {
            return BASIS_POINTS; // 100%
        }
        
        if (currentTVL < 1 ether) {
            return maxAPYMultiplier;
        }
        
        uint256 ratio = (targetTVL * PRECISION) / currentTVL;
        uint256 sqrtRatio = sqrt(ratio);
        multiplier = (sqrtRatio * BASIS_POINTS) / PRECISION;
        
        if (multiplier < minAPYMultiplier) {
            multiplier = minAPYMultiplier;
        }
        if (multiplier > maxAPYMultiplier) {
            multiplier = maxAPYMultiplier;
        }
        
        return multiplier;
    }
    
    /**
     * @notice Preview APY at different TVL levels
     * @param baseAPY Base APY in basis points
     * @param tvlLevels Array of TVL amounts to test
     * @return apyResults Corresponding dynamic APY rates
     */
    function previewAPYAtTVLs(
        uint256 baseAPY,
        uint256[] memory tvlLevels
    ) external view returns (uint256[] memory apyResults) {
        apyResults = new uint256[](tvlLevels.length);
        
        for (uint256 i = 0; i < tvlLevels.length; i++) {
            apyResults[i] = calculateDynamicAPY(baseAPY, tvlLevels[i]);
        }
        
        return apyResults;
    }
    
    // ============================================
    // INTERNAL MATH - SQUARE ROOT
    // ============================================
    
    /**
     * @notice Babylonian method for computing square root
     * @dev Gas-efficient implementation of sqrt using Newton's method
     * @param x Value to compute square root of (in PRECISION units)
     * @return y Square root of x (in PRECISION units)
     */
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        
        uint256 z = (x + 1) / 2;
        y = x;
        
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
