const { ethers, upgrades } = require("hardhat");

async function main() {
    // ====================================================
    // CONFIGURACIÓN - REEMPLAZAR CON DIRECCIONES REALES
    // ====================================================
    const PROXY_ADDRESS = "0xd502fB2Eb3d345EE9A5A0286A472B38c77Fda6d5"; // Dirección del Proxy del Marketplace Core

    // ====================================================

    console.log("🚀 Iniciando actualización del Marketplace Core (UUPS)...");

    if (PROXY_ADDRESS === "0x...") {
        console.error("❌ Error: Debes configurar la dirección del Proxy en el script antes de ejecutarlo.");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    console.log("📡 Desplegando con la cuenta:", deployer.address);

    // 1. Actualizar Proxy
    console.log("📦 Actualizando implementación...");
    // Asegúrate de que el nombre del contrato coincida con tu archivo (V1, V2, etc.)
    // Si hiciste cambios en GameifiedMarketplaceCoreV1.sol, usa ese nombre.
    const MarketplaceFactory = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");

    const upgraded = await upgrades.upgradeProxy(PROXY_ADDRESS, MarketplaceFactory);
    await upgraded.waitForDeployment();

    console.log("✅ Marketplace Core actualizado exitosamente.");
    console.log("   Dirección del Proxy (sin cambios):", await upgraded.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
