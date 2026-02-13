const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 🚀 SUSTAINABILITY UPDATE - DEPLOYMENT OPTIMIZADO
 * 
 * Desplega SOLO los contratos nuevos y actualiza los existentes
 * sin necesidad de redeploy de Core o módulos viejos
 */

async function main() {
    console.log("\n╔═══════════════════════════════════════════════════════════════════════╗");
    console.log("║                                                                       ║");
    console.log("║       🚀 SUSTAINABILITY UPDATE - NUEVOS CONTRATOS SOLO                ║");
    console.log("║                                                                       ║");
    console.log("║  📊 APY -25% | 🛡️ Reserve Fund | 📈 Dynamic APY                      ║");
    console.log("║                                                                       ║");
    console.log("╚═══════════════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance inicial:", ethers.formatEther(initialBalance), "POL");
    console.log("🌐 Network:", (await ethers.provider.getNetwork()).name);
    console.log("\n" + "═".repeat(75) + "\n");

    // ====================================================
    // DIRECCIONES EXISTENTES (PRODUCCIÓN)
    // ====================================================
    const EXISTING_CONTRACTS = {
        core: "0xC67F0a0cB719e4f4358D980a5D966878Fd6f3946",
        rewardsOld: "0x6AEd79f8567a9AAE27401E61D240fCce531561f3",
        skillsOld: "0x8Ea7278c3000a0628D0BA2925308aE0973Be3140",
        gamification: "0x90216d0227EfbBae880EC2b8F03695cB82326598",
        individualSkillsMarketplace: "0xB23257758B385444dF5A78aC2F315bd653470df3"
    };

    console.log("📋 Contratos existentes en producción:");
    console.log(`   Core:                       ${EXISTING_CONTRACTS.core}`);
    console.log(`   Rewards (actual):           ${EXISTING_CONTRACTS.rewardsOld}`);
    console.log(`   Skills (actual):            ${EXISTING_CONTRACTS.skillsOld}`);
    console.log(`   Gamification:               ${EXISTING_CONTRACTS.gamification}`);
    console.log(`   Individual Skills:          ${EXISTING_CONTRACTS.individualSkillsMarketplace}`);
    console.log("\n" + "═".repeat(75) + "\n");

    // ====================================================
    // PASO 1: TREASURY MANAGER V2
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 1/4: Desplegando TreasuryManager v2 (con Reserve Fund)        │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const TreasuryFactory = await ethers.getContractFactory("TreasuryManager");
    console.log("⏳ Desplegando TreasuryManager...");
    const treasuryManager = await TreasuryFactory.deploy();
    await treasuryManager.waitForDeployment();
    const treasuryAddress = await treasuryManager.getAddress();
    
    console.log("✅ TreasuryManager v2:", treasuryAddress);
    console.log(`🔗 https://polygonscan.com/address/${treasuryAddress}\n`);

    // ====================================================
    // PASO 2: DYNAMIC APY CALCULATOR
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 2/4: Desplegando DynamicAPYCalculator                         │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const DynamicAPYFactory = await ethers.getContractFactory("DynamicAPYCalculator");
    console.log("⏳ Desplegando DynamicAPYCalculator...");
    const dynamicAPY = await DynamicAPYFactory.deploy();
    await dynamicAPY.waitForDeployment();
    const dynamicAPYAddress = await dynamicAPY.getAddress();
    
    console.log("✅ DynamicAPYCalculator:", dynamicAPYAddress);
    console.log(`🔗 https://polygonscan.com/address/${dynamicAPYAddress}\n`);

    // ====================================================
    // PASO 3: ENHANCED SMARTSTAKING REWARDS V5.1.0
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 3/4: Desplegando EnhancedSmartStakingRewards v5.1.0           │");
    console.log("│           APY Reducido 25% para sostenibilidad                     │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const RewardsFactory = await ethers.getContractFactory("EnhancedSmartStakingRewards");
    console.log("⏳ Desplegando Rewards v5.1.0...");
    const newRewards = await RewardsFactory.deploy();
    await newRewards.waitForDeployment();
    const newRewardsAddress = await newRewards.getAddress();
    
    console.log("✅ Rewards v5.1.0:", newRewardsAddress);
    console.log(`🔗 https://polygonscan.com/address/${newRewardsAddress}`);
    
    console.log("\n📝 Configurando Rewards v5.1.0...");
    await (await newRewards.setGamificationModule(EXISTING_CONTRACTS.gamification)).wait();
    await (await newRewards.setTreasuryManager(treasuryAddress)).wait();
    console.log("✅ Rewards configurado\n");

    // ====================================================
    // PASO 4: ENHANCED SMARTSTAKING SKILLS V5.1.0
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 4/4: Desplegando EnhancedSmartStakingSkills v5.1.0            │");
    console.log("│           Boosts Reducidos 25% para sostenibilidad                 │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const SkillsFactory = await ethers.getContractFactory("EnhancedSmartStakingSkills");
    console.log("⏳ Desplegando Skills v5.1.0...");
    const newSkills = await SkillsFactory.deploy();
    await newSkills.waitForDeployment();
    const newSkillsAddress = await newSkills.getAddress();
    
    console.log("✅ Skills v5.1.0:", newSkillsAddress);
    console.log(`🔗 https://polygonscan.com/address/${newSkillsAddress}`);
    
    console.log("\n📝 Configurando Skills v5.1.0...");
    await (await newSkills.setCoreStakingContract(EXISTING_CONTRACTS.core)).wait();
    console.log("✅ Skills configurado\n");

    // ====================================================
    // POST-DEPLOYMENT: ACTUALIZAR CORE
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ POST-DEPLOY: Actualizando Core contract                            │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const core = await ethers.getContractAt("EnhancedSmartStaking", EXISTING_CONTRACTS.core);
    
    console.log("📝 Reemplazando Rewards module en Core...");
    try {
        await (await core.setRewardsModule(newRewardsAddress)).wait();
        console.log("✅ Rewards module reemplazado\n");
    } catch (err) {
        console.warn("⚠️  No se pudo actualizar Rewards en Core (no-blocking)");
        console.warn(`   Razón: ${err.message}\n`);
    }

    console.log("📝 Reemplazando Skills module en Core...");
    try {
        await (await core.setSkillsModule(newSkillsAddress)).wait();
        console.log("✅ Skills module reemplazado\n");
    } catch (err) {
        console.warn("⚠️  No se pudo actualizar Skills en Core (no-blocking)");
        console.warn(`   Razón: ${err.message}\n`);
    }

    // ====================================================
    // POST-DEPLOYMENT: CONFIGURAR TREASURY MANAGER
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ POST-DEPLOY: Configurando TreasuryManager                          │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    console.log("📝 Autorizando revenue sources...");
    await (await treasuryManager.setAuthorizedSource(EXISTING_CONTRACTS.core, true)).wait();
    console.log("   ✅ Core autorizado");
    
    await (await treasuryManager.setAuthorizedSource(EXISTING_CONTRACTS.individualSkillsMarketplace, true)).wait();
    console.log("   ✅ Individual Skills Marketplace autorizado\n");

    // ====================================================
    // POST-DEPLOYMENT: ACTUALIZAR INDIVIDUAL SKILLS MARKETPLACE
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ POST-DEPLOY: Actualizando Individual Skills Marketplace            │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const skillsMarketplace = await ethers.getContractAt("IndividualSkillsMarketplace", EXISTING_CONTRACTS.individualSkillsMarketplace);
    
    console.log("📝 Actualizando TreasuryManager en marketplace...");
    try {
        // Verificar si tiene setTreasuryManager
        const tx = await skillsMarketplace.setTreasuryManager(treasuryAddress);
        await tx.wait();
        console.log("✅ TreasuryManager actualizado en marketplace\n");
    } catch (err) {
        console.warn("⚠️  No se pudo actualizar marketplace (no-blocking)");
        console.warn(`   Razón: ${err.message}\n`);
    }

    // ====================================================
    // GUARDAR CONFIGURACIÓN
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ Guardando configuración                                            │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const deploymentsDir = path.join(__dirname, "..", "..", "..", "deployments");
    const addressesFile = path.join(deploymentsDir, "polygon-addresses.json");
    
    let deploymentData = {};
    if (fs.existsSync(addressesFile)) {
        deploymentData = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    }

    // Actualizar con nuevas direcciones
    if (!deploymentData.staking) deploymentData.staking = {};
    deploymentData.staking.core = EXISTING_CONTRACTS.core;
    deploymentData.staking.rewards = newRewardsAddress;  // NUEVO
    deploymentData.staking.rewardsOld = EXISTING_CONTRACTS.rewardsOld;  // Guardar el viejo para referencia
    deploymentData.staking.skills = newSkillsAddress;  // NUEVO
    deploymentData.staking.skillsOld = EXISTING_CONTRACTS.skillsOld;  // Guardar el viejo para referencia
    deploymentData.staking.gamification = EXISTING_CONTRACTS.gamification;
    deploymentData.staking.dynamicAPYCalculator = dynamicAPYAddress;  // NUEVO

    if (!deploymentData.treasury) deploymentData.treasury = {};
    deploymentData.treasury.manager = treasuryAddress;  // NUEVO

    if (!deploymentData.marketplace) deploymentData.marketplace = {};
    deploymentData.marketplace.individualSkills = EXISTING_CONTRACTS.individualSkillsMarketplace;

    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ Configuración guardada en polygon-addresses.json\n");

    // ====================================================
    // RESUMEN FINAL
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasSpent = ethers.formatEther(initialBalance - finalBalance);

    console.log("═".repeat(75));
    console.log("\n╔═══════════════════════════════════════════════════════════════════════╗");
    console.log("║                    ✅ DEPLOYMENT COMPLETADO                         ║");
    console.log("╚═══════════════════════════════════════════════════════════════════════╝\n");

    console.log("📋 NUEVOS CONTRATOS DESPLEGADOS:\n");
    console.log("🆕 TreasuryManager v2");
    console.log(`   📍 ${treasuryAddress}`);
    console.log(`   🔗 https://polygonscan.com/address/${treasuryAddress}\n`);

    console.log("🆕 DynamicAPYCalculator");
    console.log(`   📍 ${dynamicAPYAddress}`);
    console.log(`   🔗 https://polygonscan.com/address/${dynamicAPYAddress}\n`);

    console.log("🆕 EnhancedSmartStakingRewards v5.1.0");
    console.log(`   📍 ${newRewardsAddress}`);
    console.log(`   🔗 https://polygonscan.com/address/${newRewardsAddress}`);
    console.log(`   APY rates: [19.7%, 32.8%, 59.1%, 78.8%, 118.3%]\n`);

    console.log("🆕 EnhancedSmartStakingSkills v5.1.0");
    console.log(`   📍 ${newSkillsAddress}`);
    console.log(`   🔗 https://polygonscan.com/address/${newSkillsAddress}`);
    console.log(`   Max Boost: 37.5% (reducido 25%)\n`);

    console.log("📋 CONTRATOS EXISTENTES (SIN CAMBIOS):\n");
    console.log(`Core:                  ${EXISTING_CONTRACTS.core}`);
    console.log(`Gamification:          ${EXISTING_CONTRACTS.gamification}`);
    console.log(`Individual Skills:     ${EXISTING_CONTRACTS.individualSkillsMarketplace}\n`);

    console.log("═".repeat(75));
    console.log("\n💾 Gas gastado:", gasSpent, "POL");
    console.log("💼 Balance final:", ethers.formatEther(finalBalance), "POL\n");

    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ 📝 PRÓXIMOS PASOS MANUALES REQUERIDOS                              │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    console.log("1️⃣  Verificar que Core tenga referencias a nuevos módulos:");
    console.log("   npx hardhat run scripts/updates/staking/verify_sustainability_setup.cjs --network polygon\n");

    console.log("2️⃣  Configurar treasury wallets en TreasuryManager:");
    console.log("   npx hardhat console --network polygon");
    console.log("   > const tm = await ethers.getContractAt('TreasuryManager', '" + treasuryAddress + "');");
    console.log("   > await tm.setTreasury('rewards', <REWARDS_WALLET>);");
    console.log("   > await tm.setTreasury('staking', <STAKING_WALLET>);");
    console.log("   > await tm.setTreasury('collaborators', <COLLAB_WALLET>);");
    console.log("   > await tm.setTreasury('development', <DEV_WALLET>);\n");

    console.log("3️⃣  Test: Verificar que nueva APY se calcula correctamente");
    console.log("4️⃣  Monitorear: Seguir las primeras transacciones en Etherscan");
    console.log("5️⃣  Comunicar: Anunciar a la comunidad los cambios APY/Boosts -25%\n");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ ERROR:", error);
        process.exit(1);
    });
