const { ethers } = require("hardhat");
const hre = require("hardhat");

// Configuración de contratos para verificar
const CONTRACTS_TO_VERIFY = [
    {
        name: "TokenizationApp",
        address: "0xe8f1A205ACf4dBbb08d6d8856ae76212B9AE7582",
        constructorArgs: [] // Removed the token address argument since the contract has no constructor parameters
    },
    
    // Agrega más contratos según necesites
];

async function verifyContract(contractName, contractAddress, constructorArgs = []) {
    console.log(`\n🔍 Verificando contrato ${contractName} en ${contractAddress}...`);
    
    try {
        await hre.run("verify:verify", {
            address: contractAddress,
            constructorArguments: constructorArgs,
        });
        console.log(`✅ ${contractName} verificado exitosamente!`);
        return true;
    } catch (error) {
        if (error.message.toLowerCase().includes("already verified")) {
            console.log(`ℹ️  ${contractName} ya está verificado`);
            return true;
        } else {
            console.error(`❌ Error verificando ${contractName}:`, error.message);
            return false;
        }
    }
}

async function checkContractExists(address) {
    try {
        const code = await ethers.provider.getCode(address);
        return code !== "0x";
    } catch (error) {
        console.error(`Error verificando existencia del contrato en ${address}:`, error.message);
        return false;
    }
}

async function main() {
    console.log("🚀 Iniciando verificación de contratos en Polygon Mainnet...");
    console.log(`📡 Red: ${hre.network.name}`);
    
    // Verificar que estamos en la red correcta
    if (hre.network.name !== "polygon" && hre.network.name !== "matic") {
        console.error("❌ Este script debe ejecutarse en la red Polygon Mainnet");
        console.log("💡 Ejecuta: npx hardhat run scripts/Verify.js --network polygon");
        return;
    }

    let successCount = 0;
    let totalContracts = CONTRACTS_TO_VERIFY.length;

    for (const contract of CONTRACTS_TO_VERIFY) {
        console.log(`\n📋 Procesando: ${contract.name}`);
        
        // Verificar que el contrato existe en la dirección
        const exists = await checkContractExists(contract.address);
        if (!exists) {
            console.error(`❌ No se encontró código de contrato en ${contract.address}`);
            continue;
        }

        // Verificar el contrato
        const verified = await verifyContract(
            contract.name,
            contract.address,
            contract.constructorArgs
        );
        
        if (verified) {
            successCount++;
            console.log(`🔗 Ver en PolygonScan: https://polygonscan.com/address/${contract.address}#code`);
        }

        // Pausa entre verificaciones para evitar rate limiting
        if (CONTRACTS_TO_VERIFY.indexOf(contract) < CONTRACTS_TO_VERIFY.length - 1) {
            console.log("⏱️  Esperando 5 segundos...");
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }

    console.log(`\n📊 Resumen de verificación:`);
    console.log(`✅ Contratos verificados: ${successCount}/${totalContracts}`);
    
    if (successCount === totalContracts) {
        console.log("🎉 ¡Todos los contratos fueron verificados exitosamente!");
    } else {
        console.log("⚠️  Algunos contratos no pudieron ser verificados. Revisa los errores arriba.");
    }
}

// Función auxiliar para verificar un contrato individual
async function verifySingleContract(address, constructorArgs = [], contractName = "") {
    console.log(`🔍 Verificando contrato individual en ${address}...`);
    
    const exists = await checkContractExists(address);
    if (!exists) {
        console.error(`❌ No se encontró código de contrato en ${address}`);
        return;
    }

    await verifyContract(contractName || "Contract", address, constructorArgs);
}

// Ejecutar el script principal
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error("💥 Error ejecutando el script:", error);
            process.exit(1);
        });
}

module.exports = {
    verifyContract,
    verifySingleContract,
    checkContractExists
};