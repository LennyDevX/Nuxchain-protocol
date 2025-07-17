const { ethers, network, run } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log(`Desplegando AirdropFactory en la red ${network.name}...`);

  // Obtenemos la wallet que hará el despliegue
  const [deployer] = await ethers.getSigners();
  const deployerBalance = await ethers.provider.getBalance(deployer.address);

  console.log(
    `Cuenta de despliegue: ${deployer.address}`,
    `\nBalance: ${ethers.formatEther(deployerBalance)} ${network.name === "polygon" ? "POL" : "ETH"}`
  );

  console.log("📋 Información del AirdropFactory:");
  console.log("- Permite crear múltiples contratos Airdrop");
  console.log("- Gestiona el historial de todos los airdrops");
  console.log("- Transfiere automáticamente ownership al creador");
  console.log("- Proporciona funciones de consulta centralizadas");

  // Compilamos el contrato para asegurarnos que está actualizado
  await run("compile");
  console.log("Compilación completada");

  // Desplegamos el contrato
  console.log("\n🚀 Desplegando AirdropFactory...");
  const AirdropFactory = await ethers.getContractFactory("AirdropFactory");
  const airdropFactory = await AirdropFactory.deploy();

  await airdropFactory.waitForDeployment();
  const contractAddress = await airdropFactory.getAddress();

  console.log(`✅ Contrato AirdropFactory desplegado en: ${contractAddress}`);

  // Verificar que el owner es correcto
  const factoryOwner = await airdropFactory.owner();
  console.log(`👤 Owner del factory: ${factoryOwner}`);
  console.log(`✅ Owner verificado: ${factoryOwner === deployer.address ? "Correcto" : "❌ Incorrecto"}`);

  // Esperamos unos bloques para asegurarnos que la transacción está confirmada
  console.log("\n⏳ Esperando confirmaciones...");
  await new Promise(resolve => setTimeout(resolve, 20000)); // 20 segundos

  // Verificamos el contrato si no estamos en localhost
  if (network.name !== "localhost" && network.name !== "hardhat") {
    try {
      console.log("🔍 Verificando contrato en el explorador de bloques...");
      await run("verify:verify", {
        address: contractAddress,
        constructorArguments: [],
        contract: "contracts/AirdropFactory.sol:AirdropFactory"
      });
      console.log("✅ ¡Contrato verificado!");
    } catch (error) {
      console.log("⚠️ Error durante la verificación:", error.message);
      console.log("💡 Puedes verificar manualmente más tarde");
    }
  }

  // Guardamos la dirección del contrato en un archivo para fácil acceso
  saveContractAddress(network.name, contractAddress);

  // Configuramos el archivo de entorno para el frontend
  saveEnvFile(contractAddress);

  console.log("\n🎉 Despliegue completado exitosamente!");
  console.log("\n📋 Próximos pasos para usar el AirdropFactory:");
  console.log("1. 🏭 Crear un nuevo airdrop: factory.deployAirdrop(tokenAddress, durations, name)");
  console.log("2. 💰 Fondear el airdrop creado: airdrop.fundContract(amount)");
  console.log("3. 📝 Los usuarios se registran en el airdrop específico");
  console.log("4. 🎁 Los usuarios reclaman sus tokens del airdrop");
  console.log("5. 🔄 Repetir el proceso para crear más airdrops");
  
  console.log("\n🔗 Enlaces útiles:");
  if (network.name === "polygon" || network.name === "matic") {
    console.log(`   Polygonscan: https://polygonscan.com/address/${contractAddress}`);
  } else if (network.name === "ethereum" || network.name === "mainnet") {
    console.log(`   Etherscan: https://etherscan.io/address/${contractAddress}`);
  } else if (network.name === "sepolia") {
    console.log(`   Etherscan: https://sepolia.etherscan.io/address/${contractAddress}`);
  }

  console.log("\n📁 Scripts útiles:");
  console.log("   - Crear airdrop: npm run scripts:create-airdrop");
  console.log("   - Gestionar airdrops: npm run scripts:manage-airdrops");
  console.log("   - Ver estadísticas: npm run scripts:airdrop-stats");
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

  deployments.AirdropFactory = contractAddress;

  fs.writeFileSync(
    filePath,
    JSON.stringify(deployments, null, 2)
  );

  console.log(`💾 Dirección del contrato guardada en ${filePath}`);
}

function saveEnvFile(contractAddress) {
  const envPath = path.join(__dirname, "..", "frontend", ".env.local");
  
  // Leer contenido existente si existe
  let existingContent = "";
  if (fs.existsSync(envPath)) {
    existingContent = fs.readFileSync(envPath, "utf8");
  }

  // Contenido del archivo .env.local para AirdropFactory
  const newEnvVars = [
    `NEXT_PUBLIC_AIRDROP_FACTORY_ADDRESS=${contractAddress}`,
    `NEXT_PUBLIC_FACTORY_CHAIN_ID=${network.config.chainId}`,
    `NEXT_PUBLIC_FACTORY_NETWORK=${network.name}`
  ];

  // Si hay contenido existente, agregar las nuevas variables
  if (existingContent) {
    // Remover variables del factory existentes
    const lines = existingContent.split('\n');
    const filteredLines = lines.filter(line => 
      !line.startsWith('NEXT_PUBLIC_AIRDROP_FACTORY_ADDRESS=') &&
      !line.startsWith('NEXT_PUBLIC_FACTORY_CHAIN_ID=') &&
      !line.startsWith('NEXT_PUBLIC_FACTORY_NETWORK=')
    );
    
    // Agregar nuevas variables
    const updatedContent = [...filteredLines, ...newEnvVars].join('\n');
    fs.writeFileSync(envPath, updatedContent);
  } else {
    // Crear archivo nuevo con variables del factory
    const envContent = [
      '# AirdropFactory Configuration',
      ...newEnvVars,
      '',
      '# App Configuration',
      'NEXT_PUBLIC_APP_NAME=Nuvos Airdrop Factory'
    ].join('\n');
    
    fs.writeFileSync(envPath, envContent);
  }

  console.log(`⚙️ Variables de entorno actualizadas en ${envPath}`);
}

// Ejecutamos la función principal
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("💥 Error en el despliegue:", error);
    process.exit(1);
  });
