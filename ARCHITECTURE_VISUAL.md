# 🏗️ NuxChain Protocol - Arquitectura Completa Visualizada

## Diagrama de Sistema Completo

```
╔════════════════════════════════════════════════════════════════════════════════════════╗
║                                                                                        ║
║                        🌟 NUXCHAIN V7.0 - FULL DeFi ECOSYSTEM 🌟                    ║
║                                                                                        ║
╚════════════════════════════════════════════════════════════════════════════════════════╝

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                         USER INTERFACE LAYER                                      ┃
┃  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐                 ┃
┃  │   Dashboard UI  │  │   NFT Gallery    │  │  Quest Explorer  │                 ┃
┃  │   (React/Vue)   │  │   (Marketplace)  │  │   (Leaderboard)  │                 ┃
┃  └────────┬────────┘  └────────┬─────────┘  └────────┬─────────┘                 ┃
┃           │                    │                     │                           ┃
┃           └────────────────────┼─────────────────────┘                           ┃
┃                                │                                                 ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
                                 │
                    MetaMask / Web3 RPC Connection
                                 │
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                ▼                                              ┃
┃          ╔═══════════════════════════════════════════════════════╗           ┃
┃          ║      CORE DeFi ORCHESTRATION LAYER                    ║           ┃
┃          ║                                                       ║           ┃
┃          ║     SmartStakingCore (Central Hub)                    ║           ┃
┃          ║     - Deposit Management                              ║           ┃
┃          ║     - Withdrawal Logic                                ║           ┃
┃          ║     - Reward Distribution                             ║           ┃
┃          ║     - Module Coordination                             ║           ┃
┃          ╚═══════════════════════════════════════════════════════╝           ┃
┃                  ▲          ▲           ▲          ▲           ▲             ┃
┃                  │          │           │          │           │             ┃
┃          ╔───────┴──┐  ╔────┴──────┐ ╔──┴────────┐ │ ╔────────┴┐            ┃
┃          │          │  │           │ │           │ │ │        │             ┃
┃  ┌──────▼────────┐ ┌▼─────────────┴─┴─────────┐ ┌─▼─▼──────┐ ┌▼────────┐    ┃
┃  │   REWARDS     │ │   POWER BOOST MODULE     │ │ MARKETING │ │ INTERNAL │    ┃
┃  │   CALCULATOR  │ │  (Skill NFT Boosters)    │ │ MODULE    │ │ METRICS  │    ┃
┃  │               │ │                          │ │           │ │          │    ┃
┃  │ • Daily Calc  │ │ • Skill Slot Manager     │ │ • Social  │ │ • Stats  │    ┃
┃  │ • APY Engine  │ │ • +10-35% APY bonus      │ │ • Likes   │ │ • Vol    │    ┃
┃  │ • Rate Table  │ │ • Stacking Logic         │ │ • Comments│ │ • Users  │    ┃
┃  └──────────────┘ └────────────────────────────┘ └────────────┘ └──────────┘    ┃
┃                                                                                 ┃
┃  ┌──────────────────────────────────────────────────────────────────────────┐  ┃
┃  │         GAMIFICATION ENGINE                                              │  ┃
┃  │  ┌─────────────┐  ┌────────────┐  ┌──────────┐  ┌─────────────────┐    │  ┃
┃  │  │   XP SYSTEM │  │    QUESTS  │  │  STREAKS │  │     BADGES      │    │  ┃
┃  │  │ (15 sources)│  │  (QuestCore)  │(7-2000x) │  │ (5+ categories) │    │  ┃
┃  │  └─────────────┘  └────────────┘  └──────────┘  └─────────────────┘    │  ┃
┃  │                                                                          │  ┃
┃  │  ┌─────────────┐  ┌────────────┐  ┌──────────┐  ┌─────────────────┐    │  ┃
┃  │  │ LEADERBOARDS│  │  LEVELS    │  │ACHIEVEMENTS      REFERRAL     │    │  ┃
┃  │  │ (On-chain)  │  │ (1-50)     │  │(Unlockable)   │   SYSTEM    │    │  ┃
┃  │  └─────────────┘  └────────────┘  └──────────┘  └─────────────────┘    │  ┃
┃  └──────────────────────────────────────────────────────────────────────────┘  ┃
┃                                                                                 ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
┏━━━━━━━┴━━━━━━━━━━━┓  ┏━━━━━━━━┴━━━━━━━━━┓  ┏━━━━━━━━━┴━━━━━━━━━┓
┃                   ┃  ┃                 ┃  ┃                   ┃
┃  MARKETPLACE HUB  ┃  ┃  NFT ECOSYSTEM  ┃  ┃   TREASURY MGR    ┃
┃                   ┃  ┃                 ┃  ┃                   ┃
┃ ┌───────────────┐ ┃  ┃ ┌─────────────┐ ┃  ┃ ┌───────────────┐ ┃
┃ │ P2P Trading   │ ┃  ┃ │ NuxAgentNFT │ ┃  ┃ │Revenue Intake │ ┃
┃ │ (Buy/Sell)    │ ┃  ┃ │ (ERC-6551)  │ ┃  ┃ │               │ ┃
┃ └───────────────┘ ┃  ┃ └─────────────┘ ┃  ┃ └───────────────┘ ┃
┃                   ┃  ┃                 ┃  ┃                   ┃
┃ ┌───────────────┐ ┃  ┃ ┌─────────────┐ ┃  ┃ ┌───────────────┐ ┃
┃ │ Auction (Bids)│ ┃  ┃ │TBA Wallets  │ ┃  ┃ │Distribution   │ ┃
┃ │ (ERC-721)     │ ┃  ┃ │ (Agent $)   │ ┃  ┃ │ Engine        │ ┃
┃ └───────────────┘ ┃  ┃ └─────────────┘ ┃  ┃ └───────────────┘ ┃
┃                   ┃  ┃                 ┃  ┃                   ┃
┃ ┌───────────────┐ ┃  ┃ ┌─────────────┐ ┃  ┃ ┌───────────────┐ ┃
┃ │ Rental System │ ┃  ┃ │ Skill NFTs  │ ┃  ┃ │Emergency      │ ┃
┃ │ (Temp Access) │ ┃  ┃ │ (Multi-lvl) │ ┃  ┃ │ Circuit Breaker│ ┃
┃ └───────────────┘ ┃  ┃ └─────────────┘ ┃  ┃ └───────────────┘ ┃
┃                   ┃  ┃                 ┃  ┃                   ┃
┃ 6% Commission     ┃  ┃ 1-50% Royalties ┃  ┃ Multi-Pool Dist   ┃
┗━━━━━━━━━━━━━━━━━━┛  ┗━━━━━━━━━━━━━━━━┛  ┗━━━━━━━━━━━━━━━━━━┛
        │                        │                        │
        └────────────────┬───────┴────────┬────────────────┘
                         │                │
                         ▼                ▼
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃              TOKEN STANDARD COMPLIANCE LAYER                    ┃
┃                                                                 ┃
┃  ┌─────────────────────────────────────────────────────────┐  ┃
┃  │  ERC-20: POL (Platform Token) - Native Polygon         │  ┃
┃  └─────────────────────────────────────────────────────────┘  ┃
┃                                                                 ┃
┃  ┌─────────────────────────────────────────────────────────┐  ┃
┃  │  ERC-721: NFTs (Agent, Skill, Tickets)                 │  ┃
┃  │           + ERC-721-URIStorage (Metadata)              │  ┃
┃  └─────────────────────────────────────────────────────────┘  ┃
┃                                                                 ┃
┃  ┌─────────────────────────────────────────────────────────┐  ┃
┃  │  ERC-2981: Royalties (Secondary Market)                │  ┃
┃  └─────────────────────────────────────────────────────────┘  ┃
┃                                                                 ┃
┃  ┌─────────────────────────────────────────────────────────┐  ┃
┃  │  ERC-6551: Token Bound Accounts (Agent Wallets)        │  ┃
┃  └─────────────────────────────────────────────────────────┘  ┃
┃                                                                 ┃
┃  ┌─────────────────────────────────────────────────────────┐  ┃
┃  │  ERC-7662: AI Agent Prompts (Encrypted IPFS)           │  ┃
┃  └─────────────────────────────────────────────────────────┘  ┃
┃                                                                 ┃
┃  ┌─────────────────────────────────────────────────────────┐  ┃
┃  │  ERC-8004: Agent Registry (Capabilities)               │  ┃
┃  └─────────────────────────────────────────────────────────┘  ┃
┃                                                                 ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
                         │
                         ▼
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃          BLOCKCHAIN LAYER - POLYGON (Chain 137)                ┃
┃                                                                 ┃
┃  ┌─────────────┐  ┌──────────┐  ┌──────────────────────────┐ ┃
┃  │   RPC Node  │  │ Gas Relay│  │ Proof of Stake (PoS)     │ ┃
┃  │ (Alchemy)   │  │ (Relayer)│  │ Consensus                │ ┃
┃  └─────────────┘  └──────────┘  └──────────────────────────┘ ┃
┃                                                                 ┃
┃  Ultra-low fees: ~$0.01 per transaction                        ┃
┃  Finality: ~2 seconds                                          ┃
┃  Network: Algorand sidechain of Ethereum                       ┃
┃                                                                 ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

---

## Flujo de Depósito y Ganancias

```
USER DEPOSITS 100 POL
        │
        ▼
