# 🏗️ System Architecture - How Everything Connects

**Understanding the Nuxchain Protocol Ecosystem**

---

## Overview Diagram

```
┌─────────────────────────────────────────────────────────────┐
│         NUXCHAIN PROTOCOL - POLYGON MAINNET                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│         ┌────────────────────────────────────────┐          │
│         │   ENHANCED SMART STAKING (v4.0)       │          │
│         ├────────────────────────────────────────┤          │
│         │ • Deposit/Withdraw Management          │          │
│         │ • Reward Calculations                  │          │
│         │ • Skill Integration                    │          │
│         │ • Auto-Compounding                     │          │
│         │ • XP/Badge Tracking                    │          │
│         └────────────────┬───────────────────────┘          │
│                          │                                  │
│                          ↕ (Bi-directional Sync)            │
│                          │                                  │
│         ┌────────────────┴───────────────────────┐          │
│         │  GAMEIFIED MARKETPLACE (v2.0)         │          │
│         ├────────────────────────────────────────┤          │
│         │ • NFT Creation/Trading                 │          │
│         │ • Skill NFT System                     │          │
│         │ • Quest Management                     │          │
│         │ • XP & Leveling                        │          │
│         │ • Referral Rewards                     │          │
│         └────────────────┬───────────────────────┘          │
│                          │                                  │
│                          ↓                                  │
│         ┌────────────────────────────────────────┐          │
│         │    TREASURY MANAGER (v1.0)            │          │
│         ├────────────────────────────────────────┤          │
│         │ • Commission Collection                │          │
│         │ • Auto-Distribution (4 pools)         │          │
│         │ • Fallback Safety Chain                │          │
│         │ • Emergency Controls                   │          │
│         └────────────────────────────────────────┘          │
│                                                              │
└─────────────────────────────────────────────────────────────┘

User Interaction → Staking/Marketplace → Events & Updates → Treasury
                                      ↓
                            Cross-Contract Sync
```

---

## Component Architecture

### Layer 1: User Interaction

**Where users interact with the protocol:**
- Web3 DApp frontend
- Smart contract calls via ethers.js/web3.js
- Wallet signatures (MetaMask, etc.)

### Layer 2: Core Smart Contracts

**Enhanced Smart Staking Module** (~30KB)
```
├─ Core Functions (Deposit/Withdraw/Claim)
├─ Reward Calculations
├─ Skill Integration
├─ Gamification Tracking
└─ View/Query Functions
```

**Gameified Marketplace Module** (~35KB)
```
├─ NFT ERC721 Management
├─ Trading & Offers
├─ Social Features (likes, comments)
├─ XP & Leveling System
├─ Referral Tracking
└─ Quest Management
```

**Treasury Manager** (~10KB)
```
├─ Revenue Collection
├─ Pool Distribution
├─ Auto-Distribution Logic
└─ Emergency Controls
```

### Layer 3: Integration & Sync

**Event-Driven Communication**:
- Contracts emit events for all critical state changes
- Off-chain indexers (The Graph) listen to events
- Frontend reads from indexers for performance

**Direct Calls** (synchronous):
- Marketplace queries staking balance
- Staking queries marketplace level
- Both integrate with treasury

### Layer 4: Data Persistence

**On-Chain State**:
- User deposits & balances
- NFT ownership
- XP & level data
- Skill metadata

**Off-Chain Indexing**:
- The Graph subgraph indexes events
- Faster queries than on-chain
- Real-time dashboards

---

## Data Flow Patterns

### Pattern 1: User Deposit Flow

```
User
 │
 ├─→ Call: deposit(100 POL, 90 days)
 │
 ├─→ [EnhancedSmartStaking.Core]
 │    ├─ Validate amount (10-10,000)
 │    ├─ Check daily withdrawal limit
 │    ├─ Create Deposit struct
 │    ├─ Transfer POL from user
 │    └─ Emit DepositCreated event
 │
 ├─→ [EnhancedSmartStaking.Gamification]
 │    ├─ Check for badge eligibility
 │    ├─ Auto-award if conditions met
 │    └─ Emit BadgeAwarded event
 │
 └─→ User's account updated with:
     ├─ New deposit record
     ├─ Updated APY calculation
     ├─ Initial badge status
     └─ Ongoing reward accrual (auto-claimed)
```

### Pattern 2: Claim Rewards Flow

