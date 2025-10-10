const { ethers, network, run } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log(`Desplegando SmartStaking en la red ${network.name}...`);

  // Obtenemos la wallet que hará el despliegue
  const [deployer] = await ethers.getSigners();
  const deployerBalance = await ethers.provider.getBalance(deployer.address);

  console.log(
    `Cuenta de despliegue: ${deployer.address}`,
    `\nBalance: ${ethers.formatEther(deployerBalance)} ETH`
  );

  // Dirección del treasury - dirección específica para recibir comisiones
  const treasuryAddress = "0xad14c117b51735c072d42571e30bf2c729cd9593";
  console.log(`Treasury address: ${treasuryAddress}`);

  // Compilamos el contrato para asegurarnos que está actualizado
  await run("compile");
  console.log("Compilación completada");

  // Desplegamos el contrato
  console.log("\n🚀 Desplegando SmartStaking...");
  const SmartStaking = await ethers.getContractFactory("SmartStaking");
  
  // Obtener precio de gas optimizado para Polygon
  console.log("⛽ Obteniendo precio de gas actual...");
  const feeData = await ethers.provider.getFeeData();
  console.log(`📊 Gas recomendado: ${ethers.formatUnits(feeData.maxFeePerGas, "gwei")} Gwei`);
  
  // Usar buffer del 20% (en lugar de 3x = 300%)
  // Esto reduce significativamente los costos de gas
  const maxFeePerGas = (feeData.maxFeePerGas * BigInt(120)) / BigInt(100); // +20%
  const maxPriorityFeePerGas = (feeData.maxPriorityFeePerGas * BigInt(120)) / BigInt(100);
  
  console.log(`🔥 Usando: ${ethers.formatUnits(maxFeePerGas, "gwei")} Gwei (+20% buffer)`);
  
  // Estimar costo antes de desplegar
  try {
    const deployTx = SmartStaking.getDeployTransaction(treasuryAddress);
    const gasEstimate = await ethers.provider.estimateGas({ data: deployTx.data });
    const estimatedCost = (gasEstimate * maxFeePerGas) / BigInt(10**18);
    console.log(`💰 Costo estimado: ~${ethers.formatEther(estimatedCost)} POL`);
    console.log(`📦 Gas estimado: ${gasEstimate.toString()} units`);
  } catch (e) {
    console.warn("⚠️  No se pudo estimar gas");
  }
  
  const smartStaking = await SmartStaking.deploy(treasuryAddress, {
    maxFeePerGas,
    maxPriorityFeePerGas
  });

  const txHash = smartStaking.deploymentTransaction().hash;
  console.log(`\n📤 TX enviada: ${txHash}`);
  console.log(`🔍 Polygonscan: https://polygonscan.com/tx/${txHash}`);
  console.log("⏳ Esperando confirmación...");

  await smartStaking.waitForDeployment();
  const contractAddress = await smartStaking.getAddress();
  
  // Obtener información del receipt
  const receipt = await smartStaking.deploymentTransaction().wait();
  const gasUsed = receipt.gasUsed;
  const gasPrice = receipt.gasPrice || receipt.effectiveGasPrice;
  const totalCost = gasUsed * gasPrice;

  console.log(`\n✅ Contrato SmartStaking desplegado en: ${contractAddress}`);
  console.log(`⛽ Gas usado: ${gasUsed.toString()} units`);
  console.log(`💵 Costo real: ${ethers.formatEther(totalCost)} POL`);

  // Esperamos unos bloques para asegurarnos que la transacción está confirmada
  console.log("Esperando confirmaciones...");
  await new Promise(resolve => setTimeout(resolve, 20000)); // 20 segundos

  // Verificamos el contrato en Polygonscan si no estamos en localhost
  if (network.name !== "localhost" && network.name !== "hardhat") {
    const fullyQualifiedName = "contracts/SmartStaking/SmartStaking.sol:SmartStaking";
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

  // Guardamos la dirección del contrato en un archivo para fácil acceso
  saveContractAddress(network.name, contractAddress);

  // Actualizamos el archivo .env con la dirección del contrato
  updateEnvFile(contractAddress, treasuryAddress);

  console.log("\n🎉 Despliegue completado exitosamente!");
  console.log(`\n📋 Resumen:`);
  console.log(`   Contrato: ${contractAddress}`);
  console.log(`   Red: ${network.name} (Chain ID: ${network.config.chainId})`);
  console.log(`   Treasury: ${treasuryAddress}`);
  console.log(`   Polygonscan: https://polygonscan.com/address/${contractAddress}`);
}