┌──────────────────────────────────────┐
│  SmartStakingCore.deposit()           │
│                                      │
│  ✓ Valida cantidad (10-10,000)       │
│  ✓ Registra timestamp y lockup       │
│  ✓ Calcula APY base                  │
│  ✓ Actualiza pool balance            │
└──────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────┐
│  APY Calculation (24h)                │
│                                      │
│  Base APY = (Daily Revenue / Pool)   │
│           × 365 × 100                │
│                                      │
│  Base = 43.8%                        │
└──────────────────────────────────────┘
        │
        ▼
╔─ BONUS STACKING ─────────────────────╗
║                                      ║
║  Lockup Bonus      +0% → +50%        ║
║  × 1.0 - 1.50x                      ║
║                                      ║
║  Skill Boosts      +0% → +35%        ║
║  × 1.0 - 1.35x (up to 5 skills)     ║
║                                      ║
║  Referral Boost    +1.5% per ref     ║
║  × 1.0 - 1.15x (max 10 refs)        ║
║                                      ║
║  Streak Bonus      +0% → +100%       ║
║  × 1.0 - 2.0x (30+ days)            ║
║                                      ║
║  TOTAL MULTIPLIER = up to 4.73x      ║
║  FINAL APY = 43.8% × 4.73 ≈ 207%   ║
║                                      ║
╚──────────────────────────────────────╝
        │
        ▼
