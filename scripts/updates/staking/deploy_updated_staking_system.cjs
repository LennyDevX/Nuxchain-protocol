const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 🚀 SCRIPT DE ACTUALIZACIÓN COMPLETA - SMART STAKING SYSTEM
 * 
 * Este script despliega:
 * - EnhancedSmartStakingCore (con tracking de rewards reclamadas)
 * - EnhancedSmartStakingRewards (con nuevos APY rates)
 * - EnhancedSmartStakingView (con funciones view adicionales)
 * 
 * Cambios implementados:
 * ✅ Core: totalRewardsClaimed mapping + getTotalClaimedRewards()
 * ✅ Rewards: Nuevos APY basados en ROI por hora
 *    - Flexible: 26.3% APY (0.003%/hora)
 *    - 30 días: 43.8% APY (0.005%/hora)
 *    - 90 días: 78.8% APY (0.009%/hora)
 *    - 180 días: 105.12% APY (0.012%/hora)
 *    - 365 días: 157.68% APY (0.018%/hora)
 * ✅ View: Nuevas funciones para frontend
 *    - getHourlyROIRates()
 *    - getStakingRatesInfo()
 *    - getGlobalStats()
 *    - getUserRewardsProjection()
 *    - getUserLockupAnalysis()
 *    - calculatePotentialEarnings()
 *    - getStakingEfficiency()
 *    - getWithdrawalStatus()
 *    - getDepositRewardRates()
 */

