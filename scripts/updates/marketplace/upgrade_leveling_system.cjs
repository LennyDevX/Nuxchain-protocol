const { ethers, upgrades } = require("hardhat");

async function main() {
    // ====================================================
    // CONFIGURACIÓN - REEMPLAZAR CON DIRECCIONES REALES
    // ====================================================
    const PROXY_ADDRESS = "0x4A68884abF0B56481F6bDB0E6D4521f0074a1F44"; // Dirección del Proxy del Leveling System
    
    // ====================================================
    
    console.log("🚀 Iniciando actualización del Leveling System (UUPS)...");

    if (PROXY_ADDRESS === "0x...") {
        console.error("❌ Error: Debes configurar la dirección del Proxy en el script antes de ejecutarlo.");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    console.log("📡 Desplegando con la cuenta:", deployer.address);

    // 1. Actualizar Proxy
    console.log("📦 Actualizando implementación...");
    const LevelingFactory = await ethers.getContractFactory("LevelingSystem");
    
    const upgraded = await upgrades.upgradeProxy(PROXY_ADDRESS, LevelingFactory);
    await upgraded.waitForDeployment();
    
    console.log("✅ Leveling System actualizado exitosamente.");
    console.log("   Dirección del Proxy (sin cambios):", await upgraded.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
