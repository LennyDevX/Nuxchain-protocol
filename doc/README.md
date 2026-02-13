# � Nuxchain Protocol - Documentation Hub

**Complete reference for the Nuxchain Protocol smart contract ecosystem**

---

## 🚀 Start Here

### For Different Audiences

| Role | Start Reading |
|------|---------------|
| **Developer** | [Smart Contracts Reference](#1-smart-contracts-reference) |
| **Architect** | [System Architecture](#2-system-architecture) |
| **Deployer** | [Quick Start](#quick-start-addresses--commands) |
| **Auditor** | [/contracts/](#individual-contract-documentation) |
| **Investor** | [Whitepaper](../NUXCHAIN_WHITEPAPER.md) |

---

## 📖 Main Documentation

### 1. Smart Contracts Reference
**[SMART_CONTRACTS_REFERENCE.md](SMART_CONTRACTS_REFERENCE.md)**

Complete technical reference for all contracts:
- ✅ All 6 contract modules (Core, Rewards, Skills, Marketplace, Treasury, etc.)
- ✅ All functions with signatures & parameters
- ✅ All events & state variables
- ✅ Integration points & cross-contract calls
- ✅ View functions & query capabilities
- ✅ Security features & audit status

**Read this if**: You need to integrate, debug, or understand contract capabilities.

### 2. System Architecture
**[SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)**

How everything connects together:
- ✅ Component architecture (3 main modules)
- ✅ Data flow patterns (deposits, claims, trades, skills)
- ✅ State synchronization (Staking ↔ Marketplace)
- ✅ Revenue flow & treasury distribution
- ✅ Failsafe mechanisms
- ✅ Performance characteristics
- ✅ Execution flow examples

**Read this if**: You want to understand how contract modules work together.

### 3. Whitepaper & Marketing
**[../NUXCHAIN_WHITEPAPER.md](../NUXCHAIN_WHITEPAPER.md)** (in parent folder)

Comprehensive overview for all audiences (31,500+ words):
- Vision, mission, and problem statement
- Detailed tokenomics and economic model
- Feature overview and use cases
- Roadmap and future vision
- Market analysis and positioning

**Read this if**: You're evaluating the project or need high-level overview.

---

## 📄 Individual Contract Documentation

Located in `/contracts/` subfolder for detailed per-contract specs:

```
/contracts/
├─ EnhancedSmartStaking.md       (Core staking logic)
├─ SmartStakingRewards.md        (Reward calculations)
├─ SmartStakingSkills.md         (Skill integration)
├─ SmartStakingGamification.md   (Badges & achievements)
├─ GameifiedMarketplace.md       (NFT trading)
├─ GameifiedMarketplaceSkills.md (Skill NFTs)
├─ GameifiedMarketplaceQuests.md (Quest system)
├─ TreasuryManager.md            (Revenue & distribution)
└─ [others]                      (Supporting contracts)
```

**Each file contains**:
- Function signatures & descriptions
- Parameter definitions
- Return values
- Event emissions
- Example usage
- Integration notes

**Read specific contract if**: You need deep-dive on one component.

---

## 🔍 Quick Start (Addresses & Commands)

### 📍 Contract Addresses (Polygon Mainnet)

```
Staking:            0xae57acBf4efE2F6536D992F86145a20e11DB8C3D
Marketplace:        0xB948cC766CBE97Ce822bF4c915D2319fbc48Ad38
Treasury Manager:   0xad14c117b51735c072d42571e30bf2c729cd9593
POL Token:          0x455e53cbb86018ac2b8092fdcd39d8444aff00ef

Network: Polygon (Chain ID: 137)
Status:  Production-Deployed (2025-11-03)
```

### ⚡ Common Commands

```bash
# Deployment
npx hardhat run scripts/DeployAllContracts.cjs --network polygon

# Testing
npx hardhat test
npx hardhat coverage

# Verification
npx hardhat verify 0xae57acBf4efE2F6536D992F86145a20e11DB8C3D --network polygon
```

### 💰 Key Metrics

```
Staking:
├─ Base APY: 43.8% (minimum)
├─ Max APY:  183.6% (with all boosts)
├─ Commission: 6%
└─ Lock periods: 30, 60, 90, 180, 365 days

Marketplace:
├─ Platform Fee: 5%
├─ Skill Slot Unlock: Level-based (1-5)
├─ Level Cap: 50
└─ XP Sources: 6 activities

Treasury:
├─ Distribution: 40/30/20/10 split
├─ Auto-trigger: 1 POL minimum
└─ Revenue Sources: 3 (staking, marketplace, quests)
```

---

## 📚 Reference Tables

### Skill Types

| ID | Name | Effect | Cap |
|----|------|--------|-----|
| 1 | STAKE_BOOST_I | +5% APY | +50% total |
| 2 | STAKE_BOOST_II | +10% APY | |
| 3 | STAKE_BOOST_III | +20% APY | |
| 4 | AUTO_COMPOUND | 24h cycle | N/A |
| 5 | LOCK_REDUCER | -25% lock time | 50% reduction |
| 6 | FEE_REDUCER_I | -10% commission | 75% total |
| 7 | FEE_REDUCER_II | -25% commission | |

### Skill Rarity Multipliers

| Rarity | Multiplier | Acquisition |
|--------|-----------|-------------|
| COMMON | 1.0x | Default |
| UNCOMMON | 1.1x | Marketplace |
| RARE | 1.2x | Marketplace |
| EPIC | 1.4x | Marketplace/Quests |
| LEGENDARY | 1.8x | Quests/Events |

### User Levels & Unlocks

| Level | XP Required | Skill Slots | Features |
|-------|------------|------------|----------|
| 1 | 100 | 1 | Basic trading |
| 2 | 300 | 2 | NFT creation |
| 3 | 700 | 3 | Skill activation |
| 4 | 1,500 | 4 | Quests + Referral |
| 5 | 3,000 | 5 | Advanced features |

---

## 🛠️ Development Resources

### Setup & Testing

```bash
# Install dependencies
npm install

# Compile
npx hardhat compile

# Run tests
npx hardhat test
npx hardhat test test/SmartStaking.cjs  # Specific test

# Coverage report
npx hardhat coverage

# Local development
npx hardhat node
```

### File Structure

```
/contracts/          → Smart contract source code
/test/               → Test files (Mocha)
/scripts/            → Deployment & management scripts
/artifacts/          → Compiled contract ABIs
/deployments/        → Deployment history & addresses
/doc/                → Documentation (you are here)
└─ /contracts/       → Per-contract documentation
```

### External Links

**PolygonScan** (Mainnet Verification):
- [Staking Contract](https://polygonscan.com/address/0xae57acBf4efE2F6536D992F86145a20e11DB8C3D)
- [Marketplace Contract](https://polygonscan.com/address/0xB948cC766CBE97Ce822bF4c915D2319fbc48Ad38)
- [Treasury Contract](https://polygonscan.com/address/0xad14c117b51735c072d42571e30bf2c729cd9593)

**Source Code**:
- Repository: [github.com/nuxchain/protocol](https://github.com/nuxchain/protocol)
- Issues: [github.com/nuxchain/protocol/issues](https://github.com/nuxchain/protocol/issues)

---

## 🔐 Security & Audit

### Contract Status

```
✅ EnhancedSmartStaking (v4.0) - Audited, Production
✅ GameifiedMarketplace (v2.0) - Audited, Production
✅ TreasuryManager (v1.0)       - Audited, Production
✅ Supporting Contracts         - Standard OpenZeppelin libraries
```

### Safety Features

- **Pause/Unpause**: Emergency protocol pause capability
- **Access Control**: Role-based permissions (OWNER, ADMIN, MODERATOR)
- **Caps & Limits**: Max boost (+50% APY), fee discount (75%), lock reduction (50%)
- **Failsafes**: Treasury fallback for reward payment
- **Guards**: Reentrancy protection, valid address checks

---

## 📞 Common Questions

**Q: Where should I start reading?**  
A: Start with [System Architecture](SYSTEM_ARCHITECTURE.md) for overview, then dive into [Smart Contracts Reference](SMART_CONTRACTS_REFERENCE.md) for details.

**Q: How do I deploy the contracts?**  
A: Run `npx hardhat run scripts/DeployAllContracts.cjs --network polygon`. See `/scripts/` for options.

**Q: What's the difference between the contracts?**  
A: **Staking** = yield generation, **Marketplace** = NFT trading, **Treasury** = revenue distribution.

**Q: How do Staking and Marketplace interact?**  
A: See [System Architecture - State Synchronization](SYSTEM_ARCHITECTURE.md#state-synchronization) section.

**Q: Where's the whitepaper?**  
A: [../NUXCHAIN_WHITEPAPER.md](../NUXCHAIN_WHITEPAPER.md) in the parent `/doc/` folder.

---

## 📋 Documentation Maintenance

**Last Updated**: 2025-11-03  
**Document Version**: 2.1  
**Contract Version**: v4.0 (Staking), v2.0 (Marketplace), v1.0 (Treasury)

### What's Archived?

Outdated documentation has been archived in `/archive/` folder:
- Historical deployment guides
- Superseded feature documentation
- Old version references
- Implementation logs

These are kept for historical reference but not required for current operation.

---

## 🎯 Next Steps

1. **Understand the System** → Read [System Architecture](SYSTEM_ARCHITECTURE.md)
2. **Learn the Contracts** → Read [Smart Contracts Reference](SMART_CONTRACTS_REFERENCE.md)
3. **Explore Individual Docs** → Browse [/contracts/](contracts/) subfolder
4. **Integrate or Deploy** → Run tests and scripts in root folder
5. **Dig Deeper** → Check the `/contracts/` source code

---

**🔗 Nuxchain Protocol v2.0 - The NFT-Integrated Smart Staking Platform with Skill-Based Gamification**
