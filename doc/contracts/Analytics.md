# Analytics Contracts

**2 contracts - marketplace statistics and frontend read models**

---

## Overview

These contracts do not move money or transfer NFTs. They exist to make the marketplace understandable.

- `MarketplaceStatistics` records what happened.
- `MarketplaceView` packages that data into shapes that are easier for frontends to consume.

If `MarketplaceCore` is the execution engine, Analytics is the reporting layer built around it.

```
MarketplaceCore
    ├── MarketplaceStatistics  -> records sales, royalties, categories, daily volume
    └── MarketplaceView        -> assembles NFT and user summaries for the UI
```

## Why These Contracts Exist

Without these helpers, every page in the app would need to make many separate calls to `MarketplaceCore` and manually combine the results.

Instead, the marketplace writes raw trading data once, and the read-model contracts expose useful summaries such as:

- total marketplace volume,
- user sales and purchase history,
- category-level activity,
- NFT detail cards with owner, likes, comments, offers, and listing state.

## Typical Flow

1. A sale is executed in `MarketplaceCore`.
2. `MarketplaceStatistics.recordSale()` updates global, user, category, and daily counters.
3. Royalty payouts can be recorded with `recordRoyaltyPayment()`.
4. `MarketplaceView` reads marketplace, social, and statistics modules and returns richer objects for the app.

---

## MarketplaceStatistics

**Type:** Plain (`AccessControl`)  
**Source:** `contracts/Analytics/MarketplaceStatistics.sol`

This contract stores the numbers that describe how the marketplace is performing.

### What It Tracks

| Metric group | Examples |
|---|---|
| Global totals | total NFTs sold, total trading volume, total royalties paid |
| Per-user totals | sales volume, purchase volume, royalties earned, NFTs sold, NFTs bought |
| Category totals | category volume, category sales count |
| Time-based totals | daily volume by day index |

### Key Write Functions

```solidity
function recordSale(
    address seller,
    address buyer,
    uint256 tokenId,
    uint256 price,
    string calldata category
) external onlyRole(MARKETPLACE_ROLE)

function recordRoyaltyPayment(
    address creator,
    uint256 tokenId,
    uint256 royaltyAmount
) external onlyRole(MARKETPLACE_ROLE)
```

### Key Read Functions

```solidity
function totalNFTsSold() external view returns (uint256)
function totalTradingVolume() external view returns (uint256)
function totalRoyaltiesPaid() external view returns (uint256)
function userSalesVolume(address user) external view returns (uint256)
function userPurchaseVolume(address user) external view returns (uint256)
function userRoyaltiesEarned(address user) external view returns (uint256)
function getCategoryStats(string calldata category) external view returns (CategoryStats memory)
function getDailyVolume(uint256 daysAgo) external view returns (uint256)
```

### Reader Takeaway

This contract is useful when the question is "what happened in the marketplace?" rather than "can this NFT be bought right now?"

---

## MarketplaceView

**Type:** Plain (`AccessControl`)  
**Source:** `contracts/Analytics/MarketplaceView.sol`

This contract is the user-facing query layer. It combines data from the marketplace itself, the social module, and the statistics module.

### What It Returns

| Output | Why it matters |
|---|---|
| Full NFT cards | useful for detail pages, listings, and dashboards |
| User activity summaries | useful for profiles and leaderboards |
| Category token lists | useful for browse pages and filters |
| Paginated token lists | useful for scalable frontend loading |

### Key Functions

```solidity
function getNFTFullInfo(uint256 tokenId) external view returns (NFTFullInfo memory)
function getMultipleNFTs(uint256[] calldata ids) external view returns (NFTFullInfo[] memory)
function getUserActivitySummary(address user) external view returns (UserActivitySummary memory)
function getListedTokens() external view returns (uint256[] memory)
function getNFTsByCategory(string memory category) external view returns (uint256[] memory)
function getUserNFTs(address user) external view returns (uint256[] memory)
function getNFTComments(uint256 tokenId) external view returns (Comment[] memory)
```

### Why It Is Separate From MarketplaceCore

The protocol keeps this logic outside the trading contract so the write path stays smaller and the UI can still fetch rich data in fewer calls.

---

## Related Pages

- [Marketplace.md](./Marketplace.md) for the actual trading flow
- [Social.md](./Social.md) for comments and likes
- [Referral.md](./Referral.md) for referral-driven onboarding
