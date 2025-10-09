const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

// Configuración del token POL oficial
const POL_TOKEN_ADDRESS = "0x0000000000000000000000000000000000001010";
const POL_ABI = [
    "function balanceOf(address) view returns (uint256)",
    "function approve(address,uint256) returns (bool)",
    "function allowance(address,address) view returns (uint256)",
    "function symbol() view returns (string)",
    "function name() view returns (string)",
    "function decimals() view returns (uint8)",
    "function transfer(address,uint256) returns (bool)"
];

async function main() {
    console.log("💰 Iniciando proceso de fondeo de Airdrop...");
    console.log(`📡 Red: ${network.name}`);
    
    // Verificar que estamos en la red correcta
    if (network.name !== "polygon") {
        console.log("⚠️ ADVERTENCIA: Este script está configurado para Polygon mainnet");
        console.log(`   Red actual: ${network.name}`);
    }

    // Configurar signer con private key del .env
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) {
        throw new Error("❌ PRIVATE_KEY no encontrada en .env");
    }

    const provider = new ethers.JsonRpcProvider(
        process.env.NEXT_PUBLIC_RPC_URL || `https://polygon-mainnet.g.alchemy.com/v2/${process.env.VITE_ALCHEMY}`
    );
    
    const wallet = new ethers.Wallet(privateKey, provider);
    console.log(`👤 Wallet: ${wallet.address}`);
    
    // Verificar balance de POL y ETH
    const polBalance = await ethers.provider.getBalance(wallet.address);
    console.log(`💰 Balance POL: ${ethers.formatEther(polBalance)} POL`);

    // 1. OBTENER DIRECCIÓN DEL AIRDROP
    const airdropAddress = await getAirdropAddress();
    console.log(`🎯 Airdrop a fondear: ${airdropAddress}`);

    // 2. CONFIGURAR CANTIDAD A FONDEAR
    const fundAmount = await getFundAmount();
    console.log(`💸 Cantidad a fondear: ${ethers.formatEther(fundAmount)} POL`);

    // 3. VERIFICAR BALANCE SUFICIENTE
    await verifyBalance(wallet, fundAmount);

    // 4. CONECTAR A CONTRATOS
    const polContract = new ethers.Contract(POL_TOKEN_ADDRESS, POL_ABI, wallet);
    const airdrop = await ethers.getContractAt("Airdrop", airdropAddress, wallet);

    // 5. VERIFICAR INFORMACIÓN DEL TOKEN
    await verifyTokenInfo(polContract);

    // 6. VERIFICAR INFORMACIÓN DEL AIRDROP
    await verifyAirdropInfo(airdrop);

    // 7. APROBAR TOKENS
    await approveTokens(polContract, airdropAddress, fundAmount, wallet);

    // 8. FONDEAR AIRDROP
    await fundAirdrop(airdrop, fundAmount, wallet);

    // 9. VERIFICAR RESULTADO
    await verifyFunding(airdrop, polContract);

    console.log("\n✅ ¡Fondeo completado exitosamente!");
}

async function getAirdropAddress() {
    // Intentar obtener desde argumentos de línea de comandos
    const args = process.argv.slice(2);
    if (args.length > 0 && ethers.isAddress(args[0])) {
        return args[0];
    }

    // Intentar obtener desde .env
    if (process.env.AIRDROP_CONTRACT_ADDRESS && ethers.isAddress(process.env.AIRDROP_CONTRACT_ADDRESS)) {
        return process.env.AIRDROP_CONTRACT_ADDRESS;
    }

    // Intentar obtener desde archivo de airdrops
    const airdropsPath = path.join(__dirname, "..", "deployments", "airdrops.json");
    if (fs.existsSync(airdropsPath)) {
        const airdrops = JSON.parse(fs.readFileSync(airdropsPath, "utf8"));
        if (airdrops.length > 0) {
            console.log("\n📋 Airdrops disponibles:");
            airdrops.forEach((airdrop, index) => {
                console.log(`   ${index}: ${airdrop.name} - ${airdrop.address}`);
            });
            
            // Por defecto usar el último airdrop creado
            const lastAirdrop = airdrops[airdrops.length - 1];
            console.log(`\n🎯 Usando último airdrop: ${lastAirdrop.name}`);
            return lastAirdrop.address;
        }
    }

    throw new Error("❌ No se pudo obtener la dirección del airdrop. Proporciona la dirección como argumento: node scripts/FundAirdrop.cjs 0x...");
}

