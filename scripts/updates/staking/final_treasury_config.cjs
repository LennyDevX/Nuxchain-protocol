const { ethers } = require("hardhat");

/**
 * 🎯 CONFIGURACIÓN FINAL - TREASURY WALLETS CORRECTOS
 * 
 * Configura TreasuryManager para distribuir a:
 * - rewards (30%) → GameifiedMarketplaceQuests (quest rewards)
 * - staking (35%) → Core Staking (liquidity pool)
 * - collaborators (20%) → GameifiedMarketplaceProxy (colaboradores, temporalmente)
 * - development (15%) → Wallet personal del dev
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🎯 CONFIGURACIÓN FINAL - TREASURY → CONTRATOS               ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await ethers.getSigners();
    
    // ====================================================
    // DIRECCIONES
    // ====================================================
    const TM_ADDRESS = "0x8f3554Fca1Bd1b79bBf531706FA2C67fEcC5401F";
    const DEV_WALLET = "0xed639e84179FCEcE1d7BEe91ab1C6888fbBdD0cf";
    
    // Contratos que recibirán distribución
    const CORE_STAKING = "0xC67F0a0cB719e4f4358D980a5D966878Fd6f3946";
    const QUESTS_CONTRACT = "0x61D75d56559Cd4722870A797a17793ed9f840245"; // GameifiedMarketplaceQuests
    const MARKETPLACE_PROXY = "0xd502fB2Eb3d345EE9A5A0286A472B38c77Fda6d5"; // Para collaborators (temporal)
    
    console.log("👤 Deployer:", deployer.address);
    console.log("💼 Dev Wallet:", DEV_WALLET);
    console.log("\n📋 Direcciones de contratos:");
    console.log(`   TreasuryManager:         ${TM_ADDRESS}`);
    console.log(`   Core Staking:            ${CORE_STAKING}`);
    console.log(`   Quests (rewards):        ${QUESTS_CONTRACT}`);
    console.log(`   Marketplace (collab):    ${MARKETPLACE_PROXY}\n`);

    // ====================================================
    // CONFIGURACIÓN
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ Configurando Treasury Distribution                            │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const tm = await ethers.getContractAt("TreasuryManager", TM_ADDRESS);

    const treasuryConfig = [
        {
            type: "rewards",
            address: QUESTS_CONTRACT,
            allocation: "30%",
            description: "GameifiedMarketplaceQuests (quest rewards pool)"
        },
        {
            type: "staking",
            address: CORE_STAKING,
            allocation: "35%",
            description: "Core Staking (liquidity pool para rewards)"
        },
        {
            type: "collaborators",
            address: MARKETPLACE_PROXY,
            allocation: "20%",
            description: "Marketplace Proxy (temporalmente hasta deploy CollaboratorBadgeRewards)"
        },
        {
            type: "development",
            address: DEV_WALLET,
            allocation: "15%",
            description: "Dev Wallet (uso personal) ✅"
        }
    ];

    console.log("📝 Configuración a aplicar:\n");
    for (const config of treasuryConfig) {
        console.log(`   ${config.type.padEnd(15)} (${config.allocation})`);
        console.log(`   → ${config.address}`);
        console.log(`   ${config.description}\n`);
    }

    console.log("⏳ Ejecutando transacciones...\n");

    for (const config of treasuryConfig) {
        try {
            console.log(`   Configurando "${config.type}"...`);
            const tx = await tm.setTreasury(config.type, config.address);
            const receipt = await tx.wait();
            console.log(`      ✅ OK (gas: ${receipt.gasUsed})`);
            console.log(`      📝 Tx: ${tx.hash}\n`);
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

    console.log("📋 Treasury Wallets Confirmados:\n");
    
    for (const config of treasuryConfig) {
        const address = await tm.treasuries(config.type);
        const allocation = await tm.allocations(config.type);
        
        const isCorrect = address.toLowerCase() === config.address.toLowerCase();
        const icon = isCorrect ? "✅" : "❌";
        
        console.log(`   ${icon} ${config.type.padEnd(15)} → ${address}`);
        console.log(`      Allocation: ${Number(allocation)/100}%`);
        console.log(`      Expected:   ${config.address}\n`);
    }

    console.log("═".repeat(70));
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║           ✅ CONFIGURACIÓN COMPLETADA                        ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log("📊 FLUJO DE DISTRIBUCIÓN:\n");
    console.log("   Revenue → TreasuryManager.receiveRevenue()");
    console.log("      ↓");
    console.log("   Auto-distribución:");
    console.log("      • 10% → Reserve Fund (emergency buffer)");
    console.log("      • 30% → GameifiedMarketplaceQuests (quest rewards)");
    console.log("      • 35% → Core Staking (liquidity pool)");
    console.log("      • 20% → Marketplace Proxy (colaboradores)");
    console.log("      • 15% → Dev Wallet (0xed639...)\n");

    console.log("📝 IMPORTANTE:\n");
    console.log("   Cuando despliegues CollaboratorBadgeRewards:");
    console.log("   > await tm.setTreasury('collaborators', COLLAB_BADGE_REWARDS_ADDRESS);\n");

    console.log("═".repeat(70) + "\n");
}

main()
    .catch((error) => {
        console.error("\n❌ ERROR:", error.message);
        process.exit(1);
    });
