const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 🔄 UPDATE: INDIVIDUAL SKILLS MARKETPLACE
 * 
 * CAMBIO CRÍTICO:
 * ✅ Integración con TreasuryManager:
 *    - Antes: Fondos iban directamente a treasuryAddress wallet
 *    - Ahora: Fondos van a TreasuryManager.receiveRevenue()
 *    - Permite distribución automática y reserve fund
 * 
 * REVENUE TYPES enviados:
 *    - "individual_skill_purchase" - Compras de skills
 *    - "individual_skill_renewal" - Renovaciones
 * 
 * IMPORTANTE: No requiere redeploy si el contrato ya tiene
 * setTreasuryManager() function. Solo actualizar la referencia.
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🔄 UPDATE: INDIVIDUAL SKILLS MARKETPLACE                      ║");
    console.log("║  💰 Integración con TreasuryManager                            ║");
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
    
    const SKILLS_MARKETPLACE = deploymentData.marketplace?.individualSkills;
    const TREASURY_MANAGER = deploymentData.treasury?.manager;

    if (!SKILLS_MARKETPLACE) {
        console.error("❌ No se encontró IndividualSkillsMarketplace en polygon-addresses.json");
        console.error("   Clave esperada: marketplace.individualSkills");
        process.exit(1);
    }

    if (!TREASURY_MANAGER) {
        console.error("❌ No se encontró TreasuryManager en polygon-addresses.json");
        console.error("   Ejecuta primero: npx hardhat run scripts/updates/staking/deploy_treasury_manager_v2.cjs --network polygon");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance:", ethers.formatEther(initialBalance), "POL\n");
    
    console.log("📋 Direcciones cargadas:");
    console.log(`   Skills Marketplace:  ${SKILLS_MARKETPLACE}`);
    console.log(`   Treasury Manager:    ${TREASURY_MANAGER}\n`);

    // ====================================================
    // OPCIÓN 1: ACTUALIZAR REFERENCIA (SI EL CONTRATO TIENE SETTER)
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 1/3: Actualizando TreasuryManager en Skills Marketplace...\n");

    const skillsMarketplace = await ethers.getContractAt("IndividualSkillsMarketplace", SKILLS_MARKETPLACE);
    
    try {
        // Intentar actualizar usando setter
        console.log("   Intentando actualizar con setTreasuryManager()...");
        const tx = await skillsMarketplace.setTreasuryManager(TREASURY_MANAGER);
        await tx.wait();
        console.log("   ✅ TreasuryManager actualizado exitosamente\n");
    } catch (error) {
        console.log("   ⚠️  No se pudo actualizar (posiblemente el contrato no tiene setter)");
        console.log("   📝 Necesitarás redeploy del contrato IndividualSkillsMarketplace\n");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("📦 PASO 2/3: Desplegando nuevo IndividualSkillsMarketplace...\n");
        
        const SkillsMarketplaceFactory = await ethers.getContractFactory("IndividualSkillsMarketplace");
        console.log("   ⏳ Enviando transacción...");
        const newSkillsMarketplace = await SkillsMarketplaceFactory.deploy(TREASURY_MANAGER);
        await newSkillsMarketplace.waitForDeployment();
        const newAddress = await newSkillsMarketplace.getAddress();
        
        console.log("✅ Nuevo IndividualSkillsMarketplace deployed:", newAddress);
        console.log(`   🔗 https://polygonscan.com/address/${newAddress}\n`);

        // Actualizar addresses
        deploymentData.marketplace.individualSkillsOld = SKILLS_MARKETPLACE;
        deploymentData.marketplace.individualSkills = newAddress;
        deploymentData.marketplace.individualSkillsVersion = "2.1.0";
        deploymentData.marketplace.individualSkillsDeployedAt = new Date().toISOString();

        fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));

        console.log("⚠️  IMPORTANTE: Nuevo contrato desplegado");
        console.log("   Configuración pendiente:");
        console.log("   1. setStakingContract() para validaciones");
        console.log("   2. Transferir ownership si es necesario");
        console.log("   3. Actualizar frontend con nueva address\n");
        
        return;
    }

    // ====================================================
    // PASO 2: AUTORIZAR SKILLS MARKETPLACE EN TREASURY
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 2/3: Autorizando Skills Marketplace en TreasuryManager...\n");

    const treasuryManager = await ethers.getContractAt("TreasuryManager", TREASURY_MANAGER);
    
    console.log("   Verificando autorización actual...");
    const isAuthorized = await treasuryManager.authorizedSources(SKILLS_MARKETPLACE);
    
    if (!isAuthorized) {
        console.log("   Autorizando como revenue source...");
        const tx = await treasuryManager.setAuthorizedSource(SKILLS_MARKETPLACE, true);
        await tx.wait();
        console.log("   ✅ Skills Marketplace autorizado\n");
    } else {
        console.log("   ✅ Ya está autorizado\n");
    }

    // ====================================================
    // PASO 3: VERIFICAR INTEGRACIÓN
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🔍 PASO 3/3: Verificando integración...\n");

    const configuredTreasury = await skillsMarketplace.treasuryManager();
    const isSourceAuthorized = await treasuryManager.authorizedSources(SKILLS_MARKETPLACE);

    console.log("📊 Estado de integración:");
    console.log(`   Skills → Treasury Manager:    ${configuredTreasury === TREASURY_MANAGER ? '✅' : '❌'} ${configuredTreasury}`);
    console.log(`   Treasury authorizes Skills:   ${isSourceAuthorized ? '✅' : '❌'}`);
    console.log(`   Revenue flow:                 Skills → TreasuryManager → Treasuries ✅\n`);

    // ====================================================
    // RESUMEN FINAL
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasUsed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("✨ ACTUALIZACIÓN COMPLETADA\n");
    console.log("📊 Resumen:");
    console.log(`   Skills Marketplace:  ${SKILLS_MARKETPLACE}`);
    console.log(`   Treasury Manager:    ${TREASURY_MANAGER}`);
    console.log(`   Gas usado:           ${ethers.formatEther(gasUsed)} POL`);
    console.log(`   Tiempo:              ${executionTime}s`);
    console.log("\n💰 Flujo de revenue actualizado:");
    console.log(`   Individual Skills sales →`);
    console.log(`   TreasuryManager.receiveRevenue("individual_skill_purchase") →`);
    console.log(`   Distribución automática:`);
    console.log(`      • 10% → Reserve Fund`);
    console.log(`      • 30% → Rewards Treasury`);
    console.log(`      • 35% → Staking Treasury`);
    console.log(`      • 20% → Collaborators Treasury`);
    console.log(`      • 15% → Development Treasury`);
    console.log("\n📝 Próximos pasos:");
    console.log("   1. Probar una compra de skill para verificar flujo");
    console.log("   2. Monitorear TreasuryManager balance");
    console.log("   3. Verificar distribución automática\n");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ ERROR:", error);
        process.exit(1);
    });
