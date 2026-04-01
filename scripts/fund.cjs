#!/usr/bin/env node
"use strict";

/**
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║  NUXCHAIN PROTOCOL — FUND REWARD CONTRACTS                     ║
 * ║                                                                  ║
 * ║  Sends POL to the contracts that pay out rewards:               ║
 * ║    • LevelingSystem           (marketplace level-up rewards)    ║
 * ║    • SmartStakingGamification (staking level-up rewards)        ║
 * ║    • SmartStakingRewards      (staking yield & quest rewards)   ║
 * ║    • QuestRewardsPool         (quest prize pool)                ║
 * ║                                                                  ║
 * ║  Amounts are set via ENV vars or default to 1000 POL each.      ║
 * ║                                                                  ║
 * ║  Usage:                                                          ║
 * ║    npx hardhat run scripts/fund.cjs --network polygon            ║
 * ║                                                                  ║
 * ║  ENV overrides (optional, in POL):                               ║
 * ║    FUND_LEVELING=500                                             ║
 * ║    FUND_GAMIFICATION=500                                         ║
 * ║    FUND_STAKING_REWARDS=2000                                     ║
 * ║    FUND_QUEST_POOL=500                                           ║
 * ╚══════════════════════════════════════════════════════════════════╝
 */

const { ethers, network } = require("hardhat");
const fs   = require("fs");
const path = require("path");
require("dotenv").config({ override: true });

const POL = (n) => ethers.parseEther(String(n));
const fmt = (wei) => `${Number(ethers.formatEther(wei)).toFixed(4)} POL`;

function loadDeployment() {
    const file = path.join(__dirname, "..", "deployments", "complete-deployment.json");
    if (!fs.existsSync(file)) {
        throw new Error("❌ complete-deployment.json not found. Run deploy.cjs first.");
    }
    return JSON.parse(fs.readFileSync(file, "utf8"));
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const data = loadDeployment();
    const st   = data.contracts.staking;
    const mp   = data.contracts.marketplace;
    const tm   = data.contracts.treasury;

    const balance = await ethers.provider.getBalance(deployer.address);

    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  💰 FUND REWARD CONTRACTS                                                  ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");
    console.log(`\n   Deployer  : ${deployer.address}`);
    console.log(`   Balance   : ${fmt(balance)}`);
    console.log(`   Network   : ${network.name}\n`);

    const targets = [
        {
            name    : "LevelingSystem",
            address : mp.leveling,
            amount  : POL(process.env.FUND_LEVELING         ?? "1000"),
        },
        {
            name    : "SmartStakingGamification",
            address : st.gamification,
            amount  : POL(process.env.FUND_GAMIFICATION     ?? "1000"),
        },
        {
            name    : "SmartStakingRewards",
            address : st.rewards,
            amount  : POL(process.env.FUND_STAKING_REWARDS  ?? "1000"),
        },
        {
            name    : "QuestRewardsPool",
            address : tm.questRewardsPool,
            amount  : POL(process.env.FUND_QUEST_POOL       ?? "1000"),
        },
    ];

    const totalNeeded = targets.reduce((s, t) => s + t.amount, 0n);
    console.log(`   Total to send : ${fmt(totalNeeded)}`);
    if (balance < totalNeeded) {
        throw new Error(`❌ Insufficient balance. Need ${fmt(totalNeeded)}, have ${fmt(balance)}`);
    }

    for (const t of targets) {
        if (!t.address || t.address === ethers.ZeroAddress) {
            console.warn(`   ⚠️  Skipping ${t.name}: address not set`);
            continue;
        }
        process.stdout.write(`\n   📤 Funding ${t.name} (${fmt(t.amount)})...`);
        const tx = await deployer.sendTransaction({ to: t.address, value: t.amount });
        await tx.wait(1);
        const newBal = await ethers.provider.getBalance(t.address);
        console.log(` ✅ (contract balance: ${fmt(newBal)})`);
    }

    const finalBal = await ethers.provider.getBalance(deployer.address);
    console.log(`\n   Remaining balance : ${fmt(finalBal)}`);
    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ FUNDING COMPLETE                                                        ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝\n");
}

main()
    .then(() => process.exit(0))
    .catch((err) => { console.error(err); process.exit(1); });
