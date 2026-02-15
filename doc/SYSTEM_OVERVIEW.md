# Nuxchain Protocol System Overview

**Última actualización**: Febrero 14, 2026  
**Versión del protocolo**: 5.0+ (Modular)

---

## Quick Summary

Nuxchain es un protocolo integrado en Polygon con:
- **Staking**: Depósitos con APY dinámico
- **Marketplace**: Trading de NFTs + Skill NFTs
- **Gamification**: XP, Levels, Quests, Badges
- **Treasury**: Distribución automática de comisiones

Todos los módulos están interconectados y comparten datos críticos en tiempo real.

---

## Arquitectura de Alto Nivel

```
USER
 │
 ├─ STAKING (Depósito POL)
 │  └─ EnhancedSmartStaking
 │     ├─ Core: Deposit/Withdraw/Rewards
 │     ├─ Gamification: XP/Levels/Badges  
 │     ├─ Rewards: APY calculations
 │     ├─ Skills: Boost multipliers
 │     └─ View: Query functions
 │
 ├─ MARKETPLACE (Trading NFTs)
 │  └─ GameifiedMarketplace
 │     ├─ Core: Buy/Sell/Offer
 │     ├─ Skills: Skill NFTs
 │     ├─ Quests: Quest NFTs
 │     ├─ Social: Likes/Comments
 │     ├─ Statistics: Volume tracking
 │     └─ Referral: Ref rewards
 │
 └─ BADGES (Rewards)
    └─ CollaboratorBadgeRewards
       ├─ Quests: Task completions
       ├─ Commission Pool: 25% ingresos
       └─ Claim: Con tiered fees

         ↓ [ALL routes]

    TREASURY MANAGER
    ├─ Recibe: comisiones NFT (6%)
    ├─ Recibe: comisiones marketplace (6%)
    ├─ Recibe: fees quest (variable)
    ├─ Distribuye: 7 días cíclico
    ├─ Reserves: 20% emergencia
    └─ Fallback: Sistema de emergencia
```

---

## Módulos Principales

### 1. Enhanced Smart Staking (Core)

**Responsabilidad**: Gestión de depósitos y recompensas

**Componentes Modulares**:
```
EnhancedSmartStaking (Core)
├─ Deposits: Aceptar POL, lock periods
├─ Withdrawals: Sacar con comisión 6%
├─ Rewards: Calcular basado en APY
└─ Commission: Enviar a Treasury

EnhancedSmartStakingRewards
├─ Base APYs: [197, 328, 591, 788, 1183] bps
├─ Dynamic APY: Via DynamicAPYCalculator
├─ Skill Boost: +X% de habilidades
└─ Calculation: (deposited amount × totalAPY × time)/365

EnhancedSmartStakingGamification
├─ Level Up: +1 nivel cada reclamo
├─ XP Tracking: Por depósito/retiro/compuesto
├─ Rewards: Bonus POL por nuevo nivel
├─ Badges: Validar estado de badge

EnhancedSmartStakingSkills
├─ Skill Types: FEE_REDUCER, LOCK_REDUCER, AUTO_COMPOUND
├─ Boosts: +X% reward por skill
└─ Validation: Verificar skills activas

EnhancedSmartStakingView
└─ Query Functions: getUserStakes, getRewardsEstimate, etc
```

**Estadísticas Clave**:
- Lockup periods: 0, 30, 90, 180, 365 days
- Base APYs: 19.7% to 118.3%
- Commission: 6% en retiros
- TVL auto-sinced a Rewards module

---

### 2. Gameified Marketplace

**Responsabilidad**: Trading de NFTs con gamification

**Componentes Modulares**:
```
GameifiedMarketplaceCoreV1 (< 24KB)
├─ State: NFT listings, offers, owners
├─ Actions: createNFT, listForSale, buyToken, acceptOffer
├─ Commission: 6% en cada venta
└─ Events: Todos los cambios emitidos

MarketplaceView
├─ Queries: getUserNFTs, getListedTokens, pagination
└─ Pagination: offset/limit pattern

MarketplaceStatistics
├─ Tracking: totalVolume, userVolume, royalties
└─ Updates: Después de cada compra

MarketplaceSocial
├─ Likes: Per NFT per user
├─ Comments: Texto + timestamp
└─ Events: LikeToggled, CommentAdded

GameifiedMarketplaceSkillsNft
├─ Skill NFTs: Minteable with effects
└─ Rarity: Common/Rare/Epic variants

GameifiedMarketplaceQuests
├─ Quests: Completables para rewards
└─ Rewards: POL directo
```

