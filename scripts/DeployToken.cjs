const { ethers } = require("hardhat");

async function main() {
  try {
    console.log("Iniciando despliegue del token NUVOS...");
    
    // Obtener las cuentas disponibles
    const [deployer] = await ethers.getSigners();
    console.log(`Desplegando token con la cuenta: ${await deployer.getAddress()}`);
    console.log(`Balance de la cuenta: ${ethers.formatEther(await deployer.provider.getBalance(deployer.address))} ETH`);

    // Desplegar el token NUVOS
    console.log("\nDesplegando token NUVOS...");
    const NUVOToken = await ethers.getContractFactory("NUVOToken");
    const token = await NUVOToken.deploy(deployer.address);
    await token.waitForDeployment();
    
    const tokenAddress = await token.getAddress();
    console.log(`Token NUVOS desplegado en: ${tokenAddress}`);

    // Verificar suministro inicial
    const totalSupply = await token.totalSupply();
    console.log(`Suministro total inicial: ${ethers.formatEther(totalSupply)} NUVOS`);
    console.log(`Balance del desplegador: ${ethers.formatEther(await token.balanceOf(deployer.address))} NUVOS`);
    
    console.log("\n=== Resumen de Despliegue ===");
    console.log(`Token NUVOS: ${tokenAddress}`);
    console.log("Despliegue del token completado con éxito!");

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
