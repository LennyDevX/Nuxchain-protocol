# Nuxchain Protocol — Technical Documentation

**Version 7.0 · Solidity 0.8.28 · Polygon (chainId 137)**

---

## What is Nuxchain Protocol?

Nuxchain is an on-chain DeFi + NFT ecosystem built on Polygon. It combines three interconnected pillars:

| Pillar | What it does |
|---|---|
| **Smart Staking** | Users deposit POL and earn dynamic APY rewards. NFT Powers boost yields. |
| **NFT Marketplace** | Users mint, trade, and collect NFTs. Trading earns XP and levels up user profiles. |
| **NuxPower System** | Special NFTs that grant permanent on-chain powers (APY boosts, fee reductions, access rights). |

All revenue flows through a central **TreasuryManager** that distributes funds weekly to staking rewards, collaborators, and development.

---

## Documentation Index

| File | Description |
|---|---|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Full system overview, contract map, data flows |
| [DEPLOYMENT.md](./DEPLOYMENT.md) | Deploy workflow: 4-step process from zero to live |
| [contracts/SmartStaking.md](./contracts/SmartStaking.md) | All 12 staking contracts: core, modules, views |
| [contracts/Marketplace.md](./contracts/Marketplace.md) | All 10 marketplace contracts: core, modules, social |
| [contracts/Treasury.md](./contracts/Treasury.md) | TreasuryManager + QuestRewardsPool |
| [contracts/NuxPower.md](./contracts/NuxPower.md) | NuxPowerNFT + PowerType enum + SmartStakingPower |
| [contracts/Gamification.md](./contracts/Gamification.md) | LevelingSystem, QuestCore, CollaboratorBadgeRewards |
| [integration/FRONTEND.md](./integration/FRONTEND.md) | ABI usage, key read calls, ethers.js patterns |
| [integration/REWARDS.md](./integration/REWARDS.md) | APY formula, XP system, treasury flow details |

---

## Quick Start

### Prerequisites

- Node.js 18+
- A `.env` file with:

```env
PRIVATE_KEY=0x...          # Deployer wallet private key
TREASURY_ADDRESS=0x...     # Address to receive dev/owner fees
POLYGONSCAN_API_KEY=...    # For contract verification
```

### Install & Test

```bash
npm install
npx hardhat compile
npx hardhat test           # 623 tests — all must pass
```

### Deploy (4 steps)

```bash
# 1. Deploy all ~23 contracts
npx hardhat run scripts/deploy.cjs --network polygon

# 2. Post-deploy wiring and configuration
npx hardhat run scripts/configure.cjs --network polygon

# 3. Fund reward contracts with POL
npx hardhat run scripts/fund.cjs --network polygon

# 4. Verify on Polygonscan
npx hardhat run scripts/verify.cjs --network polygon
```

See [DEPLOYMENT.md](./DEPLOYMENT.md) for full details.

---

## Contract Count

| System | Deployable contracts |
|---|---|
| Treasury | 2 |
| Smart Staking | 12 (1 library + 11 deployable) |
| Marketplace | 10 |
| **Total** | **24** |

---

## Key Numbers

| Parameter | Value |
|---|---|
| Platform fee (staking & marketplace) | 6% |
| Max marketplace offers per NFT | 50 |
| Max NFT level (marketplace XP) | 50 |
| Max staking deposits per user | 400 |
| Min deposit | 10 POL |
| Max deposit | 100,000 POL |
| Base APY (no lock) | 8.60% |
| Base APY (365-day lock) | 25.50% |
| Treasury reserve allocation | 20% of all revenue |
| Treasury distribution interval | Every 7 days |