**Commission Flow**:
- NFT Sale (100 POL) → 6% commission (6 POL)
- 6% split: 25% Collaborators, 75% Treasury phases

---

### 3. Treasury Manager

**Responsabilidad**: Distribución centralizada de ingresos

**Income Sources**:
```
Staking Commission (6%)     ──┐
Marketplace Commission (6%)──┼──→ Treasury receives → Distribution
Quest Claim Fees (var)      ──┤
Individual Skills Sales     ──┘
         │
         ↓
    Reserve Fund (20%)  [Emergency-only]
    +
    Distributable (80%)
         │
         ├─ REWARDS pool        (30%)  → Quest rewards
         ├─ STAKING pool        (30%)  → APY sustainability
         ├─ COLLABORATORS pool  (25%)  → Badge holders
         └─ DEVELOPMENT pool    (15%)  → Operations
```

**Distribution Cycle**:
- Triggered: Weekly (7 days from first deposit)
- Accumulates: Revenue en el interim
- Fallback: `requestRewardFunds()` antes de esperar distribución

**Emergency Access**:
- `requestEmergencyFunds()`: Si solvencyRatio < 50%
- `notifyAPYCompression()`: Alerts cuando APY cae >5%
- Reserve: Only for critical protocols

---

### 4. Dynamic APY Calculator ✨

**Status**: ✅ NUEVO - Integrado en esta sesión

**Fórmula**:
```
dynamicAPY = baseAPY × sqrt(targetTVL / currentTVL)

Example:
- Target TVL: 1M POL
- Current TVL: 2M POL (2x target)
- Multiplier: sqrt(1M/2M) = sqrt(0.5) ≈ 0.707 = 70.7%
- Dynamic APY = 1183 × 0.707 ≈ 836 bps
```

**Integration Points**:
```
EnhancedSmartStaking
    ↓
deposit/withdrawAll calls _syncTVLToRewards()
    ↓
EnhancedSmartStakingRewards
    ↓
calculateStakingRewards() checks apyCalculator
    ↓
DynamicAPYCalculator
    ↓
Applies adjustment
    ↓
TreasuryManager (si compresión > 5%)
    ↓
Alert admin
```

---

## Data Flow Diagrams

### Staking Deposit Flow

```
User deposits 1000 POL (365 days)
    ↓
EnhancedSmartStaking.deposit()
    ├─ Calculate commission: 60 POL (6%)
    ├─ Net deposit: 940 POL
    ├─ Update totalPoolBalance: += 940
    ├─ Call _syncTVLToRewards() ← NEW
    │         └─ rewardsModule.updateCurrentTVL(totalPoolBalance)
    ├─ Emit Deposited event
    └─ Send commission to Treasury.receiveRevenue()

After 30 days, user calculates rewards:
    ↓
EnhancedSmartStakingRewards.calculateStakingRewards()
    ├─ Get base APY: 1183 bps (365-day)
    ├─ If apyCalculator set: Apply dynamic APY
    │   └─ checkAPYCalculator.calculateDynamicAPY(1183, currentTVL)
    │       └─ Might return 836 bps (if TVL 2x target)
    ├─ Add skill boosts: + 200 bps from skills
    ├─ Total APY: 836 + 200 = 1036 bps
    └─ Reward = 940 × 1036 × (30 days) / (365 days × 10000)
         = ~81 POL
```

### NFT Purchase Flow

```
User buys NFT for 100 POL
    ↓
GameifiedMarketplaceCoreV1.buyToken()
    ├─ Commission: 6 POL
    ├─ Royalty: N% (configurable)
    ├─ Owner receives: ~94 POL
    ├─ Update listing: remove from market
    ├─ Call statisticsModule.recordSale()
    │  └─ totalTradingVolume += 100
    └─ emit Sold event
    ↓
TreasuryManager.receiveRevenue(value: 6)
    ├─ totalRevenueReceived += 6
    ├─ Reserve allocation: 1.2 POL (20%)
    ├─ Distributable: 4.8 POL (80%)
    └─ Scheduled for distribution (7 day cycle)
    ↓
If CollaboratorBadgeRewards balance < pending:
    └─ claimRewards() calls requestEmergencyFunds()
       └─ Treasury provides from reserve if available
```

---

## Critical Integration Points

### 1. TVL Synchronization

**Flow**: Core → Rewards (real-time)

```solidity
// In EnhancedSmartStakingCore
totalPoolBalance += depositAmount;
_syncTVLToRewards();  // Updates Rewards module

// Allows DynamicAPYCalculator to use current TVL
```

