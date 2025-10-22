const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * ════════════════════════════════════════════════════════════════════════════════════════
 * VERIFY DEPLOYMENT SCRIPT
 * ════════════════════════════════════════════════════════════════════════════════════════
 * 
 * Uso:
 *   npx hardhat run scripts/VerifyDeployment.cjs --network polygon
 * 
 * Verifica que los contratos desplegados están correctamente configurados y conectados.
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║           🔍 VERIFICACIÓN DE DESPLIEGUE                        ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const network = await hre.ethers.provider.getNetwork();
    const deploymentFile = path.join(
        __dirname,
        "..",
        "deployments",
        `${network.name}-deployment.json`
    );
    
    // 1️⃣ Verificar que existe el archivo de despliegue
    console.log("📋 PASO 1: Verificar archivo de despliegue...");
    if (!fs.existsSync(deploymentFile)) {
        console.error(`❌ No se encontró archivo: ${deploymentFile}`);
        console.error("   Ejecuta primero: npx hardhat run scripts/NFTs2.cjs --network ${network.name}\n");
        process.exit(1);
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    console.log(`✅ Archivo encontrado: ${deploymentFile}\n`);
    
    const stakingAddress = deployment.contracts.EnhancedSmartStaking.address;
    const marketplaceAddress = deployment.contracts.GameifiedMarketplace.address;
    
    // 2️⃣ Verificar EnhancedSmartStaking
    console.log("📝 PASO 2: Verificar EnhancedSmartStaking...");
    try {
        const staking = await hre.ethers.getContractAt(
            "EnhancedSmartStaking",
            stakingAddress
        );
        
        console.log(`   Dirección: ${stakingAddress}`);
        
        // Verificar owner
        const owner = await staking.owner();
        console.log(`   Owner: ${owner}`);
        
        // Verificar treasury
        const treasuryAddr = await staking.treasury();
        console.log(`   Treasury: ${treasuryAddr}`);
        
        // Verificar marketplace conoce al staking
        const marketplaceInStaking = await staking.marketplaceAddress();
        console.log(`   Marketplace registrado: ${marketplaceInStaking}`);
        
        if (marketplaceInStaking.toLowerCase() === marketplaceAddress.toLowerCase()) {
            console.log(`   ✅ Marketplace correctamente conectado\n`);
        } else {
            console.warn(`   ⚠️  Marketplace NO conectado correctamente\n`);
        }
        
        // Verificar parámetros clave
        const minDeposit = await staking.MIN_DEPOSIT();
        const maxDeposit = await staking.MAX_DEPOSIT();
        console.log(`   Parámetros:`);
        console.log(`     - MIN_DEPOSIT: ${hre.ethers.formatEther(minDeposit)} ETH`);
        console.log(`     - MAX_DEPOSIT: ${hre.ethers.formatEther(maxDeposit)} ETH`);
        console.log(`     - COMMISSION: 6%`);
        console.log(`     - SKILLS DISPONIBLES: 7 (STAKE_BOOST_I/II/III, AUTO_COMPOUND, LOCK_REDUCER, FEE_REDUCER_I/II)\n`);
        
    } catch (error) {
        console.error(`❌ Error verificando EnhancedSmartStaking: ${error.message}\n`);
    }
    
    // 3️⃣ Verificar GameifiedMarketplace
    console.log("📝 PASO 3: Verificar GameifiedMarketplace...");
    try {
        const marketplace = await hre.ethers.getContractAt(
            "GameifiedMarketplace",
            marketplaceAddress
        );
        
        console.log(`   Dirección: ${marketplaceAddress}`);
        
        // Verificar owner
        const owner = await marketplace.owner();
        console.log(`   Owner: ${owner}`);
        
        // Verificar conexiones
        const polToken = await marketplace.polToken();
        const stakingContract = await marketplace.stakingContract();
        const stakingTreasury = await marketplace.stakingTreasury();
        
        console.log(`   POL Token: ${polToken}`);
        console.log(`   Staking Contract: ${stakingContract}`);
        console.log(`   Staking Treasury: ${stakingTreasury}`);
        
        if (stakingContract.toLowerCase() === stakingAddress.toLowerCase()) {
            console.log(`   ✅ Staking correctamente conectado\n`);
        } else {
            console.warn(`   ⚠️  Staking NO conectado correctamente\n`);
        }
        
        // Verificar parámetros
        const minStakeForSkill = await marketplace.MIN_POL_FOR_SKILL_NFT();
        const platformFee = await marketplace.PLATFORM_FEE_PERCENTAGE();
        
        console.log(`   Parámetros:`);
        console.log(`     - MIN_POL_FOR_SKILL_NFT: ${minStakeForSkill} POL`);
        console.log(`     - PLATFORM_FEE: ${platformFee}%`);
        console.log(`     - FIRST_SKILL_FREE: 1\n`);
        
    } catch (error) {
        console.error(`❌ Error verificando GameifiedMarketplace: ${error.message}\n`);
    }
    
    // 4️⃣ Validar conexión bidireccional
    console.log("📝 PASO 4: Validar conexión bidireccional...");
    try {
        const staking = await hre.ethers.getContractAt(
            "EnhancedSmartStaking",
            stakingAddress
        );
        const marketplace = await hre.ethers.getContractAt(
            "GameifiedMarketplace",
            marketplaceAddress
        );
        
        const stakingKnowsMarketplace = 
            (await staking.marketplaceAddress()).toLowerCase() === 
            marketplaceAddress.toLowerCase();
        
        const marketplaceKnowsStaking = 
            (await marketplace.stakingContract()).toLowerCase() === 
            stakingAddress.toLowerCase();
        
        if (stakingKnowsMarketplace && marketplaceKnowsStaking) {
            console.log("✅ Conexión bidireccional: VÁLIDA\n");
        } else {
            console.warn("⚠️  Problemas en conexión bidireccional:");
            if (!stakingKnowsMarketplace) console.warn("   - Staking no conoce al Marketplace");
            if (!marketplaceKnowsStaking) console.warn("   - Marketplace no conoce al Staking");
            console.log();
        }
    } catch (error) {
        console.error(`❌ Error validando conexión: ${error.message}\n`);
    }
    
    // 5️⃣ Verificar saldos y permisos
    console.log("📝 PASO 5: Verificar saldos...");
    try {
        const provider = hre.ethers.provider;
        
        // Balance del staking
        const stakingBalance = await provider.getBalance(stakingAddress);
        console.log(`   EnhancedSmartStaking balance: ${hre.ethers.formatEther(stakingBalance)} ETH`);
        
        // Balance del marketplace
        const marketplaceBalance = await provider.getBalance(marketplaceAddress);
        console.log(`   GameifiedMarketplace balance: ${hre.ethers.formatEther(marketplaceBalance)} ETH\n`);
        
    } catch (error) {
        console.error(`❌ Error verificando saldos: ${error.message}\n`);
    }
    
    // RESUMEN FINAL
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║                  ✅ VERIFICACIÓN COMPLETADA                    ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    console.log("📊 INFORMACIÓN DE DESPLIEGUE:\n");
    console.log(`   Red: ${deployment.network} (Chain ${deployment.chainId})`);
    console.log(`   Desplegado: ${deployment.deployedAt}`);
    console.log(`   Deployer: ${deployment.deployer}\n`);
    
    console.log("📌 CONTRATOS:\n");
    console.log(`   1. EnhancedSmartStaking`);
    console.log(`      → ${stakingAddress}`);
    console.log(`      → Treasury: ${deployment.contracts.EnhancedSmartStaking.constructor.treasury}\n`);
    
    console.log(`   2. GameifiedMarketplace`);
    console.log(`      → ${marketplaceAddress}`);
    console.log(`      → Staking: ${stakingAddress}\n`);
    
    console.log("🔗 PRÓXIMOS PASOS:\n");
    console.log("1. Usar las direcciones en tu frontend");
    console.log("2. Probar funciones básicas (deposit, createSkillNFT)");
    console.log("3. Ejecutar test suite: npx hardhat test");
    console.log("4. Considerar auditoría antes de mainnet\n");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
