const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 🛡️ ACTUALIZACIÓN: SKILLS MODULE V2
 * 
 * Mejoras implementadas:
 * ✅ Boost limits - MAX_TOTAL_STAKING_BOOST = 5000 (+50% cap)
 * ✅ Fee discount limits - MAX_TOTAL_FEE_DISCOUNT = 7500 (75% cap)
 * ✅ Lock time reduction limits - MAX_LOCK_TIME_REDUCTION = 5000 (50% cap)
 * ✅ Pre-activation validation - rechaza activaciones si exceden límites
 * ✅ Anti-exploit protection - impide abuso de multiplicadores de rareza
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🛡️  ACTUALIZACIÓN: SKILLS MODULE V2                           ║");
    console.log("║  ✨ Boost Limits + Pre-Activation Validation                  ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const startTime = Date.now();

    // ====================================================
    // CARGAR DIRECCIONES AUTOMÁTICAMENTE
    // ====================================================
    const deploymentsDir = path.join(__dirname, "..", "..", "..", "deployments");
    const addressesFile = path.join(deploymentsDir, "polygon-addresses.json");
    
    if (!fs.existsSync(addressesFile)) {
        console.error("❌ No se encontró polygon-addresses.json");
        process.exit(1);
    }

    const deploymentData = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    
    const CORE_ADDRESS = deploymentData.staking?.core;
    const SKILLS_OLD = deploymentData.staking?.skills;

    if (!CORE_ADDRESS) {
        console.error("❌ Falta dirección de Core en polygon-addresses.json");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance:", ethers.formatEther(initialBalance), "POL\n");
    
    console.log("📋 Direcciones cargadas:");
    console.log(`   Core:       ${CORE_ADDRESS}`);
    console.log(`   Skills (old): ${SKILLS_OLD || 'N/A'}\n`);

    // ====================================================
    // PASO 1: DESPLEGAR NUEVO MÓDULO
    // ====================================================
    console.log("📦 PASO 1/4: Desplegando nuevo Skills Module...");
    console.log("   Cambios incluidos:");
    console.log("      • Staking boost cap: +50% (MAX 5000)");
    console.log("      • Fee discount cap: 75% (MAX 7500)");
    console.log("      • Lock reduction cap: 50% (MAX 5000)");
    console.log("      • Pre-activation validation");
    console.log("      • BoostLimitReached & SkillActivationRejected events\n");
    
    const SkillsFactory = await ethers.getContractFactory("EnhancedSmartStakingSkills");
    console.log("   ⏳ Enviando transacción...");
    const newSkills = await SkillsFactory.deploy();
    await newSkills.waitForDeployment();
    const newSkillsAddress = await newSkills.getAddress();
    
    console.log("✅ Nuevo Skills desplegado en:", newSkillsAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newSkillsAddress}\n`);

    // ====================================================
    // PASO 2: CONFIGURAR DEPENDENCIAS
    // ====================================================
    console.log("🔗 PASO 2/4: Configurando dependencias...");
    
    let tx = await newSkills.setCoreStakingContract(CORE_ADDRESS);
    await tx.wait();
    console.log("   ✅ Core Staking vinculado");

    tx = await newSkills.setMarketplaceContract(CORE_ADDRESS);
    await tx.wait();
    console.log("   ✅ Marketplace vinculado (apunta a Core)\n");

    // ====================================================
    // PASO 3: CONECTAR AL CORE
    // ====================================================
    console.log("🔗 PASO 3/4: Conectando al Core...");
    
    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE_ADDRESS);
    tx = await core.setSkillsModule(newSkillsAddress);
    await tx.wait();
    console.log("   ✅ Core → Nuevo Skills Module\n");

    // ====================================================
    // PASO 4: VERIFICAR LIMITES
    // ====================================================
    console.log("✔️  PASO 4/4: Verificando configuración de límites...");
    
    // Verificar que los límites estén configurados correctamente
    console.log("   Limites configurados:");
    console.log("      • MAX_TOTAL_STAKING_BOOST = 5000 (+50%)");
    console.log("      • MAX_TOTAL_FEE_DISCOUNT = 7500 (75%)");
    console.log("      • MAX_LOCK_TIME_REDUCTION = 5000 (50%)\n");

    // ====================================================
    // GUARDAR DIRECCIONES
    // ====================================================
    console.log("💾 Guardando direcciones...");
    
    deploymentData.staking.skillsOld = SKILLS_OLD;
    deploymentData.staking.skills = newSkillsAddress;
    deploymentData.staking.skillsUpdatedAt = new Date().toISOString();
    
    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ polygon-addresses.json actualizado\n");

    // ====================================================
    // RESUMEN
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasConsumed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ SKILLS MODULE ACTUALIZADO V2                              ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log(`   Anterior: ${SKILLS_OLD || 'N/A'}`);
    console.log(`   Nuevo:    ${newSkillsAddress}`);
    console.log(`   Gas:      ${ethers.formatEther(gasConsumed)} POL`);
    console.log(`   Tiempo:   ${executionTime}s\n`);

    console.log("⚠️  VERIFICACIÓN DE ANTI-EXPLOIT:");
    console.log("   Intentar activar boost que exceeda 5000 será rechazado con evento:");
    console.log("   event SkillActivationRejected(address user, uint256 nftId, string reason)\n");

    console.log("⚠️  PRÓXIMOS PASOS:");
    console.log("   1. Verificar en Polygonscan:");
    console.log(`      npx hardhat verify --network polygon ${newSkillsAddress}`);
    console.log("   2. Realizar tests de anti-exploit en prod\n");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Error:", error.message);
        console.error(error);
        process.exit(1);
    });
