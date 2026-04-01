# XP Metadata Contracts

**1 contract - labels, descriptions, and weights for XP sources**

---

## Overview

`XPSourceMetadata` is a helper contract for frontends and admin tools.

It does not award XP by itself. Instead, it explains what the XP sources mean so the UI does not need to hard-code labels, icons, categories, and descriptive text.

This makes it easier to build dashboards that answer questions like:

- where did a user's XP come from,
- which activities are premium or basic,
- how should a source be labeled in the UI.

---

## XPSourceMetadata

**Type:** Plain  
**Source:** `contracts/Xp/XPSourceMetadata.sol`

### What It Stores Per XP Source

| Field | Meaning |
|---|---|
| `label` | human-readable action name |
| `icon` | UI icon string |
| `category` | activity family |
| `description` | short tooltip text |
| `multiplierBps` | relative importance expressed in basis points |
| `baseXP` | typical baseline XP amount |

### Multiplier Semantics

`multiplierBps` is informational.

- `10000` means 1x, or no bonus,
- values above `10000` mean a more valuable action,
- values below `10000` mean a lighter-weight action.

The actual XP logic still lives in the modules that award XP. This contract exists to explain those sources consistently.

### Source Catalog

| Source | Category | Base XP | Weight |
|---|---|---:|---:|
| Buy NFT | Marketplace | 15 | 10000 |
| Sell NFT | Marketplace | 20 | 10000 |
| Create NFT | Marketplace | 10 | 10000 |
| Mint AI Agent | Agent NFT | 50 | 15000 |
| Upgrade Agent | Agent NFT | 20 | 10000 |
| Complete Task | Agent NFT | 10 | 10000 |
| Stake POL | Smart Staking | 1 per 2 POL | 5000 |
| Compound Rewards | Smart Staking | 3 | 10000 |
| Complete Quest | Quests | 25 typical | 10000 |
| Achievement | Quests | 100 | 20000 |
| Place Bid | Auction | 10 | 10000 |
| Win Auction | Auction | 100 | 20000 |
| Buy NuxPower | Agent NFT | 30 | 10000 |
| Referral | Social | 50 | 15000 |
| Social Action | Social | 5 | 5000 |

### Key Functions

```solidity
function getSourceMetadata(uint8 source) external view returns (SourceMeta memory)
function getAllSourceMetadata() external view returns (SourceMeta[15] memory)
function getSourceLabel(uint8 source) external view returns (string memory)
function getSourceCategory(uint8 source) external view returns (string memory)
function getSourceMultiplier(uint8 source) external view returns (uint16)
function getAllCategories() external pure returns (string[5] memory)
```

### Reader Takeaway

Use this page when you want to understand the meaning of XP labels across the protocol, not when you want to understand who awards XP in the first place.

---

## Related Pages

- [Marketplace.md](./Marketplace.md)
- [Gamification.md](./Gamification.md)
- [Auction.md](./Auction.md)
- [NFTAgents.md](./NFTAgents.md)
