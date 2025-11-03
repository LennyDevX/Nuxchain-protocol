# 🚀 Deployment & Setup Guide

## Prerequisites

```bash
# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your settings:
# - PRIVATE_KEY=your_private_key
# - POLYGON_RPC_URL=https://polygon-rpc.com
# - POLYGONSCAN_API_KEY=your_api_key
```

---

## 📦 Deployment Steps

### Step 1: Deploy EnhancedSmartStaking

```bash
npx hardhat run scripts/DeployEnhancedSmartStaking.cjs --network polygon
```

**Output**: Contract address saved to `deployments/polygon-deployment.json`

**What it does**:
- Deploys staking contract
- Sets owner to deployer
- Sets treasury address
- Verifies on PolygonScan

### Step 2: Deploy GameifiedMarketplace

```bash
npx hardhat run scripts/DeployGameifiedMarketplace.cjs --network polygon
```

**Output**: Marketplace address added to deployment file

**What it does**:
- Deploys marketplace contract
- Connects to staking contract
- Initializes POL token address
- Verifies on PolygonScan

### Step 3: Complete Setup (All in One)

```bash
npx hardhat run scripts/DeployAllContracts.cjs --network polygon
```

**Includes**:
- Deploy both contracts
- Configure interconexion
- Verify addresses
- Save deployment info

---

## ⚙️ Post-Deployment Configuration

### Verify Deployment

```bash
npx hardhat run scripts/ManageContracts.cjs --network polygon -- verify
```

**Checks**:
```
✅ EnhancedSmartStaking
   - Owner address
   - Treasury address
   - Marketplace connected
   - Not paused

✅ GameifiedMarketplace
   - Admin role
   - POL token address
   - Staking contract address
   - Treasury address
   - Not paused

✅ Interconexion
   - Bi-directional communication
   - Address synchronization
```

### Configure Marketplace in Staking

```bash
npx hardhat run scripts/ManageContracts.cjs --network polygon -- configure
```

**Configures**:
- Sets marketplace address in staking
- Uses gas prioritization
- Validates after configuration

### Check Transaction Status

```bash
npx hardhat run scripts/ManageContracts.cjs --network polygon -- check-tx
```

**Shows**:
- Pending transactions
- Current gas prices
- Block information

---

## 💰 Fund Staking Pool

### Add Initial Capital

```bash
npx hardhat run scripts/StakingManagement.cjs --network polygon -- fund 100
```

**Parameters**:
- Amount: In ETH (100 = 100 ETH)
- Transfers ETH to staking contract

### Multiple Deposits

```bash
# Fund with 50 ETH
npx hardhat run scripts/StakingManagement.cjs --network polygon -- fund 50

# Fund with 200 ETH
npx hardhat run scripts/StakingManagement.cjs --network polygon -- fund 200

# Total: 250 ETH in pool
```

---

## 🎮 Initialize Gamification Features

### Create First Quest

```javascript
// Via marketplace admin
const tx = await marketplace.createQuest(
    "Create 3 NFTs",    // title
    3,                  // target count
    25,                 // XP reward
    ethers.parseEther("10") // POL reward
);
await tx.wait();
```

### Create First Achievement

```javascript
const tx = await marketplace.createAchievement(
    "First Creator",
    "Create your first NFT",
    10,
    true // isActive
);
await tx.wait();
```

### Enable Skills

```javascript
// Enable all skill types in staking
const skillTypes = [1, 2, 3, 4, 5, 6, 7];
for (const skillType of skillTypes) {
    await staking.setSkillEnabled(skillType, true);
}
```

---

## 🧪 Test Deployment Locally

### Local Network Testing

```bash
# Start hardhat network
npx hardhat node

# In another terminal, deploy to localhost
npx hardhat run scripts/DeployAllContracts.cjs --network localhost
```

### Run Integration Tests

```bash
# Run all tests
npx hardhat test

# Run specific test
npx hardhat test test/EnhancedSmartStaking.cjs

# With coverage
npx hardhat coverage
```

---

## 📋 Deployment Checklist

```
Pre-Deployment:
☐ Private key in .env
☐ RPC endpoint configured
☐ PolygonScan API key ready
☐ Sufficient gas (1+ POL for fees)

Deployment:
☐ Deploy EnhancedSmartStaking
☐ Verify staking on PolygonScan
☐ Deploy GameifiedMarketplace
☐ Verify marketplace on PolygonScan
☐ Configure interconexion

Post-Deployment:
☐ Verify addresses match deployment file
☐ Fund staking pool
☐ Create initial quests
☐ Create initial achievements
☐ Enable skill types
☐ Set marketplace role in staking
☐ Test basic interactions

Production Ready:
☐ All tests passing
☐ Both contracts verified
☐ Sufficient TVL
☐ Emergency pause working
☐ Documentation updated
```

