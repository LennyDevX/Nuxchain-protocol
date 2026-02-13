const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {
  console.log("\n╔════════════════════════════════════════════════════════════════╗");
  console.log("║  🚀 DESPLEGAR COLLABORATOR BADGE REWARDS                     ║");
  console.log("╚════════════════════════════════════════════════════════════════╝\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("👤 Deployer:", deployer.address);

  // Cargar direcciones de polygon-addresses.json
  const addressesPath = path.join(__dirname, '../../../deployments/polygon-addresses.json');
  let addresses = {};
  
  if (fs.existsSync(addressesPath)) {
    addresses = JSON.parse(fs.readFileSync(addressesPath, 'utf8'));
  } else {
    console.log("⚠️  polygon-addresses.json no existe, creando nuevo...");
  }

  // Obtener direcciones necesarias
  const TREASURY_ADDRESS = addresses.treasury?.manager || "0x8f3554Fca1Bd1b79bBf531706FA2C67fEcC5401F";
  const MARKETPLACE_PROXY = addresses.marketplace?.proxy || "0xd502fB2Eb3d345EE9A5A0286A472B38c77Fda6d5";

  console.log("\n📋 Direcciones de referencia:");
  console.log("   TreasuryManager: ", TREASURY_ADDRESS);
  console.log("   Marketplace:     ", MARKETPLACE_PROXY);

  // Verificar balance
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("\n💰 Balance deployer:", hre.ethers.formatEther(balance), "POL");

  if (balance < hre.ethers.parseEther("0.1")) {
    console.log("\n❌ ERROR: Balance insuficiente (mínimo 0.1 POL)");
    process.exit(1);
  }

  console.log("\n┌────────────────────────────────────────────────────────────────┐");
  console.log("│ Desplegando CollaboratorBadgeRewards...                       │");
  console.log("└────────────────────────────────────────────────────────────────┘\n");

  let totalGasUsed = 0n;

  try {
    // 1. Desplegar Implementation
    console.log("📦 Desplegando Implementation...");
    const CollaboratorBadgeRewards = await hre.ethers.getContractFactory("CollaboratorBadgeRewards");
    const implementation = await CollaboratorBadgeRewards.deploy();
    await implementation.waitForDeployment();
    const implAddress = await implementation.getAddress();
    
    const implReceipt = await implementation.deploymentTransaction().wait();
    totalGasUsed += implReceipt.gasUsed;

    console.log("   ✅ Implementation:", implAddress);
    console.log("   ⛽ Gas usado:", implReceipt.gasUsed.toString());

    // 2. Preparar datos de inicialización (sin argumentos)
    const initData = CollaboratorBadgeRewards.interface.encodeFunctionData("initialize", []);

    // 3. Desplegar Proxy
    console.log("\n📦 Desplegando UUPS Proxy...");
    const ERC1967Proxy = await hre.ethers.getContractFactory("ERC1967Proxy");
    const proxy = await ERC1967Proxy.deploy(implAddress, initData);
    await proxy.waitForDeployment();
    const proxyAddress = await proxy.getAddress();
    
    const proxyReceipt = await proxy.deploymentTransaction().wait();
    totalGasUsed += proxyReceipt.gasUsed;

    console.log("   ✅ Proxy:", proxyAddress);
    console.log("   ⛽ Gas usado:", proxyReceipt.gasUsed.toString());

    // 4. Configurar con setters
    console.log("\n┌────────────────────────────────────────────────────────────────┐");
    console.log("│ Configurando Referencias                                       │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const collaboratorContract = await hre.ethers.getContractAt("CollaboratorBadgeRewards", proxyAddress);
    
    console.log("   Configurando TreasuryManager...");
    const txTreasury = await collaboratorContract.setTreasuryManager(TREASURY_ADDRESS);
    const receiptTreasury = await txTreasury.wait();
    totalGasUsed += receiptTreasury.gasUsed;
    console.log("      ✅ OK (gas: " + receiptTreasury.gasUsed.toString() + ")");

    // Verificar BadgeManager existe en marketplace
    try {
      const marketplaceContract = await hre.ethers.getContractAt("GameifiedMarketplaceCoreV1", MARKETPLACE_PROXY);
      const badgeManagerAddress = await marketplaceContract.badgeManager();
      
      if (badgeManagerAddress && badgeManagerAddress !== hre.ethers.ZeroAddress) {
        console.log("\n   Configurando BadgeManager...");
        const txBadge = await collaboratorContract.setBadgeManager(badgeManagerAddress);
        const receiptBadge = await txBadge.wait();
        totalGasUsed += receiptBadge.gasUsed;
        console.log("      ✅ OK (gas: " + receiptBadge.gasUsed.toString() + ")");
      } else {
        console.log("\n   ⚠️  BadgeManager no encontrado en marketplace, skip...");
      }
    } catch (error) {
      console.log("\n   ⚠️  No se pudo obtener BadgeManager:", error.message);
    }

    // 5. Verificar configuración
    console.log("\n┌────────────────────────────────────────────────────────────────┐");
    console.log("│ Verificando Configuración                                      │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    const treasuryManager = await collaboratorContract.treasuryManager();
    console.log("   Treasury Manager:  ", treasuryManager);

    if (treasuryManager !== TREASURY_ADDRESS) {
      console.log("   ⚠️  ADVERTENCIA: Treasury manager diferente al esperado");
    } else {
      console.log("   ✅ Treasury manager configurado correctamente");
    }

    // 5. Actualizar polygon-addresses.json
    console.log("\n┌────────────────────────────────────────────────────────────────┐");
    console.log("│ Actualizando polygon-addresses.json                           │");
    console.log("└────────────────────────────────────────────────────────────────┘\n");

    if (!addresses.collaborators) {
      addresses.collaborators = {};
    }

    addresses.collaborators.badgeRewards = proxyAddress;
    addresses.collaborators.badgeRewardsImplementation = implAddress;

    fs.writeFileSync(addressesPath, JSON.stringify(addresses, null, 2));
    console.log("   ✅ Archivo actualizado");

    // 6. Resumen final
    const finalBalance = await hre.ethers.provider.getBalance(deployer.address);
    const gasSpent = balance - finalBalance;

    console.log("\n══════════════════════════════════════════════════════════════════════");
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║           ✅ DEPLOYMENT EXITOSO                              ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    console.log("🎯 CollaboratorBadgeRewards Proxy:");
    console.log("   📍", proxyAddress);
    console.log("   🔗 https://polygonscan.com/address/" + proxyAddress);

    console.log("\n🔧 Implementation:");
    console.log("   📍", implAddress);

    console.log("\n⚙️  Configuración:");
    console.log("   Treasury:    ", treasuryManager);

    console.log("\n💾 Gas gastado:", hre.ethers.formatEther(gasSpent), "POL");
    console.log("💼 Balance final:", hre.ethers.formatEther(finalBalance), "POL");

    console.log("\n┌─────────────────────────────────────────────────────────────────────┐");
    console.log("│ 📝 SIGUIENTE PASO                                                   │");
    console.log("└─────────────────────────────────────────────────────────────────────┘\n");

    console.log("Ejecutar configuración de treasury:");
    console.log("npx hardhat run scripts/updates/staking/configure_treasury_final.cjs --network polygon");

    console.log("\n══════════════════════════════════════════════════════════════════════\n");

  } catch (error) {
    console.error("\n❌ ERROR durante deployment:", error.message);
    if (error.data) {
      console.error("   Data:", error.data);
    }
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
