const { ethers, upgrades } = require("hardhat");

async function main() {
    // ====================================================
    // CONFIGURACIÓN - REEMPLAZAR CON DIRECCIONES REALES
    // ====================================================
    const PROXY_ADDRESS = "0x..."; // Dirección del Proxy del Referral System
    
    // ====================================================
    
    console.log("🚀 Iniciando actualización del Referral System (UUPS)...");

    if (PROXY_ADDRESS === "0x...") {
        console.error("❌ Error: Debes configurar la dirección del Proxy en el script antes de ejecutarlo.");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    console.log("📡 Desplegando con la cuenta:", deployer.address);

    // 1. Actualizar Proxy
    console.log("📦 Actualizando implementación...");
    const ReferralFactory = await ethers.getContractFactory("ReferralSystem");
    
    const upgraded = await upgrades.upgradeProxy(PROXY_ADDRESS, ReferralFactory);
    await upgraded.waitForDeployment();
    
    console.log("✅ Referral System actualizado exitosamente.");
    console.log("   Dirección del Proxy (sin cambios):", await upgraded.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
