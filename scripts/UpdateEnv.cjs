const fs = require("fs");
const path = require("path");

// Esta función lee la información del despliegue más reciente y actualiza el .env del frontend
async function main() {
  const networkName = process.argv[2] || "sepolia"; // Red por defecto
  console.log(`Actualizando variables de entorno para: ${networkName}`);

  // Leemos la dirección del contrato desplegado
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  const filePath = path.join(deploymentsDir, `${networkName}.json`);
  
  if (!fs.existsSync(filePath)) {
    console.error(`No existe archivo de despliegue para la red ${networkName}`);
    process.exit(1);
  }

  const deploymentData = JSON.parse(fs.readFileSync(filePath, "utf8"));
  const contractAddress = deploymentData.TokenizationApp;

  if (!contractAddress) {
    console.error(`Dirección del contrato no encontrada para ${networkName}`);
    process.exit(1);
  }

  // Determinar el Chain ID basado en la red
  let chainId;
  switch (networkName) {
    case "mainnet":
      chainId = 1;
      break;
    case "sepolia":
      chainId = 11155111;
      break;
    case "goerli":
      chainId = 5;
      break;
    case "polygon":
      chainId = 137;
      break;
    case "mumbai":
      chainId = 80001;
      break;
    default:
      chainId = 31337; // Hardhat default
  }

  // Creamos el contenido del archivo .env.local
  const envPath = path.join(__dirname, "..", "frontend", ".env.local");
  const envContent = `NEXT_PUBLIC_CONTRACT_ADDRESS=${contractAddress}
NEXT_PUBLIC_CHAIN_ID=${chainId}
NEXT_PUBLIC_APP_NAME=Nuvos NFT Marketplace
NEXT_PUBLIC_NETWORK=${networkName}`;

  fs.writeFileSync(envPath, envContent);
  console.log(`Variables de entorno actualizadas en ${envPath}`);
  console.log(`Contrato configurado: ${contractAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
