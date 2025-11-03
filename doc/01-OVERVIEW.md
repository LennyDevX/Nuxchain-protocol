# 📋 Nuxchain Protocol - Smart Contracts Documentation

## 🎯 Executive Summary

Nuxchain Protocol implements an advanced **staking and gamified NFT marketplace** system on Polygon. The architecture features two main contracts with integrated skill-based boosts, quest/achievement systems, and cross-contract synchronization.

**Current Status**: Production-ready on Polygon Mainnet (Chain ID: 137)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│           Nuxchain Protocol (v2.0)                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────┐          ┌──────────────────┐    │
│  │ Enhanced Smart   │◄────────►│ Gameified        │    │
│  │ Staking (v4.0)   │ Bi-dir   │ Marketplace      │    │
│  │                  │ Sync     │ (v2.0)           │    │
│  └──────────────────┘          └──────────────────┘    │
│         ⬇️                               ⬇️              │
│    • Deposits                      • NFT Creation      │
│    • Rewards                       • Skill Minting     │
│    • Auto-Compound                 • Trading           │
│    • Skill Boosts                  • XP/Leveling      │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 Core Contracts

### 1️⃣ EnhancedSmartStaking (v4.0.0)
**Address**: `0xae57acBf4efE2F6536D992F86145a20e11DB8C3D`

Advanced staking protocol with NFT skill integration and gamification features.

#### ✨ Key Features

| Feature | Details |
|---------|---------|
| **Min Deposit** | 10 ETH |
| **Max Deposit** | 10,000 ETH |
| **Base ROI** | 0.005% hourly (~43.8% APY) |
| **Lock-up Bonuses** | 30/90/180/365 days with higher ROI |
| **Commission** | 6% on rewards |
| **Daily Withdrawal Limit** | 1,000 ETH |

#### 🎮 Skill Types (7 Total)

```
• STAKE_BOOST_I      → +5% rewards
• STAKE_BOOST_II     → +10% rewards
• STAKE_BOOST_III    → +20% rewards
• AUTO_COMPOUND      → 24h automatic compounding
• LOCK_REDUCER       → -25% lockup duration
• FEE_REDUCER_I      → -10% commission
• FEE_REDUCER_II     → -25% commission
```

#### 📈 ROI Structure

```
Lock-up Period   │ ROI/Hour (bp) │ Effective APY
─────────────────┼───────────────┼──────────────
No Lock-up       │ 50            │ ~43.8%
30 Days          │ 100           │ ~87.6%
90 Days          │ 140           │ ~122.6%
180 Days         │ 170           │ ~148.8%
365 Days         │ 210           │ ~183.6%
```

### 2️⃣ GameifiedMarketplace (v2.0.0)
**Address**: `0xB948cC766CBE97Ce822bF4c915D2319fbc48Ad38`

NFT marketplace with integrated gamification and staking synchronization.

#### ✨ Key Features

| Feature | Details |
|---------|---------|
| **Min POL for Skills** | 200 POL tokens |
| **First Skill** | Free with NFT |
| **Additional Skills** | 25-100 POL (rarity-based) |
| **Skill Change Cooldown** | 7 days (10 POL to bypass) |
| **Platform Fee** | 5% on sales |
| **Rewards Commission** | 2% on staking rewards |

#### 🎮 User Progression System

```
XP Thresholds  │ Level │ Max Active Skills
───────────────┼───────┼──────────────────
100+           │   1   │ 1 skill
300+           │   2   │ 2 skills
700+           │   3   │ 3 skills
1500+          │   4   │ 4 skills
3000+          │   5   │ 5 skills
```

#### 💰 XP Rewards

```
✚ Create NFT:        +10 XP
✚ Sell NFT:          +20 XP
✚ Buy NFT:           +15 XP
✚ Like NFT:          +1 XP
✚ Comment:           +2 XP
✚ Referral:          +50 XP
```

---

## 🔄 Cross-Contract Synchronization

### Bi-Directional Communication

```
MARKETPLACE → STAKING (Notifications)
├── notifySkillActivation()      → Apply skill boosts
├── notifySkillDeactivation()    → Remove boosts
├── notifyQuestCompletion()      → +Reward amount
├── notifyAchievementUnlocked()  → +Reward amount
└── setSkillRarity()             → Update rarity multiplier

STAKING → MARKETPLACE (Queries)
├── _getStakingBalance()         → Check POL requirements
├── calculateBoostedRewards()    → Boosted APY display
└── hasAutoCompound()            → Status check
```

---

## 🚀 Deployment Info

