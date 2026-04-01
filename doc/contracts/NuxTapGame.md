# NuxTap Game Contracts

**4 contracts - tap gameplay, item economy, reward treasury, and agent trading**

---

## Overview

NuxTap is a separate game-like surface inside the repository. It mixes a tap-to-earn loop with item boosts, linked agent bonuses, a dedicated treasury, and an agent marketplace.

```
NuxTapGame
    ├── NuxTapItemStore        -> sells boosts, auto-tap items, withdraw passes, and agent inventory
    ├── NuxTapTreasury         -> holds reward liquidity and pays claims
    └── NuxTapAgentMarketplace -> secondary sales for supported agent NFTs
```

## Plain-Language Player Loop

1. A player taps manually and can accumulate passive taps through items.
2. Items from the store can increase auto-tap rate, boost rewards, or waive claim fees.
3. A linked agent NFT can improve rewards based on its profile.
4. Rewards accumulate as `unclaimedRewards` inside the game profile.
5. Claims are paid from `NuxTapTreasury`, subject to treasury limits.

---

## NuxTapGame

**Type:** UUPS Proxy  
**Source:** `contracts/NuxTapGame/NuxTapGame.sol`

This is the gameplay engine.

### What It Tracks Per Player

| Field group | Examples |
|---|---|
| Progress | total score, current level, streak, best streak |
| Activity | lifetime taps, total sessions, daily tap count |
| Rewards | unclaimed rewards, claimed rewards |
| Boosts | auto-tap rate, booster multiplier, booster expiry |
| Agent link | linked NFT contract and token ID |

### Default Game Parameters

| Parameter | Default |
|---|---|
| Reward per tap | 0.00001 ether |
| Base daily tap cap | 5,000 |
| Max manual taps per session | 1,000 |
| Passive tick interval | 300 seconds |
| Claim fee | 500 bps (5%) |

### Key Functions

```solidity
function linkAgent(address nftContract, uint256 tokenId) external
function unlinkAgent() external
function applyAutoTapItem(uint256 itemId) external
function activateBooster(uint256 itemId) external
function settleTapSession(uint256 manualTaps) external
function claimRewards(uint256 amount, uint256 withdrawPassItemId) external
function getPlayerProfile(address account) external view returns (PlayerProfile memory)
function previewPendingPassiveTaps(address account) external view returns (uint256)
```

### Reader Takeaway

This contract answers the question: "how does moment-to-moment NuxTap gameplay turn into score and claimable rewards?"

---

## NuxTapItemStore

**Type:** UUPS Proxy (`ERC1155`)  
**Source:** `contracts/NuxTapGame/NuxTapItemStore.sol`

This store sells the consumables and inventory that change gameplay.

### Supported Item Kinds

| Kind | Purpose |
|---|---|
| `AUTO_TAP` | increases passive tap production |
| `BOOSTER` | increases reward multiplier for a duration |
| `WITHDRAW_PASS` | removes claim fee when used |
| `AGENT_NFT` | sells agent NFT inventory held by the store |

### Key Functions

```solidity
function configureItem(...) external onlyRole(ADMIN_ROLE)
function depositAgentInventory(uint256 itemId, uint256 tokenId) external onlyRole(ADMIN_ROLE)
function purchaseItem(uint256 itemId, uint256 quantity) external payable
function consumeItem(address account, uint256 itemId, uint256 amount) external onlyRole(GAME_ROLE)
function getItemConfig(uint256 itemId) external view returns (...)
```

---

## NuxTapTreasury

**Type:** UUPS Proxy  
**Source:** `contracts/NuxTapGame/NuxTapTreasury.sol`

This treasury is separate from the main protocol treasury. It is focused on the NuxTap economy.

### What It Manages

| Function | Meaning |
|---|---|
| reward liquidity | the pool used to pay gameplay rewards |
| reserved liquidity | rewards promised but not yet claimed |
| single payout cap | safety limit per claim |
| daily payout cap | safety limit across a day |

### Key Functions

```solidity
function depositRevenue(string calldata revenueType) external payable onlyRole(STORE_ROLE)
function fundRewards(string calldata source) external payable onlyRole(TREASURER_ROLE)
function reserveLiquidity(uint256 amount) external onlyRole(GAME_ROLE)
function releaseReservedLiquidity(uint256 amount) external onlyRole(GAME_ROLE)
function payReward(address recipient, uint256 grossAmount, uint256 feeAmount, string calldata reason) external onlyRole(GAME_ROLE)
function getTreasuryStats() external view returns (...)
function availableLiquidity() public view returns (uint256)
```

---

## NuxTapAgentMarketplace

**Type:** UUPS Proxy  
**Source:** `contracts/NuxTapGame/NuxTapAgentMarketplace.sol`

This is a dedicated market for supported AI Agent NFTs inside the NuxTap ecosystem.

### How It Works

1. Seller lists an approved supported agent NFT.
2. Buyer pays the listed price.
3. The contract transfers the NFT, pays seller proceeds, pays royalties if present, and routes the platform fee to NuxTap treasury.

### Default Economics

| Parameter | Default |
|---|---|
| Platform fee | 500 bps (5%) |
| Maximum admin-set fee | 1500 bps (15%) |

### Key Functions

```solidity
function listAgent(address nftContract, uint256 tokenId, uint256 price) external returns (uint256 listingId)
function cancelListing(uint256 listingId) external
function updateListingPrice(uint256 listingId, uint256 newPrice) external
function buyAgent(uint256 listingId) external payable
function setSupportedNFTContract(address nftContract, bool supported) external onlyRole(ADMIN_ROLE)
```

---

## Related Pages

- [NFTAgents.md](./NFTAgents.md) for the underlying agent asset system
- [Treasury.md](./Treasury.md) for the main protocol treasury model
