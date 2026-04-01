const hre = require("hardhat");
const fs = require("fs");

// Minimal ABI snippets to read treasury references from each contract
const STAKING_CORE_ABI = [
    "function treasuryManager() view returns (address)",
    "function treasury() view returns (address)",
    "function treasuryAddress() view returns (address)",
    "function getCommissionAddress() view returns (address)",
    "function commissionAddress() view returns (address)",
    "function platformTreasury() view returns (address)",
];

const MARKETPLACE_ABI = [
    "function treasuryManager() view returns (address)",
    "function treasury() view returns (address)",
    "function platformTreasury() view returns (address)",
];

const SKILLS_ABI = [
    "function treasuryManager() view returns (address)",
    "function treasury() view returns (address)",
    "function treasuryAddress() view returns (address)",
];

async function tryRead(contract, fnName) {
    try {
        return await contract[fnName]();
    } catch {
        return null;
    }
}

async function main() {
    const addrs = JSON.parse(fs.readFileSync("./deployments/polygon-addresses.json", "utf8"));
    const TREASURY_MANAGER = addrs.treasury.manager;
    const STAKING_CORE     = addrs.staking.core;
    const MARKETPLACE      = addrs.marketplace.proxy;
    const SKILLS           = addrs.marketplace.nuxPowers;
    const OLD_TREASURY     = "0x9a7fac014e2056835878d1866651d673b0ba9407";

    console.log("═".repeat(70));
    console.log("  TREASURY ADDRESS DIAGNOSTICS");
    console.log("  Expected TreasuryManager:", TREASURY_MANAGER);
    console.log("═".repeat(70));

    // Check old treasury balance
    const oldBal = await hre.ethers.provider.getBalance(OLD_TREASURY);
    const newBal = await hre.ethers.provider.getBalance(TREASURY_MANAGER);
    console.log("\n📍 Balance check:");
    console.log("  OLD treasury wallet      :", hre.ethers.formatEther(oldBal), "POL →", OLD_TREASURY);
    console.log("  NEW TreasuryManager      :", hre.ethers.formatEther(newBal), "POL →", TREASURY_MANAGER);

    // Check StakingCore
    console.log("\n📍 StakingCore treasury references:");
    const staking = new hre.ethers.Contract(STAKING_CORE, STAKING_CORE_ABI, hre.ethers.provider);
    for (const fn of ["treasuryManager", "treasury", "treasuryAddress", "platformTreasury", "commissionAddress"]) {
        const v = await tryRead(staking, fn);
        if (v) console.log(`  .${fn}() =`, v, v.toLowerCase() === TREASURY_MANAGER.toLowerCase() ? "✅ CORRECT" : "❌ WRONG — not pointing to TreasuryManager");
    }

    // Check Marketplace
    console.log("\n📍 Marketplace treasury references:");
    const mkt = new hre.ethers.Contract(MARKETPLACE, MARKETPLACE_ABI, hre.ethers.provider);
    for (const fn of ["treasuryManager", "treasury", "platformTreasury"]) {
        const v = await tryRead(mkt, fn);
        if (v) console.log(`  .${fn}() =`, v, v.toLowerCase() === TREASURY_MANAGER.toLowerCase() ? "✅ CORRECT" : "❌ WRONG");
    }

    // Check nuxPowers
    console.log("\n📍 nuxPowers treasury references:");
    const skills = new hre.ethers.Contract(SKILLS, SKILLS_ABI, hre.ethers.provider);
    for (const fn of ["treasuryManager", "treasury", "treasuryAddress"]) {
        const v = await tryRead(skills, fn);
        if (v) console.log(`  .${fn}() =`, v, v.toLowerCase() === TREASURY_MANAGER.toLowerCase() ? "✅ CORRECT" : "❌ WRONG");
    }

    console.log("\n" + "═".repeat(70));
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
