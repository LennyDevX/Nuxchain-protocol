const hre = require("hardhat");
const fs = require("fs");

/**
 * @title Configure Treasury Manager Authorization
 * @notice Authorizes all revenue-generating contracts as sources in TreasuryManager
 * @dev This fixes the commission fallback issue where funds go to treasury wallet instead of TreasuryManager
 * 
 * PROBLEM IDENTIFIED:
 * - StakingCore, Marketplace, IndividualSkills all call treasuryManager.receiveRevenue()
 * - But they are NOT authorized as sources (authorizedSources[address] = false)
 * - receiveRevenue() reverts with "Not authorized source"
 * - Contracts fallback to sending to old treasury wallet address
 * 
 * SOLUTION:
 * - Call setAuthorizedSource() for each revenue-generating contract
 * - Enable them to send revenue to TreasuryManager
 * - Future commissions will correctly accumulate in TreasuryManager
 * 
 * CONTRACTS TO AUTHORIZE:
 * 1. EnhancedSmartStakingCoreV2 (6% staking commission)
 * 2. GameifiedMarketplaceCoreV1 (6% marketplace fees on NFT sales)
 * 3. IndividualSkillsMarketplace (100% revenue from skill purchases)
 */

async function main() {
    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║                                                                                ║");
    console.log("║          TREASURY MANAGER - AUTHORIZATION CONFIGURATION                        ║");
    console.log("║         Fix Revenue Routing & Enable Admin Funding                            ║");
    console.log("║                                                                                ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await hre.ethers.getSigners();
    console.log("📍 Deployer Address:", deployer.address);
    
    const balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("💰 Balance:", hre.ethers.formatEther(balance), "POL\n");

    // ════════════════════════════════════════════════════════════════════════════════════════
    // LOAD CONTRACT ADDRESSES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    let addresses;
    const addressPath = "./deployments/polygon-addresses.json";
    
    try {
        addresses = JSON.parse(fs.readFileSync(addressPath, "utf8"));
        console.log("✅ Loaded deployment addresses from polygon-addresses.json\n");
    } catch (error) {
        console.error("❌ Failed to load addresses file:", error.message);
        process.exit(1);
    }

    const TREASURY_MANAGER = addresses.treasury.manager;
    const STAKING_CORE = addresses.staking.core;
    const MARKETPLACE_CORE = addresses.marketplace.proxy;
    const INDIVIDUAL_SKILLS = addresses.marketplace.individualSkills;

    console.log("📦 Contract Addresses:");
    console.log("   ├─ TreasuryManager:", TREASURY_MANAGER);
    console.log("   ├─ StakingCore:", STAKING_CORE);
    console.log("   ├─ Marketplace:", MARKETPLACE_CORE);
    console.log("   └─ IndividualSkills:", INDIVIDUAL_SKILLS);
    console.log();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // GET TREASURY MANAGER CONTRACT INSTANCE
    // ════════════════════════════════════════════════════════════════════════════════════════

    console.log("🔗 Connecting to TreasuryManager contract...");
    const treasuryManager = await hre.ethers.getContractAt("TreasuryManager", TREASURY_MANAGER);
    console.log("✅ Connected to TreasuryManager\n");

    // Check current owner
    const owner = await treasuryManager.owner();
    console.log("👤 TreasuryManager Owner:", owner);
    
    if (owner.toLowerCase() !== deployer.address.toLowerCase()) {
        console.error("❌ ERROR: You are not the owner of TreasuryManager");
        console.error("   Current owner:", owner);
        console.error("   Your address:", deployer.address);
        process.exit(1);
    }
    console.log("✅ Ownership verified\n");

    // ════════════════════════════════════════════════════════════════════════════════════════
    // GAS CONFIGURATION
    // ════════════════════════════════════════════════════════════════════════════════════════

    const feeData = await hre.ethers.provider.getFeeData();
    const maxFeePerGas = feeData.maxFeePerGas * 125n / 100n; // +25% buffer
    const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas * 125n / 100n;

    console.log("⛽ Gas Configuration:");
    console.log("   Base Fee:", hre.ethers.formatUnits(feeData.maxFeePerGas, "gwei"), "Gwei");
    console.log("   Max Fee (with 25% buffer):", hre.ethers.formatUnits(maxFeePerGas, "gwei"), "Gwei");
    console.log("   Priority Fee:", hre.ethers.formatUnits(maxPriorityFeePerGas, "gwei"), "Gwei");
    console.log();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // PHASE 1: CHECK CURRENT AUTHORIZATION STATUS
    // ════════════════════════════════════════════════════════════════════════════════════════

    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 1: CHECK CURRENT AUTHORIZATION STATUS                                  ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    const stakingAuthorized = await treasuryManager.authorizedSources(STAKING_CORE);
    const marketplaceAuthorized = await treasuryManager.authorizedSources(MARKETPLACE_CORE);
    const individualSkillsAuthorized = await treasuryManager.authorizedSources(INDIVIDUAL_SKILLS);

    console.log("📊 Current Authorization Status:");
    console.log("   ├─ StakingCore:", stakingAuthorized ? "✅ AUTHORIZED" : "❌ NOT AUTHORIZED");
    console.log("   ├─ Marketplace:", marketplaceAuthorized ? "✅ AUTHORIZED" : "❌ NOT AUTHORIZED");
    console.log("   └─ IndividualSkills:", individualSkillsAuthorized ? "✅ AUTHORIZED" : "❌ NOT AUTHORIZED");
    console.log();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // PHASE 2: AUTHORIZE REVENUE SOURCES
    // ════════════════════════════════════════════════════════════════════════════════════════

    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 2: AUTHORIZE REVENUE SOURCES                                            ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    let txCount = 0;
    let totalGasUsed = 0n;

    // Authorize StakingCore
    if (!stakingAuthorized) {
        console.log("📤 2.1 Authorizing StakingCore as revenue source...");
        const tx1 = await treasuryManager.setAuthorizedSource(STAKING_CORE, true, {
            maxFeePerGas,
            maxPriorityFeePerGas,
        });
        const receipt1 = await tx1.wait(1);
        totalGasUsed += receipt1.gasUsed * receipt1.gasPrice;
        txCount++;
        console.log("✅ StakingCore authorized (TX:", receipt1.hash, ")");
        console.log("   Gas used:", receipt1.gasUsed.toString(), "\n");
    } else {
        console.log("⏭️  StakingCore already authorized, skipping...\n");
    }

    // Authorize Marketplace
    if (!marketplaceAuthorized) {
        console.log("📤 2.2 Authorizing Marketplace as revenue source...");
        const tx2 = await treasuryManager.setAuthorizedSource(MARKETPLACE_CORE, true, {
            maxFeePerGas,
            maxPriorityFeePerGas,
        });
        const receipt2 = await tx2.wait(1);
        totalGasUsed += receipt2.gasUsed * receipt2.gasPrice;
        txCount++;
        console.log("✅ Marketplace authorized (TX:", receipt2.hash, ")");
        console.log("   Gas used:", receipt2.gasUsed.toString(), "\n");
    } else {
        console.log("⏭️  Marketplace already authorized, skipping...\n");
    }

    // Authorize IndividualSkills
    if (!individualSkillsAuthorized) {
        console.log("📤 2.3 Authorizing IndividualSkills as revenue source...");
        const tx3 = await treasuryManager.setAuthorizedSource(INDIVIDUAL_SKILLS, true, {
            maxFeePerGas,
            maxPriorityFeePerGas,
        });
        const receipt3 = await tx3.wait(1);
        totalGasUsed += receipt3.gasUsed * receipt3.gasPrice;
        txCount++;
        console.log("✅ IndividualSkills authorized (TX:", receipt3.hash, ")");
        console.log("   Gas used:", receipt3.gasUsed.toString(), "\n");
    } else {
        console.log("⏭️  IndividualSkills already authorized, skipping...\n");
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // PHASE 3: VERIFY CONFIGURATION
    // ════════════════════════════════════════════════════════════════════════════════════════

    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 3: VERIFY FINAL CONFIGURATION                                          ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    const stakingAuthFinal = await treasuryManager.authorizedSources(STAKING_CORE);
    const marketplaceAuthFinal = await treasuryManager.authorizedSources(MARKETPLACE_CORE);
    const individualSkillsAuthFinal = await treasuryManager.authorizedSources(INDIVIDUAL_SKILLS);

    console.log("✅ Final Authorization Status:");
    console.log("   ├─ StakingCore:", stakingAuthFinal ? "✅ AUTHORIZED" : "❌ FAILED");
    console.log("   ├─ Marketplace:", marketplaceAuthFinal ? "✅ AUTHORIZED" : "❌ FAILED");
    console.log("   └─ IndividualSkills:", individualSkillsAuthFinal ? "✅ AUTHORIZED" : "❌ FAILED");
    console.log();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // TREASURY MANAGER INFO
    // ════════════════════════════════════════════════════════════════════════════════════════

    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  TREASURY MANAGER STATUS                                                       ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    const treasuryBalance = await hre.ethers.provider.getBalance(TREASURY_MANAGER);
    const totalRevenue = await treasuryManager.totalRevenueReceived();
    const totalDistributed = await treasuryManager.totalDistributed();
    const firstDepositTime = await treasuryManager.firstDepositTime();

    console.log("💰 Treasury Manager Financial Status:");
    console.log("   ├─ Current Balance:", hre.ethers.formatEther(treasuryBalance), "POL");
    console.log("   ├─ Total Revenue Received:", hre.ethers.formatEther(totalRevenue), "POL");
    console.log("   ├─ Total Distributed:", hre.ethers.formatEther(totalDistributed), "POL");
    console.log("   └─ First Deposit Time:", firstDepositTime > 0 ? new Date(Number(firstDepositTime) * 1000).toISOString() : "Not initialized");
    console.log();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNDING INSTRUCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  ADMIN FUNDING AVAILABLE                                                       ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    console.log("✅ TreasuryManager has THREE methods to receive admin funding:");
    console.log();
    console.log("1️⃣  receive() - Direct ETH transfer:");
    console.log("   await deployer.sendTransaction({");
    console.log("     to: \"" + TREASURY_MANAGER + "\",");
    console.log("     value: ethers.parseEther(\"100\")");
    console.log("   });");
    console.log();
    console.log("2️⃣  depositToReserve() - Add to emergency reserve (owner only):");
    console.log("   await treasuryManager.depositToReserve({ value: ethers.parseEther(\"50\") });");
    console.log();
    console.log("3️⃣  receiveRevenue() - Record as revenue (authorized sources only):");
    console.log("   Already configured for Staking, Marketplace, IndividualSkills");
    console.log();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // SUMMARY
    // ════════════════════════════════════════════════════════════════════════════════════════

    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ TREASURY CONFIGURATION COMPLETE                                            ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    console.log("📊 Configuration Summary:");
    console.log("   ├─ Transactions executed:", txCount);
    console.log("   ├─ Total gas used:", hre.ethers.formatEther(totalGasUsed), "POL");
    console.log("   └─ Configuration status: ✅ COMPLETE");
    console.log();

    console.log("🔄 Revenue Flow (After Fix):");
    console.log("   1. User deposits in Staking → 6% commission → TreasuryManager ✅");
    console.log("   2. User buys NFT in Marketplace → 6% fee → TreasuryManager ✅");
    console.log("   3. User buys Individual Skill → 100% revenue → TreasuryManager ✅");
    console.log();

    console.log("⚠️  IMPORTANT - For Past Commissions:");
    console.log("   Commissions sent to fallback wallet (0xaD14c117B51735C072D42571e30bf2C729CD9593)");
    console.log("   need to be manually transferred to TreasuryManager if you control that wallet.");
    console.log();

    console.log("🚀 Next Steps:");
    console.log("   1. Test a new staking deposit to verify commission routes correctly");
    console.log("   2. Test NFT marketplace sale to verify fee routing");
    console.log("   3. Monitor TreasuryManager balance growth");
    console.log("   4. Fund treasury with admin deposits if needed (use receive() or depositToReserve())");
    console.log();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
