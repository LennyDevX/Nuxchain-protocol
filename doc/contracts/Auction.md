# Auction Contracts

**1 contract - multi-mode auctions for agent NFTs**

---

## Overview

`NuxAuctionMarketplace` is the protocol's advanced selling surface for NFTs that need something more flexible than a fixed listing price.

It supports three auction styles:

| Auction type | What it feels like |
|---|---|
| English | bidders keep outbidding each other until time runs out |
| Dutch | price starts high and falls until someone accepts it |
| Sealed bid | bidders commit privately first, then reveal later |

This contract is especially relevant for AI Agent NFTs and premium sales where price discovery matters.

---

## User Flow In Plain English

1. A seller creates an auction and the NFT is escrowed in the contract.
2. Buyers participate according to the selected auction mode.
3. When the auction is finalized, the NFT goes to the winner.
4. The payment is split between seller, royalty recipient, and treasury.
5. The contract can award XP for bidding, winning, and selling.

## NuxAuctionMarketplace

**Type:** UUPS Proxy (`AccessControl` + `ReentrancyGuard`)  
**Source:** `contracts/Auction/NuxAuctionMarketplace.sol`

### Core Economics

| Parameter | Default |
|---|---|
| Platform fee | 600 bps (6%) |
| Max royalty honored | 1500 bps (15%) |
| Minimum English bid increment | 100 bps (1%) |
| Sealed reveal window | 24 hours |

### XP Hooks

| Action | XP |
|---|---|
| Place an English bid | 10 XP |
| Win an auction | 100 XP |
| Complete a successful sale | 50 XP |

### Key Functions

```solidity
function createAuction(
    address nftContract,
    uint256 tokenId,
    AuctionType auctionType_,
    uint256 startPrice,
    uint256 reservePrice,
    uint256 duration
) external returns (uint256 auctionId)

function placeBid(uint256 auctionId) external payable
function claimRefund(uint256 auctionId) external
function buyDutch(uint256 auctionId) external payable
function commitSealedBid(uint256 auctionId, bytes32 commitment) external payable
function revealSealedBid(uint256 auctionId, uint256 amount, bytes32 salt) external
function finalizeAuction(uint256 auctionId) external
function cancelAuction(uint256 auctionId) external
function getDutchPrice(uint256 auctionId) public view returns (uint256)
```

### What Makes Each Mode Different

#### English Auctions

- every new bid must clear the current bid plus the minimum increment,
- outbid users do not lose funds permanently because they can reclaim refunds,
- reserve price can still cause the auction to fail if the final price is too low.

#### Dutch Auctions

- there is no back-and-forth bidding,
- the current price falls over time,
- the first accepted price wins immediately.

#### Sealed-Bid Auctions

- bidders first submit commitments rather than visible bid amounts,
- later they reveal the amount and salt,
- the final result is settled after the reveal window ends.

### Reader Takeaway

This contract is not a replacement for the normal marketplace. It is the specialized sale engine for situations where competitive pricing matters more than instant purchase UX.

---

## Related Pages

- [NFTAgents.md](./NFTAgents.md) for the asset type most clearly tied to this auction surface
- [Treasury.md](./Treasury.md) for fee routing concepts
- [XP.md](./XP.md) for the XP metadata behind auction activity labels
