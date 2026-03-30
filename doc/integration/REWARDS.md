# Rewards & Economic Formulas

**APY calculation, XP system, and treasury revenue flow**

---

## Staking APY Formula

A user's effective APY is the sum of several components:

```
effectiveAPY = baseAPY + tierBonus + loyaltyBonus + powerBoost + referralBoost
```

### Base APY by Lockup

| Lockup | Base APY |
|---|---|
| 0 (Flexible) | 8.60% |
| 30 days | 14.60% |
| 90 days | 19.30% |
| 180 days | 24.20% |
| 365 days | 25.50% |

### Tier Bonus (by total staked)

| Total Staked | Tier | APY Bonus |
|---|---|---|
| < 100 POL | Bronze | +0% |
| 100 – 999 POL | Silver | +0.25% |
| 1,000 – 9,999 POL | Gold | +0.75% |
| ≥ 10,000 POL | Platinum | +1.50% |

### Loyalty Bonus (continuous staking duration)

| Staking Since | APY Bonus |
|---|---|
| < 90 days | +0% |
| 90 – 179 days | +0.25% |
| 180 – 364 days | +0.50% |
| ≥ 365 days | +1.00% |

The staking clock starts at first deposit via `recordStakingSince()` and resets to zero on full withdrawal via `clearStakingSince()`. A partial withdrawal does not reset the clock.

### Power Boost (NuxPower NFTs)

Each active NuxPower NFT adds its effective boost:

```
effectiveBoost = baseEffect × rarityMultiplier
```

| PowerType | Base Effect |
|---|---|
| STAKE_BOOST_I | +5% APY |
| STAKE_BOOST_II | +10% APY |
| STAKE_BOOST_III | +20% APY |

| Rarity | Multiplier |
|---|---|
| Common | 1.0× |
| Uncommon | 1.5× |
| Rare | 2.0× |
| Epic | 3.0× |
| Legendary | 5.0× |

Example: `STAKE_BOOST_I` (500 bps) at Rare rarity → 1000 bps = 10% extra APY.

Up to 5 NuxPower NFTs can be active simultaneously (`MAX_ACTIVE_SKILL_SLOTS = 5`).

### Referral Boost

| Event | Boost |
|---|---|
| Referred User Deposits | Referrer receives `referralBoostBps` APY boost |
| Default boost | 1.5% (`referralBoostBps = 150`) |
| Default duration | 30 days per referral |

Boosts stack per referral but are time-limited. The current admin-configurable values are set on `SmartStakingCore`.

### DynamicAPYCalculator (optional)

If set via `SmartStakingCore.setDynamicAPYCalculator()`, the calculator can compress or expand base APY based on TVL levels. This is optional and disabled by default.

---

## Reward Accrual

Rewards accrue per-deposit, not per-user. Each `Deposit` has its own `lastClaimTime`. On claim:

```
elapsed = block.timestamp - deposit.lastClaimTime
reward  = deposit.amount × APY × elapsed / 365 days
```

The 6% commission is taken from the reward amount before it is paid to the user:

```
commission = reward × 6 / 100  → TreasuryManager
userPayout = reward - commission
```

### Early Exit Fee

For flexible deposits (lockup = 0) withdrawn within 7 days of deposit:

```
earlyExitFee = principal × 0.5%
```

This is deducted from the returned principal, not rewards.

### AutoCompound Fee

When `compound()` is called:

```
compoundFee = pendingRewards × 0.25%  → TreasuryManager
compounded  = pendingRewards - compoundFee
```

The compounded amount is added as a new flexible deposit.

### Partial Reinvestment

Users can set a `reinvestmentPercentage` (0–100%):

```
compoundedPortion = pendingRewards × reinvestmentPct
paid out directly = pendingRewards × (1 - reinvestmentPct)
```

---

## Marketplace XP System

### XP Earned

| Action | XP |
|---|---|
| Mint an NFT | 10 |
| Sell an NFT | 20 |
| Buy an NFT | 15 |
| Add a comment | 2 |
| Toggle a like | 1 |

### XP Cap

`MAX_XP = 5,000`. XP cannot exceed this.

### Level Formula

```
level = floor(sqrt(totalXP / 100))
maxLevel = 50
```

| XP | Level |
|---|---|
| 0 | 0 |
| 100 | 1 |
| 400 | 2 |
| 900 | 3 |
| 1,600 | 4 |
| 2,500 | 5 |
| 5,000 | ~7 (capped at 50 in MarketplaceCore) |

> Note: `LevelingSystem` tracks up to `MAX_XP_TOTAL = 7,500` for its own profile, while `MarketplaceCore` caps at `MAX_XP = 5,000` and `MAX_LEVEL = 50`.

### Level-Up Reward

When a user levels up, `LevelingSystem.rewardLevelUp(user, level)` is called:

```
reward = min(MIN_REWARD + level / SCALE_DIVISOR, 5 POL)
```

---

## Treasury Revenue Flow

All fees flow into `TreasuryManager.receiveRevenue()`:

| Source | Amount |
|---|---|
| SmartStaking commission | 6% of rewards claimed |
| SmartStaking autocompound fee | 0.25% of rewards compounded |
| SmartStaking early exit fee | 0.5% of principal (flexible, early) |
| Marketplace platform fee | 6% of every sale |

### Distribution (weekly)

20% reserve is taken first. The remaining 80% distributes:

| Sub-treasury | % of distributable | % of total revenue |
|---|---|---|
| REWARDS (→ QuestRewardsPool) | 30% | 24% |
| STAKING (→ SmartStakingRewards) | 35% | 28% |
| COLLABORATORS (→ CollaboratorBadgeRewards) | 20% | 16% |
| DEVELOPMENT | 15% | 12% |

Distribution frequency: every 7 days from the first revenue receipt.

### Reserve Fund

The on-contract reserve fund acts as a 6–12 month buffer:

- 20% of every revenue payment → `reserveFundBalance`
- Used during emergencies via `requestEmergencyFunds()`
- Can be withdrawn by owner during deficit periods

---

## Royalty Flow (Marketplace)

On secondary sales (where `creator != seller`):

```
royalty  = price × royaltyPercentage / 100   → creator
platform = price × 6 / 100                  → TreasuryManager
seller   = price - royalty - platform        → seller
excess   = msg.value - price                 → refunded to buyer
```

On primary sales (`creator == seller`): no royalty deduction.
