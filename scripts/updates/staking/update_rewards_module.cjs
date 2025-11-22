const { ethers } = require("hardhat");

async function main() {
    // ====================================================
    // CONFIGURACIÓN - REEMPLAZAR CON DIRECCIONES REALES
    // ====================================================
    const CORE_ADDRESS = "0x..."; // Dirección del EnhancedSmartStakingCore
    const SKILLS_MODULE_ADDRESS = "0x..."; // Dirección del módulo de Skills actual
    const GAMIFICATION_MODULE_ADDRESS = "0x..."; // Dirección del módulo de Gamification actual
    
    // ====================================================
    
    console.log("🚀 Iniciando actualización del módulo Rewards...");

    if (CORE_ADDRESS === "0x..." || SKILLS_MODULE_ADDRESS === "0x..." || GAMIFICATION_MODULE_ADDRESS === "0x...") {
        console.error("❌ Error: Debes configurar las direcciones en el script antes de ejecutarlo.");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    console.log("📡 Desplegando con la cuenta:", deployer.address);

    // 1. Desplegar nuevo módulo Rewards
    console.log("📦 Desplegando EnhancedSmartStakingRewards...");
    const RewardsFactory = await ethers.getContractFactory("EnhancedSmartStakingRewards");
    const newRewards = await RewardsFactory.deploy();
    await newRewards.waitForDeployment();
    const newRewardsAddress = await newRewards.getAddress();
    console.log("✅ Nuevo Rewards Module desplegado en:", newRewardsAddress);

    // 2. Configurar dependencias en el nuevo módulo
    console.log("🔗 Configurando dependencias en el nuevo módulo...");
    let tx = await newRewards.setSkillsModule(SKILLS_MODULE_ADDRESS);
    await tx.wait();
    console.log("   - Skills Module configurado");

    tx = await newRewards.setGamificationModule(GAMIFICATION_MODULE_ADDRESS);
    await tx.wait();
    console.log("   - Gamification Module configurado");

    // 3. Conectar al Core
    console.log("🔗 Conectando nuevo módulo al Core...");
    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE_ADDRESS);
    tx = await core.setRewardsModule(newRewardsAddress);
    await tx.wait();
    
    console.log("🎉 Actualización completada exitosamente.");
    console.log("👉 No olvides actualizar la dirección en tu Frontend si es necesario.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
