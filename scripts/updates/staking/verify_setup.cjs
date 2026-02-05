const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 🔍 VERIFICACIÓN POST-DESPLIEGUE
 * 
 * Valida que todos los módulos estén correctamente configurados
 * y listos para producción
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🔍 VERIFICACIÓN POST-DESPLIEGUE                              ║");
    console.log("║  Validando configuración de todos los módulos                 ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

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
    
    const TREASURY_ADDRESS = deploymentData.treasury?.manager;
    const GAMIFICATION_ADDRESS = deploymentData.staking?.gamification;
    const REWARDS_ADDRESS = deploymentData.staking?.rewards;
    const SKILLS_ADDRESS = deploymentData.staking?.skills;
    const CORE_ADDRESS = deploymentData.staking?.core;

    console.log("📋 DIRECCIONES A VERIFICAR:\n");
    console.log(`   Treasury Manager:      ${TREASURY_ADDRESS || '❌ NO DESPLEGADO'}`);
    console.log(`   Gamification Module:   ${GAMIFICATION_ADDRESS || '❌ NO DESPLEGADO'}`);
    console.log(`   Rewards Module:        ${REWARDS_ADDRESS || '❌ NO DESPLEGADO'}`);
    console.log(`   Skills Module:         ${SKILLS_ADDRESS || '❌ NO DESPLEGADO'}`);
    console.log(`   Core Contract:         ${CORE_ADDRESS || '❌ NO DESPLEGADO'}\n`);

    let checksOK = 0;
    let checksFailed = 0;

    // ====================================================
    // VERIFICACIÓN 1: TREASURY MANAGER
    // ====================================================
    if (TREASURY_ADDRESS) {
        console.log("1️⃣  Verificando TreasuryManager...");
        try {
            const treasury = await ethers.getContractAt("TreasuryManager", TREASURY_ADDRESS);
            
            // Verificar que sea un contrato
            const code = await ethers.provider.getCode(TREASURY_ADDRESS);
            if (code === "0x") {
                console.log("   ❌ Dirección no contiene código (no es un contrato)\n");
                checksFailed++;
            } else {
                console.log("   ✅ Contrato existe");
                checksOK++;
            }
            
            // Verificar allocations
            const allocations = await treasury.getAllAllocations();
            const expectedAllocations = {
                rewards: 4000,
                staking: 3000,
                marketplace: 2000,
                development: 1000
            };
            
            if (allocations[0] == expectedAllocations.rewards &&
                allocations[1] == expectedAllocations.staking &&
                allocations[2] == expectedAllocations.marketplace &&
                allocations[3] == expectedAllocations.development) {
                console.log("   ✅ Allocations correctas (40/30/20/10)");
                checksOK++;
            } else {
                console.log("   ❌ Allocations incorrectas");
                console.log(`      Esperado: 4000/3000/2000/1000`);
                console.log(`      Obtenido: ${allocations[0]}/${allocations[1]}/${allocations[2]}/${allocations[3]}`);
                checksFailed++;
            }
            
            // Verificar que auto-distribution esté enabled
            const stats = await treasury.getStats();
            if (stats[4]) { // autoDistEnabled es índice 4
                console.log("   ✅ Auto-distribution habilitado");
                checksOK++;
            } else {
                console.log("   ⚠️  Auto-distribution deshabilitado (puede ser intencional)");
            }
            
            console.log();
        } catch (error) {
            console.log(`   ❌ Error: ${error.message}\n`);
            checksFailed++;
        }
    } else {
        console.log("   ⚠️  TreasuryManager no desplegado aún\n");
    }

    // ====================================================
    // VERIFICACIÓN 2: GAMIFICATION MODULE
    // ====================================================
    if (GAMIFICATION_ADDRESS && TREASURY_ADDRESS) {
        console.log("2️⃣  Verificando Gamification Module...");
        try {
            const gamification = await ethers.getContractAt("EnhancedSmartStakingGamification", GAMIFICATION_ADDRESS);
            const code = await ethers.provider.getCode(GAMIFICATION_ADDRESS);
            
            if (code === "0x") {
                console.log("   ❌ Dirección no contiene código\n");
                checksFailed++;
            } else {
                console.log("   ✅ Contrato existe");
                checksOK++;
            }
            
            // Verificar Treasury Manager vinculado
            const linkedTreasury = await gamification.treasuryManager();
            if (linkedTreasury.toLowerCase() === TREASURY_ADDRESS.toLowerCase()) {
                console.log("   ✅ Treasury Manager correctamente vinculado");
                checksOK++;
            } else {
                console.log("   ❌ Treasury Manager no vinculado");
                console.log(`      Esperado: ${TREASURY_ADDRESS}`);
                console.log(`      Obtenido: ${linkedTreasury}`);
                checksFailed++;
            }
            
            // Verificar Core vinculado
            const linkedCore = await gamification.coreStakingContract();
            if (linkedCore === CORE_ADDRESS) {
                console.log("   ✅ Core Staking correctamente vinculado");
                checksOK++;
            } else {
                console.log("   ⚠️  Core Staking no vinculado o diferente");
            }
            
            console.log();
        } catch (error) {
            console.log(`   ❌ Error: ${error.message}\n`);
            checksFailed++;
        }
    } else if (GAMIFICATION_ADDRESS) {
        console.log("2️⃣  Gamification sin Treasury - verificar si es intencional\n");
    }

    // ====================================================
    // VERIFICACIÓN 3: REWARDS MODULE
    // ====================================================
    if (REWARDS_ADDRESS && TREASURY_ADDRESS) {
        console.log("3️⃣  Verificando Rewards Module...");
        try {
            const rewards = await ethers.getContractAt("EnhancedSmartStakingRewards", REWARDS_ADDRESS);
            const code = await ethers.provider.getCode(REWARDS_ADDRESS);
            
            if (code === "0x") {
                console.log("   ❌ Dirección no contiene código\n");
                checksFailed++;
            } else {
                console.log("   ✅ Contrato existe");
                checksOK++;
            }
            
            // Verificar Treasury Manager vinculado
            const linkedTreasury = await rewards.treasuryManager();
            if (linkedTreasury.toLowerCase() === TREASURY_ADDRESS.toLowerCase()) {
                console.log("   ✅ Treasury Manager correctamente vinculado");
                checksOK++;
            } else {
                console.log("   ❌ Treasury Manager no vinculado");
                checksFailed++;
            }
            
            console.log();
        } catch (error) {
            console.log(`   ❌ Error: ${error.message}\n`);
            checksFailed++;
        }
    } else if (REWARDS_ADDRESS) {
        console.log("3️⃣  Rewards sin Treasury - verificar si es intencional\n");
    }

    // ====================================================
    // VERIFICACIÓN 4: SKILLS MODULE
    // ====================================================
    if (SKILLS_ADDRESS) {
        console.log("4️⃣  Verificando Skills Module...");
        try {
            const code = await ethers.provider.getCode(SKILLS_ADDRESS);
            
            if (code === "0x") {
                console.log("   ❌ Dirección no contiene código\n");
                checksFailed++;
            } else {
                console.log("   ✅ Contrato existe");
                checksOK++;
                
                // Verificar Core vinculado
                const skills = await ethers.getContractAt("EnhancedSmartStakingSkills", SKILLS_ADDRESS);
                const linkedCore = await skills.coreStakingContract();
                if (linkedCore === CORE_ADDRESS) {
                    console.log("   ✅ Core Staking correctamente vinculado");
                    checksOK++;
                } else {
                    console.log("   ⚠️  Core Staking no vinculado o diferente");
                }
            }
            
            console.log();
        } catch (error) {
            console.log(`   ❌ Error: ${error.message}\n`);
            checksFailed++;
        }
    }

    // ====================================================
    // VERIFICACIÓN 5: TREASURY AUTORIZACIONES
    // ====================================================
    if (TREASURY_ADDRESS) {
        console.log("5️⃣  Verificando autorizaciones en Treasury...");
        try {
            const treasury = await ethers.getContractAt("TreasuryManager", TREASURY_ADDRESS);
            
            // Verificar que Gamification es authorized requester
            if (GAMIFICATION_ADDRESS) {
                const isAuthGamification = await treasury.authorizedRequester(GAMIFICATION_ADDRESS);
                if (isAuthGamification) {
                    console.log("   ✅ Gamification autorizado como requester");
                    checksOK++;
                } else {
                    console.log("   ❌ Gamification NO autorizado como requester");
                    console.log("      Ejecutar: setAuthorizedRequester(gamificationAddress, true)");
                    checksFailed++;
                }
            }
            
            // Verificar que Rewards es authorized requester
            if (REWARDS_ADDRESS) {
                const isAuthRewards = await treasury.authorizedRequester(REWARDS_ADDRESS);
                if (isAuthRewards) {
                    console.log("   ✅ Rewards autorizado como requester");
                    checksOK++;
                } else {
                    console.log("   ❌ Rewards NO autorizado como requester");
                    console.log("      Ejecutar: setAuthorizedRequester(rewardsAddress, true)");
                    checksFailed++;
                }
            }
            
            console.log();
        } catch (error) {
            console.log(`   ❌ Error: ${error.message}\n`);
            checksFailed++;
        }
    }

    // ====================================================
    // RESUMEN
    // ====================================================
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  📊 RESUMEN DE VERIFICACIÓN                                   ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const totalChecks = checksOK + checksFailed;
    const percentage = ((checksOK / totalChecks) * 100).toFixed(0);

    console.log(`   ✅ Checks OK:      ${checksOK}/${totalChecks}`);
    console.log(`   ❌ Checks Fallidos: ${checksFailed}/${totalChecks}`);
    console.log(`   📊 Porcentaje:     ${percentage}%\n`);

    if (checksFailed === 0) {
        console.log("🎉 ¡TODO ESTÁ CORRECTAMENTE CONFIGURADO!\n");
        console.log("⚠️  PRÓXIMOS PASOS RECOMENDADOS:\n");
        console.log("   1. Autorizar fuentes en Treasury (si no están autorizadas)");
        console.log("   2. Fondear el Treasury con 100-200 POL inicial");
        console.log("   3. Monitorear eventos RevenueReceived en 24h");
        console.log("   4. Validar que auto-distribution está funcionando\n");
    } else if (checksFailed < 3) {
        console.log("⚠️  Algunos checks fallaron, pero la mayoría está OK.\n");
        console.log("   Ejecutar los pasos recomendados arriba para completar.\n");
    } else {
        console.log("❌ MÚLTIPLES PROBLEMAS ENCONTRADOS\n");
        console.log("   Por favor revisar:");
        console.log("   • polygon-addresses.json tiene direcciones válidas");
        console.log("   • Todos los contratos fueron desplegados en orden");
        console.log("   • Revisar logs en Polygonscan para transacciones fallidas\n");
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Error en verificación:", error.message);
        process.exit(1);
    });
