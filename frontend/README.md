# Nuxchain Protocol Frontend Package

Shared package for consuming Nuxchain Protocol contracts from external apps such as `nuxchain-app`.

## What it exports

- `@nuxchain/protocol-frontend` for the combined surface
- `@nuxchain/protocol-frontend/abis` for raw ABIs
- `@nuxchain/protocol-frontend/config` for generated addresses and shared enums/types
- `@nuxchain/protocol-frontend/clients` for ethers client helpers

## Regenerate package artifacts

From the repository root:

```bash
npm run build:frontend
```

## Example usage

```ts
import { BrowserProvider } from "ethers";
import { createNuxchainClients } from "@nuxchain/protocol-frontend";

const provider = new BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const clients = createNuxchainClients(signer);

const treasuryStats = await clients.treasuryManager.getStats();
```

## Notes

- Generated addresses are sourced from `deployments/complete-deployment.json` when available
- The current package is focused on Polygon mainnet
- Curated shared types still come from `config/contracts.config.ts`