```
User Calls: claimRewards(depositId)
│
├─→ [EnhancedSmartStaking.Rewards]
│    ├─ Calculate time elapsed
│    ├─ Apply base ROI & time bonuses
│    ├─ Fetch active skills from Marketplace
│    ├─ Apply skill boosts (capped +50%)
│    ├─ Fetch skill rarity → apply multiplier
│    ├─ Calculate commission (6%)
│    └─ Result: (gross × boosts × rarity) - commission
│
├─→ [Treasury Manager]
│    ├─ Receive 6% commission
│    └─ If balance > 1 POL: trigger auto-distribution
│         ├─ 40% → Rewards pool (fallback)
│         ├─ 30% → Liquidity pool
│         ├─ 20% → Dev fund
│         └─ 10% → Community incentives
│
├─→ [EnhancedSmartStaking.Gamification]
│    ├─ Check milestone achievements
│    ├─ Award badges if triggers hit
│    └─ Process auto-compound if enabled
│
└─→ User receives:
    ├─ Rewards (gross - commission)
    ├─ Possible badges/achievements
    ├─ Auto-compounded amount (if active)
    └─ Event: RewardsClaimed
```

### Pattern 3: Marketplace NFT Sale Flow

```
Buyer Calls: buyNFT(tokenId)
│
├─→ [GameifiedMarketplace.Core]
│    ├─ Validate NFT exists & listed
│    ├─ Check price & buyer balance
│    ├─ Transfer POL from buyer to seller
│    ├─ Award XP to buyer (+15)
│    ├─ Award XP to seller (+20)
│    └─ Transfer NFT ownership
│
├─→ [LevelingSystem]
│    ├─ Add XP to user profiles
│    ├─ Check for level-ups
│    ├─ If level-up: emit event & award bonus
│    └─ Update leaderboards
│
├─→ [ReferralSystem]
│    ├─ Check if buyer has referrer
│    ├─ If yes & first purchase: award discount
│    ├─ If seller & first sale: award referrer XP
│    └─ Update referral stats
│
├─→ [EnhancedSmartStaking]
│    ├─ Get user's active skills
│    ├─ Apply skill effects to display
│    └─ Update dashboard metrics
│
├─→ [Treasury Manager]
│    ├─ Receive 5% platform fee
│    └─ Auto-distribute if triggered
│
└─→ Events emitted (indexed by The Graph):
    ├─ NFTSold(seller, buyer, tokenId, price)
    ├─ XPAwarded(buyer, 15)
    ├─ XPAwarded(seller, 20)
    ├─ LevelUp(user, newLevel)
    └─ TreasuryDistributed(...)
```

### Pattern 4: Skill Activation Flow

```
User Activates Skill NFT
│
├─→ [Marketplace] validate & activate
│    ├─ Check user level (min check)
│    ├─ Check active skill count < limit
│    ├─ Add to activeSkills array
│    └─ Emit SkillActivated event
│
├─→ [EnhancedSmartStaking.Skills] via notifySkillActivation()
│    ├─ Validate skill boost limits
│    │  ├─ New total boost ≤ 50% APY cap
│    │  ├─ Fee discount ≤ 75% cap
│    │  └─ Lock reduction ≤ 50% cap
│    ├─ Add to active skills
│    ├─ Recalculate user APY
│    └─ Emit SkillActivated_Staking event
│
├─→ [Dashboard Updates]
│    ├─ User sees new APY immediately
│    ├─ Breakdown shows:
│    │  ├─ Base APY (43.8%)
│    │  ├─ Time bonus (+X%)
│    │  ├─ Skill boost (+X%)
│    │  └─ Rarity multiplier (X.X%)
│    └─ FINAL APY displayed
│
└─→ Ongoing Effects:
    ├─ All future rewards calculated with boost
    ├─ Commission reduced if FEE_REDUCER active
    ├─ Lock-up duration reduced if LOCK_REDUCER active
    └─ Auto-compound interval active if enabled
```

---

## State Synchronization

### How Staking ↔ Marketplace Stay in Sync

#### Marketplace Notifies Staking

```
Event: SkillActivated (Marketplace)
├─ Marketplace emits event with:
│  ├─ User address
│  ├─ Skill type (STAKE_BOOST_I, etc.)
│  └─ Rarity (COMMON to LEGENDARY)
│
├─ Staking contract listens:
│  ├─ notifySkillActivation() called
│  ├─ Validates boost limits
│  ├─ Updates user APY calculation
│  └─ Caches new values for queries
│
└─ Result:
   ├─ User's pending rewards include boost
   ├─ Dashboard shows updated APY
   └─ No manual intervention needed
```

