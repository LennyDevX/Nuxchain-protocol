const { ethers } = require("hardhat");
const hre = require("hardhat");
require('dotenv').config();

/**
 * Script para despausar el contrato SmartStaking
 * 
 * Este script permite al owner del contrato reactivar el contrato
 * después de que haya sido pausado (por ejemplo, después de un retiro de emergencia)
 * 
 * Uso:
 * npx hardhat run scripts/UnpauseSmartStaking.cjs --network polygon
 */

async function main() {
  console.log("🔄 Iniciando despausa del SmartStaking...");
  console.log(`Red: ${hre.network.name}`);

  const [signer] = await ethers.getSigners();
  console.log(`Cuenta ejecutora: ${signer.address}`);
  
  // Verificar balance de la cuenta
  const signerBalance = await ethers.provider.getBalance(signer.address);
  console.log(`Balance de la cuenta: ${ethers.formatEther(signerBalance)} POL`);

  // Obtener dirección del contrato desde variables de entorno
  const contractAddress = process.env.STAKING_ADDRESS_V2;
  if (!contractAddress) {
    throw new Error('❌ STAKING_ADDRESS_V2 no está definida en el archivo .env');
  }
  console.log(`Dirección del contrato: ${contractAddress}`);

  // Obtener el contrato
  const SmartStaking = await ethers.getContractFactory("SmartStaking");
  const contract = SmartStaking.attach(contractAddress);

  try {
    // Verificar que el ejecutor es el owner
    const owner = await contract.owner();
    if (signer.address.toLowerCase() !== owner.toLowerCase()) {
      throw new Error(`❌ Solo el owner puede ejecutar este script. Owner: ${owner}, Ejecutor: ${signer.address}`);
    }
    console.log(`✅ Verificación de owner exitosa`);

    // Verificar el estado actual del contrato
    const isPaused = await contract.paused();
    console.log(`\n📊 Estado actual del contrato:`);
    console.log(`   - Pausado: ${isPaused}`);

    if (!isPaused) {
      console.log(`\n⚠️  El contrato ya está activo (no pausado)`);
      console.log(`✅ No es necesario realizar ninguna acción`);
      return;
    }

    // Despausar el contrato
    console.log(`\n▶️  Despausando el contrato...`);
    const tx = await contract.unpause();
    console.log(`Transacción enviada: ${tx.hash}`);
    
    console.log(`Esperando confirmación...`);
    const receipt = await tx.wait();
    console.log(`Transacción confirmada en el bloque: ${receipt.blockNumber}`);
    
    // Verificar el nuevo estado
    const newPausedState = await contract.paused();
    
    console.log(`\n✅ Contrato despausado exitosamente!`);
    console.log(`📊 Resumen:`);
    console.log(`   - Estado anterior: Pausado`);
    console.log(`   - Estado actual: ${newPausedState ? 'Pausado' : 'Activo'}`);
    console.log(`   - Gas usado: ${receipt.gasUsed.toString()}`);
    console.log(`   - Hash de transacción: ${tx.hash}`);
    
    console.log(`\n🎉 El contrato SmartStaking está ahora activo y operativo!`);

  } catch (error) {
    console.error(`❌ Error durante la despausa:`, error.message);
    
    // Proporcionar información adicional sobre posibles errores
    if (error.message.includes('Ownable: caller is not the owner')) {
      console.error(`\n💡 Sugerencia: Asegúrate de estar usando la cuenta correcta del owner`);
    } else if (error.message.includes('Pausable: not paused')) {
      console.error(`\n💡 Sugerencia: El contrato ya está activo (no pausado)`);
    }
    
    process.exit(1);
  }
}

/**
 * Función auxiliar para verificar el estado del contrato
 */
async function checkContractStatus() {
  const contractAddress = process.env.STAKING_ADDRESS_V2;
  if (!contractAddress) {
    throw new Error('❌ STAKING_ADDRESS_V2 no está definida en el archivo .env');
  }
  
  const SmartStaking = await ethers.getContractFactory("SmartStaking");
  const contract = SmartStaking.attach(contractAddress);
  
  const isPaused = await contract.paused();
  const owner = await contract.owner();
  const contractBalance = await ethers.provider.getBalance(contractAddress);
  
  console.log(`\n📊 Estado del contrato SmartStaking:`);
  console.log(`   - Dirección: ${contractAddress}`);
  console.log(`   - Owner: ${owner}`);
  console.log(`   - Pausado: ${isPaused}`);
  console.log(`   - Balance: ${ethers.formatEther(contractBalance)} POL`);
  
  return { isPaused, owner, contractBalance };
}

// Ejecutar el script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

// Exportar funciones para uso individual si es necesario
module.exports = {
  checkContractStatus
};