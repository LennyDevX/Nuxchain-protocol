# NFT Agent Contracts

**7 contracts - AI Agent NFTs, registry, budgets, rental, and read models**

---

## Overview

This contract family turns an NFT into something closer to a programmable on-chain agent.

- the NFT represents the agent identity,
- the factory makes creation easier for end users,
- the registry stores trust, configuration, and validation data,
- the paymaster manages task budgets and payments,
- the rental layer lets owners monetize temporary access,
- the view layer makes agent data easier to read,
- the mini-game layer gives agents tasks, rewards, and reputation-building loops.

```
NuxAgentFactory
    -> category NFT contract (built from NuxAgentNFTBase)
        -> deploys ERC-6551 token bound account
        -> stores agent config and agent URI
    -> optional registry wiring

NuxAgentRegistry
    -> identity, metadata, reputation, validation

NuxAgentPaymaster
    -> agent budget and provider payments

NuxAgentRental
    -> temporary control rights for renters

NuxAgentView
    -> frontend-friendly agent summaries

NuxAgentMiniGame
    -> task loop, reward pool, streaks, and agent activity
```

## What A New Reader Should Understand First

An agent NFT is not just collectible art in this system. It can represent:

- a persistent on-chain identity,
- a dedicated token-bound wallet,
- configurable prompts and model settings,
- a reputation history,
- an asset that can be sold or rented,
- an entity that can receive funds and spend within policy limits.

---

## Creation Layer

### NuxAgentFactory

**Type:** UUPS Proxy  
**Source:** `contracts/NFT/NuxAgentFactory.sol`

This is the user-facing entry point for minting new agents.

### What It Adds

- default templates for categories such as Social, Tech, Marketing, Finance, and Business,
- optional batch minting,
- routing to the correct category NFT contract,
- optional registry initialization after minting.

### Key Functions

```solidity
function mintAgent(MintParams calldata params, address recipient)
    external payable returns (uint256 tokenId, address nftContract)

function mintAgentBatch(MintParams[] calldata paramsList, address recipient)
    external payable returns (uint256[] memory tokenIds)

function setCategoryContract(INuxAgentNFT.AgentCategory category, address nftContract) external onlyRole(ADMIN_ROLE)
function updateCategoryTemplate(...) external onlyRole(ADMIN_ROLE)
function setAgentRegistry(address registry_) external onlyRole(ADMIN_ROLE)
```

### Reader Takeaway

If you want to understand how a new agent is born, start here.

---

### NuxAgentNFTBase

**Type:** UUPS base contract  
**Source:** `contracts/NFT/NuxAgentNFTBase.sol`

This abstract base is where the agent NFT becomes more than a standard ERC-721.

### What It Stores

| Stored data | Meaning |
|---|---|
| Agent config | name, description, model, prompts, category, state |
| Agent URI | ERC-8004 style registration pointer |
| Token-bound account | agent wallet deployed through ERC-6551 |
| Rental state | current renter and expiry |
| Royalty settings | creator royalties for secondary sales |

### Key Functions

```solidity
function getAgentData(uint256 tokenId) external view returns (...)
function getAgentConfig(uint256 tokenId) external view returns (AgentConfig memory)
function getAgentState(uint256 tokenId) external view returns (AgentState)
function getTokenBoundAccount(uint256 tokenId) external view returns (address)
function getAgentURI(uint256 tokenId) external view returns (string memory)
function setAgentURI(uint256 tokenId, string calldata newURI) external
function setAgentState(uint256 tokenId, AgentState newState) external
function setRenter(uint256 tokenId, address renter, uint256 expiry) external onlyRole(RENTAL_ROLE)
function effectiveController(uint256 tokenId) external view returns (address)
```

### Reader Takeaway

This is the contract that makes agent NFTs controllable, configurable, and compatible with registry and rental flows.

---

## Trust And Operations Layer

### NuxAgentRegistry

**Type:** UUPS Proxy  
**Source:** `contracts/NFT/NuxAgentRegistry.sol`

This contract is the identity and reputation book for agents.

Every agent entry is scoped by the pair `nftContract + tokenId`, not by `tokenId` alone.

### What It Covers

| Registry surface | What it does |
|---|---|
| Identity | metadata, agent wallet, operational settings |
| Reputation | feedback from clients and score aggregation |
| Validation | proof that a task output was reviewed or approved |
| Activity | records tasks run, revenue earned, client count, validation count |

### Key Functions

