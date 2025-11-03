const { ethers, network, run } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log(`\n🚀 Desplegando GameifiedMarketplace en la red ${network.name}...`);

  // Obtenemos la wallet que hará el despliegue
  const [deployer] = await ethers.getSigners();
  const deployerBalance = await ethers.provider.getBalance(deployer.address);

  console.log(
    `\n👤 Cuenta de despliegue: ${deployer.address}` +
    `\n💰 Balance: ${ethers.formatEther(deployerBalance)} ETH`
  );

  // Cargar direcciones necesarias desde deployment anterior
  const network_name = network.name;
  const deploymentFile = path.join(__dirname, "..", "deployments", `${network_name}-deployment.json`);
  
  let stakingAddress = "0x0000000000000000000000000000000000000000";
  if (fs.existsSync(deploymentFile)) {
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    if (deployment.contracts?.EnhancedSmartStaking?.address) {
      stakingAddress = deployment.contracts.EnhancedSmartStaking.address;
      console.log(`\n📦 Staking Contract encontrado: ${stakingAddress}`);
    }
  } else {
    console.log(`\n⚠️  No se encontró contrato de Staking. Debes desplegar EnhancedSmartStaking primero.`);
    console.log(`   Ejecuta: npx hardhat run scripts/DeployEnhancedSmartStaking.cjs --network ${network_name}`);
    process.exit(1);
  }

  // Direcciones de configuración
  const polTokenAddress = "0x455e53cbb86018ac2b8092fdcd39d8444aff00ef"; // Polygon POL token (lowercase)
  const stakingTreasuryAddress = "0xad14c117b51735c072d42571e30bf2c729cd9593";
  
  console.log(`\n💼 Configuración:`);
  console.log(`   POL Token: ${polTokenAddress}`);
  console.log(`   Staking Treasury: ${stakingTreasuryAddress}`);

  // Compilamos el contrato para asegurarnos que está actualizado
  await run("compile");
  console.log("\n✅ Compilación completada");

  // Desplegamos el contrato
  console.log("\n📝 Desplegando GameifiedMarketplace...");
  const GameifiedMarketplace = await ethers.getContractFactory("GameifiedMarketplace");
  
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
    const deployTx = GameifiedMarketplace.getDeployTransaction(
      polTokenAddress,
      stakingAddress,
      stakingTreasuryAddress
    );
    const gasEstimate = await ethers.provider.estimateGas({ data: deployTx.data });
    const estimatedCost = (gasEstimate * maxFeePerGas) / BigInt(10**18);
    console.log(`   💵 Costo estimado: ~${ethers.formatEther(estimatedCost)} ETH`);
    console.log(`   📦 Gas estimado: ${gasEstimate.toString()} units\n`);
  } catch (e) {
    console.warn("⚠️  No se pudo estimar gas\n");
  }
  
  const marketplace = await GameifiedMarketplace.deploy(
    polTokenAddress,
    stakingAddress,
    stakingTreasuryAddress,
    {
      maxFeePerGas,
      maxPriorityFeePerGas
    }
  );

  const txHash = marketplace.deploymentTransaction().hash;
  console.log(`📤 TX enviada: ${txHash}`);
  console.log(`🔍 Polygonscan: https://polygonscan.com/tx/${txHash}`);
  console.log("⏳ Esperando confirmación...\n");

  await marketplace.waitForDeployment();
  const contractAddress = await marketplace.getAddress();
  
  // Obtener información del receipt
  const receipt = await marketplace.deploymentTransaction().wait();
  const gasUsed = receipt.gasUsed;
  const gasPrice = receipt.gasPrice || receipt.effectiveGasPrice;
  const totalCost = gasUsed * gasPrice;

  console.log(`✅ Contrato GameifiedMarketplace desplegado en: ${contractAddress}`);
  console.log(`⛽ Gas usado: ${gasUsed.toString()} units`);
  console.log(`💵 Costo real: ${ethers.formatEther(totalCost)} ETH\n`);

  // Verificar inicialización
  console.log("📊 Verificando inicialización del contrato...");
  const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
  const hasAdminRole = await marketplace.hasRole(ADMIN_ROLE, deployer.address);
  const polToken = await marketplace.polTokenAddress();
  const staking = await marketplace.stakingContractAddress();
  
  console.log(`   Admin Role (deployer): ${hasAdminRole ? '✅' : '❌'}`);
  console.log(`   POL Token: ${polToken}`);
  console.log(`   Staking Contract: ${staking}`);
  console.log(`   Staking Treasury: ${await marketplace.stakingTreasuryAddress()}\n`);

  // Configuración del marketplace para conocer la dirección del staking
  console.log("⚙️  Configurando Marketplace...");
  try {
    // El staking necesita saber quién es el marketplace
    const stakingContract = await ethers.getContractAt("EnhancedSmartStaking", stakingAddress);
    const currentMarketplace = await stakingContract.marketplaceContract();
    
    if (currentMarketplace === "0x0000000000000000000000000000000000000000") {
      console.log("   Estableciendo dirección del marketplace en Staking...");
      const tx = await stakingContract.setMarketplaceContract(contractAddress);
      await tx.wait();
      console.log("   ✅ Marketplace configurado en Staking");
    } else {
      console.log(`   ℹ️  Marketplace ya configurado: ${currentMarketplace}`);
    }
  } catch (e) {
    console.log(`   ⚠️  No se pudo configurar automáticamente. Hazlo manualmente después.`);
  }

  // Esperamos unos bloques para asegurarnos que la transacción está confirmada
  console.log("\n⏳ Esperando confirmaciones adicionales...");
  await new Promise(resolve => setTimeout(resolve, 20000)); // 20 segundos

  // Verificamos el contrato en Polygonscan si no estamos en localhost
  if (network.name !== "localhost" && network.name !== "hardhat") {
    const fullyQualifiedName = "contracts/Marketplace/GameifiedMarketplace.sol:GameifiedMarketplace";
    try {
      console.log("\n🔍 Verificando contrato en Polygonscan...");
      await verifyContract(contractAddress, fullyQualifiedName, [
        polTokenAddress,
        stakingAddress,
        stakingTreasuryAddress
      ]);
      console.log("✅ ¡Contrato verificado en Polygonscan!");
    } catch (error) {
      console.log("⚠️  Error durante la verificación automática:", error && error.message ? error.message : error);
      console.log("\n💡 Puedes verificar manualmente:");
      console.log(`   1. Ve a: https://polygonscan.com/address/${contractAddress}#code`);
      console.log(`   2. Click en "Verify and Publish"`);
      console.log(`   3. Constructor Arguments (ABI encoded):`);
      console.log(`      - POL Token: ${polTokenAddress}`);
      console.log(`      - Staking: ${stakingAddress}`);
      console.log(`      - Treasury: ${stakingTreasuryAddress}`);
    }
  }

  // Guardamos la dirección del contrato en el archivo de despliegue
  saveContractAddress(network.name, contractAddress, "GameifiedMarketplace");

  console.log("\n🎉 Despliegue completado exitosamente!");
  console.log(`\n📋 Resumen:`);
  console.log(`   Contrato: ${contractAddress}`);
  console.log(`   Red: ${network.name} (Chain ID: ${network.config.chainId})`);
  console.log(`   Staking: ${stakingAddress}`);
  console.log(`   POL Token: ${polTokenAddress}`);
  console.log(`   Staking Treasury: ${stakingTreasuryAddress}`);
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
