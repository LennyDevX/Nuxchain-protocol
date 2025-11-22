const { ethers } = require("hardhat");

async function main() {
    // ====================================================
    // CONFIGURACIÓN - REEMPLAZAR CON DIRECCIONES REALES
    // ====================================================
    const MARKETPLACE_CORE_ADDRESS = "0x..."; // Dirección del Marketplace Core (Proxy)
    const STAKING_CORE_ADDRESS = "0x..."; // Dirección del Staking Core
    
    // ====================================================
    
    console.log("🚀 Iniciando actualización del módulo Skills NFT (V2)...");
    console.log("⚠️ ADVERTENCIA: Desplegar un nuevo contrato de Skills NFT creará una colección VACÍA.");
    console.log("   Los usuarios perderán acceso a sus NFTs antiguos en la nueva versión.");
    console.log("   Solo ejecuta esto si estás seguro de lo que haces.");

    if (MARKETPLACE_CORE_ADDRESS === "0x..." || STAKING_CORE_ADDRESS === "0x...") {
        console.error("❌ Error: Debes configurar las direcciones en el script antes de ejecutarlo.");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    console.log("📡 Desplegando con la cuenta:", deployer.address);

    // 1. Desplegar nuevo contrato Skills NFT
    console.log("📦 Desplegando GameifiedMarketplaceSkillsV2...");
    const SkillsNFTFactory = await ethers.getContractFactory("GameifiedMarketplaceSkillsV2");
    // Constructor toma coreAddress
    const newSkillsNFT = await SkillsNFTFactory.deploy(MARKETPLACE_CORE_ADDRESS);
    await newSkillsNFT.waitForDeployment();
    const newSkillsNFTAddress = await newSkillsNFT.getAddress();
    console.log("✅ Nuevo Skills NFT desplegado en:", newSkillsNFTAddress);

    // 2. Configurar dependencias
    console.log("🔗 Configurando dependencias...");
    let tx = await newSkillsNFT.setStakingContract(STAKING_CORE_ADDRESS);
    await tx.wait();
    console.log("   - Staking Contract configurado");

    // 3. Conectar al Marketplace Core
    console.log("🔗 Conectando nuevo contrato al Marketplace Core...");
    const marketplace = await ethers.getContractAt("GameifiedMarketplaceCoreV1", MARKETPLACE_CORE_ADDRESS);
    tx = await marketplace.setSkillsContract(newSkillsNFTAddress);
    await tx.wait();
    
    console.log("🎉 Actualización completada exitosamente.");
    console.log("⚠️  ATENCIÓN REQUERIDA EN STAKING CORE:");
    console.log("    El Staking Core necesita autorizar este nuevo contrato para recibir notificaciones.");
    console.log("    Ejecuta manualmente en el Staking Core:");
    console.log(`    setMarketplaceAddress("${newSkillsNFTAddress}")`);
    console.log("    NOTA: El Staking Core solo admite UNA dirección de marketplace a la vez.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
