# Social Contracts

**1 contract - comments, likes, and social quest signals**

---

## Overview

`MarketplaceSocial` stores the lightweight social activity around NFTs.

- likes are tracked per NFT and per user,
- comments are stored on-chain with timestamps,
- social actions can be forwarded to `QuestCore` so they count toward quests.

This module exists mainly to keep `MarketplaceCore` focused on trading rather than community interaction.

```
MarketplaceCore
    └── MarketplaceSocial
          ├── stores likes
          ├── stores comments
          └── optionally notifies QuestCore about social activity
```

## Simple User Flow

1. A user likes an NFT or adds a comment through the marketplace UI.
2. `MarketplaceCore` forwards that action to `MarketplaceSocial`.
3. The social contract updates its own storage.
4. If quests are connected, the action is also reported to `QuestCore`.

---

## MarketplaceSocial

**Type:** Plain (`AccessControl`)  
**Source:** `contracts/Social/MarketplaceSocial.sol`

### Why It Matters

This contract gives the marketplace a simple community layer without forcing the trading contract to hold comment arrays and like-state bookkeeping directly.

### Rules And Limits

| Rule | Value |
|---|---|
| Maximum comments per NFT | 1,000 |
| Comment length | 1 to 500 bytes |
| Who can write | only the marketplace contract |
| Quest reporting | optional, only when `questCore` is configured |

### Key Write Functions

```solidity
function toggleLike(uint256 tokenId, address user) external onlyRole(MARKETPLACE_ROLE)
function addComment(uint256 tokenId, address user, string calldata comment) external onlyRole(MARKETPLACE_ROLE)
```

### Key Read Functions

```solidity
function hasUserLiked(uint256 tokenId, address user) external view returns (bool)
function getLikeCount(uint256 tokenId) external view returns (uint256)
function getComments(uint256 tokenId) external view returns (Comment[] memory)
function getCommentsPaginated(uint256 tokenId, uint256 offset, uint256 limit) external view returns (Comment[] memory)
function getCommentCount(uint256 tokenId) external view returns (uint256)
```

### Admin Wiring

```solidity
function setMarketplaceCore(address newCore) external onlyRole(DEFAULT_ADMIN_ROLE)
function setQuestCore(address questCore_) external onlyRole(DEFAULT_ADMIN_ROLE)
```

### Reader Takeaway

This is not a general-purpose social network contract. It is a thin social layer designed to enrich NFT listings and provide additional actions that quests can track.

---

## Related Pages

- [Marketplace.md](./Marketplace.md) for the main marketplace flow
- [Analytics.md](./Analytics.md) for how likes/comments surface in read models
- [Gamification.md](./Gamification.md) for how social actions feed quests
