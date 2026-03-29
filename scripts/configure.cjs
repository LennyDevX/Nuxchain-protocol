#!/usr/bin/env node
"use strict";

/**
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║  NUXCHAIN PROTOCOL — POST-DEPLOY CONFIGURATION                  ║
 * ║                                                                  ║
 * ║  Run AFTER deploy.cjs to configure:                             ║
 * ║    • TreasuryManager sub-treasury addresses & percentages       ║
 * ║    • CollaboratorBadgeRewards treasury pointer                  ║
 * ║    • NuxPowerMarketplace effect values                          ║
 * ║    • QuestRewardsPool → StakingCore link                        ║
 * ║                                                                  ║
 * ║  Usage:                                                          ║
 * ║    npx hardhat run scripts/configure.cjs --network polygon       ║
 * ╚══════════════════════════════════════════════════════════════════╝
 */

const { ethers } = require("hardhat");
const fs   = require("fs");
const path = require("path");
require("dotenv").config();

// ─── helpers ────────────────────────────────────────────────────────────────

function loadDeployment() {
    const file = path.join(__dirname, "..", "deployments", "complete-deployment.json");
    if (!fs.existsSync(file)) {
        throw new Error("❌ complete-deployment.json not found. Run deploy.cjs first.");
    }
    return JSON.parse(fs.readFileSync(file, "utf8"));
}

async function send(tx, label) {
    const r = await tx.wait(1);
    console.log(`   ✅ ${label} (gas: ${r.gasUsed})`);
}

// ─── ABIs (minimal) ─────────────────────────────────────────────────────────

const TREASURY_ABI = [
    "function setSubTreasury(uint8, address) external",
    "function setAllocation(uint8, uint256) external",
    "function authorizeSource(address) external",
    "function distributeRevenue() external",
];

const COLLAB_ABI = [
    "function setTreasuryManager(address) external",
];

const QUEST_REWARDS_ABI = [
    "function setStakingContract(address) external",
    "function setMarketplaceContract(address) external",
];

const STAKING_CORE_ABI = [
    "function setRewardsModule(address) external",
    "function setDynamicAPYCalculator(address) external",
];

// ─── main ───────────────────────────────────────────────────────────────────

async function main() {
    const [deployer] = await ethers.getSigners();
    const data = loadDeployment();

    const tm   = data.contracts.treasury;
    const st   = data.contracts.staking;
    const mp   = data.contracts.marketplace;

    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  ⚙️  NUXCHAIN PROTOCOL — POST-DEPLOY CONFIGURATION                         ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");
    console.log(`\n   Deployer : ${deployer.address}`);
    console.log(`   Loaded   : ${data.deployment.timestamp}\n`);

    const treasury = new ethers.Contract(tm.manager, TREASURY_ABI, deployer);

    // ──────────────────────────────────────────────────────────────────────────
    // 1. TreasuryManager — sub-treasury addresses + allocations
    // ──────────────────────────────────────────────────────────────────────────
    console.log("1️⃣  Configuring TreasuryManager sub-treasuries...");

    // Sub-treasury indices (must match TreasuryManager's enum order):
    //   0 = REWARDS       → SmartStakingRewards (yield / level-up rewards)
    //   1 = STAKING       → SmartStakingCore    (staking sustainability)
    //   2 = COLLABORATORS → CollaboratorBadgeRewards
    //   3 = DEVELOPMENT   → deployer EOA (dev & maintenance)
    //   4 = MARKETPLACE   → MarketplaceCore     (marketplace ops)

    const subTreasuries = [
        { idx: 0, address: st.rewards,                name: "REWARDS (StakingRewards)" },
        { idx: 1, address: st.core,                   name: "STAKING (StakingCore)"    },
        { idx: 2, address: mp.collaboratorRewards,    name: "COLLABORATORS"            },
        { idx: 3, address: deployer.address,          name: "DEVELOPMENT (deployer)"   },
        { idx: 4, address: mp.core,                   name: "MARKETPLACE (Core)"       },
    ];

    // Default allocation (basis points, must sum to 10000):
    //   30% rewards, 20% staking, 20% collaborators, 15% dev, 15% marketplace
    const allocations = [3000, 2000, 2000, 1500, 1500];

    for (const sub of subTreasuries) {
        await send(treasury.setSubTreasury(sub.idx, sub.address), `SubTreasury[${sub.idx}] = ${sub.name}`);
        await send(treasury.setAllocation(sub.idx, allocations[sub.idx]), `Allocation[${sub.idx}] = ${allocations[sub.idx] / 100}%`);
    }
    console.log("");

    // ──────────────────────────────────────────────────────────────────────────
    // 2. CollaboratorBadgeRewards — point at deployed TreasuryManager
    // ──────────────────────────────────────────────────────────────────────────
    console.log("2️⃣  Configuring CollaboratorBadgeRewards...");
    const collab = new ethers.Contract(mp.collaboratorRewards, COLLAB_ABI, deployer);
    await send(collab.setTreasuryManager(tm.manager), "CollaboratorBadgeRewards → TreasuryManager");
    console.log("");

    // ──────────────────────────────────────────────────────────────────────────
    // 3. QuestRewardsPool — link to Staking + Marketplace Core
    // ──────────────────────────────────────────────────────────────────────────
    console.log("3️⃣  Configuring QuestRewardsPool...");
    const qrp = new ethers.Contract(tm.questRewardsPool, QUEST_REWARDS_ABI, deployer);
    await send(qrp.setStakingContract(st.core),      "QuestRewardsPool → StakingCore");
    await send(qrp.setMarketplaceContract(mp.core),  "QuestRewardsPool → MarketplaceCore");
    console.log("");

    // ──────────────────────────────────────────────────────────────────────────
    // 4. SmartStakingCore — set DynamicAPYCalculator
    // ──────────────────────────────────────────────────────────────────────────
    console.log("4️⃣  Configuring SmartStakingCore extras...");
    const stakingCore = new ethers.Contract(st.core, STAKING_CORE_ABI, deployer);
    await send(stakingCore.setDynamicAPYCalculator(st.dynamicAPY), "StakingCore → DynamicAPYCalculator");
    console.log("");

    // ──────────────────────────────────────────────────────────────────────────
    // 5. TreasuryManager — authorize QuestRewardsPool as revenue source
    // ──────────────────────────────────────────────────────────────────────────
    console.log("5️⃣  Authorizing additional revenue sources in TreasuryManager...");
    await send(treasury.authorizeSource(tm.questRewardsPool),   "TreasuryManager: QuestRewardsPool authorized");
    await send(treasury.authorizeSource(mp.nuxPowerNft),        "TreasuryManager: NuxPowerNft authorized");
    await send(treasury.authorizeSource(mp.nuxPowerMarketplace),"TreasuryManager: NuxPowerMarketplace authorized");
    console.log("");

    console.log("╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ CONFIGURATION COMPLETE                                                  ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");
    console.log("\n   Next steps:");
    console.log("      npx hardhat run scripts/fund.cjs    --network polygon");
    console.log("      npx hardhat run scripts/verify.cjs  --network polygon\n");
}

main()
    .then(() => process.exit(0))
    .catch((err) => { console.error(err); process.exit(1); });
