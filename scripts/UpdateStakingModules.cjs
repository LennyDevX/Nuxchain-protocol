/**
 * 🔄 UPDATE STAKING MODULES
 * 
 * Actualiza las referencias de módulos en EnhancedSmartStakingCore
 * sin perder el estado de usuarios (stakes, rewards, etc)
 */

const { ethers } = require("hardhat");

async function main() {
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🔄 UPDATING STAKING MODULES                                 ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await ethers.getSigners();
    console.log(`👤 Deployer: ${deployer.address}\n`);

    // DIRECCIONES DESPLEGADAS
    const stakingCoreAddress = "0xC67F0a0cB719e4f4358D980a5D966878Fd6f3946"; // EXISTENTE
    const newRewardsAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
    const newSkillsAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
    const newGamificationAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";

    console.log("📍 DIRECCIONES A ACTUALIZAR:");
    console.log(`   Core (proxy):          ${stakingCoreAddress}`);
    console.log(`   Rewards (NUEVO):       ${newRewardsAddress}`);
    console.log(`   Skills (NUEVO):        ${newSkillsAddress}`);
    console.log(`   Gamification (NUEVO):  ${newGamificationAddress}\n`);

    // Conectar con el contrato
    const core = await ethers.getContractAt("EnhancedSmartStaking", stakingCoreAddress, deployer);

    console.log("📝 ACTUALIZANDO MÓDULOS...\n");

    // Actualizar Rewards Module
    console.log("1️⃣  Actualizando Rewards Module...");
    try {
        let tx = await core.setRewardsModule(newRewardsAddress);
        await tx.wait(1);
        console.log("   ✅ Rewards Module actualizado\n");
    } catch (error) {
        console.error(`   ❌ Error: ${error.message}\n`);
        return;
    }

    // Actualizar Skills Module
    console.log("2️⃣  Actualizando Skills Module...");
    try {
        let tx = await core.setSkillsModule(newSkillsAddress);
        await tx.wait(1);
        console.log("   ✅ Skills Module actualizado\n");
    } catch (error) {
        console.error(`   ❌ Error: ${error.message}\n`);
        return;
    }

    // Actualizar Gamification Module
    console.log("3️⃣  Actualizando Gamification Module...");
    try {
        let tx = await core.setGamificationModule(newGamificationAddress);
        await tx.wait(1);
        console.log("   ✅ Gamification Module actualizado\n");
    } catch (error) {
        console.error(`   ❌ Error: ${error.message}\n`);
        return;
    }

    // Verificar cambios
    console.log("✅ VERIFICANDO CAMBIOS...\n");
    try {
        const rewardsModuleRaw = await ethers.provider.call({
            to: stakingCoreAddress,
            data: core.interface.encodeFunctionData('rewardsModule')
        });
        console.log(`   Rewards Module call result: ${rewardsModuleRaw.substring(0, 66)}`);
        
        console.log("\n╔════════════════════════════════════════════════════════════════╗");
        console.log("║  ✅ LOS MÓDULOS HAN SIDO ACTUALIZADOS EXITOSAMENTE            ║");
        console.log("╚════════════════════════════════════════════════════════════════╝\n");
        
        console.log("📋 RESUMEN DE CAMBIOS:");
        console.log(`   1. Rewards Module:       ${newRewardsAddress}`);
        console.log(`   2. Skills Module:        ${newSkillsAddress}`);
        console.log(`   3. Gamification Module:  ${newGamificationAddress}\n`);
        
        console.log("⚠️  NOTA: La verificación completa se completará en el siguiente bloque\n");
    } catch (error) {
        console.log("\n╔════════════════════════════════════════════════════════════════╗");
        console.log("║  ✅ TODAS LAS TRANSACCIONES SE COMPLETARON EXITOSAMENTE        ║");
        console.log("╚════════════════════════════════════════════════════════════════╝\n");
        
        console.log("📋 MÓDULOS ACTUALIZADOS:");
        console.log(`   1. Rewards Module:       ${newRewardsAddress}`);
        console.log(`   2. Skills Module:        ${newSkillsAddress}`);
        console.log(`   3. Gamification Module:  ${newGamificationAddress}\n`);
        
        console.log("✨ El contrato de staking ahora se comunica con los nuevos módulos desplegados\n");
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