function saveContractAddress(networkName, contractAddress) {
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }

  const filePath = path.join(deploymentsDir, `${networkName}.json`);
  let deployments = {};

  if (fs.existsSync(filePath)) {
    const fileContent = fs.readFileSync(filePath, "utf8");
    deployments = JSON.parse(fileContent);
  }

  deployments.SmartStaking = contractAddress;

  fs.writeFileSync(
    filePath,
    JSON.stringify(deployments, null, 2)
  );

  console.log(`Dirección del contrato guardada en ${filePath}`);
}

function updateEnvFile(contractAddress, treasuryAddress) {
  const envPath = path.join(__dirname, "..", ".env");
  
  try {
    // Leer el archivo .env existente
    let envContent = "";
    if (fs.existsSync(envPath)) {
      envContent = fs.readFileSync(envPath, "utf8");
    }

    // Variables a actualizar/agregar
    const newVars = {
      'SMARTSTAKING_CONTRACT_ADDRESS': contractAddress,
      'TREASURY_ADDRESS': treasuryAddress,
      'DEPLOYMENT_DATE': new Date().toISOString()
    };

    // Actualizar o agregar cada variable
    let lines = envContent.split('\n');
    let updatedVars = new Set();

    lines = lines.map(line => {
      for (const [key, value] of Object.entries(newVars)) {
        if (line.startsWith(`${key}=`) || line.startsWith(`# ${key}`)) {
          updatedVars.add(key);
          return `${key}=${value}`;
        }
      }
      return line;
    });

    // Agregar variables que no existían
    const varsToAdd = [];
    for (const [key, value] of Object.entries(newVars)) {
      if (!updatedVars.has(key)) {
        varsToAdd.push(`${key}=${value}`);
      }
    }

    if (varsToAdd.length > 0) {
      // Agregar sección de SmartStaking si no existe
      if (!envContent.includes('# SmartStaking Contract')) {
        lines.push('');
        lines.push('# SmartStaking Contract');
      }
      lines = lines.concat(varsToAdd);
    }

    // Guardar archivo actualizado
    fs.writeFileSync(envPath, lines.join('\n'));
    console.log(`\n⚙️  Variables de entorno actualizadas en .env:`);
    console.log(`   - SMARTSTAKING_CONTRACT_ADDRESS=${contractAddress}`);
    console.log(`   - TREASURY_ADDRESS=${treasuryAddress}`);
  } catch (error) {
    console.warn(`⚠️  No se pudo actualizar .env:`, error.message);
  }
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
      // Si llega aquí, la verificación fue exitosa
      return true;
    } catch (err) {
      const msg = err && err.message ? err.message : String(err);
      // Si ya está verificado, considerar éxito
      if (msg.toLowerCase().includes("already verified") || msg.toLowerCase().includes("reason: already verified")) {
        console.log("ℹ️ Contrato ya verificado anteriormente.");
        return true;
      }

      attempt < maxAttempts
        ? console.log(`❗ Intento ${attempt} fallido: ${msg}. Reintentando en ${delayMs / 1000}s...`)
        : console.log(`❌ Intento ${attempt} fallido: ${msg}. No quedan reintentos.`);

      if (attempt >= maxAttempts) throw err;

      // esperar antes de reintentar
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
}

// Ejecutamos la función principal
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error en el despliegue:", error);
    process.exit(1);
  });
