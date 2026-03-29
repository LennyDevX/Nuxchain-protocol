# System Architecture

**Nuxchain Protocol v7.0**

---

## Overview

The protocol is organized in three independently deployable systems that share a common revenue layer:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         NUXCHAIN PROTOCOL v7.0                          │
│                                                                          │
│  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐    │
│  │  SMART STAKING   │   │   MARKETPLACE    │   │   NUXPOWER NFTs  │    │
│  │                  │   │                  │   │                  │    │
│  │  SmartStakingCore│◄──┤  MarketplaceCore │   │  NuxPowerNft     │    │
│  │  Rewards         │   │  LevelingSystem  │   │  SmartStakingPow.│    │
│  │  Power Module    │◄──┤  QuestCore       │   │  NuxPowerMkt     │    │
│  │  Gamification    │   │  Social/Stats/   │   │                  │    │
│  │  View contracts  │   │  View modules    │   │                  │    │
│  └────────┬─────────┘   └────────┬─────────┘   └────────┬─────────┘    │
│           │                      │                       │              │
│           └──────────────────────┼───────────────────────┘              │
│                                  ▼                                       │
│                    ┌─────────────────────────┐                          │
│                    │     TREASURYMANAGER      │                          │
│                    │  Weekly distribution     │                          │
│                    │  20% reserve fund        │                          │
│                    │  5 sub-treasuries        │                          │
│                    └─────────────────────────┘                          │
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
| `SmartStakingCoreV2` | UUPS Proxy | Orchestrator; handles deposits, withdrawals, lockups |
| `SmartStakingRewards` | Plain (Ownable) | APY calculation and reward payouts |
| `SmartStakingPower` | Plain (Ownable) | NFT power activation, rarity multipliers |
| `SmartStakingGamification` | Plain (Ownable) | XP and level tracking for staking actions |
| `DynamicAPYCalculator` | Plain (Ownable) | Optional TVL-based APY adjustment |
| `SmartStakingViewCore` | Plain | Read deposits and balances for a user |
| `SmartStakingViewStats` | Plain | Read pool statistics and APY data |
| `SmartStakingViewSkills` | Plain | Read active powers and user metrics |
| `SmartStakingViewDashboard` | Plain | Full dashboard: all data in one call |

---

### Marketplace (10 contracts)

| Contract | Type | Purpose |
|---|---|---|
| `MarketplaceCore` | UUPS Proxy + ERC721 | Minting, listing, buying, offers, XP system |
| `LevelingSystem` | UUPS Proxy | Level-up rewards (POL payout per level) |
| `ReferralSystem` | UUPS Proxy | Referral tracking and bonus management |
| `MarketplaceView` | Plain | Rich read queries: NFT info, user summaries |
| `MarketplaceStatistics` | Plain | Sales recording; daily and category volume |
| `MarketplaceSocial` | Plain | Comments and likes on NFTs |
| `NuxPowerNft` | Plain | Mints NuxPower NFTs (marketplace-facing) |
| `NuxPowerMarketplace` | Plain | Marketplace integration for power NFTs |
| `QuestCore` | UUPS Proxy | Quest creation, tracking, and completion |
| `CollaboratorBadgeRewards` | UUPS Proxy | Reward distribution to badge holders |

---

## Deployment Groups & Dependencies

Deployment must follow this order (inner deps must exist before outer):

```
Phase 0:  TreasuryManager, QuestRewardsPool
Phase 1:  SmartStakingRewards, SmartStakingPower, SmartStakingGamification,
          DynamicAPYCalculator, SkillViewLib, SmartStakingCoreV2 (links lib),
          ViewCore, ViewStats, ViewSkills, ViewDashboard
Phase 2:  LevelingSystem, ReferralSystem, MarketplaceCore,
          MarketplaceView, MarketplaceStatistics, MarketplaceSocial,
          NuxPowerNft, NuxPowerMarketplace, QuestCore, CollaboratorBadgeRewards
```

---

## Key Data Flows

### Revenue Flow (Staking)

```
user.deposit() → SmartStakingCoreV2
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

---

## Upgrade Pattern

Contracts marked **UUPS Proxy** can be upgraded without changing their address:

```
upgrader → proxy.upgradeTo(newImplementation)
                └─ requires UPGRADER_ROLE
```

Upgradeable contracts: `SmartStakingCoreV2`, `MarketplaceCore`, `LevelingSystem`, `ReferralSystem`, `QuestCore`, `CollaboratorBadgeRewards`.

Non-upgradeable (plain): All module/view contracts, TreasuryManager, QuestRewardsPool. If updated, they get new addresses and Core must call `setXxxModule(newAddr)`.

---

## Role & Access Control

### SmartStakingCoreV2 (Ownable)

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
