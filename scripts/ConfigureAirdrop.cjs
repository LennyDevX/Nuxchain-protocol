const { ethers, network } = require("hardhat");
const config = require("../config/ContractConfig.cjs");
require("dotenv").config();

async function validateConfig(airdropConfig) {
    if (!airdropConfig.tokenAmount || !airdropConfig.startDelay || !airdropConfig.duration) {
        throw new Error("Invalid configuration in ContractConfig.cjs");
    }
}

async function fundContract(airdrop, tokenAmount, wallet) {
    try {
        const balance = await wallet.provider.getBalance(airdrop.target);
        const oneMaticInWei = ethers.parseEther("1.0"); // 1 MATIC para prueba
        
        if (balance < oneMaticInWei) {
            console.log("\nFunding contract...");
            console.log("Current balance:", ethers.formatEther(balance), "MATIC");
            console.log("Funding with:", ethers.formatEther(oneMaticInWei), "MATIC");
            
            const tx = await wallet.sendTransaction({
                to: airdrop.target,
                value: oneMaticInWei,
                gasLimit: 100000
            });
            
            console.log("Funding transaction sent:", tx.hash);
            await tx.wait();
            console.log("Contract funded successfully!");
            
            const newBalance = await wallet.provider.getBalance(airdrop.target);
            console.log("New balance:", ethers.formatEther(newBalance), "MATIC");
        } else {
            console.log("\nContract already has sufficient funds");
            console.log("Current balance:", ethers.formatEther(balance), "MATIC");
        }
    } catch (error) {
        console.error("Error funding contract:", error.message);
        throw error;
    }
}

async function configurePhases(airdrop, startDate, endDate, tokenAmount) {
    const phase1Start = startDate;
    const phase1End = startDate + (endDate - startDate) / 2;
    const phase2Start = phase1End + 1;
    const phase2End = endDate;

    console.log("\nConfiguring phases...");
    console.log("Token amount per phase:", ethers.formatEther(tokenAmount), "MATIC");
    
    // Configurar Fase 1
    console.log("\nConfiguring Phase 1:");
    console.log("Start:", new Date(phase1Start * 1000).toLocaleString());
    console.log("End:", new Date(phase1End * 1000).toLocaleString());
    const phase1Tx = await airdrop.configurePhase(
        1,                // Phase ID
        phase1Start,
        phase1End,
        50,              // 50 participantes
        tokenAmount,     // 5 MATIC por usuario
        { gasLimit: 200000 }
    );
    await phase1Tx.wait();
    console.log("Phase 1 configured");

    // Configurar Fase 2
    console.log("\nConfiguring Phase 2:");
    console.log("Start:", new Date(phase2Start * 1000).toLocaleString());
    console.log("End:", new Date(phase2End * 1000).toLocaleString());
    const phase2Tx = await airdrop.configurePhase(
        2,                // Phase ID
        phase2Start,
        phase2End,
        50,              // 50 participantes
        tokenAmount,     // 5 MATIC por usuario
        { gasLimit: 200000 }
    );
    await phase2Tx.wait();
    console.log("Phase 2 configured");
    
    console.log("\nBoth phases configured successfully!");
}

async function main() {
    // Verify network
    if (network.name === 'hardhat') {
        console.error("\nError: You are trying to deploy on the Hardhat network, which is not allowed.");
        console.error("Please use the --network polygon flag.");
        process.exit(1);
    }

    // Verify environment variables
    const requiredEnvVars = [
        'POLYGON_MAINNET_RPC',
        'PRIVATE_KEY',
        'AIRDROP_CONTRACT_ADDRESS'
    ];

    requiredEnvVars.forEach(envVar => {
        if (!process.env[envVar]) {
            throw new Error(`${envVar} not set in .env`);
        }
    });

    // Configuración del proveedor y wallet
    const provider = new ethers.JsonRpcProvider(process.env.POLYGON_MAINNET_RPC);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    console.log("Configuring with account:", wallet.address);

    // Verificar dirección del contrato
    const airdropAddress = process.env.AIRDROP_CONTRACT_ADDRESS;
    if (!ethers.isAddress(airdropAddress)) {
        throw new Error("Invalid Airdrop contract address");
    }
    console.log("Airdrop contract address:", airdropAddress);

    // Obtener el ABI del contrato
    const AirdropArtifact = require("../artifacts/contracts/AirdropContract.sol/Airdrop.json");
    
    // Crear instancia del contrato
    const airdrop = new ethers.Contract(
        airdropAddress,
        AirdropArtifact.abi,
        wallet
    );

    // Verificar que el contrato existe
    const code = await provider.getCode(airdropAddress);
    if (code === "0x") {
        throw new Error("No contract found at the specified address");
    }

    // Load and validate configuration
    const airdropConfig = config.airdrop;
    await validateConfig(airdropConfig);

    // Calculate dates
    const now = Math.floor(Date.now() / 1000);
    const startDate = now + airdropConfig.startDelay;
    const endDate = startDate + airdropConfig.duration;

    console.log("\nConfiguring Airdrop...");
    console.log("Network:", network.name);
    console.log(`Start Date: ${new Date(startDate * 1000)}`);
    console.log(`End Date: ${new Date(endDate * 1000)}`);
    
    // Convert token amount to BigInt
    const tokenAmount = ethers.parseEther(airdropConfig.tokenAmount.toString());
    console.log(`Token Amount per User: ${ethers.formatEther(tokenAmount)} MATIC`);

    try {
        // Verificar ownership
        const owner = await airdrop.owner();
        if (owner.toLowerCase() !== wallet.address.toLowerCase()) {
            throw new Error(`Deployer is not the contract owner. Owner is ${owner}`);
        }

        // Step 1: Configure main airdrop parameters
        console.log("\nStep 1: Configuring main parameters...");
        const configTx = await airdrop.configureAirdrop(
            0, // AirdropType.MATIC
            ethers.ZeroAddress,
            tokenAmount,  // 5 MATIC
            startDate,
            endDate,
            "MATIC Airdrop Distribution - 5 MATIC per user",
            { gasLimit: 500000 }
        );

        console.log("Transaction sent:", configTx.hash);
        const configReceipt = await configTx.wait();
        console.log("Configuration confirmed in block:", configReceipt.blockNumber);

        // Step 2: Fund the contract
        const totalRequired = tokenAmount * 100n; // Para 100 usuarios (50 por fase)
        await fundContract(airdrop, totalRequired, wallet);

        // Step 3: Configure phases with el mismo amount
        await configurePhases(airdrop, startDate, endDate, tokenAmount);

        // Step 4: Final verification
        const airdropInfo = await airdrop.getAirdropInfo();
        console.log("\nAirdrop Configuration Verified:");
        console.log("- Token Amount:", ethers.formatEther(airdropInfo.tokenAmount), "MATIC");
        console.log("- Start Date:", new Date(Number(airdropInfo.startDate) * 1000));
        console.log("- End Date:", new Date(Number(airdropInfo.endDate) * 1000));
        console.log("- Is Active:", airdropInfo.isActive_);
        console.log("- Remaining Tokens:", ethers.formatEther(airdropInfo.remainingTokens), "MATIC");

    } catch (error) {
        console.error("\nError configuring airdrop:");
        console.error("Message:", error.message);
        console.error("Contract address:", airdropAddress);
        console.error("Network:", network.name);
        if (error.transaction) {
            console.error("Transaction:", error.transaction);
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