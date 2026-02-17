const hre = require("hardhat");
const fs = require("fs");

/**
 * @title Redirect Staking Commissions to Treasury Manager
 * @notice Authorizes Staking Core and updates its internal treasury references
 */

async function main() {
    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║                                                                                ║");
    console.log("║          REDICECT COMMISSIONS TO TREASURY MANAGER                              ║");
    console.log("║                                                                                ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await hre.ethers.getSigners();
    console.log("📍 Deployer Address:", deployer.address);

    // Load addresses
    const addressPath = "./deployments/polygon-addresses.json";
    const addresses = JSON.parse(fs.readFileSync(addressPath, "utf8"));

    const TREASURY_MANAGER = addresses.treasury.manager;
    const STAKING_CORE = addresses.staking.core;
    const MARKETPLACE_CORE = addresses.marketplace.proxy;
    const INDIVIDUAL_SKILLS = addresses.marketplace.individualSkills;

    console.log("📦 Target Addresses:");
    console.log("   ├─ TreasuryManager:", TREASURY_MANAGER);
    console.log("   ├─ StakingCore:", STAKING_CORE);
    console.log("   ├─ MarketplaceCore:", MARKETPLACE_CORE);
    console.log("   └─ IndividualSkills:", INDIVIDUAL_SKILLS);
    console.log();

    // 1. Authorize Sources in TreasuryManager
    console.log("🔗 Connecting to TreasuryManager...");
    const treasuryManager = await hre.ethers.getContractAt("TreasuryManager", TREASURY_MANAGER);

    console.log("📤 Authorizing StakingCore as source...");
    await (await treasuryManager.setAuthorizedSource(STAKING_CORE, true)).wait(1);

    console.log("📤 Authorizing MarketplaceCore as source...");
    await (await treasuryManager.setAuthorizedSource(MARKETPLACE_CORE, true)).wait(1);

    console.log("📤 Authorizing IndividualSkills as source...");
    await (await treasuryManager.setAuthorizedSource(INDIVIDUAL_SKILLS, true)).wait(1);

    console.log("✅ All sources authorized in TreasuryManager");

    // 2. Setup StakingCore
    console.log("\n🔗 Connecting to StakingCore...");
    const stakingCore = await hre.ethers.getContractAt("EnhancedSmartStakingCoreV2", STAKING_CORE);

    console.log("📤 Setting TreasuryManager in StakingCore...");
    await (await stakingCore.setTreasuryManager(TREASURY_MANAGER)).wait(1);

    console.log("📤 Setting fallback treasury in StakingCore...");
    await (await stakingCore.changeTreasuryAddress(TREASURY_MANAGER)).wait(1);
    console.log("✅ StakingCore configured");

    // 3. Setup MarketplaceCore
    console.log("\n🔗 Connecting to MarketplaceCore...");
    const marketplaceCore = await hre.ethers.getContractAt("GameifiedMarketplaceCoreV1", MARKETPLACE_CORE);

    console.log("📤 Setting TreasuryManager in MarketplaceCore...");
    await (await marketplaceCore.setTreasuryManager(TREASURY_MANAGER)).wait(1);
    console.log("✅ MarketplaceCore configured");

    // 4. Setup IndividualSkills
    console.log("\n🔗 Connecting to IndividualSkills...");
    const individualSkills = await hre.ethers.getContractAt("IndividualSkillsMarketplace", INDIVIDUAL_SKILLS);

    console.log("📤 Setting TreasuryManager in IndividualSkills...");
    await (await individualSkills.setTreasuryManager(TREASURY_MANAGER)).wait(1);
    console.log("✅ IndividualSkills configured");

    console.log("\n🧪 Verification:");
    const stakingAuth = await treasuryManager.authorizedSources(STAKING_CORE);
    const marketplaceAuth = await treasuryManager.authorizedSources(MARKETPLACE_CORE);
    const skillsAuth = await treasuryManager.authorizedSources(INDIVIDUAL_SKILLS);

    console.log("   ├─ Staking Authorized:", stakingAuth ? "YES" : "NO");
    console.log("   ├─ Marketplace Authorized:", marketplaceAuth ? "YES" : "NO");
    console.log("   ├─ Indiv. Skills Authorized:", skillsAuth ? "YES" : "NO");
    console.log("   ├─ Staking Manager:", await stakingCore.treasuryManager());
    console.log("   ├─ Marketplace Manager:", await marketplaceCore.treasuryManager());
    console.log("   └─ Indiv. Skills Manager:", await individualSkills.treasuryManager());

    console.log("\n🎉 COMMISSION REDIRECTION COMPLETE!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
