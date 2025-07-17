const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");

// Configuración predeterminada
const DEFAULT_CONFIG = {
    registrationDuration: 7 * 24 * 60 * 60,  // 7 días
    claimDelay: 1 * 24 * 60 * 60,            // 1 día 
    claimDuration: 30 * 24 * 60 * 60,        // 30 días
    fundAmount: ethers.parseEther("1000")     // 1000 tokens para fondear
};

async function main() {
    console.log("🚀 Iniciando creación de nuevo Airdrop...");
    console.log(`📡 Red: ${network.name}`);
    
    const [deployer] = await ethers.getSigners();
    const deployerBalance = await ethers.provider.getBalance(deployer.address);
    
    console.log(`👤 Creador: ${deployer.address}`);
    console.log(`💰 Balance: ${ethers.formatEther(deployerBalance)} ${network.name === "polygon" ? "POL" : "ETH"}`);

    // 1. CONFIGURACIÓN - Puedes modificar estos valores
    const config = await getAirdropConfig();
    
    // 2. VALIDACIONES
    await validateConfiguration(config);
    
    // 3. CONEXIÓN AL FACTORY
    const factory = await connectToFactory(config.factoryAddress);
    
    // 4. CREAR AIRDROP
    console.log("\n🏭 Creando nuevo airdrop a través del Factory...");
    const airdropAddress = await createAirdrop(factory, config);
    
    // 5. VERIFICAR AIRDROP CREADO
    console.log("\n🔍 Verificando airdrop creado...");
    await verifyAirdrop(airdropAddress, config);
    
    // 6. FONDEAR AIRDROP (OPCIONAL)
    if (config.autoFund) {
        console.log("\n💰 Fondeando airdrop automáticamente...");
        await fundAirdrop(airdropAddress, config);
    }
    
    // 7. GUARDAR INFORMACIÓN
    await saveAirdropInfo(airdropAddress, config);
    
    // 8. MOSTRAR RESUMEN
    await showSummary(airdropAddress, config);
    
    console.log("\n✅ ¡Airdrop creado exitosamente!");
}

async function getAirdropConfig() {
    // Leer configuración desde archivo o usar valores por defecto
    const configPath = path.join(__dirname, "..", "config", "airdrop-config.json");
    let config = { ...DEFAULT_CONFIG };
    
    if (fs.existsSync(configPath)) {
        console.log("📄 Cargando configuración desde archivo...");
        const fileConfig = JSON.parse(fs.readFileSync(configPath, "utf8"));
        
        // Convertir fundAmount de string a BigInt si es necesario
        if (typeof fileConfig.fundAmount === "string") {
            fileConfig.fundAmount = BigInt(fileConfig.fundAmount);
        }
        
        config = { ...DEFAULT_CONFIG, ...fileConfig };
    } else {
        console.log("⚙️ Usando configuración por defecto...");
    }

    // Obtener direcciones desde deployments
    const deploymentsPath = path.join(__dirname, "..", "deployments", `${network.name}.json`);
    if (!fs.existsSync(deploymentsPath)) {
        throw new Error(`❌ No se encontró archivo de deployments para ${network.name}`);
    }
    
    const deployments = JSON.parse(fs.readFileSync(deploymentsPath, "utf8"));
    
    // Dirección oficial del token POL en Polygon
    const POL_TOKEN_ADDRESS = "0x0000000000000000000000000000000000001010";
    
    const airdropConfig = {
        // Direcciones desde deployments
        factoryAddress: deployments.AirdropFactory,
        tokenAddress: config.tokenAddress || POL_TOKEN_ADDRESS,
        
        // Parámetros de tiempo
        registrationDuration: config.registrationDuration,
        claimDelay: config.claimDelay,
        claimDuration: config.claimDuration,
        
        // Configuración del airdrop
        name: config.name || `POL Airdrop ${new Date().toLocaleDateString()}`,
        fundAmount: config.fundAmount,
        autoFund: config.autoFund || false,
        
        // Metadatos
        description: config.description || "Airdrop de tokens POL",
        category: config.category || "community"
    };

    console.log("\n📋 Configuración del Airdrop POL:");
    console.log(`   Factory: ${airdropConfig.factoryAddress}`);
    console.log(`   Token: ${airdropConfig.tokenAddress} (POL)`);
    console.log(`   Nombre: ${airdropConfig.name}`);
    console.log(`   Registro: ${airdropConfig.registrationDuration / (24 * 60 * 60)} días`);
    console.log(`   Delay: ${airdropConfig.claimDelay / (24 * 60 * 60)} días`);
    console.log(`   Claim: ${airdropConfig.claimDuration / (24 * 60 * 60)} días`);
    console.log(`   Cantidad por usuario: 5 POL`);
    console.log(`   Fondeo total: ${ethers.formatEther(airdropConfig.fundAmount)} POL`);
    console.log(`   Auto-fondeo: ${airdropConfig.autoFund ? "Sí" : "No"}`);

    return airdropConfig;
}

