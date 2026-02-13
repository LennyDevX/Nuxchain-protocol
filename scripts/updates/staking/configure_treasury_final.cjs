const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {
  console.log("\n╔════════════════════════════════════════════════════════════════╗");
  console.log("║  🔧 CONFIGURACIÓN FINAL TREASURY MANAGER                     ║");
  console.log("║  Direcciones CORRECTAS a CONTRATOS                           ║");
  console.log("╚════════════════════════════════════════════════════════════════╝\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("👤 Deployer:", deployer.address);

  // Cargar direcciones desde polygon-addresses.json
  const addressesPath = path.join(__dirname, '../../../deployments/polygon-addresses.json');
  
  if (!fs.existsSync(addressesPath)) {
    console.log("❌ ERROR: polygon-addresses.json no encontrado");
    process.exit(1);
  }

  const addresses = JSON.parse(fs.readFileSync(addressesPath, 'utf8'));

  // Direcciones de contratos
  const TREASURY_MANAGER = addresses.treasury?.manager;
  const REWARDS_CONTRACT = addresses.staking?.rewards;
  const CORE_CONTRACT = addresses.staking?.core;
  const COLLABORATOR_CONTRACT = addresses.collaborators?.badgeRewards;
  const DEV_WALLET = deployer.address; // 0xed639e84179FCEcE1d7BEe91ab1C6888fbBdD0cf

  console.log("\n📋 Direcciones a configurar:\n");
  console.log("   TreasuryManager:          ", TREASURY_MANAGER || "❌ NO ENCONTRADO");
  console.log("   Rewards Contract:         ", REWARDS_CONTRACT || "❌ NO ENCONTRADO");
  console.log("   Core Staking:             ", CORE_CONTRACT || "❌ NO ENCONTRADO");
  console.log("   CollaboratorBadgeRewards: ", COLLABORATOR_CONTRACT || "❌ NO ENCONTRADO");
  console.log("   Dev Wallet:               ", DEV_WALLET);

  // Validar que existan todas las direcciones necesarias
  if (!TREASURY_MANAGER || !REWARDS_CONTRACT || !CORE_CONTRACT || !COLLABORATOR_CONTRACT) {
    console.log("\n❌ ERROR: Faltan direcciones necesarias");
    console.log("\nAsegúrate de:");
    console.log("1. Haber desplegado TreasuryManager v2");
    console.log("2. Haber desplegado Rewards v5.1.0");
    console.log("3. Haber desplegado CollaboratorBadgeRewards");
    process.exit(1);
  }

  console.log("\n┌────────────────────────────────────────────────────────────────┐");
  console.log("│ Configuración Propuesta                                        │");
  console.log("└────────────────────────────────────────────────────────────────┘\n");

  const treasuryConfig = {
    rewards: {
      address: REWARDS_CONTRACT,
      description: "Rewards contract (quest rewards, distributions)",
      allocation: "30%"
    },
    staking: {
      address: CORE_CONTRACT,
      description: "Core Staking (liquidity pool)",
      allocation: "35%"
    },
    collaborators: {
      address: COLLABORATOR_CONTRACT,
      description: "CollaboratorBadgeRewards (badge holder passive income)",
      allocation: "20%"
    },
    development: {
      address: DEV_WALLET,
      description: "Dev wallet personal ✅",
      allocation: "15%"
    }
  };

  console.log("📝 DISTRIBUCIÓN DE FONDOS:\n");
  for (const [type, config] of Object.entries(treasuryConfig)) {
    console.log(`   ${type.padEnd(15)} → ${config.address}`);
    console.log(`   ${' '.repeat(18)} ${config.description}`);
    console.log(`   ${' '.repeat(18)} Allocation: ${config.allocation}\n`);
  }

  // Verificar balance
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Balance deployer:", hre.ethers.formatEther(balance), "POL\n");

  if (balance < hre.ethers.parseEther("0.01")) {
    console.log("❌ ERROR: Balance insuficiente");
    process.exit(1);
  }

  console.log("┌────────────────────────────────────────────────────────────────┐");
  console.log("│ Ejecutando Configuración                                       │");
  console.log("└────────────────────────────────────────────────────────────────┘\n");

  const treasuryManager = await hre.ethers.getContractAt("TreasuryManager", TREASURY_MANAGER);
  let totalGasUsed = 0n;

  try {
    // Configurar cada treasury wallet
    for (const [type, config] of Object.entries(treasuryConfig)) {
      console.log(`   Configurando "${type}"...`);
      
      const tx = await treasuryManager.setTreasury(type, config.address);
      const receipt = await tx.wait();
      
      totalGasUsed += receipt.gasUsed;
      
      console.log(`      ✅ OK (gas: ${receipt.gasUsed}, tx: ${receipt.hash.substring(0, 10)}...)\n`);
    }

    console.log("┌────────────────────────────────────────────────────────────────┐");
    console.log("│ Verificación Final                                            │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    console.log("📋 Treasury Wallets Configurados:\n");

    for (const [type, config] of Object.entries(treasuryConfig)) {
      const [configuredAddress, allocationBps] = await treasuryManager.getTreasuryConfig(type);
      const isCorrect = configuredAddress.toLowerCase() === config.address.toLowerCase();
      
      console.log(`   ${type.padEnd(15)} → ${configuredAddress}`);
      console.log(`   ${' '.repeat(18)} ${isCorrect ? '✅' : '❌'} ${config.description}`);
      console.log(`   ${' '.repeat(18)} Allocation: ${config.allocation}\n`);
      
      if (!isCorrect) {
        console.log(`      ⚠️  ADVERTENCIA: Dirección no coincide!`);
        console.log(`      Esperado: ${config.address}`);
        console.log(`      Obtenido: ${configuredAddress}\n`);
      }
    }

    // Verificar allocations
    console.log("📊 Verificando allocations...\n");
    
    const [, allocationRewards] = await treasuryManager.getTreasuryConfig("rewards");
    const [, allocationStaking] = await treasuryManager.getTreasuryConfig("staking");
    const [, allocationCollabs] = await treasuryManager.getTreasuryConfig("collaborators");
    const [, allocationDev] = await treasuryManager.getTreasuryConfig("development");

    console.log(`   rewards:       ${allocationRewards} bps (${Number(allocationRewards)/100}%)`);
    console.log(`   staking:       ${allocationStaking} bps (${Number(allocationStaking)/100}%)`);
    console.log(`   collaborators: ${allocationCollabs} bps (${Number(allocationCollabs)/100}%)`);
    console.log(`   development:   ${allocationDev} bps (${Number(allocationDev)/100}%)`);

    const totalAllocation = Number(allocationRewards) + Number(allocationStaking) + Number(allocationCollabs) + Number(allocationDev);
    console.log(`   TOTAL:         ${totalAllocation} bps (${totalAllocation/100}%)`);

    if (totalAllocation === 10000) {
      console.log("   ✅ Allocations correctas (100%)\n");
    } else {
      console.log("   ⚠️  ADVERTENCIA: Total no es 100%\n");
    }

    // Reserve Fund
    console.log("🛡️  Reserve Fund:\n");
    const [reserveBalance, totalAccumulated, totalWithdrawn, reservePercentage, reserveEnabled] = await treasuryManager.getReserveStats();

    console.log(`   Estado:        ${reserveEnabled ? '✅ Enabled' : '❌ Disabled'}`);
    console.log(`   Acumulación:   ${Number(reservePercentage)/100}%`);
    console.log(`   Balance:       ${hre.ethers.formatEther(reserveBalance)} POL`);
    console.log(`   Total Acum:    ${hre.ethers.formatEther(totalAccumulated)} POL`);
    console.log(`   Total Retirado: ${hre.ethers.formatEther(totalWithdrawn)} POL\n`);

    const finalBalance = await hre.ethers.provider.getBalance(deployer.address);
    const gasSpent = balance - finalBalance;

    console.log("══════════════════════════════════════════════════════════════════════\n");
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║           ✅ CONFIGURACIÓN COMPLETADA                        ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log("📊 FLUJO DE FONDOS CONFIGURADO:\n");
    console.log("   1️⃣  Revenue → TreasuryManager.receiveRevenue()");
    console.log("   2️⃣  Auto-acumula 10% → Reserve Fund");
    console.log("   3️⃣  Distribuye automáticamente:");
    console.log("      • 30% → Rewards Contract (quest rewards)");
    console.log("      • 35% → Core Staking (liquidity pool)");
    console.log("      • 20% → CollaboratorBadgeRewards (passive income)");
    console.log("      • 15% → Dev wallet\n");

    console.log("💾 Gas gastado:", hre.ethers.formatEther(gasSpent), "POL");
    console.log("💼 Balance final:", hre.ethers.formatEther(finalBalance), "POL\n");

    console.log("┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ 📝 SIGUIENTE PASO                                                   │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    console.log("Conectar IndividualSkillsMarketplace al Treasury:");
    console.log("npx hardhat run scripts/updates/marketplace/fix_individual_skills_treasury.cjs --network polygon\n");

    console.log("══════════════════════════════════════════════════════════════════════\n");

  } catch (error) {
    console.error("\n❌ ERROR durante configuración:", error.message);
    if (error.data) {
      console.error("   Data:", error.data);
    }
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
