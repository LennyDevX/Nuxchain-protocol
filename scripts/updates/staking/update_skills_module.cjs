const { ethers } = require("hardhat");

async function main() {
    // ====================================================
    // CONFIGURACIÓN - REEMPLAZAR CON DIRECCIONES REALES
    // ====================================================
    const CORE_ADDRESS = "0x..."; // Dirección del EnhancedSmartStakingCore
    const MARKETPLACE_ADDRESS = "0x..."; // Dirección del Marketplace Core (Proxy)
    
    // ====================================================
    
    console.log("🚀 Iniciando actualización del módulo Skills...");

    if (CORE_ADDRESS === "0x..." || MARKETPLACE_ADDRESS === "0x...") {
        console.error("❌ Error: Debes configurar las direcciones en el script antes de ejecutarlo.");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    console.log("📡 Desplegando con la cuenta:", deployer.address);

    // 1. Desplegar nuevo módulo Skills
    console.log("📦 Desplegando EnhancedSmartStakingSkills...");
    const SkillsFactory = await ethers.getContractFactory("EnhancedSmartStakingSkills");
    const newSkills = await SkillsFactory.deploy();
    await newSkills.waitForDeployment();
    const newSkillsAddress = await newSkills.getAddress();
    console.log("✅ Nuevo Skills Module desplegado en:", newSkillsAddress);

    // 2. Configurar dependencias en el nuevo módulo
    console.log("🔗 Configurando dependencias en el nuevo módulo...");
    let tx = await newSkills.setCoreStakingContract(CORE_ADDRESS);
    await tx.wait();
    console.log("   - Core Staking configurado");

    // NOTA CRÍTICA: El Staking Core reenvía las llamadas al módulo.
    // Por lo tanto, el "Marketplace" que ve el módulo es el propio Core.
    // Configuramos el MarketplaceContract del módulo como la dirección del Core.
    tx = await newSkills.setMarketplaceContract(CORE_ADDRESS);
    await tx.wait();
    console.log("   - Marketplace configurado (apuntando al Core para forwarding)");

    // 3. Conectar al Core
    console.log("🔗 Conectando nuevo módulo al Core...");
    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE_ADDRESS);
    tx = await core.setSkillsModule(newSkillsAddress);
    await tx.wait();
    
    console.log("🎉 Actualización completada exitosamente.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
