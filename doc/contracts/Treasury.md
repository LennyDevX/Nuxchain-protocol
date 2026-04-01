# Treasury Contracts

**2 contracts — Revenue management and reward pool**

---

## Overview

All protocol fees flow into `TreasuryManager`. It accumulates revenue and distributes it weekly to 5 sub-treasuries. A 20% reserve fund is automatically taken from every incoming payment for sustainability.

```
Revenue sources → TreasuryManager
                      ├─ 20% → Reserve fund (on-contract buffer)
                      └─ 80% → Distributed weekly to:
                                   REWARDS       (30% of distributable = 24% of total)
                                   STAKING       (35% of distributable = 28% of total)
                                   COLLABORATORS (20% of distributable = 16% of total)
                                   DEVELOPMENT   (15% of distributable = 12% of total)
                                   MARKETPLACE   (0% — reserved for future)
                      
QuestRewardsPool ← funded by TreasuryManager REWARDS treasury
                      └─ pays out on quest completion
```

---

## TreasuryManager

**Type:** Plain (Ownable + ReentrancyGuard)  
**Deploy:** `new TreasuryManager()`  
**Source:** `contracts/Treasury/TreasuryManager.sol`

### Sub-Treasury Types

```solidity
enum TreasuryType {
    REWARDS,        // 0 — Quest/achievement/level-up reward payouts
    STAKING,        // 1 — Staking operations and sustainability
    COLLABORATORS,  // 2 — Collaborator badge holder rewards
    DEVELOPMENT,    // 3 — Protocol development and maintenance
    MARKETPLACE     // 4 — Marketplace operations (currently 0%)
}
```

### Default Allocations

| Treasury | % of distributable (80%) | % of total revenue |
|---|---|---|
| REWARDS | 30% | 24% |
| STAKING | 35% | 28% |
| COLLABORATORS | 20% | 16% |
| DEVELOPMENT | 15% | 12% |
| MARKETPLACE | 0% | 0% |
| **Reserve** | — | **20% (auto-taken first)** |

Allocations can be changed by owner via `setAllocation()`. All allocations must sum to 10000 (100%).

### Constants

| Name | Value | Description |
|---|---|---|
| `DISTRIBUTION_INTERVAL` | 7 days | How often distributions happen |
| `DEFAULT_RESERVE_PERCENTAGE` | 2000 (20%) | Auto-taken from every revenue payment |
| `MAX_RESERVE_PERCENTAGE` | 3000 (30%) | Maximum reserve allocation |

### Distribution Lifecycle

1. First `receiveRevenue()` call initializes the distribution clock (`firstDepositTime`)
2. Revenue accumulates in the contract
3. Every 7 days, `triggerDistribution()` can be called (or auto-distributes if `autoDistributionEnabled = true`)
4. Funds are pushed to each registered sub-treasury address proportionally

### Key Functions

#### Revenue & Distribution

```solidity
// Called by SmartStakingCore and MarketplaceCore to send platform fees
function receiveRevenue(string calldata revenueType) external payable

// Trigger the weekly distribution (callable by anyone when ready)
function triggerDistribution() external nonReentrant

// Check if distribution window is open
function isDistributionReady() external view returns (bool ready, uint256 timeUntilNext)

// Enable/disable automatic distribution on every revenue receipt
function setAutoDistribution(bool enabled) external onlyOwner
```

#### Configuration (owner only)

```solidity
// Set the address for a sub-treasury
function setTreasury(TreasuryType treasuryType, address treasuryAddress) external onlyOwner

// Update allocation % (basis points, must all sum to 10000)
function setAllocation(TreasuryType treasuryType, uint256 percentage) external onlyOwner

// Authorize a contract to call receiveRevenue()
function setAuthorizedSource(address source, bool authorized) external onlyOwner

// Authorize a contract to call requestRewardFunds()
function setAuthorizedRequester(address requester, bool authorized) external onlyOwner

// Reserve fund
function setReserveAllocation(uint256 percentage) external onlyOwner
function setReserveAccumulation(bool enabled) external onlyOwner
```

#### Reward Funding

```solidity
// Called by reward contracts (SmartStakingRewards, QuestRewardsPool) to pull funds
function requestRewardFunds(uint256 amount) external nonReentrant returns (bool success)
```

#### Emergency System

```solidity
// Declare protocol emergency (unlocks reserve fund usage)
function declareEmergency(string calldata reason) external onlyOwner
function endEmergency() external onlyOwner

// Request emergency funds for a specific protocol
function requestEmergencyFunds(TreasuryType protocol, uint256 amount) external

// Notify APY compression needed (called by rewards when reserves are low)
function notifyAPYCompression(TreasuryType protocol, uint256 amount, string calldata reason) external
```

#### Protocol Status

```solidity
enum ProtocolStatus { HEALTHY, UNSTABLE, CRITICAL, EMERGENCY }

function setProtocolStatus(TreasuryType protocol, ProtocolStatus newStatus) external onlyOwner
function getProtocolStatus(TreasuryType protocol) external view returns (ProtocolStatus, string memory reason)
function getEmergencyInfo() external view returns (bool active, string memory reason, uint256 startTime)
```

#### View Functions

```solidity
function getTreasuryInfo(TreasuryType treasuryType)
    external view returns (address addr, uint256 allocation)

function getAllAllocations()
    external view returns (
        uint256 rewards,
        uint256 staking,
        uint256 collaborators,
        uint256 development,
        uint256 marketplace
    )
```

### State Variables

```solidity
mapping(TreasuryType => address) public treasuries;       // Sub-treasury addresses
mapping(TreasuryType => uint256) public allocations;      // % allocations (bps)
mapping(address => bool) public authorizedSources;        // Can call receiveRevenue()
mapping(address => bool) public authorizedRequester;      // Can call requestRewardFunds()

uint256 public totalRevenueReceived;
uint256 public totalDistributed;
uint256 public lastDistributionTime;
uint256 public nextDistributionTime;
bool    public autoDistributionEnabled;

uint256 public reserveFundBalance;
uint256 public reserveAllocationPercentage;   // default 2000 (20%)
bool    public reserveAccumulationEnabled;
```

### Events

```solidity
event RevenueReceived(address indexed source, uint256 amount, string revenueType);
event DistributionTriggered(uint256 totalDistributed, uint256 timestamp);
event TreasuryUpdated(TreasuryType indexed treasuryType, address indexed newAddress);
event AllocationUpdated(TreasuryType indexed treasuryType, uint256 oldPct, uint256 newPct);
event SourceAuthorized(address indexed source, bool authorized);
event ReserveFundUpdated(uint256 newBalance);
event EmergencyDeclared(string reason, uint256 timestamp);
event EmergencyEnded(uint256 timestamp);
```

---

## QuestRewardsPool

**Type:** Plain (Ownable)  
**Deploy:** `new QuestRewardsPool(adminAddress)`  
**Source:** `contracts/Treasury/QuestRewardsPool.sol`

Holds POL prizes for quest completions. Funded by the TreasuryManager REWARDS treasury or directly by the owner.

### Key Functions

```solidity
// Called by QuestCore when a user completes a quest
function payReward(address user, uint256 amount) external onlyAuthorized

// Admin: link to staking and marketplace quest systems
function setStakingContract(address _staking) external onlyOwner
function setMarketplaceContract(address _marketplace) external onlyOwner

// View
function getBalance() external view returns (uint256)
```

### Integration

`SmartStakingRewards` holds a reference to `QuestRewardsPool` and calls it on quest-based reward events. `QuestCore` also calls it directly on quest completion. The pool must be funded before quests can pay out.

---

## Setup Checklist

After deploying:

```
TreasuryManager:
  ✓ setTreasury(REWARDS, questRewardsPoolAddr)
  ✓ setTreasury(STAKING, stakingRewardsAddr)
  ✓ setTreasury(COLLABORATORS, collaboratorRewardsAddr)
  ✓ setTreasury(DEVELOPMENT, devWalletAddr)
  ✓ setAuthorizedSource(stakingCoreAddr, true)
  ✓ setAuthorizedSource(marketplaceCoreAddr, true)
  ✓ setAuthorizedRequester(stakingRewardsAddr, true)
  ✓ setAuthorizedRequester(questRewardsPoolAddr, true)
```
