// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IMarketplaceCore {
    struct NFTMetadata {
        address creator;
        string uri;
        string category;
        uint256 createdAt;
        uint96 royaltyPercentage;
    }
    
    struct Offer {
        address offeror;
        uint256 amount;
        uint8 expiresInDays;
        uint256 timestamp;
    }
    
    struct UserProfile {
        uint256 totalXP;
        uint8 level;
        uint256 nftsCreated;
        uint256 nftsOwned;
        uint32 nftsSold;
        uint32 nftsBought;
    }
    
    function getListedTokenIds() external view returns (uint256[] memory);
    function isListed(uint256 tokenId) external view returns (bool);
    function getNFTMetadata(uint256 tokenId) external view returns (address, string memory, string memory, uint256, uint96);
    function nftMetadata(uint256 tokenId) external view returns (NFTMetadata memory);
    function listedPrice(uint256 tokenId) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function userProfiles(address user) external view returns (UserProfile memory);
    function getOwnedTokensArray(address user) external view returns (uint256[] memory);
    function getCreatedTokensArray(address user) external view returns (uint256[] memory);
    function getOffersArray(uint256 tokenId) external view returns (Offer[] memory);
}
