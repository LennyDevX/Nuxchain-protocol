const { ethers, network, run } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log(`Desplegando Airdrop en la red ${network.name}...`);

  // Obtenemos la wallet que hará el despliegue
  const [deployer] = await ethers.getSigners();
  const deployerBalance = await ethers.provider.getBalance(deployer.address);

  console.log(
    `Cuenta de despliegue: ${deployer.address}`,
    `\nBalance: ${ethers.formatEther(deployerBalance)} POL`
  );

  // Parámetros del contrato Airdrop - ajusta según tus necesidades
  const tokenAddress = "0x0000000000000000000000000000000000000000"; // CAMBIAR por la dirección del token ERC20
  const registrationDuration = 7 * 24 * 60 * 60; // 7 días en segundos
  const claimDelay = 1 * 24 * 60 * 60; // 1 día en segundos
  const claimDuration = 30 * 24 * 60 * 60; // 30 días para reclamar (0 = ilimitado)

  console.log(`Token address: ${tokenAddress}`);
  console.log(`Registration duration: ${registrationDuration} seconds (${registrationDuration / (24 * 60 * 60)} days)`);
  console.log(`Claim delay: ${claimDelay} seconds (${claimDelay / (24 * 60 * 60)} days)`);
  console.log(`Claim duration: ${claimDuration} seconds (${claimDuration / (24 * 60 * 60)} days)`);
  console.log(`Tokens per user: 5 tokens (fixed amount)`);

  // Validar que la dirección del token no sea la dirección cero
  if (tokenAddress === "0x0000000000000000000000000000000000000000") {
    console.error("❌ ERROR: Debes especificar una dirección válida del token ERC20");
    console.log("💡 Edita el script y cambia la variable 'tokenAddress' por la dirección correcta del token");
    process.exit(1);
  }

  // Compilamos el contrato para asegurarnos que está actualizado
  await run("compile");
  console.log("Compilación completada");

  // Desplegamos el contrato
  const Airdrop = await ethers.getContractFactory("Airdrop");
  const airdrop = await Airdrop.deploy(
    tokenAddress,
    registrationDuration,
    claimDelay,
    claimDuration
  );

  await airdrop.waitForDeployment();
  const contractAddress = await airdrop.getAddress();

  console.log(`Contrato Airdrop desplegado en: ${contractAddress}`);

  // Esperamos unos bloques para asegurarnos que la transacción está confirmada
  console.log("Esperando confirmaciones...");
  await new Promise(resolve => setTimeout(resolve, 20000)); // 20 segundos

  // Verificamos el contrato si no estamos en localhost
  if (network.name !== "localhost" && network.name !== "hardhat") {
    const fullyQualifiedName = "contracts/Airdrop/Airdrops.sol:Airdrop";
    try {
      console.log("Verificando contrato en Etherscan...");
      await verifyContract(contractAddress, fullyQualifiedName, [tokenAddress, registrationDuration, claimDelay, claimDuration]);
      console.log("¡Contrato verificado!");
    } catch (error) {
      console.log("Error durante la verificación:", error && error.message ? error.message : error);
      console.log("💡 Puedes verificar manualmente más tarde");
    }
  }

  // Guardamos la dirección del contrato en un archivo para fácil acceso
  saveContractAddress(network.name, contractAddress);

  // Configuramos el archivo de entorno para el frontend
  saveEnvFile(contractAddress, tokenAddress);

  console.log("Despliegue completado exitosamente!");
  console.log("\n📋 Pasos siguientes:");
  console.log("1. Asegúrate de tener tokens ERC20 en tu wallet");
  console.log("2. Aprobar tokens al contrato: token.approve(airdropAddress, amount)");
  console.log("3. Fondear el contrato: airdrop.fundContract(amount)");
  console.log("4. Los usuarios pueden registrarse durante el período de registro");
  console.log("5. Después del período de registro + delay, los usuarios pueden reclamar 5 tokens cada uno");
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

  deployments.Airdrop = contractAddress;

  fs.writeFileSync(
    filePath,
    JSON.stringify(deployments, null, 2)
  );

  console.log(`Dirección del contrato guardada en ${filePath}`);
}

function saveEnvFile(contractAddress, tokenAddress) {
  const envPath = path.join(__dirname, "..", "frontend", ".env.local");
  const frontendDir = path.join(__dirname, "..", "frontend");

  // Si la carpeta frontend no existe, no creamos nada (evitar crear carpetas no deseadas)
  if (!fs.existsSync(frontendDir)) {
    console.log(`⚠️ La carpeta frontend no existe en ${frontendDir}. Se omite la creación/actualización de .env.local`);
    return;
  }
  
  // Contenido del archivo .env.local para Airdrop
  const envContent = `NEXT_PUBLIC_AIRDROP_CONTRACT_ADDRESS=${contractAddress}
NEXT_PUBLIC_TOKEN_ADDRESS=${tokenAddress}
NEXT_PUBLIC_CHAIN_ID=${network.config.chainId}
NEXT_PUBLIC_APP_NAME=Nuvos Airdrop`;

  fs.writeFileSync(envPath, envContent);
  console.log(`Variables de entorno guardadas en ${envPath}`);
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
