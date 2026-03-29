// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "../interfaces/IMarketplaceView.sol";
import "../interfaces/IMarketplaceCore.sol";
import "../interfaces/IMarketplaceSocial.sol";
import "../interfaces/IMarketplaceStatistics.sol";

contract MarketplaceView is AccessControl, IMarketplaceView {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");
    
    IMarketplaceCore public marketplaceCore;
    IMarketplaceSocial public socialModule;
    IMarketplaceStatistics public statisticsModule;
    mapping(string => EnumerableSetUpgradeable.UintSet) private _nftsByCategory;

    struct NFTFullInfo {
        IMarketplaceCore.NFTMetadata metadata;
        address owner;
        bool isListed;
        uint256 price;
        uint256 likeCount;
        uint256 commentCount;
        IMarketplaceCore.Offer[] offers;
    }

    struct UserActivitySummary {
        uint256 totalXP;
        uint8 level;
        uint256 nftsCreated;
        uint256 nftsSold;
        uint256 nftsBought;
        uint256 salesVolume;
        uint256 purchaseVolume;
        uint256 royaltiesEarned;
    }
    
    constructor(address admin, address marketplaceCoreAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MARKETPLACE_ROLE, marketplaceCoreAddress);
        marketplaceCore = IMarketplaceCore(marketplaceCoreAddress);
    }
    
    function setSocialModule(address _social) external onlyRole(DEFAULT_ADMIN_ROLE) {
        socialModule = IMarketplaceSocial(_social);
    }
    
    function setStatisticsModule(address _statistics) external onlyRole(DEFAULT_ADMIN_ROLE) {
        statisticsModule = IMarketplaceStatistics(_statistics);
    }
    
    function addNFTToCategory(uint256 tokenId, string memory category) external onlyRole(MARKETPLACE_ROLE) {
        _nftsByCategory[category].add(tokenId);
    }
    
    function removeNFTFromCategory(uint256 tokenId, string memory category) external onlyRole(MARKETPLACE_ROLE) {
        _nftsByCategory[category].remove(tokenId);
    }
    
    function getListedTokens() external view returns (uint256[] memory) {
        return marketplaceCore.getListedTokenIds();
    }
    
    function getNFTsByCategory(string memory category) external view returns (uint256[] memory) {
        return _nftsByCategory[category].values();
    }
    
    function getCategoryCount(string memory category) external view returns (uint256) {
        return _nftsByCategory[category].length();
    }
    
    function getListedTokensPaginated(uint256 offset, uint256 limit) external view returns (uint256[] memory) {
        uint256[] memory allTokens = marketplaceCore.getListedTokenIds();
        return _paginate(allTokens, offset, limit);
    }
    
    function getNFTsByCategoryPaginated(string memory category, uint256 offset, uint256 limit) external view returns (uint256[] memory) {
        uint256[] memory allTokens = _nftsByCategory[category].values();
        return _paginate(allTokens, offset, limit);
    }
    
    function getUserProfile(address user) external view returns (IMarketplaceCore.UserProfile memory) {
        return marketplaceCore.userProfiles(user);
    }
    
    function getUserNFTs(address user) external view returns (uint256[] memory) {
        return marketplaceCore.getOwnedTokensArray(user);
    }
    
    function getUserNFTsPage(address user, uint256 offset, uint256 limit) external view returns (uint256[] memory) {
        uint256[] memory allTokens = marketplaceCore.getOwnedTokensArray(user);
        return _paginate(allTokens, offset, limit);
    }
    
    function getUserCreatedNFTs(address user) external view returns (uint256[] memory) {
        return marketplaceCore.getCreatedTokensArray(user);
    }
    
    function getUserCreatedNFTsPage(address user, uint256 offset, uint256 limit) external view returns (uint256[] memory) {
        uint256[] memory allTokens = marketplaceCore.getCreatedTokensArray(user);
        return _paginate(allTokens, offset, limit);
    }
    
    function getListedNFTs() external view returns (uint256[] memory) {
        return marketplaceCore.getListedTokenIds();
    }
    
    function getListedNFTsPage(uint256 offset, uint256 limit) external view returns (uint256[] memory) {
        uint256[] memory allTokens = marketplaceCore.getListedTokenIds();
        return _paginate(allTokens, offset, limit);
    }
    
    function getUserNFTsDetailed(address user) external view returns (IMarketplaceCore.NFTMetadata[] memory) {
        uint256[] memory tokenIds = marketplaceCore.getOwnedTokensArray(user);
        IMarketplaceCore.NFTMetadata[] memory result = new IMarketplaceCore.NFTMetadata[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            result[i] = marketplaceCore.nftMetadata(tokenIds[i]);
        }
        return result;
    }
    
    function getNFTMarketInfo(uint256 tokenId) external view returns (address owner, bool isListedStatus, uint256 price) {
        owner = marketplaceCore.ownerOf(tokenId);
        isListedStatus = marketplaceCore.isListed(tokenId);
        price = isListedStatus ? marketplaceCore.listedPrice(tokenId) : 0;
    }
    
    function getNFTOffers(uint256 tokenId) external view returns (IMarketplaceCore.Offer[] memory) {
        return marketplaceCore.getOffersArray(tokenId);
    }
    
    function getNFTLikeCount(uint256 tokenId) external view returns (uint256) {
        return address(socialModule) != address(0) ? socialModule.getLikeCount(tokenId) : 0;
    }
    
    function getNFTComments(uint256 tokenId) external view returns (IMarketplaceSocial.Comment[] memory) {
        if (address(socialModule) == address(0)) return new IMarketplaceSocial.Comment[](0);
        return socialModule.getComments(tokenId);
    }
    
    function getUserNFTLike(uint256 tokenId, address user) external view returns (bool) {
        return address(socialModule) != address(0) ? socialModule.hasUserLiked(tokenId, user) : false;
    }
    
    function _paginate(uint256[] memory allTokens, uint256 offset, uint256 limit) private pure returns (uint256[] memory) {
        if (offset >= allTokens.length) return new uint256[](0);
        uint256 end = offset + limit > allTokens.length ? allTokens.length : offset + limit;
        uint256 pageSize = end - offset;
        uint256[] memory result = new uint256[](pageSize);
        for (uint256 i = 0; i < pageSize; i++) {
            result[i] = allTokens[offset + i];
        }
        return result;
    }
    
    function setMarketplaceCore(address newCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MARKETPLACE_ROLE, newCore);
        marketplaceCore = IMarketplaceCore(newCore);
    }

    function getNFTFullInfo(uint256 tokenId) external view returns (NFTFullInfo memory) {
        return _buildNFTFullInfo(tokenId);
    }

    function getMultipleNFTs(uint256[] calldata ids) external view returns (NFTFullInfo[] memory) {
        NFTFullInfo[] memory result = new NFTFullInfo[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = _buildNFTFullInfo(ids[i]);
        }
        return result;
    }

    function getUserActivitySummary(address user) external view returns (UserActivitySummary memory) {
        IMarketplaceCore.UserProfile memory profile = marketplaceCore.userProfiles(user);
        uint256 salesVolume = address(statisticsModule) != address(0) ? statisticsModule.userSalesVolume(user) : 0;
        uint256 purchaseVolume = address(statisticsModule) != address(0) ? statisticsModule.userPurchaseVolume(user) : 0;
        uint256 royaltiesEarned = address(statisticsModule) != address(0) ? statisticsModule.userRoyaltiesEarned(user) : 0;
        return UserActivitySummary({
            totalXP: profile.totalXP,
            level: profile.level,
            nftsCreated: profile.nftsCreated,
            nftsSold: profile.nftsSold,
            nftsBought: profile.nftsBought,
            salesVolume: salesVolume,
            purchaseVolume: purchaseVolume,
            royaltiesEarned: royaltiesEarned
        });
    }

    function _buildNFTFullInfo(uint256 tokenId) private view returns (NFTFullInfo memory) {
        IMarketplaceCore.NFTMetadata memory meta = marketplaceCore.nftMetadata(tokenId);
        address owner = marketplaceCore.ownerOf(tokenId);
        bool listed = marketplaceCore.isListed(tokenId);
        uint256 price = listed ? marketplaceCore.listedPrice(tokenId) : 0;
        uint256 likeCount = address(socialModule) != address(0) ? socialModule.getLikeCount(tokenId) : 0;
        uint256 commentCount = address(socialModule) != address(0) ? socialModule.getCommentCount(tokenId) : 0;
        IMarketplaceCore.Offer[] memory offers = marketplaceCore.getOffersArray(tokenId);
        return NFTFullInfo({
            metadata: meta,
            owner: owner,
            isListed: listed,
            price: price,
            likeCount: likeCount,
            commentCount: commentCount,
            offers: offers
        });
    }
}
