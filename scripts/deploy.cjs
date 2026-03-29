#!/usr/bin/env node
"use strict";

/**
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║  NUXCHAIN PROTOCOL — FULL DEPLOYMENT SCRIPT                    ║
 * ║                                                                  ║
 * ║  Phase 0 · TreasuryManager                                      ║
 * ║  Phase 1 · SmartStaking (11 contracts + library)                ║
 * ║  Phase 2 · Marketplace   (10 contracts)                         ║
 * ║                                                                  ║
 * ║  Total: ~23 contracts deployed + configured                     ║
 * ║                                                                  ║
 * ║  Usage:                                                          ║
 * ║    npx hardhat run scripts/deploy.cjs --network polygon          ║
 * ╚══════════════════════════════════════════════════════════════════╝
 */

const { ethers, network, upgrades } = require("hardhat");
const fs   = require("fs");
const path = require("path");
require("dotenv").config();

// ─── helpers ────────────────────────────────────────────────────────────────

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitForCode(address, { name = address, retries = 20, delay = 3000 } = {}) {
    for (let i = 0; i < retries; i++) {
        const code = await ethers.provider.getCode(address);
        if (code && code !== "0x") return;
        process.stdout.write(`   ⏳ Waiting for ${name} bytecode... (${i + 1}/${retries})\r`);
        await sleep(delay);
    }
    console.warn(`\n   ⚠️  ${name}: bytecode not detected after ${retries} retries`);
}

async function deployPlain(factory, args, label) {
    process.stdout.write(`\n📦 Deploying ${label}...\n`);
    const c = args.length ? await factory.deploy(...args) : await factory.deploy();
    const tx = c.deploymentTransaction();
    if (tx) console.log(`   TX: ${tx.hash}`);
    await c.waitForDeployment();
    const addr = await c.getAddress();
    console.log(`   ✅ ${label}: ${addr}`);
    await waitForCode(addr, { name: label });
    return { contract: c, address: addr };
}

async function deployUUPS(factory, initArgs, label) {
    process.stdout.write(`\n📦 Deploying ${label} (UUPS proxy)...\n`);
    const c = await upgrades.deployProxy(factory, initArgs, {
        initializer: "initialize",
        kind: "uups",
    });
    await c.waitForDeployment();
    const addr = await c.getAddress();
    console.log(`   ✅ ${label} proxy: ${addr}`);
    await waitForCode(addr, { name: label });
    return { contract: c, address: addr };
}

function saveDeployment(data) {
    const dir = path.join(__dirname, "..", "deployments");
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, "complete-deployment.json");
    fs.writeFileSync(file, JSON.stringify(data, null, 2));
    // Also write flat address file for easy consumption
    const flat = {};
    for (const [section, entries] of Object.entries(data.contracts)) {
        for (const [key, val] of Object.entries(entries)) {
            flat[`${section}.${key}`] = val;
        }
    }
    fs.writeFileSync(path.join(dir, "addresses.json"), JSON.stringify(flat, null, 2));
    console.log(`\n💾 Deployment data saved to deployments/complete-deployment.json`);
}

// ─── main ───────────────────────────────────────────────────────────────────

async function main() {
    const TREASURY_ADDRESS = process.env.TREASURY_ADDRESS;
    if (!TREASURY_ADDRESS) throw new Error("❌ TREASURY_ADDRESS not set in .env");

    const [deployer] = await ethers.getSigners();
    const balance    = await ethers.provider.getBalance(deployer.address);
    const chainId    = (await ethers.provider.getNetwork()).chainId;

    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  🚀 NUXCHAIN PROTOCOL — FULL DEPLOYMENT                                    ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");
    console.log(`\n   Deployer  : ${deployer.address}`);
    console.log(`   Balance   : ${ethers.formatEther(balance)} POL`);
    console.log(`   Network   : ${network.name} (chainId ${chainId})`);
    console.log(`   Treasury  : ${TREASURY_ADDRESS}\n`);

    const d = {
        deployment: {
            network: network.name,
            chainId: chainId.toString(),
            deployer: deployer.address,
            timestamp: new Date().toISOString(),
        },
        contracts: {
            treasury:    {},
            staking:     {},
            marketplace: {},
        },
    };

    // ══════════════════════════════════════════════════════════════════════════
    // PHASE 0 — TREASURY MANAGER
    // ══════════════════════════════════════════════════════════════════════════
    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 0 · TREASURY                                                        ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");

    const TreasuryF = await ethers.getContractFactory("TreasuryManager");
    const { contract: treasury, address: treasuryAddr } =
        await deployPlain(TreasuryF, [], "TreasuryManager");
    d.contracts.treasury.manager = treasuryAddr;

    const QuestRewardsF = await ethers.getContractFactory("QuestRewardsPool");
    const { contract: questRewards, address: questRewardsAddr } =
        await deployPlain(QuestRewardsF, [deployer.address], "QuestRewardsPool");
    d.contracts.treasury.questRewardsPool = questRewardsAddr;

    // ══════════════════════════════════════════════════════════════════════════
    // PHASE 1 — SMART STAKING (11 contracts + 1 library)
    // ══════════════════════════════════════════════════════════════════════════
    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 1 · SMART STAKING                                                   ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");

    // 1.1 Deploy independent modules first (no cross-deps)
    const RewardsF = await ethers.getContractFactory("SmartStakingRewards");
    const { contract: stakingRewards, address: stakingRewardsAddr } =
        await deployPlain(RewardsF, [], "SmartStakingRewards");
    d.contracts.staking.rewards = stakingRewardsAddr;

    const PowerF = await ethers.getContractFactory("SmartStakingPower");
    const { contract: stakingPower, address: stakingPowerAddr } =
        await deployPlain(PowerF, [], "SmartStakingPower");
    d.contracts.staking.power = stakingPowerAddr;

    const GamF = await ethers.getContractFactory("SmartStakingGamification");
    const { contract: stakingGam, address: stakingGamAddr } =
        await deployPlain(GamF, [], "SmartStakingGamification");
    d.contracts.staking.gamification = stakingGamAddr;

    const APYF = await ethers.getContractFactory("DynamicAPYCalculator");
    const { address: apyAddr } = await deployPlain(APYF, [], "DynamicAPYCalculator");
    d.contracts.staking.dynamicAPY = apyAddr;

    // 1.2 Deploy SkillViewLib (external library — required by Core)
    const LibF = await ethers.getContractFactory("SkillViewLib");
    const { address: skillViewLibAddr } = await deployPlain(LibF, [], "SkillViewLib");
    d.contracts.staking.skillViewLib = skillViewLibAddr;

    // 1.3 Deploy Core (UUPS proxy — links to library)
    const CoreF = await ethers.getContractFactory("SmartStakingCoreV2", {
        libraries: { SkillViewLib: skillViewLibAddr },
    });
    const { contract: stakingCore, address: stakingCoreAddr } =
        await deployUUPS(CoreF, [TREASURY_ADDRESS], "SmartStakingCoreV2");
    d.contracts.staking.core = stakingCoreAddr;

    // 1.4 Deploy view contracts (need Core address)
    const ViewCoreF = await ethers.getContractFactory("SmartStakingViewCore");
    const { address: viewCoreAddr } =
        await deployPlain(ViewCoreF, [stakingCoreAddr], "SmartStakingViewCore");
    d.contracts.staking.viewCore = viewCoreAddr;

    const ViewStatsF = await ethers.getContractFactory("SmartStakingViewStats");
    const { address: viewStatsAddr } =
        await deployPlain(ViewStatsF, [stakingCoreAddr], "SmartStakingViewStats");
    d.contracts.staking.viewStats = viewStatsAddr;

    const ViewSkillsF = await ethers.getContractFactory("SmartStakingViewSkills");
    const { address: viewSkillsAddr } =
        await deployPlain(ViewSkillsF, [stakingCoreAddr], "SmartStakingViewSkills");
    d.contracts.staking.viewSkills = viewSkillsAddr;

    // 1.5 Deploy SmartStakingViewDashboard (needs core + all module addresses)
    const ViewDashF = await ethers.getContractFactory("SmartStakingViewDashboard");
    const { address: viewDashAddr } = await deployPlain(
        ViewDashF,
        [stakingCoreAddr, stakingRewardsAddr, stakingPowerAddr, stakingGamAddr],
        "SmartStakingViewDashboard"
    );
    d.contracts.staking.viewDashboard = viewDashAddr;

    // ── Staking phase wiring ─────────────────────────────────────────────────
    console.log("\n🔗 Wiring SmartStaking modules...");

    // Core → modules
    const tx1 = await stakingCore.setRewardsModule(stakingRewardsAddr);
    const tx2 = await stakingCore.setPowerModule(stakingPowerAddr);
    const tx3 = await stakingCore.setGamificationModule(stakingGamAddr);
    await Promise.all([tx1.wait(1), tx2.wait(1), tx3.wait(1)]);
    console.log("   ✅ Core → Rewards / Power / Gamification");

    // Core → TreasuryManager
    const tx4 = await stakingCore.setTreasuryManager(treasuryAddr);
    await tx4.wait(1);
    console.log("   ✅ Core → TreasuryManager");

    // Rewards → Core
    const tx5 = await stakingRewards.setCoreStakingContract(stakingCoreAddr);
    await tx5.wait(1);
    console.log("   ✅ Rewards → Core");

    // Power → Core
    const tx6 = await stakingPower.setCoreStakingContract(stakingCoreAddr);
    await tx6.wait(1);
    console.log("   ✅ Power → Core");

    // Gamification → Core
    const tx7 = await stakingGam.setCoreStakingContract(stakingCoreAddr);
    await tx7.wait(1);
    console.log("   ✅ Gamification → Core");

    // TreasuryManager authorizes Core as revenue source
    const tx8 = await treasury.authorizeSource(stakingCoreAddr);
    await tx8.wait(1);
    console.log("   ✅ TreasuryManager: Core authorized");

    // ══════════════════════════════════════════════════════════════════════════
    // PHASE 2 — MARKETPLACE (10 contracts)
    // ══════════════════════════════════════════════════════════════════════════
    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 2 · MARKETPLACE                                                     ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");

    // 2.1 LevelingSystem + ReferralSystem (UUPS, no deps on marketplace core yet)
    const LevelingF = await ethers.getContractFactory("LevelingSystem");
    const { contract: leveling, address: levelingAddr } =
        await deployUUPS(LevelingF, [deployer.address], "LevelingSystem");
    d.contracts.marketplace.leveling = levelingAddr;

    const ReferralF = await ethers.getContractFactory("ReferralSystem");
    const { contract: referral, address: referralAddr } =
        await deployUUPS(ReferralF, [deployer.address], "ReferralSystem");
    d.contracts.marketplace.referral = referralAddr;

    // 2.2 MarketplaceCore (UUPS proxy)
    const MktCoreF = await ethers.getContractFactory("MarketplaceCore");
    const { contract: mktCore, address: mktCoreAddr } =
        await deployUUPS(MktCoreF, [TREASURY_ADDRESS], "MarketplaceCore");
    d.contracts.marketplace.core = mktCoreAddr;

    // 2.3 Sub-modules that need marketplace core address
    const MktViewF = await ethers.getContractFactory("MarketplaceView");
    const { contract: mktView, address: mktViewAddr } =
        await deployPlain(MktViewF, [deployer.address, mktCoreAddr], "MarketplaceView");
    d.contracts.marketplace.view = mktViewAddr;

    const MktStatsF = await ethers.getContractFactory("MarketplaceStatistics");
    const { contract: mktStats, address: mktStatsAddr } =
        await deployPlain(MktStatsF, [deployer.address, mktCoreAddr], "MarketplaceStatistics");
    d.contracts.marketplace.statistics = mktStatsAddr;

    const MktSocialF = await ethers.getContractFactory("MarketplaceSocial");
    const { contract: mktSocial, address: mktSocialAddr } =
        await deployPlain(MktSocialF, [deployer.address, mktCoreAddr], "MarketplaceSocial");
    d.contracts.marketplace.social = mktSocialAddr;

    const NuxPowerNftF = await ethers.getContractFactory("NuxPowerNft");
    const { contract: nuxPowerNft, address: nuxPowerNftAddr } =
        await deployPlain(NuxPowerNftF, [mktCoreAddr], "NuxPowerNft");
    d.contracts.marketplace.nuxPowerNft = nuxPowerNftAddr;

    const NuxPowerMktF = await ethers.getContractFactory("NuxPowerMarketplace");
    const { contract: nuxPowerMkt, address: nuxPowerMktAddr } =
        await deployPlain(NuxPowerMktF, [mktCoreAddr, deployer.address], "NuxPowerMarketplace");
    d.contracts.marketplace.nuxPowerMarketplace = nuxPowerMktAddr;

    // 2.4 QuestCore (UUPS proxy, needs core address)
    const QuestCoreF = await ethers.getContractFactory("QuestCore");
    const { contract: questCore, address: questCoreAddr } =
        await deployUUPS(QuestCoreF, [deployer.address, mktCoreAddr], "QuestCore");
    d.contracts.marketplace.questCore = questCoreAddr;

    // 2.5 CollaboratorBadgeRewards (UUPS proxy)
    const CollabF = await ethers.getContractFactory("CollaboratorBadgeRewards");
    const { contract: collab, address: collabAddr } =
        await deployUUPS(CollabF, [deployer.address], "CollaboratorBadgeRewards");
    d.contracts.marketplace.collaboratorRewards = collabAddr;

    // ── Marketplace phase wiring ─────────────────────────────────────────────
    console.log("\n🔗 Wiring Marketplace modules...");

    const MARKETPLACE_ROLE = ethers.id("MARKETPLACE_ROLE");
    const ADMIN_ROLE        = await mktCore.ADMIN_ROLE();

    // Connect View / Statistics / Social to Core
    const mw1 = await mktCore.setViewModule(mktViewAddr);
    const mw2 = await mktCore.setStatisticsModule(mktStatsAddr);
    const mw3 = await mktCore.setSocialModule(mktSocialAddr);
    await Promise.all([mw1.wait(1), mw2.wait(1), mw3.wait(1)]);
    console.log("   ✅ Core → View / Statistics / Social");

    // Connect social module to view module (for comment queries)
    const mw4 = await mktView.setSocialModule(mktSocialAddr);
    const mw5 = await mktView.setStatisticsModule(mktStatsAddr);
    await Promise.all([mw4.wait(1), mw5.wait(1)]);
    console.log("   ✅ View → Social / Statistics");

    // Core → TreasuryManager
    const mw6 = await mktCore.setTreasuryManager(treasuryAddr);
    await mw6.wait(1);
    console.log("   ✅ Core → TreasuryManager");

    // Core → external systems
    const mw7 = await mktCore.setSkillsContract(nuxPowerNftAddr);
    const mw8 = await mktCore.setLevelingSystem(levelingAddr);
    const mw9 = await mktCore.setReferralSystem(referralAddr);
    const mw10 = await mktCore.setCollaboratorRewardsContract(collabAddr);
    await Promise.all([mw7.wait(1), mw8.wait(1), mw9.wait(1), mw10.wait(1)]);
    console.log("   ✅ Core → Skills / Leveling / Referral / CollaboratorRewards");

    // Grant MARKETPLACE_ROLE in Leveling + Referral to Core
    const mr1 = await leveling.grantRole(MARKETPLACE_ROLE, mktCoreAddr);
    const mr2 = await referral.grantRole(MARKETPLACE_ROLE, mktCoreAddr);
    await Promise.all([mr1.wait(1), mr2.wait(1)]);
    console.log("   ✅ Leveling / Referral: MARKETPLACE_ROLE → Core");

    // Grant ADMIN_ROLE to Quest + NuxPowerNft contracts (so they can call updateUserXP etc.)
    const mr3 = await mktCore.grantRole(ADMIN_ROLE, questCoreAddr);
    const mr4 = await mktCore.grantRole(ADMIN_ROLE, nuxPowerNftAddr);
    await Promise.all([mr3.wait(1), mr4.wait(1)]);
    console.log("   ✅ Core: ADMIN_ROLE → QuestCore / NuxPowerNft");

    // NuxPowerNft treasury
    const mr5 = await nuxPowerNft.setTreasuryAddress(TREASURY_ADDRESS);
    await mr5.wait(1);
    console.log("   ✅ NuxPowerNft → treasury");

    // QuestCore → Core
    const mr6 = await questCore.setCoreContract(mktCoreAddr);
    await mr6.wait(1);
    console.log("   ✅ QuestCore → Core");

    // TreasuryManager authorizes Marketplace Core
    const mr7 = await treasury.authorizeSource(mktCoreAddr);
    await mr7.wait(1);
    console.log("   ✅ TreasuryManager: MarketplaceCore authorized");

    // Link staking ↔ marketplace (so staking bonuses apply in MP context)
    const mr8 = await mktCore.setStakingContract(stakingCoreAddr);
    await mr8.wait(1);
    console.log("   ✅ Marketplace Core → StakingCore");

    // ══════════════════════════════════════════════════════════════════════════
    // SAVE & SUMMARY
    // ══════════════════════════════════════════════════════════════════════════
    saveDeployment(d);

    const finalBal = await ethers.provider.getBalance(deployer.address);
    const spent    = balance - finalBal;

    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  🎉 DEPLOYMENT COMPLETE                                                    ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");
    console.log(`\n   POL spent   : ${ethers.formatEther(spent)}`);
    console.log(`   Final bal   : ${ethers.formatEther(finalBal)}`);
    console.log("\n   Contract summary:");
    console.log(`     TreasuryManager          : ${d.contracts.treasury.manager}`);
    console.log(`     QuestRewardsPool         : ${d.contracts.treasury.questRewardsPool}`);
    console.log(`     SmartStakingCoreV2       : ${d.contracts.staking.core}`);
    console.log(`     SmartStakingRewards      : ${d.contracts.staking.rewards}`);
    console.log(`     SmartStakingPower        : ${d.contracts.staking.power}`);
    console.log(`     SmartStakingGamification : ${d.contracts.staking.gamification}`);
    console.log(`     DynamicAPYCalculator     : ${d.contracts.staking.dynamicAPY}`);
    console.log(`     SmartStakingViewCore     : ${d.contracts.staking.viewCore}`);
    console.log(`     SmartStakingViewStats    : ${d.contracts.staking.viewStats}`);
    console.log(`     SmartStakingViewSkills   : ${d.contracts.staking.viewSkills}`);
    console.log(`     SmartStakingViewDashboard: ${d.contracts.staking.viewDashboard}`);
    console.log(`     MarketplaceCore          : ${d.contracts.marketplace.core}`);
    console.log(`     LevelingSystem           : ${d.contracts.marketplace.leveling}`);
    console.log(`     ReferralSystem           : ${d.contracts.marketplace.referral}`);
    console.log(`     MarketplaceView          : ${d.contracts.marketplace.view}`);
    console.log(`     MarketplaceStatistics    : ${d.contracts.marketplace.statistics}`);
    console.log(`     MarketplaceSocial        : ${d.contracts.marketplace.social}`);
    console.log(`     NuxPowerNft              : ${d.contracts.marketplace.nuxPowerNft}`);
    console.log(`     NuxPowerMarketplace      : ${d.contracts.marketplace.nuxPowerMarketplace}`);
    console.log(`     QuestCore                : ${d.contracts.marketplace.questCore}`);
    console.log(`     CollaboratorBadgeRewards : ${d.contracts.marketplace.collaboratorRewards}`);
    console.log("\n   ✅ Run next steps:");
    console.log("      npx hardhat run scripts/fund.cjs --network polygon");
    console.log("      npx hardhat run scripts/verify.cjs --network polygon\n");
}

main()
    .then(() => process.exit(0))
    .catch((err) => { console.error(err); process.exit(1); });
