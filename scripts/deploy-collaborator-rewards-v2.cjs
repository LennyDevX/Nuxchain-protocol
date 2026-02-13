const { ethers, upgrades } = require("hardhat");
require("dotenv").config();

/**
 * @title Deploy CollaboratorBadgeRewards V2
 * @notice Deployment script with PHASE 1 & 2 improvements
 * @dev Production-ready with tiered commissions, BadgeManager integration, and solvency tracking
 */

async function main() {
    console.log("\n🚀 ========================================");
    console.log("📋 CollaboratorBadgeRewards V2 Deployment");
    console.log("========================================\n");

    const [deployer] = await ethers.getSigners();
    console.log("👤 Deploying with account:", deployer.address);
    console.log("💰 Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "POL\n");

    // ═══════════════════════════════════════════════════════════════════════════════
    // STEP 1: Deploy CollaboratorBadgeRewards Proxy
    // ═══════════════════════════════════════════════════════════════════════════════
    
    console.log("📦 Step 1: Deploying CollaboratorBadgeRewards...");
    const CollaboratorBadgeRewards = await ethers.getContractFactory("CollaboratorBadgeRewards");
    
    const proxy = await upgrades.deployProxy(
        CollaboratorBadgeRewards,
        [],
        {
            initializer: 'initialize',
            kind: 'uups'
        }
    );
    
    await proxy.deployed();
    console.log("✅ CollaboratorBadgeRewards deployed to:", proxy.address);
    
    // Get implementation address
    const implAddress = await upgrades.erc1967.getImplementationAddress(proxy.address);
    console.log("📍 Implementation address:", implAddress);
    console.log("");

    // ═══════════════════════════════════════════════════════════════════════════════
    // STEP 2: Post-Deployment Configuration
    // ═══════════════════════════════════════════════════════════════════════════════
    
    console.log("⚙️  Step 2: Post-Deployment Configuration...\n");

    // 2.1 Set Quest Wallet
    const QUEST_WALLET = process.env.QUEST_ADDRESS;
    if (!QUEST_WALLET) {
        console.log("⚠️  Warning: QUEST_ADDRESS not set in .env");
    } else {
        console.log("🔧 Setting Quest Wallet...");
        const tx1 = await proxy.setQuestWallet(QUEST_WALLET);
        await tx1.wait();
        console.log("✅ Quest Wallet set to:", QUEST_WALLET);
    }

    // 2.2 Set TreasuryManager (if deployed)
    const TREASURY_MANAGER = process.env.TREASURY_MANAGER_ADDRESS || process.env.TREASURY_ADDRESS;
    if (TREASURY_MANAGER && ethers.utils.isAddress(TREASURY_MANAGER)) {
        console.log("\n🔧 Setting TreasuryManager...");
        const tx2 = await proxy.setTreasuryManager(TREASURY_MANAGER);
        await tx2.wait();
        console.log("✅ TreasuryManager set to:", TREASURY_MANAGER);
    } else {
        console.log("\n⚠️  TreasuryManager not configured (set later with setTreasuryManager)");
    }

    // 2.3 Configure Security Limits
    console.log("\n🔧 Configuring Security Limits...");
    const maxRewardLimit = ethers.utils.parseEther("500");   // 500 POL max per quest
    const maxBalanceLimit = ethers.utils.parseEther("10000"); // 10,000 POL max contract balance
    
    const tx3 = await proxy.setLimits(maxRewardLimit, maxBalanceLimit);
    await tx3.wait();
    console.log("✅ Security Limits:");
    console.log("   - Max Reward per Quest: 500 POL");
    console.log("   - Max Contract Balance: 10,000 POL");

    // 2.4 Set Max Pending Rewards Per User
    console.log("\n🔧 Setting Max Pending Rewards Per User...");
    const maxPendingPerUser = ethers.utils.parseEther("1000"); // 1,000 POL max pending
    
    const tx4 = await proxy.setMaxPendingRewardsPerUser(maxPendingPerUser);
    await tx4.wait();
    console.log("✅ Max Pending Rewards Per User: 1,000 POL");

    // 2.5 Set Claim Fee (default is 2% from initialize, can adjust here)
    console.log("\n🔧 Configuring Claim Fee...");
    const claimFeePercent = 200; // 2% (200 basis points)
    
    const tx5 = await proxy.setClaimFeePercent(claimFeePercent);
    await tx5.wait();
    console.log("✅ Claim Fee: 2% (200 BPS)");

    // 2.6 Configure Commission Tiers
    console.log("\n🔧 Configuring Commission Tiers...");
    
    // Tier 1: 0-10 POL → 2.0% fee
    const tx6a = await proxy.setCommissionTier(0, 200);
    await tx6a.wait();
    console.log("✅ Tier 1: 0+ POL → 2.0% fee");

    // Tier 2: 10-50 POL → 1.5% fee
    const tx6b = await proxy.setCommissionTier(ethers.utils.parseEther("10"), 150);
    await tx6b.wait();
    console.log("✅ Tier 2: 10+ POL → 1.5% fee");

    // Tier 3: 50+ POL → 1.0% fee
    const tx6c = await proxy.setCommissionTier(ethers.utils.parseEther("50"), 100);
    await tx6c.wait();
    console.log("✅ Tier 3: 50+ POL → 1.0% fee");

    // Tier 4 (Optional): 100+ POL → 0.5% fee
    const tx6d = await proxy.setCommissionTier(ethers.utils.parseEther("100"), 50);
    await tx6d.wait();
    console.log("✅ Tier 4: 100+ POL → 0.5% fee");

    // ═══════════════════════════════════════════════════════════════════════════════
    // STEP 3: Verify Configuration
    // ═══════════════════════════════════════════════════════════════════════════════
    
    console.log("\n\n🔍 Step 3: Verifying Configuration...\n");

    // Get contract stats
    const stats = await proxy.getStats();
    console.log("📊 Contract Stats:");
    console.log("   - Balance:", ethers.utils.formatEther(stats.balance), "POL");
    console.log("   - Pending Debt:", ethers.utils.formatEther(stats.pendingDebt), "POL");
    console.log("   - Total Commission:", ethers.utils.formatEther(stats.commission), "POL");
    console.log("   - Total Holders:", stats.holders.toString());
    console.log("   - Total Quests:", stats.questCount.toString());

    // Get health metrics
    const health = await proxy.getContractHealth();
    console.log("\n💊 Contract Health:");
    console.log("   - Solvency Ratio:", (health.solvencyRatio / 100).toFixed(2), "%");
    console.log("   - Is Healthy:", health.isHealthy ? "✅ YES" : "⚠️ NO");
    console.log("   - Deficit:", ethers.utils.formatEther(health.deficit), "POL");

    // Get commission tiers
    const tiers = await proxy.getAllCommissionTiers();
    console.log("\n🎯 Commission Tiers:");
    for (let i = 0; i < tiers.thresholds.length; i++) {
        console.log(`   - ${ethers.utils.formatEther(tiers.thresholds[i])}+ POL → ${tiers.rates[i] / 100}%`);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // STEP 4: Save Deployment Info
    // ═══════════════════════════════════════════════════════════════════════════════
    
    const deploymentInfo = {
        network: (await ethers.provider.getNetwork()).name,
        chainId: (await ethers.provider.getNetwork()).chainId,
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        contracts: {
            CollaboratorBadgeRewards: {
                proxy: proxy.address,
                implementation: implAddress
            }
        },
        configuration: {
            questWallet: QUEST_WALLET || "NOT_SET",
            treasuryManager: TREASURY_MANAGER || "NOT_SET",
            maxRewardLimit: "500 POL",
            maxBalanceLimit: "10000 POL",
            maxPendingPerUser: "1000 POL",
            claimFeePercent: "2%",
            commissionTiers: [
                { threshold: "0 POL", fee: "2.0%" },
                { threshold: "10 POL", fee: "1.5%" },
                { threshold: "50 POL", fee: "1.0%" },
                { threshold: "100 POL", fee: "0.5%" }
            ]
        }
    };

    console.log("\n\n💾 Saving deployment info...");
    const fs = require("fs");
    const path = require("path");
    const deploymentsDir = path.join(__dirname, "../deployments");
    
    if (!fs.existsSync(deploymentsDir)) {
        fs.mkdirSync(deploymentsDir, { recursive: true });
    }
    
    const filename = `collaborator-badge-rewards-v2-${deploymentInfo.chainId}.json`;
    fs.writeFileSync(
        path.join(deploymentsDir, filename),
        JSON.stringify(deploymentInfo, null, 2)
    );
    
    console.log("✅ Deployment info saved to:", filename);

    // ═══════════════════════════════════════════════════════════════════════════════
    // STEP 5: Next Steps
    // ═══════════════════════════════════════════════════════════════════════════════
    
    console.log("\n\n🎯 ========================================");
    console.log("📋 Next Steps");
    console.log("========================================\n");

    console.log("1️⃣  Authorize in TreasuryManager:");
    console.log(`   await treasuryManager.setAuthorizedSource("${proxy.address}", true);\n`);

    console.log("2️⃣  Set BadgeManager (if available):");
    console.log(`   await collaboratorBadgeRewards.setBadgeManager("<BADGE_MANAGER_ADDRESS>");\n`);

    console.log("3️⃣  Create first quest:");
    console.log(`   await collaboratorBadgeRewards.createQuest(
       "Welcome Quest",
       ethers.utils.parseEther("10"),
       startTime,
       endTime,
       100
   );\n`);

    console.log("4️⃣  Fund contract with initial POL:");
    console.log(`   await deployer.sendTransaction({
       to: "${proxy.address}",
       value: ethers.utils.parseEther("1000")
   });\n`);

    console.log("5️⃣  Verify contract on Polygonscan:");
    console.log(`   npx hardhat verify --network polygon ${implAddress}\n`);

    console.log("✅ Deployment Complete!\n");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
