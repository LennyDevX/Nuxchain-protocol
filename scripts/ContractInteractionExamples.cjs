// ════════════════════════════════════════════════════════════════════════════════════════
// EJEMPLOS DE USO - EnhancedSmartStaking & GameifiedMarketplace
// ════════════════════════════════════════════════════════════════════════════════════════
// 
// Este archivo contiene ejemplos de cómo interactuar con los contratos después del despliegue.
// 
// Guardar como: scripts/ContractInteractionExamples.cjs
// Usar con: npx hardhat run scripts/ContractInteractionExamples.cjs --network polygon
//

const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 1: Leer configuración de contratos desplegados
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function readContractConfiguration() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║        📖 EJEMPLO 1: Leer Configuración de Contratos         ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const network = await hre.ethers.provider.getNetwork();
    const deploymentFile = path.join(__dirname, "..", "deployments", `${network.name}-deployment.json`);
    
    if (!fs.existsSync(deploymentFile)) {
        console.log("❌ No hay despliegue guardado. Ejecuta NFTs2.cjs primero.\n");
        return;
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    const stakingAddress = deployment.contracts.EnhancedSmartStaking.address;
    const marketplaceAddress = deployment.contracts.GameifiedMarketplace.address;
    
    // Conectar a EnhancedSmartStaking
    const staking = await hre.ethers.getContractAt("EnhancedSmartStaking", stakingAddress);
    
    console.log("📝 EnhancedSmartStaking Configuración:");
    console.log(`   Dirección: ${stakingAddress}`);
    console.log(`   Owner: ${await staking.owner()}`);
    console.log(`   Treasury: ${await staking.treasury()}`);
    console.log(`   MIN_DEPOSIT: ${hre.ethers.formatEther(await staking.MIN_DEPOSIT())} ETH`);
    console.log(`   MAX_DEPOSIT: ${hre.ethers.formatEther(await staking.MAX_DEPOSIT())} ETH`);
    console.log(`   COMMISSION: 6%`);
    console.log(`   Marketplace: ${await staking.marketplaceAddress()}\n`);
    
    // Conectar a GameifiedMarketplace
    const marketplace = await hre.ethers.getContractAt("GameifiedMarketplace", marketplaceAddress);
    
    console.log("📝 GameifiedMarketplace Configuración:");
    console.log(`   Dirección: ${marketplaceAddress}`);
    console.log(`   Owner: ${await marketplace.owner()}`);
    console.log(`   POL Token: ${await marketplace.polToken()}`);
    console.log(`   Staking: ${await marketplace.stakingContract()}`);
    console.log(`   Treasury: ${await marketplace.stakingTreasury()}`);
    console.log(`   MIN_POL_FOR_SKILL_NFT: ${await marketplace.MIN_POL_FOR_SKILL_NFT()} POL`);
    console.log(`   PLATFORM_FEE: ${await marketplace.PLATFORM_FEE_PERCENTAGE()}%\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 2: Hacer Staking
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleStaking() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║              📖 EJEMPLO 2: Hacer Staking                     ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [, user1] = await hre.ethers.getSigners();
    const network = await hre.ethers.provider.getNetwork();
    const deploymentFile = path.join(__dirname, "..", "deployments", `${network.name}-deployment.json`);
    
    if (!fs.existsSync(deploymentFile)) {
        console.log("❌ No hay despliegue guardado.\n");
        return;
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    const stakingAddress = deployment.contracts.EnhancedSmartStaking.address;
    
    const staking = await hre.ethers.getContractAt("EnhancedSmartStaking", stakingAddress);
    
    console.log("📝 Hacer Staking de 100 ETH por 30 días:\n");
    
    const depositAmount = hre.ethers.parseEther("100");
    const lockupDays = 30;
    
    console.log(`   Usuario: ${user1.address}`);
    console.log(`   Monto: 100 ETH`);
    console.log(`   Días de bloqueo: ${lockupDays}`);
    
    // NOTA: En red real, esto requeriría transacción actual
    console.log(`\n   // Código para ejecutar el staking:`);
    console.log(`   const tx = await staking.connect(user1).deposit(${lockupDays}, {`);
    console.log(`       value: hre.ethers.parseEther("100")`);
    console.log(`   });`);
    console.log(`   await tx.wait();\n`);
    
    console.log(`   // Leer información del depósito:`);
    console.log(`   const userInfo = await staking.getUserInfo(user1.address);`);
    console.log(`   console.log("Amount:", ethers.formatEther(userInfo.amount));`);
    console.log(`   console.log("Lock time:", userInfo.lockupTime);\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 3: Ver Recompensas
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleViewRewards() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║            📖 EJEMPLO 3: Ver Recompensas de Staking          ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [, user1] = await hre.ethers.getSigners();
    const network = await hre.ethers.provider.getNetwork();
    const deploymentFile = path.join(__dirname, "..", "deployments", `${network.name}-deployment.json`);
    
    if (!fs.existsSync(deploymentFile)) {
        console.log("❌ No hay despliegue guardado.\n");
        return;
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    const stakingAddress = deployment.contracts.EnhancedSmartStaking.address;
    
    const staking = await hre.ethers.getContractAt("EnhancedSmartStaking", stakingAddress);
    
    console.log("📝 Leer recompensas del usuario:\n");
    console.log(`   Usuario: ${user1.address}\n`);
    
    console.log(`   // Código para ver recompensas:`);
    console.log(`   const rewards = await staking.calculateRewards(user1.address);`);
    console.log(`   console.log("Recompensas:", ethers.formatEther(rewards));\n`);
    
    console.log(`   // Ver información completa:`);
    console.log(`   const userInfo = await staking.getUserInfo(user1.address);`);
    console.log(`   console.log({`);
    console.log(`       amount: ethers.formatEther(userInfo.amount),`);
    console.log(`       lockupTime: new Date(userInfo.lockupTime * 1000),`);
    console.log(`       dailyReturn: userInfo.dailyReturn,`);
    console.log(`       accumulatedRewards: ethers.formatEther(userInfo.accumulatedRewards)`);
    console.log(`   });\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 4: Crear Skill NFT
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleCreateSkillNFT() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║           📖 EJEMPLO 4: Crear Skill NFT                      ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [deployer, user1] = await hre.ethers.getSigners();
    const network = await hre.ethers.provider.getNetwork();
    const deploymentFile = path.join(__dirname, "..", "deployments", `${network.name}-deployment.json`);
    
    if (!fs.existsSync(deploymentFile)) {
        console.log("❌ No hay despliegue guardado.\n");
        return;
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    const marketplaceAddress = deployment.contracts.GameifiedMarketplace.address;
    
    const marketplace = await hre.ethers.getContractAt("GameifiedMarketplace", marketplaceAddress);
    
    console.log("📝 Crear nuevo Skill NFT:\n");
    
    const skillData = {
        name: "STAKE_BOOST_I",
        rarity: 1, // COMMON
        level: 1,
        maxSupply: 1000,
        royaltyPercentage: 5,
        metadataURI: "ipfs://QmXXXXXX...",
    };
    
    console.log(`   Nombre: ${skillData.name}`);
    console.log(`   Rareza: ${skillData.rarity} (COMMON)`);
    console.log(`   Nivel: ${skillData.level}`);
    console.log(`   Max Supply: ${skillData.maxSupply}`);
    console.log(`   Royalty: ${skillData.royaltyPercentage}%\n`);
    
    console.log(`   // Código para crear el NFT:`);
    console.log(`   const tx = await marketplace.connect(deployer).createSkillNFT(`);
    console.log(`       "${skillData.name}",      // Nombre`);
    console.log(`       ${skillData.rarity},        // Rareza`);
    console.log(`       ${skillData.level},         // Nivel`);
    console.log(`       ${skillData.maxSupply},     // Max Supply`);
    console.log(`       ${skillData.royaltyPercentage}, // Royalty %`);
    console.log(`       "${skillData.metadataURI}"  // Metadata URI`);
    console.log(`   );`);
    console.log(`   await tx.wait();`);
    console.log(`\n   const receipt = await tx.wait();`);
    console.log(`   const tokenId = receipt.events[0].args.tokenId;`);
    console.log(`   console.log("NFT creado con ID:", tokenId.toString());\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 5: Listar NFT para Venta
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleListNFTForSale() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║         📖 EJEMPLO 5: Listar NFT para Venta                  ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const network = await hre.ethers.provider.getNetwork();
    const deploymentFile = path.join(__dirname, "..", "deployments", `${network.name}-deployment.json`);
    
    if (!fs.existsSync(deploymentFile)) {
        console.log("❌ No hay despliegue guardado.\n");
        return;
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    const marketplaceAddress = deployment.contracts.GameifiedMarketplace.address;
    
    console.log("📝 Listar NFT para Venta:\n");
    
    const tokenId = 1;
    const price = hre.ethers.parseEther("50");
    
    console.log(`   Token ID: ${tokenId}`);
    console.log(`   Precio: 50 POL`);
    console.log(`   Marketplace: ${marketplaceAddress}\n`);
    
    console.log(`   // Código para listar el NFT:`);
    console.log(`   const tx = await marketplace.connect(owner).listTokenForSale(`);
    console.log(`       ${tokenId},  // Token ID`);
    console.log(`       hre.ethers.parseEther("50")  // Precio en POL`);
    console.log(`   );`);
    console.log(`   await tx.wait();`);
    console.log(`   console.log("NFT listado exitosamente");\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 6: Activar Skill
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleActivateSkill() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║             📖 EJEMPLO 6: Activar Skill                      ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [, user1] = await hre.ethers.getSigners();
    const network = await hre.ethers.provider.getNetwork();
    const deploymentFile = path.join(__dirname, "..", "deployments", `${network.name}-deployment.json`);
    
    if (!fs.existsSync(deploymentFile)) {
        console.log("❌ No hay despliegue guardado.\n");
        return;
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    const stakingAddress = deployment.contracts.EnhancedSmartStaking.address;
    
    console.log("📝 Activar Skill para usuario:\n");
    console.log(`   Usuario: ${user1.address}`);
    console.log(`   Skill: STAKE_BOOST_I (ID: 0)\n`);
    
    console.log(`   // Código para activar skill:`);
    console.log(`   const skillId = 0; // STAKE_BOOST_I`);
    console.log(`   const tx = await staking.connect(user1).activateSkill(skillId);`);
    console.log(`   await tx.wait();`);
    console.log(`\n   // Verificar que se activó:`);
    console.log(`   const userSkills = await staking.getUserSkills(user1.address);`);
    console.log(`   console.log("Skills activos:", userSkills);\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * MAIN: Ejecutar todos los ejemplos
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function main() {
    console.log("\n");
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  📖 EJEMPLOS DE USO - Nuxchain Protocol Contratos            ║");
    console.log("╚════════════════════════════════════════════════════════════════╝");
    
    console.log("\nEste script contiene ejemplos de cómo usar los contratos.");
    console.log("Cada ejemplo muestra el código necesario para ejecutar una acción.\n");
    
    try {
        await readContractConfiguration();
        await exampleStaking();
        await exampleViewRewards();
        await exampleCreateSkillNFT();
        await exampleListNFTForSale();
        await exampleActivateSkill();
        
        console.log("\n╔════════════════════════════════════════════════════════════════╗");
        console.log("║                    ✅ EJEMPLOS COMPLETADOS                    ║");
        console.log("╚════════════════════════════════════════════════════════════════╝\n");
        
        console.log("📌 PRÓXIMOS PASOS:\n");
        console.log("1. Copiar el código de los ejemplos que necesites");
        console.log("2. Adaptarlos a tu aplicación");
        console.log("3. Ejecutar en testnet primero");
        console.log("4. Validar funcionalidad completa\n");
        
    } catch (error) {
        console.error("\n❌ Error durante ejemplos:");
        console.error(error.message);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
