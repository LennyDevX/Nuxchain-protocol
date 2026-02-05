// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ITreasuryManager
 * @notice Interface for interacting with the TreasuryManager
 */
interface ITreasuryManager {
    
    /**
     * @notice Receive revenue with type label
     * @param revenueType Type of revenue ("staking_commission", "marketplace_fee", etc.)
     */
    function receiveRevenue(string calldata revenueType) external payable;
    
    /**
     * @notice Get treasury address for a specific type
     * @param treasuryType Type of treasury
     */
    function treasuries(string calldata treasuryType) external view returns (address);
    
    /**
     * @notice Get allocation percentage for a treasury type
     * @param treasuryType Type of treasury
     */
    function allocations(string calldata treasuryType) external view returns (uint256);
    
    /**
     * @notice Get current balance
     */
    function getBalance() external view returns (uint256);
    
    /**
     * @notice Request funds from rewards pool (only authorized contracts)
     * @param amount Amount requested
     * @return success True if funds were provided
     */
    function requestRewardFunds(uint256 amount) external returns (bool success);
}
