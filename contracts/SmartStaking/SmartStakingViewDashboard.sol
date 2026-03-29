// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title SmartStakingViewDashboard
/// @notice Single-call mega-view contract that aggregates all data a frontend dashboard needs.
/// @dev Pure view contract. No state-changing functions. All data gathered via staticcall
///      so it is forward-compatible even when underlying modules are upgraded.
/// @custom:version 1.0 — NuxChain Protocol v7.0
contract SmartStakingViewDashboard {

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    struct DepositSnapshot {
        uint256 index;
        uint256 amount;
        uint256 timestamp;
        uint256 lastClaimTime;
        uint256 lockupDuration;     // 0 = flexible
        uint256 unlockTime;
        bool    isLocked;
        bool    isWithdrawable;
        string  lockupLabel;        // "Flexible" | "30 Days" | "90 Days" | "180 Days" | "365 Days"
    }

    struct DashboardData {
        // ── Portfolio ──────────────────────────────────────────────
        uint256 totalDeposited;
        uint256 totalRewards;       // all accrued (unrealised)
        uint256 depositCount;
        uint256 flexibleBalance;
        uint256 lockedBalance;
        uint256 unlockedBalance;
        DepositSnapshot[] deposits;

        // ── APY ────────────────────────────────────────────────────
        uint256[5] baseAPYs;        // bps: [flexible, 30d, 90d, 180d, 365d]
        uint256[5] boostedAPYs;     // baseAPY + tier + loyalty bonuses (user-specific)

        // ── Tier / Loyalty ─────────────────────────────────────────
        string  tierName;           // "None" | "Silver" | "Gold" | "Platinum"
        uint256 tierBonusBps;
        uint256 loyaltyDays;
        uint256 loyaltyBonusBps;

        // ── Skills ─────────────────────────────────────────────────
        uint256 apyBoostBps;        // from active skill
        uint256 compoundBoostBps;
        uint256 withdrawBoostBps;

        // ── Gamification ───────────────────────────────────────────
        uint256 currentXP;
        uint256 currentLevel;
        uint256 streakDays;
        uint256 deferredRewardAmount;  // pending deferred reward (if any)

        // ── Projections ────────────────────────────────────────────
        uint256 projectedDailyRewards;
        uint256 projectedMonthlyRewards;   // × 30
        uint256 projectedYearlyRewards;    // × 365

        // ── Daily Withdrawal ───────────────────────────────────────
        uint256 dailyWithdrawalLimit;
        uint256 dailyWithdrawalUsed;
        uint256 dailyWithdrawalRemaining;
        bool    circuitBreakerActive;

        // ── Auto-Compound / Reinvestment ───────────────────────────
        uint256 reinvestmentPct;    // bps
        bool    autoCompoundEnabled;

        // ── Referral ───────────────────────────────────────────────
        address referrer;
        uint256 referralBoostBps;

        // ── Next Unlock ────────────────────────────────────────────
        uint256 secondsUntilNextUnlock;
        uint256 nextUnlockTime;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE
    // ════════════════════════════════════════════════════════════════════════════════════════

    address public stakingContract;
    address public rewardsModule;
    address public powerModule;
    address public gamificationModule;
    address public owner;

    event StakingContractUpdated(address indexed newAddress);
    event ModulesUpdated(address rewards, address powers, address gamification);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════

    constructor(
        address _stakingContract,
        address _rewardsModule,
        address _powerModule,
        address _gamificationModule
    ) {
        require(_stakingContract != address(0), "Invalid staking contract");
        stakingContract = _stakingContract;
        rewardsModule = _rewardsModule;
        powerModule = _powerModule;
        gamificationModule = _gamificationModule;
        owner = msg.sender;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN
    // ════════════════════════════════════════════════════════════════════════════════════════

    function setStakingContract(address _addr) external onlyOwner {
        require(_addr != address(0), "Invalid address");
        stakingContract = _addr;
        emit StakingContractUpdated(_addr);
    }

    function setModules(address _rewards, address _powers, address _gamification) external onlyOwner {
        rewardsModule     = _rewards;
        powerModule       = _powers;
        gamificationModule = _gamification;
        emit ModulesUpdated(_rewards, _powers, _gamification);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // MAIN DASHBOARD CALL
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Returns the full dashboard dataset for `_user` in one call.
    /// @dev    All staticcalls are wrapped in try/catch-style success checks so that
    ///         partial module failures degrade gracefully (zero values rather than reverts).
    function getUserDashboard(address _user) external view returns (DashboardData memory data) {
        // ── Portfolio data from Core ──────────────────────────────
        _fillPortfolio(_user, data);

        // ── APY rates from Rewards ────────────────────────────────
        _fillAPY(_user, data);

        // ── Tier & Loyalty from Rewards ───────────────────────────
        _fillTierLoyalty(_user, data);

        // ── Skill boosts ─────────────────────────────────────────
        _fillSkills(_user, data);

        // ── Gamification (XP / level / streak) ───────────────────
        _fillGamification(_user, data);

        // ── Daily withdrawal / circuit breaker ───────────────────
        _fillWithdrawalInfo(_user, data);

        // ── Auto-compound / reinvestment ─────────────────────────
        _fillReinvestment(_user, data);

        // ── Referral ─────────────────────────────────────────────
        _fillReferral(_user, data);

        // ── Projections (calculated last, needs baseAPYs + boosts) ─
        _fillProjections(data);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INTERNAL FILL HELPERS
    // ════════════════════════════════════════════════════════════════════════════════════════

    function _fillPortfolio(address _user, DashboardData memory d) internal view {
        // getUserInfo(address) → (totalDeposited, totalRewards, depositCount, lastWithdrawTime)
        (bool ok, bytes memory raw) = stakingContract.staticcall(
            abi.encodeWithSignature("getUserInfo(address)", _user)
        );
        if (!ok || raw.length < 128) return;
        (uint256 tDep, uint256 tRew, uint256 dCount, ) = abi.decode(raw, (uint256, uint256, uint256, uint256));
        d.totalDeposited = tDep;
        d.totalRewards   = tRew;
        d.depositCount   = dCount;

        if (dCount == 0) return;

        d.deposits = new DepositSnapshot[](dCount);
        uint256 nextUnlock = type(uint256).max;
        uint256 nextUnlockTime_;

        for (uint256 i; i < dCount; i++) {
            (bool ok2, bytes memory r2) = stakingContract.staticcall(
                abi.encodeWithSignature("getUserDeposit(address,uint256)", _user, i)
            );
            if (!ok2 || r2.length < 128) continue;
            (uint128 amt, uint64 ts, , uint64 lkp) = abi.decode(r2, (uint128, uint64, uint64, uint64));

            uint256 unlockTime = uint256(ts) + uint256(lkp);
            bool isLocked      = lkp > 0 && block.timestamp < unlockTime;

            string memory label;
            if (lkp == 0)              label = "Flexible";
            else if (lkp == 30 days)   label = "30 Days";
            else if (lkp == 90 days)   label = "90 Days";
            else if (lkp == 180 days)  label = "180 Days";
            else if (lkp == 365 days)  label = "365 Days";
            else                       label = "Custom";

            d.deposits[i] = DepositSnapshot({
                index:          i,
                amount:         uint256(amt),
                timestamp:      uint256(ts),
                lastClaimTime:  0,          // decoded separately if needed
                lockupDuration: uint256(lkp),
                unlockTime:     unlockTime,
                isLocked:       isLocked,
                isWithdrawable: !isLocked,
                lockupLabel:    label
            });

            // Balance breakdown
            if (lkp == 0)            d.flexibleBalance  += uint256(amt);
            else if (isLocked)       d.lockedBalance    += uint256(amt);
            else                     d.unlockedBalance  += uint256(amt);

            // Track soonest unlock
            if (isLocked && unlockTime < nextUnlock) {
                nextUnlock      = unlockTime;
                nextUnlockTime_ = unlockTime;
            }
        }

        d.nextUnlockTime           = nextUnlockTime_;
        d.secondsUntilNextUnlock   = nextUnlockTime_ > block.timestamp ? nextUnlockTime_ - block.timestamp : 0;
    }

    function _fillAPY(address /* _user */, DashboardData memory d) internal view {
        if (rewardsModule == address(0)) {
            // Fallback hardcoded v6.3.0 rates
            d.baseAPYs = [uint256(86), 146, 193, 242, 255];
        } else {
            (bool ok, bytes memory raw) = rewardsModule.staticcall(
                abi.encodeWithSignature("getBaseAPYs()")
            );
            if (ok && raw.length >= 160) {
                // First 32 bytes: offset; then 32 bytes: length; then 5 × 32 bytes: elements
                uint256[] memory apys = abi.decode(raw, (uint256[]));
                if (apys.length >= 5) {
                    for (uint256 i; i < 5; i++) d.baseAPYs[i] = apys[i];
                }
            } else {
                d.baseAPYs = [uint256(86), 146, 193, 242, 255];
            }
        }

        // Boosted APYs = base + tier + loyalty (applied uniformly; skill boost added separately)
        for (uint256 i; i < 5; i++) {
            d.boostedAPYs[i] = d.baseAPYs[i] + d.tierBonusBps + d.loyaltyBonusBps + d.apyBoostBps;
        }
    }

    function _fillTierLoyalty(address _user, DashboardData memory d) internal view {
        if (rewardsModule == address(0)) return;

        // getUserTier(totalDeposited)
        (bool ok1, bytes memory r1) = rewardsModule.staticcall(
            abi.encodeWithSignature("getUserTier(uint256)", d.totalDeposited)
        );
        if (ok1 && r1.length >= 64) {
            (string memory tName, uint256 tBonus) = abi.decode(r1, (string, uint256));
            d.tierName     = tName;
            d.tierBonusBps = tBonus;
        } else {
            d.tierName = "None";
        }

        // getLoyaltyDays(user)
        (bool ok2, bytes memory r2) = rewardsModule.staticcall(
            abi.encodeWithSignature("getLoyaltyDays(address)", _user)
        );
        if (ok2 && r2.length >= 32) d.loyaltyDays = abi.decode(r2, (uint256));

        // getLoyaltyBonus(user)
        (bool ok3, bytes memory r3) = rewardsModule.staticcall(
            abi.encodeWithSignature("getLoyaltyBonus(address)", _user)
        );
        if (ok3 && r3.length >= 32) d.loyaltyBonusBps = abi.decode(r3, (uint256));
    }

    function _fillSkills(address _user, DashboardData memory d) internal view {
        if (powerModule == address(0)) return;
        (bool ok, bytes memory raw) = powerModule.staticcall(
            abi.encodeWithSignature("getUserBoosts(address)", _user)
        );
        if (!ok || raw.length < 96) return;
        (uint16 apy, uint16 compound, uint16 withdraw) = abi.decode(raw, (uint16, uint16, uint16));
        d.apyBoostBps      = uint256(apy);
        d.compoundBoostBps = uint256(compound);
        d.withdrawBoostBps = uint256(withdraw);
    }

    function _fillGamification(address _user, DashboardData memory d) internal view {
        if (gamificationModule == address(0)) return;

        // getUserXP(address) → (currentXP, level, totalXPEarned)
        (bool ok1, bytes memory r1) = gamificationModule.staticcall(
            abi.encodeWithSignature("getUserXP(address)", _user)
        );
        if (ok1 && r1.length >= 96) {
            (uint256 xp, uint256 lvl, ) = abi.decode(r1, (uint256, uint256, uint256));
            d.currentXP    = xp;
            d.currentLevel = lvl;
        }

        // getUserStreak(address) → (currentStreak, longestStreak, lastActivityTime)
        (bool ok2, bytes memory r2) = gamificationModule.staticcall(
            abi.encodeWithSignature("getUserStreak(address)", _user)
        );
        if (ok2 && r2.length >= 96) {
            (uint256 streak, , ) = abi.decode(r2, (uint256, uint256, uint256));
            d.streakDays = streak;
        }

        // deferredRewardAmount(address) → uint256
        (bool ok3, bytes memory r3) = gamificationModule.staticcall(
            abi.encodeWithSignature("deferredRewardAmount(address)", _user)
        );
        if (ok3 && r3.length >= 32) d.deferredRewardAmount = abi.decode(r3, (uint256));
    }

    function _fillWithdrawalInfo(address _user, DashboardData memory d) internal view {
        d.dailyWithdrawalLimit = 2_000 ether;

        // circuitBreakerEnabled()
        (bool ok1, bytes memory r1) = stakingContract.staticcall(
            abi.encodeWithSignature("circuitBreakerEnabled()")
        );
        if (ok1 && r1.length >= 32) d.circuitBreakerActive = abi.decode(r1, (bool));

        // getDailyWithdrawalUsed(address) — added in v7.0 if exposed
        (bool ok2, bytes memory r2) = stakingContract.staticcall(
            abi.encodeWithSignature("getDailyWithdrawalUsed(address)", _user)
        );
        if (ok2 && r2.length >= 32) d.dailyWithdrawalUsed = abi.decode(r2, (uint256));

        d.dailyWithdrawalRemaining = d.dailyWithdrawalUsed >= d.dailyWithdrawalLimit
            ? 0
            : d.dailyWithdrawalLimit - d.dailyWithdrawalUsed;
    }

    function _fillReinvestment(address _user, DashboardData memory d) internal view {
        // reinvestmentPercentage(address)
        (bool ok1, bytes memory r1) = stakingContract.staticcall(
            abi.encodeWithSignature("reinvestmentPercentage(address)", _user)
        );
        if (ok1 && r1.length >= 32) d.reinvestmentPct = abi.decode(r1, (uint256));

        // autoCompoundEnabled from gamification (getAutoCompoundConfig)
        if (gamificationModule != address(0)) {
            (bool ok2, bytes memory r2) = gamificationModule.staticcall(
                abi.encodeWithSignature("getAutoCompoundConfig(address)", _user)
            );
            // Returns (enabled, reinvestPct, lastCompoundTime) or similar
            if (ok2 && r2.length >= 32) {
                (bool enabled, , ) = abi.decode(r2, (bool, uint256, uint256));
                d.autoCompoundEnabled = enabled;
            }
        }
    }

    function _fillReferral(address _user, DashboardData memory d) internal view {
        // referrers(address)
        (bool ok1, bytes memory r1) = stakingContract.staticcall(
            abi.encodeWithSignature("referrers(address)", _user)
        );
        if (ok1 && r1.length >= 32) d.referrer = abi.decode(r1, (address));

        // referralBoostBps() — protocol-wide referral boost
        (bool ok2, bytes memory r2) = stakingContract.staticcall(
            abi.encodeWithSignature("referralBoostBps()")
        );
        if (ok2 && r2.length >= 32) d.referralBoostBps = abi.decode(r2, (uint256));
    }

    function _fillProjections(DashboardData memory d) internal pure {
        if (d.totalDeposited == 0 || d.boostedAPYs[0] == 0) return;

        // Use the weighted average boosted APY across deposit types as a simple projection.
        // For accuracy we'd weight by lockup, but this is a good-enough dashboard estimate.
        // Uses the first slot (flexible APY) as the conservative estimate.
        uint256 effectiveAPYBps = d.boostedAPYs[0];
        d.projectedYearlyRewards  = (d.totalDeposited * effectiveAPYBps) / 10_000;
        // Daily = yearly / 365, Monthly = yearly / 12
        d.projectedDailyRewards   = d.projectedYearlyRewards / 365;
        d.projectedMonthlyRewards = d.projectedYearlyRewards / 12;
    }
}