┌──────────────────────────────────────┐
│  Rewards Accrue (Real-Time)          │
│                                      │
│  Day 1   +$0.12    (100 × 43.8% / 365) × bonus
│  Day 2   +$0.24
│  Day 3   +$0.36
│  ...                                │
│  Day 365 +$43.80 (at 43.8% base)   │
│                                      │
│  Total with bonus: ~$207 earned!    │
└──────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────┐
│  User Claims Rewards                  │
│                                      │
│  Raw Rewards: $43.80                 │
│                                      │
│  ├─ User opt: 100% payout           │
│  │  → $43.80 transferred            │
│  │  → Total balance: $143.80        │
│  │                                  │
│  ├─ User opt: 50% reinvest          │
│  │  → Reinvest: $21.90              │
│  │  → Payout: $21.90                │
│  │  → New dep: 100 + 21.90 = $121.90│
│  │  → Accuracy fee: -0.05           │
│  │                                  │
│  └─ User opt: 100% auto-compound    │
│     → Reinvest: $43.80              │
│     → Fee: -0.11                    │
│     → New deposit: $143.69          │
│                                      │
│  BONUS: +10 XP for claiming         │
│  BONUS: +10 XP for compounding      │
│                                      │
└──────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────┐
│  Commission Distribution (6%)         │
│                                      │
│  From $43.80 earned:                 │
│                                      │
│  Commission: $2.63 (6%)              │
│                                      │
│  ├─ 30% → Rewards Fund = $0.79      │
│  ├─ 25% → Staking Fund = $0.66      │
│  ├─ 20% → Collaborators = $0.53     │
│  ├─ 15% → Development = $0.39       │
│  ├─ 10% → Marketplace = $0.26       │
│  └─ 20% → Reserve = $0.52 (always!)│
│                                      │
│  All go to Treasury (auto-distribute)
└──────────────────────────────────────┘
        │
        ▼
    USER IS RICHER! 💰
