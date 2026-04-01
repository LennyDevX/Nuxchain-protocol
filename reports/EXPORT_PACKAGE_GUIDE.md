# 📦 EXPORT PACKAGE - READY TO COPY

**Status**: ✅ **READY FOR nuxchain-app**  
**Location**: `./export/`  
**Size**: ~500KB (all ABIs + config + clients)  
**Can be copied**: YES - Complete, standalone, zero external dependencies

---

## WHAT'S INCLUDED

### 1. ABIs (All Contracts)
- **Format**: JSON compiled ABIs bundled in `all-abis.json`
- **By Category**: Organized in `abis-by-category.json`
- **Runtime Export**: `abis/runtime.js` (zero-overhead, direct usage)
- **TypeScript Definitions**: `abis/index.ts` (full IDE autocomplete)
- **Total ABIs**: 47 contracts

**Includes**:
- SmartStaking suite (7 contracts)
- Marketplace suite (5 contracts)
- Treasury (2 contracts)
- NFT system (10 contracts)
- Gamification & Leveling
- All utility contracts

### 2. On-Chain Configuration
- **Mainnet Addresses**: ALL deployed contract addresses
- **Wallet Addresses**: Deployer + Treasury addresses
- **Chain ID**: 137 (Polygon mainnet)
- **Network**: Polygon (pre-configured)
- **Format**: JSON + TypeScript types

**Deployed Addresses** (pre-configured):
```json
{
  "StakingCore": "0x2cda88046543be25a3EC4eA2d86dBe975Fda0028",
  "MarketplaceProxy": "0xc8Af452F3842805Bc79bfFBBbDB9b130f222d9BC",
  "TreasuryManager": "0x312a3c5072c9DE2aB5cbDd799b3a65fb053DF043",
  "... (20+ more)"
}
```

### 3. Ethers.js Client Helpers
- **createNuxchainClients()**: Main orchestration function
- **createNuxTapClients()**: NuxTap-specific clients
- **Pre-typed**: All contracts strongly typed
- **Zero boilerplate**: Signers/providers auto-wired
- **Ready to use**: Copy, import, call

**Usage Example**:
```typescript
import { createNuxchainClients } from './lib/nuxchain-protocol'

const clients = createNuxchainClients(signer, CONTRACT_ADDRESSES)
const stats = await clients.treasuryManager.getStats()
```

### 4. Types & Enums
- **SkillType**: All power types enumerated
- **AgentCategory**: Agent NFT categories
- **QuestType**: Quest system types
- **Rarity**: NFT rarity levels
- **PowerType**: All power effects

### 5. Documentation
- **USAGE_GUIDE.js**: Copy-paste examples
- **README.md**: Full integration guide
- **package.json**: Metadata + peer dependencies

---

## HOW TO COPY TO nuxchain-app

### Option 1: Direct Copy (Recommended)

```bash
# In your machine (where nuxchain-protocol exists)

# 1. Copy the entire export folder
cp -r export/ /path/to/nuxchain-app/src/lib/nuxchain-protocol

# 2. Update nuxchain-app/package.json (if needed)
# Ensure peer dependency: "ethers": "^6.16.0"

# 3. Start using
# In your frontend code:
import { createNuxchainClients, CONTRACT_ADDRESSES } from './lib/nuxchain-protocol'
```

### Option 2: npm Package (Future)

If you want to publish `@nuxchain/protocol-export` to npm later:

```bash
# In export/ folder
npm publish

# Then in nuxchain-app
npm install @nuxchain/protocol-export
```

---

## VERIFY BEFORE COPYING

