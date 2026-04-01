# Referral Contracts

**1 contract - referral codes, onboarding discounts, and referral XP**

---

## Overview

`ReferralSystem` turns invitations into an on-chain onboarding flow.

- every wallet can generate one permanent referral code,
- a new buyer can register under a referrer before the first purchase,
- the first purchase can receive a discount,
- the buyer and the referrer can both receive XP at different moments.

This keeps referral logic out of the marketplace core while still letting the marketplace apply referral incentives during real trades.

## Plain-Language Flow

1. A user generates a personal referral code.
2. A new buyer arrives with that code and is linked to the referrer.
3. On the buyer's first eligible purchase, the contract calculates a discount.
4. The buyer gets referral-related XP for that first purchase.
5. When the referred account completes its first sale, the referrer receives XP and a successful referral is counted.

---

## ReferralSystem

**Type:** UUPS Proxy (`AccessControl`)  
**Source:** `contracts/Referral/ReferralSystem.sol`

### Incentives

| Incentive | Value |
|---|---|
| First purchase discount | 10% |
| Buyer XP on first purchase with referral | 25 XP |
| Referrer XP when referred seller completes first sale | 30 XP |

### Main State The Contract Keeps

| Stored relationship | Meaning |
|---|---|
| `referralCodeOwner` | who owns each referral code |
| `referralCode` | the permanent code assigned to a wallet |
| `referrer` | who referred a buyer |
| `referrals` | which wallets a referrer brought in |
| `hasMadeFirstPurchase` | whether the first-purchase referral benefit is already used |
| `hasMadeFirstSale` | whether the first referral-triggered sale has already been counted |

### Key User And Marketplace Functions

```solidity
function generateReferralCode(address wallet) external returns (bytes32)
function registerWithReferralCode(address buyer, bytes32 code) external onlyRole(MARKETPLACE_ROLE) returns (bool)
function processFirstPurchaseDiscount(address buyer, uint256 nftPrice) external onlyRole(MARKETPLACE_ROLE) returns (uint256)
function processFirstSaleByReferral(address seller) external onlyRole(MARKETPLACE_ROLE) returns (bool)
```

### Useful Read Functions

```solidity
function getReferralCode(address wallet) external view returns (bytes32)
function isValidReferralCode(bytes32 code) public view returns (bool)
function getReferrer(address buyer) external view returns (address)
function getReferralsList(address referrerAddr) external view returns (address[] memory)
function getReferrerStats(address referrerAddr) external view returns (uint256, uint256, uint256)
function getUserReferralStatus(address user) external view returns (address, bool, bool, uint256)
function getUserReferralNetwork(address user) external view returns (address, address[] memory, uint256)
```

### Admin Wiring

```solidity
function setLevelingSystem(address _levelingSystem) external onlyRole(ADMIN_ROLE)
```

### Design Notes

- The contract is wallet-first. It does not assume traditional account login.
- Referral codes are permanent once created.
- The marketplace decides when to call the referral hooks during purchases and sales.
- XP is treated as a bonus path. The contract tries to award it through the leveling system when configured.

---

## Related Pages

- [Marketplace.md](./Marketplace.md) for the purchase and sale lifecycle
- [Gamification.md](./Gamification.md) for how XP fits into progression
