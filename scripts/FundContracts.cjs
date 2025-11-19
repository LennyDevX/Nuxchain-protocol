#!/usr/bin/env node

const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

/**
 * 💰 FUND REWARD CONTRACTS
 * 
 * This script funds the reward contracts with POL (Native Token) so they can pay out rewards.
 * 
 * Targets:
 * 1. LevelingSystem (Marketplace Level Up Rewards)
 * 2. EnhancedSmartStakingGamification (Staking Level Up Rewards)
 * 3. EnhancedSmartStakingRewards (Staking Yield/Quest Rewards)
 */

async function main() {
    console.log("\n");
    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  💰 FUND REWARD CONTRACTS                                                    ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    // 1. Load Deployment Data
    const deploymentsDir = path.join(__dirname, "..", "deployments");
    const deploymentFile = path.join(deploymentsDir, "complete-deployment.json");

    if (!fs.existsSync(deploymentFile)) {
        throw new Error(`❌ Deployment file not found at ${deploymentFile}. Please run deployment first.`);
    }

    const deploymentData = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    console.log(`📂 Loaded deployment data from: ${deploymentFile}`);
    console.log(`🌐 Network: ${deploymentData.deployment.network}`);
    console.log(`📅 Timestamp: ${deploymentData.deployment.timestamp}\n`);

    // 2. Get Deployer
    const [deployer] = await ethers.getSigners();
    const deployerBalance = await ethers.provider.getBalance(deployer.address);
    console.log(`📍 Deployer: ${deployer.address}`);
    console.log(`💰 Balance: ${ethers.formatEther(deployerBalance)} POL\n`);

    // 3. Define Targets and Amounts
    // Default: 1000 POL for each contract
    const DEFAULT_AMOUNT = ethers.parseEther("1000"); 
    
    const targets = [
        {
            name: "LevelingSystem (Marketplace)",
            address: deploymentData.marketplace.leveling?.address,
            amount: DEFAULT_AMOUNT,
            description: "Funds for Level Up Rewards (20 POL/level)"
        },
        {
            name: "EnhancedSmartStakingGamification (Staking)",
            address: deploymentData.staking.gamification?.address,
            amount: DEFAULT_AMOUNT,
            description: "Funds for Level Up Rewards (20 POL/level)"
        },
        {
            name: "EnhancedSmartStakingRewards (Staking Rewards)",
            address: deploymentData.staking.rewards?.address,
            amount: DEFAULT_AMOUNT,
            description: "Funds for Staking Yield & Quest Rewards"
        }
    ];

    // 4. Execute Funding
    console.log("🚀 Starting Funding Process...\n");

    for (const target of targets) {
        if (!target.address) {
            console.log(`⚠️  Skipping ${target.name}: Address not found in deployment data.`);
            continue;
        }

        console.log(`💸 Funding ${target.name}...`);
        console.log(`   Address: ${target.address}`);
        console.log(`   Amount: ${ethers.formatEther(target.amount)} POL`);
        console.log(`   Purpose: ${target.description}`);

        try {
            // Check contract balance before
            const balanceBefore = await ethers.provider.getBalance(target.address);
            console.log(`   Current Balance: ${ethers.formatEther(balanceBefore)} POL`);

            // Send Transaction
            const tx = await deployer.sendTransaction({
                to: target.address,
                value: target.amount
            });

            console.log(`   ⏳ Transaction sent: ${tx.hash}`);
            await tx.wait();

            // Check contract balance after
            const balanceAfter = await ethers.provider.getBalance(target.address);
            console.log(`   ✅ Funded! New Balance: ${ethers.formatEther(balanceAfter)} POL\n`);

        } catch (error) {
            console.error(`   ❌ Error funding ${target.name}: ${error.message}\n`);
        }
    }

    console.log("✅ Funding Process Complete!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
