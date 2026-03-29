# Smart Staking Contracts

**12 contracts (1 library + 11 deployable)**

---

## Overview

The staking system lets users deposit POL and earn dynamic APY rewards. It is organized as a hub-and-spoke architecture: `SmartStakingCoreV2` is the central proxy that delegates to specialized modules.

```
SmartStakingCoreV2 (UUPS proxy)
    ├── SmartStakingRewards     — APY calc + reward payouts
    ├── SmartStakingPower       — NFT power activation + rarity boosts
    ├── SmartStakingGamification — XP + level tracking
    └── DynamicAPYCalculator    — Optional TVL-based APY adjustment

SkillViewLib (external library)  — Linked into Core at deploy time

View contracts (read-only, no storage):
    ├── SmartStakingViewCore      — User deposits + balances
    ├── SmartStakingViewStats     — Pool stats + APY table
    ├── SmartStakingViewSkills    — Active powers + metrics
    └── SmartStakingViewDashboard — Full dashboard in one call
```

---

## SmartStakingCoreV2

**Type:** UUPS Proxy (Ownable + Pausable + ReentrancyGuard)  
**Version:** v7.0  
**Deploy:** `upgrades.deployProxy(factory, [TREASURY_ADDRESS], { kind: "uups" })`  
**Library:** Must link `SkillViewLib` in factory options

### Constants

| Name | Value | Description |
|---|---|---|
| `COMMISSION_PERCENTAGE` | 600 (6%) | Taken from rewards and sent to treasury |
| `MAX_DEPOSIT` | 100,000 POL | Per-user deposit cap |
| `MIN_DEPOSIT` | 10 POL | Minimum deposit amount |
| `DAILY_WITHDRAWAL_LIMIT` | 2,000 POL | Per-day withdrawal cap per user |
| `MAX_DEPOSITS_PER_USER` | 400 | Max concurrent deposit entries |
| `MAX_ACTIVE_SKILL_SLOTS` | 5 | Max simultaneous active NFT powers |
| `EARLY_EXIT_FEE_BPS` | 50 (0.5%) | Fee on principal for flexible exit within 7 days |
| `AUTOCOMPOUND_FEE_BPS` | 25 (0.25%) | Fee on rewards when auto-compounding |

### Lockup Periods

| Duration | Base APY |
|---|---|
| 0 (Flexible) | 8.60% |
| 30 days | 14.60% |
| 90 days | 19.30% |
| 180 days | 24.20% |
| 365 days | 25.50% |

*APY can increase via power boosts, tier bonuses, and loyalty bonuses (see [integration/REWARDS.md](../integration/REWARDS.md)).*

### Key Structs

```solidity
struct Deposit {
    uint128 amount;
    uint64  timestamp;
    uint64  lastClaimTime;
    uint64  lockupDuration;
}

struct User {
    Deposit[] deposits;
    uint128   totalDeposited;
    uint64    lastWithdrawTime;
}
```

### Key State Variables

```solidity
address public treasury;               // Owner fee address
ITreasuryManager public treasuryManager;
uint256 public totalPoolBalance;       // Sum of all active deposits
uint256 public uniqueUsersCount;

ISmartStakingRewards public rewardsModule;
ISmartStakingPower   public powerModule;
ISmartStakingGamification public gamificationModule;

mapping(address => bool) public authorizedMarketplaces;
mapping(PowerType => bool) private _powerEnabled;  // per-power enable/disable
```

### Core User Functions

```solidity
// Deposit POL with optional lockup (0 = flexible)
function deposit(uint256 lockupDuration) external payable

// Withdraw all unlocked deposits
function withdraw() external

// Withdraw a single deposit by index
function withdrawByIndex(uint256 depositIndex) external

// Claim rewards without withdrawing principal
function claimRewards() external

// Auto-compound: re-stake pending rewards as a new deposit
function compound() external

// Emergency withdrawal (no rewards, forfeits any earned)
function emergencyWithdraw() external

// Migrate a flexible deposit to a longer lockup
function migrateLockup(uint256 depositIndex, uint64 newLockupDuration) external

// Set partial reinvestment % for future claims (0–10000 bps)
function setReinvestmentPercentage(uint256 percentage) external

// Register a referrer (one-time)
function setReferrer(address referrer) external
```

### Admin Functions

