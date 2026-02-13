const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 📊 DEPLOY: ENHANCED STAKING REWARDS V5.1.0
 * 
 * CAMBIOS CRÍTICOS - REDUCCIÓN 25% PARA SOSTENIBILIDAD:
 * ✅ APY rates reducidos 25%:
 *    - No Lock:   26.3% → 19.7% APY
 *    - 30 días:   43.8% → 32.8% APY
 *    - 90 días:   78.8% → 59.1% APY
 *    - 180 días:  105.12% → 78.8% APY
 *    - 365 días:  157.68% → 118.3% APY
 * 
 * Beneficios:
 * - Reduce annual payout ~$187K (para $1M TVL)
 * - Breakeven TVL: $29.8M → $22.4M
 * - Aún 30x más atractivo que Lido (4% APY)
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  📊 DEPLOY: REWARDS MODULE V5.1.0                              ║");
    console.log("║  🎯 APY Reducido 25% - Sostenibilidad Protocol                ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const startTime = Date.now();

    // ====================================================
    // CARGAR DIRECCIONES
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
    const TREASURY_MANAGER = deploymentData.treasury?.manager;

    if (!CORE_ADDRESS || !SKILLS_MODULE || !GAMIFICATION_MODULE) {
        console.error("❌ Faltan direcciones en polygon-addresses.json");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance:", ethers.formatEther(initialBalance), "POL\n");
    
    console.log("📋 Direcciones cargadas:");
    console.log(`   Core:             ${CORE_ADDRESS}`);
    console.log(`   Rewards (old):    ${OLD_REWARDS || 'No desplegado'}`);
    console.log(`   Skills:           ${SKILLS_MODULE}`);
    console.log(`   Gamification:     ${GAMIFICATION_MODULE}`);
    console.log(`   Treasury Manager: ${TREASURY_MANAGER || 'No configurado'}\n`);

    // ====================================================
    // PASO 1: DESPLEGAR NUEVO REWARDS V5.1.0
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 1/5: Desplegando Rewards Module v5.1.0...");
    console.log("   📊 Nuevos APY rates (reducidos 25%):");
    console.log("      • No Lock:   19.7% APY (was 26.3%)");
    console.log("      • 30 días:   32.8% APY (was 43.8%)");
    console.log("      • 90 días:   59.1% APY (was 78.8%)");
    console.log("      • 180 días:  78.8% APY (was 105.12%)");
    console.log("      • 365 días:  118.3% APY (was 157.68%)\n");
    
    const RewardsFactory = await ethers.getContractFactory("EnhancedSmartStakingRewards");
    console.log("   ⏳ Enviando transacción...");
    const newRewards = await RewardsFactory.deploy();
    await newRewards.waitForDeployment();
    const newRewardsAddress = await newRewards.getAddress();
    
    console.log("✅ Nuevo Rewards deployed:", newRewardsAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newRewardsAddress}\n`);

    // ====================================================
    // PASO 2: CONFIGURAR MÓDULOS DE REFERENCIA
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 2/5: Configurando módulos...\n");

    console.log("   Configurando Skills module...");
    let tx = await newRewards.setSkillsModule(SKILLS_MODULE);
    await tx.wait();
    console.log("   ✅ Skills module configurado\n");

    console.log("   Configurando Gamification module...");
    tx = await newRewards.setGamificationModule(GAMIFICATION_MODULE);
    await tx.wait();
    console.log("   ✅ Gamification module configurado\n");

    if (TREASURY_MANAGER) {
        console.log("   Configurando Treasury Manager...");
        tx = await newRewards.setTreasuryManager(TREASURY_MANAGER);
        await tx.wait();
        console.log("   ✅ Treasury Manager configurado\n");
    }

    // ====================================================
    // PASO 3: ACTUALIZAR CORE CONTRACT
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 3/5: Actualizando Core contract...\n");

    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE_ADDRESS);
    
    console.log("   Actualizando referencia a Rewards module...");
    tx = await core.setRewardsModule(newRewardsAddress);
    await tx.wait();
    console.log("   ✅ Core actualizado con nuevo Rewards module\n");

    // ====================================================
    // PASO 4: VERIFICAR CONFIGURACIÓN
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🔍 PASO 4/5: Verificando configuración...\n");

    const skillsConfigured = await newRewards.skillsModule();
    const gamificationConfigured = await newRewards.gamificationModule();
    const coreRewardsRef = await core.rewardsModule();

    console.log("📊 Estado del nuevo Rewards module:");
    console.log(`   Skills module:        ${skillsConfigured === SKILLS_MODULE ? '✅' : '❌'} ${skillsConfigured}`);
    console.log(`   Gamification module:  ${gamificationConfigured === GAMIFICATION_MODULE ? '✅' : '❌'} ${gamificationConfigured}`);
    console.log(`   Core apunta a nuevo:  ${coreRewardsRef === newRewardsAddress ? '✅' : '❌'} ${coreRewardsRef}\n`);

    // Verificar APY rates
    const apyRates = await newRewards.getLockupPeriodsConfig();
    console.log("📈 APY Rates configurados:");
    console.log(`   [0] No Lock:   ${apyRates[1][0]} bps (${Number(apyRates[1][0])/100}%)`);
    console.log(`   [1] 30 días:   ${apyRates[1][1]} bps (${Number(apyRates[1][1])/100}%)`);
    console.log(`   [2] 90 días:   ${apyRates[1][2]} bps (${Number(apyRates[1][2])/100}%)`);
    console.log(`   [3] 180 días:  ${apyRates[1][3]} bps (${Number(apyRates[1][3])/100}%)`);
    console.log(`   [4] 365 días:  ${apyRates[1][4]} bps (${Number(apyRates[1][4])/100}%)\n`);

    // ====================================================
    // PASO 5: GUARDAR DIRECCIÓN
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("💾 PASO 5/5: Guardando dirección...\n");

    deploymentData.staking.rewardsOld = OLD_REWARDS; // Backup
    deploymentData.staking.rewards = newRewardsAddress;
    deploymentData.staking.rewardsVersion = "5.1.0";
    deploymentData.staking.rewardsDeployedAt = new Date().toISOString();

    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ Dirección guardada en polygon-addresses.json\n");

    // ====================================================
    // RESUMEN FINAL
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasUsed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("✨ ACTUALIZACIÓN COMPLETADA\n");
    console.log("📊 Resumen:");
    console.log(`   Contrato:          EnhancedSmartStakingRewards v5.1.0`);
    console.log(`   Nueva dirección:   ${newRewardsAddress}`);
    console.log(`   Dirección antigua: ${OLD_REWARDS || 'N/A'}`);
    console.log(`   Gas usado:         ${ethers.formatEther(gasUsed)} POL`);
    console.log(`   Tiempo:            ${executionTime}s`);
    console.log("\n🎯 Impacto de sostenibilidad:");
    console.log(`   Annual payout reduction:  ~$187,000 (para $1M TVL)`);
    console.log(`   Breakeven TVL:            $29.8M → $22.4M`);
    console.log(`   Competitividad vs Lido:   Aún 30x mejor (118% vs 4%)`);
    console.log("\n📝 Próximos pasos:");
    console.log("   1. Deploy Skills module v5.1.0");
    console.log("   2. Monitorear métricas de usuario primeras 48h");
    console.log("   3. Comunicar cambios a la comunidad\n");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ ERROR:", error);
        process.exit(1);
    });
