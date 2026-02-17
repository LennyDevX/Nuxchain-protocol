const hre = require("hardhat");
const fs = require("fs");

/**
 * @title Verify View Contracts Configuration
 * @notice Checks if View contracts have correct staking core addresses configured
 * @dev Diagnoses why view functions are reverting
 */

async function main() {
    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║                                                                                ║");
    console.log("║              VIEW CONTRACTS CONFIGURATION VERIFICATION                         ║");
    console.log("║                                                                                ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await hre.ethers.getSigners();
    console.log("📍 Deployer:", deployer.address);
    console.log();

    // Load addresses
    let addresses;
    try {
        addresses = JSON.parse(fs.readFileSync("./deployments/polygon-addresses.json", "utf8"));
    } catch (error) {
        console.error("❌ Failed to load addresses:", error.message);
        process.exit(1);
    }

    const STAKING_CORE = addresses.staking.core;
    const VIEW_CORE = addresses.staking.viewCore;
    const VIEW_STATS = addresses.staking.viewStats;
    const VIEW_SKILLS = addresses.staking.viewSkills;

    console.log("📦 Contract Addresses:");
    console.log("   ├─ StakingCore:", STAKING_CORE);
    console.log("   ├─ ViewCore:", VIEW_CORE);
    console.log("   ├─ ViewStats:", VIEW_STATS);
    console.log("   └─ ViewSkills:", VIEW_SKILLS);
    console.log();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CHECK VIEW CONTRACTS CONFIGURATION
    // ════════════════════════════════════════════════════════════════════════════════════════

    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  CHECKING VIEW CONTRACTS STAKING CORE REFERENCES                               ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    try {
        // Check ViewCore
        console.log("🔍 Checking ViewCore...");
        const viewCore = await hre.ethers.getContractAt("EnhancedSmartStakingViewCore", VIEW_CORE);
        const viewCoreStakingAddress = await viewCore.stakingContract();
        const viewCoreOwner = await viewCore.owner();
        
        console.log("   ├─ Configured Staking Address:", viewCoreStakingAddress);
        console.log("   ├─ Expected Staking Address:", STAKING_CORE);
        console.log("   ├─ Match:", viewCoreStakingAddress.toLowerCase() === STAKING_CORE.toLowerCase() ? "✅" : "❌");
        console.log("   └─ Owner:", viewCoreOwner);
        console.log();

        // Check ViewStats
        console.log("🔍 Checking ViewStats...");
        const viewStats = await hre.ethers.getContractAt("EnhancedSmartStakingViewStats", VIEW_STATS);
        const viewStatsStakingAddress = await viewStats.stakingContract();
        const viewStatsOwner = await viewStats.owner();
        
        console.log("   ├─ Configured Staking Address:", viewStatsStakingAddress);
        console.log("   ├─ Expected Staking Address:", STAKING_CORE);
        console.log("   ├─ Match:", viewStatsStakingAddress.toLowerCase() === STAKING_CORE.toLowerCase() ? "✅" : "❌");
        console.log("   └─ Owner:", viewStatsOwner);
        console.log();

        // Check ViewSkills
        console.log("🔍 Checking ViewSkills...");
        const viewSkills = await hre.ethers.getContractAt("EnhancedSmartStakingViewSkills", VIEW_SKILLS);
        const viewSkillsStakingAddress = await viewSkills.stakingContract();
        const viewSkillsOwner = await viewSkills.owner();
        
        console.log("   ├─ Configured Staking Address:", viewSkillsStakingAddress);
        console.log("   ├─ Expected Staking Address:", STAKING_CORE);
        console.log("   ├─ Match:", viewSkillsStakingAddress.toLowerCase() === STAKING_CORE.toLowerCase() ? "✅" : "❌");
        console.log("   └─ Owner:", viewSkillsOwner);
        console.log();

        // ════════════════════════════════════════════════════════════════════════════════════════
        // TEST VIEW FUNCTIONS
        // ════════════════════════════════════════════════════════════════════════════════════════

        console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
        console.log("║  TESTING VIEW FUNCTIONS                                                        ║");
        console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

        // Test ViewCore functions
        console.log("🧪 Testing ViewCore.getContractBalance()...");
        try {
            const contractBalance = await viewCore.getContractBalance();
            console.log("   ✅ Success!");
            console.log("   └─ Contract Balance:", hre.ethers.formatEther(contractBalance[0]), "POL");
            console.log();
        } catch (error) {
            console.log("   ❌ FAILED:", error.message);
            console.log();
        }

        console.log("🧪 Testing ViewCore.getTotalDeposit() for deployer...");
        try {
            const totalDeposit = await viewCore.getTotalDeposit(deployer.address);
            console.log("   ✅ Success!");
            console.log("   └─ Total Deposit:", hre.ethers.formatEther(totalDeposit), "POL");
            console.log();
        } catch (error) {
            console.log("   ❌ FAILED:", error.message);
            console.log();
        }

        // Test ViewStats functions
        console.log("🧪 Testing ViewStats.getPoolHealthStatus()...");
        try {
            const healthStatus = await viewStats.getPoolHealthStatus();
            console.log("   ✅ Success!");
            console.log("   └─ Health Status:", healthStatus.toString());
            console.log();
        } catch (error) {
            console.log("   ❌ FAILED:", error.message);
            console.log();
        }

        // ════════════════════════════════════════════════════════════════════════════════════════
        // SUMMARY
        // ════════════════════════════════════════════════════════════════════════════════════════

        console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
        console.log("║  DIAGNOSIS SUMMARY                                                             ║");
        console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

        const viewCoreMatch = viewCoreStakingAddress.toLowerCase() === STAKING_CORE.toLowerCase();
        const viewStatsMatch = viewStatsStakingAddress.toLowerCase() === STAKING_CORE.toLowerCase();
        const viewSkillsMatch = viewSkillsStakingAddress.toLowerCase() === STAKING_CORE.toLowerCase();

        if (viewCoreMatch && viewStatsMatch && viewSkillsMatch) {
            console.log("✅ All View contracts have correct StakingCore addresses configured");
            console.log();
            console.log("If view functions are still reverting, the issue is likely:");
            console.log("   1. StakingCore doesn't have the expected public getter functions");
            console.log("   2. View contracts are delegating to wrong function signatures");
            console.log("   3. Gas limit issues on complex view calls");
            console.log();
        } else {
            console.log("❌ CONFIGURATION ISSUE FOUND:");
            console.log();
            if (!viewCoreMatch) {
                console.log("   ❌ ViewCore has incorrect StakingCore address");
                console.log("      Current:", viewCoreStakingAddress);
                console.log("      Expected:", STAKING_CORE);
            }
            if (!viewStatsMatch) {
                console.log("   ❌ ViewStats has incorrect StakingCore address");
                console.log("      Current:", viewStatsStakingAddress);
                console.log("      Expected:", STAKING_CORE);
            }
            if (!viewSkillsMatch) {
                console.log("   ❌ ViewSkills has incorrect StakingCore address");
                console.log("      Current:", viewSkillsStakingAddress);
                console.log("      Expected:", STAKING_CORE);
            }
            console.log();
            console.log("🔧 FIX: Run the following commands to update View contracts:");
            console.log();
            if (!viewCoreMatch) {
                console.log("await viewCore.setStakingContract(\"" + STAKING_CORE + "\");");
            }
            if (!viewStatsMatch) {
                console.log("await viewStats.setStakingContract(\"" + STAKING_CORE + "\");");
            }
            if (!viewSkillsMatch) {
                console.log("await viewSkills.setStakingContract(\"" + STAKING_CORE + "\");");
            }
            console.log();
        }

    } catch (error) {
        console.error("❌ Error during verification:", error);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