### 2. Commission Distribution

**Flow**: All modules → Treasury → Pools

```
Staking commission (6%) → treasuryManager.receiveRevenue()
Marketplace commission (6%) → treasuryManager.receiveRevenue()
Quest fees → treasuryManager.receiveRevenue()
        ↓
TreasuryManager distributes weekly
```

### 3. Health Monitoring

**Flow**: Protocol → Treasury (optional alerts)

```
CollaboratorBadgeRewards.getContractHealth()
    ↓
If solvencyRatio < 50%:
    └─ claimRewards() attempts emergency funds
    └─ If fails: revert + emit CriticalStatus

DynamicAPYCalculator compression > 5%:
    └─ notifyAPYCompression() → Treasury
    └─ Treasury logs APYCompressionAlert
```

---

## Key Design Patterns

### 1. Modular Core

**Benefit**: Each module < 24KB (deployable separately)

```
Core contracts < 24KB:
├─ GameifiedMarketplaceCoreV1
├─ EnhancedSmartStakingCore
└─ Stateless library contracts

Separate modules:
├─ View, Statistics, Social (Marketplace)
├─ Gamification, Skills, View (Staking)
└─ Rewards, Treasury
```

### 2. Dependency Injection

**Benefit**: Flexible, upgradeable connections

```
protocol → Interface → Implementation

Example:
EnhancedSmartStakingRewards → IAPYCalculator → DynamicAPYCalculator
                                             → Or any other impl
```

### 3. Try-Catch Fallback

**Benefit**: Non-blocking errors

```solidity
try treasuryManager.receiveRevenue{value: fee}("type") {
    // Success
} catch {
    // Fail silently or revert depending on criticality
}
```

---

## Contract Deployments (Current)

| Contract | Address | Status | Size |
|----------|---------|--------|------|
| EnhancedSmartStaking | [CORE] | ✅ Live | ~18KB |
| EnhancedSmartStakingRewards | [REWARDS] | ✅ Live | <2KB |
| EnhancedSmartStakingGamification | [GAMIF] | ✅ Live | ~19KB |
| EnhancedSmartStakingSkills | [SKILLS] | ✅ Live | ~20KB |
| GameifiedMarketplaceCoreV1 | [MARKET] | ✅ Live | <24KB |
| DynamicAPYCalculator | [APY] | ✅ New | <4KB |
| TreasuryManager | [TREASURY] | ✅ Live | ~32KB |
| CollaboratorBadgeRewards | [BADGES] | ✅ Live | ~25KB |

---

## Events & Monitoring

### Critical Events to Monitor

```javascript
// Staking
Deposited(user, amount, lockupDays)
Withdrawn(user, netAmount)

// Marketplace
NFTCreated(owner, tokenId)
TokenSold(buyer, tokenId, price)
CommentAdded(user, tokenId)

// Treasury
RevenueReceived(source, amount, type)
DistributionTriggered(amount)
EmergencyFundingProvided(protocol, amount)
APYCompressionDetected(old, new, bps)

// GameificationLevelUp(user, newLevel, reward)
XPEarned(user, xpAmount, action)
```

---

## Common Operations

### For Users

```javascript
// Stake
stakingCore.deposit(365);  // 365 days lockup

// Claim rewards
stakingCore.withdraw();

// Buy NFT
marketplace.buyToken([tokenId, price]);

// Claim badge rewards
badgeRewards.claimRewards();
```

### For Admins

```javascript
// Create quest
badgeRewards.createQuest(description, reward, start, end, maxCompletions);

// Monitor health
badgeRewards.getContractHealth();
treasury.getDistributionTimeline();

// Emergency: Pause staking
stakingCore.pause();
```

---

## Next Steps & Roadmap

**Completed**:
- ✅ DynamicAPYCalculator integrated
- ✅ TVL auto-sync implemented
- ✅ Documentation consolidated

**Planned**:
- Multi-sig governance for parameter changes
- Oracle integration for TVL verification
- Timelock for critical functions
- AMM liquidity pools for POL
- Cross-chain bridges

---

**More Details**: See individual guides:
- [DynamicAPYCalculator.md](IMPLEMENTATION_GUIDES/DynamicAPYCalculator.md)
- [EmergencyFundSystem.md](IMPLEMENTATION_GUIDES/EmergencyFundSystem.md)
- [SMART_CONTRACTS_REFERENCE.md](SMART_CONTRACTS_REFERENCE.md)
- [contracts/](contracts/) for detailed per-contract docs
