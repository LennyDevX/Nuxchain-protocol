const { ethers, network, run } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log(`Desplegando Marketplace en la red ${network.name}...`);

  // Obtenemos la wallet que hará el despliegue
  const [deployer] = await ethers.getSigners();
  const deployerBalance = await ethers.provider.getBalance(deployer.address);

  console.log(
    `Cuenta de despliegue: ${deployer.address}`,
    `\nBalance: ${ethers.formatEther(deployerBalance)} ETH`
  );

  // Compilamos el contrato para asegurarnos que está actualizado
  await run("compile");
  console.log("Compilación completada");

  // Desplegamos el contrato
  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy();

  await marketplace.waitForDeployment();
  const contractAddress = await marketplace.getAddress();

  console.log(`Contrato Marketplace desplegado en: ${contractAddress}`);

  // Esperamos unos bloques para asegurarnos que la transacción está confirmada
  console.log("Esperando confirmaciones...");
  await new Promise(resolve => setTimeout(resolve, 20000)); // 20 segundos

  // Verificamos el contrato si no estamos en localhost
  if (network.name !== "localhost" && network.name !== "hardhat") {
    try {
  console.log("Verificando contrato en Etherscan...");
  const fullyQualifiedName = "contracts/Marketplace/Marketplace.sol:Marketplace";
  await verifyContract(contractAddress, fullyQualifiedName);
      console.log("¡Contrato verificado!");
    } catch (error) {
      console.log("Error durante la verificación:", error && error.message ? error.message : error);
    }
  }

  // Guardamos la dirección del contrato en un archivo para fácil acceso
  saveContractAddress(network.name, contractAddress);

  // Configuramos el archivo de entorno para el frontend
  saveEnvFile(contractAddress);

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

  deployments.Marketplace = contractAddress;

  fs.writeFileSync(
    filePath,
    JSON.stringify(deployments, null, 2)
  );

  console.log(`Dirección del contrato guardada en ${filePath}`);
}


// Verifica un contrato en el explorador usando hardhat-etherscan plugin con reintentos
async function verifyContract(address, fullyQualifiedName, maxAttempts = 3, delayMs = 7000) {
  let attempt = 0;
  while (attempt < maxAttempts) {
    try {
      attempt++;
      await run("verify:verify", {
        address: address,
        constructorArguments: [],
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
