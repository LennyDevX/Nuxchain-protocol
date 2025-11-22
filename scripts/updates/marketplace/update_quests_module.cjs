const { ethers } = require("hardhat");

async function main() {
    // ====================================================
    // CONFIGURACIÓN - REEMPLAZAR CON DIRECCIONES REALES
    // ====================================================
    const MARKETPLACE_CORE_ADDRESS = "0x..."; // Dirección del Marketplace Core (Proxy)
    const STAKING_CORE_ADDRESS = "0x..."; // Dirección del Staking Core
    const LEVELING_ADDRESS = "0x..."; // Dirección del Leveling System (Proxy)
    
    // ====================================================
    
    console.log("🚀 Iniciando actualización del módulo Quests...");

    if (MARKETPLACE_CORE_ADDRESS === "0x..." || STAKING_CORE_ADDRESS === "0x..." || LEVELING_ADDRESS === "0x...") {
        console.error("❌ Error: Debes configurar las direcciones en el script antes de ejecutarlo.");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    console.log("📡 Desplegando con la cuenta:", deployer.address);

    // 1. Desplegar nuevo contrato Quests
    console.log("📦 Desplegando GameifiedMarketplaceQuests...");
    const QuestsFactory = await ethers.getContractFactory("GameifiedMarketplaceQuests");
    // Constructor toma coreAddress
    const newQuests = await QuestsFactory.deploy(MARKETPLACE_CORE_ADDRESS);
    await newQuests.waitForDeployment();
    const newQuestsAddress = await newQuests.getAddress();
    console.log("✅ Nuevo Quests Contract desplegado en:", newQuestsAddress);

    // 2. Configurar dependencias
    console.log("🔗 Configurando dependencias...");
    let tx = await newQuests.setStakingContract(STAKING_CORE_ADDRESS);
    await tx.wait();
    console.log("   - Staking Contract configurado");

    tx = await newQuests.setLevelingContract(LEVELING_ADDRESS);
    await tx.wait();
    console.log("   - Leveling Contract configurado");

    // 3. Conectar al Marketplace Core
    console.log("🔗 Conectando nuevo contrato al Marketplace Core...");
    const marketplace = await ethers.getContractAt("GameifiedMarketplaceCoreV1", MARKETPLACE_CORE_ADDRESS);
    tx = await marketplace.setQuestsContract(newQuestsAddress);
    await tx.wait();
    
    console.log("🎉 Actualización completada exitosamente.");
    console.log("⚠️  ATENCIÓN REQUERIDA EN STAKING CORE:");
    console.log("    Si las Quests otorgan XP/Recompensas en el Staking, el Core debe autorizar este contrato.");
    console.log("    Ejecuta manualmente en el Staking Core:");
    console.log(`    setMarketplaceAddress("${newQuestsAddress}")`);
    console.log("    NOTA: El Staking Core solo admite UNA dirección de marketplace a la vez.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
