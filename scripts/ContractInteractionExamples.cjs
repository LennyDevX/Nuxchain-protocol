// ════════════════════════════════════════════════════════════════════════════════════════
// EJEMPLOS DE USO COMPLETO - EnhancedSmartStaking v4.0 & GameifiedMarketplace v2.0
// ════════════════════════════════════════════════════════════════════════════════════════
//
// Este archivo contiene ejemplos prácticos de cómo interactuar con los contratos inteligentes
// incluyendo: staking, skills gamificados, marketplace, boosts, auto-compound, y gamificación.
//
// Guardar como: scripts/ContractInteractionExamples.cjs
// Usar con: npx hardhat run scripts/ContractInteractionExamples.cjs --network polygon -- [1-9]
//

const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * UTILIDADES COMUNES
 * ════════════════════════════════════════════════════════════════════════════════════════
 */

async function loadContracts() {
    const network = await hre.ethers.provider.getNetwork();
    const deploymentFile = path.join(__dirname, "..", "deployments", `${network.name}-deployment.json`);
    
    if (!fs.existsSync(deploymentFile)) {
        throw new Error(`No se encontró archivo de despliegue para ${network.name}`);
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    
    const staking = await hre.ethers.getContractAt(
        "EnhancedSmartStaking",
        deployment.contracts.EnhancedSmartStaking.address
    );
    
    const marketplace = await hre.ethers.getContractAt(
        "GameifiedMarketplace",
        deployment.contracts.GameifiedMarketplace.address
    );
    
    return { staking, marketplace, deployment };
}

function formatEther(value) {
    return hre.ethers.formatEther(value);
}

function parseEther(value) {
    return hre.ethers.parseEther(value);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 1: Leer Configuración de Contratos Desplegados
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function readContractConfiguration() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║        📖 EJEMPLO 1: Configuración de Contratos              ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const { staking, marketplace, deployment } = await loadContracts();
    
    console.log("🏦 EnhancedSmartStaking Configuración:");
    console.log(`   📍 Dirección: ${deployment.contracts.EnhancedSmartStaking.address}`);
    console.log(`   👤 Owner: ${await staking.owner()}`);
    console.log(`   💰 Treasury: ${await staking.treasury()}`);
    console.log(`   📊 MIN_DEPOSIT: 10 ETH`);
    console.log(`   📊 MAX_DEPOSIT: 10000 ETH`);
    console.log(`   📊 COMMISSION: 6%`);
    console.log(`   🎮 Marketplace: ${await staking.marketplaceContract()}\n`);
    
    const ADMIN_ROLE = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("ADMIN_ROLE"));
    const [deployer] = await hre.ethers.getSigners();
    
    console.log("🏬 GameifiedMarketplace Configuración:");
    console.log(`   📍 Dirección: ${deployment.contracts.GameifiedMarketplace.address}`);
    console.log(`   👤 Admin: ${await marketplace.hasRole(ADMIN_ROLE, deployer.address) ? 'Sí' : 'No'}`);
    console.log(`   🪙 POL Token: ${await marketplace.polTokenAddress()}`);
    console.log(`   📦 Staking: ${await marketplace.stakingContractAddress()}`);
    console.log(`   💼 Treasury: ${await marketplace.stakingTreasuryAddress()}\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 2: Staking Básico - Depositar y Ver Recompensas
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleBasicStaking() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║              📖 EJEMPLO 2: Staking Básico                   ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [deployer] = await hre.ethers.getSigners();
    const { staking } = await loadContracts();
    
    console.log(`👤 Usuario ejemplo: ${deployer.address}\n`);
    
    const depositAmount = parseEther("100");
    const lockupDays = 30;
    
    console.log("� Hacer Staking de 100 ETH por 30 días:\n");
    console.log(`   const tx = await staking.connect(user1).deposit(${lockupDays}, {`);
    console.log(`       value: hre.ethers.parseEther("100")`);
    console.log(`   });`);
    console.log(`   await tx.wait();\n`);
    
    console.log("📊 Ver información del depósito:\n");
    console.log(`   const userInfo = await staking.getUserInfo(user1.address);`);
    console.log(`   console.log({`);
    console.log(`       totalDeposited: hre.ethers.formatEther(userInfo.totalDeposited),`);
    console.log(`       rewards: hre.ethers.formatEther(userInfo.rewards),`);
    console.log(`       lockupTime: new Date(userInfo.lockupTime * 1000)`);
    console.log(`   });\n`);
    
    console.log("💹 Ver recompensas acumuladas:\n");
    console.log(`   const rewards = await staking.calculateRewards(user1.address);`);
    console.log(`   console.log("Recompensas:", hre.ethers.formatEther(rewards));\n`);
    
    console.log("💡 Nota: Este es un ejemplo de código. Para ejecutarlo, necesitas:");
    console.log("   1. Tener suficiente balance (mínimo 10 ETH)");
    console.log("   2. Conectar tu wallet");
    console.log("   3. Aprobar la transacción\n");
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 3: Sistema de Skills - Crear y Activar Skills
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleSkillSystem() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║         📖 EJEMPLO 3: Sistema de Skills Gamificado          ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [deployer] = await hre.ethers.getSigners();
    const { marketplace } = await loadContracts();
    
    console.log(`👤 Usuario ejemplo: ${deployer.address}\n`);
    
    console.log("🎨 1. Crear Skill NFT:\n");
    const skillTypes = {
        0: "NONE",
        1: "STAKE_BOOST_I       → +5% rewards",
        2: "STAKE_BOOST_II      → +10% rewards",
        3: "STAKE_BOOST_III     → +20% rewards",
        4: "AUTO_COMPOUND       → Reinversión automática",
        5: "LOCK_REDUCER        → -25% lockup time",
        6: "FEE_REDUCER_I       → -10% comisión",
        7: "FEE_REDUCER_II      → -25% comisión"
    };
    
    const rarities = {
        0: "COMMON              → 1.0x",
        1: "UNCOMMON            → 1.25x",
        2: "RARE                → 1.5x",
        3: "EPIC                → 1.75x",
        4: "LEGENDARY           → 2.0x"
    };
    
    console.log(`   Tipos de Skills:`);
    Object.entries(skillTypes).forEach(([id, name]) => {
        if (id !== "0") console.log(`      ${name}`);
    });
    
    console.log(`\n   Rarities (Multiplicadores):`);
    Object.entries(rarities).forEach(([id, name]) => {
        console.log(`      ${name}`);
    });
    
    console.log(`\n   Crear Skill NFT STAKE_BOOST_I con LEGENDARY rarity:`);
    console.log(`   const tx = await marketplace.connect(user1).createSkillNFT(`);
    console.log(`       "ipfs://QmXXX...",  // Token URI`);
    console.log(`       "skills",           // Category`);
    console.log(`       500,                // Royalty (5%)`);
    console.log(`       1,                  // SkillType.STAKE_BOOST_I`);
    console.log(`       4                   // Rarity.LEGENDARY`);
    console.log(`   );\n`);
    
    console.log("📊 Ver Información del Skill:\n");
    console.log(`   const skillProfile = await staking.getUserSkillProfile(user1.address);`);
    console.log(`   console.log({`);
    console.log(`       hasAutoCompound: skillProfile.hasAutoCompound,`);
    console.log(`       boostPercentage: skillProfile.currentBoostPercentage,`);
    console.log(`       lockupReduction: skillProfile.lockupReduction`);
    console.log(`   });\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 4: Sistema de Marketplace - Listar y Comprar NFTs
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleMarketplace() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║         📖 EJEMPLO 4: Marketplace - Listar y Comprar       ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [deployer] = await hre.ethers.getSigners();
    const { marketplace } = await loadContracts();
    
    console.log(`👤 Usuario ejemplo: ${deployer.address}\n`);
    
    console.log("🏷️  1. Listar NFT para Venta:\n");
    console.log(`   const tokenId = 0; // ID del NFT a listar`);
    console.log(`   const price = hre.ethers.parseEther("50"); // Precio en POL`);
    console.log(`   \n   const tx = await marketplace.connect(user1).listTokenForSale(`);
    console.log(`       tokenId,`);
    console.log(`       price`);
    console.log(`   );`);
    console.log(`   await tx.wait();\n`);
    
    console.log("🛒 2. Comprar NFT:\n");
    console.log(`   const tx = await marketplace.connect(user2).buyToken(tokenId, {`);
    console.log(`       value: price`);
    console.log(`   });`);
    console.log(`   await tx.wait();\n`);
    
    console.log("💰 3. Sistema de Ofertas:\n");
    console.log(`   // Hacer oferta`);
    console.log(`   const offerAmount = hre.ethers.parseEther("40");`);
    console.log(`   const tx = await marketplace.connect(user2).makeOffer(`);
    console.log(`       tokenId,`);
    console.log(`       offerAmount,`);
    console.log(`       7  // Expira en 7 días`);
    console.log(`   );`);
    console.log(`   await tx.wait();\n`);
    
    console.log(`   // Aceptar oferta`);
    console.log(`   const tx = await marketplace.connect(user1).acceptOffer(`);
    console.log(`       tokenId,`);
    console.log(`       0  // índice de la oferta`);
    console.log(`   );`);
    console.log(`   await tx.wait();\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 5: Sistema de Gamificación - XP, Niveles y Logros
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleGamification() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║      📖 EJEMPLO 5: Gamificación - XP, Niveles y Logros    ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [deployer] = await hre.ethers.getSigners();
    const { marketplace } = await loadContracts();
    
    console.log(`👤 Usuario ejemplo: ${deployer.address}\n`);
    
    console.log("👥 1. Obtener Perfil de Usuario:\n");
    console.log(`   const profile = await marketplace.getUserProfile(user1.address);`);
    console.log(`   console.log({`);
    console.log(`       level: profile.currentLevel,`);
    console.log(`       totalXP: profile.totalXP.toString(),`);
    console.log(`       nftsCreated: profile.nftsCreated.toString(),`);
    console.log(`       nftsBought: profile.nftsBought.toString()`);
    console.log(`   });\n`);
    
    console.log("❤️  2. Social Features - Likes y Comentarios:\n");
    console.log(`   // Dar like a un NFT (gana 1 XP)`);
    console.log(`   const tx = await marketplace.connect(user1).toggleLike(tokenId);`);
    console.log(`   await tx.wait();\n`);
    
    console.log(`   // Comentar en un NFT (gana 2 XP)`);
    console.log(`   const tx = await marketplace.connect(user1).addComment(`);
    console.log(`       tokenId,`);
    console.log(`       "¡Me encanta este NFT!"`);
    console.log(`   );`);
    console.log(`   await tx.wait();\n`);
    
    console.log("🏆 3. XP Rewards:\n");
    console.log(`   Crear NFT:       +10 XP`);
    console.log(`   Vender NFT:      +20 XP`);
    console.log(`   Comprar NFT:     +15 XP`);
    console.log(`   Like:            +1 XP`);
    console.log(`   Comentar:        +2 XP`);
    console.log(`   Referral:        +50 XP\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 6: Auto-Compound - Reinversión Automática
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleAutoCompound() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║    📖 EJEMPLO 6: Auto-Compound - Reinversión Automática   ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [deployer] = await hre.ethers.getSigners();
    const { staking, marketplace } = await loadContracts();
    
    console.log(`👤 Usuario ejemplo: ${deployer.address}\n`);
    
    console.log("⚙️  1. Activar Auto-Compound:\n");
    console.log(`   // Requiere skill AUTO_COMPOUND (SkillType = 4)`);
    console.log(`   // El marketplace notifica al staking automáticamente\n`);
    
    console.log("🔄 2. Verificar Estado de Auto-Compound:\n");
    console.log(`   const skillProfile = await staking.getUserSkillProfile(user1.address);`);
    console.log(`   const hasAutoCompound = skillProfile.hasAutoCompound;`);
    console.log(`   console.log("Auto-Compound activo:", hasAutoCompound);\n`);
    
    console.log("� 3. Forzar Auto-Compound Manual:\n");
    console.log(`   const performData = hre.ethers.AbiCoder.defaultAbiCoder().encode(`);
    console.log(`       ["address"],`);
    console.log(`       [user1.address]`);
    console.log(`   );`);
    console.log(`   const tx = await staking.performAutoCompound(performData);`);
    console.log(`   await tx.wait();\n`);
    
    console.log("📊 4. Ver Efecto del Auto-Compound:\n");
    console.log(`   const totalBefore = await staking.getTotalDeposit(user1.address);`);
    console.log(`   // ... esperar 24 horas ...\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * EJEMPLO 7: Boosts de Skills - Cálculos y Multiplicadores
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function exampleSkillBoosts() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║      📖 EJEMPLO 7: Boosts de Skills - Recompensas Extra   ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [deployer] = await hre.ethers.getSigners();
    const { staking } = await loadContracts();
    
    console.log(`👤 Usuario ejemplo: ${deployer.address}\n`);
    
    console.log("📈 1. STAKE_BOOST Skills:\n");
    console.log(`   SkillType 1: STAKE_BOOST_I    → +5% a recompensas`);
    console.log(`   SkillType 2: STAKE_BOOST_II   → +10% a recompensas`);
    console.log(`   SkillType 3: STAKE_BOOST_III  → +20% a recompensas\n`);
    console.log(`   Los boosts se acumulan: BOOST_I + BOOST_II = 15% extra\n`);
    
    console.log("💸 2. FEE_REDUCER Skills:\n");
    console.log(`   SkillType 6: FEE_REDUCER_I    → -10% comisión`);
    console.log(`   SkillType 7: FEE_REDUCER_II   → -25% comisión\n`);
    console.log(`   Base commission: 6%`);
    console.log(`   With FEE_REDUCER_I: 6% - 10% = 5.4%`);
    console.log(`   With FEE_REDUCER_II: 6% - 25% = 4.5%\n`);
    
    console.log("🔒 3. LOCK_REDUCER Skill:\n");
    console.log(`   SkillType 5: LOCK_REDUCER → -25% tiempo de bloqueo\n`);
    console.log(`   Ejemplo:`);
    console.log(`   Deposit lockup: 90 días`);
    console.log(`   With LOCK_REDUCER: 90 * 0.75 = 67.5 días\n`);
}

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * MAIN: Menú de Ejemplos
 * ════════════════════════════════════════════════════════════════════════════════════════
 */
async function main() {
    console.log("\n");
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  📚 EJEMPLOS DE INTERACCIÓN - EnhancedSmartStaking v4.0.0   ║");
    console.log("║        & GameifiedMarketplace Gamification System v2.0         ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    console.log("Opciones disponibles:\n");
    console.log("  0 → Todas las configuraciones (default)");
    console.log("  1 → Leer configuración de contratos");
    console.log("  2 → Staking básico");
    console.log("  3 → Sistema de Skills");
    console.log("  4 → Marketplace");
    console.log("  5 → Gamificación");
    console.log("  6 → Auto-Compound");
    console.log("  7 → Boosts de Skills\n");
    
    // Buscar el parámetro en el objeto global hre
    let exampleNumber = "0";
    
    // Verificar si se pasó como propiedad del hre
    if (typeof hre !== 'undefined' && hre.example) {
        exampleNumber = hre.example;
    }
    
    // Ejecutar todas las demostraciones por defecto
    try {
        await readContractConfiguration();
        await exampleBasicStaking();
        await exampleSkillSystem();
        await exampleMarketplace();
        await exampleGamification();
        await exampleAutoCompound();
        await exampleSkillBoosts();
        
        console.log("\n╔════════════════════════════════════════════════════════════════╗");
        console.log("║                    ✅ EJEMPLOS COMPLETADOS                    ║");
        console.log("╚════════════════════════════════════════════════════════════════╝\n");
        
    } catch (error) {
        console.error("\n❌ Error:", error.message);
        process.exit(1);
    }
}

main();
