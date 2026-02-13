const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 💰 DEPLOY: TREASURY MANAGER V2 (con Reserve Fund)
 * 
 * NUEVAS FEATURES:
 * ✅ Reserve Fund System:
 *    - Acumulación automática (default 10% de ingresos)
 *    - Buffer de emergencia para volatilidad
 *    - Retiros controlados con justificación on-chain
 * 
 * ✅ Distribución actualizada:
 *    - Rewards: 30% (was 35%)
 *    - Staking: 35% (was 30%)
 *    - Collaborators: 20% (was 25%)
 *    - Development: 15% (was 10%)
 * 
 * ✅ Revenue sources integradas:
 *    - Staking commission (6%)
 *    - Marketplace fees (5%)
 *    - Individual Skills sales (nuevo)
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  💰 DEPLOY: TREASURY MANAGER V2                                ║");
    console.log("║  🛡️ Con Reserve Fund System                                    ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const startTime = Date.now();

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance inicial:", ethers.formatEther(initialBalance), "POL\n");

    // ====================================================
    // DESPLEGAR TREASURY MANAGER V2
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 1/4: Desplegando TreasuryManager v2...");
    console.log("   Configuración inicial:");
    console.log("      • Rewards allocation:        30%");
    console.log("      • Staking allocation:        35%");
    console.log("      • Collaborators allocation:  20%");
    console.log("      • Development allocation:    15%");
    console.log("      • Reserve fund allocation:   10%");
    console.log("      • Auto-distribution:         Enabled\n");
    
    const TreasuryFactory = await ethers.getContractFactory("TreasuryManager");
    console.log("   ⏳ Enviando transacción...");
    const treasuryManager = await TreasuryFactory.deploy();
    await treasuryManager.waitForDeployment();
    const treasuryAddress = await treasuryManager.getAddress();
    
    console.log("✅ TreasuryManager deployed:", treasuryAddress);
    console.log(`   🔗 https://polygonscan.com/address/${treasuryAddress}\n`);

    // ====================================================
    // VERIFICAR CONFIGURACIÓN
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🔍 PASO 2/4: Verificando configuración...\n");

    const allocations = await treasuryManager.getAllAllocations();
    const reserveStats = await treasuryManager.getReserveStats();
    const stats = await treasuryManager.getStats();

    console.log("📊 Allocations configuradas:");
    console.log(`   Rewards:        ${allocations[0].toString()} bps (${Number(allocations[0])/100}%)`);
    console.log(`   Staking:        ${allocations[1].toString()} bps (${Number(allocations[1])/100}%)`);
    console.log(`   Marketplace:    ${allocations[2].toString()} bps (${Number(allocations[2])/100}%)`);
    console.log(`   Development:    ${allocations[3].toString()} bps (${Number(allocations[3])/100}%)`);
    console.log(`   Collaborators:  ${allocations[4].toString()} bps (${Number(allocations[4])/100}%)\n`);

    console.log("🛡️ Reserve Fund configurado:");
    console.log(`   Balance actual:      ${ethers.formatEther(reserveStats[0])} POL`);
    console.log(`   Allocation:          ${reserveStats[3].toString()} bps (${Number(reserveStats[3])/100}%)`);
    console.log(`   Acumulación:         ${reserveStats[4] ? '✅ Enabled' : '❌ Disabled'}\n`);

    console.log("⚙️ Sistema general:");
    console.log(`   Auto-distribution:   ${stats[4] ? '✅ Enabled' : '❌ Disabled'}`);
    console.log(`   Total received:      ${ethers.formatEther(stats[0])} POL`);
    console.log(`   Total distributed:   ${ethers.formatEther(stats[1])} POL\n`);

    // ====================================================
    // CONFIGURAR TREASURY ADDRESSES (EJEMPLO)
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 3/4: Configurando treasury addresses...\n");

    // Cargar addresses existentes si hay
    const deploymentsDir = path.join(__dirname, "..", "..", "..", "deployments");
    const addressesFile = path.join(deploymentsDir, "polygon-addresses.json");
    
    let deploymentData = {};
    if (fs.existsSync(addressesFile)) {
        deploymentData = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    }

    // Si hay wallets configuradas, setearlas
    if (deploymentData.wallets) {
        const wallets = deploymentData.wallets;

        if (wallets.rewards) {
            console.log("   Configurando rewards treasury...");
            let tx = await treasuryManager.setTreasury("rewards", wallets.rewards);
            await tx.wait();
            console.log(`   ✅ Rewards: ${wallets.rewards}\n`);
        }

        if (wallets.staking) {
            console.log("   Configurando staking treasury...");
            let tx = await treasuryManager.setTreasury("staking", wallets.staking);
            await tx.wait();
            console.log(`   ✅ Staking: ${wallets.staking}\n`);
        }

        if (wallets.development) {
            console.log("   Configurando development treasury...");
            let tx = await treasuryManager.setTreasury("development", wallets.development);
            await tx.wait();
            console.log(`   ✅ Development: ${wallets.development}\n`);
        }

        if (wallets.collaborators) {
            console.log("   Configurando collaborators treasury...");
            let tx = await treasuryManager.setTreasury("collaborators", wallets.collaborators);
            await tx.wait();
            console.log(`   ✅ Collaborators: ${wallets.collaborators}\n`);
        }
    } else {
        console.log("   ⚠️  No se encontraron wallets configuradas.");
        console.log("   💡 Configura manualmente con setTreasury() después del deploy\n");
    }

    // ====================================================
    // GUARDAR DIRECCIÓN
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("💾 PASO 4/4: Guardando dirección...\n");

    if (!deploymentData.treasury) {
        deploymentData.treasury = {};
    }

    deploymentData.treasury.managerOld = deploymentData.treasury?.manager; // Backup
    deploymentData.treasury.manager = treasuryAddress;
    deploymentData.treasury.managerVersion = "2.0.0";
    deploymentData.treasury.managerDeployedAt = new Date().toISOString();

    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ Dirección guardada en polygon-addresses.json");
    console.log(`   Path: ${addressesFile}\n`);

    // ====================================================
    // RESUMEN FINAL
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasUsed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("✨ DEPLOYMENT COMPLETADO\n");
    console.log("📊 Resumen:");
    console.log(`   Contrato:          TreasuryManager v2.0.0`);
    console.log(`   Dirección:         ${treasuryAddress}`);
    console.log(`   Gas usado:         ${ethers.formatEther(gasUsed)} POL`);
    console.log(`   Tiempo:            ${executionTime}s`);
    console.log("\n🛡️ Reserve Fund System:");
    console.log(`   Acumulación automática:  10% de ingresos`);
    console.log(`   Estado inicial:          0 POL`);
    console.log(`   Funciones disponibles:`);
    console.log(`      • setReserveAllocation(percentage)`);
    console.log(`      • withdrawFromReserve(to, amount, reason)`);
    console.log(`      • depositToReserve() payable`);
    console.log(`      • getReserveStats()`);
    console.log("\n📝 Próximos pasos:");
    console.log("   1. Autorizar contratos como revenue sources:");
    console.log("      • setAuthorizedSource(stakingCore, true)");
    console.log("      • setAuthorizedSource(marketplace, true)");
    console.log("      • setAuthorizedSource(skillsMarketplace, true)");
    console.log("   2. Configurar treasury wallets si no están seteadas");
    console.log("   3. Configurar en contratos para que usen este TreasuryManager\n");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ ERROR EN DEPLOYMENT:", error);
        process.exit(1);
    });
