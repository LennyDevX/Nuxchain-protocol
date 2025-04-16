const { ethers } = require("hardhat");

async function main() {
  try {
    // Dirección de token fija proporcionada
    const tokenAddress = "0x931ee18c4691EF286116952D76BB810D44Ad976a";
    console.log(`Usando dirección de token: ${tokenAddress}`);

    console.log("Iniciando despliegue del sistema modularizado...");
    
    // Obtener las cuentas disponibles
    const [deployer] = await ethers.getSigners();
    console.log(`Desplegando contratos con la cuenta: ${await deployer.getAddress()}`);
    console.log(`Balance de la cuenta: ${ethers.formatEther(await deployer.provider.getBalance(deployer.address))} ETH`);

    // 1. Desplegar el contrato principal del juego
    console.log("\nDesplegando contrato AgentMiningSimple...");
    const AgentMiningSimple = await ethers.getContractFactory("AgentMiningSimple");
    const gameContract = await AgentMiningSimple.deploy(tokenAddress);
    await gameContract.waitForDeployment();
    
    const gameAddress = await gameContract.getAddress();
    console.log(`AgentMiningSimple desplegado en: ${gameAddress}`);

    // 2. Desplegar el contrato Factory
    console.log("\nDesplegando contrato AgentMiningFactory...");
    const AgentMiningFactory = await ethers.getContractFactory("AgentMiningFactory");
    const factoryContract = await AgentMiningFactory.deploy(tokenAddress);
    await factoryContract.waitForDeployment();
    
    const factoryAddress = await factoryContract.getAddress();
    console.log(`AgentMiningFactory desplegado en: ${factoryAddress}`);

    // 3. Desplegar el contrato del Marketplace
    console.log("\nDesplegando contrato AgentMarketplace...");
    const AgentMarketplace = await ethers.getContractFactory("AgentMarketplace");
    const marketplaceContract = await AgentMarketplace.deploy(gameAddress, tokenAddress);
    await marketplaceContract.waitForDeployment();
    
    const marketplaceAddress = await marketplaceContract.getAddress();
    console.log(`AgentMarketplace desplegado en: ${marketplaceAddress}`);

    // 4. Desplegar el contrato del sistema de torneos
    console.log("\nDesplegando contrato TournamentSystem...");
    const TournamentSystem = await ethers.getContractFactory("TournamentSystem");
    const tournamentContract = await TournamentSystem.deploy(tokenAddress);
    await tournamentContract.waitForDeployment();
    
    const tournamentAddress = await tournamentContract.getAddress();
    console.log(`TournamentSystem desplegado en: ${tournamentAddress}`);

    // 5. Registrar los contratos en el Factory
    console.log("\nRegistrando contratos en el Factory...");
    await factoryContract.registerCoreContract(gameAddress);
    console.log("- Core contract registrado");
    
    await factoryContract.registerMarketplace(marketplaceAddress);
    console.log("- Marketplace registrado");
    
    await factoryContract.registerTournament(tournamentAddress);
    console.log("- Tournament system registrado");

    // Verificaciones
    console.log("\nVerificando configuración inicial del juego...");
    const baseRewardPool = await gameContract.baseRewardPool();
    console.log(`Pool de recompensas base: ${ethers.formatEther(baseRewardPool)} NUVOS`);
    
    const currentRewardPool = await gameContract.currentRewardPool();
    console.log(`Pool de recompensas actual: ${ethers.formatEther(currentRewardPool)} NUVOS`);
    
    // Verificar balance real del contrato
    const contractBalance = await token.balanceOf(gameAddress);
    console.log(`Balance real de NUVOS en el contrato: ${ethers.formatEther(contractBalance)} NUVOS`);
    
    const agentLitePrice = await gameContract.agentPrices(0);
    console.log(`Precio agente LITE: ${ethers.formatEther(agentLitePrice)} NUVOS`);
    
    const agentProPrice = await gameContract.agentPrices(1);
    console.log(`Precio agente PRO: ${ethers.formatEther(agentProPrice)} NUVOS`);
    
    const agentMaxPrice = await gameContract.agentPrices(2);
    console.log(`Precio agente MAX: ${ethers.formatEther(agentMaxPrice)} NUVOS`);

    // Obtener instancia del token para aprobaciones (opcional)
    const NUVOToken = await ethers.getContractFactory("NUVOToken");
    const token = NUVOToken.attach(tokenAddress);

    // Aprobar tokens para el contrato del juego (opcional, para tests)
    const approvalAmount = ethers.parseEther("10000");
    console.log(`\nAprobando ${ethers.formatEther(approvalAmount)} tokens para el contrato del juego...`);
    await token.approve(gameAddress, approvalAmount);
    console.log("Aprobación completada");

    // Verificar que los contratos están registrados correctamente
    console.log("\nVerificando registros en el Factory...");
    const addresses = await factoryContract.getContractAddresses();
    console.log(`- Core: ${addresses[0]}`);
    console.log(`- Marketplace: ${addresses[1]}`);
    console.log(`- Tournament: ${addresses[2]}`);
    
    console.log("\n=== Resumen de Despliegue ===");
    console.log(`Token NUVOS usado: ${tokenAddress}`);
    console.log(`Contrato principal de juego: ${gameAddress}`);
    console.log(`Contrato Factory: ${factoryAddress}`);
    console.log(`Contrato Marketplace: ${marketplaceAddress}`);
    console.log(`Contrato TournamentSystem: ${tournamentAddress}`);
    console.log("Despliegue del sistema modularizado completado con éxito!");

  } catch (error) {
    console.error("Error durante el despliegue:", error);
    process.exit(1);
  }
}

// Ejecutar la función de despliegue
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error no manejado:", error);
    process.exit(1);
  });