```

---

## Flujo de Marketplace y Quests

```
USER SCENARIO: John quiere ganar XP y recompensas

STEP 1: John crea un NFT
┌────────────────────────────────────────┐
│ MarketplaceCore.createNFT()            │
│                                        │
│ ✓ Genera tokenId                      │
│ ✓ Almacena metadata (IPFS)            │
│ ✓ Otorga NFT a John                   │
│ ✓ XPHub.awardXP(+10 XP)               │
│ ✓ Le informa a QuestCore              │
└────────────────────────────────────────┘
        │
        ▼
EVENTS TRIGGERED:
- TokenCreated (blockchain event)
- UserAcquired (on marketplace)
- LevelingSystem.awardXP() processed
- QuestCore.notifyAction(CREATE)
- Gamification.onAction() streak updated

JOHN GAINS:
- 1 NFT ✓
- +10 XP ✓
- Quest progress for "Creator" ✓
- +1 streak day ✓

STEP 2: John lista el NFT a venta
┌────────────────────────────────────────┐
│ MarketplaceCore.list(tokenId, price)   │
│                                        │
│ ✓ Fija precio                         │
│ ✓ Va a marketplace                    │
│ ✓ Crea snapshot para analytics        │
└────────────────────────────────────────┘

STEP 3: Jane compra el NFT
┌────────────────────────────────────────┐
│ MarketplaceCore.buy(tokenId)           │
│                                        │
│ Jane paga $10 (variable)              │
│                                        │
│ COMMISSION (6%): $0.60               │
│ ├─ $0.36 → Seller (John)             │
│ ├─ $0.24 → Treasury                  │
│                                        │
│ John recibe: $9.60 actual            │
└────────────────────────────────────────┘

JANE GAINS:
- +5 XP (for purchase)
- +1 streak day
- Quest progress for "Buyer"

JOHN GAINS:
- $9.64 in wallet
- +0 XP (seller, no XP)

STEP 4: QuestCore scores progress
┌────────────────────────────────────────┐
│ userQuestProgress["John"]["quest #3"]  │
│                                        │
│ Quest: "Create 5 NFTs"                │
│ ├─ Progress: 1/5 ✓                   │
│ ├─ Status: IN_PROGRESS                │
│ └─ Reward pending: 25 XP + 5 POL     │
│                                        │
│ Quest: "Earn $100 from sales"         │
│ ├─ Progress: $9.64/100 ✓             │
│ ├─ Status: IN_PROGRESS                │
│ └─ Reward pending: 50 XP + 10 POL    │
└────────────────────────────────────────┘

STEP 5: John completes a quest
┌────────────────────────────────────────┐
│ QuestCore.completeQuest(questId)       │
│                                        │
│ ✓ Valida progress >= requirement     │
│ ✓ Marca como COMPLETED                │
│ ✓ Calcula rewards                     │
│ └─ 25 XP + 5 POL                     │
│                                        │
│ QuestRewardsPool.distributeReward()    │
│ └─ Transfiere 5 POL a John           │
│                                        │
│ LevelingSystem.awardXP(25 XP)         │
│ └─ +25 XP aplicado                    │
└────────────────────────────────────────┘

STEP 6: Level up detection
┌────────────────────────────────────────┐
│ LevelingSystem.updateProfile()         │
│                                        │
│ Old Level: 1 (0 XP)                   │
│ New XP: 10 + 5 + 25 = 40 XP          │
│                                        │
│ Level up? NO (need 50 for L2)        │
│ Progress: 40/50 (80%)                │
│                                        │
│ But! Streak is 7 days → 1.1x XP     │
│ Effective XP: 40 × 1.1 = 44 XP      │
│                                        │
│ Still Level 1 (need 55 with streak)  │
└────────────────────────────────────────┘

