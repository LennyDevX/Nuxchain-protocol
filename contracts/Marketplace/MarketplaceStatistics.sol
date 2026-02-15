// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IMarketplaceStatistics.sol";

/**
 * @title MarketplaceStatistics
 * @notice Tracks global and per-user marketplace statistics
 * @dev Separate module to reduce GameifiedMarketplaceCoreV1 contract size
 * @custom:security Only GameifiedMarketplaceCoreV1 can update statistics (MARKETPLACE_ROLE)
 */
contract MarketplaceStatistics is AccessControl, IMarketplaceStatistics {
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - GLOBAL STATISTICS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    uint256 private _totalNFTsSold;
    uint256 private _totalTradingVolume;
    uint256 private _totalRoyaltiesPaid;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES - USER STATISTICS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    mapping(address => uint256) private _userSalesVolume;
    mapping(address => uint256) private _userPurchaseVolume;
    mapping(address => uint256) private _userRoyaltiesEarned;
    mapping(address => uint256) private _userNFTsSold;
    mapping(address => uint256) private _userNFTsBought;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Initializes the statistics module
     * @param admin Address to be granted DEFAULT_ADMIN_ROLE
     * @param marketplaceCore Address of GameifiedMarketplaceCoreV1 (granted MARKETPLACE_ROLE)
     */
    constructor(address admin, address marketplaceCore) {
        require(admin != address(0), "Invalid admin");
        require(marketplaceCore != address(0), "Invalid marketplace");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MARKETPLACE_ROLE, marketplaceCore);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // WRITE FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @inheritdoc IMarketplaceStatistics
     */
    function recordSale(
        address seller,
        address buyer,
        uint256 tokenId,
        uint256 price
    ) external onlyRole(MARKETPLACE_ROLE) {
        _totalNFTsSold++;
        _totalTradingVolume += price;
        _userSalesVolume[seller] += price;
        _userPurchaseVolume[buyer] += price;
        _userNFTsSold[seller]++;
        _userNFTsBought[buyer]++;
        
        emit NFTSold(seller, buyer, tokenId, price);
        emit TradingVolumeUpdated(_totalTradingVolume, seller, _userSalesVolume[seller]);
    }
    
    /**
     * @inheritdoc IMarketplaceStatistics
     */
    function recordRoyaltyPayment(
        address creator,
        uint256 tokenId,
        uint256 royaltyAmount
    ) external onlyRole(MARKETPLACE_ROLE) {
        _totalRoyaltiesPaid += royaltyAmount;
        _userRoyaltiesEarned[creator] += royaltyAmount;
        
        emit RoyaltyPaid(creator, royaltyAmount, tokenId);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS - GLOBAL STATISTICS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @inheritdoc IMarketplaceStatistics
    function totalNFTsSold() external view returns (uint256) {
        return _totalNFTsSold;
    }
    
    /// @inheritdoc IMarketplaceStatistics
    function totalTradingVolume() external view returns (uint256) {
        return _totalTradingVolume;
    }
    
    /// @inheritdoc IMarketplaceStatistics
    function totalRoyaltiesPaid() external view returns (uint256) {
        return _totalRoyaltiesPaid;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS - USER STATISTICS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @inheritdoc IMarketplaceStatistics
    function userSalesVolume(address user) external view returns (uint256) {
        return _userSalesVolume[user];
    }
    
    /// @inheritdoc IMarketplaceStatistics
    function userPurchaseVolume(address user) external view returns (uint256) {
        return _userPurchaseVolume[user];
    }
    
    /// @inheritdoc IMarketplaceStatistics
    function userRoyaltiesEarned(address user) external view returns (uint256) {
        return _userRoyaltiesEarned[user];
    }
    
    /// @inheritdoc IMarketplaceStatistics
    function userNFTsSold(address user) external view returns (uint256) {
        return _userNFTsSold[user];
    }
    
    /// @inheritdoc IMarketplaceStatistics
    function userNFTsBought(address user) external view returns (uint256) {
        return _userNFTsBought[user];
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Updates the marketplace core contract address
     * @dev Revokes MARKETPLACE_ROLE from old address and grants to new address
     * @param newCore Address of the new GameifiedMarketplaceCoreV1 contract
     */
    function setMarketplaceCore(address newCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newCore != address(0), "Invalid address");
        _grantRole(MARKETPLACE_ROLE, newCore);
    }
}
