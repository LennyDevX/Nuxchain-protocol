const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 💰 DESPLIEGUE: TREASURY MANAGER
 * 
 * Contrato centralizado que gestiona todos los ingresos del protocolo:
 * ✅ Recibe comisiones de:
 *    - Staking: 6% de retiros
 *    - Marketplace: 5% de ventas de NFT + 5% de skills
 *    - Quests: 2% de recompensas
 * 
 * ✅ Distribuye automáticamente en 4 pools:
 *    - 40% Rewards Pool (recompensas de nivel-up, quests, logros)
 *    - 30% Staking Operations (mantenimiento del protocolo)
 *    - 20% Marketplace Operations (desarrollo de features)
 *    - 10% Development Fund (investigación y desarrollo)
 * 
 * ✅ Características:
 *    - Auto-distribución cuando balance ≥ 1 POL
 *    - Autorización de fuentes (solo contratos autorizados pueden enviar fondos)
 *    - Autorización de requesters (solo módulos autorizados pueden solicitar fondos)
 *    - Fallback seguro si treasury no tiene fondos
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  💰 DESPLIEGUE: TREASURY MANAGER                              ║");
    console.log("║  Gestión centralizada de ingresos del protocolo               ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const startTime = Date.now();

    // ====================================================
    // CARGAR O CREAR ARCHIVO DE DIRECCIONES
    // ====================================================
    const deploymentsDir = path.join(__dirname, "..", "..", "..", "deployments");
    const addressesFile = path.join(deploymentsDir, "polygon-addresses.json");
    
    let deploymentData = {};
    
    if (fs.existsSync(addressesFile)) {
        deploymentData = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    } else {
        // Crear estructura básica si no existe
        deploymentData = {
            network: "polygon",
            chainId: "137",
            timestamp: new Date().toISOString(),
            staking: {},
            marketplace: {},
            treasury: {}
        };
    }

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance:", ethers.formatEther(initialBalance), "POL\n");

    // ====================================================
    // PASO 1: DESPLEGAR TREASURY MANAGER
    // ====================================================
    console.log("📦 PASO 1/4: Desplegando TreasuryManager...");
    console.log("   Configuración inicial:");
    console.log("      • Rewards Pool: 40%");
    console.log("      • Staking Operations: 30%");
    console.log("      • Marketplace Operations: 20%");
    console.log("      • Development Fund: 10%");
    console.log("      • Auto-distribute @ 1 POL\n");
    
    const TreasuryFactory = await ethers.getContractFactory("TreasuryManager");
    console.log("   ⏳ Enviando transacción...");
    const treasury = await TreasuryFactory.deploy();
    await treasury.waitForDeployment();
    const treasuryAddress = await treasury.getAddress();
    
    console.log("✅ TreasuryManager desplegado en:", treasuryAddress);
    console.log(`   🔗 https://polygonscan.com/address/${treasuryAddress}\n`);

    // ====================================================
    // PASO 2: OBTENER O CREAR DIRECCIONES DE TREASURIES
    // ====================================================
    console.log("🔐 PASO 2/4: Configurando sub-treasuries...");
    
    // Usar deployer como placeholder si no existen direcciones
    // En producción, estas serían direcciones multisig o contratos especializados
    const rewardsTreasury = deploymentData.treasury?.rewards || deployer.address;
    const stakingTreasury = deploymentData.treasury?.staking || deployer.address;
    const marketplaceTreasury = deploymentData.treasury?.marketplace || deployer.address;
    const developmentTreasury = deploymentData.treasury?.development || deployer.address;
    
    console.log("   Treasury Addresses:");
    console.log(`      • Rewards:      ${rewardsTreasury}`);
    console.log(`      • Staking:      ${stakingTreasury}`);
    console.log(`      • Marketplace:  ${marketplaceTreasury}`);
    console.log(`      • Development:  ${developmentTreasury}\n`);

    // ====================================================
    // PASO 3: REGISTRAR TREASURIES EN TREASURY MANAGER
    // ====================================================
    console.log("🔗 PASO 3/4: Registrando sub-treasuries en TreasuryManager...");
    
    let tx = await treasury.setTreasury("rewards", rewardsTreasury);
    await tx.wait();
    console.log("   ✅ Rewards Treasury registrada");

    tx = await treasury.setTreasury("staking", stakingTreasury);
    await tx.wait();
    console.log("   ✅ Staking Treasury registrada");

    tx = await treasury.setTreasury("marketplace", marketplaceTreasury);
    await tx.wait();
    console.log("   ✅ Marketplace Treasury registrada");

    tx = await treasury.setTreasury("development", developmentTreasury);
    await tx.wait();
    console.log("   ✅ Development Treasury registrada\n");

    // ====================================================
    // PASO 4: CONFIGURAR AUTORIZACIONES INICIALES
    // ====================================================
    console.log("🔐 PASO 4/4: Configurando autorizaciones iniciales...");
    
    // Estas direcciones se actualizarán una vez que se desplieguen los contratos
    console.log("   ⚠️  IMPORTANTE:");
    console.log("   Las autorizaciones se completarán cuando despliegues los módulos:");
    console.log("      • npx hardhat run scripts/updates/staking/update_gamification_module.cjs");
    console.log("      • npx hardhat run scripts/updates/staking/update_rewards_module.cjs\n");

    // ====================================================
    // GUARDAR DIRECCIONES
    // ====================================================
    console.log("💾 Guardando direcciones...");
    
    deploymentData.treasury = {
        manager: treasuryAddress,
        rewards: rewardsTreasury,
        staking: stakingTreasury,
        marketplace: marketplaceTreasury,
        development: developmentTreasury,
        deployedAt: new Date().toISOString(),
        allocations: {
            rewards: 4000,
            staking: 3000,
            marketplace: 2000,
            development: 1000
        },
        notes: "All allocation percentages in basis points (10000 = 100%)"
    };
    
    // Actualizar timestamp general
    if (!deploymentData.timestamp) {
        deploymentData.timestamp = new Date().toISOString();
    }
    
    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ polygon-addresses.json actualizado\n");

    // ====================================================
    // RESUMEN
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasConsumed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ TREASURY MANAGER DESPLEGADO                               ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log(`   Dirección:   ${treasuryAddress}`);
    console.log(`   Gas gastado: ${ethers.formatEther(gasConsumed)} POL`);
    console.log(`   Tiempo:      ${executionTime}s\n`);

    console.log("📊 ESTRUCTURA DE DISTRIBUCIÓN:");
    console.log("   Cuando el Treasury recibe fondos (≥ 1 POL):");
    console.log("      • 40% → Rewards Pool (recompensas de usuarios)");
    console.log("      • 30% → Staking Operations (sustentabilidad)");
    console.log("      • 20% → Marketplace Operations (features)");
    console.log("      • 10% → Development Fund (R&D)\n");

    console.log("💡 PRÓXIMOS PASOS:");
    console.log("   1. OPCIONALMENTE - Crear sub-treasuries especializadas:");
    console.log("      • Multisig para mayor seguridad");
    console.log("      • Contratos con lockups o vesting");
    console.log("      • EOAs separadas por responsabilidad\n");

    console.log("   2. DESPLEGAR MÓDULOS CON TREASURY INTEGRATION:");
    console.log("      npx hardhat run scripts/updates/staking/update_gamification_module.cjs --network polygon");
    console.log("      npx hardhat run scripts/updates/staking/update_rewards_module.cjs --network polygon");
    console.log("      npx hardhat run scripts/updates/staking/update_skills_module.cjs --network polygon\n");

    console.log("   3. AUTORIZAR FUENTES:");
    console.log("      En Polygonscan llamar a setAuthorizedSource() para:");
    console.log("      • EnhancedSmartStakingCore (comisiones de staking)");
    console.log("      • GameifiedMarketplaceCore (comisiones de marketplace)\n");

    console.log("   4. VERIFICAR EN POLYGONSCAN:");
    console.log(`      npx hardhat verify --network polygon ${treasuryAddress}\n`);

    console.log("⚠️  VERIFICACIÓN POST-DESPLIEGUE:");
    console.log(`   Ejecutar: npx hardhat run scripts/verify_treasury_setup.cjs --network polygon\n`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Error:", error.message);
        console.error(error);
        process.exit(1);
    });
