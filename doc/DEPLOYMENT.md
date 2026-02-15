# 🚀 Smart Deployment Guide

**Automated contract deployment system for Nuxchain Protocol** | [← Back to doc](../doc)

---

## 📋 Quick Start

```bash
# Install dependencies
npm install

# Run smart deployment (auto-detects changes)
npx hardhat run scripts/DeploySmartV2.cjs --network polygon

# Deploy to specific network
npx hardhat run scripts/DeploySmartV2.cjs --network polygon
npx hardhat run scripts/DeploySmartV2.cjs --network mumbai
```

---

## ✨ Features

### Smart Change Detection
- ✅ Analyzes git log to find modified contracts
- ✅ Fallback to filesystem timestamps if git unavailable
- ✅ Groups contracts by category (staking, marketplace, etc.)
- ✅ Auto-analyzes dependencies

### Intelligent Deployment Strategies

| Strategy | Use Case | Result |
|---|---|---|
| **UPGRADE** | Core contracts, proxy updates | Preserves address ✅ |
| **REDEPLOY** | Module updates, new code | New address 🆕 |
| **MIXED** | Complex changes | Auto-detected |

### Address Management
- ✅ Loads existing addresses from `deployments/complete-deployment.json`
- ✅ Creates timestamped backups before each deployment
- ✅ Auto-updates `.env` with new addresses
- ✅ Verifies contracts exist on-chain

### Interactive CLI
- ✅ Menu-driven interface with checkboxes
- ✅ Visual contract selection
- ✅ Action confirmation before execute
- ✅ Real-time deployment progress

---

## 🎯 Deployment Modes

### 1. Smart Deploy (Recommended)

```bash
npx hardhat run scripts/DeploySmartV2.cjs --network polygon
```

**What it does**:
1. Analyzes git for modified contracts
2. Shows change report
3. Suggests UPGRADE or REDEPLOY for each
4. Pre-selects modified contracts
5. Allows manual adjustment
6. Executes deployment
7. Updates .env and deployment files

**Best for**: Regular updates after code changes

**Decision tree**:
```
Modified contract?
├─ Core/Proxy → UPGRADE (preserve address)
├─ Module → REDEPLOY (new address)
└─ Multiple deps → MIXED (auto-calculate)
```

### 2. Upgrade Only

```bash
# Interactive menu shows only upgradeable contracts
npm run deploy:upgrade
```

**Characteristics**:
- Points to existing addresses
- Uses `upgradeProxy()` for all
- No new addresses created
- Frontend doesn't need updates

**When to use**: Bug fixes, optimizations, non-breaking changes

### 3. Fresh Deploy (New Network)

```bash
# Full clean deployment
npm run deploy:fresh
```

**Characteristics**:
- Deploys all contracts fresh
- Creates new addresses
- No address preservation
- Useful for testnet initialization

**When to use**: New network, clean slate, testing

---

## 🔧 Configuration

### Prerequisites
```json
{
  "hardhat": "^2.26.5",
  "ethers": "^6.15.0",
  "inquirer": "^8.2.5",
  "@openzeppelin/hardhat-upgrades": "^3.9.1"
}
```

### Environment Variables
```bash
# .env file
POLYGON_RPC_URL=https://polygon-rpc.com/
MUMBAI_RPC_URL=https://rpc-mumbai.maticvigil.com/
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_key_here
```

### Hardhat Config
```javascript
// hardhat.config.cjs
module.exports = {
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    mumbai: {
      url: process.env.MUMBAI_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

### Deployment File Structure
```
deployments/
├── complete-deployment.json  // Main deployment record
├── backup-2024-02-14.json   // Timestamped backups
└── backup-2024-02-13.json
```

---

## 📊 Deployment Checklist

### Before Deployment

- [ ] All tests passing: `npm test`
- [ ] No lint errors: `npx hardhat compile`
- [ ] Git committed: `git status` (no uncommitted changes)
- [ ] RPC URL set: `echo $POLYGON_RPC_URL`
- [ ] Private key available: `echo $PRIVATE_KEY`
- [ ] Sufficient balance: `ethers.getBalance(signer)`
- [ ] Network correct: Verify mainnet vs testnet

### During Deployment

- [ ] Monitor transaction hashes
- [ ] Check gas prices (Polygon usually <$1)
- [ ] Wait for confirmations (usually <1 min)
- [ ] Verify contract creation on PolygonScan
- [ ] Review .env updates

### After Deployment

- [ ] Compare new vs old addresses in output
- [ ] Verify contracts on PolygonScan
- [ ] Update frontend config with new addresses
- [ ] Test basic interactions
- [ ] Commit updated files to git

---

## 🔍 Contract Categories

| Category | Contracts | Strategy |
|---|---|---|
| **Core** | EnhancedSmartStaking, GameifiedMarketplace | UPGRADE |
| **Infrastructure** | TreasuryManager, DynamicAPYCalculator | UPGRADE |
| **Modules** | Rewards, Skills, Marketplace subsystems | REDEPLOY or UPGRADE |
| **Interfaces** | All IContract files | REDEPLOY (rarely change) |

---

## 📝 Deployment Output Example

```
╔══════════════════════════════════════════════════════╗
║          NUXCHAIN SMART DEPLOYMENT SYSTEM            ║
╚══════════════════════════════════════════════════════╝

