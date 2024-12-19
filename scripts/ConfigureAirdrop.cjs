const { ethers, network } = require("hardhat");
const config = require("../config/ContractConfig.cjs");
require("dotenv").config();

async function main() {
    // Verify network
    if (network.name === 'hardhat') {
        console.error("\nError: You are trying to deploy on the Hardhat network, which is not allowed.");
        console.error("Please use the --network polygon flag.");
        console.error("Example: npx hardhat run scripts/ConfigureAirdrop.cjs --network polygon\n");
        process.exit(1);
    }

    // Verify environment variables
    if (!process.env.POLYGON_MAINNET_RPC) {
        throw new Error("POLYGON_MAINNET_RPC not set in .env");
    }
    if (!process.env.PRIVATE_KEY) {
        throw new Error("PRIVATE_KEY not set in .env");
    }
    if (!process.env.AIRDROP_CONTRACT_ADDRESS) {
        throw new Error("AIRDROP_CONTRACT_ADDRESS not set in .env");
    }

    // Get network
    const [deployer] = await ethers.getSigners();
    console.log("Configuring with account:", deployer.address);

    // Load configuration
    const airdropConfig = config.airdrop;
    
    // Get contract
    const Airdrop = await ethers.getContractFactory("Airdrop");
    const airdrop = Airdrop.attach(process.env.AIRDROP_CONTRACT_ADDRESS);

    // Calculate dates
    const now = Math.floor(Date.now() / 1000);
    const startDate = now + airdropConfig.startDelay;
    const endDate = startDate + airdropConfig.duration;

    console.log("\nConfiguring Airdrop...");
    console.log("Network:", network.name);
    console.log(`Start Date: ${new Date(startDate * 1000)}`);
    console.log(`End Date: ${new Date(endDate * 1000)}`);
    
    // Adjust token amount to be BigInt
    const tokenAmount = BigInt(airdropConfig.tokenAmount);

    console.log(`Token Amount: ${ethers.formatEther(tokenAmount)} MATIC`);

    try {
        // Configure airdrop
        console.log("Sending transaction...");
        const tx = await airdrop.configureAirdrop(
            startDate,
            endDate,
            tokenAmount
        );

        console.log(`Transaction hash: ${tx.hash}`);
        console.log("Waiting for confirmations...");
        
        const receipt = await tx.wait(1); // Wait for 1 confirmation
        
        console.log(`\nAirdrop configured successfully!`);
        console.log(`Transaction hash: ${tx.hash}`);
        console.log(`Block number: ${receipt.blockNumber}`);
        console.log(`Gas used: ${receipt.gasUsed.toString()}`);
    } catch (error) {
        console.error("Error configuring airdrop:", error.message);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });