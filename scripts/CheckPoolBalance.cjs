const { ethers } = require("hardhat");

async function main() {
  try {
    // Dirección del juego por defecto
    let gameAddress = "0x9b17ba3Dc29F2f01e8ccddbBa955E1fD9Ce19902";
    
    // Verificar si se proporcionó otra dirección como argumento
    const args = process.argv.slice(2);
    if (args.length > 0) {
      gameAddress = args[0];
      console.log(`Usando dirección del juego proporcionada como argumento: ${gameAddress}`);
    } else {
      console.log(`Usando dirección del juego por defecto: ${gameAddress}`);
    }
    
    // Dirección del token fija
    const tokenAddress = "0x931ee18c4691EF286116952D76BB810D44Ad976a";
    
    console.log("Iniciando verificación de balances del pool...");
    
    // Obtener las cuentas disponibles
    const [account] = await ethers.getSigners();
    console.log(`Cuenta usada para consulta: ${await account.getAddress()}`);
    
    // Mostrar información de la red
    const network = await ethers.provider.getNetwork();
    console.log(`Red conectada: ${network.name} (Chain ID: ${network.chainId})`);
    
    // Verificar que los contratos existen
    console.log("\nVerificando contratos...");
    
    // Verificar el código del contrato del juego
    const gameCode = await ethers.provider.getCode(gameAddress);
    if (gameCode === "0x" || gameCode === "") {
      console.log(`⚠️ ADVERTENCIA: No se encontró código en la dirección del juego ${gameAddress}`);
      console.log("Asegúrate de estar conectado a la red correcta donde están desplegados los contratos.");
      process.exit(1);
    } else {
      console.log(`✅ Contrato del juego verificado en: ${gameAddress}`);
    }
    
    // Verificar el código del contrato del token
    const tokenCode = await ethers.provider.getCode(tokenAddress);
    if (tokenCode === "0x" || tokenCode === "") {
      console.log(`⚠️ ADVERTENCIA: No se encontró código en la dirección del token ${tokenAddress}`);
      console.log("Asegúrate de estar conectado a la red correcta donde está desplegado el token.");
      process.exit(1);
    } else {
      console.log(`✅ Contrato del token verificado en: ${tokenAddress}`);
    }
    
    try {
      // Cargar los contratos con una interfaz mínima para evitar problemas
      const tokenABI = [
        "function balanceOf(address) view returns (uint256)",
        "function symbol() view returns (string)"
      ];
      
      const gameABI = [
        "function baseRewardPool() view returns (uint256)",
        "function currentRewardPool() view returns (uint256)"
      ];
      
      const token = new ethers.Contract(tokenAddress, tokenABI, account);
      const game = new ethers.Contract(gameAddress, gameABI, account);
      
      // Intentar obtener símbolo del token
      try {
        const symbol = await token.symbol();
        console.log(`\nToken: ${symbol}`);
      } catch (error) {
        console.log("\nNo se pudo obtener el símbolo del token");
      }
      
      // Verificar balances
      try {
        const contractNUVOS = await token.balanceOf(gameAddress);
        console.log(`Balance real de tokens en el contrato: ${ethers.formatEther(contractNUVOS)}`);
      } catch (error) {
        console.log(`⚠️ Error al obtener balance de tokens: ${error.message}`);
      }
      
      // Valores contables internos
      try {
        const basePool = await game.baseRewardPool();
        console.log(`Pool base (contable): ${ethers.formatEther(basePool)}`);
      } catch (error) {
        console.log(`⚠️ Error al obtener pool base: ${error.message}`);
      }
      
      try {
        const currentPool = await game.currentRewardPool();
        console.log(`Pool actual (contable): ${ethers.formatEther(currentPool)}`);
      } catch (error) {
        console.log(`⚠️ Error al obtener pool actual: ${error.message}`);
      }
      
      // Balance de MATIC en el contrato
      try {
        const contractMATIC = await ethers.provider.getBalance(gameAddress);
        console.log(`Balance de MATIC en el contrato: ${ethers.formatEther(contractMATIC)} MATIC`);
      } catch (error) {
        console.log(`⚠️ Error al obtener balance de MATIC: ${error.message}`);
      }
    } catch (error) {
      console.error(`Error al interactuar con contratos: ${error.message}`);
    }

  } catch (error) {
    console.error("Error durante la verificación:", error);
    process.exit(1);
  }
}

// Ejecutar la función principal
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error no manejado:", error);
    process.exit(1);
  });
