#!/usr/bin/env node
"use strict";

/**
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║  NUXCHAIN PROTOCOL — POLYGONSCAN VERIFICATION                  ║
 * ║                                                                  ║
 * ║  Verifies every deployed contract on Polygonscan.               ║
 * ║  For UUPS proxies it reads the EIP-1967 implementation slot     ║
 * ║  and verifies both proxy and implementation.                    ║
 * ║                                                                  ║
 * ║  Usage:                                                          ║
 * ║    npx hardhat run scripts/verify.cjs --network polygon          ║
 * ╚══════════════════════════════════════════════════════════════════╝
 */

const hre  = require("hardhat");
const { ethers } = hre;
const fs   = require("fs");
const path = require("path");
require("dotenv").config();

const IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function loadDeployment() {
    const file = path.join(__dirname, "..", "deployments", "complete-deployment.json");
    if (!fs.existsSync(file)) {
        throw new Error("❌ complete-deployment.json not found. Run deploy.cjs first.");
    }
    return JSON.parse(fs.readFileSync(file, "utf8"));
}

async function getImpl(proxyAddress) {
    const raw = await ethers.provider.getStorage(proxyAddress, IMPL_SLOT);
    return "0x" + raw.slice(-40);
}

async function verify(address, contractPath, constructorArgs, label) {
    try {
        await hre.run("verify:verify", {
            address,
            contract: contractPath,
            constructorArguments: constructorArgs ?? [],
        });
        console.log(`   ✅ ${label ?? address}`);
        return true;
    } catch (err) {
        if (/already.?verified/i.test(err.message)) {
            console.log(`   ⏭️  ${label ?? address} (already verified)`);
            return true;
        }
        console.error(`   ❌ ${label ?? address}: ${err.message}`);
        return false;
    }
}

async function main() {
    const data = loadDeployment();
    const tm   = data.contracts.treasury;
    const st   = data.contracts.staking;
    const mp   = data.contracts.marketplace;

    let passed = 0;
    let failed = 0;

    const ok  = () => passed++;
    const bad = () => failed++;

    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  🔍 NUXCHAIN — POLYGONSCAN BATCH VERIFICATION                              ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝\n");
    console.log("⏳ Note: waiting 2s between submissions to avoid API rate-limits\n");

    // ── Treasury ──────────────────────────────────────────────────────────────
    console.log("── TREASURY ──────────────────────────────────────────────────────────────────");
    (await verify(tm.manager,        "contracts/Treasury/TreasuryManager.sol:TreasuryManager", [], "TreasuryManager"))        ? ok() : bad(); await sleep(2000);
    (await verify(tm.questRewardsPool,"contracts/Treasury/QuestRewardsPool.sol:QuestRewardsPool", [data.deployment.deployer], "QuestRewardsPool")) ? ok() : bad(); await sleep(2000);

    // ── Smart Staking — plain contracts ───────────────────────────────────────
    console.log("\n── SMART STAKING ─────────────────────────────────────────────────────────────");
    (await verify(st.rewards,      "contracts/SmartStaking/SmartStakingRewards.sol:SmartStakingRewards",           [], "SmartStakingRewards"))      ? ok() : bad(); await sleep(2000);
    (await verify(st.power,        "contracts/SmartStaking/SmartStakingPower.sol:SmartStakingPower",               [], "SmartStakingPower"))          ? ok() : bad(); await sleep(2000);
    (await verify(st.gamification, "contracts/SmartStaking/SmartStakingGamification.sol:SmartStakingGamification", [], "SmartStakingGamification"))   ? ok() : bad(); await sleep(2000);
    (await verify(st.dynamicAPY,   "contracts/SmartStaking/DynamicAPYCalculator.sol:DynamicAPYCalculator",         [], "DynamicAPYCalculator"))       ? ok() : bad(); await sleep(2000);
    (await verify(st.skillViewLib, "contracts/SmartStaking/SkillViewLib.sol:SkillViewLib",                         [], "SkillViewLib"))               ? ok() : bad(); await sleep(2000);
    (await verify(st.viewCore,     "contracts/SmartStaking/SmartStakingViewCore.sol:SmartStakingViewCore",         [st.core], "SmartStakingViewCore")) ? ok() : bad(); await sleep(2000);
    (await verify(st.viewStats,    "contracts/SmartStaking/SmartStakingViewStats.sol:SmartStakingViewStats",       [st.core], "SmartStakingViewStats")) ? ok() : bad(); await sleep(2000);
    (await verify(st.viewSkills,   "contracts/SmartStaking/SmartStakingViewSkills.sol:SmartStakingViewSkills",     [st.core], "SmartStakingViewSkills")) ? ok() : bad(); await sleep(2000);
    (await verify(st.viewDashboard,"contracts/SmartStaking/SmartStakingViewDashboard.sol:SmartStakingViewDashboard",[st.core, st.rewards, st.power, st.gamification], "SmartStakingViewDashboard")) ? ok() : bad(); await sleep(2000);

    // UUPS: verify implementation of Core
    console.log("   (UUPS) SmartStakingCore proxy implementation...");
    const coreImpl = await getImpl(st.core);
    (await verify(coreImpl, "contracts/SmartStaking/SmartStakingCore.sol:SmartStakingCore", [], "SmartStakingCore impl")) ? ok() : bad(); await sleep(2000);

    // ── Marketplace — UUPS proxies ─────────────────────────────────────────────
    console.log("\n── MARKETPLACE ───────────────────────────────────────────────────────────────");

    // UUPS proxy implementations
    const mktCoreImpl  = await getImpl(mp.core);
    const levelingImpl = await getImpl(mp.leveling);
    const referralImpl = await getImpl(mp.referral);
    const questImpl    = await getImpl(mp.questCore);
    const collabImpl   = await getImpl(mp.collaboratorRewards);

    (await verify(mktCoreImpl,  "contracts/Marketplace/MarketplaceCore.sol:MarketplaceCore",                       [], "MarketplaceCore impl"))            ? ok() : bad(); await sleep(2000);
    (await verify(levelingImpl, "contracts/Leveling/LevelingSystem.sol:LevelingSystem",                            [], "LevelingSystem impl"))              ? ok() : bad(); await sleep(2000);
    (await verify(referralImpl, "contracts/Referral/ReferralSystem.sol:ReferralSystem",                            [], "ReferralSystem impl"))              ? ok() : bad(); await sleep(2000);
    (await verify(questImpl,    "contracts/Quest/QuestCore.sol:QuestCore",                                         [], "QuestCore impl"))                   ? ok() : bad(); await sleep(2000);
    (await verify(collabImpl,   "contracts/Rewards/CollaboratorBadgeRewards.sol:CollaboratorBadgeRewards",         [], "CollaboratorBadgeRewards impl"))     ? ok() : bad(); await sleep(2000);

    // Plain marketplace contracts
    (await verify(mp.view,       "contracts/Analytics/MarketplaceView.sol:MarketplaceView",           [data.deployment.deployer, mp.core], "MarketplaceView"))    ? ok() : bad(); await sleep(2000);
    (await verify(mp.statistics, "contracts/Analytics/MarketplaceStatistics.sol:MarketplaceStatistics",[data.deployment.deployer, mp.core], "MarketplaceStatistics")) ? ok() : bad(); await sleep(2000);
    (await verify(mp.social,     "contracts/Social/MarketplaceSocial.sol:MarketplaceSocial",           [data.deployment.deployer, mp.core], "MarketplaceSocial"))  ? ok() : bad(); await sleep(2000);
    (await verify(mp.nuxPowerNft,"contracts/NuxPower/NuxPowerNft.sol:NuxPowerNft",                     [mp.core], "NuxPowerNft"))                                   ? ok() : bad(); await sleep(2000);
    (await verify(mp.nuxPowerMarketplace,"contracts/NuxPower/NuxPowerMarketplace.sol:NuxPowerMarketplace",[mp.core, data.deployment.deployer],"NuxPowerMarketplace")) ? ok() : bad(); await sleep(2000);

    console.log(`\n╔══════════════════════════════════════════════════════════════════════════════╗`);
    console.log(`║  VERIFICATION SUMMARY                                                      ║`);
    console.log(`║  ✅ Passed: ${String(passed).padEnd(3)}   ❌ Failed: ${String(failed).padEnd(3)}                                ║`);
    console.log(`╚══════════════════════════════════════════════════════════════════════════════╝\n`);

    if (failed > 0) process.exit(1);
}

main()
    .then(() => process.exit(0))
    .catch((err) => { console.error(err); process.exit(1); });
