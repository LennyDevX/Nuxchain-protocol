const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
    // Configuración
    const fundAmount = ethers.parseEther("100"); // Fondear con 100 MATIC (suficiente para 20 usuarios)
    const airdropAddress = process.env.AIRDROP_CONTRACT_ADDRESS;

    // Validaciones iniciales
    if (!airdropAddress) {
        throw new Error("AIRDROP_CONTRACT_ADDRESS no está configurado en .env");
    }

    const [signer] = await ethers.getSigners();
    console.log("Fondeando desde la cuenta:", signer.address);
    console.log("Contrato del Airdrop:", airdropAddress);

    // Verificar balance del sender
    const balance = await ethers.provider.getBalance(signer.address);
    console.log("\nBalance actual del sender:", ethers.formatEther(balance), "MATIC");
    console.log("Cantidad a fondear:", ethers.formatEther(fundAmount), "MATIC");

    if (balance < fundAmount) {
        throw new Error("Balance insuficiente para fondear");
    }

    try {
        // Obtener instancia del contrato
        const Airdrop = await ethers.getContractFactory("Airdrop");
        const airdrop = await Airdrop.attach(airdropAddress);

        // Verificar balance actual del contrato
        const contractBalance = await ethers.provider.getBalance(airdropAddress);
        console.log("\nBalance actual del contrato:", ethers.formatEther(contractBalance), "MATIC");

        // Enviar fondos
        console.log("\nEnviando fondos...");
        const tx = await airdrop.fundContract({
            value: fundAmount,
            gasLimit: 100000
        });

        console.log("Transacción enviada:", tx.hash);
        const receipt = await tx.wait();
        console.log("Transacción confirmada en el bloque:", receipt.blockNumber);

        // Verificar nuevo balance
        const newBalance = await ethers.provider.getBalance(airdropAddress);
        console.log("\nNuevo balance del contrato:", ethers.formatEther(newBalance), "MATIC");
        
        // Verificar estado del airdrop
        const airdropInfo = await airdrop.getAirdropInfo();
        console.log("\nEstado del Airdrop:");
        console.log("Tokens por usuario:", ethers.formatEther(airdropInfo.tokenAmount), "MATIC");
        console.log("Inicio:", new Date(Number(airdropInfo.startDate) * 1000).toLocaleString());
        console.log("Fin:", new Date(Number(airdropInfo.endDate) * 1000).toLocaleString());
        console.log("Está activo:", airdropInfo.isActive_);
        console.log("Tokens restantes:", ethers.formatEther(airdropInfo.remainingTokens), "MATIC");
        console.log("Usuarios que han reclamado:", airdropInfo.claimedCount.toString());

    } catch (error) {
        console.error("\nError al fondear el contrato:");
        console.error(error.message);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });