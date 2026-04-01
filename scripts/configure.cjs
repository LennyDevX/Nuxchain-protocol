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
require("dotenv").config({ override: true });

// ─── helpers ────────────────────────────────────────────────────────────────

function loadDeployment() {
    const file = path.join(__dirname, "..", "deployments", "complete-deployment.json");
    if (!fs.existsSync(file)) {
        throw new Error("❌ complete-deployment.json not found. Run deploy.cjs first.");
    }
    return JSON.parse(fs.readFileSync(file, "utf8"));
}

async function send(txPromise, label) {
    const tx = await txPromise;
    const r = await tx.wait(1);
    console.log(`   ✅ ${label} (gas: ${r.gasUsed})`);
}

// ─── ABIs (minimal) ─────────────────────────────────────────────────────────

const TREASURY_ABI = [
    "function setTreasury(uint8, address) external",
    "function setAllocation(uint8, uint256) external",
    "function authorizeSource(address) external",
    "function authorizeRequester(address) external",
];

const COLLAB_ABI = [
    "function setTreasuryManager(address) external",
    "function setQuestRewardsPool(address) external",
];

const QUEST_REWARDS_ABI = [
    "function setTreasuryManager(address) external",
    "function grantRole(bytes32,address) external",
];

const STAKING_REWARDS_ABI = [
    "function setQuestRewardsPool(address) external",
    "function setTreasuryManager(address) external",
    "function setAPYCalculator(address) external",
];

const QUEST_CORE_ABI = [
    "function setLevelingContract(address) external",
    "function setQuestRewardsPool(address) external",
    "function grantRole(bytes32,address) external",
];

const NUXPOWER_MARKETPLACE_ABI = [
    "function setTreasuryManager(address) external",
    "function setStakingContract(address) external",
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

    const moduleRole = ethers.id("MODULE_ROLE");
    const reporterRole = ethers.id("REPORTER_ROLE");

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
        await send(treasury.setTreasury(sub.idx, sub.address), `SubTreasury[${sub.idx}] = ${sub.name}`);
        await send(treasury.setAllocation(sub.idx, allocations[sub.idx]), `Allocation[${sub.idx}] = ${allocations[sub.idx] / 100}%`);
    }
    console.log("");

    // ──────────────────────────────────────────────────────────────────────────
    // 2. CollaboratorBadgeRewards — point at deployed TreasuryManager
    // ──────────────────────────────────────────────────────────────────────────
    console.log("2️⃣  Configuring CollaboratorBadgeRewards...");
    const collab = new ethers.Contract(mp.collaboratorRewards, COLLAB_ABI, deployer);
    await send(collab.setTreasuryManager(tm.manager), "CollaboratorBadgeRewards → TreasuryManager");
    await send(collab.setQuestRewardsPool(tm.questRewardsPool), "CollaboratorBadgeRewards → QuestRewardsPool");
    console.log("");

    // ──────────────────────────────────────────────────────────────────────────
    // 3. QuestRewardsPool — set treasury + authorize payout modules
    // ──────────────────────────────────────────────────────────────────────────
    console.log("3️⃣  Configuring QuestRewardsPool...");
    const qrp = new ethers.Contract(tm.questRewardsPool, QUEST_REWARDS_ABI, deployer);
    await send(qrp.setTreasuryManager(tm.manager), "QuestRewardsPool → TreasuryManager");
    await send(qrp.grantRole(moduleRole, st.rewards), "QuestRewardsPool: MODULE_ROLE → SmartStakingRewards");
    await send(qrp.grantRole(moduleRole, mp.questCore), "QuestRewardsPool: MODULE_ROLE → QuestCore");
    await send(qrp.grantRole(moduleRole, mp.collaboratorRewards), "QuestRewardsPool: MODULE_ROLE → CollaboratorBadgeRewards");
    console.log("");

    // ──────────────────────────────────────────────────────────────────────────
    // 4. SmartStakingRewards + QuestCore + NuxPowerMarketplace extras
    // ──────────────────────────────────────────────────────────────────────────
    console.log("4️⃣  Configuring protocol modules...");
    const stakingRewards = new ethers.Contract(st.rewards, STAKING_REWARDS_ABI, deployer);
    const questCore = new ethers.Contract(mp.questCore, QUEST_CORE_ABI, deployer);
    const nuxPowerMarketplace = new ethers.Contract(mp.nuxPowerMarketplace, NUXPOWER_MARKETPLACE_ABI, deployer);

    await send(stakingRewards.setQuestRewardsPool(tm.questRewardsPool), "SmartStakingRewards → QuestRewardsPool");
    await send(stakingRewards.setTreasuryManager(tm.manager), "SmartStakingRewards → TreasuryManager");
    await send(stakingRewards.setAPYCalculator(st.dynamicAPY), "SmartStakingRewards → DynamicAPYCalculator");
    await send(questCore.setLevelingContract(mp.leveling), "QuestCore → LevelingSystem");
    await send(questCore.setQuestRewardsPool(tm.questRewardsPool), "QuestCore → QuestRewardsPool");
    await send(questCore.grantRole(reporterRole, st.core), "QuestCore: REPORTER_ROLE → SmartStakingCore");
    await send(questCore.grantRole(reporterRole, mp.social), "QuestCore: REPORTER_ROLE → MarketplaceSocial");
    await send(nuxPowerMarketplace.setTreasuryManager(tm.manager), "NuxPowerMarketplace → TreasuryManager");
    await send(nuxPowerMarketplace.setStakingContract(st.core), "NuxPowerMarketplace → StakingCore");
    console.log("");

    // ──────────────────────────────────────────────────────────────────────────
    // 5. TreasuryManager — authorize revenue sources and emergency requesters
    // ──────────────────────────────────────────────────────────────────────────
    console.log("5️⃣  Authorizing TreasuryManager integrations...");
    await send(treasury.authorizeSource(tm.questRewardsPool),   "TreasuryManager: QuestRewardsPool authorized");
    await send(treasury.authorizeSource(mp.nuxPowerNft),        "TreasuryManager: NuxPowerNft authorized");
    await send(treasury.authorizeSource(mp.nuxPowerMarketplace),"TreasuryManager: NuxPowerMarketplace authorized");
    await send(treasury.authorizeRequester(tm.questRewardsPool), "TreasuryManager: QuestRewardsPool requester authorized");
    await send(treasury.authorizeRequester(st.rewards),          "TreasuryManager: SmartStakingRewards requester authorized");
    await send(treasury.authorizeRequester(mp.collaboratorRewards), "TreasuryManager: CollaboratorBadgeRewards requester authorized");
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
