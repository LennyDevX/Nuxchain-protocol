const { ethers } = require("hardhat");

async function main() {
    // ====================================================
    // CONFIGURACIÓN - REEMPLAZAR CON DIRECCIONES REALES
    // ====================================================
    const CORE_ADDRESS = "0x..."; // Dirección del EnhancedSmartStakingCore
    
    // ====================================================
    
    console.log("🚀 Iniciando actualización del contrato View...");

    if (CORE_ADDRESS === "0x...") {
        console.error("❌ Error: Debes configurar la dirección del Core en el script antes de ejecutarlo.");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    console.log("📡 Desplegando con la cuenta:", deployer.address);

    // 1. Desplegar nuevo View Contract
    console.log("📦 Desplegando EnhancedSmartStakingView...");
    const ViewFactory = await ethers.getContractFactory("EnhancedSmartStakingView");
    const newView = await ViewFactory.deploy(CORE_ADDRESS);
    await newView.waitForDeployment();
    const newViewAddress = await newView.getAddress();
    
    console.log("✅ Nuevo View Contract desplegado en:", newViewAddress);
    console.log("⚠️ IMPORTANTE: Actualiza la dirección del View Contract en tu Frontend (.env o config).");
    console.log("   El Core Contract NO necesita saber de este cambio.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