🔍 CHANGE ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Modified contracts detected:
[✓] EnhancedSmartStakingRewards.sol
[✓] DynamicAPYCalculator.sol

📋 DEPLOYMENT STRATEGY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EnhancedSmartStakingRewards:
  Current:  0x1234567890...
  Strategy: UPGRADE (preserves address)
  ✓ Selected

DynamicAPYCalculator:
  Current:  0xabcdef1234...
  Strategy: UPGRADE (core infrastructure)
  ✓ Selected

🚀 EXECUTING DEPLOYMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/2] Upgrading EnhancedSmartStakingRewards...
      TxHash: 0xabc123...
      Status: ✅ Success (1 confirmation)
      Gas: 2,450,000 (cost: $0.12)

[2/2] Upgrading DynamicAPYCalculator...
      TxHash: 0xdef456...
      Status: ✅ Success (1 confirmation)
      Gas: 1,850,000 (cost: $0.09)

✅ DEPLOYMENT COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total time: 45 seconds
Total cost: ~$0.21
Network: Polygon (mainnet)

📁 Backup created: deployments/backup-2024-02-14-143022.json
📝 .env updated with new addresses
✅ All contracts verified on PolygonScan

Next steps:
1. Update frontend config with new addresses
2. Run integration tests
3. Commit changes: git add . && git commit -m "Deploy V5.0+"
```

---

## ⚠️ Common Issues

### Issue: "RPC URL not configured"
**Solution**: 
```bash
export POLYGON_RPC_URL="https://polygon-rpc.com/"
```

### Issue: "Not enough gas / Insufficient balance"
**Solution**:
```bash
# Check balance
ethers.getBalance(signerAddress)

# Fund account from faucet or exchange
```

### Issue: "Contract already exists at address"
**Solution**:
```bash
# Use UPGRADE strategy instead of REDEPLOY
# Or uncheck the contract in interactive menu
```

### Issue: "Verification failed on PolygonScan"
**Solution**:
```bash
# Manual verification (after deployment)
npx hardhat verify --network polygon ADDRESS constructor_args
```

---

## 🔐 Security Best Practices

✅ **Keep private keys secure** (never commit to git)  
✅ **Use hardware wallet for mainnet deployments**  
✅ **Test on testnet first** (Mumbai)  
✅ **Verify contracts on PolygonScan** (for transparency)  
✅ **Review deployment output** (verify addresses match expected)  
✅ **Maintain deployment backups** (timestamped automatically)  
✅ **Use multi-sig Treasury** (for mainnet access)  

---

## 📊 Deployment History

Latest deployments tracked in:
- `deployments/complete-deployment.json` - Current addresses
- `deployments/backup-*.json` - Historical records
- `.env` - Current environment configuration

---

## 🚀 Scripts Available

```bash
# Quick deployment (smart detection)
npm run deploy

# Upgrade existing contracts only
npm run deploy:upgrade

# Fresh deployment (all new)
npm run deploy:fresh

# Verify contract on-chain
npm run verify:contract

# Check deployment status
npm run deploy:status

# Create backup
npm run deploy:backup
```

---

## 📞 Support

**For deployment issues**:
1. Check `.env` configuration
2. Verify RPC connectivity
3. Review [Hardhat docs](https://hardhat.org)
4. Check deployment output logs
5. Inspect contract on PolygonScan

---

**Last Updated**: February 14, 2026  
**Version**: Smart V2  
**Network**: Polygon (Production) ✅
