const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 📊 ACTUALIZACIÓN DEL MÓDULO REWARDS V2
 * 
 * Mejoras implementadas:
 * ✅ Treasury Manager integration - 2% commission en quest rewards
 * ✅ APY rates optimizados
 *    - Flexible: 26.3% APY (0.003%/hora)
 *    - 30 días:  43.8% APY (0.005%/hora)
 *    - 90 días:  78.8% APY (0.009%/hora)
 *    - 180 días: 105.12% APY (0.012%/hora)
 *    - 365 días: 157.68% APY (0.018%/hora)
 * ✅ Quest commission routing to Treasury (2% automático)
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  📊 ACTUALIZACIÓN: REWARDS MODULE V2                           ║");
    console.log("║  ✨ Treasury Integration + Quest Commission                   ║");
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
    const OLD_REWARDS = deploymentData.staking?.rewards;
    const SKILLS_MODULE = deploymentData.staking?.skills;
    const GAMIFICATION_MODULE = deploymentData.staking?.gamification;
    const TREASURY_ADDRESS = deploymentData.treasury?.manager;

    if (!CORE_ADDRESS || !SKILLS_MODULE || !GAMIFICATION_MODULE) {
        console.error("❌ Faltan direcciones en polygon-addresses.json");
        console.error("   Verifica: staking.core, staking.skills, staking.gamification");
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
    
    console.log("📋 Direcciones cargadas automáticamente:");
    console.log(`   Core:          ${CORE_ADDRESS}`);
    console.log(`   Rewards (old): ${OLD_REWARDS || 'No desplegado'}`);
    console.log(`   Skills:        ${SKILLS_MODULE}`);
    console.log(`   Gamification:  ${GAMIFICATION_MODULE}`);
    console.log(`   Treasury:      ${TREASURY_ADDRESS}\n`);

    // ====================================================
    // PASO 1: DESPLEGAR NUEVO REWARDS
    // ====================================================
    console.log("📦 PASO 1/4: Desplegando nuevo Rewards Module...");
    console.log("   Cambios incluidos:");
    console.log("      • Treasury Manager integration");
    console.log("      • Quest reward commission (2%)");
    console.log("      • Optimized APY rates");
    console.log("      • Skill boost calculations\n");
    
    const RewardsFactory = await ethers.getContractFactory("EnhancedSmartStakingRewards");
    console.log("   ⏳ Enviando transacción...");
    const newRewards = await RewardsFactory.deploy();
    await newRewards.waitForDeployment();
    const newRewardsAddress = await newRewards.getAddress();
    
    console.log("✅ Nuevo Rewards desplegado en:", newRewardsAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newRewardsAddress}\n`);

    // ====================================================
    // PASO 2: CONFIGURAR DEPENDENCIAS
    // ====================================================
    console.log("🔗 PASO 2/4: Configurando dependencias...");
    
    let tx = await newRewards.setSkillsModule(SKILLS_MODULE);
    await tx.wait();
    console.log("   ✅ Skills Module vinculado");

    tx = await newRewards.setGamificationModule(GAMIFICATION_MODULE);
    await tx.wait();
    console.log("   ✅ Gamification Module vinculado");

    tx = await newRewards.setTreasuryManager(TREASURY_ADDRESS);
    await tx.wait();
    console.log("   ✅ Treasury Manager vinculado\n");

    // ====================================================
    // PASO 3: CONECTAR AL CORE
    // ====================================================
    console.log("🔗 PASO 3/4: Conectando al Core...");
    
    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE_ADDRESS);
    tx = await core.setRewardsModule(newRewardsAddress);
    await tx.wait();
    console.log("   ✅ Core → Nuevo Rewards Module\n");

    // ====================================================
    // PASO 4: AUTORIZAR EN TREASURY
    // ====================================================
    console.log("🔐 PASO 4/4: Configurando autorizaciones en Treasury...");
    
    const treasury = await ethers.getContractAt("TreasuryManager", TREASURY_ADDRESS);
    tx = await treasury.setAuthorizedRequester(newRewardsAddress, true);
    await tx.wait();
    console.log("   ✅ Rewards autorizado como requester en Treasury\n");

    // ====================================================
    // GUARDAR DIRECCIONES
    // ====================================================
    console.log("💾 Guardando direcciones...");
    
    deploymentData.staking.rewardsOld = OLD_REWARDS;
    deploymentData.staking.rewards = newRewardsAddress;
    deploymentData.staking.rewardsUpdatedAt = new Date().toISOString();
    
    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ polygon-addresses.json actualizado\n");

    // ====================================================
    // RESUMEN
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasConsumed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ REWARDS MODULE ACTUALIZADO V2                              ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log(`   Anterior: ${OLD_REWARDS || 'N/A'}`);
    console.log(`   Nuevo:    ${newRewardsAddress}`);
    console.log(`   Gas:      ${ethers.formatEther(gasConsumed)} POL`);
    console.log(`   Tiempo:   ${executionTime}s\n`);

    console.log("⚠️  PRÓXIMOS PASOS:");
    console.log("   1. Actualizar Skills Module: npx hardhat run scripts/updates/staking/update_skills_module.cjs --network polygon");
    console.log("   2. Verificar en Polygonscan:");
    console.log(`      npx hardhat verify --network polygon ${newRewardsAddress}\n`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Error:", error.message);
        console.error(error);
        process.exit(1);
    });
