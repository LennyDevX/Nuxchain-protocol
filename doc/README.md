# 🔗 Quick Reference - Nuxchain Protocol

## 📍 Contract Addresses (Polygon Mainnet)

```
Staking:      0xae57acBf4efE2F6536D992F86145a20e11DB8C3D
Marketplace:  0xB948cC766CBE97Ce822bF4c915D2319fbc48Ad38
Treasury:     0xad14c117b51735c072d42571e30bf2c729cd9593
POL Token:    0x455e53cbb86018ac2b8092fdcd39d8444aff00ef
```

---

## ⚡ Quick Commands

### Deploy
```bash
npx hardhat run scripts/DeployAllContracts.cjs --network polygon
```

### Verify Status
```bash
npx hardhat run scripts/ManageContracts.cjs --network polygon -- verify
```

### Fund Staking
```bash
npx hardhat run scripts/StakingManagement.cjs --network polygon -- fund 100
```

### Configure
```bash
npx hardhat run scripts/ManageContracts.cjs --network polygon -- configure
```

---

## 💰 Staking Rewards

```
Deposit: 50 ETH for 365 days
├─ Base ROI: 0.021% per hour
├─ Annual: ~183.6% APY
├─ 1 Year Reward: 91.8 ETH
└─ After 6% commission: 86.29 ETH
```

---

## 🎮 Gamification Quick Start

### Skill Types
```
1 = STAKE_BOOST_I      (+5%)
2 = STAKE_BOOST_II     (+10%)
3 = STAKE_BOOST_III    (+20%)
4 = AUTO_COMPOUND      (24h)
5 = LOCK_REDUCER       (-25%)
6 = FEE_REDUCER_I      (-10%)
7 = FEE_REDUCER_II     (-25%)
```

### User Levels
```
Lvl 1: 100 XP  → 1 skill
Lvl 2: 300 XP  → 2 skills
Lvl 3: 700 XP  → 3 skills
Lvl 4: 1500 XP → 4 skills
Lvl 5: 3000 XP → 5 skills
```

### XP Rewards
```
Create NFT: +10 XP
Sell NFT:   +20 XP
Buy NFT:    +15 XP
Like:       +1 XP
Comment:    +2 XP
Referral:   +50 XP
```

---

## 📊 Key Parameters

| Parameter | Value |
|-----------|-------|
| Min Deposit | 10 ETH |
| Max Deposit | 10,000 ETH |
| Daily Limit | 1,000 ETH |
| Commission | 6% |
| Platform Fee | 5% |
| Min POL for Skills | 200 POL |
| Skill Cooldown | 7 days |

---

## 🔐 Access Control

```
Staking:
├─ Owner: Contract owner
└─ Marketplace: Only marketplace contract

Marketplace:
├─ ADMIN_ROLE: Contract admins
├─ MODERATOR_ROLE: Moderators
└─ PUBLIC: All users
```

---

## 📈 Rarity Multipliers

```
COMMON:    1.0x
UNCOMMON:  1.1x
RARE:      1.2x
EPIC:      1.4x
LEGENDARY: 1.8x
```

---

## 🧪 Test Commands

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/EnhancedSmartStaking.cjs

# With coverage report
npx hardhat coverage

# On polygon network
npx hardhat test test/EnhancedSmartStaking.cjs --network polygon
```

---

## 🔗 External Links

**PolygonScan**:
- Staking: https://polygonscan.com/address/0xae57acBf4efE2F6536D992F86145a20e11DB8C3D
- Marketplace: https://polygonscan.com/address/0xB948cC766CBE97Ce822bF4c915D2319fbc48Ad38

**GitHub**:
- Repository: github.com/nuxchain/protocol
- Issues: github.com/nuxchain/protocol/issues

**Documentation**:
- See `/doc` folder for detailed guides

---

## 🚨 Emergency Procedures

### Pause Contract
```javascript
await staking.pause();
await marketplace.pause();
```

### Resume Contract
```javascript
await staking.unpause();
await marketplace.unpause();
```

### Emergency Withdrawal
```javascript
// User can still withdraw even if paused
await staking.withdraw();
```

---

## 💡 Development Setup

```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Run local network
npx hardhat node

# Deploy to local
npx hardhat run scripts/DeployAllContracts.cjs --network localhost

# Deploy to polygon
npx hardhat run scripts/DeployAllContracts.cjs --network polygon
```

---

## 📞 Support Resources

| Type | Resource |
|------|----------|
| **Contracts** | See `/contracts` folder |
| **Tests** | See `/test` folder |
| **Scripts** | See `/scripts` folder |
| **Docs** | See `/doc` folder |
| **Config** | `hardhat.config.cjs` |

---

Last Updated: 2025-11-03  
Version: 2.0.0
