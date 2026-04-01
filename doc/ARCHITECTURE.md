# System Architecture

**Nuxchain Protocol v7.0**

---

## Overview

The protocol started around three core systems, but the repository now exposes a broader product surface around them. The easiest way to read the architecture is as a set of connected layers:

- core value loops: Smart Staking, Marketplace, NuxPower, Treasury,
- user progression: levels, quests, referrals, social actions,
- advanced surfaces: auctions, AI Agent NFTs, and NuxTap,
- read models and metadata helpers that make the frontend usable.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         NUXCHAIN PROTOCOL v7.0                          │
│                                                                          │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────────────────┐  │
│  │ SMART STAKING  │  │  MARKETPLACE   │  │  AGENT / NUXTAP LAYER    │  │
│  │ Core           │  │ Core           │  │ Factory / Registry       │  │
│  │ Rewards        │  │ Social / Stats │  │ Rental / Game / Store    │  │
│  │ Power / Views  │  │ Levels / Quest │  │ Agent Market / Treasury  │  │
│  └──────┬─────────┘  └──────┬─────────┘  └────────────┬─────────────┘  │
│         │                   │                         │                │
│         └──────────────┬────┴──────────────┬──────────┘                │
│                        │                   │                           │
│                 ┌──────▼──────┐     ┌──────▼──────┐                    │
│                 │ NUXPOWER    │     │ TREASURY    │                    │
│                 │ NFT Powers  │     │ Revenue hub │                    │
│                 └─────────────┘     └─────────────┘                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Complete Contract Map

### Treasury (2 contracts)

| Contract | Type | Purpose |
|---|---|---|
| `TreasuryManager` | Plain (Ownable) | Central revenue hub; distributes to 5 sub-treasuries weekly |
| `QuestRewardsPool` | Plain (Ownable) | Prize pool for quest completions; funded by TreasuryManager |

---

### Smart Staking (1 library + 11 deployable contracts)

| Contract | Type | Purpose |
|---|---|---|
| `SkillViewLib` | External library | Linked to Core; provides view helper logic |
| `SmartStakingCore` | UUPS Proxy | Orchestrator; handles deposits, withdrawals, lockups |
| `SmartStakingRewards` | Plain (Ownable) | APY calculation and reward payouts |
| `SmartStakingPower` | Plain (Ownable) | NFT power activation, rarity multipliers |
| `SmartStakingGamification` | Plain (Ownable) | XP and level tracking for staking actions |
| `DynamicAPYCalculator` | Plain (Ownable) | Optional TVL-based APY adjustment |
| `SmartStakingViewCore` | Plain | Read deposits and balances for a user |
| `SmartStakingViewStats` | Plain | Read pool statistics and APY data |
| `SmartStakingViewSkills` | Plain | Read active powers and user metrics |
| `SmartStakingViewDashboard` | Plain | Full dashboard: all data in one call |

---

### Marketplace Core (6 contracts)

| Contract | Type | Purpose |
|---|---|---|
| `MarketplaceCore` | UUPS Proxy + ERC721 | Minting, listing, buying, offers, XP system |
| `LevelingSystem` | UUPS Proxy | Level-up rewards (POL payout per level) |
| `NuxPowerNft` | Plain | Mints NuxPower NFTs (marketplace-facing) |
| `NuxPowerMarketplace` | Plain | Marketplace integration for power NFTs |
| `QuestCore` | UUPS Proxy | Quest creation, tracking, and completion |
| `CollaboratorBadgeRewards` | UUPS Proxy | Reward distribution to badge holders |

---

### Marketplace Support Modules (4 contracts)

| Contract | Type | Purpose |
|---|---|---|
| `MarketplaceStatistics` | Plain | Records sales volume, royalties, category totals, and daily totals |
| `MarketplaceView` | Plain | Aggregates NFT and user views for frontends |
| `MarketplaceSocial` | Plain | Stores likes/comments and forwards social actions to quests |
| `ReferralSystem` | UUPS Proxy | Manages referral codes, first-purchase discounts, and referral XP |

---

### Auction (1 contract)

| Contract | Type | Purpose |
|---|---|---|
| `NuxAuctionMarketplace` | UUPS Proxy | Runs English, Dutch, and sealed-bid auctions for agent NFTs |

---

### AI Agent NFTs (7 contracts)

| Contract | Type | Purpose |
|---|---|---|
| `NuxAgentNFTBase` | UUPS base | Base ERC-721 agent implementation with ERC-6551, royalties, and agent config storage |
| `NuxAgentFactory` | UUPS Proxy | User-facing minting router with category templates |
| `NuxAgentRegistry` | UUPS Proxy | Identity, reputation, validation, and operational profile registry |
| `NuxAgentPaymaster` | UUPS Proxy | Payment and spend-control helper for agent activity |
| `NuxAgentRental` | UUPS Proxy | Time-based rental market for agent NFTs |
| `NuxAgentView` | Plain | Read-only helper for agent collection and token views |
| `NuxAgentMiniGame` | UUPS Proxy | Task execution surface used by quests and agent progression |

