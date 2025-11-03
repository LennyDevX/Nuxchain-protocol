const { ethers, network, run } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log(`\n🚀 Desplegando EnhancedSmartStaking en la red ${network.name}...`);

  // Obtenemos la wallet que hará el despliegue
  const [deployer] = await ethers.getSigners();
  const deployerBalance = await ethers.provider.getBalance(deployer.address);

  console.log(
    `\n👤 Cuenta de despliegue: ${deployer.address}` +
    `\n💰 Balance: ${ethers.formatEther(deployerBalance)} ETH`
  );

  // Dirección del treasury - dirección específica para recibir comisiones
  const treasuryAddress = "0xad14c117b51735c072d42571e30bf2c729cd9593";
  console.log(`\n💼 Treasury address: ${treasuryAddress}`);

  // Compilamos el contrato para asegurarnos que está actualizado
  await run("compile");
  console.log("✅ Compilación completada\n");

  // Desplegamos el contrato
  console.log("📝 Desplegando EnhancedSmartStaking...");
  const EnhancedSmartStaking = await ethers.getContractFactory("EnhancedSmartStaking");
  
  // Obtener precio de gas optimizado
  console.log("⛽ Obteniendo precio de gas actual...");
  const feeData = await ethers.provider.getFeeData();
  console.log(`   Gas recomendado: ${ethers.formatUnits(feeData.maxFeePerGas, "gwei")} Gwei`);
  
  // Usar buffer del 20%
  const maxFeePerGas = (feeData.maxFeePerGas * BigInt(120)) / BigInt(100);
  const maxPriorityFeePerGas = (feeData.maxPriorityFeePerGas * BigInt(120)) / BigInt(100);
  
  console.log(`   Usando: ${ethers.formatUnits(maxFeePerGas, "gwei")} Gwei (+20% buffer)`);
  
  // Estimar costo antes de desplegar
  try {
    const deployTx = EnhancedSmartStaking.getDeployTransaction(treasuryAddress);
    const gasEstimate = await ethers.provider.estimateGas({ data: deployTx.data });
    const estimatedCost = (gasEstimate * maxFeePerGas) / BigInt(10**18);
    console.log(`   💵 Costo estimado: ~${ethers.formatEther(estimatedCost)} ETH`);
    console.log(`   📦 Gas estimado: ${gasEstimate.toString()} units\n`);
  } catch (e) {
    console.warn("⚠️  No se pudo estimar gas\n");
  }
  
  const smartStaking = await EnhancedSmartStaking.deploy(treasuryAddress, {
    maxFeePerGas,
    maxPriorityFeePerGas
  });

  const txHash = smartStaking.deploymentTransaction().hash;
  console.log(`📤 TX enviada: ${txHash}`);
  console.log(`🔍 Polygonscan: https://polygonscan.com/tx/${txHash}`);
  console.log("⏳ Esperando confirmación...\n");

  await smartStaking.waitForDeployment();
  const contractAddress = await smartStaking.getAddress();
  
  // Obtener información del receipt
  const receipt = await smartStaking.deploymentTransaction().wait();
  const gasUsed = receipt.gasUsed;
  const gasPrice = receipt.gasPrice || receipt.effectiveGasPrice;
  const totalCost = gasUsed * gasPrice;

  console.log(`✅ Contrato EnhancedSmartStaking desplegado en: ${contractAddress}`);
  console.log(`⛽ Gas usado: ${gasUsed.toString()} units`);
  console.log(`💵 Costo real: ${ethers.formatEther(totalCost)} ETH\n`);

  // Verificar inicialización
  console.log("📊 Verificando inicialización del contrato...");
  const owner = await smartStaking.owner();
  const treasury = await smartStaking.treasury();
  
  console.log(`   Owner: ${owner}`);
  console.log(`   Treasury: ${treasury}`);
  console.log(`   MIN_DEPOSIT: 10 ETH`);
  console.log(`   MAX_DEPOSIT: 10000 ETH\n`);

  // Esperamos unos bloques para asegurarnos que la transacción está confirmada
  console.log("⏳ Esperando confirmaciones adicionales...");
  await new Promise(resolve => setTimeout(resolve, 20000)); // 20 segundos

  // Verificamos el contrato en Polygonscan si no estamos en localhost
  if (network.name !== "localhost" && network.name !== "hardhat") {
    const fullyQualifiedName = "contracts/SmartStaking/EnhancedSmartStaking.sol:EnhancedSmartStaking";
    try {
      console.log("\n🔍 Verificando contrato en Polygonscan...");
      await verifyContract(contractAddress, fullyQualifiedName, [treasuryAddress]);
      console.log("✅ ¡Contrato verificado en Polygonscan!");
    } catch (error) {
      console.log("⚠️  Error durante la verificación automática:", error && error.message ? error.message : error);
      console.log("\n💡 Puedes verificar manualmente:");
      console.log(`   1. Ve a: https://polygonscan.com/address/${contractAddress}#code`);
      console.log(`   2. Click en "Verify and Publish"`);
      console.log(`   3. Constructor Arguments: ${treasuryAddress}`);
    }
  }

  // Guardamos la dirección del contrato en el archivo de despliegue
  saveContractAddress(network.name, contractAddress, "EnhancedSmartStaking");

  console.log("\n🎉 Despliegue completado exitosamente!");
  console.log(`\n📋 Resumen:`);
  console.log(`   Contrato: ${contractAddress}`);
  console.log(`   Red: ${network.name} (Chain ID: ${network.config.chainId})`);
  console.log(`   Treasury: ${treasuryAddress}`);
  console.log(`   Polygonscan: https://polygonscan.com/address/${contractAddress}\n`);

  return contractAddress;
}

function saveContractAddress(networkName, contractAddress, contractName) {
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }

  const filePath = path.join(deploymentsDir, `${networkName}-deployment.json`);
  let deployments = {};

  if (fs.existsSync(filePath)) {
    const fileContent = fs.readFileSync(filePath, "utf8");
    deployments = JSON.parse(fileContent);
  }

  // Asegurar que existe la estructura de contratos
  if (!deployments.contracts) {
    deployments.contracts = {};
  }

  // Actualizar el contrato específico
  deployments.contracts[contractName] = {
    address: contractAddress,
    deployedAt: new Date().toISOString(),
    network: networkName
  };

  fs.writeFileSync(
    filePath,
    JSON.stringify(deployments, null, 2)
  );

  console.log(`💾 Dirección guardada en ${filePath}`);
}

// Verifica un contrato en el explorador usando hardhat-etherscan plugin con reintentos
async function verifyContract(address, fullyQualifiedName, constructorArgs = [], maxAttempts = 3, delayMs = 7000) {
  let attempt = 0;
  while (attempt < maxAttempts) {
    try {
      attempt++;
      await run("verify:verify", {
        address: address,
        constructorArguments: constructorArgs,
        contract: fullyQualifiedName
      });
      return true;
    } catch (err) {
      const msg = err && err.message ? err.message : String(err);
      if (msg.toLowerCase().includes("already verified") || msg.toLowerCase().includes("reason: already verified")) {
        console.log("ℹ️ Contrato ya verificado anteriormente.");
        return true;
      }

      attempt < maxAttempts
        ? console.log(`❗ Intento ${attempt} fallido: ${msg}. Reintentando en ${delayMs / 1000}s...`)
        : console.log(`❌ Intento ${attempt} fallido: ${msg}. No quedan reintentos.`);

      if (attempt >= maxAttempts) throw err;

      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
}

// Ejecutamos la función principal
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Error en el despliegue:", error);
    process.exit(1);
  });
