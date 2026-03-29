# Deployment Guide

**Nuxchain Protocol v7.0 — Polygon Mainnet**

---

## Prerequisites

### Environment file (`.env`)

Create a `.env` in the project root with:

```env
# Required
PRIVATE_KEY=0x...                # Deployer wallet private key (must have enough POL for gas)
TREASURY_ADDRESS=0x...           # Protocol owner address that receives dev/ownership funds

# Required for verification
POLYGONSCAN_API_KEY=...

# Optional — fund amounts (defaults shown)
FUND_STAKING=1000                # POL to send to SmartStakingRewards
FUND_LEVELING=1000               # POL to send to LevelingSystem
FUND_QUEST=1000                  # POL to send to QuestRewardsPool
```

### RPC (hardhat.config.cjs)

The config reads `process.env.POLYGON_RPC_URL` for mainnet and `process.env.AMOY_RPC_URL` for testnet. Add them to `.env`:

```env
POLYGON_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY
AMOY_RPC_URL=https://polygon-amoy.g.alchemy.com/v2/YOUR_KEY
```

---

## 5-Step Deployment Process

Each script reads `deployments/complete-deployment.json` written by the previous step.

### Step 1 — Deploy all contracts

```bash
npx hardhat run scripts/deploy.cjs --network polygon
```

**What it does:**
- Phase 0: Deploys `TreasuryManager` + `QuestRewardsPool`
- Phase 1: Deploys all 12 staking contracts (including `SkillViewLib` library and `SmartStakingCoreV2` proxy), wires modules together
- Phase 2: Deploys all 10 marketplace contracts, wires modules together

**Output:**
- `deployments/complete-deployment.json` — all addresses organized by section
- `deployments/addresses.json` — flat key/address map for easy consumption

**Estimated gas:** ~35–50M gas total (~15 POL on mainnet at 30 gwei)

---

### Step 2 — Configure

```bash
npx hardhat run scripts/configure.cjs --network polygon
```

**What it does:**
- Sets Treasury sub-treasury addresses in `TreasuryManager`
- Grants `MARKETPLACE_ROLE` on `LevelingSystem` to `MarketplaceCore`
- Grants `MARKETPLACE_ROLE` on `ReferralSystem` to `MarketplaceCore`
- Authorizes `MarketplaceCore` as revenue source in `TreasuryManager`
- Sets `TreasuryManager` in `CollaboratorBadgeRewards`
- Sets treasury address in `NuxPowerNft`
- Wires `QuestCore` to staking + marketplace

---

### Step 3 — Fund

```bash
npx hardhat run scripts/fund.cjs --network polygon
```

**What it does:**
- Sends POL to `SmartStakingRewards` (reward payout pool)
- Sends POL to `LevelingSystem` (level-up rewards)
- Sends POL to `QuestRewardsPool` (quest prizes)

Controlled by env vars:
```env
FUND_STAKING=1000    # 1000 POL → SmartStakingRewards
FUND_LEVELING=1000   # 1000 POL → LevelingSystem
FUND_QUEST=1000      # 1000 POL → QuestRewardsPool
```

---

### Step 4 — Verify on Polygonscan

```bash
npx hardhat run scripts/verify.cjs --network polygon
```

**What it does:**
- Reads all addresses from `deployments/complete-deployment.json`
- Calls `hardhat verify` for every contract with correct constructor args
- Skips UUPS proxy implementation contracts automatically

---

### Step 5 — Generate frontend integration package

```bash
npm run build:frontend
```

**What it does:**
- Regenerates ABI exports from compiled artifacts
- Generates `frontend/abis/runtime.js` for runtime imports
- Generates `frontend/config/contracts.generated.*` from deployment output when available
- Refreshes the shared frontend package consumed by external apps such as `nuxchain-app`

**Output:**
- `frontend/abis/all-abis.json`
- `frontend/abis/runtime.js`
- `frontend/config/contracts.generated.json`
- `frontend/config/contracts.generated.ts`
- `frontend/config/contracts.generated.js`
- `frontend/package.json` package exports remain the stable consumer boundary

---

## Testnet Deployment (Amoy)

Use `--network amoy` instead of `--network polygon` for all steps:

