const { ethers } = require("hardhat");

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  ⚙️ Configurando Treasury Wallets                            ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await ethers.getSigners();
    const deployerAddress = deployer.address;

    console.log("📋 Direcciones:");
    console.log(`   Deployer/Signer: ${deployerAddress}\n`);

    const TM_ADDRESS = "0x8f3554Fca1Bd1b79bBf531706FA2C67fEcC5401F";
    const MP_ADDRESS = "0xB23257758B385444dF5A78aC2F315bd653470df3";

    // ====================================================
    // PASO 1: Configurar Individual Skills Marketplace
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 1: Configurar TreasuryManager en IndividualSkillsMP      │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    try {
        const mp = await ethers.getContractAt("IndividualSkillsMarketplace", MP_ADDRESS);
        
        console.log("📝 Ejecutando setTreasuryManager()...");
        const tx1 = await mp.setTreasuryManager(TM_ADDRESS);
        console.log(`   TxHash: ${tx1.hash}`);
        
        const receipt1 = await tx1.wait();
        console.log(`   ✅ Completado (gas: ${receipt1.gasUsed})\n`);
    } catch (err) {
        console.warn(`   ⚠️  Error: ${err.message}\n`);
    }

    // ====================================================
    // PASO 2: Configurar Treasury Wallets
    // ====================================================
    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 2: Configurar Treasury Wallets en TreasuryManager        │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const tm = await ethers.getContractAt("TreasuryManager", TM_ADDRESS);

    // Usar deployer como wallet para todos (puede ser cambiado después)
    const walletAddress = deployerAddress;

    console.log(`📝 Configurando treasuries apuntando a: ${walletAddress}\n`);

    const treasuryTypes = ["rewards", "staking", "collaborators", "development"];
    
    for (const treasuryType of treasuryTypes) {
        try {
            console.log(`   Configurando "${treasuryType}"...`);
            const tx = await tm.setTreasury(treasuryType, walletAddress);
            console.log(`      ⏳ Tx: ${tx.hash}`);
            
            const receipt = await tx.wait();
            console.log(`      ✅ OK (gas: ${receipt.gasUsed})`);
        } catch (err) {
            console.error(`      ❌ Error: ${err.message}`);
        }
    }

    // ====================================================
    // PASO 3: Verificar
    // ====================================================
    console.log("\n┌────────────────────────────────────────────────────────────────┐");
    console.log("│ PASO 3: Verificando Configuración                            │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    console.log("📋 Treasury Wallets Configurados:\n");
    
    for (const treasuryType of treasuryTypes) {
        const address = await tm.treasuries(treasuryType);
        const allocation = await tm.allocations(treasuryType);
        console.log(`   ${treasuryType.padEnd(15)} → ${address} (${Number(allocation)/100}%)`);
    }

    console.log("\n" + "═".repeat(70));
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║              ✅ CONFIGURACIÓN COMPLETADA                     ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log("📝 IMPORTANTE:\n");
    console.log("Todos los treasuries apuntan actualmente a:");
    console.log(`   ${walletAddress}\n`);

    console.log("Si quieres cambiar a wallets diferentes, ejecuta en hardhat console:\n");
    console.log("   const tm = await ethers.getContractAt('TreasuryManager', '0x8f3554...');");
    console.log("   await tm.setTreasury('rewards', '0x<NEW_ADDRESS>');");
    console.log("   // Repite para 'staking', 'collaborators', 'development'\n");

    console.log("═".repeat(70) + "\n");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ ERROR:", error.message);
        process.exit(1);
    });
