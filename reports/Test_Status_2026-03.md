# Test Status - March 2026

## Current Result

- Full Hardhat suite: `650 passing`, `2 pending`, `0 failing`
- Marketplace suite: `173 passing`, `0 pending`, `0 failing`

## What Changed

- Reactivated the previously skipped Marketplace coverage in `test/Marketplace.cjs`
- Re-enabled the `NuxPowerMarketplace` test block with a real deployment fixture
- Updated stale expectations for Marketplace analytics, referral stats, Leveling rewards, and admin setters
- Kept SmartStaking warning filtering in place so CI output stays readable

## Remaining Pending Tests

Two tests are still intentionally pending in `test/SmartStaking.cjs`.

### Pending 1

- Test: `Should reject deposit above maximum`
- Area: `SmartStakingCore -> Deposit Functionality`
- Reason: the contract's `MAX_DEPOSIT` is `100000 ether`, but the Hardhat test accounts in this repo do not hold enough balance to submit a transaction above that threshold.

### Pending 2

- Test: `Should reject deposit above maximum`
- Area: `SmartStaking - Security & Edge Cases -> Core - Advanced Edge Cases`
- Reason: same environment limitation as above; the test needs an account balance larger than the configured maximum deposit to exercise the revert path.

## Why These Are Still Pending

This is an environment constraint, not a currently known product defect.

The pending coverage can be removed later by choosing one of these options:

1. Increase Hardhat account balances in the local test network configuration.
2. Add a dedicated fixture that impersonates or funds a high-balance account for the max-deposit path.
3. Refactor the max-deposit validation so it can be exercised without needing to transfer more than `100000 ether` in a single test transaction.

## Practical Conclusion

The Marketplace pending debt has been eliminated.

The repo now has only two remaining pending tests, both narrow and explained by test-environment funding limits.