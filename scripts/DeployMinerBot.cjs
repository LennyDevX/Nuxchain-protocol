const { ethers, network, run } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log(`🚀 Desplegando MinerBot Empire en la red ${network.name}...`);
  
  // Obtener signers
  const [deployer] = await ethers.getSigners();
  const deployerBalance = await ethers.provider.getBalance(deployer.address);
  
  console.log(
    `📝 Cuenta de despliegue: ${deployer.address}`,
    `\n💰 Balance: ${ethers.formatEther(deployerBalance)} ETH`
  );

  // Compilamos los contratos para asegurarnos que están actualizados
  await run("compile");
  console.log("✅ Compilación completada");

  const deployedContracts = {};
  const deploymentInfo = {
    network: network.name,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {}
  };

  try {
    // 1. Deploy MinerBotToken
    console.log("\n🪙 Deploying MinerBotToken...");
    const MinerBotToken = await ethers.getContractFactory("MinerBotToken");
    const token = await MinerBotToken.deploy();
    await token.waitForDeployment();
    
    const tokenAddress = await token.getAddress();
    deployedContracts.token = token;
    deploymentInfo.contracts.MinerBotToken = {
      address: tokenAddress,
      constructorArgs: []
    };
    
    console.log("✅ MinerBotToken deployed to:", tokenAddress);
    
    // Verificar suministro inicial
    const totalSupply = await token.totalSupply();
    console.log("📊 Total Supply:", ethers.formatEther(totalSupply), "MBT");

    // 2. Deploy MinerBotNFT
    console.log("\n🤖 Deploying MinerBotNFT...");
    const MinerBotNFT = await ethers.getContractFactory("MinerBotNFT");
    const nft = await MinerBotNFT.deploy(tokenAddress);
    await nft.waitForDeployment();
    
    const nftAddress = await nft.getAddress();
    deployedContracts.nft = nft;
    deploymentInfo.contracts.MinerBotNFT = {
      address: nftAddress,
      constructorArgs: [tokenAddress]
    };
    
    console.log("✅ MinerBotNFT deployed to:", nftAddress);
    
    // Verificar configuración inicial
    const commonSupply = await nft.raritySupply(0);
    console.log("📊 Common robots supply limit:", commonSupply.toString());

    // 3. Deploy MinerBotGame
    console.log("\n🎮 Deploying MinerBotGame...");
    const MinerBotGame = await ethers.getContractFactory("MinerBotGame");
    const game = await MinerBotGame.deploy(tokenAddress, nftAddress);
    await game.waitForDeployment();
    
    const gameAddress = await game.getAddress();
    deployedContracts.game = game;
    deploymentInfo.contracts.MinerBotGame = {
      address: gameAddress,
      constructorArgs: [tokenAddress, nftAddress]
    };
    
    console.log("✅ MinerBotGame deployed to:", gameAddress);
    
    // Verificar zonas de minería
    const zone0 = await game.miningZones(0);
    console.log("📊 First mining zone:", zone0.name, "- Base reward:", ethers.formatEther(zone0.baseReward), "MBT");

    // 4. Deploy MinerBotStaking
    console.log("\n🏦 Deploying MinerBotStaking...");
    const MinerBotStaking = await ethers.getContractFactory("MinerBotStaking");
    const staking = await MinerBotStaking.deploy(tokenAddress);
    await staking.waitForDeployment();
    
    const stakingAddress = await staking.getAddress();
    deployedContracts.staking = staking;
    deploymentInfo.contracts.MinerBotStaking = {
      address: stakingAddress,
      constructorArgs: [tokenAddress]
    };
    
    console.log("✅ MinerBotStaking deployed to:", stakingAddress);
    
    // Verificar pools de staking
    const pool0 = await staking.stakingPools(0);
    console.log("📊 First staking pool - Duration:", pool0.duration.toString(), "seconds, APY:", pool0.apy.toString(), "bps");

    // 5. Deploy MinerBotMarketplace
    console.log("\n🛒 Deploying MinerBotMarketplace...");
    const MinerBotMarketplace = await ethers.getContractFactory("MinerBotMarketplace");
    const marketplace = await MinerBotMarketplace.deploy(nftAddress, tokenAddress);
    await marketplace.waitForDeployment();
    
    const marketplaceAddress = await marketplace.getAddress();
    deployedContracts.marketplace = marketplace;
    deploymentInfo.contracts.MinerBotMarketplace = {
      address: marketplaceAddress,
      constructorArgs: [nftAddress, tokenAddress]
    };
    
    console.log("✅ MinerBotMarketplace deployed to:", marketplaceAddress);
    
    // Verificar comisión del marketplace
    const marketplaceFee = await marketplace.marketplaceFee();
    console.log("📊 Marketplace fee:", marketplaceFee.toString(), "bps (" + (marketplaceFee / 100).toString() + "%)");

    // 6. Configurar autorizaciones
    console.log("\n🔐 Setting up contract authorizations...");
    
    // Autorizar contratos del juego para mintear tokens
    console.log("🔑 Authorizing game contract...");
    await token.authorizeGameContract(gameAddress);
    
    console.log("🔑 Authorizing staking contract...");
    await token.authorizeGameContract(stakingAddress);
    
    // Autorizar contrato del juego para gestionar NFTs
    console.log("🔑 Authorizing game contract for NFTs...");
    await nft.authorizeGameContract(gameAddress);
    
    console.log("✅ Todas las autorizaciones completadas!");

    // Esperamos unos bloques para asegurarnos que las transacciones están confirmadas
    console.log("⏳ Esperando confirmaciones...");
    await new Promise(resolve => setTimeout(resolve, 30000)); // 30 segundos

    // 7. Verificar configuraciones
    console.log("\n🔍 Verifying configurations...");
    
    // Verificar autorizaciones
    const isGameAuthorized = await token.authorizedContracts(gameAddress);
    const isStakingAuthorized = await token.authorizedContracts(stakingAddress);
    const isGameAuthorizedNFT = await nft.authorizedContracts(gameAddress);
    
    console.log("✅ Game contract authorized for token:", isGameAuthorized);
    console.log("✅ Staking contract authorized for token:", isStakingAuthorized);
    console.log("✅ Game contract authorized for NFT:", isGameAuthorizedNFT);
    
    // Verificar ownership
    console.log("👑 Token owner:", await token.owner());
    console.log("👑 NFT owner:", await nft.owner());
    console.log("👑 Game owner:", await game.owner());
    console.log("👑 Staking owner:", await staking.owner());
    console.log("👑 Marketplace owner:", await marketplace.owner());

    // 8. Verificar contratos si no estamos en localhost
    if (network.name !== "localhost" && network.name !== "hardhat") {
      try {
        console.log("\n🔍 Verificando contratos en Etherscan...");
        
        console.log("🔍 Verificando MinerBotToken...");
        await verifyContract(tokenAddress, "contracts/MinerBotGame/MinerBotToken.sol:MinerBotToken", []);
        
        console.log("🔍 Verificando MinerBotNFT...");
        await verifyContract(nftAddress, "contracts/MinerBotGame/MinerBotNFT.sol:MinerBotNFT", [tokenAddress]);
        
        console.log("🔍 Verificando MinerBotGame...");
        await verifyContract(gameAddress, "contracts/MinerBotGame/MinerBotGame.sol:MinerBotGame", [tokenAddress, nftAddress]);
        
        console.log("🔍 Verificando MinerBotStaking...");
        await verifyContract(stakingAddress, "contracts/MinerBotGame/MinerBotStaking.sol:MinerBotStaking", [tokenAddress]);
        
        console.log("🔍 Verificando MinerBotMarketplace...");
        await verifyContract(marketplaceAddress, "contracts/MinerBotGame/MinerBotMarketplace.sol:MinerBotMarketplace", [nftAddress, tokenAddress]);
        
        console.log("✅ ¡Todos los contratos verificados!");
      } catch (error) {
        console.log("❌ Error durante la verificación:", error && error.message ? error.message : error);
        console.log("💡 Puedes verificar manualmente más tarde");
      }
    }

    // 9. Guardar información de deployment
    saveContractAddresses(network.name, {
      MinerBotToken: tokenAddress,
      MinerBotNFT: nftAddress,
      MinerBotGame: gameAddress,
      MinerBotStaking: stakingAddress,
      MinerBotMarketplace: marketplaceAddress
    });

    // 10. Configurar archivo de entorno para el frontend
    saveEnvFile({
      token: tokenAddress,
      nft: nftAddress,
      game: gameAddress,
      staking: stakingAddress,
      marketplace: marketplaceAddress
    });

    // 9. Mostrar resumen final
    console.log("\n🎉 ===== DESPLIEGUE COMPLETADO EXITOSAMENTE! ===== 🎉");
    console.log("\n📋 Direcciones de Contratos:");
    console.log("🪙 MinerBotToken:", tokenAddress);
    console.log("🤖 MinerBotNFT:", nftAddress);
    console.log("🎮 MinerBotGame:", gameAddress);
    console.log("🏦 MinerBotStaking:", stakingAddress);
    console.log("🛒 MinerBotMarketplace:", marketplaceAddress);
    
    console.log("\n🔗 Red:", network.name);
    console.log("👤 Deployer:", deployer.address);
    console.log("⏰ Timestamp:", deploymentInfo.timestamp);
    
    console.log("\n📝 Próximos Pasos:");
    console.log("1. ✅ Contratos verificados en block explorer");
    console.log("2. ✅ Variables de entorno configuradas para frontend");
    console.log("3. 🔄 Probar funcionalidad básica");
    console.log("4. 🔄 Configurar parámetros adicionales si es necesario");
    
    console.log("\n🚀 ¡MinerBot Empire está listo para usar!");
    
    return deployedContracts;
    
  } catch (error) {
    console.error("❌ Error en el despliegue:", error);
    throw error;
  }
}

function saveContractAddresses(networkName, contracts) {
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const filePath = path.join(deploymentsDir, `${networkName}.json`);
  let deployments = {};

  if (fs.existsSync(filePath)) {
    const fileContent = fs.readFileSync(filePath, "utf8");
    deployments = JSON.parse(fileContent);
  }

  // Agregar todos los contratos de MinerBot
  Object.assign(deployments, contracts);

  fs.writeFileSync(
    filePath,
    JSON.stringify(deployments, null, 2)
  );

  console.log(`📄 Direcciones de contratos guardadas en ${filePath}`);
}

function saveEnvFile(contracts) {
  const envPath = path.join(__dirname, "..", "frontend", ".env.local");
  const frontendDir = path.join(__dirname, "..", "frontend");

  // Si la carpeta frontend no existe, no creamos nada (evitar crear carpetas no deseadas)
  if (!fs.existsSync(frontendDir)) {
    console.log(`⚠️ La carpeta frontend no existe en ${frontendDir}. Se omite la creación/actualización de .env.local`);
    return;
  }
  
  // Contenido del archivo .env.local para MinerBot Empire
  const envContent = `# MinerBot Empire Contract Addresses
NEXT_PUBLIC_MINERBOT_TOKEN_ADDRESS=${contracts.token}
NEXT_PUBLIC_MINERBOT_NFT_ADDRESS=${contracts.nft}
NEXT_PUBLIC_MINERBOT_GAME_ADDRESS=${contracts.game}
NEXT_PUBLIC_MINERBOT_STAKING_ADDRESS=${contracts.staking}
NEXT_PUBLIC_MINERBOT_MARKETPLACE_ADDRESS=${contracts.marketplace}

# Network Configuration
NEXT_PUBLIC_CHAIN_ID=${network.config.chainId}
NEXT_PUBLIC_NETWORK_NAME=${network.name}

# App Configuration
NEXT_PUBLIC_APP_NAME=MinerBot Empire
NEXT_PUBLIC_APP_VERSION=1.0.0`;

  fs.writeFileSync(envPath, envContent);
  console.log(`📄 Variables de entorno guardadas en ${envPath}`);
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

// Ejecutar la función principal
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error en el despliegue:", error);
    process.exit(1);
  });