FINAL RESULT FOR JOHN:
✅ 1 NFT created
✅ +40 XP earned
✅ +$9.64 from sale
✅ +5 POL from quest
✅ 7-day streak active
✅ +1.1x XP multiplier
✅ 1 quest completed
✅ Progress toward badges
✅ Leaderboard updated
✅ Dashboard shows activity
```

---

## Topología de Contratos Inteligentes

```
NUXCHAIN SMART CONTRACT TOPOLOGY

Level 0: Core Proxy Pattern (UUPS Upgradeable)
┌─────────────────────────────────────┐
│  TransparentProxy / ProxyAdmin       │
│  └─ Delegates to Implementation      │
│     (Can be upgraded by UPGRADER)    │
└─────────────────────────────────────┘

Level 1: Main Contracts (Proxy-protected)
┌──────────────┬──────────────┬──────────────┐
│SmartStaking  │ Marketplace  │ TreasuryMgr  │
│   Core       │    Core      │              │
└──────┬───────┴──────┬───────┴──────────────┘
       │              │
       ▼              ▼

Level 2: Module Contracts
┌─────────────────────────────────────┐
│ SmartStakingRewards (Library-based) │
│ SmartStakingPower                   │
│ DynamicAPYCalculator                │
│ Gamification                        │
│ QuestCore                           │
│ LevelingSystem (IXPHub)             │
└─────────────────────────────────────┘
       │
       ▼

Level 3: Specialized Modules
┌──────────────┬──────────────┬──────────────┐
│  NFT Modules │ Treasury Pls │ Aux Modules  │
│              │              │              │
│ NuxAgentNFT  │ QuestRewards │ ReferralSys  │
│ NuxAgentRent │ Pool         │ Leveling     │
│ Auction      │              │              │
│ MarketplaceS │ Collab       │ NuxTapGame   │
│ ocial        │ BadgeRewards │              │
└──────────────┴──────────────┴──────────────┘

Security Features Active:
┌─────────────────────────────────────┐
│ ✅ ReentrancyGuard (all transfers)  │
│ ✅ AccessControl RBAC (ADMIN_ROLE)  │
│ ✅ Pausable emergency (onlyOwner)   │
│ ✅ Initialization (only once)       │
│ ✅ Parameter validation (all inputs)│
│ ✅ Event logging (audit trail)      │
│ ✅ Circuit breaker (APY anomalies)  │
│ ✅ Time locks (critical functions)  │
└─────────────────────────────────────┘
```

---

## Data Flow: Complete User Journey

```
                    🟢 USER JOINS NUXCHAIN 🟢

                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
            SIGN UP              FUND WALLET
        ┌──────────────┐       ┌──────────────┐
        │ Create       │       │ Buy POL from │
        │ profile id   │       │ exchange     │
        │ on-chain     │       │              │
        └──────────────┘       └──────────────┘
                │                       │
                └───────────┬───────────┘
                            ▼
                    DEPOSIT 100 POL
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
    COMPOUND         BUY SKILLS          CREATE NFT
    ┌──────────┐    ┌──────────┐        ┌──────────┐
    │ Auto     │    │ 1-5 NFTs │        │ Mint on  │
    │ reinvest │    │ 5 prefs  │        │ Market   │
    │ rewards  │    │ 1.1-1.8x │        │ +10 XP   │
    └──────────┘    │ +APY     │        └──────────┘
                    └──────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
            SOCIAL             COMPLETE QUESTS
        ┌──────────────┐       ┌──────────────┐
        │ Like/Comment │       │ Track quest  │
        │ +2 XP each   │       │ progress     │
        │ Streak +1day │       │ Claim reward │
        └──────────────┘       │ +XP + $POL   │
                               └──────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
            LEVEL UP            UNLOCK BADGES
        ┌──────────────┐       ┌──────────────┐
        │ L1-L50       │       │ 5+ types     │
        │ +1-5 POL     │       │ Achievements │
        │ per level    │       │ Cosmetics    │
        └──────────────┘       │ Status       │
                               └──────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
            TRADE NFTs          REFER FRIENDS
        ┌──────────────┐       ┌──────────────┐
        │ Buy/Sell     │       │ Share ref    │
        │ Auction      │       │ link         │
        │ Rent         │       │ +1.5% APY    │
        │ +5 XP        │       │ per friend   │
        └──────────────┘       └──────────────┘
                            │
                            ▼
                    PASSIVE INCOME FLOW
                    ┌──────────────────────────┐
                    │  Every block (2.3 sec)   │
                    │  Rewards calculated      │
                    │  No action needed!       │
                    │                          │
                    │  Users see balance grow  │
                    │  24/7/365                │
                    │                          │
                    │  Dashboard auto-updates  │
                    │  Real-time metrics       │
                    └──────────────────────────┘
                    │
                    ▼
    USER BECOMES SUCCESSFUL NUXCHAINER! 🚀
    ├─ $100 initial → $273+ after year
    ├─ Level 15+ unlocked
    ├─ 5 Badges earned
    ├─ 50+ XP from quests
    ├─ 10+ referrals
    └─ Community reputation ⭐⭐⭐⭐⭐
