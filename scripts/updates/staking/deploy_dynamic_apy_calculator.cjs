const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 📈 DEPLOY: DYNAMIC APY CALCULATOR
 * 
 * Sistema de APY dinámico basado en TVL:
 * - APY se ajusta automáticamente según el Total Value Locked
 * - Fórmula: APY = baseAPY × sqrt(targetTVL / currentTVL)
 * - Previene insostenibilidad a escala
 * 
 * Configuración inicial:
 * - Target TVL: 1M POL (referencia)
 * - Min APY Multiplier: 30% (floor)
 * - Max APY Multiplier: 100% (ceiling)
 * - Dynamic APY: Habilitado
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  📈 DEPLOY: DYNAMIC APY CALCULATOR                             ║");
    console.log("║  🎯 Sistema de APY adaptativo según TVL                       ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const startTime = Date.now();

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance inicial:", ethers.formatEther(initialBalance), "POL\n");

    // ====================================================
    // DESPLEGAR DYNAMIC APY CALCULATOR
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 Desplegando DynamicAPYCalculator...");
    console.log("   Configuración por defecto:");
    console.log("      • Target TVL:    1,000,000 POL");
    console.log("      • Min Multiplier: 30% (3000 bps)");
    console.log("      • Max Multiplier: 100% (10000 bps)");
    console.log("      • Dynamic APY:    Enabled\n");

    const DynamicAPYFactory = await ethers.getContractFactory("DynamicAPYCalculator");
    console.log("   ⏳ Enviando transacción...");
    const dynamicAPY = await DynamicAPYFactory.deploy();
    await dynamicAPY.waitForDeployment();
    const dynamicAPYAddress = await dynamicAPY.getAddress();
    
    console.log("✅ DynamicAPYCalculator desplegado:", dynamicAPYAddress);
    console.log(`   🔗 https://polygonscan.com/address/${dynamicAPYAddress}\n`);

    // ====================================================
    // VERIFICAR CONFIGURACIÓN
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🔍 Verificando configuración...\n");

    const targetTVL = await dynamicAPY.targetTVL();
    const minMultiplier = await dynamicAPY.minAPYMultiplier();
    const maxMultiplier = await dynamicAPY.maxAPYMultiplier();
    const isEnabled = await dynamicAPY.dynamicAPYEnabled();

    console.log("📊 Configuración actual:");
    console.log(`   Target TVL:        ${ethers.formatEther(targetTVL)} POL`);
    console.log(`   Min Multiplier:    ${minMultiplier.toString()} bps (${Number(minMultiplier)/100}%)`);
    console.log(`   Max Multiplier:    ${maxMultiplier.toString()} bps (${Number(maxMultiplier)/100}%)`);
    console.log(`   Dynamic APY:       ${isEnabled ? '✅ Enabled' : '❌ Disabled'}\n`);

    // ====================================================
    // PRUEBAS DE CÁLCULO
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🧪 Probando cálculos de APY dinámico...\n");

    const baseAPY = 1183; // 118.3% (365-day lock, reducido 25%)
    const testTVLs = [
        ethers.parseEther("500000"),    // 500K POL
        ethers.parseEther("1000000"),   // 1M POL (target)
        ethers.parseEther("2000000"),   // 2M POL
        ethers.parseEther("5000000"),   // 5M POL
        ethers.parseEther("10000000"),  // 10M POL
    ];

    console.log(`Base APY: ${baseAPY} bps (${baseAPY/100}%)\n`);
    console.log("TVL Scenario           Multiplier    Dynamic APY");
    console.log("─────────────────────  ───────────   ───────────");

    for (const tvl of testTVLs) {
        const dynamicResult = await dynamicAPY.calculateDynamicAPY(baseAPY, tvl);
        const multiplier = await dynamicAPY.getCurrentMultiplier(tvl);
        
        const tvlFormatted = ethers.formatEther(tvl).padEnd(10);
        const multFormatted = `${Number(multiplier)/100}%`.padEnd(12);
        const apyFormatted = `${Number(dynamicResult)/100}%`;
        
        console.log(`${tvlFormatted} POL    ${multFormatted} ${apyFormatted}`);
    }

    console.log("\n");

    // ====================================================
    // GUARDAR DIRECCIÓN
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("💾 Guardando dirección...\n");

    const deploymentsDir = path.join(__dirname, "..", "..", "..", "deployments");
    const addressesFile = path.join(deploymentsDir, "polygon-addresses.json");
    
    let deploymentData = {};
    if (fs.existsSync(addressesFile)) {
        deploymentData = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    }

    if (!deploymentData.staking) {
        deploymentData.staking = {};
    }

    deploymentData.staking.dynamicAPYCalculator = dynamicAPYAddress;
    deploymentData.staking.dynamicAPYCalculatorDeployedAt = new Date().toISOString();

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
    console.log(`   Contrato:          DynamicAPYCalculator`);
    console.log(`   Dirección:         ${dynamicAPYAddress}`);
    console.log(`   Gas usado:         ${ethers.formatEther(gasUsed)} POL`);
    console.log(`   Tiempo ejecución:  ${executionTime}s`);
    console.log(`   Network:           ${(await ethers.provider.getNetwork()).name}`);
    console.log("\n📝 Próximos pasos:");
    console.log("   1. (Opcional) Configurar en Rewards module para usar dinámicamente");
    console.log("   2. Monitorear TVL y ajustar targetTVL si es necesario");
    console.log("   3. El sistema ya está listo para calcular APY dinámico\n");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ ERROR EN DEPLOYMENT:", error);
        process.exit(1);
    });