async function main() {
    console.log("\n╔═══════════════════════════════════════════════════════════════════════╗");
    console.log("║  🚀 ACTUALIZACIÓN COMPLETA: CORE + REWARDS + VIEW                    ║");
    console.log("║  📊 Nuevos APY rates + Tracking de rewards + Funciones View         ║");
    console.log("╚═══════════════════════════════════════════════════════════════════════╝\n");

    const startTime = Date.now();

    // ====================================================
    // CARGAR DIRECCIONES EXISTENTES
    // ====================================================
    const deploymentsDir = path.join(__dirname, "..", "..", "..", "deployments");
    const addressesFile = path.join(deploymentsDir, "polygon-addresses.json");
    
    if (!fs.existsSync(addressesFile)) {
        console.error("❌ No se encontró polygon-addresses.json");
        console.error("   Ubicación esperada:", addressesFile);
        process.exit(1);
    }

    const deploymentData = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    
    // Guardar direcciones antiguas
    const OLD_CORE = deploymentData.staking?.core;
    const OLD_VIEW = deploymentData.staking?.view;
    const OLD_REWARDS = deploymentData.staking?.rewards;
    const SKILLS_MODULE = deploymentData.staking?.skills;
    const GAMIFICATION_MODULE = deploymentData.staking?.gamification;

    if (!SKILLS_MODULE || !GAMIFICATION_MODULE) {
        console.error("❌ Faltan direcciones en polygon-addresses.json");
        console.error("   Verifica que existan: staking.skills, staking.gamification");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance inicial:", ethers.formatEther(initialBalance), "POL");
    console.log("\n📋 DIRECCIONES ACTUALES:");
    console.log(`   Core:          ${OLD_CORE || 'No desplegado'}`);
    console.log(`   Rewards:       ${OLD_REWARDS || 'No desplegado'}`);
    console.log(`   View:          ${OLD_VIEW || 'No desplegado'}`);
    console.log(`   Skills:        ${SKILLS_MODULE}`);
    console.log(`   Gamification:  ${GAMIFICATION_MODULE}\n`);

    // ====================================================
    // PASO 1: DESPLEGAR NUEVO REWARDS MODULE
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 1/7: Desplegando nuevo Rewards Module...");
    console.log("   📊 Nuevos APY rates:");
    console.log("      • Flexible: 26.3% APY (0.003%/hora)");
    console.log("      • 30 días:  43.8% APY (0.005%/hora)");
    console.log("      • 90 días:  78.8% APY (0.009%/hora)");
    console.log("      • 180 días: 105.12% APY (0.012%/hora)");
    console.log("      • 365 días: 157.68% APY (0.018%/hora)");
    
    const RewardsFactory = await ethers.getContractFactory("EnhancedSmartStakingRewards");
    console.log("   ⏳ Enviando transacción...");
    const newRewards = await RewardsFactory.deploy();
    await newRewards.waitForDeployment();
    const newRewardsAddress = await newRewards.getAddress();
    
    console.log("✅ Nuevo Rewards:", newRewardsAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newRewardsAddress}\n`);

    // ====================================================
    // PASO 2: CONFIGURAR REWARDS MODULE
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🔗 PASO 2/7: Configurando Rewards Module...");
    
    let tx = await newRewards.setSkillsModule(SKILLS_MODULE);
    await tx.wait();
    console.log("   ✅ Skills Module vinculado");

    tx = await newRewards.setGamificationModule(GAMIFICATION_MODULE);
    await tx.wait();
    console.log("   ✅ Gamification Module vinculado\n");

    // ====================================================
    // PASO 3: DESPLEGAR NUEVO CORE
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 3/7: Desplegando nuevo Core...");
    console.log("   ✨ Nueva funcionalidad: totalRewardsClaimed tracking");
    
    const treasury = process.env.TREASURY_ADDRESS || "0xad14c117b51735c072d42571e30bf2c729cd9593";
    console.log("   💼 Treasury:", treasury);
    
    const CoreFactory = await ethers.getContractFactory("EnhancedSmartStaking");
    console.log("   ⏳ Enviando transacción...");
    const newCore = await CoreFactory.deploy(treasury);
    await newCore.waitForDeployment();
    const newCoreAddress = await newCore.getAddress();
    
    console.log("✅ Nuevo Core:", newCoreAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newCoreAddress}\n`);

    // ====================================================
    // PASO 4: CONFIGURAR MÓDULOS EN EL CORE
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🔗 PASO 4/7: Configurando módulos en Core...");
    
    tx = await newCore.setRewardsModule(newRewardsAddress);
    await tx.wait();
    console.log("   ✅ Rewards Module (NUEVO)");

    tx = await newCore.setSkillsModule(SKILLS_MODULE);
    await tx.wait();
    console.log("   ✅ Skills Module");

    tx = await newCore.setGamificationModule(GAMIFICATION_MODULE);
    await tx.wait();
    console.log("   ✅ Gamification Module\n");

    // ====================================================
    // PASO 5: ACTUALIZAR REFERENCIAS EN MÓDULOS EXISTENTES
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🔄 PASO 5/7: Actualizando referencias en módulos...");

    const skillsModule = await ethers.getContractAt("EnhancedSmartStakingSkills", SKILLS_MODULE);
    tx = await skillsModule.setCoreStakingContract(newCoreAddress);
    await tx.wait();
    console.log("   ✅ Skills → Nuevo Core");

    const gamificationModule = await ethers.getContractAt("EnhancedSmartStakingGamification", GAMIFICATION_MODULE);
    tx = await gamificationModule.setCoreStakingContract(newCoreAddress);
    await tx.wait();
    console.log("   ✅ Gamification → Nuevo Core\n");

    // ====================================================
    // PASO 6: AUTORIZAR MARKETPLACES
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🏪 PASO 6/7: Autorizando marketplaces...");
    
    if (deploymentData.marketplace) {
        const marketplaces = [
            { name: "Marketplace Proxy", addr: deploymentData.marketplace.proxy },
            { name: "Skills NFT", addr: deploymentData.marketplace.skillsNFT },
            { name: "Individual Skills", addr: deploymentData.marketplace.individualSkills },
            { name: "Quests", addr: deploymentData.marketplace.quests }
        ];

        for (const mp of marketplaces) {
            if (mp.addr) {
                tx = await newCore.setMarketplaceAuthorization(mp.addr, true);
                await tx.wait();
                console.log(`   ✅ ${mp.name}: ${mp.addr.slice(0, 10)}...`);
            }
        }
        console.log();
    } else {
        console.log("   ℹ️  No hay marketplaces configurados\n");
    }

    // ====================================================
    // PASO 7: DESPLEGAR NUEVO VIEW
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 7/7: Desplegando nuevo View...");
    console.log("   ✨ Nuevas funciones view:");
    console.log("      • getHourlyROIRates()");
    console.log("      • getStakingRatesInfo()");
    console.log("      • getGlobalStats()");
    console.log("      • getUserRewardsProjection()");
    console.log("      • getUserLockupAnalysis()");
    console.log("      • calculatePotentialEarnings()");
    console.log("      • getStakingEfficiency()");
    console.log("      • getWithdrawalStatus()");
    console.log("      • getDepositRewardRates()");
    
    const ViewFactory = await ethers.getContractFactory("EnhancedSmartStakingView");
    console.log("   ⏳ Enviando transacción...");
    const newView = await ViewFactory.deploy(newCoreAddress);
    await newView.waitForDeployment();
    const newViewAddress = await newView.getAddress();
    
    console.log("✅ Nuevo View:", newViewAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newViewAddress}\n`);

    // ====================================================
    // GUARDAR DIRECCIONES
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("💾 Guardando direcciones...");
    
    // Backup de direcciones antiguas
    if (!deploymentData.staking) deploymentData.staking = {};
    if (!deploymentData.staking.history) deploymentData.staking.history = [];
    
    // Guardar historial
    deploymentData.staking.history.push({
        date: new Date().toISOString(),
        core: OLD_CORE,
        rewards: OLD_REWARDS,
        view: OLD_VIEW,
        reason: "Update: New APY rates + Rewards tracking + View functions"
    });
    
    // Actualizar direcciones actuales
    deploymentData.staking.coreOld = OLD_CORE;
    deploymentData.staking.core = newCoreAddress;
    deploymentData.staking.rewardsOld = OLD_REWARDS;
    deploymentData.staking.rewards = newRewardsAddress;
    deploymentData.staking.viewOld = OLD_VIEW;
    deploymentData.staking.view = newViewAddress;
    deploymentData.staking.updatedAt = new Date().toISOString();
    deploymentData.staking.updateVersion = "2.0.0";
    deploymentData.staking.updateNotes = "New APY rates (0.003%-0.018%/hour), totalRewardsClaimed tracking, new View functions";
    
    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ polygon-addresses.json actualizado\n");

    // ====================================================
    // CALCULAR GAS CONSUMIDO
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasConsumed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    // ====================================================
    // RESUMEN FINAL
    // ====================================================
    console.log("\n╔═══════════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ ACTUALIZACIÓN COMPLETADA EXITOSAMENTE                            ║");
    console.log("╚═══════════════════════════════════════════════════════════════════════╝\n");

    console.log("📊 RESUMEN DE CAMBIOS:\n");
    
    console.log("   ┌─────────────────────────────────────────────────────────────────┐");
    console.log("   │  CONTRATOS ANTIGUOS                                             │");
    console.log("   ├─────────────────────────────────────────────────────────────────┤");
    console.log(`   │  Core:    ${OLD_CORE || 'N/A'} │`);
    console.log(`   │  Rewards: ${OLD_REWARDS || 'N/A'} │`);
    console.log(`   │  View:    ${OLD_VIEW || 'N/A'} │`);
    console.log("   └─────────────────────────────────────────────────────────────────┘\n");
    
    console.log("   ┌─────────────────────────────────────────────────────────────────┐");
    console.log("   │  CONTRATOS NUEVOS                                               │");
    console.log("   ├─────────────────────────────────────────────────────────────────┤");
    console.log(`   │  Core:    ${newCoreAddress} │`);
    console.log(`   │  Rewards: ${newRewardsAddress} │`);
    console.log(`   │  View:    ${newViewAddress} │`);
    console.log("   └─────────────────────────────────────────────────────────────────┘\n");
    
    console.log("   ┌─────────────────────────────────────────────────────────────────┐");
    console.log("   │  MÓDULOS SIN CAMBIOS                                            │");
    console.log("   ├─────────────────────────────────────────────────────────────────┤");
    console.log(`   │  Skills:       ${SKILLS_MODULE} │`);
    console.log(`   │  Gamification: ${GAMIFICATION_MODULE} │`);
    console.log("   └─────────────────────────────────────────────────────────────────┘\n");

    console.log("⛽ COSTOS:");
    console.log(`   Gas consumido: ${ethers.formatEther(gasConsumed)} POL`);
    console.log(`   Balance final: ${ethers.formatEther(finalBalance)} POL`);
    console.log(`   Tiempo:        ${executionTime}s\n`);

    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("⚠️  PRÓXIMOS PASOS:\n");
    
    console.log("   1. ✅ VERIFICAR CONTRATOS en PolygonScan:\n");
    console.log(`      npx hardhat verify --network polygon ${newRewardsAddress}`);
    console.log(`      npx hardhat verify --network polygon ${newCoreAddress} ${treasury}`);
    console.log(`      npx hardhat verify --network polygon ${newViewAddress} ${newCoreAddress}\n`);
    
    console.log("   2. 🔄 ACTUALIZAR EL FRONTEND:\n");
    console.log("      En tu archivo de configuración (config.js o .env):\n");
    console.log(`      STAKING_CORE_ADDRESS="${newCoreAddress}"`);
    console.log(`      STAKING_REWARDS_ADDRESS="${newRewardsAddress}"`);
    console.log(`      STAKING_VIEW_ADDRESS="${newViewAddress}"\n`);
    
    console.log("   3. ⚠️  PAUSAR CORE ANTERIOR (opcional pero recomendado):\n");
    console.log(`      const oldCore = await ethers.getContractAt("EnhancedSmartStaking", "${OLD_CORE}");`);
    console.log(`      await oldCore.pause();\n`);
    
    console.log("   4. ✅ PROBAR NUEVAS FUNCIONES:\n");
    console.log(`      // Verificar APY rates`);
    console.log(`      const view = await ethers.getContractAt("EnhancedSmartStakingView", "${newViewAddress}");`);
    console.log(`      const rates = await view.getAPYRates();`);
    console.log(`      console.log(rates); // [263, 438, 788, 1051, 1577] en basis points\n`);
    console.log(`      // Verificar tracking de rewards`);
    console.log(`      const core = await ethers.getContractAt("EnhancedSmartStaking", "${newCoreAddress}");`);
    console.log(`      const claimed = await core.getTotalClaimedRewards("0xUSER_ADDRESS");\n`);

    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🔗 ENLACES ÚTILES:\n");
    console.log(`   Core:    https://polygonscan.com/address/${newCoreAddress}`);
    console.log(`   Rewards: https://polygonscan.com/address/${newRewardsAddress}`);
    console.log(`   View:    https://polygonscan.com/address/${newViewAddress}\n`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Error durante el despliegue:");
        console.error(error.message);
        console.error(error);
        process.exit(1);
    });
