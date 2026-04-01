# Marketplace Contracts

**10 contracts — NFT minting, trading, social, gamification**

---

## Overview

The marketplace is an ERC-721 NFT exchange with built-in gamification. Users earn XP by trading and reach levels that unlock rewards. Revenue is shared between sellers, creators (royalties), and the protocol treasury.

```
MarketplaceCore (UUPS proxy + ERC721)
    ├── LevelingSystem     — POL rewards on level-up
    ├── ReferralSystem     — Referral tracking
    ├── MarketplaceView    — Rich read queries
    ├── MarketplaceStatistics — Sales recording & analytics
    ├── MarketplaceSocial  — Comments + likes
    ├── NuxPowerNft        — Mints power NFTs
    ├── NuxPowerMarketplace — Power NFT integration
    ├── QuestCore          — Quest engine
    └── CollaboratorBadgeRewards — Badge holder rewards
```

## What This Module Does In Plain English

If Smart Staking is the "earn yield" side of Nuxchain, Marketplace is the "do things and build a profile" side.

- A creator mints an NFT and chooses royalties.
- An owner lists it, updates the price, or accepts offers.
- A buyer purchases it and the payment is split automatically.
- The protocol records activity, social interactions, and XP in the background.
- Extra modules handle rewards, quests, referrals, comments, likes, and analytics.

The important idea for a new reader is that `MarketplaceCore` is not meant to do everything by itself. It is the transaction hub, while the surrounding contracts keep the marketplace readable, reward-driven, and easier to query from a frontend.

## How To Read This Page

| If you want to understand... | Start with... |
|---|---|
| How minting, listing, buying, and offers work | `MarketplaceCore` |
| Why users gain XP and level up | `LevelingSystem` |
| How the frontend gets rich NFT/user data | `MarketplaceView` |
| Where marketplace metrics come from | `MarketplaceStatistics` |
| How comments and likes are stored | `MarketplaceSocial` |
| How referrals work | [Referral.md](./Referral.md) |
| How quests and collaborator rewards plug in | [Gamification.md](./Gamification.md) |
| How power NFTs affect the marketplace | [NuxPower.md](./NuxPower.md) |

## Typical User Journey

1. A creator mints an NFT with `createToken()`.
2. The NFT can be listed for direct sale or left unlisted to receive offers.
3. A buyer purchases the NFT or submits an offer.
4. The contract sends the platform fee to treasury, pays royalties when needed, and pays the seller.
5. Marketplace activity increases XP, which can trigger a level-up reward.
6. Comments, likes, quests, referrals, and analytics update through their own modules.

---

## MarketplaceCore

**Type:** UUPS Proxy + ERC721 (Upgradeable)  
**Token name/symbol:** `NuxMarketNFT` / `GNFT`  
**Deploy:** `upgrades.deployProxy(factory, [TREASURY_ADDRESS], { kind: "uups" })`

### Constants

| Name | Value | Description |
|---|---|---|
| `PLATFORM_FEE_PERCENTAGE` | 6 | % of every sale sent to treasury |
| `MAX_OFFERS_PER_TOKEN` | 50 | Max simultaneous offers per NFT |
| `MAX_XP` | 5,000 | Total XP cap per address |
| `MAX_LEVEL` | 50 | Level cap (XP-based) |
| `MAX_COMMENTS_PER_NFT` | 1,000 | Max comments per token |

### Core Structs

```solidity
struct NFTMetadata {
    address creator;
    string  uri;
    string  category;
    uint256 createdAt;
    uint96  royaltyPercentage;
}

struct Offer {
    address offeror;
    uint256 amount;
    uint8   expiresInDays;
    uint256 timestamp;
}

struct UserProfile {
    uint256 totalXP;
    uint8   level;
    uint256 nftsCreated;
    uint256 nftsOwned;
    uint32  nftsSold;
    uint32  nftsBought;
}
```

### XP Rewards by Action

| Action | XP Gained |
|---|---|
| Create NFT | 10 |
| Sell NFT | 20 |
| Buy NFT | 15 |
| Add comment | 2 |
| Toggle like | 1 |

XP is capped at 5,000. Level is derived from XP: `level = floor(sqrt(totalXP / 100))`, capped at 50.

### Core User Functions

