// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IMarketplaceView
 * @notice Interface for Marketplace view and pagination functions
 * @dev Separates view logic from core marketplace to reduce contract size
 */
interface IMarketplaceView {
    // ════════════════════════════════════════════════════════════════════════════════════════
    // WRITE FUNCTIONS (Only MARKETPLACE_ROLE)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Adds an NFT to a category
     * @dev Only callable by GameifiedMarketplaceCoreV1 (MARKETPLACE_ROLE)
     * @param tokenId ID of the NFT to add
     * @param category Category name to add the NFT to
     */
    function addNFTToCategory(uint256 tokenId, string memory category) external;
    
    /**
     * @notice Removes an NFT from a category
     * @dev Only callable by GameifiedMarketplaceCoreV1 (MARKETPLACE_ROLE)
     * @param tokenId ID of the NFT to remove
     * @param category Category name to remove the NFT from
     */
    function removeNFTFromCategory(uint256 tokenId, string memory category) external;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // READ FUNCTIONS (Public)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Get all currently listed NFT token IDs
     * @return Array of token IDs that are listed for sale
     */
    function getListedTokens() external view returns (uint256[] memory);
    
    /**
     * @notice Get all NFTs in a specific category
     * @param category Category name to query
     * @return Array of token IDs in the category
     */
    function getNFTsByCategory(string memory category) external view returns (uint256[] memory);
    
    /**
     * @notice Get count of NFTs in a category
     * @param category Category name to query
     * @return Number of NFTs in the category
     */
    function getCategoryCount(string memory category) external view returns (uint256);
    
    /**
     * @notice Get paginated list of listed tokens
     * @param offset Starting index
     * @param limit Maximum number of results
     * @return Array of token IDs (paginated)
     */
    function getListedTokensPaginated(uint256 offset, uint256 limit) external view returns (uint256[] memory);
    
    /**
     * @notice Get paginated list of NFTs by category
     * @param category Category name to query
     * @param offset Starting index
     * @param limit Maximum number of results
     * @return Array of token IDs (paginated)
     */
    function getNFTsByCategoryPaginated(
        string memory category,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory);
}
