const { spawn } = require("child_process");
const path = require("path");

/**
 * 🚀 ORQUESTADOR DE DESPLIEGUES
 * 
 * Ejecuta secuencialmente todos los updates necesarios:
 * 1. TreasuryManager (centralización de ingresos)
 * 2. Gamification Module (con treasury integration)
 * 3. Rewards Module (con quest commission)
 * 4. Skills Module (con boost limits)
 */

async function runScript(scriptPath, scriptName) {
    return new Promise((resolve, reject) => {
        console.log(`\n${"═".repeat(70)}`);
        console.log(`▶️  EJECUTANDO: ${scriptName}`);
        console.log(`${"═".repeat(70)}\n`);

        const child = spawn("npx", [
            "hardhat",
            "run",
            scriptPath,
            "--network",
            "polygon"
        ], {
            stdio: "inherit",
            shell: true
        });

        child.on("close", (code) => {
            if (code === 0) {
                console.log(`\n✅ ${scriptName} completado\n`);
                resolve(true);
            } else {
                console.error(`\n❌ ${scriptName} falló con código ${code}\n`);
                reject(new Error(`${scriptName} falló`));
            }
        });

        child.on("error", (err) => {
            console.error(`\n❌ Error ejecutando ${scriptName}:`, err);
            reject(err);
        });
    });
}

async function main() {
    console.log("\n╔═══════════════════════════════════════════════════════════════════════╗");
    console.log("║  🚀 ORQUESTADOR DE ACTUALIZACIONES - NUXCHAIN PROTOCOL V2          ║");
    console.log("║  Ejecutará secuencialmente todos los módulos actualizados          ║");
    console.log("╚═══════════════════════════════════════════════════════════════════════╝");

    const startTime = Date.now();

    const scripts = [
        {
            path: path.join(__dirname, "deploy_treasury_manager.cjs"),
            name: "1️⃣  TREASURY MANAGER - Centralización de ingresos"
        },
        {
            path: path.join(__dirname, "update_gamification_module.cjs"),
            name: "2️⃣  GAMIFICATION MODULE - Auto-compound + Badges + Treasury"
        },
        {
            path: path.join(__dirname, "update_rewards_module.cjs"),
            name: "3️⃣  REWARDS MODULE - Quest commission + Treasury integration"
        },
        {
            path: path.join(__dirname, "update_skills_module.cjs"),
            name: "4️⃣  SKILLS MODULE - Boost limits + Anti-exploit"
        }
    ];

    console.log("\n📋 ORDEN DE EJECUCIÓN:\n");
    scripts.forEach((script, index) => {
        console.log(`   ${script.name}`);
    });

    console.log("\n⚠️  IMPORTANTE:");
    console.log("   • Esta operación puede demorar 10-15 minutos");
    console.log("   • Requiere suficiente balance de POL para gas");
    console.log("   • Asegúrate de tener las claves privadas configuradas\n");

    const answer = await new Promise((resolve) => {
        console.log("¿Deseas continuar? (s/n): ");
        process.stdin.setEncoding("utf8");
        process.stdin.once("readable", () => {
            const chunk = process.stdin.read();
            if (chunk !== null) {
                resolve(chunk.trim().toLowerCase() === "s" || chunk.trim().toLowerCase() === "y");
            }
        });
    });

    if (!answer) {
        console.log("\n❌ Operación cancelada por el usuario\n");
        process.exit(0);
    }

    try {
        for (const script of scripts) {
            await runScript(script.path, script.name);
        }

        const executionTime = ((Date.now() - startTime) / 1000 / 60).toFixed(2);

        console.log("\n╔═══════════════════════════════════════════════════════════════════════╗");
        console.log("║  ✅ TODAS LAS ACTUALIZACIONES COMPLETADAS EXITOSAMENTE            ║");
        console.log("╚═══════════════════════════════════════════════════════════════════════╝\n");

        console.log(`✨ Tiempo total: ${executionTime} minutos\n`);

        console.log("📊 RESUMEN DE CAMBIOS:\n");
        console.log("   🏦 TreasuryManager:");
        console.log("      • Centraliza todos los ingresos (6% staking + 5% marketplace + 2% quests)");
        console.log("      • Auto-distribuye a 4 pools (40/30/20/10)\n");

        console.log("   🎮 Gamification Module:");
        console.log("      • Auto-compound calcula rewards correctamente");
        console.log("      • 8 tipos de badges auto-award");
        console.log("      • Treasury fallback para rewards de level-up\n");

        console.log("   📊 Rewards Module:");
        console.log("      • 2% commission en quest rewards");
        console.log("      • Auto-routing a treasury");
        console.log("      • Fallback si treasury no disponible\n");

        console.log("   🛡️  Skills Module:");
        console.log("      • Max staking boost: +50%");
        console.log("      • Max fee discount: 75%");
        console.log("      • Max lock reduction: 50%");
        console.log("      • Pre-activation validation\n");

        console.log("🔐 PRÓXIMOS PASOS:\n");
        console.log("   1. Verificar todas las direcciones en Polygonscan");
        console.log("   2. Ejecutar suite de tests:");
        console.log("      npx hardhat test\n");
        console.log("   3. Autorizar fuentes en Treasury:");
        console.log("      setAuthorizedSource(CoreAddress, true)");
        console.log("      setAuthorizedSource(MarketplaceAddress, true)\n");
        console.log("   4. Fondear rewards pool en treasury:");
        console.log("      Transferir 100-200 POL al treasury\n");
        console.log("   5. Monitorear eventos en 24h:");
        console.log("      • RevenueReceived");
        console.log("      • RevenueDistributed");
        console.log("      • BadgeEarned\n");

        process.exit(0);
    } catch (error) {
        console.error("\n❌ Error en la cadena de despliegues:", error.message);
        console.error("\n⚠️  NOTA: Algunos módulos pueden haber sido desplegados exitosamente.");
        console.error("   Verifica polygon-addresses.json para ver qué se completó.\n");
        process.exit(1);
    }
}

main().catch(console.error);
