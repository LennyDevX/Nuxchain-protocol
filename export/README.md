# Nuxchain Protocol Export Package

Shared package for consuming Nuxchain Protocol contracts from external apps such as `nuxchain-app`.

## Copy into another app

If you want to move this folder directly into `nuxchain-app`, copy the whole `export/` directory and keep its internal structure unchanged.

Minimum requirements in the target app:

- `ethers@^6.16.0`
- ESM support

Recommended flow:

1. Copy `export/` into your app, for example as `src/lib/nuxchain-protocol`
2. Keep `abis/`, `clients/`, `config/`, `index.js`, `index.ts`, and `package.json` together
3. Import from the copied folder path

Example using a copied local folder:

```ts
import { BrowserProvider } from "ethers";
import {
	CONTRACT_ADDRESSES,
	POLYGON_MAINNET,
	SkillType,
	createNuxchainClients,
	createNuxTapClients
} from "../lib/nuxchain-protocol/index.js";

const provider = new BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

const coreClients = createNuxchainClients(signer, CONTRACT_ADDRESSES);
// Only call this if your copied config includes deployed NuxTap addresses.
const nuxTapClients = createNuxTapClients(signer, {
	...CONTRACT_ADDRESSES,
	NuxTapGame: "0x...",
	NuxTapAgentMarketplace: "0x...",
	NuxTapStore: "0x...",
	NuxTapTreasury: "0x..."
});

const treasuryStats = await coreClients.treasuryManager.getStats();
console.log(POLYGON_MAINNET.chainName, SkillType.AUTO_COMPOUND, treasuryStats);
console.log(nuxTapClients.nuxTapGame.target);

if (coreClients.nuxAgentView) {
	const agentView = await coreClients.nuxAgentView.getAgentView("0xYourAgentNFT", 1n);
	console.log(agentView);
}
```

## What it exports

- `@nuxchain/protocol-export` for the combined surface
- `@nuxchain/protocol-export/abis` for raw ABIs
- `@nuxchain/protocol-export/config` for generated addresses and shared enums/types
- `@nuxchain/protocol-export/clients` for ethers client helpers

## Regenerate package artifacts

From the repository root:

```bash
npm run build:export
```

## Example usage

```ts
import { BrowserProvider } from "ethers";
import { createNuxchainClients } from "@nuxchain/protocol-export";

const provider = new BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const clients = createNuxchainClients(signer);

const treasuryStats = await clients.treasuryManager.getStats();
```

## Notes

- Generated addresses are sourced from `deployments/complete-deployment.json` when available
- `NuxAgentView` is exported as an optional address/client because older deployments may not include it yet
- The current package is focused on Polygon mainnet
- Curated shared types still come from `config/contracts.config.ts`
- The JS runtime surface now matches the TS surface for exported config values and NuxTap clients