#### Staking Provides Data to Marketplace

```
Query: getUserLevel(address)
├─ Marketplace calls Staking
│  ├─ Get user's total deposited amount
│  ├─ Determine tier based on deposits
│  └─ Return level/tier
│
├─ Marketplace uses for:
│  ├─ Skill slot unlocking (level-based)
│  ├─ Feature access gating
│  └─ Fee structure adjustments
│
└─ Data always current (no caching lag)
```

### Consistency Guarantees

✅ **No Orphaned Deposits**: Treasury fallback ensures all rewards paid  
✅ **No Invalid Skills**: Pre-activation validation prevents over-boost  
✅ **No Lost XP**: Events indexed for audit trail  
✅ **No Duplicate Payments**: Claim tracking prevents double-pay  
✅ **No Withdrawal Attacks**: Daily limits + checks prevent exploits  

---

## Revenue Flow

### Commission Collection

```
All User Activities
├─ Staking Reward Claimed
│  └─ 6% Commission → Treasury
│
├─ NFT Sale Completed
│  └─ 5% Fee → Treasury
│
├─ Quest Completed
│  └─ 2% Commission → Treasury
│
└─ Skill Purchased
   └─ 25-100 POL → Treasury

        ↓ All combined ↓

    TREASURY POOL
    (Stored in TreasuryManager contract)

        ↓ Auto-Distribution (@ 1 POL) ↓

├─ 40% → Rewards Pool
│  └─ Fallback if staking depletes
│
├─ 30% → Liquidity Pool
│  └─ Market-making & LP support
│
├─ 20% → Development Fund
│  └─ Features, infrastructure, salaries
│
└─ 10% → Community Incentives
   └─ Marketing, events, giveaways
```

### Economic Sustainability

**Why this works**:
1. **Multiple Revenue Streams**: Not dependent on one source
2. **Scaling**: More users = more transactions = more fees
3. **Smart Distribution**: Each pool serves a purpose
4. **No Token Printing**: Rewards come from fees, not inflation
5. **Fallback Safety**: Treasury ensures sustainability

---

## Contract Interaction Map

### Direct Calls (Synchronous)

```
Marketplace
    ├─→ Calls: EnhancedStaking.getBalance(user)
    ├─→ Calls: EnhancedStaking.calculateBoostedRewards(user)
    └─→ Calls: EnhancedStaking.hasAutoCompound(user)

EnhancedStaking
    ├─→ Calls: Treasury.receiveTokens(amount, "staking_commission")
    └─→ Calls: Marketplace.getUserLevel(user)

Both
    └─→ Call: Treasury.getPoolBalance(poolId)
```

### Event Emissions (Asynchronous)

```
EnhancedStaking emits:
├─ DepositCreated → Indexed for analytics
├─ RewardsClaimed → Indexed for tracking
├─ SkillActivated_Staking → Triggers skill sync
└─ BadgeAwarded → Indexed for achievements

Marketplace emits:
├─ NFTCreated → Indexed for NFT feed
├─ NFTSold → Indexed for volume tracking
├─ SkillActivated → Triggers Staking sync
├─ LevelUp → Indexed for leaderboards
└─ XPAwarded → Indexed for XP tracking

Treasury emits:
└─ DistributionTriggered → Indexed for accounting

All events → The Graph Subgraph → Frontend queries
```

---

## Execution Flow Examples

### Example 1: Complete User Journey (Simplified)

```
Hour 0:   User deposits 100 POL for 90 days
Hour 1:   System awards 10 XP (achievement)
Day 1:    Creates NFT (+10 XP)
Day 2:    Sells NFT (+20 XP) = Level Up!
Day 3:    Buys Skill NFT (+100 POL)
Day 4:    Activates Skill (+STAKE_BOOST_II)
Day 5:    APY changes from 43.8% → 53.8%
Day 90:   Lock-up period ends, can withdraw
Day 91:   User claims rewards:
          • Base: 100 × 0.00014 × 90 = 1.26 POL
          • Time bonus (+1%): 0.013 POL
          • Skill boost (+10%): 0.129 POL
          • Total: ~1.40 POL
          • Commission (6%): 0.084 POL
          • User gets: 1.31 POL
Day 91:   Treasury receives 0.084 POL
Day 91:   Treasury balance > 1 POL? 
          YES → Auto-distribute:
                ├─ 40% → Rewards pool
                ├─ 30% → Liquidity
                ├─ 20% → Dev fund
                └─ 10% → Community
```

