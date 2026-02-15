// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IMarketplaceStatistics
 * @notice Interface for Marketplace statistics tracking module
 * @dev Separates statistics tracking from core marketplace logic to reduce contract size
 */
interface IMarketplaceStatistics {
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event TradingVolumeUpdated(uint256 totalVolume, address user, uint256 userVolume);
    event RoyaltyPaid(address indexed creator, uint256 amount, uint256 tokenId);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // WRITE FUNCTIONS (Only MARKETPLACE_ROLE)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Records a completed NFT sale
     * @dev Only callable by GameifiedMarketplaceCoreV1 (MARKETPLACE_ROLE)
     * @param seller Address of the NFT seller
     * @param buyer Address of the NFT buyer
     * @param tokenId ID of the sold NFT
     * @param price Sale price in wei
     */
    function recordSale(
        address seller,
        address buyer,
        uint256 tokenId,
        uint256 price
    ) external;
    
    /**
     * @notice Records a royalty payment to NFT creator
     * @dev Only callable by GameifiedMarketplaceCoreV1 (MARKETPLACE_ROLE)
     * @param creator Address of the NFT creator receiving royalty
     * @param tokenId ID of the NFT that generated the royalty
     * @param royaltyAmount Amount of royalty paid in wei
     */
    function recordRoyaltyPayment(
        address creator,
        uint256 tokenId,
        uint256 royaltyAmount
    ) external;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // READ FUNCTIONS (Public)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Total number of NFTs sold across the marketplace
    function totalNFTsSold() external view returns (uint256);
    
    /// @notice Total trading volume in wei across the marketplace
    function totalTradingVolume() external view returns (uint256);
    
    /// @notice Total royalties paid to creators in wei
    function totalRoyaltiesPaid() external view returns (uint256);
    
    /// @notice Get user's total sales volume in wei
    function userSalesVolume(address user) external view returns (uint256);
    
    /// @notice Get user's total purchase volume in wei
    function userPurchaseVolume(address user) external view returns (uint256);
    
    /// @notice Get total royalties earned by a creator in wei
    function userRoyaltiesEarned(address user) external view returns (uint256);
    
    /// @notice Get number of NFTs sold by a user
    function userNFTsSold(address user) external view returns (uint256);
    
    /// @notice Get number of NFTs bought by a user
    function userNFTsBought(address user) external view returns (uint256);
}
