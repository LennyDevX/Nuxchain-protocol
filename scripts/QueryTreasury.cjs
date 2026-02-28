const hre = require("hardhat");
const fs = require("fs");

/**
 * @title TreasuryManager — Complete Pool Balance Report
 * @notice Read-only diagnostic: fetches all financial state from TreasuryManager on-chain
 *
 * Usage:
 *   npx hardhat run scripts/QueryTreasury.cjs --network polygon
 */

// ─── helpers ────────────────────────────────────────────────────────────────

const fmt   = (wei)     => Number(hre.ethers.formatEther(wei)).toFixed(6) + " POL";
const fmtPct = (bps)    => (Number(bps) / 100).toFixed(2) + "%";
const fmtDate = (ts)    => ts > 0 ? new Date(Number(ts) * 1000).toLocaleString() : "—";
const fmtDur  = (secs)  => {
    if (secs <= 0) return "READY NOW ✅";
    const d = Math.floor(secs / 86400);
    const h = Math.floor((secs % 86400) / 3600);
    const m = Math.floor((secs % 3600) / 60);
    const s = secs % 60;
    return `${d}d ${h}h ${m}m ${s}s`;
};

const TREASURY_TYPES = ["REWARDS", "STAKING", "COLLABORATORS", "DEVELOPMENT", "MARKETPLACE"];
const PROTOCOL_STATUS = ["HEALTHY ✅", "UNSTABLE ⚠️", "CRITICAL 🔴", "EMERGENCY 🚨"];

const bar = (label, len = 80) =>
    `╔${"═".repeat(len - 2)}╗\n║  ${label.padEnd(len - 4)}║\n╚${"═".repeat(len - 2)}╝`;

// ─── main ───────────────────────────────────────────────────────────────────

