const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
    const [deployer] = await ethers.getSigners();
    const airdropAddress = process.env.AIRDROP_CONTRACT_ADDRESS;
    
    if (!airdropAddress) {
        throw new Error("AIRDROP_CONTRACT_ADDRESS not set in .env");
    }

    // Get contract instance
    const Airdrop = await ethers.getContractFactory("Airdrop");
    const airdrop = Airdrop.attach(airdropAddress);

    // Reduced funding amount
    const fundAmount = ethers.parseEther("0.1"); // Further reduced to 0.1 MATIC for testing

    // Check deployer balance with fixed gas values
    const balance = await ethers.provider.getBalance(deployer.address);
    const gasPrice = (await ethers.provider.getFeeData()).gasPrice;
    const gasLimit = 100000n; // Fixed gas limit
    const totalCost = fundAmount + (gasLimit * gasPrice);

    console.log("\nFunding Airdrop Contract...");
    console.log("Deployer:", deployer.address);
    console.log("Airdrop Contract:", airdropAddress);
    console.log("Amount:", ethers.formatEther(fundAmount), "MATIC");
    console.log("Deployer Balance:", ethers.formatEther(balance), "MATIC");
    console.log("Gas Price:", ethers.formatUnits(gasPrice, "gwei"), "Gwei");
    console.log("Gas Limit:", gasLimit.toString());
    console.log("Estimated total cost:", ethers.formatEther(totalCost), "MATIC");

    if (balance < totalCost) {
        throw new Error("Insufficient balance for funding and gas");
    }

    try {
        // Ensure contract exists
        const code = await ethers.provider.getCode(airdropAddress);
        if (code === "0x") {
            throw new Error("No contract deployed at the specified address");
        }

        console.log("\nFunding Airdrop Contract via fundContract() function...");
        const tx = await airdrop.fundContract({ 
            value: fundAmount,
            gasLimit: 100000n, // Adjust as needed
            gasPrice: gasPrice
        });

        console.log(`Transaction hash: ${tx.hash}`);
        console.log("Waiting for confirmation...");
        
        const receipt = await tx.wait(1);

        if (receipt.status === 0) {
            throw new Error("Transaction failed");
        }

        console.log(`\nFunding successful!`);
        console.log(`Transaction hash: ${receipt.hash}`);
        console.log(`Block number: ${receipt.blockNumber}`);
        console.log(`Gas used: ${receipt.gasUsed}`);

        // Verify final balance
        const contractBalance = await ethers.provider.getBalance(airdropAddress);
        console.log(`\nContract balance: ${ethers.formatEther(contractBalance)} MATIC`);
    } catch (error) {
        console.error("\nError funding contract:");
        if (error.data) {
            console.error(`Revert reason:`, error.data);
        }
        if (error.receipt) {
            console.error(`Transaction failed in block ${error.receipt.blockNumber}`);
            console.error(`Gas used: ${error.receipt.gasUsed.toString()}`);
        }
        if (error.transaction) {
            console.error(`Failed transaction details:`, error.transaction);
        }
        console.error(error.message || error);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });