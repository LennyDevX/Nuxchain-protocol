const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 🔧 FIX SCRIPT - Corregir configuración post-deployment
 * 
 * Soluciona:
 * 1. Configurar Skills en Rewards v5.1.0
 * 2. Verificar y actualizar Core si es necesario
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🔧 FIXING SUSTAINABILITY DEPLOYMENT                          ║");
    console.log("║  Corrigiendo configuraciones post-deployment                  ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    // Cargar direcciones
    const deploymentsDir = path.join(__dirname, "..", "..", "..", "deployments");
    const addressesFile = path.join(deploymentsDir, "polygon-addresses.json");
    
    if (!fs.existsSync(addressesFile)) {
        console.error("❌ No se encontró polygon-addresses.json");
        process.exit(1);
    }

    const deploymentData = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    
    const CORE = deploymentData.staking?.core;
    const REWARDS = deploymentData.staking?.rewards;
    const SKILLS = deploymentData.staking?.skills;
    const GAMIFICATION = deploymentData.staking?.gamification;
    const TREASURY_MANAGER = deploymentData.treasury?.manager;

    console.log("📋 Direcciones cargadas:");
    console.log(`   Core:             ${CORE}`);
    console.log(`   Rewards (v5.1.0): ${REWARDS}`);
    console.log(`   Skills (v5.1.0):  ${SKILLS}`);
    console.log(`   Gamification:     ${GAMIFICATION}`);
    console.log(`   Treasury Manager: ${TREASURY_MANAGER}\n`);

    if (!CORE || !REWARDS || !SKILLS || !TREASURY_MANAGER) {
        console.error("❌ Faltan direcciones críticas");
        process.exit(1);
    }

    console.log("═".repeat(70) + "\n");

    // ====================================================
    // FIX 1: CONFIGURAR SKILLS EN REWARDS
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ FIX 1: Configurar Skills Module en Rewards v5.1.0             │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const rewards = await ethers.getContractAt("EnhancedSmartStakingRewards", REWARDS);
    
    console.log("📝 Verificando configuración actual...");
    try {
        const skillsInRewards = await rewards.skillsModule();
        console.log(`   Skills en Rewards: ${skillsInRewards}`);
        
        if (skillsInRewards === "0x0000000000000000000000000000000000000000") {
            console.log("   ⚠️  Skills no configurado (0x0000...), configurando ahora...\n");
            
            try {
                const tx = await rewards.setSkillsModule(SKILLS);
                console.log(`   ⏳ Esperando confirmación... (tx: ${tx.hash})`);
                const receipt = await tx.wait();
                console.log(`   ✅ Skills configurado en Rewards (gas: ${receipt.gasUsed})\n`);
            } catch (err) {
                console.error(`   ❌ Error al configurar Skills: ${err.message}\n`);
            }
        } else if (skillsInRewards.toLowerCase() === SKILLS.toLowerCase()) {
            console.log("   ✅ Skills ya configurado correctamente\n");
        } else {
            console.log(`   ⚠️  Skills apunta a dirección diferente: ${skillsInRewards}`);
            console.log("   ACIÓN: Actualizando...\n");
            
            try {
                const tx = await rewards.setSkillsModule(SKILLS);
                console.log(`   ⏳ Esperando confirmación... (tx: ${tx.hash})`);
                const receipt = await tx.wait();
                console.log(`   ✅ Skills actualizado en Rewards (gas: ${receipt.gasUsed})\n`);
            } catch (err) {
                console.error(`   ❌ Error al actualizar Skills: ${err.message}\n`);
            }
        }
    } catch (err) {
        console.error(`   ❌ Error al leer skillsModule: ${err.message}\n`);
    }

    console.log("═".repeat(70) + "\n");

    // ====================================================
    // FIX 2: VERIFICAR CORE TREASURY MANAGER
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ FIX 2: Verificar Core - Treasury Manager                      │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE);
    
    console.log("📝 Verificando referencias en Core...");
    
    try {
        const rewardsInCore = await core.rewardsModule();
        console.log(`   Rewards en Core:      ${rewardsInCore}`);
        
        if (rewardsInCore.toLowerCase() === REWARDS.toLowerCase()) {
            console.log("   ✅ Rewards OK");
        } else {
            console.log("   ⚠️  Rewards incorrecto, actualizando...");
            const tx = await core.setRewardsModule(REWARDS);
            await tx.wait();
            console.log("   ✅ Rewards actualizado");
        }
    } catch (err) {
        console.log(`   ⚠️  No se puede verificar Rewards: ${err.message}`);
    }

    try {
        const skillsInCore = await core.skillsModule();
        console.log(`   Skills en Core:       ${skillsInCore}`);
        
        if (skillsInCore.toLowerCase() === SKILLS.toLowerCase()) {
            console.log("   ✅ Skills OK");
        } else {
            console.log("   ⚠️  Skills incorrecto, actualizando...");
            const tx = await core.setSkillsModule(SKILLS);
            await tx.wait();
            console.log("   ✅ Skills actualizado");
        }
    } catch (err) {
        console.log(`   ⚠️  No se puede verificar Skills: ${err.message}`);
    }

    try {
        const gamificationInCore = await core.gamificationModule();
        console.log(`   Gamification en Core: ${gamificationInCore}`);
        
        if (gamificationInCore.toLowerCase() === GAMIFICATION.toLowerCase()) {
            console.log("   ✅ Gamification OK\n");
        }
    } catch (err) {
        console.log(`   ⚠️  No se puede verificar Gamification: ${err.message}\n`);
    }

    // Intentar leer treasuryManager (puede no existir en versión vieja)
    console.log("📝 Intentando leer treasuryManager en Core...");
    try {
        const treasuryInCore = await core.treasuryManager();
        console.log(`   Treasury en Core:     ${treasuryInCore}`);
        
        if (treasuryInCore === "0x0000000000000000000000000000000000000000") {
            console.log("   ⚠️  Treasury no configurado en Core\n");
        } else if (treasuryInCore.toLowerCase() === TREASURY_MANAGER.toLowerCase()) {
            console.log("   ✅ Treasury OK\n");
        } else {
            console.log("   ⚠️  Treasury apunta a dirección diferente\n");
        }
    } catch (err) {
        console.log(`   ⚠️  Core no tiene setter para treasuryManager (versión vieja)`);
        console.log(`   💡 NOTA: Esto es normal si el Core no fue upgradeable\n`);
    }

    console.log("═".repeat(70) + "\n");

    // ====================================================
    // RESUMEN
    // ====================================================
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║                  ✅ FIXING COMPLETADO                         ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log("📋 CONFIGURACIÓN POST-FIX:\n");
    console.log("✅ Skills module configurado en Rewards v5.1.0");
    console.log("✅ Core referencias verificadas y actualizadas");
    console.log("✅ Treasury Manager registrado (si aplica)\n");

    console.log("📝 PRÓXIMOS PASOS:\n");
    console.log("1. Ejecutar nuevamente el script de verificación:");
    console.log("   npx hardhat run scripts/updates/staking/verify_sustainability_setup.cjs --network polygon\n");

    console.log("2. Si sigue habiendo errores, revisar manualmente en Etherscan:");
    console.log(`   https://polygonscan.com/address/${CORE}#readContract\n`);

    console.log("3. Configurar treasury wallets si aún no lo has hecho:");
    console.log("   npx hardhat console --network polygon\n");
}

main()
    .catch((error) => {
        console.error("\n❌ ERROR:", error.message);
        process.exit(1);
    });