### Example 2: Skill Activation Sequence

```
t=0:   User calls activateSkill(tokenId)
       ├─ Marketplace validates
       ├─ Adds skill to active list
       └─ Emits SkillActivated

t=1:   Staking listens to SkillActivated event
       ├─ Calls notifySkillActivation()
       ├─ Validates boost limits (OK)
       ├─ Updates user profile
       └─ Caches new APY

t=2:   Frontend refetches user data
       ├─ Queries getDashboardData()
       ├─ APY has changed: 43.8% → 53.8%
       ├─ Shows breakdown to user
       └─ Displays visual update

t=3:   Auto-claim reward (if enabled)
       ├─ System uses new APY for calc
       ├─ User enjoys boosted returns
       └─ All in real-time, no delays
```

---

## Failsafe Mechanisms

### Treasury Fallback Chain

If user earns rewards but contract balance is low:

```
Level 1: Try to pay from Staking contract balance
├─ Success → User receives rewards immediately
└─ Fail → Go to Level 2

Level 2: Request from Treasury Rewards Pool
├─ Success → Treasury sends, user receives
└─ Fail → Go to Level 3

Level 3: Defer reward + emit event
├─ Event: RewardDeferred(user, amount, reason)
├─ User can claim later when treasury replenished
└─ Amount is recorded and guaranteed

Result: User NEVER loses earned rewards, only timing changes
```

### Skill Boost Validation

```
User attempts to activate 5 STAKE_BOOST_III skills (20% each = 100%)
│
├─ Pre-activation check:
│  ├─ Current boost: 0%
│  ├─ New with all 5: 100%
│  ├─ Max allowed: 50%
│  └─ REJECTED: "Boost limit exceeded"
│
├─ User can instead:
│  ├─ Activate 2 skills (40% boost)
│  ├─ Deactivate one, activate another
│  └─ Mix with FEE_REDUCER skills for different benefit
│
└─ Result: System stays balanced, no exploits
```

---

## Performance Characteristics

### Gas Optimization

```
Common Operations:
├─ Deposit: ~90K gas = $0.24
├─ Claim Rewards: ~85K gas = $0.22
├─ Create NFT: ~120K gas = $0.31
├─ Buy NFT: ~150K gas = $0.39
└─ Activate Skill: ~95K gas = $0.25

Query Operations:
├─ getDashboardData(): Free (view function)
├─ getUserLevel(): Free
├─ getAPYRates(): Free
└─ Marketplace stats: Free
```

### Scalability

- **Current TPS**: 100+ transactions/sec (Polygon)
- **Target Scale**: 10,000+ users (current), 1M users (future)
- **Contract Size**: ~26KB (under Polygon 24KB limit when optimized)
- **Storage Growth**: ~35 bytes per deposit + ~100 bytes per NFT

---

## Future Architecture Plans

### Phase 2 (2027): Multi-Chain

```
        Ethereum (Main)
             │
        Bridge Protocol
       ↓    ↓    ↓    ↓
   Polygon Arbitrum Optimism Avalanche
```

### Phase 3 (2027): Governance DAO

```
Protocol controlled by community:
├─ Governance token (NUXC)
├─ Voting on parameters
├─ Community treasury management
└─ Decentralized upgrades
```

---

## Monitoring & Alerting

### Critical Metrics to Watch

```
Protocol Health:
├─ Treasury balance (< 5 POL = alert)
├─ Rewards pool (< 2 POL = alert)
├─ Total deposited (tracking growth)
└─ Active users (tracking engagement)

User Safety:
├─ Failed claims (should be 0)
├─ Rejected skills (tracking attempts)
├─ Deferred rewards (tracking payment delays)
└─ Emergency pauses (should never happen)

Economic Health:
├─ Daily commissions (should be > $100)
├─ APY sustainability (should be > 40%)
├─ Fee revenue (per source)
└─ Distribution efficiency (> 95%)
```

---

**© 2026 Nuxchain Protocol - Architecture Reference**

*For smart contract code, see `/contracts/`*  
*For detailed specs, see `SMART_CONTRACTS_REFERENCE.md`*  
*For contract-specific docs, see `/doc/contracts/`*

