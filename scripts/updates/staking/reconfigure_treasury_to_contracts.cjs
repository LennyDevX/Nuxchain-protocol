const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 🔧 RECONFIGURAR TREASURY WALLETS
 * 
 * Configura treasuries para apuntar a CONTRATOS, no a wallets personales:
 * - rewards → CollaboratorBadgeRewards (recibe con depositFromTreasury)
 * - staking → Core Staking (mantiene pool de liquidez)
 * - collaborators → CollaboratorBadgeRewards (quest rewards)
 * - development → Wallet personal del dev ✅
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🔧 RECONFIGURAR TREASURY PARA CONTRATOS                     ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await ethers.getSigners();
    console.log("👤 Deployer:", deployer.address);

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
    
    const TM_ADDRESS = deploymentData.treasury?.manager;
    const CORE_ADDRESS = deploymentData.staking?.core;
    const COLLABORATOR_BADGE_REWARDS = deploymentData.collaborators?.badgeRewards;

    console.log("\n📋 Direcciones actuales:");
    console.log(`   TreasuryManager:          ${TM_ADDRESS}`);
    console.log(`   Core Staking:             ${CORE_ADDRESS}`);
    console.log(`   CollaboratorBadgeRewards: ${COLLABORATOR_BADGE_REWARDS || '❌ NO ENCONTRADO'}\n`);

    if (!TM_ADDRESS || !CORE_ADDRESS) {
        console.error("❌ Faltan direcciones críticas");
        process.exit(1);
    }

    // ====================================================
    // VERIFICAR SI EXISTE COLLABORATOR BADGE REWARDS
    // ====================================================
    let collaboratorAddress = COLLABORATOR_BADGE_REWARDS;

    if (!collaboratorAddress) {
        console.log("⚠️  CollaboratorBadgeRewards no encontrado en polygon-addresses.json\n");
        console.log("🔍 Buscando en direcciones conocidas...\n");
        
        // Intenta encontrar el proxy del marketplace que podría tener los rewards
        const MARKETPLACE_PROXY = deploymentData.marketplace?.proxy;
        
        if (MARKETPLACE_PROXY) {
            console.log(`   Verificando si ${MARKETPLACE_PROXY} es CollaboratorBadgeRewards...\n`);
            try {
                const contract = await ethers.getContractAt("CollaboratorBadgeRewards", MARKETPLACE_PROXY);
                const testCall = await contract.totalBadgeHolders();
                collaboratorAddress = MARKETPLACE_PROXY;
                console.log(`   ✅ Encontrado! Es CollaboratorBadgeRewards\n`);
            } catch (err) {
                console.log(`   ❌ No es CollaboratorBadgeRewards\n`);
            }
        }
        
        if (!collaboratorAddress) {
            console.error("❌ ERROR: No se pudo encontrar CollaboratorBadgeRewards");
            console.error("\n📝 OPCIONES:");
            console.error("   1. Desplegar CollaboratorBadgeRewards primero");
            console.error("   2. Proporcionar la dirección manualmente\n");
            
            console.log("⏭️  Continuando solo con staking y development...\n");
        }
    }

    // ====================================================
    // CONFIGURAR TREASURIES
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ Configurando Treasury Addresses                               │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const tm = await ethers.getContractAt("TreasuryManager", TM_ADDRESS);

    const treasuryConfig = [
        {
            type: "rewards",
            address: collaboratorAddress || deployer.address,
            description: collaboratorAddress 
                ? "CollaboratorBadgeRewards (quest rewards + passive income)"
                : "⚠️  Wallet temporal (deploy CollaboratorBadgeRewards ASAP)"
        },
        {
            type: "staking",
            address: CORE_ADDRESS,
            description: "Core Staking (liquidez pool para rewards)"
        },
        {
            type: "collaborators",
            address: collaboratorAddress || deployer.address,
            description: collaboratorAddress
                ? "CollaboratorBadgeRewards (distribución badge holders)"
                : "⚠️  Wallet temporal (deploy CollaboratorBadgeRewards ASAP)"
        },
        {
            type: "development",
            address: deployer.address,
            description: "Dev wallet personal ✅"
        }
    ];

    console.log("📝 Configuración propuesta:\n");
    for (const config of treasuryConfig) {
        console.log(`   ${config.type.padEnd(15)} → ${config.address}`);
        console.log(`   ${"".padEnd(18)} ${config.description}\n`);
    }

    console.log("⏳ Ejecutando configuración...\n");

    for (const config of treasuryConfig) {
        try {
            console.log(`   Configurando "${config.type}"...`);
            const tx = await tm.setTreasury(config.type, config.address);
            const receipt = await tx.wait();
            console.log(`      ✅ OK (gas: ${receipt.gasUsed}, tx: ${tx.hash.slice(0, 10)}...)\n`);
        } catch (err) {
            console.error(`      ❌ Error: ${err.message}\n`);
        }
    }

    // ====================================================
    // VERIFICACIÓN
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ Verificación Final                                            │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    console.log("📋 Treasury Wallets Configurados:\n");
    
    for (const config of treasuryConfig) {
        const address = await tm.treasuries(config.type);
        const allocation = await tm.allocations(config.type);
        console.log(`   ${config.type.padEnd(15)} → ${address}`);
        console.log(`   ${"".padEnd(18)} Allocation: ${Number(allocation)/100}%\n`);
    }

    // ====================================================
    // GUARDAR CONFIGURACIÓN
    // ====================================================
    if (collaboratorAddress && !deploymentData.collaborators) {
        deploymentData.collaborators = {
            badgeRewards: collaboratorAddress
        };
        fs.writeFileSync(addressesFile, JSON.stringify(deploymentData, null, 2));
        console.log("✅ Direcciones actualizadas en polygon-addresses.json\n");
    }

    console.log("═".repeat(70));
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║           ✅ RECONFIGURACIÓN COMPLETADA                      ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log("📊 FLUJO DE FONDOS:\n");
    console.log("   1️⃣  Revenue → TreasuryManager.receiveRevenue()");
    console.log("   2️⃣  Auto-acumula 10% → Reserve Fund");
    console.log("   3️⃣  Distribuye automáticamente:");
    console.log("      • 30% → CollaboratorBadgeRewards (quests)");
    console.log("      • 35% → Core Staking (liquidity pool)");
    console.log("      • 20% → CollaboratorBadgeRewards (passive income)");
    console.log("      • 15% → Dev wallet\n");

    if (!collaboratorAddress) {
        console.log("⚠️  ADVERTENCIA:\n");
        console.log("   CollaboratorBadgeRewards NO desplegado");
        console.log("   Fondos van temporalmente a wallet del deployer");
        console.log("   Despliega CollaboratorBadgeRewards y reconfigura ASAP\n");
    }

    console.log("═".repeat(70) + "\n");
}

main()
    .catch((error) => {
        console.error("\n❌ ERROR:", error.message);
        process.exit(1);
    });
