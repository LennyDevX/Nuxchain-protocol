const { ethers } = require("hardhat");
const hre = require("hardhat");
const fs = require("fs");
const path = require("path");
require('dotenv').config();

/**
 * Script para retirar fondos del contrato SmartStaking
 * 
 * Opciones disponibles:
 * 1. Retirar comisiones pendientes (withdrawPendingCommission)
 * 2. Retiro de emergencia - requiere pausar el contrato primero (emergencyWithdraw)
 * 
 * Uso:
 * npx hardhat run scripts/WithdrawFromSmartStaking.cjs --network polygon
 */

async function main() {
  console.log("🔄 Iniciando retiro de fondos del SmartStaking...");
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

    // Obtener información del contrato
    const contractBalance = await ethers.provider.getBalance(contractAddress);
    const pendingCommission = await contract.pendingCommission();
    const totalPoolBalance = await contract.totalPoolBalance();
    const isPaused = await contract.paused();

    console.log(`\n📊 Estado del contrato:`);
    console.log(`   - Balance total: ${ethers.formatEther(contractBalance)} POL`);
    console.log(`   - Comisiones pendientes: ${ethers.formatEther(pendingCommission)} POL`);
    console.log(`   - Total Pool Balance: ${ethers.formatEther(totalPoolBalance)} POL`);
    console.log(`   - Pausado: ${isPaused}`);

    // Menú de opciones
    console.log(`\n🔧 Opciones de retiro disponibles:`);
    console.log(`   1. Retirar comisiones pendientes (${ethers.formatEther(pendingCommission)} POL)`);
    console.log(`   2. Retiro de emergencia (${ethers.formatEther(contractBalance)} POL) - Pausa automática si es necesario`);
    
    // Para este script, implementaremos ambas opciones
    // El usuario puede modificar esta variable para elegir la opción
    const WITHDRAWAL_OPTION = 2; // Cambiar a 2 para retiro de emergencia con pausa automática
    
    if (WITHDRAWAL_OPTION === 1) {
      // Opción 1: Retirar comisiones pendientes
      await withdrawPendingCommission(contract, pendingCommission);
    } else if (WITHDRAWAL_OPTION === 2) {
      // Opción 2: Retiro de emergencia
      await emergencyWithdraw(contract, contractBalance, signer.address, isPaused);
    }

  } catch (error) {
    console.error(`❌ Error durante el retiro:`, error.message);
    process.exit(1);
  }
}

/**
 * Retira las comisiones pendientes del contrato
 */
async function withdrawPendingCommission(contract, pendingCommission) {
  console.log(`\n💰 Retirando comisiones pendientes...`);
  
  if (pendingCommission.toString() === '0') {
    console.log(`⚠️  No hay comisiones pendientes para retirar`);
    return;
  }

  try {
    console.log(`Monto a retirar: ${ethers.formatEther(pendingCommission)} POL`);
    
    const tx = await contract.withdrawPendingCommission();
    console.log(`Transacción enviada: ${tx.hash}`);
    
    console.log(`Esperando confirmación...`);
    const receipt = await tx.wait();
    console.log(`Transacción confirmada en el bloque: ${receipt.blockNumber}`);
    
    console.log(`✅ Comisiones retiradas exitosamente!`);
    console.log(`📊 Resumen:`);
    console.log(`   - Monto retirado: ${ethers.formatEther(pendingCommission)} POL`);
    console.log(`   - Gas usado: ${receipt.gasUsed.toString()}`);
    
  } catch (error) {
    console.error(`❌ Error retirando comisiones:`, error.message);
    throw error;
  }
}

/**
 * Realiza un retiro de emergencia (pausa automáticamente el contrato si es necesario)
 */
async function emergencyWithdraw(contract, contractBalance, withdrawAddress, isPaused) {
  console.log(`\n🚨 Iniciando retiro de emergencia...`);
  
  if (contractBalance.toString() === '0') {
    console.log(`⚠️  No hay fondos en el contrato para retirar`);
    return;
  }

  try {
    // Pausar el contrato automáticamente si no está pausado
    if (!isPaused) {
      console.log(`⏸️  El contrato no está pausado. Pausando automáticamente...`);
      const pauseTx = await contract.pause();
      console.log(`Transacción de pausa enviada: ${pauseTx.hash}`);
      await pauseTx.wait();
      console.log(`✅ Contrato pausado exitosamente`);
    } else {
      console.log(`✅ El contrato ya está pausado`);
    }

    console.log(`Monto a retirar: ${ethers.formatEther(contractBalance)} POL`);
    console.log(`Dirección de destino: ${withdrawAddress}`);
    
    const tx = await contract.emergencyWithdraw(withdrawAddress);
    console.log(`Transacción enviada: ${tx.hash}`);
    
    console.log(`Esperando confirmación...`);
    const receipt = await tx.wait();
    console.log(`Transacción confirmada en el bloque: ${receipt.blockNumber}`);
    
    console.log(`✅ Retiro de emergencia completado exitosamente!`);
    console.log(`📊 Resumen:`);
    console.log(`   - Monto retirado: ${ethers.formatEther(contractBalance)} POL`);
    console.log(`   - Dirección destino: ${withdrawAddress}`);
    console.log(`   - Gas usado: ${receipt.gasUsed.toString()}`);
    
    console.log(`\n⚠️  IMPORTANTE: El contrato permanece pausado. Usa unpause() para reactivarlo.`);
    
  } catch (error) {
    console.error(`❌ Error en retiro de emergencia:`, error.message);
    throw error;
  }
}

// Función para despausar el contrato (función auxiliar)
async function unpauseContract() {
  const [signer] = await ethers.getSigners();
  const contractAddress = process.env.STAKING_ADDRESS_V2;
  if (!contractAddress) {
    throw new Error('❌ STAKING_ADDRESS_V2 no está definida en el archivo .env');
  }
  const SmartStaking = await ethers.getContractFactory("SmartStaking");
  const contract = SmartStaking.attach(contractAddress);
  
  console.log(`🔄 Despausando el contrato...`);
  const tx = await contract.unpause();
  await tx.wait();
  console.log(`✅ Contrato despausado exitosamente`);
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
  withdrawPendingCommission,
  emergencyWithdraw,
  unpauseContract
};