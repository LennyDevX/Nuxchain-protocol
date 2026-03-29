#!/usr/bin/env node

/**
 * Shared frontend package usage examples.
 */

console.log(`
╔════════════════════════════════════════════════════════════════╗
║  NUXCHAIN FRONTEND PACKAGE USAGE                              ║
╚════════════════════════════════════════════════════════════════╝

Recommended workflow:

1. Regenerate package artifacts in this repo
   npm run build:frontend

2. Consume the shared package from nuxchain-app
   "@nuxchain/protocol-frontend": "file:../nuxchain-protocol/frontend"

3. Import addresses, ABIs, or ethers helpers

Examples:

TypeScript client helpers:

import { BrowserProvider } from "ethers";
import { createNuxchainClients } from "@nuxchain/protocol-frontend";

const provider = new BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const clients = createNuxchainClients(signer);

const treasuryStats = await clients.treasuryManager.getStats();

Low-level ABI usage:

import { Contract, JsonRpcProvider } from "ethers";
import { TreasuryManager } from "@nuxchain/protocol-frontend/abis";
import { CONTRACT_ADDRESSES } from "@nuxchain/protocol-frontend/config";

const provider = new JsonRpcProvider("https://polygon-rpc.com");
const treasury = new Contract(CONTRACT_ADDRESSES.TreasuryManager, TreasuryManager, provider);

Available entrypoints:

• @nuxchain/protocol-frontend
• @nuxchain/protocol-frontend/abis
• @nuxchain/protocol-frontend/config
• @nuxchain/protocol-frontend/clients

Generated files:

• frontend/abis/all-abis.json
• frontend/abis/runtime.js
• frontend/config/contracts.generated.json
• frontend/config/contracts.generated.ts
• frontend/config/contracts.generated.js

Notes:

• Generated addresses come from deployments/complete-deployment.json when present
• If no deployment manifest exists, the generator falls back to frontend/config/contracts.config.ts
• The current package is focused on Polygon mainnet
`);