```solidity
// Mint a new ERC-721 NFT
function createToken(string memory uri, string memory category, uint96 royaltyPercentage)
    external returns (uint256 tokenId)

// List an NFT for sale at a fixed price
function listToken(uint256 tokenId, uint256 price) external

// Remove a listing
function unlistToken(uint256 tokenId) external

// Buy a listed NFT (send msg.value >= listed price)
function buyToken(uint256 tokenId) external payable nonReentrant

// Update listing price
function updatePrice(uint256 tokenId, uint256 newPrice) external

// Make an offer on any NFT (locked until accepted/cancelled)
function makeOffer(uint256 tokenId, uint8 expiresInDays) external payable nonReentrant

// Accept a specific offer (refunds all other offerors)
function acceptOffer(uint256 tokenId, uint256 offerIndex) external nonReentrant

// Cancel your own offer and reclaim ETH
function cancelOffer(uint256 tokenId, uint256 offerIndex) external nonReentrant

// Like or unlike an NFT
function toggleLike(uint256 tokenId) external

// Add a comment (stored in MarketplaceSocial module)
function addComment(uint256 tokenId, string calldata comment) external
```

### Fee & Royalty Logic

On every sale (`buyToken` and `acceptOffer`):
1. `platformFee = price * 6 / 100` → sent to `TreasuryManager`
2. If `creator != seller` (secondary market): `royalty = price * royaltyPercentage / 100` → sent to creator
3. Remainder → seller
4. Any excess `msg.value` above `price` → refunded to buyer
5. On `acceptOffer`: all non-winning offers → immediately refunded to their offerors

### Admin Functions

```solidity
function initialize(address _platformTreasury) public initializer
function setStatisticsModule(address _statistics) external onlyRole(ADMIN_ROLE)
function setViewModule(address _view) external onlyRole(ADMIN_ROLE)
function setSocialModule(address _social) external onlyRole(ADMIN_ROLE)
function setTreasuryManager(address _manager) external onlyRole(ADMIN_ROLE)
function setSkillsContract(address _skills) external onlyRole(ADMIN_ROLE)
function setLevelingSystem(address _leveling) external onlyRole(ADMIN_ROLE)
function setReferralSystem(address _referral) external onlyRole(ADMIN_ROLE)
function setStakingContract(address _staking) external onlyRole(ADMIN_ROLE)
function pause() / unpause() external onlyRole(ADMIN_ROLE)
```

### Events

```solidity
event TokenCreated(address indexed creator, uint256 indexed tokenId, string uri);
event TokenListed(address indexed seller, uint256 indexed tokenId, uint256 price);
event TokenUnlisted(address indexed seller, uint256 indexed tokenId);
event TokenSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
event OfferMade(address indexed offeror, uint256 indexed tokenId, uint256 amount);
event OfferAccepted(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 amount);
event PriceUpdated(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
event XPGained(address indexed user, uint256 amount, string reason);
event LevelUp(address indexed user, uint8 newLevel);
event LikeToggled(address indexed user, uint256 indexed tokenId, bool liked);
event CommentAdded(address indexed user, uint256 indexed tokenId, string comment);
```

### Errors

```solidity
error TokenNotFound();
error NotTokenOwner();
error TokenNotListed();
error InsufficientPayment();
error NoOffersAvailable();
error InvalidRoyalty();
error InvalidPrice();
error InvalidOfferId();
error InvalidOffer();
error OfferExpired();
error NotOfferor();
error XPOverflow();
error TreasuryFailed();
error RefundFailed();
error BadgeSoulbound();
```

---

## LevelingSystem

**Type:** UUPS Proxy (Ownable)  
**Deploy:** `upgrades.deployProxy(factory, [admin], { kind: "uups" })`  
**Post-deploy:** `grantRole(MARKETPLACE_ROLE, marketplaceCoreAddr)` on `LevelingSystem`

Pays out POL rewards when a user levels up in the marketplace.

### Constants

| Name | Value |
|---|---|
| `MAX_LEVEL` | 50 |
| `MAX_XP_TOTAL` | 7,500 |
| `MAX_LEVEL_REWARD` | 5 POL |

### Reward Formula

```
reward = MIN_REWARD + (level / SCALE_DIVISOR)
reward = min(reward, 5 POL)
```

### Key Functions

```solidity
function rewardLevelUp(address user, uint8 level) external onlyMarketplace
function getRewardForLevel(uint8 level) external view returns (uint256)
function getMaxLevel() external pure returns (uint8)   // returns 50
function addXP(address user, uint256 amount) external onlyMarketplace
```

---

## ReferralSystem

`ReferralSystem` is part of the marketplace experience, but it now has its own page because it is easier to understand as a separate user journey: share a code, onboard a buyer, apply a first-purchase discount, then reward the referrer when the referred account becomes active.

See [Referral.md](./Referral.md) for the dedicated explanation, flows, and key functions.

