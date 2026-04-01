#!/usr/bin/env node

/**
 * Shared export package usage examples.
 */

console.log(`
╔════════════════════════════════════════════════════════════════╗
║  NUXCHAIN EXPORT PACKAGE USAGE                                ║
╚════════════════════════════════════════════════════════════════╝

Recommended workflow:

1. Regenerate package artifacts in this repo
   npm run build:export

2. Consume the shared package from nuxchain-app
   "@nuxchain/protocol-export": "file:../nuxchain-protocol/export"

3. Import addresses, ABIs, or ethers helpers

Examples:

TypeScript client helpers:

import { BrowserProvider } from "ethers";
import { createNuxchainClients } from "@nuxchain/protocol-export";

const provider = new BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const clients = createNuxchainClients(signer);

const treasuryStats = await clients.treasuryManager.getStats();

Low-level ABI usage:

import { Contract, JsonRpcProvider } from "ethers";
import { TreasuryManager } from "@nuxchain/protocol-export/abis";
import { CONTRACT_ADDRESSES } from "@nuxchain/protocol-export/config";

const provider = new JsonRpcProvider("https://polygon-rpc.com");
const treasury = new Contract(CONTRACT_ADDRESSES.TreasuryManager, TreasuryManager, provider);

Available entrypoints:

• @nuxchain/protocol-export
• @nuxchain/protocol-export/abis
• @nuxchain/protocol-export/config
• @nuxchain/protocol-export/clients

Generated files:

• export/abis/all-abis.json
• export/abis/runtime.js
• export/config/contracts.generated.json
• export/config/contracts.generated.ts
• export/config/contracts.generated.js

Notes:

• Generated addresses come from deployments/complete-deployment.json when present
• If no deployment manifest exists, the generator falls back to export/config/contracts.config.ts
• The current package is focused on Polygon mainnet
`);