---

### NuxTap (4 contracts)

| Contract | Type | Purpose |
|---|---|---|
| `NuxTapGame` | UUPS Proxy | Tap-to-earn gameplay loop with streaks, levels, and linked agents |
| `NuxTapItemStore` | UUPS Proxy | ERC-1155 store for boosters, auto-tap items, withdraw passes, and agent inventory |
| `NuxTapTreasury` | UUPS Proxy | Dedicated reward-liquidity treasury for NuxTap |
| `NuxTapAgentMarketplace` | UUPS Proxy | Secondary market for supported AI Agent NFTs inside NuxTap |

---

### XP Metadata (1 contract)

| Contract | Type | Purpose |
|---|---|---|
| `XPSourceMetadata` | Plain | Read-only labels, descriptions, icons, and relative weights for XP sources |

---

## Deployment Groups & Dependencies

Deployment must follow this order (inner deps must exist before outer):

```
Phase 0:  TreasuryManager, QuestRewardsPool
Phase 1:  SmartStakingRewards, SmartStakingPower, SmartStakingGamification,
          DynamicAPYCalculator, SkillViewLib, SmartStakingCore (links lib),
          ViewCore, ViewStats, ViewSkills, ViewDashboard
Phase 2:  LevelingSystem, ReferralSystem, MarketplaceCore,
          MarketplaceView, MarketplaceStatistics, MarketplaceSocial,
          NuxPowerNft, NuxPowerMarketplace, QuestCore, CollaboratorBadgeRewards

Extended modules such as auctions, agent NFTs, and NuxTap can be deployed as separate surfaces once treasury, progression hooks, and any required NFT contracts are available.
```

---

## Key Data Flows

### Revenue Flow (Staking)

```
user.deposit() → SmartStakingCore
                     └─ 6% commission → TreasuryManager.receiveRevenue()
                           └─ weekly → sub-treasuries (Rewards/Staking/Collaborators/Dev)
```

### Revenue Flow (Marketplace)

```
user.buyToken() → MarketplaceCore
                     ├─ royalty → creator (if secondary sale)
                     ├─ 6% → TreasuryManager.receiveRevenue()
                     └─ remainder → seller
```

### NFT Power Activation

```
user activates NuxPower NFT in Marketplace
  → MarketplaceCore → SmartStakingPower.notifyPowerActivation()
       └─ rarity multiplier applied to user's power profile
            └─ SmartStakingRewards reads powers on next reward claim
```

### XP & Leveling (Marketplace)

```
Action → MarketplaceCore._addXP(user, amount)
              └─ totalXP += amount (capped at 5000)
              └─ level = sqrt(totalXP / 100) (capped at 50)
              └─ if LevelUp → emit LevelUp + call LevelingSystem.rewardLevelUp()
```

### Agent Mint / Registry Flow

```
user.mintAgent() → NuxAgentFactory
                    └─ category NFT contract mints token
                    └─ NuxAgentNFTBase deploys ERC-6551 account
                    └─ NuxTap treasury receives mint fee
                    └─ registry can store operational metadata
```

### NuxTap Reward Flow

```
player taps / uses items → NuxTapGame
                           ├─ score and unclaimed rewards updated
                           ├─ reward liquidity reserved in NuxTapTreasury
                           └─ claimRewards() pulls payout from NuxTapTreasury
```

---

## Upgrade Pattern

Contracts marked **UUPS Proxy** can be upgraded without changing their address:

```
upgrader → proxy.upgradeTo(newImplementation)
                └─ requires UPGRADER_ROLE
```

Upgradeable contracts: `SmartStakingCore`, `MarketplaceCore`, `LevelingSystem`, `ReferralSystem`, `QuestCore`, `CollaboratorBadgeRewards`.

Non-upgradeable (plain): All module/view contracts, TreasuryManager, QuestRewardsPool. If updated, they get new addresses and Core must call `setXxxModule(newAddr)`.

---

## Role & Access Control

### SmartStakingCore (Ownable)

| Who | Can do |
|---|---|
| Owner | Set modules, pause, set treasury, upgrade |
| Authorized marketplace | Call `notifyPowerActivation/Deactivation` |

### MarketplaceCore (AccessControl)

| Role | Holders | Can do |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` | Deployer | Grant/revoke roles |
| `ADMIN_ROLE` | Deployer, NuxPowerNft, QuestCore | Set modules, pause |
| `UPGRADER_ROLE` | Deployer | Call `upgradeTo` |

### TreasuryManager (Ownable)

| Who | Can do |
|---|---|
| Owner | Set treasuries, allocations, emergency |
| Authorized sources | Call `receiveRevenue()` |
| Authorized requesters | Call `requestRewardFunds()` |

---

## Network Configuration

| Parameter | Value |
|---|---|
| Network | Polygon Mainnet |
| Chain ID | 137 |
| EVM version | shanghai |
| Solidity | 0.8.28 |
| Optimizer | viaIR, runs: 1 (Core/Marketplace), runs: 200 (rest) |
| Proxy standard | ERC-1967 UUPS |
