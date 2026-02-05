const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🔄 ACTUALIZACIÓN COMPLETA: CORE + VIEW - SMART STAKING      ║");
    console.log("║  ✨ Agregando tracking de recompensas reclamadas             ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const startTime = Date.now();

    // ====================================================
    // CARGAR DIRECCIONES
    // ====================================================
    const deploymentsDir = path.join(__dirname, "..", "..", "..", "deployments");
    const addressesFile = path.join(deploymentsDir, "polygon-addresses.json");
    
    if (!fs.existsSync(addressesFile)) {
        console.error("❌ No se encontró polygon-addresses.json");
        console.error("   Ubicación esperada:", addressesFile);
        process.exit(1);
    }

    const deploymentData = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    
    const OLD_CORE = deploymentData.staking?.core;
    const OLD_VIEW = deploymentData.staking?.view;
    const REWARDS_MODULE = deploymentData.staking?.rewards;
    const SKILLS_MODULE = deploymentData.staking?.skills;
    const GAMIFICATION_MODULE = deploymentData.staking?.gamification;

    if (!OLD_CORE || !REWARDS_MODULE || !SKILLS_MODULE || !GAMIFICATION_MODULE) {
        console.error("❌ Faltan direcciones en polygon-addresses.json");
        console.error("   Verifica que existan: staking.core, staking.rewards, staking.skills, staking.gamification");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance inicial:", ethers.formatEther(initialBalance), "POL");
    console.log("\n📋 Direcciones actuales:");
    console.log(`   Core:          ${OLD_CORE}`);
    console.log(`   View:          ${OLD_VIEW || 'No desplegado'}`);
    console.log(`   Rewards:       ${REWARDS_MODULE}`);
    console.log(`   Skills:        ${SKILLS_MODULE}`);
    console.log(`   Gamification:  ${GAMIFICATION_MODULE}\n`);

    // ====================================================
    // PASO 1: DESPLEGAR NUEVO CORE
    // ====================================================
    console.log("📦 PASO 1/6: Desplegando nuevo Core...");
    const treasury = process.env.TREASURY_ADDRESS || "0xad14c117b51735c072d42571e30bf2c729cd9593";
    console.log("   Treasury:", treasury);
    
    const CoreFactory = await ethers.getContractFactory("EnhancedSmartStaking");
    console.log("   ⏳ Enviando transacción...");
    const newCore = await CoreFactory.deploy(treasury);
    await newCore.waitForDeployment();
    const newCoreAddress = await newCore.getAddress();
    
    console.log("✅ Nuevo Core:", newCoreAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newCoreAddress}\n`);

    // ====================================================
    // PASO 2: CONFIGURAR MÓDULOS EN EL CORE
    // ====================================================
    console.log("🔗 PASO 2/6: Configurando módulos...");
    
    let tx = await newCore.setRewardsModule(REWARDS_MODULE);
    await tx.wait();
    console.log("   ✅ Rewards Module");

    tx = await newCore.setSkillsModule(SKILLS_MODULE);
    await tx.wait();
    console.log("   ✅ Skills Module");

    tx = await newCore.setGamificationModule(GAMIFICATION_MODULE);
    await tx.wait();
    console.log("   ✅ Gamification Module\n");

    // ====================================================
    // PASO 3: ACTUALIZAR MÓDULOS
    // ====================================================
    console.log("🔄 PASO 3/6: Actualizando referencias en módulos...");

    const skillsModule = await ethers.getContractAt("EnhancedSmartStakingSkills", SKILLS_MODULE);
    tx = await skillsModule.setCoreStakingContract(newCoreAddress);
    await tx.wait();
    console.log("   ✅ Skills → Nuevo Core");

    const gamificationModule = await ethers.getContractAt("EnhancedSmartStakingGamification", GAMIFICATION_MODULE);
    tx = await gamificationModule.setCoreStakingContract(newCoreAddress);
    await tx.wait();
    console.log("   ✅ Gamification → Nuevo Core\n");

    // ====================================================
    // PASO 4: AUTORIZAR MARKETPLACES
    // ====================================================
    console.log("🏪 PASO 4/6: Autorizando marketplaces...");
    
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
                console.log(`   ✅ ${mp.name}`);
            }
        }
        console.log();
    } else {
        console.log("   ℹ️  No hay marketplaces configurados\n");
    }

    // ====================================================
    // PASO 5: DESPLEGAR NUEVO VIEW
    // ====================================================
    console.log("📦 PASO 5/6: Desplegando nuevo View...");
    
    const ViewFactory = await ethers.getContractFactory("EnhancedSmartStakingView");
    console.log("   ⏳ Enviando transacción...");
    const newView = await ViewFactory.deploy(newCoreAddress);
    await newView.waitForDeployment();
    const newViewAddress = await newView.getAddress();
    
    console.log("✅ Nuevo View:", newViewAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newViewAddress}\n`);

    // ====================================================
    // PASO 6: GUARDAR DIRECCIONES
    // ====================================================
    console.log("💾 PASO 6/6: Guardando direcciones...");
    
    if (!deploymentData.staking) deploymentData.staking = {};
    
    deploymentData.staking.coreOld = OLD_CORE;
    deploymentData.staking.core = newCoreAddress;
    deploymentData.staking.viewOld = OLD_VIEW || null;
    deploymentData.staking.view = newViewAddress;
    deploymentData.staking.updatedAt = new Date().toISOString();
    
    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ Archivo actualizado\n");

    // ====================================================
    // CALCULAR GAS CONSUMIDO
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasConsumed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    // ====================================================
    // RESUMEN FINAL
    // ====================================================
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ ACTUALIZACIÓN COMPLETADA EXITOSAMENTE                    ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log("📊 RESUMEN DE CAMBIOS:");
    console.log("\n   CONTRATOS ANTIGUOS:");
    console.log(`   Core: ${OLD_CORE}`);
    console.log(`   View: ${OLD_VIEW || 'No existía'}`);
    
    console.log("\n   CONTRATOS NUEVOS:");
    console.log(`   Core: ${newCoreAddress}`);
    console.log(`   View: ${newViewAddress}`);
    
    console.log("\n   MÓDULOS (Sin cambios):");
    console.log(`   Rewards:       ${REWARDS_MODULE}`);
    console.log(`   Skills:        ${SKILLS_MODULE}`);
    console.log(`   Gamification:  ${GAMIFICATION_MODULE}`);

    console.log("\n⛽ COSTOS:");
    console.log(`   Gas consumido: ${ethers.formatEther(gasConsumed)} POL`);
    console.log(`   Balance final: ${ethers.formatEther(finalBalance)} POL`);
    console.log(`   Tiempo:        ${executionTime}s`);

    console.log("\n⚠️  PRÓXIMOS PASOS:");
    console.log("\n   1. ✅ Verificar contratos en PolygonScan:");
    console.log(`      npx hardhat verify --network polygon ${newCoreAddress} ${treasury}`);
    console.log(`      npx hardhat verify --network polygon ${newViewAddress} ${newCoreAddress}`);
    
    console.log("\n   2. 🔄 Actualizar el Frontend:");
    console.log("      En tu archivo de configuración (config.js o .env):");
    console.log(`      STAKING_CORE_ADDRESS="${newCoreAddress}"`);
    console.log(`      STAKING_VIEW_ADDRESS="${newViewAddress}"`);
    
    console.log("\n   3. ⚠️  PAUSAR el Core anterior:");
    console.log("      Para evitar que los usuarios sigan usándolo:");
    console.log(`      const oldCore = await ethers.getContractAt("EnhancedSmartStaking", "${OLD_CORE}");`);
    console.log(`      await oldCore.pause();`);
    
    console.log("\n   4. ✅ Probar las nuevas funciones:");
    console.log(`      const core = await ethers.getContractAt("EnhancedSmartStaking", "${newCoreAddress}");`);
    console.log(`      await core.getTotalClaimedRewards("0xUSER_ADDRESS");`);
    
    console.log("\n🔗 ENLACES ÚTILES:");
    console.log(`   Core Nuevo:  https://polygonscan.com/address/${newCoreAddress}`);
    console.log(`   View Nuevo:  https://polygonscan.com/address/${newViewAddress}\n`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Error:", error.message);
        console.error(error);
        process.exit(1);
    });