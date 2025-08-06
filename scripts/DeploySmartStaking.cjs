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

  // Dirección del treasury - puedes cambiar esta dirección según tus necesidades
  const treasuryAddress = deployer.address; // Por defecto usa la dirección del deployer
  console.log(`Treasury address: ${treasuryAddress}`);

  // Compilamos el contrato para asegurarnos que está actualizado
  await run("compile");
  console.log("Compilación completada");

  // Desplegamos el contrato
  const SmartStaking = await ethers.getContractFactory("SmartStaking");
  const smartStaking = await SmartStaking.deploy(treasuryAddress);

  await smartStaking.waitForDeployment();
  const contractAddress = await smartStaking.getAddress();

  console.log(`Contrato SmartStaking desplegado en: ${contractAddress}`);

  // Esperamos unos bloques para asegurarnos que la transacción está confirmada
  console.log("Esperando confirmaciones...");
  await new Promise(resolve => setTimeout(resolve, 20000)); // 20 segundos

  // Verificamos el contrato si no estamos en localhost
  if (network.name !== "localhost" && network.name !== "hardhat") {
    try {
      console.log("Verificando contrato en Etherscan...");
      await run("verify:verify", {
        address: contractAddress,
        constructorArguments: [treasuryAddress],
        contract: "contracts/SmartStaking.sol:SmartStaking"
      });
      console.log("¡Contrato verificado!");
    } catch (error) {
      console.log("Error durante la verificación:", error.message);
    }
  }

  // Guardamos la dirección del contrato en un archivo para fácil acceso
  saveContractAddress(network.name, contractAddress);

  // Configuramos el archivo de entorno para el frontend
  saveEnvFile(contractAddress, treasuryAddress);

  console.log("Despliegue completado exitosamente!");
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

function saveEnvFile(contractAddress, treasuryAddress) {
  const envPath = path.join(__dirname, "..", "frontend", ".env.local");
  
  // Contenido del archivo .env.local para SmartStaking
  const envContent = `NEXT_PUBLIC_SMARTSTAKING_CONTRACT_ADDRESS=${contractAddress}
NEXT_PUBLIC_TREASURY_ADDRESS=${treasuryAddress}
NEXT_PUBLIC_CHAIN_ID=${network.config.chainId}
NEXT_PUBLIC_APP_NAME=Nuvos Smart Staking`;

  fs.writeFileSync(envPath, envContent);
  console.log(`Variables de entorno guardadas en ${envPath}`);
}

// Ejecutamos la función principal
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error en el despliegue:", error);
    process.exit(1);
  });