```bash
npx hardhat run scripts/deploy.cjs --network amoy
npx hardhat run scripts/configure.cjs --network amoy
npx hardhat run scripts/fund.cjs --network amoy
npx hardhat run scripts/verify.cjs --network amoy
npm run build:frontend
```

---

## Post-Deployment Checklist

After all 5 steps complete, verify:

- [ ] `deployments/complete-deployment.json` exists with all addresses
- [ ] `deployments/addresses.json` exists with the flat address map
- [ ] `frontend/config/contracts.generated.json` exists and matches the deployed network
- [ ] `frontend/abis/runtime.js` exists and exports the latest ABI catalog
- [ ] `TreasuryManager.authorizedSources` — SmartStakingCoreV2 and MarketplaceCore are both `true`
- [ ] `SmartStakingCoreV2.rewardsModule()` → SmartStakingRewards address
- [ ] `SmartStakingCoreV2.powerModule()` → SmartStakingPower address
- [ ] `SmartStakingCoreV2.gamificationModule()` → SmartStakingGamification address
- [ ] `MarketplaceCore.statisticsModule()` → MarketplaceStatistics address
- [ ] `MarketplaceCore.viewModule()` → MarketplaceView address
- [ ] `MarketplaceCore.socialModule()` → MarketplaceSocial address
- [ ] `SmartStakingRewards` balance ≥ expected POL
- [ ] `LevelingSystem` balance ≥ expected POL
- [ ] `QuestRewardsPool` balance ≥ expected POL

---

## Upgrading a Contract

For UUPS proxies (`SmartStakingCoreV2`, `MarketplaceCore`, `LevelingSystem`, `ReferralSystem`, `QuestCore`, `CollaboratorBadgeRewards`):

```js
const proxyAddr = "0x...";   // existing proxy address (unchanged)
const NewImpl = await ethers.getContractFactory("MyContractV2");
await upgrades.upgradeProxy(proxyAddr, NewImpl, {
    kind: "uups",
    // if SmartStakingCoreV2, add library:
    // unsafeAllow: ["external-library-linking"]
});
```

The proxy address stays the same. Existing state is preserved.

---

## Module Replacement (non-upgradeable)

For plain contracts (`SmartStakingRewards`, `SmartStakingPower`, etc.):

1. Deploy the new contract
2. Call the setter on the Core:
   - `SmartStakingCoreV2.setRewardsModule(newAddr)`
   - `SmartStakingCoreV2.setPowerModule(newAddr)`
   - `SmartStakingCoreV2.setGamificationModule(newAddr)`
   - `MarketplaceCore.setStatisticsModule(newAddr)`
   - `MarketplaceCore.setViewModule(newAddr)`
   - `MarketplaceCore.setSocialModule(newAddr)`
3. Set back-references in the new module (e.g. `SmartStakingRewards.setCoreStakingContract`)

---

## Deployment Files

| File | Contents |
|---|---|
| `deployments/complete-deployment.json` | All addresses grouped by section; network + timestamp |
| `deployments/addresses.json` | Flat map: `"staking.core" → "0x..."` |
| `frontend/config/contracts.generated.json` | Frontend-safe address manifest used by the shared package |
| `frontend/abis/runtime.js` | Runtime ABI entrypoint for external apps |

Example `addresses.json`:
```json
{
  "treasury.manager": "0x...",
  "treasury.questRewardsPool": "0x...",
  "staking.core": "0x...",
  "staking.rewards": "0x...",
  "staking.power": "0x...",
  "staking.gamification": "0x...",
  "staking.dynamicAPY": "0x...",
  "staking.skillViewLib": "0x...",
  "staking.viewCore": "0x...",
  "staking.viewStats": "0x...",
  "staking.viewSkills": "0x...",
  "staking.viewDashboard": "0x...",
  "marketplace.core": "0x...",
  "marketplace.leveling": "0x...",
  "marketplace.referral": "0x...",
  "marketplace.view": "0x...",
  "marketplace.statistics": "0x...",
  "marketplace.social": "0x...",
  "marketplace.nuxPowerNft": "0x...",
  "marketplace.nuxPowerMarketplace": "0x...",
  "marketplace.questCore": "0x...",
  "marketplace.collaboratorRewards": "0x..."
}
```
