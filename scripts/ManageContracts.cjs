const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("\n╔════════════════════════════════════════════════════════════════╗");
  console.log("║  🔧 GESTOR DE CONTRATOS - Configuración y Verificación      ║");
  console.log("╚════════════════════════════════════════════════════════════════╝\n");

  const args = process.argv.slice(2);
  const command = args[0] || "verify";

  const [deployer] = await ethers.getSigners();
  const network = (await ethers.provider.getNetwork()).name;
  const deploymentFile = path.join(__dirname, "..", "deployments", `${network}-deployment.json`);

  if (!fs.existsSync(deploymentFile)) {
    throw new Error(`❌ No se encontró deployment para ${network}`);
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
  const stakingAddress = deployment.contracts.EnhancedSmartStaking.address;
  const marketplaceAddress = deployment.contracts.GameifiedMarketplace.address;

  const staking = await ethers.getContractAt("EnhancedSmartStaking", stakingAddress);
  const marketplace = await ethers.getContractAt("GameifiedMarketplace", marketplaceAddress);

  switch (command) {
    case "verify":
      await verifyDeployment(staking, marketplace, stakingAddress, marketplaceAddress, deployment, deployer);
      break;

    case "configure":
      await configureMarketplace(staking, marketplaceAddress, network);
      break;

    case "check-tx":
      await checkTransactionStatus(deployer, network);
      break;

    case "fund-staking":
      console.log("📝 Para fondear staking:");
      console.log(`   npx hardhat run scripts/FundSmartStaking.cjs --network ${network}`);
      break;

    case "help":
      showHelp();
      break;

    default:
      console.log(`❌ Comando desconocido: ${command}`);
      showHelp();
  }
}

async function verifyDeployment(staking, marketplace, stakingAddress, marketplaceAddress, deployment, deployer) {
  console.log("🔍 Verificando deployment...\n");

  console.log("🏦 EnhancedSmartStaking:");
  try {
    const owner = await staking.owner();
    const treasury = await staking.treasury();
    const marketplaceContract = await staking.marketplaceContract();

    console.log(`   ✅ Owner: ${owner}`);
    console.log(`   ✅ Treasury: ${treasury}`);
    console.log(`   ✅ Marketplace: ${marketplaceContract}`);
    console.log(`   ✅ Paused: ${await staking.paused()}`);
    console.log(`   ℹ️  MIN_DEPOSIT: 10 ETH`);
    console.log(`   ℹ️  MAX_DEPOSIT: 10000 ETH\n`);
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}\n`);
  }

  console.log("🎮 GameifiedMarketplace:");
  try {
    const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
    const hasAdminRole = await marketplace.hasRole(ADMIN_ROLE, deployer.address);

    console.log(`   ✅ Admin: ${hasAdminRole ? 'Sí' : 'No'}`);
    console.log(`   ✅ POL Token: ${await marketplace.polTokenAddress()}`);
    console.log(`   ✅ Staking: ${await marketplace.stakingContractAddress()}`);
    console.log(`   ✅ Treasury: ${await marketplace.stakingTreasuryAddress()}`);
    console.log(`   ✅ Paused: ${await marketplace.paused()}\n`);
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}\n`);
  }

  console.log("🔗 Verificación de Interconexión:");
  const stakingMarketplace = await staking.marketplaceContract();
  const marketplaceStaking = await marketplace.stakingContractAddress();

  if (stakingMarketplace.toLowerCase() === marketplaceAddress.toLowerCase() &&
      marketplaceStaking.toLowerCase() === stakingAddress.toLowerCase()) {
    console.log(`   ✅ Ambos contratos correctamente interconectados\n`);
  } else {
    console.log(`   ⚠️  Advertencia: Las direcciones no coinciden\n`);
  }

  console.log("📍 Enlaces:");
  console.log(`   Staking: https://polygonscan.com/address/${stakingAddress}`);
  console.log(`   Marketplace: https://polygonscan.com/address/${marketplaceAddress}\n`);
}

async function configureMarketplace(staking, marketplaceAddress, network) {
  console.log("⚙️  Configurando Marketplace en Staking...\n");

  const [deployer] = await ethers.getSigners();
  const feeData = await ethers.provider.getFeeData();
  const maxFeePerGas = (feeData.maxFeePerGas * BigInt(150)) / BigInt(100);
  const maxPriorityFeePerGas = (feeData.maxPriorityFeePerGas * BigInt(200)) / BigInt(100);

  const currentMarketplace = await staking.marketplaceContract();

  if (currentMarketplace.toLowerCase() === marketplaceAddress.toLowerCase()) {
    console.log(`✅ Ya está configurado correctamente\n`);
    return;
  }

  console.log(`🚀 Enviando transacción con gas prioritario...`);

  const nonce = await ethers.provider.getTransactionCount(deployer.address, "latest");
  const tx = await staking.setMarketplaceAddress(marketplaceAddress, {
    maxFeePerGas,
    maxPriorityFeePerGas,
    nonce,
    gasLimit: 100000
  });

  console.log(`📤 TX Hash: ${tx.hash}`);
  console.log(`🔍 Polygonscan: https://polygonscan.com/tx/${tx.hash}`);
  console.log(`⏳ Esperando confirmación...\n`);

  try {
    const receipt = await Promise.race([
      tx.wait(),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error("Timeout 30s")), 30000)
      )
    ]);

    if (receipt.status === 1) {
      console.log(`✅ ¡Transacción confirmada!\n`);
    }
  } catch (error) {
    if (error.message.includes("Timeout")) {
      console.log(`⏰ Timeout - La transacción puede confirmar en los próximos minutos\n`);
    } else {
      console.error(`❌ Error: ${error.message}\n`);
    }
  }
}

async function checkTransactionStatus(deployer, network) {
  console.log("📊 Estado de transacciones:\n");

  const nonce = await ethers.provider.getTransactionCount(deployer.address, "latest");
  const pendingNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");

  console.log(`📍 Red: ${network} (Chain ID: 137)`);
  console.log(`💰 Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH\n`);

  console.log(`Nonce confirmado: ${nonce}`);
  console.log(`Nonce pendiente: ${pendingNonce}`);
  console.log(`Transacciones pendientes: ${pendingNonce - nonce}\n`);

  const feeData = await ethers.provider.getFeeData();
  console.log(`⛽ Gas actual:`);
  console.log(`   Gas Price: ${ethers.formatUnits(feeData.gasPrice, "gwei")} Gwei`);
  console.log(`   Max Fee: ${ethers.formatUnits(feeData.maxFeePerGas, "gwei")} Gwei\n`);
}

function showHelp() {
  console.log("Comandos disponibles:\n");
  console.log("  verify      - Verificar el estado del deployment (default)");
  console.log("  configure   - Configurar Marketplace en Staking");
  console.log("  check-tx    - Ver estado de transacciones pendientes");
  console.log("  fund-staking - Información para fondear staking");
  console.log("  help        - Mostrar este mensaje\n");
  console.log("Ejemplos:");
  console.log("  npx hardhat run scripts/ManageContracts.cjs --network polygon");
  console.log("  npx hardhat run scripts/ManageContracts.cjs --network polygon -- configure");
  console.log("  npx hardhat run scripts/ManageContracts.cjs --network polygon -- check-tx\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Error:", error.message);
    process.exit(1);
  });