async function getFundAmount() {
    // Intentar obtener desde argumentos
    const args = process.argv.slice(2);
    if (args.length > 1) {
        const amount = args[1];
        if (!isNaN(amount) && Number(amount) > 0) {
            return ethers.parseEther(amount);
        }
    }

    // Usar cantidad por defecto desde config o 5000 POL
    const defaultAmount = process.env.FUND_AMOUNT || "5000";
    return ethers.parseEther(defaultAmount);
}

async function verifyBalance(wallet, fundAmount) {
    console.log("\n🔍 Verificando balance...");
    
    const balance = await ethers.provider.getBalance(wallet.address);
    
    if (balance < fundAmount) {
        console.log(`❌ Balance insuficiente:`);
        console.log(`   Requerido: ${ethers.formatEther(fundAmount)} POL`);
        console.log(`   Disponible: ${ethers.formatEther(balance)} POL`);
        console.log(`   Faltante: ${ethers.formatEther(fundAmount - balance)} POL`);
        
        console.log("\n💡 Cómo obtener más POL:");
        console.log("   1. Comprar en exchanges (Binance, Coinbase, etc.)");
        console.log("   2. Usar bridge desde Ethereum");
        console.log("   3. Swap en DEXs de Polygon (QuickSwap, SushiSwap)");
        
        throw new Error("Balance insuficiente para realizar el fondeo");
    }
    
    console.log("✅ Balance suficiente para el fondeo");
}

async function verifyTokenInfo(polContract) {
    console.log("\n🔍 Verificando información del token POL...");
    
    try {
        const name = await polContract.name();
        const symbol = await polContract.symbol();
        const decimals = await polContract.decimals();
        
        console.log(`   Nombre: ${name}`);
        console.log(`   Símbolo: ${symbol}`);
        console.log(`   Decimales: ${decimals}`);
        console.log(`   Dirección: ${POL_TOKEN_ADDRESS}`);
        
    } catch (error) {
        console.log("⚠️ No se pudo obtener información del token (normal para POL nativo)");
        console.log("   POL es el token nativo de Polygon");
    }
}

async function verifyAirdropInfo(airdrop) {
    console.log("\n🔍 Verificando información del airdrop...");
    
    try {
        const owner = await airdrop.owner();
        const token = await airdrop.token();
        const airdropAmount = await airdrop.airdropAmount();
        const info = await airdrop.getAirdropInfo();
        
        console.log(`   Owner: ${owner}`);
        console.log(`   Token: ${token}`);
        console.log(`   Cantidad por usuario: ${ethers.formatEther(airdropAmount)} POL`);
        console.log(`   Usuarios registrados: ${info.registeredUsersCount}`);
        console.log(`   Balance actual: ${ethers.formatEther(info._contractBalance)} POL`);
        console.log(`   Registro abierto: ${info._isRegistrationOpen ? "Sí" : "No"}`);
        console.log(`   Claims abiertos: ${info._isClaimOpen ? "Sí" : "No"}`);
        
        // Verificar que el token del airdrop sea POL
        if (token.toLowerCase() !== POL_TOKEN_ADDRESS.toLowerCase()) {
            throw new Error(`❌ El airdrop usa un token diferente: ${token}`);
        }
        
        console.log("✅ Airdrop verificado correctamente");
        
    } catch (error) {
        throw new Error(`❌ Error verificando airdrop: ${error.message}`);
    }
}

async function approveTokens(polContract, airdropAddress, fundAmount, wallet) {
    console.log("\n🔓 Verificando y procesando aprobación...");
    
    try {
        // Para POL nativo, no necesitamos aprobación típica de ERC20
        // POL funciona de manera diferente en Polygon
        console.log("💡 POL es el token nativo de Polygon");
        console.log("   No requiere aprobación tradicional de ERC20");
        console.log("   Se transferirá directamente al contrato");
        
        return true;
        
    } catch (error) {
        console.log(`⚠️ Manejo especial para POL nativo: ${error.message}`);
        return true;
    }
}