```solidity
function setRewardsModule(address _rewards) external onlyOwner
function setPowerModule(address _power) external onlyOwner
function setGamificationModule(address _gamification) external onlyOwner
function setTreasuryManager(address _manager) external onlyOwner
function setTreasury(address _treasury) external onlyOwner
function setAuthorizedMarketplace(address mkt, bool authorized) external onlyOwner
function setPowerEnabled(PowerType powerType, bool enabled) external onlyOwner
function setQuestCore(address _questCore) external onlyOwner
function setDynamicAPYCalculator(address _calc) external onlyOwner
function pause() / unpause() external onlyOwner
function setCircuitBreaker(bool enabled, uint256 reserveRatio) external onlyOwner
function setReferralConfig(uint256 boostBps, uint256 duration) external onlyOwner
```

### Key Events

```solidity
event Deposited(address indexed user, uint256 amount, uint256 lockupDuration);
event Withdrawn(address indexed user, uint256 amount);
event Compounded(address indexed user, uint256 amount);
event EmergencyWithdrawal(address indexed user, uint256 amount);
event WithdrawnByIndex(address indexed user, uint256 indexed depositIndex, uint256 principal, uint256 rewards);
event ModuleUpdated(uint8 indexed moduleId, address indexed oldModule, address indexed newModule);
event PowerDisabled(PowerType powerType);  // Custom error — also event name
event ReferralRegistered(address indexed referrer, address indexed referee);
event EarlyExitFeePaid(address indexed user, uint256 feeAmount);
event AutocompoundFeePaid(address indexed user, uint256 feeAmount);
event LockupMigrated(address indexed user, uint256 indexed depositIndex, uint64 newLockupDuration);
```

### Key Errors

```solidity
error DepositTooLow(uint256 provided, uint256 minimum);
error DepositTooHigh(uint256 provided, uint256 maximum);
error MaxDepositsReached(address user, uint16 maxDeposits);
error FundsAreLocked();
error DailyWithdrawalLimitExceeded(uint256 availableToWithdraw);
error PowerDisabled(PowerType powerType);
error CircuitBreakerActive();
error AutoCompoundNotEnabled();
```

---

## SmartStakingRewards

**Type:** Plain (Ownable + ReentrancyGuard)  
**Deploy:** `new SmartStakingRewards()`

Handles APY calculation and payout when users claim or withdraw. Reads active powers from `SmartStakingPower` to apply rarity multipliers.

### APY Bonus Tiers

| Staked Amount | Tier | APY Bonus |
|---|---|---|
| < 100 POL | Bronze | +0% |
| 100 – 999 POL | Silver | +0.25% |
| 1,000 – 9,999 POL | Gold | +0.75% |
| ≥ 10,000 POL | Platinum | +1.50% |

### Loyalty Bonuses (continuous staking time)

| Duration | APY Bonus |
|---|---|
| 90+ days | +0.25% |
| 180+ days | +0.50% |
| 365+ days | +1.00% |

### Admin Functions

```solidity
function setCoreStakingContract(address _core) external onlyOwner
function setPowerModule(address _power) external onlyOwner
function setGamificationModule(address _gam) external onlyOwner
function setTreasuryManager(address _manager) external onlyOwner
function setAPYCalculator(address _calc) external onlyOwner
function setQuestRewardsPool(address _pool) external onlyOwner
function recordStakingSince(address user, uint256 timestamp) external  // only core
function clearStakingSince(address user) external                       // only core
```

---

## SmartStakingPower

**Type:** Plain (Ownable)  
**Deploy:** `new SmartStakingPower()`  
**Was formerly:** `SmartStakingSkills`

Tracks which NFT powers each user has activated. Applies rarity multipliers to determine effective boost values.

### PowerType Enum (20 values)

```solidity
enum PowerType {
    NONE,              // 0  — No power
    STAKE_BOOST_I,     // 1  — +5% APY
    STAKE_BOOST_II,    // 2  — +10% APY
    STAKE_BOOST_III,   // 3  — +20% APY
    AUTO_COMPOUND,     // 4  — Automatic compounding
    LOCK_REDUCER,      // 5  — -25% lock time
    FEE_REDUCER_I,     // 6  — -10% platform fees
    FEE_REDUCER_II,    // 7  — -25% platform fees
    PRIORITY_LISTING,  // 8  — Featured listing
    BATCH_MINTER,      // 9  — Batch NFT minting
    VERIFIED_CREATOR,  // 10 — Verified badge
    INFLUENCER,        // 11 — 2x like/comment weight
    CURATOR,           // 12 — Create featured collections
    AMBASSADOR,        // 13 — 2x referral bonus
    VIP_ACCESS,        // 14 — Exclusive drops access
    EARLY_ACCESS,      // 15 — 24h early access
    PRIVATE_AUCTIONS,  // 16 — Private auction access
    MODERATOR,         // 17 — Community moderator
    BETA_TESTER,       // 18 — Beta testing access
    VIP_PARTNER        // 19 — VIP partnership rewards
}
```

### PowerRarity Enum

```solidity
enum PowerRarity {
    Common,      // 1x multiplier
    Uncommon,    // 1.5x multiplier
    Rare,        // 2x multiplier
    Epic,        // 3x multiplier
    Legendary    // 5x multiplier
}
```

### NFTPower Struct

```solidity
struct NFTPower {
    PowerType powerType;
    uint16    effectValue;    // Base effect in basis points
    Rarity    rarity;
    uint64    activatedAt;
    uint64    cooldownEnds;
    bool      isActive;
}
```

### Key Functions

```solidity
// Called by authorized marketplace when user activates NuxPower NFT
function notifyPowerActivation(
    address user,
    uint256 nftId,
    IStakingIntegration.PowerType powerType,
    uint16 effectValue
) external onlyMarketplace

// Called by marketplace when user deactivates power
function notifyPowerDeactivation(address user, uint256 nftId) external onlyMarketplace

// Set rarity for an NFT (affects multiplier)
function setPowerRarity(uint256 nftId, PowerRarity rarity) external onlyMarketplace
function batchSetPowerRarity(uint256[] calldata nftIds, PowerRarity rarity) external onlyMarketplace

// Update base boost for a PowerType
function updatePowerBoost(IStakingIntegration.PowerType powerType, uint16 newBoost) external onlyOwner

// Read functions
function getPowerBoost(IStakingIntegration.PowerType powerType) external view returns (uint16)
function getUserPowerProfile(address user) external view returns (UserPowerProfile memory)
function getActivePowers(address user) external view returns (uint256[] memory nftIds)
function getActivePowersWithDetails(address user) external view returns (NFTPower[] memory)
function isPowerActive(address user, uint256 nftId) external view returns (bool)
```

### Admin Functions

```solidity
function setCoreStakingContract(address _core) external onlyOwner
function setMarketplaceContract(address _marketplace) external onlyOwner
```

---

## SmartStakingGamification

**Type:** Plain (Ownable)  
**Deploy:** `new SmartStakingGamification()`

Tracks XP and levels for staking actions. Level cap: 100.

### Admin Functions

```solidity
function setCoreStakingContract(address _core) external onlyOwner
```

---

## DynamicAPYCalculator

**Type:** Plain (Ownable)  
**Deploy:** `new DynamicAPYCalculator()`

Provides TVL-based APY adjustments. Set on Core via `setDynamicAPYCalculator()`. Optional — works only if Core's `apyCalculator` is set.

---

## SkillViewLib

**Type:** External library  
**Deploy:** `new SkillViewLib()`

Must be deployed before `SmartStakingCoreV2`. Address passed to factory:
```js
const CoreFactory = await ethers.getContractFactory("SmartStakingCoreV2", {
    libraries: { SkillViewLib: skillViewLibAddr }
});
```

---

## View Contracts

All view contracts are read-only. They hold no funds. They query Core and its modules.

### SmartStakingViewCore

```solidity
constructor(address core)

function getUserDeposits(address user) external view returns (Deposit[] memory)
function getUserTotalDeposited(address user) external view returns (uint256)
function getUserClaimableRewards(address user) external view returns (uint256)
function getTotalPoolBalance() external view returns (uint256)
```

### SmartStakingViewStats

```solidity
constructor(address core)

function getPoolStats() external view returns (uint256 tvl, uint256 uniqueUsers)
function getAPYTable() external view returns (uint256[] memory periods, uint256[] memory apys)
function getCurrentAPY(address user) external view returns (uint256)
```

### SmartStakingViewSkills

```solidity
constructor(address core)

function getActivePowers(address user) external view returns (NFTPower[] memory)
function getUserMetrics(address user) external view returns (uint256 xp, uint16 level)
```

### SmartStakingViewDashboard

```solidity
constructor(address core, address rewards, address powers, address gamification)

// Returns a full snapshot for a user in one call:
// deposits, claimable, TVL, active powers, XP, level, tier
function getUserDashboard(address user) external view returns (DashboardData memory)
```
