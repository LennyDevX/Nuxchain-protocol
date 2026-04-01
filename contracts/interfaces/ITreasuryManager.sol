// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ITreasuryManager
 * @notice Interface for interacting with the TreasuryManager
 * @dev Updated to support weekly distribution cycle and enum-based treasury types
 */
interface ITreasuryManager {
    
    // Treasury type enum (must match TreasuryManager)
    enum TreasuryType {
        REWARDS,
        STAKING,
        COLLABORATORS,
        DEVELOPMENT,
        MARKETPLACE
    }
    
    // Protocol health status enum
    enum ProtocolStatus {
        HEALTHY,
        UNSTABLE,
        CRITICAL,
        EMERGENCY
    }
    
    /**
     * @notice Receive revenue with type label
     * @param revenueType Type of revenue ("staking_commission", "marketplace_fee", etc.)
     */
    function receiveRevenue(string calldata revenueType) external payable;
    
    /**
     * @notice Get treasury address for a specific type
     * @param treasuryType Type of treasury (enum)
     */
    function treasuries(TreasuryType treasuryType) external view returns (address);
    
    /**
     * @notice Get allocation percentage for a treasury type
     * @param treasuryType Type of treasury (enum)
     */
    function allocations(TreasuryType treasuryType) external view returns (uint256);
    
    /**
     * @notice Get current total balance
     */
    function getBalance() external view returns (uint256);
    
    /**
     * @notice Get available balance for distributions (total - reserve)
     */
    function getAvailableBalance() external view returns (uint256);
    
    /**
     * @notice Request immediate reward funds from TreasuryManager balance
     * @param amount Amount requested
     * @return success True if funds were provided
     */
    function requestRewardFunds(uint256 amount) external returns (bool success);
    
    /**
     * @notice Request emergency funds from reserve (when protocol is at risk)
     * @param protocol Type of protocol requesting funds (enum)
     * @param amount Amount requested from reserve
     * @return success True if emergency funds were provided
     * @dev Only authorized requesters can call this
     *      Draws from reserve fund if enabled
     *      Requires emergencyModeEnabled = true
     */
    function requestEmergencyFunds(TreasuryType protocol, uint256 amount) 
        external 
        returns (bool success);
    
    /**
     * @notice Check if distribution is ready to be triggered
     * @return ready True if distribution can be executed now
     * @return timeUntilNext Seconds until next distribution (0 if ready)
     */
    function isDistributionReady() external view returns (bool ready, uint256 timeUntilNext);
    
    /**
     * @notice Trigger weekly revenue distribution (if ready)
     */
    function triggerDistribution() external;
    
    /**
     * @notice Get distribution timeline information
     */
    function getDistributionTimeline()
        external
        view
        returns (
            uint256 firstDeposit,
            uint256 lastDistribution,
            uint256 nextDistribution,
            uint256 timeUntilNext,
            bool isReady
        );
    
    /**
     * @notice Update protocol health status
     * @param protocol Protocol type to update
     * @param newStatus New health status
     */
    function setProtocolStatus(TreasuryType protocol, ProtocolStatus newStatus) external;
    
    /**
     * @notice Check current health status of a protocol
     * @param protocol Protocol to check
     */
    function getProtocolStatus(TreasuryType protocol) 
        external 
        view 
        returns (ProtocolStatus status, uint256 deficit, bool canAccessEmergency);
    
    /**
     * @notice Get emergency mode information
     */
    function getEmergencyInfo()
        external
        view
        returns (
            bool isActive,
            uint256 timestamp,
            uint256 emergencyFundsDistributed,
            uint256 reserveAvailable
        );
    
    /**
     * @notice Declare emergency mode (protocols can access reserve funds)
     * @param reason Reason for emergency declaration
     */
    function declareEmergency(string calldata reason) external;
    
    /**
     * @notice End emergency mode (returns to normal distribution)
     */
    function endEmergency() external;
    
    /**
     * @notice Receive notification about significant APY compression
     * @param currentTVL Current total value locked
     * @param oldMultiplier Previous APY multiplier in basis points
     * @param newMultiplier New APY multiplier in basis points
     * @param compressionBps Compression amount in basis points
     * @dev Called by DynamicAPYCalculator when APY drops significantly
     */
    function notifyAPYCompression(
        uint256 currentTVL,
        uint256 oldMultiplier,
        uint256 newMultiplier,
        uint256 compressionBps
    ) external;
}