---

## MarketplaceView

**Type:** Plain (admin-controlled)  
**Deploy:** `new MarketplaceView(admin, marketplaceCoreAddr)`

Provides rich, aggregated read queries. No state modification.

### Setters (admin only)

```solidity
function setSocialModule(address _social) external onlyAdmin
function setStatisticsModule(address _statistics) external onlyAdmin
```

### Rich Query Functions

```solidity
// Full info about a single NFT
function getNFTFullInfo(uint256 tokenId) external view returns (NFTFullInfo memory)

// Full info for multiple NFTs in one call
function getMultipleNFTs(uint256[] calldata ids) external view returns (NFTFullInfo[] memory)

// User activity summary: XP, levels, trading volumes, royalties earned
function getUserActivitySummary(address user) external view returns (UserActivitySummary memory)

// NFT comments array (from social module)
function getNFTComments(uint256 tokenId) external view returns (Comment[] memory)

// All listed token IDs
function getListedTokenIds() external view returns (uint256[] memory)

// Tokens owned by a user
function getOwnedTokens(address user) external view returns (uint256[] memory)

// Tokens created by a user
function getCreatedTokens(address user) external view returns (uint256[] memory)
```

### NFTFullInfo Struct

```solidity
struct NFTFullInfo {
    NFTMetadata metadata;
    address     owner;
    bool        isListed;
    uint256     price;
    uint256     likeCount;
    uint256     commentCount;
    Offer[]     offers;
}
```

### UserActivitySummary Struct

```solidity
struct UserActivitySummary {
    uint256 totalXP;
    uint8   level;
    uint256 nftsCreated;
    uint32  nftsSold;
    uint32  nftsBought;
    uint256 salesVolume;      // POL earned as seller
    uint256 purchaseVolume;   // POL spent as buyer
    uint256 royaltiesEarned;  // POL earned as creator on secondary sales
}
```

---

## MarketplaceStatistics

**Type:** Plain (admin-controlled)  
**Deploy:** `new MarketplaceStatistics(admin, marketplaceCoreAddr)`

Records sales data and provides analytics.

### Key Functions

```solidity
// Called by Core on every sale
function recordSale(
    address seller,
    address buyer,
    uint256 tokenId,
    uint256 price,
    string calldata category
) external onlyCore

// Analytics
function getCategoryStats(string calldata category) external view returns (CategoryStats memory)
function getDailyVolume(uint256 daysAgo) external view returns (uint256)
function getTotalVolume() external view returns (uint256)
function getTotalSalesCount() external view returns (uint256)
```

### CategoryStats Struct

```solidity
struct CategoryStats {
    uint256 volume;   // Total POL traded in this category
    uint256 sales;    // Number of sales
}
```

---

## MarketplaceSocial

**Type:** Plain (admin-controlled)  
**Deploy:** `new MarketplaceSocial(admin, marketplaceCoreAddr)`

Stores comments and likes per NFT.

### Comment Struct

```solidity
struct Comment {
    address author;
    string  text;
    uint256 timestamp;
}
```

### Key Functions

```solidity
// Called by Core on addComment
function addComment(uint256 tokenId, address author, string calldata text) external onlyCore

// Called by Core on toggleLike
function toggleLike(uint256 tokenId, address user) external onlyCore

// Read
function getComments(uint256 tokenId) external view returns (Comment[] memory)
function getCommentsPaginated(uint256 tokenId, uint256 offset, uint256 limit)
    external view returns (Comment[] memory)
function getCommentCount(uint256 tokenId) external view returns (uint256)
function getLikeCount(uint256 tokenId) external view returns (uint256)
function hasLiked(uint256 tokenId, address user) external view returns (bool)
```

---

## NuxPowerNft

**Type:** Plain  
**Deploy:** `new NuxPowerNft(marketplaceCoreAddr)`  
**Post-deploy:** `setTreasuryAddress(treasuryAddr)`; grant `ADMIN_ROLE` on MarketplaceCore

Mints NFTs that carry NuxPower. Sold through the marketplace. Revenue goes to treasury.

### Key Functions

```solidity
function setTreasuryAddress(address treasury) external onlyOwner
function mintPowerNFT(address to, PowerType powerType, uint96 royaltyPct, string calldata uri)
    external returns (uint256 tokenId)
```

---

## NuxPowerMarketplace

**Type:** Plain  
**Deploy:** `new NuxPowerMarketplace(marketplaceCoreAddr, adminAddr)`

Marketplace-facing integration bridge for power NFT purchases.