async function validateConfiguration(config) {
    console.log("\n🔍 Validando configuración...");
    
    // Validar direcciones
    if (!ethers.isAddress(config.factoryAddress)) {
        throw new Error("❌ Dirección del Factory inválida");
    }
    
    if (!ethers.isAddress(config.tokenAddress) || config.tokenAddress === ethers.ZeroAddress) {
        throw new Error("❌ Dirección del token inválida. Asegúrate de usar la dirección correcta del token POL.");
    }
    
    // Verificar que es la dirección correcta de POL
    const POL_TOKEN_ADDRESS = "0x0000000000000000000000000000000000001010";
    if (config.tokenAddress.toLowerCase() !== POL_TOKEN_ADDRESS.toLowerCase()) {
        console.log("⚠️ ADVERTENCIA: La dirección del token no coincide con POL oficial");
        console.log(`   Configurado: ${config.tokenAddress}`);
        console.log(`   POL oficial: ${POL_TOKEN_ADDRESS}`);
    }
    
    // Validar parámetros de tiempo
    if (config.registrationDuration < 3600) { // Mínimo 1 hora
        throw new Error("❌ Duración de registro muy corta (mínimo 1 hora)");
    }
    
    if (config.claimDelay < 0) {
        throw new Error("❌ Delay de claim no puede ser negativo");
    }
    
    // Validar nombre
    if (!config.name || config.name.length === 0) {
        throw new Error("❌ El nombre del airdrop no puede estar vacío");
    }
    
    console.log("✅ Configuración válida para POL");
}

async function connectToFactory(factoryAddress) {
    console.log("\n🏭 Conectando al AirdropFactory...");
    
    try {
        const factory = await ethers.getContractAt("AirdropFactory", factoryAddress);
        
        // Verificar que el factory existe y es funcional
        const totalAirdrops = await factory.getTotalAirdrops();
        console.log(`📊 Factory encontrado con ${totalAirdrops} airdrops creados`);
        
        return factory;
    } catch (error) {
        throw new Error(`❌ Error conectando al Factory: ${error.message}`);
    }
}

async function createAirdrop(factory, config) {
    console.log("\n🎯 Desplegando nuevo contrato Airdrop...");
    
    try {
        // Estimar gas antes de la transacción
        const gasEstimate = await factory.deployAirdrop.estimateGas(
            config.tokenAddress,
            config.registrationDuration,
            config.claimDelay,
            config.claimDuration,
            config.name
        );
        
        console.log(`⛽ Gas estimado: ${gasEstimate.toString()}`);
        
        // Ejecutar transacción
        const tx = await factory.deployAirdrop(
            config.tokenAddress,
            config.registrationDuration,
            config.claimDelay,
            config.claimDuration,
            config.name,
            { gasLimit: gasEstimate * 120n / 100n } // 20% extra de gas
        );
        
        console.log(`📝 Transacción enviada: ${tx.hash}`);
        console.log("⏳ Esperando confirmación...");
        
        const receipt = await tx.wait();
        console.log(`✅ Confirmado en bloque: ${receipt.blockNumber}`);
        
        // Extraer dirección del evento
        const event = receipt.logs.find(log => 
            log.topics[0] === factory.interface.getEvent("AirdropDeployed").topicHash
        );
        
        if (!event) {
            throw new Error("❌ No se encontró evento AirdropDeployed");
        }
        
        const decodedEvent = factory.interface.parseLog(event);
        const airdropAddress = decodedEvent.args.airdropContract;
        
        console.log("🎉 ¡Airdrop desplegado exitosamente!");
        console.log(`📍 Dirección: ${airdropAddress}`);
        console.log(`👤 Owner: ${decodedEvent.args.owner}`);
        console.log(`🪙 Token: ${decodedEvent.args.token}`);
        console.log(`📛 Nombre: ${decodedEvent.args.name}`);
        console.log(`📊 Índice en Factory: ${decodedEvent.args.index}`);
        
        return airdropAddress;
        
    } catch (error) {
        throw new Error(`❌ Error creando airdrop: ${error.message}`);
    }
}