```

---

## Treasury Distribution Cycle

```
┌─────────────────────────────────────────────────────────┐
│                 REVENUE COLLECTION (Daily)              │
│                                                         │
│  ├─ Staking Commission (6% of user rewards)            │
│  ├─ Marketplace Fees (6% of trades)                    │
│  ├─ NFT Minting Revenue (10-50% of mint price)         │
│  ├─ Rental Payments (% of rental duration)             │
│  └─ Auction Commissions (5% of bids)                   │
│                                                         │
│  ▼                                                      │
│  Accumulates in TreasuryManager.receiveFunds()         │
│                                                         │
└────────────────┬──────────────────────────────────────┘
                 │
        ┌────────┴─────────┐
        │                  │
    Every 7 Days        When Triggered
        │                  │
        ▼                  ▼
AUTO-DISTRIBUTION    EMERGENCY DISTRIBUTION
    (Weekly)            (Manual by Admin)
        │                  │
        ├─ RESERVES ────► Reserve Fund (20%)
        │    ↓
        ├─ REWARDS ────► QuestRewardsPool
        │    │ (30%)    └─ Pending claims
        │    │
        ├─ STAKING ────► StakingTreasury
        │    │ (25%)    └─ APY sustainability
        │    │
        ├─ DEVELOPMENT ─► Dev Treasury
        │    │ (15%)     └─ Operations
        │    │
        ├─ COLLABORATORS ─► CollabBadgeRewards
        │    │ (20%)     └─ Badge payouts
        │    │
        └─ MARKETPLACE ─► MarketplaceTreasury
             (10%)      └─ Operations
             
        Distribution events fired ✓
        All balances updated ✓
        Leaderboards refreshed ✓

STATUS MONITORING:
├─ Protocol Health Score
│  ├─ Healthy: >30% budget remaining
│  ├─ Unstable: 10-30% buffer
│  └─ Emergency: <10% (circuit breaker ON)
│
├─ Reserve Adequacy
│  ├─ Optimal: 20% of total TVL
│  ├─ Warning: 10-20%
│  └─ Critical: <10%
│
└─ APY Sustainability
   ├─ Target APY: 75%
   ├─ Warning: >100%
   └─ Anomaly: 250%+ (circuit breaker)
```

---

## API Endpoint Reference

```
🔑 MAIN FUNCTIONS

STAKING
├─ deposit(amount, lockupDays)          → Deposit POL
├─ withdraw(depositIndex, amount)       → Withdraw partial
├─ withdrawAll()                        → Withdraw all
├─ compound(depositIndex)               → Reinvest rewards
├─ claimRewards(depositIndex)           → Claim as POL
└─ setReinvestmentPercentage(percent)   → Auto-compound %

