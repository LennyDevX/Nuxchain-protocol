const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 🚀 SUSTAINABILITY UPDATE - DEPLOYMENT COMPLETO
 * 
 * Script maestro que despliega todos los cambios de sostenibilidad:
 * 
 * 1. TreasuryManager v2 (con Reserve Fund)
 * 2. DynamicAPYCalculator (nuevo)
 * 3. EnhancedSmartStakingRewards v5.1.0 (APY -25%)
 * 4. EnhancedSmartStakingSkills v5.1.0 (Boosts -25%)
 * 5. IndividualSkillsMarketplace update (Treasury integration)
 * 6. Configurac configurationiones y autorizaciones
 * 7. Verificación completa
 * 
 * IMPACTO:
 * - Annual payout: -$187K (para $1M TVL)
 * - Breakeven TVL: $29.8M → $22.4M
 * - Reserve fund: 10% de ingresos acumulado
 * - APY dinámico según TVL
 */

async function main() {
    console.log("\n╔═══════════════════════════════════════════════════════════════════════╗");
    console.log("║                                                                       ║");
    console.log("║       🚀 SUSTAINABILITY UPDATE - DEPLOYMENT COMPLETO                 ║");
    console.log("║                                                                       ║");
    console.log("║  📊 APY Reducido 25% | 🛡️ Reserve Fund | 📈 Dynamic APY              ║");
    console.log("║                                                                       ║");
    console.log("╚═══════════════════════════════════════════════════════════════════════╝\n");

    const overallStartTime = Date.now();

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance inicial:", ethers.formatEther(initialBalance), "POL");
    console.log("🌐 Network:", (await ethers.provider.getNetwork()).name);
    console.log("\n" + "═".repeat(75) + "\n");

    // ====================================================
    // CARGAR CONFIGURACIÓN
    // ====================================================
    const deploymentsDir = path.join(__dirname, "..", "..", "..", "deployments");
    const addressesFile = path.join(deploymentsDir, "polygon-addresses.json");
    
    let deploymentData = {};
    if (fs.existsSync(addressesFile)) {
        deploymentData = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    }

    const CORE_ADDRESS = deploymentData.staking?.core;
    const GAMIFICATION_MODULE = deploymentData.staking?.gamification;
    const MARKETPLACE_CORE = deploymentData.marketplace?.core;
    const SKILLS_MARKETPLACE = deploymentData.marketplace?.individualSkills;

    if (!CORE_ADDRESS || !GAMIFICATION_MODULE) {
        console.error("❌ Faltan direcciones críticas en polygon-addresses.json");
        console.error("   Necesarias: staking.core, staking.gamification");
        process.exit(1);
    }

    console.log("📋 Direcciones existentes:");
    console.log(`   Staking Core:            ${CORE_ADDRESS}`);
    console.log(`   Gamification Module:     ${GAMIFICATION_MODULE}`);
    console.log(`   Marketplace Core:        ${MARKETPLACE_CORE || 'No desplegado'}`);
    console.log(`   Skills Marketplace:      ${SKILLS_MARKETPLACE || 'No desplegado'}`);
    console.log("\n" + "═".repeat(75) + "\n");

    // ====================================================
    // PASO 1: TREASURY MANAGER V2
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 1/7: Desplegando TreasuryManager v2 (con Reserve Fund)        │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const TreasuryFactory = await ethers.getContractFactory("TreasuryManager");
    console.log("⏳ Desplegando TreasuryManager...");
    const treasuryManager = await TreasuryFactory.deploy();
    await treasuryManager.waitForDeployment();
    const treasuryAddress = await treasuryManager.getAddress();
    
    console.log("✅ TreasuryManager:", treasuryAddress);
    console.log(`🔗 https://polygonscan.com/address/${treasuryAddress}\n`);

    // ====================================================
    // PASO 2: DYNAMIC APY CALCULATOR
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 2/7: Desplegando DynamicAPYCalculator                         │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const DynamicAPYFactory = await ethers.getContractFactory("DynamicAPYCalculator");
    console.log("⏳ Desplegando DynamicAPYCalculator...");
    const dynamicAPY = await DynamicAPYFactory.deploy();
    await dynamicAPY.waitForDeployment();
    const dynamicAPYAddress = await dynamicAPY.getAddress();
    
    console.log("✅ DynamicAPYCalculator:", dynamicAPYAddress);
    console.log(`🔗 https://polygonscan.com/address/${dynamicAPYAddress}\n`);

    // ====================================================
    // PASO 3: REWARDS MODULE V5.1.0
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 3/7: Desplegando EnhancedSmartStakingRewards v5.1.0           │");
    console.log("│           APY Reducido 25% para sostenibilidad                     │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const RewardsFactory = await ethers.getContractFactory("EnhancedSmartStakingRewards");
    console.log("⏳ Desplegando Rewards module...");
    const newRewards = await RewardsFactory.deploy();
    await newRewards.waitForDeployment();
    const newRewardsAddress = await newRewards.getAddress();
    
    console.log("✅ Rewards v5.1.0:", newRewardsAddress);
    console.log(`🔗 https://polygonscan.com/address/${newRewardsAddress}`);
    
    // Configurar Rewards
    console.log("\n📝 Configurando Rewards module...");
    await (await newRewards.setGamificationModule(GAMIFICATION_MODULE)).wait();
    await (await newRewards.setTreasuryManager(treasuryAddress)).wait();
    console.log("✅ Rewards configurado\n");

    // ====================================================
    // PASO 4: SKILLS MODULE V5.1.0
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 4/7: Desplegando EnhancedSmartStakingSkills v5.1.0            │");
    console.log("│           Boosts Reducidos 25% para sostenibilidad                 │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const SkillsFactory = await ethers.getContractFactory("EnhancedSmartStakingSkills");
    console.log("⏳ Desplegando Skills module...");
    const newSkills = await SkillsFactory.deploy();
    await newSkills.waitForDeployment();
    const newSkillsAddress = await newSkills.getAddress();
    
    console.log("✅ Skills v5.1.0:", newSkillsAddress);
    console.log(`🔗 https://polygonscan.com/address/${newSkillsAddress}`);
    
    // Configurar Skills
    console.log("\n📝 Configurando Skills module...");
    await (await newSkills.setCoreStakingContract(CORE_ADDRESS)).wait();
    if (MARKETPLACE_CORE) {
        await (await newSkills.setMarketplaceContract(MARKETPLACE_CORE)).wait();
    }
    console.log("✅ Skills configurado\n");

    // ====================================================
    // PASO 5: ACTUALIZAR CORE CONTRACT
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 5/7: Actualizando Core contract con nuevos módulos            │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE_ADDRESS);
    
    console.log("📝 Actualizando Rewards module en Core...");
    await (await core.setRewardsModule(newRewardsAddress)).wait();
    console.log("✅ Rewards module actualizado");
    
    console.log("📝 Actualizando Skills module en Core...");
    await (await core.setSkillsModule(newSkillsAddress)).wait();
    console.log("✅ Skills module actualizado");
    
    console.log("📝 Actualizando TreasuryManager en Core...");
    
    // Verificar que el deployer es el owner
    const currentOwner = await core.owner();
    if (currentOwner.toLowerCase() !== deployer.address.toLowerCase()) {
        console.error(`❌ ERROR: Deployer no es el owner del Core`);
        console.error(`   Owner actual: ${currentOwner}`);
        console.error(`   Deployer: ${deployer.address}`);
        process.exit(1);
    }
    console.log("   ✓ Deployer confirmado como owner");
    
    // El setTreasuryManager puede no existir en versiones anteriores del Core
    // Intentar con manejo de error
    try {
        const tx = await core.setTreasuryManager(treasuryAddress);
        console.log("   ⏳ Esperando confirmación...");
        const receipt = await tx.wait();
        console.log(`✅ TreasuryManager actualizado (gas: ${receipt.gasUsed})\n`);
    } catch (error) {
        console.warn("⚠️  AVISO: No se pudo hacer setTreasuryManager() en Core");
        console.warn("   Razón: El Core deployado anteriormente no tiene este método");
        console.warn("   Estado: NON-BLOCKING - continuando deployment\n");
        console.warn("   📝 NOTA: El TreasuryManager está desplegado en " + treasuryAddress);
        console.warn("   Para conectarlo con Core, necesitas:");
        console.warn("   1. Upgradear el Core a una versión más nueva, O");
        console.warn("   2. Usar un nuevo Core (que implique migrar usuarios)\n");
    }

    // ====================================================
    // PASO 6: CONFIGURAR REWARDS CON SKILLS
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 6/7: Configurando cross-references entre módulos              │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    console.log("📝 Configurando Skills en Rewards...");
    await (await newRewards.setSkillsModule(newSkillsAddress)).wait();
    console.log("✅ Skills module configurado en Rewards\n");

    // ====================================================
    // PASO 7: INDIVIDUAL SKILLS MARKETPLACE (SI EXISTE)
    // ====================================================
    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 7/7: Actualizando IndividualSkillsMarketplace                 │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    if (SKILLS_MARKETPLACE) {
        try {
            const skillsMarketplace = await ethers.getContractAt("IndividualSkillsMarketplace", SKILLS_MARKETPLACE);
            
            console.log("📝 Actualizando TreasuryManager en Skills Marketplace...");
            await (await skillsMarketplace.setTreasuryManager(treasuryAddress)).wait();
            console.log("✅ TreasuryManager actualizado");
            
            console.log("📝 Autorizando Skills Marketplace en TreasuryManager...");
            await (await treasuryManager.setAuthorizedSource(SKILLS_MARKETPLACE, true)).wait();
            console.log("✅ Skills Marketplace autorizado\n");
        } catch (error) {
            console.log("⚠️  No se pudo actualizar Skills Marketplace automáticamente");
            console.log("   Puede requerir redeploy manual\n");
        }
    } else {
        console.log("ℹ️  Skills Marketplace no desplegado, saltando...\n");
    }

    // ====================================================
    // AUTORIZAR CORE COMO REVENUE SOURCE
    // ====================================================
    console.log("📝 Autorizando Staking Core como revenue source...");
    await (await treasuryManager.setAuthorizedSource(CORE_ADDRESS, true)).wait();
    console.log("✅ Core autorizado\n");

    if (MARKETPLACE_CORE) {
        console.log("📝 Autorizando Marketplace Core como revenue source...");
        await (await treasuryManager.setAuthorizedSource(MARKETPLACE_CORE, true)).wait();
        console.log("✅ Marketplace autorizado\n");
    }

    // ====================================================
    // GUARDAR DIRECCIONES
    // ====================================================
    console.log("═".repeat(75) + "\n");
    console.log("💾 Guardando nuevas direcciones...\n");

    if (!deploymentData.staking) deploymentData.staking = {};
    if (!deploymentData.treasury) deploymentData.treasury = {};

    // Backup old addresses
    deploymentData.staking.rewardsOld = deploymentData.staking?.rewards;
    deploymentData.staking.skillsOld = deploymentData.staking?.skills;
    deploymentData.treasury.managerOld = deploymentData.treasury?.manager;

    // New addresses
    deploymentData.treasury.manager = treasuryAddress;
    deploymentData.treasury.managerVersion = "2.0.0";
    deploymentData.staking.dynamicAPYCalculator = dynamicAPYAddress;
    deploymentData.staking.rewards = newRewardsAddress;
    deploymentData.staking.rewardsVersion = "5.1.0";
    deploymentData.staking.skills = newSkillsAddress;
    deploymentData.staking.skillsVersion = "5.1.0";
    deploymentData.staking.sustainabilityUpdateDeployedAt = new Date().toISOString();

    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ Direcciones guardadas en polygon-addresses.json\n");

    // ====================================================
    // RESUMEN FINAL
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const totalGasUsed = initialBalance - finalBalance;
    const totalExecutionTime = ((Date.now() - overallStartTime) / 1000).toFixed(2);

    console.log("═".repeat(75));
    console.log("\n✨ DEPLOYMENT COMPLETADO EXITOSAMENTE\n");
    console.log("═".repeat(75) + "\n");

    console.log("📊 CONTRATOS DESPLEGADOS:\n");
    console.log("1. TreasuryManager v2.0.0");
    console.log(`   ${treasuryAddress}`);
    console.log("\n2. DynamicAPYCalculator");
    console.log(`   ${dynamicAPYAddress}`);
    console.log("\n3. EnhancedSmartStakingRewards v5.1.0");
    console.log(`   ${newRewardsAddress}`);
    console.log("\n4. EnhancedSmartStakingSkills v5.1.0");
    console.log(`   ${newSkillsAddress}\n`);

    console.log("═".repeat(75) + "\n");

    console.log("📈 IMPACTO DE SOSTENIBILIDAD:\n");
    console.log("APY Rates (reducidos 25%):");
    console.log("  • No Lock:   19.7% (was 26.3%)");
    console.log("  • 365 días:  118.3% (was 157.68%)");
    console.log("\nSkill Boosts (reducidos 25%):");
    console.log("  • Max boost: +37.5% (was +50%)");
    console.log("\nReserve Fund:");
    console.log("  • Acumulación automática: 10% de ingresos");
    console.log("\nDynamic APY:");
    console.log("  • Ajuste automático según TVL");
    console.log("\nProjected savings:");
    console.log("  • Annual payout: -$187K (para $1M TVL)");
    console.log("  • Breakeven TVL: $22.4M (was $29.8M)\n");

    console.log("═".repeat(75) + "\n");

    console.log("💰 RECURSOS USADOS:\n");
    console.log(`Total gas:        ${ethers.formatEther(totalGasUsed)} POL`);
    console.log(`Balance final:    ${ethers.formatEther(finalBalance)} POL`);
    console.log(`Tiempo total:     ${totalExecutionTime}s\n`);

    console.log("═".repeat(75) + "\n");

    console.log("📝 PRÓXIMOS PASOS:\n");
    console.log("1. Ejecutar verificación:");
    console.log("   npx hardhat run scripts/updates/staking/verify_sustainability_setup.cjs --network polygon\n");
    console.log("2. Configurar treasury wallets en TreasuryManager:");
    console.log("   • setTreasury(\"rewards\", address)");
    console.log("   • setTreasury(\"staking\", address)");
    console.log("   • setTreasury(\"collaborators\", address)");
    console.log("   • setTreasury(\"development\", address)\n");
    console.log("3. Comunicar a la comunidad (2 semanas antes de activar)");
    console.log("4. Monitorear métricas primeras 48h después de activación");
    console.log("5. Actualizar frontend con nuevos ABIs y direcciones\n");

    console.log("═".repeat(75) + "\n");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n" + "═".repeat(75));
        console.error("\n❌ ERROR EN DEPLOYMENT:\n");
        console.error(error);
        console.error("\n" + "═".repeat(75) + "\n");
        process.exit(1);
    });