async function verifyAirdrop(airdropAddress, config) {
    try {
        const airdrop = await ethers.getContractAt("Airdrop", airdropAddress);
        const info = await airdrop.getAirdropInfo();
        
        console.log("📊 Información del airdrop verificada:");
        console.log(`   Token: ${await airdrop.token()}`);
        console.log(`   Owner: ${await airdrop.owner()}`);
        console.log(`   Cantidad por usuario: ${ethers.formatEther(info._airdropAmount)} tokens`);
        console.log(`   Fin registro: ${new Date(Number(info._registrationEndTime) * 1000).toLocaleString()}`);
        console.log(`   Inicio claim: ${new Date(Number(info._claimStartTime) * 1000).toLocaleString()}`);
        console.log(`   Fin claim: ${info._claimEndTime > 0 ? new Date(Number(info._claimEndTime) * 1000).toLocaleString() : "Ilimitado"}`);
        console.log(`   Usuarios registrados: ${info.registeredUsersCount}`);
        console.log(`   Balance del contrato: ${ethers.formatEther(info._contractBalance)} tokens`);
        
    } catch (error) {
        console.error(`⚠️ Error verificando airdrop: ${error.message}`);
    }
}

async function fundAirdrop(airdropAddress, config) {
    try {
        const airdrop = await ethers.getContractAt("Airdrop", airdropAddress);
        
        // Conectar al contrato POL
        const polContract = await ethers.getContractAt([
            "function balanceOf(address) view returns (uint256)",
            "function approve(address,uint256) returns (bool)",
            "function symbol() view returns (string)",
            "function name() view returns (string)",
            "function decimals() view returns (uint8)"
        ], config.tokenAddress);
        
        // Verificar información del token
        const tokenName = await polContract.name();
        const tokenSymbol = await polContract.symbol();
        const tokenDecimals = await polContract.decimals();
        
        console.log(`💰 Token: ${tokenName} (${tokenSymbol})`);
        console.log(`🔢 Decimales: ${tokenDecimals}`);
        
        // Verificar balance del deployer
        const [deployer] = await ethers.getSigners();
        const balance = await polContract.balanceOf(deployer.address);
        
        console.log(`💰 Balance actual: ${ethers.formatEther(balance)} ${tokenSymbol}`);
        
        if (balance < config.fundAmount) {
            console.log(`⚠️ Balance insuficiente. Necesitas ${ethers.formatEther(config.fundAmount)} ${tokenSymbol}`);
            console.log("💡 Puedes obtener POL en:");
            console.log("   - Exchanges como Binance, Coinbase, etc.");
            console.log("   - Bridge desde Ethereum si tienes MATIC");
            console.log("   - Swap en Polygon DEXs como QuickSwap");
            return;
        }
        
        // Aprobar tokens
        console.log("🔓 Aprobando tokens POL...");
        const approveTx = await polContract.approve(airdropAddress, config.fundAmount);
        await approveTx.wait();
        
        // Fondear contrato
        console.log("💸 Fondeando contrato con POL...");
        const fundTx = await airdrop.fundContract(config.fundAmount);
        await fundTx.wait();
        
        console.log(`✅ Airdrop fondeado con ${ethers.formatEther(config.fundAmount)} ${tokenSymbol}`);
        
    } catch (error) {
        console.error(`❌ Error fondeando airdrop: ${error.message}`);
    }
}

async function saveAirdropInfo(airdropAddress, config) {
    console.log("\n💾 Guardando información del airdrop...");
    
    const deploymentsDir = path.join(__dirname, "..", "deployments");
    const filePath = path.join(deploymentsDir, "airdrops.json");
    
    let airdrops = [];
    if (fs.existsSync(filePath)) {
        airdrops = JSON.parse(fs.readFileSync(filePath, "utf8"));
    }
    
    const airdropInfo = {
        address: airdropAddress,
        name: config.name,
        description: config.description,
        category: config.category,
        tokenAddress: config.tokenAddress,
        factoryAddress: config.factoryAddress,
        network: network.name,
        deploymentTime: new Date().toISOString(),
        config: {
            registrationDuration: config.registrationDuration,
            claimDelay: config.claimDelay,
            claimDuration: config.claimDuration,
            fundAmount: config.fundAmount.toString(),
            autoFund: config.autoFund
        }
    };
    
    airdrops.push(airdropInfo);
    
    if (!fs.existsSync(deploymentsDir)) {
        fs.mkdirSync(deploymentsDir, { recursive: true });
    }
    
    fs.writeFileSync(filePath, JSON.stringify(airdrops, null, 2));
    console.log(`✅ Información guardada en ${filePath}`);
}

