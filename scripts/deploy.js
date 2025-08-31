const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 Iniciando deployment de MinerBot Empire...");
  
  // Obtener signers
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying contracts with account:", deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH");

  const deployedContracts = {};
  const deploymentInfo = {
    network: hre.network.name,
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
    
    console.log("✅ All authorizations completed!");

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

    // 8. Guardar información de deployment
    const deploymentsDir = path.join(__dirname, '..', 'deployments');
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }
    
    const deploymentFile = path.join(deploymentsDir, `${hre.network.name}.json`);
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
    
    console.log("\n📄 Deployment info saved to:", deploymentFile);

    // 9. Mostrar resumen final
    console.log("\n🎉 ===== DEPLOYMENT COMPLETED SUCCESSFULLY! ===== 🎉");
    console.log("\n📋 Contract Addresses:");
    console.log("🪙 MinerBotToken:", tokenAddress);
    console.log("🤖 MinerBotNFT:", nftAddress);
    console.log("🎮 MinerBotGame:", gameAddress);
    console.log("🏦 MinerBotStaking:", stakingAddress);
    console.log("🛒 MinerBotMarketplace:", marketplaceAddress);
    
    console.log("\n🔗 Network:", hre.network.name);
    console.log("👤 Deployer:", deployer.address);
    console.log("⏰ Timestamp:", deploymentInfo.timestamp);
    
    // 10. Instrucciones post-deployment
    console.log("\n📝 Next Steps:");
    console.log("1. Verify contracts on block explorer");
    console.log("2. Set up frontend with contract addresses");
    console.log("3. Test basic functionality");
    console.log("4. Configure any additional parameters");
    
    if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
      console.log("\n🔍 To verify contracts, run:");
      console.log(`npx hardhat verify --network ${hre.network.name} ${tokenAddress}`);
      console.log(`npx hardhat verify --network ${hre.network.name} ${nftAddress} ${tokenAddress}`);
      console.log(`npx hardhat verify --network ${hre.network.name} ${gameAddress} ${tokenAddress} ${nftAddress}`);
      console.log(`npx hardhat verify --network ${hre.network.name} ${stakingAddress} ${tokenAddress}`);
      console.log(`npx hardhat verify --network ${hre.network.name} ${marketplaceAddress} ${nftAddress} ${tokenAddress}`);
    }
    
    return deployedContracts;
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    throw error;
  }
}

// Función para deployment en desarrollo con datos de prueba
async function deployWithTestData() {
  console.log("\n🧪 Setting up test data...");
  
  const contracts = await main();
  const [deployer, testUser1, testUser2] = await ethers.getSigners();
  
  try {
    // Transferir tokens a usuarios de prueba
    const transferAmount = ethers.parseEther("10000");
    
    if (testUser1) {
      await contracts.token.transfer(testUser1.address, transferAmount);
      console.log("💰 Transferred", ethers.formatEther(transferAmount), "MBT to", testUser1.address);
    }
    
    if (testUser2) {
      await contracts.token.transfer(testUser2.address, transferAmount);
      console.log("💰 Transferred", ethers.formatEther(transferAmount), "MBT to", testUser2.address);
    }
    
    console.log("✅ Test data setup completed!");
    
  } catch (error) {
    console.error("❌ Test data setup failed:", error);
  }
}

// Ejecutar deployment
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = { main, deployWithTestData };