const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * ⚡ DEPLOY: ENHANCED STAKING SKILLS V5.1.0
 * 
 * CAMBIOS CRÍTICOS - REDUCCIÓN 25% PARA SOSTENIBILIDAD:
 * ✅ Skill boosts reducidos 25%:
 *    - STAKE_BOOST_I:    +5% → +3.75%
 *    - STAKE_BOOST_II:   +10% → +7.5%
 *    - STAKE_BOOST_III:  +20% → +15%
 *    - FEE_REDUCER_I:    -10% → -7.5%
 *    - FEE_REDUCER_II:   -25% → -18.75%
 *    - Badge Skills:     +5% → +3.75%
 * 
 * ✅ Caps reducidos:
 *    - Max Staking Boost:    50% → 37.5%
 *    - Max Fee Discount:     75% → 56.25%
 *    - Max Lock Reduction:   50% → 37.5%
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  ⚡ DEPLOY: SKILLS MODULE V5.1.0                               ║");
    console.log("║  🎯 Boosts Reducidos 25% - Sostenibilidad Protocol            ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const startTime = Date.now();

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
    
    const CORE_ADDRESS = deploymentData.staking?.core;
    const OLD_SKILLS = deploymentData.staking?.skills;
    const MARKETPLACE_ADDRESS = deploymentData.marketplace?.core;

    if (!CORE_ADDRESS) {
        console.error("❌ Falta CORE_ADDRESS en polygon-addresses.json");
        process.exit(1);
    }

    const [deployer] = await ethers.getSigners();
    const initialBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💰 Balance:", ethers.formatEther(initialBalance), "POL\n");
    
    console.log("📋 Direcciones cargadas:");
    console.log(`   Core:                 ${CORE_ADDRESS}`);
    console.log(`   Skills (old):         ${OLD_SKILLS || 'No desplegado'}`);
    console.log(`   Marketplace:          ${MARKETPLACE_ADDRESS || 'No configurado'}\n`);

    // ====================================================
    // PASO 1: DESPLEGAR NUEVO SKILLS V5.1.0
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 1/5: Desplegando Skills Module v5.1.0...");
    console.log("   ⚡ Nuevos skill boosts (reducidos 25%):");
    console.log("      • STAKE_BOOST_I:    +3.75% (was +5%)");
    console.log("      • STAKE_BOOST_II:   +7.5% (was +10%)");
    console.log("      • STAKE_BOOST_III:  +15% (was +20%)");
    console.log("      • FEE_REDUCER_I:    -7.5% (was -10%)");
    console.log("      • FEE_REDUCER_II:   -18.75% (was -25%)");
    console.log("      • Badge Skills:     +3.75% each (was +5%)\n");
    console.log("   🛡️ Nuevos caps:");
    console.log("      • Max Staking Boost:  37.5% (was 50%)");
    console.log("      • Max Fee Discount:   56.25% (was 75%)");
    console.log("      • Max Lock Reduction: 37.5% (was 50%)\n");
    
    const SkillsFactory = await ethers.getContractFactory("EnhancedSmartStakingSkills");
    console.log("   ⏳ Enviando transacción...");
    const newSkills = await SkillsFactory.deploy();
    await newSkills.waitForDeployment();
    const newSkillsAddress = await newSkills.getAddress();
    
    console.log("✅ Nuevo Skills deployed:", newSkillsAddress);
    console.log(`   🔗 https://polygonscan.com/address/${newSkillsAddress}\n`);

    // ====================================================
    // PASO 2: CONFIGURAR REFERENCIAS
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 2/5: Configurando referencias...\n");

    console.log("   Configurando Core staking contract...");
    let tx = await newSkills.setCoreStakingContract(CORE_ADDRESS);
    await tx.wait();
    console.log("   ✅ Core contract configurado\n");

    if (MARKETPLACE_ADDRESS) {
        console.log("   Configurando Marketplace contract...");
        tx = await newSkills.setMarketplaceContract(MARKETPLACE_ADDRESS);
        await tx.wait();
        console.log("   ✅ Marketplace configurado\n");
    }

    // ====================================================
    // PASO 3: ACTUALIZAR CORE CONTRACT
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 3/5: Actualizando Core contract...\n");

    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE_ADDRESS);
    
    console.log("   Actualizando referencia a Skills module...");
    tx = await core.setSkillsModule(newSkillsAddress);
    await tx.wait();
    console.log("   ✅ Core actualizado con nuevo Skills module\n");

    // ====================================================
    // PASO 4: ACTUALIZAR REWARDS MODULE
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 PASO 4/5: Actualizando Rewards module...\n");

    const REWARDS_ADDRESS = deploymentData.staking?.rewards;
    if (REWARDS_ADDRESS) {
        const rewards = await ethers.getContractAt("EnhancedSmartStakingRewards", REWARDS_ADDRESS);
        
        console.log("   Actualizando referencia a Skills en Rewards...");
        tx = await rewards.setSkillsModule(newSkillsAddress);
        await tx.wait();
        console.log("   ✅ Rewards actualizado con nuevo Skills module\n");
    } else {
        console.log("   ⚠️  No se encontró Rewards module, saltando...\n");
    }

    // ====================================================
    // PASO 5: VERIFICAR CONFIGURACIÓN
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🔍 PASO 5/5: Verificando configuración...\n");

    const coreConfigured = await newSkills.coreStakingContract();
    const marketplaceConfigured = await newSkills.marketplaceContract();
    const coreSkillsRef = await core.skillsModule();

    console.log("📊 Estado del nuevo Skills module:");
    console.log(`   Core contract:          ${coreConfigured === CORE_ADDRESS ? '✅' : '❌'} ${coreConfigured}`);
    console.log(`   Marketplace contract:   ${marketplaceConfigured === (MARKETPLACE_ADDRESS || ethers.ZeroAddress) ? '✅' : '❌'} ${marketplaceConfigured}`);
    console.log(`   Core apunta a nuevo:    ${coreSkillsRef === newSkillsAddress ? '✅' : '❌'} ${coreSkillsRef}\n`);

    // ====================================================
    // GUARDAR DIRECCIÓN
    // ====================================================
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("💾 Guardando dirección...\n");

    deploymentData.staking.skillsOld = OLD_SKILLS; // Backup
    deploymentData.staking.skills = newSkillsAddress;
    deploymentData.staking.skillsVersion = "5.1.0";
    deploymentData.staking.skillsDeployedAt = new Date().toISOString();

    fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
    console.log("✅ Dirección guardada en polygon-addresses.json\n");

    // ====================================================
    // RESUMEN FINAL
    // ====================================================
    const finalBalance = await ethers.provider.getBalance(deployer.address);
    const gasUsed = initialBalance - finalBalance;
    const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("✨ ACTUALIZACIÓN COMPLETADA\n");
    console.log("📊 Resumen:");
    console.log(`   Contrato:          EnhancedSmartStakingSkills v5.1.0`);
    console.log(`   Nueva dirección:   ${newSkillsAddress}`);
    console.log(`   Dirección antigua: ${OLD_SKILLS || 'N/A'}`);
    console.log(`   Gas usado:         ${ethers.formatEther(gasUsed)} POL`);
    console.log(`   Tiempo:            ${executionTime}s`);
    console.log("\n⚡ Nuevos valores de skills:");
    console.log(`   STAKE_BOOST max:    +37.5% (was +50%)`);
    console.log(`   FEE_DISCOUNT max:   56.25% (was 75%)`);
    console.log(`   LOCK_REDUCTION max: 37.5% (was 50%)`);
    console.log("\n📝 Nota importante:");
    console.log("   Los skills activos de usuarios existentes:");
    console.log("   ✅ Mantienen su estado (activo/inactivo)");
    console.log("   ✅ Pero ahora usan NUEVOS valores reducidos");
    console.log("   ✅ Cambios aplican inmediatamente tras actualización\n");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ ERROR:", error);
        process.exit(1);
    });