async function main() {
    console.clear();
    console.log("\n" + bar("  TREASURY MANAGER — COMPLETE POOL BALANCE REPORT  ", 80));
    console.log(`\n  Generated: ${new Date().toLocaleString()}`);
    console.log(`  Network  : ${hre.network.name}\n`);

    // ── load address ──────────────────────────────────────────────────────
    let TREASURY_MANAGER;
    const envPath = "./.env";
    const addrPath = "./deployments/polygon-addresses.json";

    try {
        const addrs = JSON.parse(fs.readFileSync(addrPath, "utf8"));
        TREASURY_MANAGER = addrs.treasury.manager;
    } catch {
        // fallback: read from .env VITE_TREASURY_MANAGER_ADDRESS
        const env = fs.readFileSync(envPath, "utf8");
        const m = env.match(/VITE_TREASURY_MANAGER_ADDRESS\s*=\s*(\S+)/);
        if (!m) throw new Error("TreasuryManager address not found in polygon-addresses.json or .env");
        TREASURY_MANAGER = m[1];
    }

    console.log(`  Contract : ${TREASURY_MANAGER}\n`);

    // ── connect ───────────────────────────────────────────────────────────
    const tm = await hre.ethers.getContractAt("TreasuryManager", TREASURY_MANAGER);

    // ─────────────────────────────────────────────────────────────────────
    // 1. BALANCES
    // ─────────────────────────────────────────────────────────────────────
    console.log(bar("  1. BALANCES", 80));

    const [
        totalReceived,
        totalDist,
        currentBalance,
        availableBalance,
        lastDistTime,
        autoDistEnabled,
    ] = await tm.getStats();

    const rawBalance      = await hre.ethers.provider.getBalance(TREASURY_MANAGER);
    const reserveBalance  = await tm.reserveFundBalance();

    console.log(`\n  On-chain balance (raw)     : ${fmt(rawBalance)}`);
    console.log(`  Available for distribution : ${fmt(availableBalance)}`);
    console.log(`  Reserve fund (locked)      : ${fmt(reserveBalance)}`);
    console.log(`  ─────────────────────────────────────────────`);
    console.log(`  Total revenue ever received: ${fmt(totalReceived)}`);
    console.log(`  Total distributed to date  : ${fmt(totalDist)}`);
    const pending = rawBalance > reserveBalance ? rawBalance - reserveBalance : 0n;
    console.log(`  Pending (undistributed)    : ${fmt(pending)}`);
    console.log(`  Auto-distribution enabled  : ${autoDistEnabled ? "Yes ✅" : "No ❌"}`);

    // ─────────────────────────────────────────────────────────────────────
    // 2. DISTRIBUTION TIMELINE
    // ─────────────────────────────────────────────────────────────────────
    console.log("\n" + bar("  2. DISTRIBUTION TIMELINE", 80));

    const [firstDeposit, lastDist, nextDist, timeUntilNext, isReady] =
        await tm.getDistributionTimeline();

    const [readyNow] = await tm.isDistributionReady();

    console.log(`\n  First deposit              : ${fmtDate(firstDeposit)}`);
    console.log(`  Last distribution          : ${fmtDate(lastDist)}`);
    console.log(`  Next distribution          : ${fmtDate(nextDist)}`);
    console.log(`  Time until next            : ${fmtDur(Number(timeUntilNext))}`);
    console.log(`  Distribution ready now     : ${readyNow ? "YES ✅  — call triggerDistribution()" : "Not yet ⏳"}`);

    // Cycle day progress
    if (firstDeposit > 0n) {
        const SEVEN_DAYS = 7 * 24 * 3600;
        const elapsed = Number(BigInt(Math.floor(Date.now() / 1000)) - lastDist);
        const progress = Math.min(Math.round((elapsed / SEVEN_DAYS) * 100), 100);
        const bar7 = "█".repeat(Math.floor(progress / 5)) + "░".repeat(20 - Math.floor(progress / 5));
        console.log(`\n  Weekly cycle progress      : [${bar7}] ${progress}%`);
    } else {
        console.log(`\n  ⚠️  Distribution cycle NOT initialized — no deposits received yet.`);
    }

    // ─────────────────────────────────────────────────────────────────────
    // 3. RESERVE FUND
    // ─────────────────────────────────────────────────────────────────────
    console.log("\n" + bar("  3. RESERVE FUND", 80));

    const [resBalance, resAccumulated, resWithdrawn, resAllocPct, resEnabled] =
        await tm.getReserveStats();

    console.log(`\n  Reserve fund balance       : ${fmt(resBalance)}`);
    console.log(`  Total accumulated          : ${fmt(resAccumulated)}`);
    console.log(`  Total withdrawn            : ${fmt(resWithdrawn)}`);
    console.log(`  Allocation (% of revenue)  : ${fmtPct(resAllocPct)}`);
    console.log(`  Auto-accumulation          : ${resEnabled ? "Enabled ✅" : "Disabled ❌"}`);

    // Runway estimate (use last 30-day avg if possible, else show raw calc)
    if (resBalance > 0n) {
        // Estimate: if distributed monthly ~ totalDist / months since deploy
        const secondsSinceFirst = firstDeposit > 0n
            ? BigInt(Math.floor(Date.now() / 1000)) - firstDeposit
            : 1n;
        const months = secondsSinceFirst / BigInt(30 * 24 * 3600);
        if (months > 0n) {
            const monthlyBurn = totalDist / (months > 0n ? months : 1n);
            if (monthlyBurn > 0n) {
                const runway = resBalance / monthlyBurn;
                console.log(`  Estimated runway           : ~${runway} months (based on avg monthly distribution)`);
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // 4. ALLOCATION BREAKDOWN
    // ─────────────────────────────────────────────────────────────────────
    console.log("\n" + bar("  4. ALLOCATION BREAKDOWN (of distributable 80%)", 80));

    const [rewardsAlloc, stakingAlloc, collabAlloc, devAlloc, marketAlloc] =
        await tm.getAllAllocations();

    const allocMap = {
        REWARDS:       rewardsAlloc,
        STAKING:       stakingAlloc,
        COLLABORATORS: collabAlloc,
        DEVELOPMENT:   devAlloc,
        MARKETPLACE:   marketAlloc,
    };

    const distributable = pending > 0n ? (pending * 8000n) / 10000n : 0n; // 80% after reserve
    console.log(`\n  Distributable amount (est.): ${fmt(distributable)}`);
    console.log(`\n  ${"TYPE".padEnd(16)} ${"ALLOC".padEnd(8)} ${"EST. AMOUNT".padEnd(18)} ADDRESS`);
    console.log(`  ${"─".repeat(72)}`);

    for (const [typeName, allocBps] of Object.entries(allocMap)) {
        const typeIdx = TREASURY_TYPES.indexOf(typeName);
        const [addr] = await tm.getTreasuryConfig(typeIdx);
        const estAmt = distributable > 0n ? (distributable * allocBps) / 10000n : 0n;
        const addrStr = addr === "0x0000000000000000000000000000000000000000" ? "(not set)" : addr;
        console.log(
            `  ${typeName.padEnd(16)} ${fmtPct(allocBps).padEnd(8)} ${fmt(estAmt).padEnd(18)} ${addrStr}`
        );
    }

    // ─────────────────────────────────────────────────────────────────────
    // 5. AUTHORIZED SOURCES
    // ─────────────────────────────────────────────────────────────────────
    console.log("\n" + bar("  5. AUTHORIZED REVENUE SOURCES", 80));

    let addresses;
    try {
        addresses = JSON.parse(fs.readFileSync(addrPath, "utf8"));
    } catch { addresses = null; }

    const sources = addresses
        ? [
            { name: "StakingCore",        addr: addresses.staking?.core },
            { name: "Marketplace",        addr: addresses.marketplace?.proxy },
            { name: "IndividualSkills",   addr: addresses.marketplace?.individualSkills },
          ]
        : [];

    console.log();
    if (sources.length === 0) {
        console.log("  (Could not load polygon-addresses.json to check sources)");
    }

    for (const { name, addr } of sources) {
        if (!addr) { console.log(`  ${name.padEnd(20)}: address not found`); continue; }
        const isAuth = await tm.authorizedSources(addr);
        console.log(`  ${name.padEnd(20)}: ${addr}  →  ${isAuth ? "✅ AUTHORIZED" : "❌ NOT AUTHORIZED"}`);
    }

    // ─────────────────────────────────────────────────────────────────────
    // 6. EMERGENCY & PROTOCOL STATUS
    // ─────────────────────────────────────────────────────────────────────
    console.log("\n" + bar("  6. EMERGENCY & PROTOCOL STATUS", 80));

    const [isEmergency, emergencyTs, emergencyFunds, reserveAvail] =
        await tm.getEmergencyInfo();

    console.log(`\n  Emergency mode active      : ${isEmergency ? "YES 🚨" : "No ✅"}`);
    if (isEmergency) {
        console.log(`  Emergency declared at      : ${fmtDate(emergencyTs)}`);
    }
    console.log(`  Emergency funds used       : ${fmt(emergencyFunds)}`);
    console.log(`  Reserve available          : ${fmt(reserveAvail)}`);

    console.log(`\n  ${"PROTOCOL".padEnd(16)} ${"STATUS".padEnd(22)} DEFICIT`);
    console.log(`  ${"─".repeat(56)}`);

    for (let i = 0; i < TREASURY_TYPES.length; i++) {
        const [status, deficit, canAccess] = await tm.getProtocolStatus(i);
        const statusStr = PROTOCOL_STATUS[Number(status)] ?? "UNKNOWN";
        console.log(
            `  ${TREASURY_TYPES[i].padEnd(16)} ${statusStr.padEnd(22)} ${deficit > 0n ? fmt(deficit) : "—"}`
        );
    }

    // ─────────────────────────────────────────────────────────────────────
    // 7. OWNER & DEPLOYER
    // ─────────────────────────────────────────────────────────────────────
    console.log("\n" + bar("  7. OWNERSHIP", 80));

    const owner = await tm.owner();
    const [signer] = await hre.ethers.getSigners();
    const isOwner = owner.toLowerCase() === signer.address.toLowerCase();
    console.log(`\n  Owner                      : ${owner}`);
    console.log(`  Current signer             : ${signer.address}`);
    console.log(`  Is owner                   : ${isOwner ? "Yes ✅" : "No ❌"}`);

    // ─────────────────────────────────────────────────────────────────────
    // 8. SUMMARY / HEALTH SCORE
    // ─────────────────────────────────────────────────────────────────────
    console.log("\n" + bar("  8. HEALTH SUMMARY", 80));

    let score = 100;
    const issues = [];

    if (rawBalance === 0n)          { score -= 30; issues.push("❌ Treasury balance is ZERO — no funds received yet"); }
    if (!isEmergency && score === 100) issues.push("✅ No emergency active");
    if (!autoDistEnabled)           { score -= 10; issues.push("⚠️  Auto-distribution is DISABLED"); }
    if (firstDeposit === 0n)        { score -= 20; issues.push("⚠️  Distribution cycle NOT started — needs first deposit"); }
    else if (readyNow)              { score -= 5;  issues.push("⏰ Distribution is READY — consider calling triggerDistribution()"); }
    if (resBalance === 0n)          { score -= 10; issues.push("⚠️  Reserve fund is empty"); }
    if (sources.length > 0) {
        for (const { name, addr } of sources) {
            if (!addr) continue;
            const isAuth = await tm.authorizedSources(addr);
            if (!isAuth) { score -= 15; issues.push(`❌ ${name} is NOT authorized as revenue source`); }
        }
    }

    const healthBar = "█".repeat(Math.floor(score / 5)) + "░".repeat(20 - Math.floor(score / 5));
    const healthLabel = score >= 80 ? "HEALTHY ✅" : score >= 50 ? "NEEDS ATTENTION ⚠️" : "CRITICAL 🔴";

    console.log(`\n  Health Score               : [${healthBar}] ${score}/100 — ${healthLabel}`);
    console.log("\n  Details:");
    for (const issue of issues) console.log(`     ${issue}`);

    // ─────────────────────────────────────────────────────────────────────
    // 9. QUICK ACTIONS (informational)
    // ─────────────────────────────────────────────────────────────────────
    console.log("\n" + bar("  9. QUICK ACTIONS", 80));
    console.log(`
  Fund treasury (direct transfer):
    npx hardhat console --network polygon
    > const tm = await ethers.getContractAt("TreasuryManager", "${TREASURY_MANAGER}")
    > await (await ethers.getSigners())[0].sendTransaction({ to: "${TREASURY_MANAGER}", value: ethers.parseEther("10") })

  Fund reserve (owner only):
    > await tm.depositToReserve({ value: ethers.parseEther("5") })

  Trigger distribution (anyone, once 7 days have passed):
    > await tm.triggerDistribution()

  Re-run this report:
    npx hardhat run scripts/QueryTreasury.cjs --network polygon
`);

    console.log("═".repeat(80) + "\n");
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error(err);
        process.exit(1);
    });