async function showSummary(airdropAddress, config) {
    console.log("\n" + "=".repeat(60));
    console.log("📋 RESUMEN DEL AIRDROP POL CREADO");
    console.log("=".repeat(60));
    console.log(`🎯 Nombre: ${config.name}`);
    console.log(`📍 Dirección del Airdrop: ${airdropAddress}`);
    console.log(`🪙 Token: POL (${config.tokenAddress})`);
    console.log(`🏭 Factory: ${config.factoryAddress}`);
    console.log(`🌐 Red: ${network.name}`);
    console.log(`💰 Cantidad por usuario: 5 POL`);
    console.log(`📊 Fondeo total: ${ethers.formatEther(config.fundAmount)} POL`);
    
    console.log("\n⏰ CRONOLOGÍA:");
    const now = new Date();
    const registrationEnd = new Date(now.getTime() + config.registrationDuration * 1000);
    const claimStart = new Date(registrationEnd.getTime() + config.claimDelay * 1000);
    const claimEnd = config.claimDuration > 0 ? new Date(claimStart.getTime() + config.claimDuration * 1000) : null;
    
    console.log(`📝 Registro hasta: ${registrationEnd.toLocaleString()}`);
    console.log(`🎁 Claims desde: ${claimStart.toLocaleString()}`);
    console.log(`⏳ Claims hasta: ${claimEnd ? claimEnd.toLocaleString() : "Ilimitado"}`);
    
    console.log("\n🔗 ENLACES ÚTILES:");
    console.log(`   Polygonscan Airdrop: https://polygonscan.com/address/${airdropAddress}`);
    console.log(`   Polygonscan POL Token: https://polygonscan.com/address/${config.tokenAddress}`);
    console.log(`   Factory: https://polygonscan.com/address/${config.factoryAddress}`);
    
    console.log("\n📝 PRÓXIMOS PASOS:");
    console.log("1. 💰 Fondear el airdrop con POL (si no lo hiciste automáticamente)");
    console.log(`   - Necesitas ${ethers.formatEther(config.fundAmount)} POL en tu wallet`);
    console.log("   - Ejecuta: airdrop.fundContract(amount)");
    console.log("2. 📢 Anunciar el airdrop a tu comunidad");
    console.log("3. 👥 Los usuarios se registran con: airdrop.register()");
    console.log("4. 🎁 Los usuarios reclaman 5 POL con: airdrop.claim()");
    console.log("5. 📊 Monitorear estadísticas");
    
    console.log("\n💡 INFORMACIÓN DEL TOKEN POL:");
    console.log("   - POL es el token de gobernanza de Polygon");
    console.log("   - Anteriormente conocido como MATIC");
    console.log("   - 18 decimales estándar");
    console.log("   - Nativo de la red Polygon");
    
    console.log("=".repeat(60));
}

// Función para crear configuración personalizada
async function createConfig() {
    const config = {
        name: "Mi Airdrop Personalizado",
        description: "Descripción del airdrop",
        tokenAddress: "0x...", // Dirección de tu token ERC20
        registrationDuration: 7 * 24 * 60 * 60,  // 7 días
        claimDelay: 1 * 24 * 60 * 60,            // 1 día
        claimDuration: 30 * 24 * 60 * 60,        // 30 días (0 = ilimitado)
        fundAmount: "1000000000000000000000",     // 1000 tokens en string (evita BigInt)
        autoFund: false,                          // Fondear automáticamente
        category: "marketing"
    };
    
    const configDir = path.join(__dirname, "..", "config");
    const configPath = path.join(configDir, "airdrop-config.json");
    
    if (!fs.existsSync(configDir)) {
        fs.mkdirSync(configDir, { recursive: true });
    }
    
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    console.log(`📄 Configuración creada en: ${configPath}`);
    console.log("\n💡 Instrucciones:");
    console.log("1. Edita el archivo config/airdrop-config.json");
    console.log("2. Cambia 'tokenAddress' por la dirección real de tu token ERC20");
    console.log("3. Ajusta los demás parámetros según tus necesidades");
    console.log("4. Ejecuta: npx hardhat run scripts/CreateAirdrop.cjs --network [red]");
}

// Manejar argumentos de línea de comandos
if (process.argv.includes("--create-config")) {
    createConfig()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error("Error creando configuración:", error);
            process.exit(1);
        });
} else {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error("Error:", error);
            process.exit(1);
        });
}
