const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 🎮 ACTUALIZACIÓN: GAMIFICATION MODULE V2
 * 
 * Mejoras implementadas:
 * ✅ Treasury Manager integration - para financiar rewards de level-up
 * ✅ Auto-compound fix - calcula rewards correctamente
 * ✅ Badges automation - 8 tipos de badges auto-award
 * ✅ RewardDeferred event - tracking de rewards que se aplazan
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🎮 ACTUALIZACIÓN: GAMIFICATION MODULE V2                       ║");
    console.log("║  ✨ Treasury Integration + Auto-Compound + Badges              ║");
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
    const TREASURY_ADDRESS = deploymentData.treasury?.manager;
    const GAMIFICATION_OLD = deploymentData.staking?.gamification;

    if (!CORE_ADDRESS) {
        console.error("❌ Falta dirección de Core en polygon-addresses.json");
        process.exit(1);
    }

    if (!TREASURY_ADDRESS) {
        console.error("❌ Falta dirección de Treasury Manager en polygon-addresses.json");
        console.error("   Ejecuta primero: npx hardhat run scripts/updates/staking/deploy_treasury_manager.cjs --network polygon");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance:", ethers.formatEther(initialBalance), "POL\n");
    
    console.log("📋 Direcciones cargadas:");
    console.log(`   Core:       ${CORE_ADDRESS}`);
    console.log(`   Treasury:   ${TREASURY_ADDRESS}`);
    console.log(`   Gamification (old): ${GAMIFICATION_OLD}\n`);

    // ====================================================
    // PASO 1: DESPLEGAR NUEVO MÓDULO
    // ====================================================
    console.log("📦 PASO 1/4: Desplegando nuevo Gamification Module...");
    console.log("   Cambios incluidos:");
    console.log("      • Treasury Manager integration");
    console.log("      • Auto-compound rewards calculation fix");
    console.log("      • Automatic badge system (8 tipos)");
    console.log("      • RewardDeferred event tracking\n");
    
    const GamificationFactory = await ethers.getContractFactory("EnhancedSmartStakingGamification");
    console.log("   ⏳ Enviando transacción...");
    const newGamification = await GamificationFactory.deploy();
    await newGamification.waitForDeployment();
    const newGamificationAddress = await newGamification.getAddress();
    
    console.log("✅ Nuevo Gamification desplegado en:", newGamificationAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newGamificationAddress}\n`);

    // ====================================================
    // PASO 2: CONFIGURAR DEPENDENCIAS
    // ====================================================
    console.log("🔗 PASO 2/4: Configurando dependencias...");
    
    let tx = await newGamification.setCoreStakingContract(CORE_ADDRESS);
    await tx.wait();
    console.log("   ✅ Core Staking vinculado");

    tx = await newGamification.setMarketplaceContract(CORE_ADDRESS);
    await tx.wait();
    console.log("   ✅ Marketplace vinculado (apunta a Core)");

    tx = await newGamification.setTreasuryManager(TREASURY_ADDRESS);
    await tx.wait();
    console.log("   ✅ Treasury Manager vinculado\n");

    // ====================================================
    // PASO 3: CONECTAR AL CORE
    // ====================================================
    console.log("🔗 PASO 3/4: Conectando al Core...");
    
    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE_ADDRESS);
    tx = await core.setGamificationModule(newGamificationAddress);
    await tx.wait();
    console.log("   ✅ Core → Nuevo Gamification Module\n");

    // ====================================================
    // PASO 4: AUTORIZAR EN TREASURY
    // ====================================================
    console.log("🔐 PASO 4/4: Configurando autorizaciones en Treasury...");
    
    const treasury = await ethers.getContractAt("TreasuryManager", TREASURY_ADDRESS);
    tx = await treasury.setAuthorizedRequester(newGamificationAddress, true);
    await tx.wait();
    console.log("   ✅ Gamification autorizado como requester en Treasury\n");

    // ====================================================
    // GUARDAR DIRECCIONES
    // ====================================================
    console.log("💾 Guardando direcciones...");
    
    deploymentData.staking.gamificationOld = GAMIFICATION_OLD;
    deploymentData.staking.gamification = newGamificationAddress;
    deploymentData.staking.gamificationUpdatedAt = new Date().toISOString();
    
    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ polygon-addresses.json actualizado\n");

    // ====================================================
    // RESUMEN
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasConsumed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ GAMIFICATION MODULE ACTUALIZADO V2                         ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log(`   Anterior: ${GAMIFICATION_OLD || 'N/A'}`);
    console.log(`   Nuevo:    ${newGamificationAddress}`);
    console.log(`   Gas:      ${ethers.formatEther(gasConsumed)} POL`);
    console.log(`   Tiempo:   ${executionTime}s\n`);

    console.log("⚠️  PRÓXIMOS PASOS:");
    console.log("   1. Actualizar Rewards Module: npx hardhat run scripts/updates/staking/update_rewards_module.cjs --network polygon");
    console.log("   2. Actualizar Skills Module: npx hardhat run scripts/updates/staking/update_skills_module.cjs --network polygon");
    console.log("   3. Verificar en Polygonscan:");
    console.log(`      npx hardhat verify --network polygon ${newGamificationAddress}\n`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Error:", error.message);
        console.error(error);
        process.exit(1);
    });
