const { ethers } = require("hardhat");

async function main() {
    // ====================================================
    // CONFIGURACIÓN - REEMPLAZAR CON DIRECCIONES REALES
    // ====================================================
    const CORE_ADDRESS = "0x..."; // Dirección del EnhancedSmartStakingCore
    const MARKETPLACE_ADDRESS = "0x..."; // Dirección del Marketplace Core (Proxy)
    
    // ====================================================
    
    console.log("🚀 Iniciando actualización del módulo Gamification...");

    if (CORE_ADDRESS === "0x..." || MARKETPLACE_ADDRESS === "0x...") {
        console.error("❌ Error: Debes configurar las direcciones en el script antes de ejecutarlo.");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    console.log("📡 Desplegando con la cuenta:", deployer.address);

    // 1. Desplegar nuevo módulo Gamification
    console.log("📦 Desplegando EnhancedSmartStakingGamification...");
    const GamificationFactory = await ethers.getContractFactory("EnhancedSmartStakingGamification");
    const newGamification = await GamificationFactory.deploy();
    await newGamification.waitForDeployment();
    const newGamificationAddress = await newGamification.getAddress();
    console.log("✅ Nuevo Gamification Module desplegado en:", newGamificationAddress);

    // 2. Configurar dependencias en el nuevo módulo
    console.log("🔗 Configurando dependencias en el nuevo módulo...");
    let tx = await newGamification.setCoreStakingContract(CORE_ADDRESS);
    await tx.wait();
    console.log("   - Core Staking configurado");

    // NOTA CRÍTICA: El Staking Core reenvía las llamadas al módulo.
    // Por lo tanto, el "Marketplace" que ve el módulo es el propio Core.
    tx = await newGamification.setMarketplaceContract(CORE_ADDRESS);
    await tx.wait();
    console.log("   - Marketplace configurado (apuntando al Core para forwarding)");

    // 3. Conectar al Core
    console.log("🔗 Conectando nuevo módulo al Core...");
    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE_ADDRESS);
    tx = await core.setGamificationModule(newGamificationAddress);
    await tx.wait();
    
    console.log("🎉 Actualización completada exitosamente.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
