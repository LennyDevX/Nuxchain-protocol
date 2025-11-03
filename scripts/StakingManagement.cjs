const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
  console.log("\n╔════════════════════════════════════════════════════════════════╗");
  console.log("║  💰 STAKING MANAGEMENT - Fondear, Pausar y Retirar Fondos   ║");
  console.log("╚════════════════════════════════════════════════════════════════╝\n");

  const args = process.argv.slice(2);
  const command = args[0] || "help";

  const [deployer] = await ethers.getSigners();
  const network = (await ethers.provider.getNetwork()).name;
  const deploymentFile = path.join(__dirname, "..", "deployments", `${network}-deployment.json`);

  if (!fs.existsSync(deploymentFile)) {
    throw new Error(`❌ No se encontró deployment para ${network}`);
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
  const stakingAddress = deployment.contracts.EnhancedSmartStaking.address;
  const staking = await ethers.getContractAt("EnhancedSmartStaking", stakingAddress);

  switch (command) {
    case "fund":
      await fundStaking(staking, deployer, args[1]);
      break;

    case "unpause":
      await unpauseStaking(staking, deployer);
      break;

    case "withdraw":
      await withdrawFromStaking(staking, deployer, args[1]);
      break;

    case "status":
      await checkStakingStatus(staking, deployer);
      break;

    case "help":
    default:
      showHelp();
  }
}

async function fundStaking(staking, deployer, amount) {
  console.log("💰 Fondeando Staking...\n");

  if (!amount) {
    console.log("❌ Debes especificar la cantidad de ETH a fondear");
    console.log("Ejemplo: npx hardhat run scripts/StakingManagement.cjs --network polygon -- fund 10\n");
    return;
  }

  const fundAmount = ethers.parseEther(amount);
  console.log(`👤 Deployer: ${deployer.address}`);
  console.log(`💸 Cantidad: ${amount} ETH`);
  console.log(`📍 Staking: ${await staking.getAddress()}\n`);

  console.log("🚀 Enviando fondos...");

  try {
    const tx = await deployer.sendTransaction({
      to: await staking.getAddress(),
      value: fundAmount
    });

    console.log(`📤 TX: ${tx.hash}`);
    console.log(`⏳ Esperando confirmación...`);

    const receipt = await tx.wait();
    console.log(`✅ ¡Fondeo completado!`);
    console.log(`   Bloque: ${receipt.blockNumber}`);
    console.log(`   Gas usado: ${receipt.gasUsed.toString()}\n`);
  } catch (error) {
    console.error(`❌ Error: ${error.message}\n`);
  }
}

async function unpauseStaking(staking, deployer) {
  console.log("🚀 Reanudando Staking...\n");

  const isPaused = await staking.paused();
  console.log(`Estado actual: ${isPaused ? '⏸️  Pausado' : '▶️  En ejecución'}`);

  if (!isPaused) {
    console.log("✅ Staking ya está activo\n");
    return;
  }

  try {
    const tx = await staking.unpause();
    console.log(`📤 TX: ${tx.hash}`);
    console.log(`⏳ Esperando confirmación...`);

    const receipt = await tx.wait();
    console.log(`✅ ¡Staking reanudado!`);
    console.log(`   Bloque: ${receipt.blockNumber}\n`);
  } catch (error) {
    console.error(`❌ Error: ${error.message}\n`);
  }
}

async function withdrawFromStaking(staking, deployer, amount) {
  console.log("💸 Retirando fondos del Staking...\n");

  if (!amount) {
    console.log("❌ Debes especificar la cantidad de ETH a retirar");
    console.log("Ejemplo: npx hardhat run scripts/StakingManagement.cjs --network polygon -- withdraw 5\n");
    return;
  }

  const withdrawAmount = ethers.parseEther(amount);
  console.log(`👤 Usuario: ${deployer.address}`);
  console.log(`💸 Cantidad: ${amount} ETH\n`);

  try {
    // Verificar balance del usuario en staking
    const userInfo = await staking.getUserInfo(deployer.address);
    const balance = userInfo.totalDeposited;

    console.log(`📊 Tu deposito: ${ethers.formatEther(balance)} ETH`);

    if (balance < withdrawAmount) {
      console.log(`❌ No tienes suficientes fondos (necesitas ${ethers.formatEther(withdrawAmount)} ETH)\n`);
      return;
    }

    console.log(`🚀 Procesando retiro...`);

    const tx = await staking.withdraw(withdrawAmount);
    console.log(`📤 TX: ${tx.hash}`);
    console.log(`⏳ Esperando confirmación...`);

    const receipt = await tx.wait();
    console.log(`✅ ¡Retiro completado!`);
    console.log(`   Bloque: ${receipt.blockNumber}`);
    console.log(`   Gas usado: ${receipt.gasUsed.toString()}\n`);
  } catch (error) {
    console.error(`❌ Error: ${error.message}\n`);
  }
}

async function checkStakingStatus(staking, deployer) {
  console.log("📊 Estado del Staking:\n");

  try {
    const isPaused = await staking.paused();
    const userInfo = await staking.getUserInfo(deployer.address);
    const rewards = await staking.calculateRewards(deployer.address);

    console.log(`Estado: ${isPaused ? '⏸️  Pausado' : '▶️  En ejecución'}`);
    console.log(`\n👤 Tu información:`);
    console.log(`   Deposito: ${ethers.formatEther(userInfo.totalDeposited)} ETH`);
    console.log(`   Recompensas: ${ethers.formatEther(userInfo.rewards)} ETH`);
    console.log(`   Recompensas acumuladas: ${ethers.formatEther(rewards)} ETH\n`);
  } catch (error) {
    console.error(`❌ Error: ${error.message}\n`);
  }
}

function showHelp() {
  console.log("Comandos disponibles:\n");
  console.log("  fund <amount>     - Fondear staking con ETH");
  console.log("  unpause           - Reanudar staking");
  console.log("  withdraw <amount> - Retirar fondos del staking");
  console.log("  status            - Ver estado del staking");
  console.log("  help              - Mostrar este mensaje\n");
  console.log("Ejemplos:");
  console.log("  npx hardhat run scripts/StakingManagement.cjs --network polygon -- fund 100");
  console.log("  npx hardhat run scripts/StakingManagement.cjs --network polygon -- unpause");
  console.log("  npx hardhat run scripts/StakingManagement.cjs --network polygon -- withdraw 50");
  console.log("  npx hardhat run scripts/StakingManagement.cjs --network polygon -- status\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Error:", error.message);
    process.exit(1);
  });
