const { ethers } = require("hardhat");

async function main() {
    // ====================================================
    // CONFIGURACIÓN - REEMPLAZAR CON DIRECCIONES REALES
    // ====================================================
    const MARKETPLACE_CORE_ADDRESS = "0x..."; // Dirección del Marketplace Core (Proxy)
    const STAKING_CORE_ADDRESS = "0x..."; // Dirección del Staking Core
    const TREASURY_ADDRESS = "0x..."; // Dirección de la Tesorería
    
    // ====================================================
    
    console.log("🚀 Iniciando actualización del módulo Individual Skills...");

    if (MARKETPLACE_CORE_ADDRESS === "0x..." || STAKING_CORE_ADDRESS === "0x..." || TREASURY_ADDRESS === "0x...") {
        console.error("❌ Error: Debes configurar las direcciones en el script antes de ejecutarlo.");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    console.log("📡 Desplegando con la cuenta:", deployer.address);

    // 1. Desplegar nuevo contrato Individual Skills
    console.log("📦 Desplegando IndividualSkillsMarketplace...");
    const SkillsFactory = await ethers.getContractFactory("IndividualSkillsMarketplace");
    // Constructor toma treasuryAddress
    const newSkills = await SkillsFactory.deploy(TREASURY_ADDRESS);
    await newSkills.waitForDeployment();
    const newSkillsAddress = await newSkills.getAddress();
    console.log("✅ Nuevo Individual Skills desplegado en:", newSkillsAddress);

    // 2. Configurar dependencias
    console.log("🔗 Configurando dependencias...");
    let tx = await newSkills.setStakingContract(STAKING_CORE_ADDRESS);
    await tx.wait();
    console.log("   - Staking Contract configurado");

    // 3. Conectar al Marketplace Core
    console.log("🔗 Conectando nuevo contrato al Marketplace Core...");
    const marketplace = await ethers.getContractAt("GameifiedMarketplaceCoreV1", MARKETPLACE_CORE_ADDRESS);
    tx = await marketplace.setIndividualSkillsContract(newSkillsAddress);
    await tx.wait();
    
    console.log("🎉 Actualización completada exitosamente.");
    console.log("⚠️  ATENCIÓN REQUERIDA EN STAKING CORE:");
    console.log("    El Staking Core necesita autorizar este nuevo contrato para recibir notificaciones.");
    console.log("    Ejecuta manualmente en el Staking Core:");
    console.log(`    setMarketplaceAddress("${newSkillsAddress}")`);
    console.log("    NOTA: El Staking Core solo admite UNA dirección de marketplace a la vez.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
