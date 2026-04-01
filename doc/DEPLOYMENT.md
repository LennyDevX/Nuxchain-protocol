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

# Optional — NFT suite deployment
NUXAGENT_ERC6551_IMPL=0x...      # Optional external ERC-6551 account implementation override
NUXAGENT_VALIDATOR=0x...         # Default validator for NuxAgentMiniGame (defaults to deployer)
NUXAGENT_MINT_FEE=0.01           # Default mint fee for all category NFT proxies
NUXAGENT_SOCIAL_MINT_FEE=0.01    # Optional per-category override
NUXAGENT_TECH_MINT_FEE=0.02
NUXAGENT_MARKETING_MINT_FEE=0.01
NUXAGENT_FINANCE_MINT_FEE=0.02
NUXAGENT_BUSINESS_MINT_FEE=0.01
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
- Phase 1: Deploys all 12 staking contracts (including `SkillViewLib` library and `SmartStakingCore` proxy), wires modules together
- Phase 2: Deploys all 10 marketplace contracts, wires modules together
- Phase 3: Deploys or reuses an ERC-6551 account implementation, deploys the full stateful NFT suite behind UUPS proxies (`NuxAgentRegistry`, `NuxAgentFactory`, `NuxAgentPaymaster`, `NuxAgentRental`, `NuxAgentMiniGame`, and all 5 category NFT contracts), wires roles and registry/rental support, then deploys plain `NuxAgentView`

**Output:**
- `deployments/complete-deployment.json` — all addresses organized by section
- `deployments/deployment-in-progress.json` — rolling checkpoint written during the run and deleted on successful completion
- `deployments/addresses.json` — flat key/address map for easy consumption
- `deployments/complete-deployment.json > proxyMetadata` — proxy address, implementation address, initializer args hash, and designated upgrader holder for every UUPS deployment

**Estimated gas:** ~50–70M gas total depending on NFT suite deployment and current base fee

**Resume behavior:**
- If the deploy is interrupted, rerunning `npx hardhat run scripts/deploy.cjs --network polygon` resumes from `deployments/deployment-in-progress.json` and reuses already deployed addresses.

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
- Applies the ERC-6551 implementation from env when provided, otherwise uses the implementation recorded during deployment

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
- Calls `hardhat verify` for every plain contract with correct constructor args
- Reads EIP-1967 implementation slots for every deployed UUPS contract and verifies the implementations for staking, marketplace, treasury, and NFT proxies

---

### Step 5 — Generate frontend integration package

```bash
npm run build:export
```

**What it does:**
- Regenerates ABI exports from compiled artifacts
- Generates `export/abis/runtime.js` for runtime imports
- Generates `export/config/contracts.generated.*` from deployment output when available
- Refreshes the shared frontend package consumed by external apps such as `nuxchain-app`

**Output:**
- `export/abis/all-abis.json`
- `export/abis/runtime.js`
- `export/config/contracts.generated.json`
- `export/config/contracts.generated.ts`
- `export/config/contracts.generated.js`
- `export/package.json` package exports remain the stable consumer boundary

---

## Testnet Deployment (Amoy)

Use `--network amoy` instead of `--network polygon` for all steps:

```bash
npx hardhat run scripts/deploy.cjs --network amoy
npx hardhat run scripts/configure.cjs --network amoy
npx hardhat run scripts/fund.cjs --network amoy
npx hardhat run scripts/verify.cjs --network amoy
npm run build:export
```

---

## Post-Deployment Checklist

After all 5 steps complete, verify:

- [ ] `deployments/complete-deployment.json` exists with all addresses
- [ ] `deployments/deployment-in-progress.json` has been removed after successful completion
- [ ] `deployments/addresses.json` exists with the flat address map
- [ ] `export/config/contracts.generated.json` exists and matches the deployed network
- [ ] `export/abis/runtime.js` exists and exports the latest ABI catalog
- [ ] `TreasuryManager.authorizedSources` — SmartStakingCore and MarketplaceCore are both `true`
- [ ] `SmartStakingCore.rewardsModule()` → SmartStakingRewards address
- [ ] `SmartStakingCore.powerModule()` → SmartStakingPower address
- [ ] `SmartStakingCore.gamificationModule()` → SmartStakingGamification address
- [ ] `MarketplaceCore.statisticsModule()` → MarketplaceStatistics address
- [ ] `MarketplaceCore.viewModule()` → MarketplaceView address
- [ ] `MarketplaceCore.socialModule()` → MarketplaceSocial address
- [ ] `NuxAgentFactory.agentRegistry()` → NuxAgentRegistry address
- [ ] `NuxAgentRental.agentRegistry()` → NuxAgentRegistry address
- [ ] `NuxAgentMiniGame.agentRegistry()` → NuxAgentRegistry address
- [ ] `NuxAgentMiniGame.treasuryManager()` → TreasuryManager address
- [ ] Every category NFT proxy grants `FACTORY_ROLE` to `NuxAgentFactory`
- [ ] Every category NFT proxy grants `REGISTRY_ROLE` to `NuxAgentRegistry`
- [ ] Every category NFT proxy grants `RENTAL_ROLE` to `NuxAgentRental`
- [ ] `NuxAgentRegistry.registeredNFTContracts(categoryProxy)` → `true` for all 5 categories
- [ ] Every category NFT proxy has `erc6551Implementation()` set before any agent mint occurs
- [ ] `SmartStakingRewards` balance ≥ expected POL
- [ ] `LevelingSystem` balance ≥ expected POL
- [ ] `QuestRewardsPool` balance ≥ expected POL

---

## Upgrading a Contract

Only contracts deployed behind a UUPS proxy can be upgraded without changing address.
If a contract was deployed directly as a plain implementation, preserving the same address later is not possible.

### Recommended Script

Use the dedicated upgrade script for any deployed UUPS proxy, including the NuxTap suite and future NFT proxies:

```bash
npm run upgrade:uups -- --network polygon -- --contract NuxTapGame --key nuxtap.game
```

Examples:

```bash
# Upgrade a known proxy from deployments/complete-deployment.json
npm run upgrade:uups -- --network polygon -- --contract NuxTapTreasury --key nuxtap.treasury

# Upgrade by explicit address
npm run upgrade:uups -- --network polygon -- --contract NuxAgentRegistry --proxy 0xYourProxy

# Upgrade a proxy that links libraries
npm run upgrade:uups -- --network polygon -- --contract SmartStakingCore --key staking.core --unsafe-linked-libraries

# Upgrade and run a post-upgrade reinitializer
npm run upgrade:uups -- --network polygon -- --contract MyContractV2 --proxy 0xYourProxy --call initializeV2 --call-args '["arg1",123]'
```

What the script does:

- Resolves the proxy from `--key` or `--proxy`
- Validates upgrade compatibility with the OpenZeppelin Upgrades plugin
- Executes `upgradeProxy(..., { kind: "uups" })`
- Optionally executes one post-upgrade function such as a `reinitializer`
- Appends the result to `deployments/upgrade-history.json`

### Low-Level Hardhat Example

```js
const proxyAddr = "0x...";
const NewImpl = await ethers.getContractFactory("MyContractV2");
await upgrades.upgradeProxy(proxyAddr, NewImpl, {
    kind: "uups",
    // if linked libraries are used:
    // unsafeAllowLinkedLibraries: true,
});
```

The proxy address stays the same. Existing state is preserved.

### Proxy-First Rule for Mainnet

For contracts that must keep a stable address on mainnet, deploy them behind UUPS proxies from day one.
This applies to stateful NuxTap and NFT contracts. Stateless helpers such as `NuxAgentView` can remain plain.

---

## Module Replacement (non-upgradeable)

For plain contracts (`SmartStakingRewards`, `SmartStakingPower`, etc.):

1. Deploy the new contract
2. Call the setter on the Core:
  - `SmartStakingCore.setRewardsModule(newAddr)`
  - `SmartStakingCore.setPowerModule(newAddr)`
  - `SmartStakingCore.setGamificationModule(newAddr)`
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
| `deployments/complete-deployment.json > proxyMetadata` | UUPS proxy metadata including implementation address and initializer args hash |
| `export/config/contracts.generated.json` | Frontend-safe address manifest used by the shared package |
| `export/abis/runtime.js` | Runtime ABI entrypoint for external apps |

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