MARKETPLACE
├─ createNFT(uri, royaltyBps)           → Mint NFT (10 XP)
├─ listNFT(tokenId, price)              → List for sale
├─ buyNFT(tokenId)                      → Purchase NFT (5 XP)
├─ placeOffer(tokenId, amount)          → Make offer
├─ acceptOffer(tokenId, offerId)        → Accept offer
├─ toggleLike(tokenId)                  → Like NFT (2 XP)
└─ addComment(tokenId, text)            → Comment (2 XP)

QUESTS
├─ createQuest(type, requirement, reward) → Admin only
├─ completeQuest(questId)               → Claim rewards
├─ getQuestProgress(user, questId)      → Check progress
└─ getUserCompletedQuests(user)          → History

GAMIFICATION
├─ getUserProfile(user)                 → XP, Level, Badges
├─ getLevelupReward(level)              → POL amount for level
├─ getUserBadges(user)                  → Array of badges
├─ getStreakMultiplier(user)             → Current 1x-2x
└─ setAutoCompound(threshold, enabled)  → Configure auto

REFERRAL
├─ registerReferral(referrer)           → Link referrer
├─ getReferralCount(user)               → # of referrals
├─ getReferralBoost(user)               → +% APY from refs
└─ claimReferralRewards(user)           → Collect bonus

TREASURY (ADMIN)
├─ setAllocation(fundType, percent)     → Configure split
├─ triggerDistribution()                → Manual payout
├─ getProtocolHealth()                  → Status check
├─ activateCircuitBreaker()             → Emergency pause
└─ withdrawFromReserve(amount, reason)  → Emergency fund
```

---

## Seguridad y Auditoría

```
╔═══════════════════════════════════════════════════════╗
║           SECURITY AUDIT CHECKLIST                    ║
╚═══════════════════════════════════════════════════════╝

STANDARD PROTECTIONS ✅
┌───────────────────────────────────────────────────────┐
│ ✅ ReentrancyGuard          │ Prevents re-entrance    │
│ ✅ AccessControl            │ RBAC granular          │
│ ✅ Pausable                 │ Emergency stop         │
│ ✅ Initializable (UUPS)     │ Only init once         │
│ ✅ Parameter validation     │ All inputs checked     │
│ ✅ Event logging            │ Full audit trail       │
│ ✅ SafeMath (built-in)      │ No overflows/underflow │
│ ✅ Time locks               │ Critical delays        │
└───────────────────────────────────────────────────────┘

ADVANCED PROTECTIONS ⚡
┌───────────────────────────────────────────────────────┐
│ ✅ Circuit Breaker          │ Halts on anomalies     │
│ ✅ Withdrawal Limits        │ Rate limiting          │
│ ✅ Daily Limits             │ Max $2,000/day          │
│ ✅ Early Exit Fee           │ 0.5% within 7 days    │
│ ✅ Auto-compound Fee        │ 0.25% on compounding  │
│ ✅ Reserve Accumulation     │ Always 20% set aside  │
│ ✅ Async Rewards            │ Deferred if low funds │
│ ✅ OpenZeppelin Audited     │ Battle-tested libs    │
└───────────────────────────────────────────────────────┘

VERIFIED ON NETWORK ✓
┌───────────────────────────────────────────────────────┐
│ ✓ All contracts on PolygonScan                       │
│ ✓ Source code visible                                │
│ ✓ Constructor args verified                          │
│ ✓ Proxy patterns documented                          │
│ ✓ Gas optimization profile                           │
│ ✓ No hidden functions                                │
└───────────────────────────────────────────────────────┘

NEXT STEPS FOR SECURITY 🔒
┌───────────────────────────────────────────────────────┐
│ ⏳ Third-party audit (Recommended)                    │
│ ⏳ Formal verification (Optional)                     │
│ ⏳ Bounty program (Future)                            │
│ ⏳ Annual re-audit                                     │
└───────────────────────────────────────────────────────┘
```

---

**Last Updated:** April 1, 2026  
**Version:** 5.0+ Architecture Diagrams  
**Network:** Polygon (Chain 137)  
**Status:** Production-Ready ✅
