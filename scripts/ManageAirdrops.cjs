const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    
    // Dirección del factory
    const FACTORY_ADDRESS = "0x..."; // Reemplazar con la dirección real
    
    const factory = await ethers.getContractAt("AirdropFactory", FACTORY_ADDRESS);
    
    console.log("🏭 Información del AirdropFactory");
    console.log("Dirección:", FACTORY_ADDRESS);
    console.log("Owner:", await factory.owner());
    
    // Obtener todos los airdrops del usuario
    const userAirdrops = await factory.getAirdropsByOwner(deployer.address);
    console.log(`\n📦 Airdrops creados por ${deployer.address}: ${userAirdrops.length}`);
    
    if (userAirdrops.length === 0) {
        console.log("No hay airdrops creados aún.");
        return;
    }
    
    // Mostrar información de cada airdrop
    for (let i = 0; i < userAirdrops.length; i++) {
        const index = userAirdrops[i];
        const airdropInfo = await factory.getAirdropInfo(index);
        
        console.log(`\n--- Airdrop #${index} ---`);
        console.log("Nombre:", airdropInfo.name);
        console.log("Contrato:", airdropInfo.airdropContract);
        console.log("Token:", airdropInfo.token);
        console.log("Desplegado:", new Date(Number(airdropInfo.deploymentTime) * 1000));
        console.log("Activo:", airdropInfo.isActive);
        
        // Obtener estadísticas del airdrop
        const airdrop = await ethers.getContractAt("Airdrop", airdropInfo.airdropContract);
        const stats = await getAirdropStats(airdrop);
        
        console.log("Estadísticas:");
        console.log("  - Registrados:", stats.registered);
        console.log("  - Reclamado:", stats.claimed);
        console.log("  - Balance:", ethers.formatEther(stats.balance), "tokens");
        console.log("  - Estado:", stats.phase);
    }
    
    // Obtener total de airdrops en el factory
    const totalAirdrops = await factory.getTotalAirdrops();
    console.log(`\n📊 Total de airdrops en el factory: ${totalAirdrops}`);
}

async function getAirdropStats(airdrop) {
    try {
        const info = await airdrop.getAirdropInfo();
        const timeInfo = await airdrop.getTimeInfo();
        
        let phase = "Desconocido";
        const now = Math.floor(Date.now() / 1000);
        
        if (timeInfo.timeUntilRegistrationEnd > 0) {
            phase = "Registro Abierto";
        } else if (timeInfo.timeUntilClaimStart > 0) {
            phase = "Esperando Inicio de Claims";
        } else if (info._claimEndTime === 0n || timeInfo.timeUntilClaimEnd > 0) {
            phase = "Claims Abiertos";
        } else {
            phase = "Finalizado";
        }
        
        return {
            registered: Number(info.registeredUsersCount),
            claimed: Number(info.claimedUsersCount),
            balance: info._contractBalance,
            phase
        };
    } catch (error) {
        return {
            registered: "Error",
            claimed: "Error", 
            balance: "0",
            phase: "Error"
        };
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Error:", error);
        process.exit(1);
    });