---

## 🔍 Verify on PolygonScan

### Automatic Verification (During Deployment)

```
✅ Constructor arguments automatically encoded
✅ Source code uploaded
✅ Contract verified within 5-10 minutes
```

### Manual Verification (If Needed)

1. Go to PolygonScan contract page
2. Click "Verify and Publish"
3. Select compiler version: **0.8.28**
4. Select license: **MIT / UNLICENSED**
5. Paste source code
6. Constructor arguments (ABI encoded):

**EnhancedSmartStaking**:
```
(no constructor arguments)
```

**GameifiedMarketplace**:
```
polTokenAddress: 0x455e53cbb86018ac2b8092fdcd39d8444aff00ef
stakingAddress: 0xae57acBf4efE2F6536D992F86145a20e11DB8C3D
stakingTreasuryAddress: 0xad14c117b51735c072d42571e30bf2c729cd9593
```

---

## 💾 Deployment File Structure

**File**: `deployments/polygon-deployment.json`

```json
{
  "network": "polygon",
  "chainId": "137",
  "deployedAt": "2025-11-03T03:20:05.455Z",
  "deployer": "0xed639e84179FCEcE1d7BEe91ab1C6888fbBdD0cf",
  "contracts": {
    "EnhancedSmartStaking": {
      "address": "0xae57acBf4efE2F6536D992F86145a20e11DB8C3D",
      "deployedAt": "2025-11-03T03:20:05.455Z",
      "network": "polygon",
      "verified": true
    },
    "GameifiedMarketplace": {
      "address": "0xB948cC766CBE97Ce822bF4c915D2319fbc48Ad38",
      "deployedAt": "2025-11-03T03:22:43.928Z",
      "network": "polygon",
      "verified": true
    }
  },
  "configuration": {
    "treasury": "0xad14c117b51735c072d42571e30bf2c729cd9593",
    "polToken": "0x455e53cbb86018ac2b8092fdcd39d8444aff00ef"
  }
}
```

---

## 🚨 Troubleshooting

### Issue: Deployment Timeout

**Solution**:
```bash
# Increase timeout in hardhat.config.cjs
networks: {
  polygon: {
    url: process.env.POLYGON_RPC_URL,
    accounts: [process.env.PRIVATE_KEY],
    timeout: 100000,  // 100 seconds
    gas: "auto"
  }
}
```

### Issue: Insufficient Gas

**Solution**:
```bash
# Deploy with explicit gas limit
npx hardhat run scripts/DeployEnhancedSmartStaking.cjs --network polygon
# Check gas prices on PolygonScan first
```

### Issue: Contract Too Large

**Solution**:
- Use contract optimizer
- In `hardhat.config.cjs`:
```javascript
solidity: {
  version: "0.8.28",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
}
```

### Issue: Verification Failed

**Solution**:
```bash
# Manually verify with exact details
npx hardhat verify --network polygon <ADDRESS> \
  "<constructor_arg_1>" "<constructor_arg_2>"

# Or use Polygonscan UI directly
```

---

## 📊 Performance Metrics

### Gas Usage Estimates

```
EnhancedSmartStaking deployment:
├─ Compilation: ~5,455,187 gas
├─ Deployment: ~0.52 ETH (at 102 Gwei)
└─ Verification: ~5 minutes

GameifiedMarketplace deployment:
├─ Compilation: ~5,649,193 gas
├─ Deployment: ~0.52 ETH (at 102 Gwei)
└─ Verification: ~5 minutes

Total: ~1.04 ETH for full deployment
```

### Time Estimates

```
Full Deployment: ~30 minutes
├─ Compilation: ~2 min
├─ Deploy staking: ~3 min
├─ Deploy marketplace: ~3 min
├─ Configuration: ~2 min
└─ PolygonScan verification: ~20 min
```

---

## ✅ Success Indicators

After deployment, you should see:

```
✅ Contract addresses in deployment file
✅ Both contracts verified on PolygonScan
✅ Marketplace can query staking balance
✅ Staking can accept skill notifications
✅ ManageContracts.cjs shows "verify" success
✅ StakingManagement.cjs allows funding
✅ No console errors during operation
```

---

Generated: 2025-11-03  
Version: 1.0.0
