# 🔧 Smart Contracts Reference - Complete Technical Guide

**Version**: 2.0 | **Updated**: February 2026 | **Network**: Polygon (Chain ID: 137)

---

## 📋 Table of Contents

1. [Staking System](#staking-system)
2. [Marketplace System](#marketplace-system)
3. [Treasury & Economy](#treasury--economy)
4. [Skills & Gamification](#skills--gamification)
5. [View Functions & Queries](#view-functions--queries)
6. [Integration Points](#integration-points)

---

## 🏦 Staking System

### Enhanced Smart Staking (v4.0)

**Address**: `0xae57acBf4efE2F6536D992F86145a20e11DB8C3D`  
**Status**: ✅ Production-Ready

#### Core Functionality

| Feature | Details | Impact |
|---------|---------|--------|
| **Min/Max Deposit** | 10 / 10,000 POL | User-friendly entry, risk limits |
| **Base ROI** | 0.005% hourly (~43.8% APY) | Competitive returns |
| **Daily Withdrawal Limit** | 1,000 POL/day | Prevents liquidity drain |
| **Commission** | 6% on rewards | Funds treasury |

#### Deposit Types (Lock-up Bonuses)

```
No Lock-up    → 0.005% hourly = 43.8% APY
30 Days       → 0.01% hourly = 87.6% APY (+44%)
90 Days       → 0.014% hourly = 122.6% APY (+79%)
180 Days      → 0.017% hourly = 148.8% APY (+105%)
365 Days      → 0.021% hourly = 183.6% APY (+140%)
```

#### Core Functions

```solidity
// State-Changing
deposit(uint128 amount, uint64 lockupDays)
withdraw(uint256 depositId, uint128 amount)
claimRewards(uint256 depositId) returns uint256

// Read-Only
getBalance(address user) returns uint256
getPendingRewards(address user) returns uint256
getCurrentAPY(address user) returns uint256
getUserPortfolio(address user) returns Portfolio
```

#### Reward Calculation Formula

```
baseReward = (depositAmount × hourlyROI × elapsedHours) / 1,000,000
timeBonus = baseReward × (lockupPercentage)
skillBoost = (baseReward × totalSkillBoost) / 10000 [CAPPED: +50%]
rarity = 1.0x to 1.8x (multiplier from skill rarity)
commission = finalAmount × 0.06 (reducible via FEE_REDUCER skills)

FINAL = ((baseReward + timeBonus) × (1 + skillBoost)) × rarity - commission
```

---

## 🎮 Marketplace System

### Gameified Marketplace (v2.0)

**Address**: `0xB948cC766CBE97Ce822bF4c915D2319fbc48Ad38`  
**Status**: ✅ Production-Ready

#### Core Features

| Feature | Details |
|---------|---------|
| **Platform Fee** | 5% on NFT sales |
| **Min POL for Skills** | 200 POL required |
| **First Skill** | Free with account |
| **Additional Skills** | 25-100 POL each |
| **Skill Change Cooldown** | 7 days (10 POL to bypass) |
| **Max Levels** | 50 levels |

#### NFT Trading Functions

```solidity
// Create & List
createNFT(string uri, string category) returns tokenId
listNFT(uint256 tokenId, uint256 price)
updateListing(uint256 tokenId, uint256 newPrice)
delistNFT(uint256 tokenId)

// Trade
buyNFT(uint256 tokenId) payable
makeOffer(uint256 tokenId, uint256 amount) external
acceptOffer(uint256 tokenId, uint256 offerIndex)
rejectOffer(uint256 tokenId, uint256 offerIndex)

// Social
likeNFT(uint256 tokenId)
addComment(uint256 tokenId, string memory comment)
```

#### XP System

| Action | XP Awarded | Notes |
|--------|-----------|-------|
| Create NFT | +10 | Free NFT creation |
| Sell NFT | +20 | Successful transaction |
| Buy NFT | +15 | Any purchase |
| Like NFT | +1 | Per like (capped daily) |
| Comment | +2 | Per comment |
| Referral | +50 | New user signup |

#### Level Progression

```
Level  │ XP Threshold │ Max Active Skills │ Benefits
───────┼──────────────┼──────────────────┼─────────────
   1   │ 100+         │ 1                 │ Basic trading
   2   │ 300+         │ 2                 │ Fee reductions
   3   │ 700+         │ 3                 │ Enhanced earnings
   4   │ 1500+        │ 4                 │ Quest access
   5   │ 3000+        │ 5                 │ Full unlock
```

#### Quest System

| Quest Type | Mechanics | Reward |
|-----------|-----------|--------|
| **Daily** | 24h window | 50-100 XP |
| **Weekly** | 7d window | 200-500 XP |
| **Seasonal** | 30d window | Limited edition NFTs |

---

## 🏦 Treasury & Economy

### Treasury Manager

**Address**: `0xad14c117b51735c072d42571e30bf2c729cd9593`  
**Status**: ✅ Production-Ready

#### Revenue Streams

```
Commission Sources:
├─ Staking: 6% of user rewards
├─ Marketplace: 5% of NFT sales
├─ Quests: 2% of completion rewards
└─ Skills: Direct purchases (25-100 POL)

Total collected → TREASURY
```

#### Automatic Distribution (triggered @ 1 POL)

```
Treasury Balance (100%)
├─ 40% → Rewards Pool (fallback for user rewards)
├─ 30% → Liquidity Pool (market-making)
├─ 20% → Development Fund (features & infrastructure)
└─ 10% → Community Incentives (marketing & events)
```

#### Treasury Functions

```solidity
// Receive
receiveTokens(uint256 amount, string calldata source)

// Query
getPoolBalance(uint8 poolId) returns uint256
getTotalBalance() returns uint256
getDistributionStats() returns (uint256[] pools)

// Distribute
distributeToPool(uint8 poolId, uint256 amount)
triggerAutoDistribution()
```

#### Failsafe Chain

If primary reward source is insufficient:
1. Staking rewards pool
2. Marketplace fees
3. Treasury allocation
4. Event emission (all logged on-chain)

---

## 💎 Skills & Gamification

### Skill NFT System

#### 7 Staking Skill Types

| ID | Name | Effect | Max Boost |
|----|----|--------|-----------|
| 1 | STAKE_BOOST_I | +5% | Stacking allowed |
| 2 | STAKE_BOOST_II | +10% | Stacking allowed |
| 3 | STAKE_BOOST_III | +20% | Stacking allowed |
| 4 | AUTO_COMPOUND | Special | 24h intervals |
| 5 | LOCK_REDUCER | -25% lockup | Reduces duration |
| 6 | FEE_REDUCER_I | -10% commission | Stacking allowed |
| 7 | FEE_REDUCER_II | -25% commission | Stacking allowed |

**⚠️ IMPORTANT CAPS**:
- Total Staking Boost: MAX +50% APY
- Total Fee Discount: MAX 75% (commission)
- Lock Reduction: MAX 50%

#### Rarity Levels & Multipliers

```
⭐           (Common)     × 1.0  (+0%)
⭐⭐         (Uncommon)   × 1.1  (+10%)
⭐⭐⭐       (Rare)       × 1.2  (+20%)
⭐⭐⭐⭐     (Epic)       × 1.4  (+40%)
⭐⭐⭐⭐⭐   (Legendary)  × 1.8  (+80%)
```

#### Skill Functions

```solidity
// Marketplace skills
activateSkill(uint256 tokenId)
deactivateSkill(uint256 tokenId)
getUserActiveSkills(address user) returns SkillNFT[]
getSkillData(uint256 tokenId) returns Skill

// Staking integration
notifySkillActivation(address user, SkillType type, Rarity rarity)
notifySkillDeactivation(address user, SkillType type)
validateSkillBoost(address user, uint256 newValue) returns bool
```

### Gamification Mechanics

#### Achievements & Badges (Auto-awarded)

```
🏆 First Deposit        → 50 XP + badge
🏆 Whale Depositor      → 100 XP (1000+ POL staked)
🏆 Marketplace Champion → 75 XP (10+ NFTs traded)
🏆 Social Butterfly     → 60 XP (50+ interactions)
🏆 Skill Master         → 200 XP (all 7 skills active)
🏆 Compound King        → 80 XP (auto-compound milestone)
🏆 Loyalty Icon         → Special (365+ days active)
🏆 Ecosystem Pioneer    → Early adopter status
```

---

## 📊 View Functions & Queries

### Query Functions (No Gas Cost)

#### Staking Queries

```solidity
getPoolStats() returns (totalValue, totalRewards, activeUsers)
getPoolHealth() returns (healthStatus, description, reserveRatio)
getAPYRates() returns (flex, 30d, 90d, 180d, 365d rates)
getDashboardData(user) returns (complete dashboard snapshot)
getEarningsBreakdown(user) returns (daily, monthly, annual)
getUserRanking(user) returns (position, tier)
```

#### Marketplace Queries

```solidity
getMarketplaceStats() returns (totalNFTs, listed, sold, volume)
getUserTradingStats(address) returns (created, owned, sold, bought)
getNFTsByCategory(category, offset, limit)
getTrendingNFTs(limit) returns (topLiked tokens)
getMarketplaceHealth() returns (activeListings, avgPrice, 24hVolume)
getSkillMarketStats() returns (totalSkills, active, revenue)
```

#### Leveling Queries

```solidity
getLevelingStats() returns (systemStats)
getUserRanking(address) returns (rank, level, tier)
getXPLeaderboard(limit) returns (topUsers)
getLevelDistribution() returns (userCountPerLevel)
getUserLevelProgress(address) returns (currentXP, nextLevelXP, level)
```

#### Referral Queries

```solidity
getReferralCode(address) returns (bytes32)
getReferrer(address buyer) returns (address)
getReferrerStats(address) returns (total, successful, xpEarned)
getTopReferrers(limit) returns (topUsers)
getReferralNetwork(address) returns (network stats)
```

---

## 🔗 Integration Points

### Cross-Contract Communication

#### Marketplace → Staking (Notifications)

```
notifySkillActivation(user, skillType, rarity)
├─ Apply boost to active stakes
└─ Recalculate APY

notifySkillDeactivation(user, skillType)
├─ Remove boost
└─ Update APY

notifyQuestCompletion(user, reward)
├─ Add bonus to pending rewards
└─ Trigger achievement check

notifyAchievementUnlocked(user, achieved)
├─ Award special bonus
└─ Log milestone event
```

#### Staking → Marketplace (Queries)

```
_getStakingBalance(user)
├─ Returns total staked
└─ Used for tier eligibility

calculateBoostedRewards(user)
├─ Returns APY with active boosts
└─ Used for dashboard display

hasAutoCompound(user)
├─ Returns bool
└─ Affects display flags
```

### Event Emissions (For Indexing)

All critical state changes emit events:
```solidity
event DepositCreated(address user, uint256 amount, uint256 lockupDays)
event RewardsClaimed(address user, uint256 amount)
event SkillActivated(address user, SkillType skillType, Rarity rarity)
event NFTCreated(address creator, uint256 tokenId, string category)
event NFTSold(address seller, address buyer, uint256 tokenId, uint256 price)
event TreasuryDistributed(uint256 total, uint256[] poolAmounts)
event LevelUp(address user, uint8 newLevel, uint256 xpEarned)
```

---

## ⚙️ Configuration

### Key Parameters (Settable by Owner)

```solidity
/// Staking
HOURLY_ROI_PERCENTAGE = 50 (0.005%)
MIN_DEPOSIT = 10 * 10^18
MAX_DEPOSIT = 10000 * 10^18
DAILY_WITHDRAWAL_LIMIT = 1000 * 10^18
COMMISSION_PERCENTAGE = 600 (6%)

/// Marketplace
PLATFORM_FEE = 500 (5%)
MIN_POL_FOR_SKILL = 200 * 10^18
SKILL_CHANGE_COOLDOWN = 7 days
SKILL_CHANGE_FEE = 10 * 10^18

/// Gamification
MAX_SKILLS_PER_LEVEL = [1, 2, 3, 4, 5]
LEVEL_UP_REWARD = 20 * 10^18
ACHIEVEMENT_REWARD = varies

/// Treasury
POOL_ALLOCATIONS = [4000, 3000, 2000, 1000] (basis points)
AUTO_DISTRIBUTION_THRESHOLD = 1 * 10^18
```

---

## 🔐 Security Features

### Protections Implemented

✅ **Deposit Limits**: Max 10,000 POL prevents catastrophic loss  
✅ **Withdrawal Limits**: 1,000 POL/day prevents bank runs  
✅ **Skill Boost Caps**: +50% APY maximum (cannot be exceeded)  
✅ **Fee Discount Cap**: 75% maximum discount  
✅ **Pre-Activation Validation**: All skills validated before activation  
✅ **Reentrancy Guard**: OpenZeppelin ReentrancyGuard on critical functions  
✅ **Emergency Pause**: Owner can pause contracts in emergency  
✅ **Multi-Signature Treasury**: Critical operations require approval  

### Audit Status

- ✅ Verified on PolygonScan
- ✅ Used in production since Nov 2025
- ✅ No critical vulnerabilities reported
- ✅ All contracts follow OpenZeppelin standards

---

## 📈 Performance Metrics

### Gas Costs (Polygon)

| Operation | Gas | Est. Cost |
|-----------|-----|-----------|
| Deposit | ~90K | ~$0.24 |
| Claim Rewards | ~85K | ~$0.22 |
| Create NFT | ~120K | ~$0.31 |
| Buy NFT | ~150K | ~$0.39 |
| Activate Skill | ~95K | ~$0.25 |

### Transaction Speed

- **Average Block Time**: 2 seconds
- **Finality**: Immediate (PoS)
- **Confirmation Time**: 1-2 blocks (~5 seconds)

---

## 🚀 Deployment Information

### Polygon Mainnet (Chain ID: 137)

```
Enhanced Smart Staking:  0xae57acBf4efE2F6536D992F86145a20e11DB8C3D
Gameified Marketplace:   0xB948cC766CBE97Ce822bF4c915D2319fbc48Ad38
Treasury Manager:        0xad14c117b51735c072d42571e30bf2c729cd9593
POL Token:               0x455e53cbb86018ac2b8092fdcd39d8444aff00ef
```

### Deployment Date: November 3, 2025
### Last Updated: February 11, 2026

---

## 📚 Additional Resources

- **Contracts Code**: `/contracts/`
- **Detailed Specs**: `/doc/contracts/`
- **Whitepaper**: `NUXCHAIN_WHITEPAPER.md`
- **Architecture**: `SYSTEM_ARCHITECTURE.md`

---

**© 2026 Nuxchain Protocol - Technical Reference**