### Polygon Mainnet

| Component | Address | Status |
|-----------|---------|--------|
| **EnhancedSmartStaking** | `0xae57acBf4efE2F6536D992F86145a20e11DB8C3D` | ✅ Verified |
| **GameifiedMarketplace** | `0xB948cC766CBE97Ce822bF4c915D2319fbc48Ad38` | ✅ Verified |
| **Treasury** | `0xad14c117b51735c072d42571e30bf2c729cd9593` | Fixed |
| **POL Token** | `0x455e53cbb86018ac2b8092fdcd39d8444aff00ef` | Standard |

**Deployed**: 2025-11-03  
**Network**: Polygon (Chain ID: 137)  
**View on PolygonScan**: https://polygonscan.com/address/0xae57acBf4efE2F6536D992F86145a20e11DB8C3D

---

## 📋 Deployment Scripts (Simplified)

```
scripts/
├── DeployEnhancedSmartStaking.cjs      ✅ Deploy staking v4
├── DeployGameifiedMarketplace.cjs      ✅ Deploy marketplace v2
├── DeployAllContracts.cjs              ✅ Full deployment workflow
├── ManageContracts.cjs                 ✅ Verify & configure (consolidated)
├── StakingManagement.cjs               ✅ Fund/pause/withdraw (consolidated)
└── ContractInteractionExamples.cjs     ✅ Usage examples
```

### Quick Deploy Commands

```bash
# Deploy staking contract
npx hardhat run scripts/DeployEnhancedSmartStaking.cjs --network polygon

# Deploy marketplace
npx hardhat run scripts/DeployGameifiedMarketplace.cjs --network polygon

# Deploy all + configure
npx hardhat run scripts/DeployAllContracts.cjs --network polygon

# Verify status
npx hardhat run scripts/ManageContracts.cjs --network polygon -- verify

# Fund staking
npx hardhat run scripts/StakingManagement.cjs --network polygon -- fund 100
```

---

## 🔐 Security Features

### Access Control

```
EnhancedSmartStaking:
├─ onlyOwner:        pause, unpause, setMarketplaceAddress
├─ onlyMarketplace:  skill/quest/achievement notifications
└─ Public:           deposit, withdraw, calculateRewards

GameifiedMarketplace:
├─ ADMIN_ROLE:       pause, setStakingContractAddress
├─ Public:           createSkillNFT, buyToken, activateSkill
└─ External:         marketplace interactions
```

### Risk Mitigations

```
✅ ReentrancyGuard on all critical functions
✅ Pausable for emergency stops
✅ Commission fallback mechanism
✅ Daily withdrawal limits (1,000 ETH)
✅ Max deposit cap (10,000 ETH)
✅ Min deposit requirement (10 ETH)
✅ Lock-up period enforcement
✅ Skill cooldown protection (7 days)
```

---

## 💡 Usage Examples

### Example 1: Staking with Skill Boost

```javascript
// 1. User deposits 50 ETH with 90-day lock-up
await stakingContract.deposit(90, { value: ethers.parseEther("50") });

// 2. After 365 days, check boosted rewards
const boostedRewards = await stakingContract.calculateBoostedRewards(userAddress);
// Base rewards: ~65 ETH (138% APY)
// With STAKE_BOOST_II (+10%): ~71.5 ETH
// With UNCOMMON rarity (1.1x): ~78.65 ETH

// 3. Withdraw boosted rewards
await stakingContract.withdrawBoosted();
```

### Example 2: Creating & Trading Skill NFT

```javascript
// 1. Create Skill NFT with 3 skills
const tx = await marketplace.createSkillNFT(
  "ipfs://QmXXX...",
  "combat",
  500,  // 5% royalty
  [1, 4, 6],  // STAKE_BOOST_I, AUTO_COMPOUND, FEE_REDUCER_I
  [500, 1000, 1000],  // effect values
  [2, 3, 1]  // RARE, EPIC, UNCOMMON
);
// Cost: 0 (1st) + 60 (RARE) + 80 (EPIC) = 140 POL

// 2. List for sale
await marketplace.listTokenForSale(tokenId, ethers.parseEther("5"));

// 3. Buyer purchases
await marketplace.buyToken(tokenId, { value: ethers.parseEther("5") });
```

---

## 📞 Support

**Documentation**: See individual contract files  
**Verification**: https://polygonscan.com/address/0xae57acBf4efE2F6536D992F86145a20e11DB8C3D  
**Issues**: GitHub repository

---

Generated: 2025-11-03  
Version: 2.0.0
