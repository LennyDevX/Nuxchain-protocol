const { execSync } = require("child_process");
const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("\n");
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🚀 DEPLOYMENT COMPLETO - Nuxchain Protocol Smart Contracts  ║");
    console.log("║     EnhancedSmartStaking v4.0 + GameifiedMarketplace v2.0    ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");
    
    const [deployer] = await ethers.getSigners();
    console.log(`📍 Red: ${network.name}`);
    console.log(`👤 Deployer: ${deployer.address}`);
    console.log(`💰 Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH\n`);
    
    console.log("📋 Plan de despliegue:\n");
    console.log("  1️⃣  Desplegar EnhancedSmartStaking");
    console.log("  2️⃣  Desplegar GameifiedMarketplace");
    console.log("  3️⃣  Configurar interconexiones");
    console.log("  4️⃣  Verificar en Polygonscan\n");
    
    try {
        // Step 1: Deploy EnhancedSmartStaking
        console.log("═".repeat(64));
        console.log("PASO 1: Desplegando EnhancedSmartStaking...");
        console.log("═".repeat(64) + "\n");
        
        await deployEnhancedSmartStaking();
        
        // Step 2: Deploy GameifiedMarketplace
        console.log("\n" + "═".repeat(64));
        console.log("PASO 2: Desplegando GameifiedMarketplace...");
        console.log("═".repeat(64) + "\n");
        
        await deployGameifiedMarketplace();
        
        // Step 3: Configure contracts
        console.log("\n" + "═".repeat(64));
        console.log("PASO 3: Configurando interconexiones...");
        console.log("═".repeat(64) + "\n");
        
        await configureContracts();
        
        // Step 4: Print summary
        printSummary();
        
        console.log("\n✅ ¡Despliegue completado exitosamente!\n");
        
    } catch (error) {
        console.error("\n❌ Error durante el despliegue:", error.message);
        process.exit(1);
    }
}

async function deployEnhancedSmartStaking() {
    console.log("Ejecutando: npx hardhat run scripts/DeployEnhancedSmartStaking.cjs --network " + network.name);
    
    try {
        execSync(
            `npx hardhat run scripts/DeployEnhancedSmartStaking.cjs --network ${network.name}`,
            { stdio: "inherit" }
        );
        console.log("\n✅ EnhancedSmartStaking desplegado correctamente");
    } catch (error) {
        throw new Error("Fallo en el despliegue de EnhancedSmartStaking: " + error.message);
    }
}

async function deployGameifiedMarketplace() {
    console.log("Ejecutando: npx hardhat run scripts/DeployGameifiedMarketplace.cjs --network " + network.name);
    
    try {
        execSync(
            `npx hardhat run scripts/DeployGameifiedMarketplace.cjs --network ${network.name}`,
            { stdio: "inherit" }
        );
        console.log("\n✅ GameifiedMarketplace desplegado correctamente");
    } catch (error) {
        throw new Error("Fallo en el despliegue de GameifiedMarketplace: " + error.message);
    }
}

async function configureContracts() {
    const deploymentFile = path.join(__dirname, "..", "deployments", `${network.name}-deployment.json`);
    
    if (!fs.existsSync(deploymentFile)) {
        console.log("⚠️  No se encontró archivo de despliegue");
        return;
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    const stakingAddress = deployment.contracts?.EnhancedSmartStaking?.address;
    const marketplaceAddress = deployment.contracts?.GameifiedMarketplace?.address;
    
    if (!stakingAddress || !marketplaceAddress) {
        console.log("⚠️  Direcciones incompletas en el archivo de despliegue");
        return;
    }
    
    const staking = await ethers.getContractAt("EnhancedSmartStaking", stakingAddress);
    
    // Verificar si ya está configurado
    const currentMarketplace = await staking.marketplaceContract();
    if (currentMarketplace !== "0x0000000000000000000000000000000000000000") {
        console.log(`✅ Marketplace ya configurado en Staking: ${currentMarketplace}`);
        return;
    }
    
    // Configurar marketplace en staking
    console.log(`📝 Estableciendo Marketplace en Staking...`);
    console.log(`   Staking: ${stakingAddress}`);
    console.log(`   Marketplace: ${marketplaceAddress}`);
    
    const tx = await staking.setMarketplaceContract(marketplaceAddress);
    await tx.wait();
    
    console.log(`✅ Configuración completada`);
}

function printSummary() {
    console.log("\n" + "═".repeat(64));
    console.log("RESUMEN DE DESPLIEGUE");
    console.log("═".repeat(64) + "\n");
    
    const deploymentFile = path.join(__dirname, "..", "deployments", `${network.name}-deployment.json`);
    
    if (!fs.existsSync(deploymentFile)) {
        console.log("⚠️  No se encontró archivo de despliegue\n");
        return;
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
    const staking = deployment.contracts?.EnhancedSmartStaking;
    const marketplace = deployment.contracts?.GameifiedMarketplace;
    
    console.log("🏦 EnhancedSmartStaking:");
    if (staking) {
        console.log(`   📍 Dirección: ${staking.address}`);
        console.log(`   📅 Desplegado: ${staking.deployedAt}`);
        console.log(`   🔗 Polygonscan: https://polygonscan.com/address/${staking.address}`);
    } else {
        console.log("   ⚠️  No desplegado");
    }
    
    console.log("\n🛍️  GameifiedMarketplace:");
    if (marketplace) {
        console.log(`   📍 Dirección: ${marketplace.address}`);
        console.log(`   📅 Desplegado: ${marketplace.deployedAt}`);
        console.log(`   🔗 Polygonscan: https://polygonscan.com/address/${marketplace.address}`);
    } else {
        console.log("   ⚠️  No desplegado");
    }
    
    console.log("\n📁 Archivo de configuración:");
    console.log(`   ${deploymentFile}`);
    
    console.log("\n📚 Próximos pasos:\n");
    console.log("1. Verificar contratos en Polygonscan");
    console.log("2. Ejecutar ejemplos de uso:");
    console.log(`   npx hardhat run scripts/ContractInteractionExamples.cjs --network ${network.name} -- 1`);
    console.log("3. Configurar treasury y direcciones de control en ambos contratos");
    console.log("4. Preparar para producción\n");
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
