# NuxPower NFT System

**NFTs that grant permanent on-chain powers to their holders**

---

## Overview

NuxPower NFTs are special ERC-721 tokens that grant their holder a permanent protocol power. When activated, they boost staking APY, reduce fees, grant access rights, or provide other in-protocol benefits.

```
NuxPowerNft (minting + ERC721 storage)
      │
      ▼ activates via marketplace
SmartStakingPower (tracks active powers per user)
      │
      ▼ read at claim time
SmartStakingRewards (applies rarity multiplier to APY)
```

---

## PowerType Reference

All 20 power types defined in `IStakingIntegration`:

| # | Name | Effect |
|---|---|---|
| 0 | `NONE` | No effect |
| 1 | `STAKE_BOOST_I` | +5% APY |
| 2 | `STAKE_BOOST_II` | +10% APY |
| 3 | `STAKE_BOOST_III` | +20% APY |
| 4 | `AUTO_COMPOUND` | Automatic reward compounding |
| 5 | `LOCK_REDUCER` | -25% lock duration |
| 6 | `FEE_REDUCER_I` | -10% platform fees |
| 7 | `FEE_REDUCER_II` | -25% platform fees |
| 8 | `PRIORITY_LISTING` | Featured placement on homepage |
| 9 | `BATCH_MINTER` | Mint multiple NFTs in one tx |
| 10 | `VERIFIED_CREATOR` | Verified creator badge |
| 11 | `INFLUENCER` | 2× weight on likes/comments |
| 12 | `CURATOR` | Create featured collections |
| 13 | `AMBASSADOR` | 2× referral bonus |
| 14 | `VIP_ACCESS` | Access to exclusive drops |
| 15 | `EARLY_ACCESS` | 24-hour early access to new drops |
| 16 | `PRIVATE_AUCTIONS` | Access to private auction rooms |
| 17 | `MODERATOR` | Community moderator privileges |
| 18 | `BETA_TESTER` | Beta testing access |
| 19 | `VIP_PARTNER` | VIP partnership rewards |

---

## PowerRarity Reference

Rarity controls the multiplier applied to a power's `effectValue`:

| Rarity | Multiplier | Staking context |
|---|---|---|
| Common | 1.0× | Base effect |
| Uncommon | 1.5× | 50% stronger |
| Rare | 2.0× | Double effect |
| Epic | 3.0× | Triple effect |
| Legendary | 5.0× | 5× effect |

Example: A `STAKE_BOOST_I` NFT with base effect 500 bps (5% APY) at Rare rarity grants 10% APY boost.

---

## SmartStakingPower Functions

Full reference in [SmartStaking.md](./SmartStaking.md#smartstakingpower). Key calls:

```solidity
// Activate a NuxPower NFT for a user
function notifyPowerActivation(
    address user,
    uint256 nftId,
    PowerType powerType,
    uint16 effectValue
) external onlyMarketplace

// Deactivate (e.g. NFT sold or transferred)
function notifyPowerDeactivation(address user, uint256 nftId) external onlyMarketplace

// Set rarity. Usually called by NuxPowerNft at mint time
function setPowerRarity(uint256 nftId, PowerRarity rarity) external onlyMarketplace
```

---

## NuxPowerNft

**Type:** Plain (Ownable)  
**Deploy:** `new NuxPowerNft(marketplaceCoreAddr)`  
**Post-deploy:** `setTreasuryAddress(treasuryAddr)` + grant `ADMIN_ROLE` in `MarketplaceCore`

Mints NuxPower NFTs. Each minted NFT has a `PowerType` embedded in its metadata. Revenue from sales goes to treasury.

### Key Functions

```solidity
function setTreasuryAddress(address treasury) external onlyOwner

function mintPowerNFT(
    address to,
    IStakingIntegration.PowerType powerType,
    uint96 royaltyPercentage,
    string calldata uri
) external returns (uint256 tokenId)
```

---

## NuxPowerMarketplace

**Type:** Plain  
**Deploy:** `new NuxPowerMarketplace(marketplaceCoreAddr, adminAddr)`

Acts as a bridge between the marketplace and the power system. It routes power activation events from the marketplace to `SmartStakingPower`.

---

## Activation Flow

1. User purchases a NuxPower NFT (via `MarketplaceCore.buyToken()` or `acceptOffer()`)
2. `MarketplaceCore` calls `NuxPowerMarketplace.onNFTPurchased(buyer, tokenId)`
3. `NuxPowerMarketplace` reads the NFT's `powerType` and calls `SmartStakingPower.notifyPowerActivation()`
4. `SmartStakingPower` records the power in the user's profile
5. On the next reward claim in `SmartStakingRewards`, the power boost is applied

## Deactivation

A power deactivates when the NFT is transferred or listed for sale. The marketplace calls `SmartStakingPower.notifyPowerDeactivation()` which removes the NFT from the user's active power profile.

---

## Max Active Powers

`SmartStakingCoreV2` constant `MAX_ACTIVE_SKILL_SLOTS = 5`. A user can hold at most 5 active NuxPower NFTs simultaneously. Attempting to activate a 6th will fail with `PowerSlotsFull`.

---

## Enable/Disable Powers

Each `PowerType` can be individually enabled or disabled by the staking owner:

```solidity
SmartStakingCoreV2.setPowerEnabled(PowerType.STAKE_BOOST_III, false);
```

Disabled powers revert with `PowerDisabled(PowerType)` when a user attempts activation.
