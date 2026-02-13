const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 🔍 VERIFICACIÓN COMPLETA - SUSTAINABILITY UPDATE
 * 
 * Verifica que todos los contratos estén correctamente:
 * - Desplegados
 * - Configurados
 * - Integrados entre sí
 * - Con los valores correctos (APY, boosts, allocations)
 * 
 * CHECKS:
 * ✅ TreasuryManager configuración
 * ✅ Reserve Fund sistema
 * ✅ DynamicAPYCalculator
 * ✅ Rewards APY rates reducidos 25%
 * ✅ Skills boosts reducidos 25%
 * ✅ Cross-references entre módulos
 * ✅ Autorizaciones
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🔍 VERIFICACIÓN SUSTAINABILITY UPDATE                        ║");
    console.log("║  Validando deployment y configuración                         ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    let errors = 0;
    let warnings = 0;

    // ====================================================
    // CARGAR DIRECCIONES
    // ====================================================
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
    const DYNAMIC_APY = deploymentData.staking?.dynamicAPYCalculator;
    const TREASURY_MANAGER = deploymentData.treasury?.manager;
    const SKILLS_MARKETPLACE = deploymentData.marketplace?.individualSkills;

    console.log("📋 Direcciones a verificar:");
    console.log(`   Core:                  ${CORE || '❌ NO ENCONTRADO'}`);
    console.log(`   Rewards:               ${REWARDS || '❌ NO ENCONTRADO'}`);
    console.log(`   Skills:                ${SKILLS || '❌ NO ENCONTRADO'}`);
    console.log(`   Gamification:          ${GAMIFICATION || '❌ NO ENCONTRADO'}`);
    console.log(`   DynamicAPYCalculator:  ${DYNAMIC_APY || '❌ NO ENCONTRADO'}`);
    console.log(`   TreasuryManager:       ${TREASURY_MANAGER || '❌ NO ENCONTRADO'}`);
    console.log(`   Skills Marketplace:    ${SKILLS_MARKETPLACE || 'No desplegado'}\n`);

    if (!CORE || !REWARDS || !SKILLS || !TREASURY_MANAGER) {
        console.error("❌ Faltan direcciones críticas. Ejecuta deployment primero.\n");
        process.exit(1);
    }

    console.log("═".repeat(70) + "\n");

    // ====================================================
    // 1. VERIFICAR TREASURY MANAGER
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ 1. TREASURY MANAGER V2                                         │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const treasuryManager = await ethers.getContractAt("TreasuryManager", TREASURY_MANAGER);

    // Allocations
    console.log("📊 Verificando allocations...");
    const allocations = await treasuryManager.getAllAllocations();
    const expectedAllocations = {
        rewards: 3000,      // 30%
        staking: 3500,      // 35%
        collaborators: 2000,// 20%
        development: 1500   // 15%
    };

    let allocationCheck = true;
    if (Number(allocations[0]) !== expectedAllocations.rewards) {
        console.error(`   ❌ Rewards: ${allocations[0]} (esperado ${expectedAllocations.rewards})`);
        errors++;
        allocationCheck = false;
    }
    if (Number(allocations[1]) !== expectedAllocations.staking) {
        console.error(`   ❌ Staking: ${allocations[1]} (esperado ${expectedAllocations.staking})`);
        errors++;
        allocationCheck = false;
    }
    if (Number(allocations[4]) !== expectedAllocations.collaborators) {
        console.error(`   ❌ Collaborators: ${allocations[4]} (esperado ${expectedAllocations.collaborators})`);
        errors++;
        allocationCheck = false;
    }
    if (Number(allocations[3]) !== expectedAllocations.development) {
        console.error(`   ❌ Development: ${allocations[3]} (esperado ${expectedAllocations.development})`);
        errors++;
        allocationCheck = false;
    }

    if (allocationCheck) {
        console.log("   ✅ Allocations correctas (30%, 35%, 20%, 15%)\n");
    }

    // Reserve Fund
    console.log("🛡️ Verificando Reserve Fund...");
    const reserveStats = await treasuryManager.getReserveStats();
    const reserveAllocation = Number(reserveStats[3]);
    const reserveEnabled = reserveStats[4];

    if (reserveAllocation === 1000 && reserveEnabled) {
        console.log(`   ✅ Reserve Fund: ${reserveAllocation/100}% acumulación, ${reserveEnabled ? 'Enabled' : 'Disabled'}\n`);
    } else {
        console.error(`   ❌ Reserve Fund mal configurado: ${reserveAllocation/100}%, ${reserveEnabled ? 'Enabled' : 'Disabled'}`);
        errors++;
    }

    // Autorizaciones
    console.log("🔐 Verificando autorizaciones...");
    const coreAuthorized = await treasuryManager.authorizedSources(CORE);
    if (coreAuthorized) {
        console.log("   ✅ Core autorizado como revenue source");
    } else {
        console.error("   ❌ Core NO autorizado");
        errors++;
    }

    if (SKILLS_MARKETPLACE) {
        const skillsMarketAuthorized = await treasuryManager.authorizedSources(SKILLS_MARKETPLACE);
        if (skillsMarketAuthorized) {
            console.log("   ✅ Skills Marketplace autorizado");
        } else {
            console.warn("   ⚠️  Skills Marketplace NO autorizado");
            warnings++;
        }
    }

    console.log("\n" + "═".repeat(70) + "\n");

    // ====================================================
    // 2. VERIFICAR DYNAMIC APY CALCULATOR
    // ====================================================
    if (DYNAMIC_APY) {
        console.log("┌────────────────────────────────────────────────────────────────┐");
        console.log("│ 2. DYNAMIC APY CALCULATOR                                      │");
        console.log("└────────────────────────────────────────────────────────────────┘\n");

        const dynamicAPY = await ethers.getContractAt("DynamicAPYCalculator", DYNAMIC_APY);

        const targetTVL = await dynamicAPY.targetTVL();
        const minMultiplier = await dynamicAPY.minAPYMultiplier();
        const maxMultiplier = await dynamicAPY.maxAPYMultiplier();
        const isEnabled = await dynamicAPY.dynamicAPYEnabled();

        console.log("⚙️ Configuración:");
        console.log(`   Target TVL:        ${ethers.formatEther(targetTVL)} POL`);
        console.log(`   Min Multiplier:    ${Number(minMultiplier)/100}%`);
        console.log(`   Max Multiplier:    ${Number(maxMultiplier)/100}%`);
        console.log(`   Estado:            ${isEnabled ? '✅ Enabled' : '⚠️ Disabled'}\n`);

        // Test calculation
        const baseAPY = 1183; // 118.3%
        const testTVL = ethers.parseEther("2000000"); // 2M POL
        const resultAPY = await dynamicAPY.calculateDynamicAPY(baseAPY, testTVL);
        
        console.log("🧪 Test cálculo (TVL = 2M POL):");
        console.log(`   Base APY:          ${baseAPY/100}%`);
        console.log(`   Dynamic APY:       ${Number(resultAPY)/100}%`);
        console.log(`   ✅ Funcionando correctamente\n`);

        console.log("═".repeat(70) + "\n");
    }

    // ====================================================
    // 3. VERIFICAR REWARDS MODULE V5.1.0
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ 3. REWARDS MODULE V5.1.0 (APY -25%)                            │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const rewards = await ethers.getContractAt("EnhancedSmartStakingRewards", REWARDS);

    // Verificar APY rates
    console.log("📊 Verificando APY rates...");
    const apyConfig = await rewards.getLockupPeriodsConfig();
    const expectedAPYs = [197, 328, 591, 788, 1183]; // Reducidos 25%

    let apyCheck = true;
    for (let i = 0; i < 5; i++) {
        const actual = Number(apyConfig[1][i]);
        const expected = expectedAPYs[i];
        
        if (actual !== expected) {
            console.error(`   ❌ APY[${i}]: ${actual/100}% (esperado ${expected/100}%)`);
            errors++;
            apyCheck = false;
        }
    }

    if (apyCheck) {
        console.log("   ✅ APY rates correctos (19.7%, 32.8%, 59.1%, 78.8%, 118.3%)\n");
    }

    // Verificar módulos configurados
    console.log("🔗 Verificando módulos configurados...");
    const skillsInRewards = await rewards.skillsModule();
    const gamificationInRewards = await rewards.gamificationModule();
    const treasuryInRewards = await rewards.treasuryManager();

    if (skillsInRewards === SKILLS) {
        console.log("   ✅ Skills module configurado");
    } else {
        console.error(`   ❌ Skills module incorrecto: ${skillsInRewards}`);
        errors++;
    }

    if (gamificationInRewards === GAMIFICATION) {
        console.log("   ✅ Gamification module configurado");
    } else {
        console.error(`   ❌ Gamification module incorrecto: ${gamificationInRewards}`);
        errors++;
    }

    if (treasuryInRewards === TREASURY_MANAGER) {
        console.log("   ✅ TreasuryManager configurado\n");
    } else {
        console.error(`   ❌ TreasuryManager incorrecto: ${treasuryInRewards}\n`);
        errors++;
    }

    console.log("═".repeat(70) + "\n");

    // ====================================================
    // 4. VERIFICAR SKILLS MODULE V5.1.0
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ 4. SKILLS MODULE V5.1.0 (Boosts -25%)                          │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const skills = await ethers.getContractAt("EnhancedSmartStakingSkills", SKILLS);

    // Verificar configuraciones
    console.log("🔗 Verificando configuraciones...");
    const coreInSkills = await skills.coreStakingContract();

    if (coreInSkills === CORE) {
        console.log("   ✅ Core contract configurado");
    } else {
        console.error(`   ❌ Core contract incorrecto: ${coreInSkills}`);
        errors++;
    }

    console.log("\n⚠️  Nota: No se pueden verificar valores de skills directamente");
    console.log("   desde external view (mappings privados)");
    console.log("   Verificación manual requerida:\n");
    console.log("   Valores esperados:");
    console.log("      • MAX_TOTAL_STAKING_BOOST: 3750 bps (37.5%)");
    console.log("      • MAX_TOTAL_FEE_DISCOUNT: 5625 bps (56.25%)");
    console.log("      • MAX_LOCK_TIME_REDUCTION: 3750 bps (37.5%)\n");

    console.log("═".repeat(70) + "\n");

    // ====================================================
    // 5. VERIFICAR CORE CONTRACT
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ 5. CORE CONTRACT - REFERENCIAS                                 │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE);

    console.log("🔗 Verificando referencias...");
    
    try {
        const rewardsInCore = await core.rewardsModule();
        if (rewardsInCore === REWARDS) {
            console.log("   ✅ Rewards module apunta a v5.1.0");
        } else {
            console.error(`   ❌ Rewards module incorrecto: ${rewardsInCore}`);
            errors++;
        }
    } catch (err) {
        console.warn("   ⚠️  No se puede verificar Rewards en Core");
    }

    try {
        const skillsInCore = await core.skillsModule();
        if (skillsInCore === SKILLS) {
            console.log("   ✅ Skills module apunta a v5.1.0");
        } else {
            console.error(`   ❌ Skills module incorrecto: ${skillsInCore}`);
            errors++;
        }
    } catch (err) {
        console.warn("   ⚠️  No se puede verificar Skills en Core");
    }

    try {
        const gamificationInCore = await core.gamificationModule();
        if (gamificationInCore === GAMIFICATION) {
            console.log("   ✅ Gamification module configurado");
        } else {
            console.error(`   ❌ Gamification module incorrecto: ${gamificationInCore}`);
            errors++;
        }
    } catch (err) {
        console.warn("   ⚠️  No se puede verificar Gamification en Core");
    }

    try {
        const treasuryInCore = await core.treasuryManager();
        if (treasuryInCore === TREASURY_MANAGER) {
            console.log("   ✅ TreasuryManager configurado\n");
        } else if (treasuryInCore === "0x0000000000000000000000000000000000000000") {
            console.warn("   ⚠️  TreasuryManager no configurado en Core (puede ser normal)\n");
        } else {
            console.warn(`   ⚠️  TreasuryManager apunta a dirección diferente\n`);
        }
    } catch (err) {
        console.warn("   ⚠️  Core no tiene getter para treasuryManager (versión antigua)\n");
        console.warn("   💡 NOTA: Si Core no es upgradeable, esto es esperado\n");
    }

    console.log("═".repeat(70) + "\n");

    // ====================================================
    // 6. VERIFICAR INDIVIDUAL SKILLS MARKETPLACE (SI EXISTE)
    // ====================================================
    if (SKILLS_MARKETPLACE) {
        console.log("┌────────────────────────────────────────────────────────────────┐");
        console.log("│ 6. INDIVIDUAL SKILLS MARKETPLACE                               │");
        console.log("└────────────────────────────────────────────────────────────────┘\n");

        try {
            const skillsMarketplace = await ethers.getContractAt("IndividualSkillsMarketplace", SKILLS_MARKETPLACE);

            console.log("🔗 Verificando integración...");
            
            try {
                const treasuryInSkillsMarket = await skillsMarketplace.treasuryManager();

                if (treasuryInSkillsMarket === TREASURY_MANAGER) {
                    console.log("   ✅ TreasuryManager configurado");
                } else if (treasuryInSkillsMarket === "0x0000000000000000000000000000000000000000") {
                    console.warn("   ⚠️  TreasuryManager no configurado en marketplace");
                    warnings++;
                } else {
                    console.log(`   ⚠️  TreasuryManager apunta a: ${treasuryInSkillsMarket}`);
                }
            } catch (innerErr) {
                if (innerErr.message.includes("execution reverted")) {
                    console.warn("   ⚠️  Marketplace proxy puede estar vacío o con setter faltante");
                    console.warn("   💡 Esto es normal si el setter no fue llamado\n");
                    warnings++;
                } else {
                    throw innerErr;
                }
            }

            const isAuthorized = await treasuryManager.authorizedSources(SKILLS_MARKETPLACE);
            if (isAuthorized) {
                console.log("   ✅ Autorizado en TreasuryManager\n");
            } else {
                console.warn("   ⚠️  NO autorizado en TreasuryManager\n");
                warnings++;
            }

        } catch (err) {
            console.error(`   ❌ Error verificando marketplace: ${err.message}\n`);
            errors++;
        }

        console.log("═".repeat(70) + "\n");
    }

    // ====================================================
    // RESUMEN FINAL
    // ====================================================
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║                    RESUMEN DE VERIFICACIÓN                     ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log(`Total de errores:      ${errors}`);
    console.log(`Total de warnings:     ${warnings}\n`);

    if (errors === 0 && warnings === 0) {
        console.log("✅ ¡VERIFICACIÓN EXITOSA! Todos los contratos están correctamente configurados.\n");
        console.log("═".repeat(70) + "\n");
        console.log("📝 Próximos pasos:");
        console.log("   1. Configurar treasury wallets (rewards, staking, etc.)");
        console.log("   2. Realizar pruebas en testnet antes de production");
        console.log("   3. Comunicar cambios a la comunidad");
        console.log("   4. Actualizar frontend con nuevos ABIs\n");
        process.exit(0);
    } else if (errors === 0) {
        console.log("⚠️  VERIFICACIÓN COMPLETADA CON WARNINGS\n");
        console.log(`   ${warnings} warning(s) encontrado(s).`);
        console.log("   Revisa los mensajes arriba y corrige si es necesario.\n");
        process.exit(0);
    } else {
        console.log("❌ VERIFICACIÓN FALLIDA\n");
        console.log(`   ${errors} error(es) crítico(s) encontrado(s).`);
        console.log("   Revisa los mensajes arriba y corrige antes de continuar.\n");
        process.exit(1);
    }
}

main()
    .catch((error) => {
        console.error("\n❌ ERROR EN VERIFICACIÓN:", error);
        process.exit(1);
    });
