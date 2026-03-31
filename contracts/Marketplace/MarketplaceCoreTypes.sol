// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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

struct SaleSettlement {
    address seller;
    address buyer;
    uint256 grossAmount;
    uint256 platformFee;
    uint256 royaltyAmount;
    uint256 sellerAmount;
}