```solidity
function registerNFTContract(address nftContract) external onlyRole(ADMIN_ROLE)
function setMetadata(address nftContract, uint256 tokenId, string calldata metadataKey, bytes calldata metadataValue) external
function configureAgent(address nftContract, uint256 tokenId, uint256 dailySpendingLimit, bool x402Enabled, string calldata mcpEndpoint, string calldata a2aEndpoint) external
function setAgentWallet(address nftContract, uint256 tokenId, address newWallet, uint256 deadline, bytes calldata signature) external
function giveFeedback(...) external
function validationResponse(...) external onlyRole(VALIDATOR_ROLE)
function getAgentOperationalProfile(address nftContract, uint256 tokenId) external view returns (AgentOperationalProfile memory)
function getAgentPerformanceSnapshot(address nftContract, uint256 tokenId) external view returns (AgentPerformanceSnapshot memory)
function recordTaskExecution(address nftContract, uint256 tokenId, address executor, uint256 rewardPaid) external onlyRole(GAME_ROLE)
```

### Reader Takeaway

If the NFT base answers "what is this agent?", the registry answers "how trustworthy and active is this agent?"

---

### NuxAgentPaymaster

**Type:** UUPS Proxy  
**Source:** `contracts/NFT/NuxAgentPaymaster.sol`

This contract manages spending budgets for agent activity.

### What It Enables

- owners can pre-fund an agent,
- spending can be limited by day and by task,
- approved providers can be paid from the agent budget,
- payment receipts can support agent-service proof flows.

### Key Functions

```solidity
function depositForAgent(address nftContract, uint256 tokenId) external payable
function withdrawAgentBalance(address nftContract, uint256 tokenId, uint256 amount) external
function setSpendingPolicy(address nftContract, uint256 tokenId, uint256 dailyLimit, uint256 perTaskLimit, address[] calldata allowedProviders) external
function createAuthorization(...) external returns (bytes32 authId)
function executePayment(bytes32 authId, uint256 amount) external nonReentrant
function getAgentBudgetStatus(address nftContract, uint256 tokenId) external view returns (AgentBudgetStatus memory)
```

---

## Monetization And Access Layer

### NuxAgentRental

**Type:** UUPS Proxy  
**Source:** `contracts/NFT/NuxAgentRental.sol`

This contract lets an owner rent out an agent without escrowing the NFT itself.

### Rental Flow

1. Owner creates a rental offer.
2. Renter pays for a chosen duration.
3. Revenue is split between owner and treasury.
4. The NFT contract records the renter as the temporary effective controller.
5. When the rental expires, the temporary control can be cleared.

### Default Revenue Split

| Recipient | Share |
|---|---|
| NFT owner | 80% |
| Treasury bucket | 14% |
| Platform fee | 6% |

### Key Functions

```solidity
function createRentalOffer(address nftContract, uint256 tokenId, uint256 pricePerDay, uint256 minDays, uint256 maxDays) external returns (uint256)
function cancelRentalOffer(uint256 offerId) external
function rentAgent(uint256 offerId, uint256 days_) external payable returns (uint256 rentalId)
function extendRental(uint256 rentalId, uint256 extraDays) external payable
function claimExpiredRental(uint256 rentalId) external
```

---

### NuxAgentView

**Type:** Plain  
**Source:** `contracts/NFT/NuxAgentView.sol`

This is the read helper that turns agent data into usable UI payloads.

### Key Functions

```solidity
function getAgentView(address nftContract, uint256 tokenId) external view returns (INuxAgentNFT.AgentView memory)
function getOwnerAgentIds(address nftContract, address owner, uint256 offset, uint256 limit) external view returns (uint256[] memory tokenIds, uint256 total)
function getCollectionStats(address nftContract) external view returns (INuxAgentNFT.CollectionStats memory stats)
```

---

## Agent Mission Layer

### NuxAgentMiniGame

**Type:** UUPS Proxy  
**Source:** `contracts/NFT/NuxAgentMiniGame.sol`

This contract gives agent NFTs repeatable missions, a reward pool, and reputation-building activity.

### What It Adds

- admin-created tasks,
- optional validation before approval,
- XP and reward payouts on success,
- streak tracking for daily challenges,
- leaderboard-friendly events,
- registry hooks for task execution and validation history.

### Key Functions

```solidity
function depositRewards() external payable onlyRole(DEPOSITOR_ROLE)
function createTask(CreateTaskParams calldata p) external onlyRole(ADMIN_ROLE) returns (uint256 taskId)
function setTaskActive(uint256 taskId, bool active_) external onlyRole(ADMIN_ROLE)
function submitTask(...) external returns (uint256 submissionId)
function claimReward(uint256 submissionId) external nonReentrant
function getTask(uint256 taskId) external view returns (Task memory)
function getTaskStatus(uint256 taskId) external view returns (TaskStatusView memory)
function getUserRewardSummary(address user) external view returns (RewardSummary memory)
```

---

## Related Pages

- [NuxTapGame.md](./NuxTapGame.md) for the separate tap-based game surface
- [Auction.md](./Auction.md) for advanced sales of agent NFTs
- [XP.md](./XP.md) for XP labels shared across agent-related activity
