const { ethers } = require("hardhat");

/**
 * 🔧 CONFIGURAR INDIVIDUAL SKILLS MARKETPLACE
 * 
 * Conecta IndividualSkillsMarketplace con TreasuryManager para que
 * las ventas de skills vayan automáticamente a la distribución.
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🔧 CONFIGURAR INDIVIDUAL SKILLS → TREASURY MANAGER          ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await ethers.getSigners();
    console.log("👤 Deployer:", deployer.address);

    const MP_ADDRESS = "0xB23257758B385444dF5A78aC2F315bd653470df3";
    const TM_ADDRESS = "0x8f3554Fca1Bd1b79bBf531706FA2C67fEcC5401F";

    console.log("\n📋 Direcciones:");
    console.log(`   Individual Skills MP: ${MP_ADDRESS}`);
    console.log(`   Treasury Manager:     ${TM_ADDRESS}\n`);

    const mp = await ethers.getContractAt("IndividualSkillsMarketplace", MP_ADDRESS);

    // ====================================================
    // PASO 1: Verificar roles
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 1: Verificar Roles                                       │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    // DEFAULT_ADMIN_ROLE es bytes32(0)
    const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
    
    // ADMIN_ROLE = keccak256("ADMIN_ROLE")
    const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));

    console.log("📝 Verificando roles del deployer...\n");

    const hasDefaultAdmin = await mp.hasRole(DEFAULT_ADMIN_ROLE, deployer.address);
    const hasAdminRole = await mp.hasRole(ADMIN_ROLE, deployer.address);

    console.log(`   DEFAULT_ADMIN_ROLE: ${hasDefaultAdmin ? "✅ SÍ" : "❌ NO"}`);
    console.log(`   ADMIN_ROLE:         ${hasAdminRole ? "✅ SÍ" : "❌ NO"}\n`);

    // ====================================================
    // PASO 2: Otorgar ADMIN_ROLE si no lo tiene
    // ====================================================
    if (!hasAdminRole) {
        console.log("┌────────────────────────────────────────────────────────────────┐");
        console.log("│ PASO 2: Otorgar ADMIN_ROLE                                    │");
        console.log("└────────────────────────────────────────────────────────────────┘\n");

        if (hasDefaultAdmin) {
            console.log("📝 Otorgando ADMIN_ROLE al deployer...");
            try {
                const tx = await mp.grantRole(ADMIN_ROLE, deployer.address);
                console.log(`   ⏳ Tx: ${tx.hash}`);
                const receipt = await tx.wait();
                console.log(`   ✅ ADMIN_ROLE otorgado (gas: ${receipt.gasUsed})\n`);
            } catch (err) {
                console.error(`   ❌ Error: ${err.message}\n`);
                console.error("   Necesitas que un DEFAULT_ADMIN actual te otorgue el rol\n");
                process.exit(1);
            }
        } else {
            console.error("❌ ERROR: Deployer no tiene DEFAULT_ADMIN_ROLE");
            console.error("\n📝 SOLUCIÓN:");
            console.error("   Un administrador actual debe ejecutar:");
            console.error(`   > mp.grantRole("${ADMIN_ROLE}", "${deployer.address}");\n`);
            process.exit(1);
        }
    } else {
        console.log("✅ Deployer ya tiene ADMIN_ROLE\n");
    }

    // ====================================================
    // PASO 3: Configurar TreasuryManager
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 3: Configurar TreasuryManager                            │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    console.log("📝 Ejecutando setTreasuryManager()...");
    try {
        const tx = await mp.setTreasuryManager(TM_ADDRESS);
        console.log(`   ⏳ Tx: ${tx.hash}`);
        
        const receipt = await tx.wait();
        console.log(`   ✅ TreasuryManager configurado (gas: ${receipt.gasUsed})\n`);
    } catch (err) {
        console.error(`   ❌ Error: ${err.message}\n`);
        
        if (err.message.includes("AccessControl")) {
            console.error("   Causa: Falta de permisos ADMIN_ROLE");
        }
        process.exit(1);
    }

    // ====================================================
    // PASO 4: Verificar configuración
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 4: Verificar Configuración                               │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const treasuryInMP = await mp.treasuryManager();
    console.log(`📋 TreasuryManager en MP: ${treasuryInMP}`);

    if (treasuryInMP.toLowerCase() === TM_ADDRESS.toLowerCase()) {
        console.log("   ✅ Configurado correctamente\n");
    } else {
        console.error("   ❌ ERROR: Dirección no coincide\n");
        process.exit(1);
    }

    // Verificar autorización en TreasuryManager
    const tm = await ethers.getContractAt("TreasuryManager", TM_ADDRESS);
    const isAuthorized = await tm.authorizedSources(MP_ADDRESS);
    
    console.log(`📋 MP autorizado en TM:   ${isAuthorized ? "✅ SÍ" : "❌ NO"}`);

    if (!isAuthorized) {
        console.log("\n⚠️  NOTA: Individual Skills MP no está autorizado en TreasuryManager");
        console.log("   Ya debería estarlo desde el deployment");
        console.log("   Si no, ejecuta manualmente:");
        console.log(`   > tm.setAuthorizedSource("${MP_ADDRESS}", true);\n`);
    } else {
        console.log("");
    }

    console.log("═".repeat(70));
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║           ✅ CONFIGURACIÓN COMPLETADA                        ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log("📊 FLUJO DE VENTAS DE SKILLS:\n");
    console.log("   1️⃣  Usuario compra skill en web");
    console.log("   2️⃣  IndividualSkillsMP.purchaseIndividualSkill()");
    console.log("   3️⃣  Fondos → TreasuryManager.receiveRevenue('individual_skill_purchase')");
    console.log("   4️⃣  Auto-distribución:");
    console.log("      • 10% → Reserve Fund");
    console.log("      • 30% → Rewards (CollaboratorBadgeRewards)");
    console.log("      • 35% → Staking (Core)");
    console.log("      • 20% → Collaborators (CollaboratorBadgeRewards)");
    console.log("      • 15% → Development (tu wallet)\n");

    console.log("═".repeat(70) + "\n");
}

main()
    .catch((error) => {
        console.error("\n❌ ERROR:", error.message);
        process.exit(1);
    });
