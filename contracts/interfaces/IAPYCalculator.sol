// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAPYCalculator
 * @notice Interface for dynamic APY calculation based on TVL
 * @dev Allows staking contracts to query adjusted APY rates without tight coupling
 */
interface IAPYCalculator {
    
    // ============================================
    // EVENTS
    // ============================================
    
    /**
     * @notice Emitted when APY is calculated
     * @param currentTVL Total value locked used for calculation
     * @param baseAPY Base APY rate in basis points
     * @param dynamicAPY Calculated dynamic APY in basis points
     * @param multiplier Applied multiplier in basis points
     */
    event APYCalculated(
        uint256 indexed currentTVL,
        uint256 baseAPY,
        uint256 dynamicAPY,
        uint256 multiplier
    );
    
    /**
     * @notice Emitted when APY drops significantly (compression event)
     * @param oldMultiplier Previous multiplier in basis points
     * @param newMultiplier New multiplier in basis points
     * @param compressionBps Compression amount in basis points
     */
    event APYCompressionDetected(
        uint256 oldMultiplier,
        uint256 newMultiplier,
        uint256 compressionBps
    );
    
    // ============================================
    // CORE FUNCTIONS
    // ============================================
    
    /**
     * @notice Calculate dynamic APY based on current TVL
     * @param baseAPY Base APY rate in basis points (e.g., 1183 = 118.3%)
     * @param currentTVL Current total value locked in wei
     * @return dynamicAPY Adjusted APY rate in basis points
     */
    function calculateDynamicAPY(
        uint256 baseAPY,
        uint256 currentTVL
    ) external view returns (uint256 dynamicAPY);
    
    /**
     * @notice Batch calculate dynamic APY for multiple lock periods
     * @param baseAPYs Array of base APY rates
     * @param currentTVL Current total value locked
     * @return dynamicAPYs Array of adjusted APY rates
     */
    function calculateDynamicAPYBatch(
        uint256[] memory baseAPYs,
        uint256 currentTVL
    ) external view returns (uint256[] memory dynamicAPYs);
    
    /**
     * @notice Get current multiplier for given TVL
     * @param currentTVL Current TVL to calculate multiplier for
     * @return multiplier Current APY multiplier in basis points
     */
    function getCurrentMultiplier(uint256 currentTVL) external view returns (uint256 multiplier);
    
    /**
     * @notice Check if dynamic APY is enabled
     * @return enabled True if dynamic APY calculations are active
     */
    function dynamicAPYEnabled() external view returns (bool enabled);
}