async function fundAirdrop(airdrop, fundAmount, wallet) {
    console.log("\n💸 Fondeando airdrop...");
    
    try {
        // Estimar gas para la transacción
        console.log("⛽ Estimando gas...");
        const gasEstimate = await airdrop.fundContract.estimateGas(fundAmount, {
            value: fundAmount // POL se envía como value
        });
        console.log(`   Gas estimado: ${gasEstimate.toString()}`);
        
        // Obtener precio de gas actual
        const gasPrice = await ethers.provider.getFeeData();
        console.log(`   Gas price: ${gasPrice.gasPrice ? ethers.formatUnits(gasPrice.gasPrice, "gwei") : "N/A"} gwei`);
        
        // Ejecutar transacción
        console.log("📝 Enviando transacción...");
        const tx = await airdrop.fundContract(fundAmount, {
            value: fundAmount, // Para POL nativo
            gasLimit: gasEstimate * 120n / 100n // 20% extra de gas
        });
        
        console.log(`   Hash: ${tx.hash}`);
        console.log("⏳ Esperando confirmación...");
        
        const receipt = await tx.wait();
        console.log(`✅ Transacción confirmada en bloque: ${receipt.blockNumber}`);
        console.log(`   Gas usado: ${receipt.gasUsed}`);
        console.log(`   Costo total: ${ethers.formatEther(receipt.gasUsed * receipt.gasPrice)} POL`);
        
        return receipt;
        
    } catch (error) {
        console.error(`❌ Error fondeando airdrop: ${error.message}`);
        
        if (error.message.includes("Ownable: caller is not the owner")) {
            console.log("💡 Solo el owner del airdrop puede fondearlo");
        } else if (error.message.includes("insufficient funds")) {
            console.log("💡 Balance insuficiente para la transacción");
        }
        
        throw error;
    }
}

async function verifyFunding(airdrop, polContract) {
    console.log("\n🔍 Verificando resultado del fondeo...");
    
    try {
        const info = await airdrop.getAirdropInfo();
        const contractBalance = info._contractBalance;
        const estimatedNeeded = await airdrop.getEstimatedTokensNeeded();
        
        console.log("📊 Estado del airdrop después del fondeo:");
        console.log(`   Balance del contrato: ${ethers.formatEther(contractBalance)} POL`);
        console.log(`   Tokens estimados necesarios: ${ethers.formatEther(estimatedNeeded)} POL`);
        console.log(`   Usuarios registrados: ${info.registeredUsersCount}`);
        
        if (contractBalance >= estimatedNeeded) {
            console.log("✅ El airdrop tiene suficientes fondos para todos los usuarios registrados");
        } else {
            console.log("⚠️ El airdrop podría necesitar más fondos si se registran más usuarios");
        }
        
        // Mostrar enlace a Polygonscan
        const airdropAddress = await airdrop.getAddress();
        console.log(`\n🔗 Ver en Polygonscan: https://polygonscan.com/address/${airdropAddress}`);
        
    } catch (error) {
        console.error(`⚠️ Error verificando resultado: ${error.message}`);
    }
}

// Función helper para mostrar ayuda
function showHelp() {
    console.log("📖 Uso del script FundAirdrop:");
    console.log("   node scripts/FundAirdrop.cjs [airdrop_address] [amount_in_pol]");
    console.log("");
    console.log("📝 Ejemplos:");
    console.log("   node scripts/FundAirdrop.cjs");
    console.log("   node scripts/FundAirdrop.cjs 0x1234... 1000");
    console.log("   npx hardhat run scripts/FundAirdrop.cjs --network polygon");
    console.log("");
    console.log("⚙️ Configuración en .env:");
    console.log("   PRIVATE_KEY=tu_private_key");
    console.log("   AIRDROP_CONTRACT_ADDRESS=0x...");
    console.log("   FUND_AMOUNT=5000");
}

// Manejo de argumentos de ayuda
if (process.argv.includes("--help") || process.argv.includes("-h")) {
    showHelp();
    process.exit(0);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n💥 Error en el fondeo:", error.message);
        console.log("\n💡 Consejos:");
        console.log("   1. Verifica que tienes suficiente POL en tu wallet");
        console.log("   2. Asegúrate de ser el owner del airdrop");
        console.log("   3. Verifica que la dirección del airdrop sea correcta");
        console.log("   4. Usa --help para ver opciones de uso");
        process.exit(1);
    });
