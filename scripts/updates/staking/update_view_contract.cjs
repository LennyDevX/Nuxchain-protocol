const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 📺 ACTUALIZACIÓN DEL CONTRATO VIEW
 * 
 * Despliega un nuevo EnhancedSmartStakingView con:
 * - getHourlyROIRates() - Tasas ROI por hora
 * - getStakingRatesInfo() - Info estructurada de tasas
 * - getGlobalStats() - Estadísticas globales
 * - getUserRewardsProjection() - Proyección de rewards
 * - getUserLockupAnalysis() - Análisis de lockups
 * - calculatePotentialEarnings() - Calculadora de ganancias
 * - getStakingEfficiency() - Score de eficiencia
 * - getWithdrawalStatus() - Estado de retiro
 * - getDepositRewardRates() - Tasas por depósito
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  📺 ACTUALIZACIÓN: VIEW CONTRACT                              ║");
    console.log("║  Nuevas funciones view para frontend                         ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const startTime = Date.now();

    // ====================================================
    // CARGAR DIRECCIONES AUTOMÁTICAMENTE
    // ====================================================
    const deploymentsDir = path.join(__dirname, "..", "..", "..", "deployments");
    const addressesFile = path.join(deploymentsDir, "polygon-addresses.json");
    
    if (!fs.existsSync(addressesFile)) {
        console.error("❌ No se encontró polygon-addresses.json");
        process.exit(1);
    }

    const deploymentData = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    
    const CORE_ADDRESS = deploymentData.staking?.core;
    const OLD_VIEW = deploymentData.staking?.view;

    if (!CORE_ADDRESS) {
        console.error("❌ No se encontró staking.core en polygon-addresses.json");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance:", ethers.formatEther(initialBalance), "POL\n");
    
    console.log("📋 Direcciones cargadas automáticamente:");
    console.log(`   Core:       ${CORE_ADDRESS}`);
    console.log(`   View (old): ${OLD_VIEW || 'No desplegado'}\n`);

    // ====================================================
    // DESPLEGAR NUEVO VIEW
    // ====================================================
    console.log("📦 Desplegando nuevo View Contract...");
    console.log("   ✨ Nuevas funciones:");
    console.log("      • getHourlyROIRates()");
    console.log("      • getStakingRatesInfo()");
    console.log("      • getGlobalStats()");
    console.log("      • getUserRewardsProjection()");
    console.log("      • getUserLockupAnalysis()");
    console.log("      • calculatePotentialEarnings()");
    console.log("      • getStakingEfficiency()");
    console.log("      • getWithdrawalStatus()");
    console.log("      • getDepositRewardRates()\n");
    
    const ViewFactory = await ethers.getContractFactory("EnhancedSmartStakingView");
    console.log("   ⏳ Enviando transacción...");
    const newView = await ViewFactory.deploy(CORE_ADDRESS);
    await newView.waitForDeployment();
    const newViewAddress = await newView.getAddress();
    
    console.log("✅ Nuevo View:", newViewAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newViewAddress}\n`);

    // ====================================================
    // GUARDAR DIRECCIONES
    // ====================================================
    console.log("💾 Guardando direcciones...");
    
    deploymentData.staking.viewOld = OLD_VIEW;
    deploymentData.staking.view = newViewAddress;
    deploymentData.staking.viewUpdatedAt = new Date().toISOString();
    
    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ polygon-addresses.json actualizado\n");

    // ====================================================
    // RESUMEN
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasConsumed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ VIEW CONTRACT ACTUALIZADO                                 ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log(`   Anterior: ${OLD_VIEW || 'N/A'}`);
    console.log(`   Nuevo:    ${newViewAddress}`);
    console.log(`   Gas:      ${ethers.formatEther(gasConsumed)} POL`);
    console.log(`   Tiempo:   ${executionTime}s\n`);

    console.log("⚠️  IMPORTANTE:");
    console.log("   • El Core NO necesita saber de este cambio");
    console.log("   • Solo actualiza la dirección en tu Frontend\n");

    console.log("⚠️  VERIFICAR EN POLYGONSCAN:");
    console.log(`   npx hardhat verify --network polygon ${newViewAddress} ${CORE_ADDRESS}\n`);

    console.log("📱 ACTUALIZAR FRONTEND:");
    console.log(`   STAKING_VIEW_ADDRESS="${newViewAddress}"\n`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Error:", error.message);
        console.error(error);
        process.exit(1);
    });
