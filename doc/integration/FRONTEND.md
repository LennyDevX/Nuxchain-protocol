# Frontend Integration Guide

How to consume Nuxchain Protocol from an external app such as `nuxchain-app`.

---

## Recommended Approach

The `frontend` folder is now the shared integration boundary for the protocol.

It exposes:

- `abis` for low-level contract interaction
- `config` for generated addresses and network metadata
- `clients` for ready-to-use ethers contract factories

The recommended workflow is:

1. Generate protocol artifacts in this repo
2. Consume the `frontend` package from `nuxchain-app`
3. Instantiate contracts through exported helpers instead of hardcoding ABIs and addresses

---

## Generate Artifacts

After compiling or deploying contracts, regenerate the shared frontend artifacts:

```bash
npm run build:export
```

This produces or refreshes:

- `export/abis/all-abis.json`
- `export/abis/runtime.js`
- `export/config/contracts.generated.json`
- `export/config/contracts.generated.ts`
- `export/config/contracts.generated.js`

If `deployments/complete-deployment.json` exists, generated addresses come from deployment output.
If it does not exist, the generator falls back to `export/config/contracts.config.ts`.

---

## Package Entry Points

The shared package is defined in `export/package.json` and exposes:

- `@nuxchain/protocol-export`
- `@nuxchain/protocol-export/abis`
- `@nuxchain/protocol-export/config`
- `@nuxchain/protocol-export/clients`

Current runtime entrypoints in this repo are:

- `export/index.js`
- `export/abis/runtime.js`
- `export/config/index.js`
- `export/clients/index.js`

Current TypeScript entrypoints are:

- `export/index.ts`
- `export/config/index.ts`
- `export/clients/index.ts`

---

## Install in nuxchain-app

If both repos live on the same machine, you can use a local link or workspace dependency.

Example local file dependency:

```json
{
  "dependencies": {
    "@nuxchain/protocol-export": "file:../nuxchain-protocol/export"
  }
}
```

Then install dependencies in `nuxchain-app`.

---

## Quick Start With Clients

```ts
import { BrowserProvider } from "ethers";
import {
  CONTRACT_ADDRESSES,
  POLYGON_MAINNET,
  createNuxchainClients
} from "@nuxchain/protocol-export";

const provider = new BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

const clients = createNuxchainClients(signer);

const stakingSummary = await clients.stakingViewCore.getUserDeposits(await signer.getAddress());
const treasuryStats = await clients.treasuryManager.getStats();

console.log(POLYGON_MAINNET.chainId, CONTRACT_ADDRESSES.TreasuryManager);
console.log(stakingSummary, treasuryStats);
```

---

## Domain-Specific Clients

### Treasury

```ts
import { BrowserProvider } from "ethers";
import { createTreasuryClient } from "@nuxchain/protocol-export/clients";

const provider = new BrowserProvider(window.ethereum);
const treasury = createTreasuryClient(provider);

const stats = await treasury.getStats();
const reserve = await treasury.getReserveStats();
```

### Staking

```ts
import { JsonRpcProvider } from "ethers";
import { createStakingClients } from "@nuxchain/protocol-export/clients";

const provider = new JsonRpcProvider("https://polygon-rpc.com");
const staking = createStakingClients(provider);

const pool = await staking.stakingViewStats.getPoolStats();
const user = await staking.stakingViewCore.getUserDeposits("0xYourWallet");
```

### Marketplace

```ts
import { JsonRpcProvider } from "ethers";
import { createMarketplaceClients } from "@nuxchain/protocol-export/clients";

const provider = new JsonRpcProvider("https://polygon-rpc.com");
const marketplace = createMarketplaceClients(provider);

const listed = await marketplace.marketplaceView.getListedTokens();
const volume = await marketplace.marketplaceStatistics.totalTradingVolume();
```

---

## Low-Level ABI Usage

If you need direct ABI control instead of client helpers:

```ts
import { Contract, JsonRpcProvider } from "ethers";
import { TreasuryManager } from "@nuxchain/protocol-export/abis";
import { CONTRACT_ADDRESSES } from "@nuxchain/protocol-export/config";

const provider = new JsonRpcProvider("https://polygon-rpc.com");

const treasury = new Contract(
  CONTRACT_ADDRESSES.TreasuryManager,
  TreasuryManager,
  provider
);

const ready = await treasury.isDistributionReady();
```

---

## Addresses and Metadata

The generated config exports `CONTRACT_ADDRESSES` and `WALLET_ADDRESSES`.

```ts
import {
  CONTRACT_ADDRESSES,
  WALLET_ADDRESSES,
  GENERATED_METADATA
} from "@nuxchain/protocol-export/config";

console.log(GENERATED_METADATA.network);
console.log(CONTRACT_ADDRESSES.StakingCore);
console.log(WALLET_ADDRESSES.deployer);
```

`GENERATED_METADATA.source` tells you whether the current addresses came from deployment output or the manual fallback config.

---

## TypeScript Enums and Shared Types

Curated protocol-facing types still come from `contracts.config.ts` and are re-exported through the config entrypoint.

```ts
import {
  SkillType,
  Rarity,
  QuestType,
  ProtocolStatus,
  SKILL_TYPE_NAMES,
  type UserStakingInfo
} from "@nuxchain/protocol-export/config";

const label = SKILL_TYPE_NAMES[SkillType.AUTO_COMPOUND];
```

---

## Network Notes

Initial shared package support is focused on Polygon mainnet.

- `POLYGON_MAINNET` is exported for wallet setup
- Generated addresses currently assume a single active network
- Multi-network manifests should be added later instead of duplicating manual config files

---

## Suggested nuxchain-app Structure

```ts
// src/lib/nuxchain.ts
import { createNuxchainClients } from "@nuxchain/protocol-export/clients";
import { BrowserProvider } from "ethers";

export async function getNuxchainClients() {
  const provider = new BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  return createNuxchainClients(signer);
}
```

Keep protocol imports centralized so future address or ABI changes only need to be updated in one place.

---

## Regeneration Checklist

Run this whenever contracts or addresses change:

```bash
npx hardhat compile
npm run build:export
```

For a deployment flow, prefer:

```bash
npx hardhat run scripts/deploy.cjs --network polygon
npx hardhat run scripts/configure.cjs --network polygon
npx hardhat run scripts/fund.cjs --network polygon
npx hardhat run scripts/verify.cjs --network polygon
npm run build:export
```

---

## Current Limitations

- The package is local to this repo and not yet published to npm
- The generated config is single-network for now
- Additional grouped clients can still be added for social, quests, and dashboard-specific reads
