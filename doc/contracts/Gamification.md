# Gamification Contracts

**3 contracts — Leveling, Quests, and Collaborator Rewards**

---

## Overview

The gamification layer incentivizes user participation across the entire protocol:

- **LevelingSystem** — pays POL when users level up in the marketplace
- **QuestCore** — tracks user progress across all protocol actions and rewards completions
- **CollaboratorBadgeRewards** — distributes protocol revenue to badge holders

---

## LevelingSystem

**Type:** UUPS Proxy (Ownable)  
**Deploy:** `upgrades.deployProxy(factory, [adminAddr], { kind: "uups" })`  
**Post-deploy:** `grantRole(MARKETPLACE_ROLE, marketplaceCoreAddr)`  
**Source:** `contracts/Leveling/LevelingSystem.sol`

### Constants

| Name | Value |
|---|---|
| `MAX_LEVEL` | 50 |
| `MAX_XP_TOTAL` | 7,500 |
| `MAX_LEVEL_REWARD` | 5 POL |

### Reward Formula

```
reward = min(MIN_REWARD + (level / SCALE_DIVISOR), 5 POL)
```

Higher levels pay more, capped at 5 POL.

### Key Functions

```solidity
function initialize(address admin) public initializer

// Called by MarketplaceCore when a user levels up
function rewardLevelUp(address user, uint8 level) external onlyMarketplace

// Called by MarketplaceCore when XP is awarded
function addXP(address user, uint256 amount) external onlyMarketplace

// View
function getRewardForLevel(uint8 level) external view returns (uint256)
function getMaxLevel() external pure returns (uint8)       // 50
function getUserProfile(address user) external view returns (UserProfile memory)
function getMaxXPTotal() external pure returns (uint256)   // 7500
```

### UserProfile Struct

```solidity
struct UserProfile {
    uint256 totalXP;
    uint8   level;
    uint256 nftsCreated;
    uint256 nftsSold;
    uint256 nftsBought;
}
```

### Funding

`LevelingSystem` must hold POL to pay rewards. Fund it via `scripts/fund.cjs` or by sending POL directly to the contract address.

---

## QuestCore

**Type:** UUPS Proxy (AccessControl)  
**Deploy:** `upgrades.deployProxy(factory, [adminAddr, marketplaceCoreAddr], { kind: "uups" })`  
**Source:** `contracts/Quest/QuestCore.sol`

Central quest registry for the entire protocol. All quest creation, tracking, and completion flows through this contract.

### Roles

| Role | Holder | Can do |
|---|---|---|
| `ADMIN_ROLE` | Deployer | Create quests, set contracts |
| `UPGRADER_ROLE` | Deployer | Upgrade proxy |
| `REPORTER_ROLE` | SmartStakingCore, MarketplaceSocial, NuxAgentMiniGame | Call `notifyAction()` |

### Post-Deploy Setup

```solidity
// Grant reporter role to action sources
QuestCore.grantRole(REPORTER_ROLE, stakingCoreAddr);
QuestCore.grantRole(REPORTER_ROLE, marketplaceSocialAddr);
QuestCore.grantRole(REPORTER_ROLE, miniGameAddr);  // if used

// Set dependencies
QuestCore.setLevelingContract(levelingSystemAddr);
QuestCore.setQuestRewardsPool(questRewardsPoolAddr);
```

### Quest Types

```solidity
enum QuestType {
    PURCHASE,     // Buy NFTs (tracks profile.nftsBought)
    CREATE,       // Mint NFTs (tracks profile.nftsCreated)
    SOCIAL,       // Likes + comments (counter-based via notifyAction)
    LEVEL_UP,     // Reach a level (capped at 50)
    TRADING,      // Sell NFTs (tracks profile.nftsSold)
    STAKE,        // Deposit POL (counter-based, in wei)
    COMPOUND,     // Compound rewards (counter-based by count)
    AGENT_TASK    // Complete AI agent tasks (notified by NuxAgentMiniGame)
}
```

### Quest Struct

```solidity
struct Quest {
    string      name;
    string      description;
    QuestType   questType;
    uint256     requirement;    // Target value to complete quest
    uint256     xpReward;       // XP awarded on completion (max 50,000)
    uint256     polReward;      // POL awarded on completion
    uint256     startTime;
    uint256     endTime;
    bool        active;
}
```

### Key Functions

