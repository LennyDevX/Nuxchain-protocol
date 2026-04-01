// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IBadgeManager
 * @notice Interface for badge holder management and validation
 * @dev Used by CollaboratorBadgeRewards to verify badge holder status dynamically
 */
interface IBadgeManager {
    /**
     * @notice Check if an address holds a valid collaborator badge
     * @param account Address to check
     * @return True if address holds a valid badge
     */
    function hasBadge(address account) external view returns (bool);
    
    /**
     * @notice Get total count of active badge holders
     * @return Total number of badge holders
     */
    function getTotalBadgeHolders() external view returns (uint256);
    
    /**
     * @notice Get all badge holder addresses (for batch operations)
     * @return Array of badge holder addresses
     */
    function getAllBadgeHolders() external view returns (address[] memory);
}
