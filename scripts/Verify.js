const { run } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  
  // Obtener las direcciones de los contratos desplegados
  // Estas direcciones deberían ser almacenadas después del despliegue o provistas como argumentos
  const tokenAddress = process.env.TOKEN_ADDRESS;
  const gameAddress = process.env.GAME_ADDRESS;

  if (!tokenAddress || !gameAddress) {
    console.error("Error: Las direcciones de los contratos deben definirse como variables de entorno (TOKEN_ADDRESS y GAME_ADDRESS)");
    process.exit(1);
  }

  console.log("Iniciando verificación de contratos en Etherscan...");

  try {
    // Verificar el contrato del token
    console.log(`\nVerificando token NUVOS en ${tokenAddress}...`);
    await run("verify:verify", {
      address: tokenAddress,
      constructorArguments: [deployer.address],
      contract: "contracts/NUVOSToken.sol:NUVOToken"
    });
    console.log("Token NUVOS verificado exitosamente");

    // Verificar el contrato del juego
    console.log(`\nVerificando contrato AgentMiningContract en ${gameAddress}...`);
    await run("verify:verify", {
      address: gameAddress,
      constructorArguments: [tokenAddress],
      contract: "contracts/AgentMiningContract.sol:AgentMiningContract"
    });
    console.log("Contrato de juego verificado exitosamente");

    console.log("\nVerificación completada con éxito!");
  } catch (error) {
    console.error("Error durante la verificación:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error no manejado:", error);
    process.exit(1);
  });