```solidity
function initialize(address admin, address core) public initializer

// Admin: create a new quest
function createQuest(QuestParams calldata params) external onlyRole(ADMIN_ROLE) returns (uint256 questId)

// Admin: toggle quest active/inactive
function setQuestActive(uint256 questId, bool active) external onlyRole(ADMIN_ROLE)

// Reporter: notify that a user performed a tracked action
function notifyAction(address user, QuestType questType, uint256 value) external onlyRole(REPORTER_ROLE)

// User: claim reward when their progress meets the requirement
function completeQuest(uint256 questId) external nonReentrant

// View
function getQuest(uint256 questId) external view returns (Quest memory)
function getUserProgress(address user, uint256 questId) external view returns (UserQuestProgress memory)
function getActiveQuests() external view returns (uint256[] memory questIds)
function canComplete(address user, uint256 questId) external view returns (bool)
```

### Progress Tracking

Some quest types use profile data from `LevelingSystem` (PURCHASE, CREATE, TRADING, LEVEL_UP). Others are counter-based, incremented directly via `notifyAction` (SOCIAL, STAKE, COMPOUND, AGENT_TASK).

### Limits

| Constant | Value |
|---|---|
| `MAX_XP_REWARD` | 50,000 |
| `MAX_SOCIAL_ACTIONS_PER_QUEST` | 1,000 |
| `MAX_LEVEL` | 50 (for LEVEL_UP quests) |

---

## CollaboratorBadgeRewards

**Type:** UUPS Proxy (Ownable)  
**Deploy:** `upgrades.deployProxy(factory, [adminAddr], { kind: "uups" })`  
**Post-deploy:** `setTreasuryManager(treasuryManagerAddr)`  
**Source:** `contracts/Rewards/CollaboratorBadgeRewards.sol`

Manages quest rewards and commission pools for Collaborator Badge holders. Receives funds from the TreasuryManager COLLABORATORS treasury.

### CollaboratorQuest Struct

```solidity
struct CollaboratorQuest {
    string  description;
    uint256 rewardAmount;      // POL per completion
    uint256 startTime;
    uint256 endTime;
    bool    active;
    uint256 completionCount;
    uint256 maxCompletions;    // 0 = unlimited
}
```

### Key Functions

```solidity
function initialize(address admin) public initializer
function setTreasuryManager(address _manager) external onlyOwner
function setBadgeManager(address _manager) external onlyOwner
function setQuestRewardsPool(address _pool) external onlyOwner

// Create collaborator-exclusive quests
function createCollaboratorQuest(
    string calldata description,
    uint256 rewardAmount,
    uint256 startTime,
    uint256 endTime,
    uint256 maxCompletions
) external onlyOwner returns (uint256 questId)

// Badge holders complete a quest and receive reward
function completeQuest(uint256 questId) external nonReentrant

// Claim accumulated pending rewards
function claimRewards() external nonReentrant

// View
function getPendingRewards(address user) external view returns (uint256)
function getQuest(uint256 questId) external view returns (CollaboratorQuest memory)
function getActiveQuests() external view returns (uint256[] memory)
```

### State Variables

```solidity
ITreasuryManager public treasuryManager;
IBadgeManager    public badgeManager;  // Validates who holds a collaborator badge
IQuestRewardsPool public questRewardsPool;

uint256 public totalCommissionReceived;
uint256 public totalTreasuryReceived;
uint256 public totalRewardsPaid;
uint256 public totalBadgeHolders;
uint256 public maxRewardLimit;
uint256 public claimFeePercent;

mapping(address => uint256) public pendingRewards;
mapping(uint256 => CollaboratorQuest) public quests;
mapping(address => mapping(uint256 => bool)) public questCompleted;
```

### Eligibility

Badge holders must be registered in `IBadgeManager`. The deployer or owner configures the badge manager address post-deploy. Only valid badge holders can participate in collaborator quests or receive passive distributions.

---

## SmartStakingGamification

**Type:** Plain (Ownable)  
**Deploy:** `new SmartStakingGamification()`  
**Post-deploy:** `setCoreStakingContract(stakingCoreAddr)`  
**Source:** `contracts/SmartStaking/SmartStakingGamification.sol`

Tracks XP and levels for staking actions. Separate from the marketplace leveling system.

| Constant | Value |
|---|---|
| `MAX_LEVEL_CAP` | 100 |

### Key Functions

```solidity
function setCoreStakingContract(address _core) external onlyOwner
function addXP(address user, uint256 amount) external onlyCore
function getUserXP(address user) external view returns (uint256)
function getUserLevel(address user) external view returns (uint256)
```
