const hre = require("hardhat");
const { ethers, network, run } = require("hardhat");
const fs = require("fs");
const path = require("path");

// ════════════════════════════════════════════════════════════════════════════════════════
// DEPLOYMENT SCRIPT - EnhancedSmartStaking & GameifiedMarketplace
// ════════════════════════════════════════════════════════════════════════════════════════

// Función para verificar contrato en Etherscan con reintentos
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
            return true;
        } catch (err) {
            const msg = err && err.message ? err.message : String(err);
            if (msg.toLowerCase().includes("already verified") || msg.toLowerCase().includes("reason: already verified")) {
                console.log("   ℹ️ Contrato ya verificado anteriormente.");
                return true;
            }

            attempt < maxAttempts
                ? console.log(`   ⚠️ Intento ${attempt} fallido: ${msg}. Reintentando en ${delayMs / 1000}s...`)
                : console.log(`   ❌ Intento ${attempt} fallido: ${msg}`);

            if (attempt >= maxAttempts) return false;
            await new Promise((resolve) => setTimeout(resolve, delayMs));
        }
    }
}

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║   🚀 DESPLIEGUE DE CONTRATOS - Nuxchain Protocol v2.0          ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    // 1️⃣ OBTENER SIGNERS Y VALIDAR
    console.log("📋 PASO 1: Validar configuración...");
    const [deployer] = await hre.ethers.getSigners();
    console.log(`   ✓ Deployer: ${deployer.address}`);
    
    const network = await hre.ethers.provider.getNetwork();
    console.log(`   ✓ Red: ${network.name} (Chain ID: ${network.chainId})`);
    
    // Validar balance del deployer
    const balance = await hre.ethers.provider.getBalance(deployer.address);
    const balanceInEth = hre.ethers.formatEther(balance);
    console.log(`   ✓ Balance deployer: ${balanceInEth} ETH`);
    
    if (parseFloat(balanceInEth) < 0.1) {
        console.error("   ⚠️  ADVERTENCIA: Balance bajo (<0.1 ETH). El despliegue puede fallar.");
    }
    
    // Configuraciones de dirección
    const treasuryAddress = process.env.TREASURY_ADDRESS || deployer.address;
    const polTokenAddress = process.env.POL_TOKEN_ADDRESS || deployer.address; // Dummy si no existe
    
    console.log(`   ✓ Treasury: ${treasuryAddress}`);
    console.log(`   ✓ POL Token (dummy): ${polTokenAddress}\n`);
    
    // 2️⃣ DESPLEGAR ENHANCED SMART STAKING (sin dependencias)
    console.log("📝 PASO 2: Desplegar EnhancedSmartStaking...");
    try {
        const EnhancedSmartStaking = await hre.ethers.getContractFactory("EnhancedSmartStaking");
        const staking = await EnhancedSmartStaking.deploy(treasuryAddress, {
            gasLimit: 8000000, // Especificar gas limit para contratos complejos
        });
        
        console.log(`   ⏳ Esperando confirmación (${network.confirmations || 1} bloque/s)...`);
        await staking.waitForDeployment();
        
        const stakingAddress = await staking.getAddress();
        console.log(`   ✅ EnhancedSmartStaking desplegado: ${stakingAddress}\n`);
        
        // 3️⃣ DESPLEGAR GAMEIFIED MARKETPLACE
        console.log("📝 PASO 3: Desplegar GameifiedMarketplace...");
        const GameifiedMarketplace = await hre.ethers.getContractFactory("GameifiedMarketplace");
        const gameified = await GameifiedMarketplace.deploy(
            polTokenAddress,      // POL token address (dummy si no existe)
            stakingAddress,       // Staking contract address (recién desplegado)
            treasuryAddress,      // Staking treasury address
            {
                gasLimit: 8000000,
            }
        );
        
        console.log(`   ⏳ Esperando confirmación (${network.confirmations || 1} bloque/s)...`);
        await gameified.waitForDeployment();
        
        const gameifiedAddress = await gameified.getAddress();
        console.log(`   ✅ GameifiedMarketplace desplegado: ${gameifiedAddress}\n`);
        
        // 4️⃣ CONECTAR CONTRATOS
        console.log("📝 PASO 4: Conectar contratos...");
        
        // Marketplace notifica al staking
        console.log(`   ⏳ Configurando marketplace en staking...`);
        const stakingContract = await hre.ethers.getContractAt("EnhancedSmartStaking", stakingAddress);
        const tx1 = await stakingContract.setMarketplaceAddress(gameifiedAddress);
        await tx1.wait();
        console.log(`   ✅ Marketplace conectado al staking: ${gameifiedAddress}`);
        
        // Staking se conoce a sí mismo (configuración interna)
        console.log(`   ✅ Conexión de contratos completada\n`);
        
        // 5️⃣ GUARDAR DIRECCIONES EN JSON
        console.log("📝 PASO 5: Guardar direcciones de despliegue...");
        const deploymentData = {
            network: network.name,
            chainId: network.chainId.toString(),
            deployedAt: new Date().toISOString(),
            deployer: deployer.address,
            contracts: {
                EnhancedSmartStaking: {
                    address: stakingAddress,
                    constructor: {
                        treasury: treasuryAddress,
                    },
                },
                GameifiedMarketplace: {
                    address: gameifiedAddress,
                    constructor: {
                        polToken: polTokenAddress,
                        staking: stakingAddress,
                        stakingTreasury: treasuryAddress,
                    },
                },
            },
            configuration: {
                treasury: treasuryAddress,
                polToken: polTokenAddress,
            },
        };
        
        // Crear carpeta deployments si no existe
        const deploymentsDir = path.join(__dirname, "..", "deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }
        
        // Guardar en archivo JSON
        const filename = path.join(deploymentsDir, `${network.name}-deployment.json`);
        fs.writeFileSync(filename, JSON.stringify(deploymentData, null, 2));
        console.log(`   ✅ Direcciones guardadas en: ${filename}\n`);
        
        // 6️⃣ VERIFICAR CONTRATOS EN ETHERSCAN (si no es localhost)
        if (network.name !== "localhost" && network.name !== "hardhat") {
            console.log("📝 PASO 6: Verificar contratos en Polygonscan...");
            
            console.log(`   ⏳ Verificando EnhancedSmartStaking...`);
            const stakingVerified = await verifyContract(
                stakingAddress,
                "contracts/SmartStaking/EnhancedSmartStaking.sol:EnhancedSmartStaking",
                [treasuryAddress]
            );
            if (stakingVerified) {
                console.log(`   ✅ EnhancedSmartStaking verificado\n`);
            } else {
                console.log(`   ⚠️ No se pudo verificar EnhancedSmartStaking\n`);
            }
            
            console.log(`   ⏳ Verificando GameifiedMarketplace...`);
            const marketplaceVerified = await verifyContract(
                gameifiedAddress,
                "contracts/Marketplace/GameifiedMarketplace.sol:GameifiedMarketplace",
                [polTokenAddress, stakingAddress, treasuryAddress]
            );
            if (marketplaceVerified) {
                console.log(`   ✅ GameifiedMarketplace verificado\n`);
            } else {
                console.log(`   ⚠️ No se pudo verificar GameifiedMarketplace\n`);
            }
        }
        
        // 7️⃣ MOSTRAR RESUMEN
        console.log("╔════════════════════════════════════════════════════════════════╗");
        console.log("║                    ✅ DESPLIEGUE COMPLETADO                    ║");
        console.log("╚════════════════════════════════════════════════════════════════╝\n");
        
        console.log("📊 RESUMEN DE CONTRATOS:\n");
        console.log(`🔹 Red: ${network.name} (Chain ID: ${network.chainId})`);
        console.log(`🔹 Deployer: ${deployer.address}\n`);
        
        console.log("📌 CONTRATO 1: EnhancedSmartStaking");
        console.log(`   Dirección: ${stakingAddress}`);
        console.log(`   Treasury: ${treasuryAddress}`);
        console.log(`   Funciones iniciales:`);
        console.log(`     - deposit(lockupDays) → Hacer staking`);
        console.log(`     - calculateRewards(address) → Ver recompensas`);
        console.log(`     - withdraw() → Retirar ganancias\n`);
        
        console.log("📌 CONTRATO 2: GameifiedMarketplace");
        console.log(`   Dirección: ${gameifiedAddress}`);
        console.log(`   POL Token: ${polTokenAddress}`);
        console.log(`   Staking conectado: ${stakingAddress}`);
        console.log(`   Funciones iniciales:`);
        console.log(`     - createSkillNFT(...) → Crear NFT skill`);
        console.log(`     - listTokenForSale(tokenId, price) → Vender NFT`);
        console.log(`     - buyToken(tokenId) → Comprar NFT\n`);
        
        console.log("🔗 PRÓXIMOS PASOS:\n");
        console.log("1. Copiar direcciones a tu .env o configuración frontend");
        console.log("2. Verificar contratos en Polygonscan (si aplica)");
        console.log("3. Conectar marketplace a staking desde frontend");
        console.log("4. Probar funciones básicas (deposit, createSkillNFT)");
        console.log("5. Auditoría de seguridad antes de ir a mainnet\n");
        
        console.log("📄 Archivo de despliegue generado:");
        console.log(`   → deployments/${network.name}-deployment.json\n`);
        
        return deploymentData;
        
    } catch (error) {
        console.error("\n❌ ERROR DURANTE DESPLIEGUE:");
        console.error(`   ${error.message}\n`);
        
        if (error.data) {
            console.error("   Detalles del error:");
            console.error(`   ${error.data}\n`);
        }
        
        throw error;
    }
}

// Ejecutar
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});