✅ **What to check in export/**:

```bash
# Contents you should see:
ls -la export/

abis/
├── all-abis.json          ✅ (size: ~150KB)
├── abis-by-category.json  ✅ (organized)
├── runtime.js             ✅ (JS export)
├── index.ts               ✅ (TS definitions)
└── USAGE_GUIDE.js         ✅ (examples)

clients/
├── index.js               ✅ (ethers helpers)
└── index.ts               ✅ (TS types)

config/
├── contracts.generated.json  ✅ (mainnet addresses)
├── contracts.generated.js    ✅ (JS export)
├── contracts.generated.ts    ✅ (TS definitions)
└── index.js / index.ts       ✅ 

index.js                      ✅ (main entry)
index.ts                      ✅ (TS types)
package.json                  ✅ (metadata)
README.md                     ✅ (guide)
```

**Size check**:
```bash
du -sh export/
# Should be ~500KB
```

---

## REGENERATE EXPORT (if contracts change)

```bash
# At protocol root
npm run build:export

# This will:
# 1. Re-extract ABIs from artifacts/
# 2. Re-generate config from deployments/
# 3. Update all runtime files
# 4. Preserve all types and helpers
```

---

## MINIMAL REQUIREMENTS FOR nuxchain-app

**Node Version**: 18+ (ESM support)  
**Package Manager**: npm 9+ or yarn 3+  
**Dependencies**:
- ethers@^6.16.0 (peer dependency)
- No other dependencies in export package!

**File System**:
- Can go anywhere in your project (e.g., `src/lib/`, `node_modules/`, etc.)
- Keep internal structure intact
- Import only from `index.js` or individual modules

---

## INTEGRATION PATTERN

### Step 1: Copy
```bash
mkdir -p src/lib
cp -r /path/to/nuxchain-protocol/export src/lib/nuxchain-protocol
```

### Step 2: Setup Provider (in your main app file)
```typescript
import { BrowserProvider } from 'ethers'
import { createNuxchainClients, CONTRACT_ADDRESSES } from './lib/nuxchain-protocol'

// Wait for wallet connection
const provider = new BrowserProvider(window.ethereum)
const signer = await provider.getSigner()

// Create clients
const clients = createNuxchainClients(signer, CONTRACT_ADDRESSES)
```

### Step 3: Use in Components
```typescript
// React example
const { data: treasuryStats } = useQuery(
  ['treasury-stats'],
  () => clients.treasuryManager.getStats(),
  { staleTime: 30000 }
)

// Direct usage
const userInfo = await clients.smartStakingCore.getUserInfo(userAddress)
const nfts = await clients.marketplaceCore.getOwnedTokensArray(userAddress)
```

---

## CHECKLIST FOR COPY

- [ ] Verify `export/` folder exists and has all subfolders
- [ ] Check that `export/config/contracts.generated.json` has > 20 addresses
- [ ] Confirm `export/abis/all-abis.json` is ~150KB+
- [ ] Open `export/README.md` and review usage
- [ ] Copy entire `export/` to target app
- [ ] Verify imports work (no "module not found" errors)
- [ ] Test `createNuxchainClients()` initialization
- [ ] Call one simple method (e.g., `getStats()`) to confirm connection

---

## TROUBLESHOOTING

### "ethers not found"
```bash
cd nuxchain-app
npm install ethers@^6.16.0
```

### "Module not found" when importing
- Confirm you copied to correct path
- Check `index.ts` / `index.js` exports exist
- Try clearing node_modules and reinstalling

### "Contract address is undefined"
- Ensure `contracts.generated.json` has your target contract
- Check that chain ID matches (137 for Polygon mainnet)
- Call `CONTRACT_ADDRESSES.ContractName` to debug

### ABIs not loading
- Verify `all-abis.json` exists and is valid JSON
- Check that `runtime.js` properly exports ABI objects
- Try importing directly from `abis/all-abis.json` if helpers fail

---

## REGENERATION SCHEDULE

**Regenerate export/ when**:
- ✅ New contracts deployed (add to addresses)
- ✅ Contract ABIs change (recompile)
- ✅ New helpers needed (edit clients/)
- ✅ Major protocol updates (quarterly review)

**Don't regenerate if**:
- ❌ Only fixing bugs (no ABI changes)
- ❌ Only frontend changes
- ❌ Only script updates

---

**Status**: Ready now  
**Last Built**: March 31, 2026  
**Next Sync**: Before mainnet deployment or after contract upgrade  
