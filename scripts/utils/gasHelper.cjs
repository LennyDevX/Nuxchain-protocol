const { ethers } = require("hardhat");

/**
 * Calcula el precio de gas optimizado para Polygon
 * @param {number} bufferPercent - Porcentaje de buffer sobre el precio recomendado (default: 20)
 * @returns {Promise<{maxFeePerGas: bigint, maxPriorityFeePerGas: bigint}>}
 */
async function getOptimizedGasPrice(bufferPercent = 20) {
  const feeData = await ethers.provider.getFeeData();
  
  console.log(`📊 Gas actual de la red:`);
  console.log(`   MaxFeePerGas: ${ethers.formatUnits(feeData.maxFeePerGas, "gwei")} Gwei`);
  console.log(`   MaxPriorityFee: ${ethers.formatUnits(feeData.maxPriorityFeePerGas, "gwei")} Gwei`);
  
  // Aplicar buffer configurable
  const multiplier = BigInt(100 + bufferPercent);
  const maxFeePerGas = (feeData.maxFeePerGas * multiplier) / BigInt(100);
  const maxPriorityFeePerGas = (feeData.maxPriorityFeePerGas * multiplier) / BigInt(100);
  
  console.log(`\n🔥 Usando (con +${bufferPercent}% buffer):`);
  console.log(`   MaxFeePerGas: ${ethers.formatUnits(maxFeePerGas, "gwei")} Gwei`);
  console.log(`   MaxPriorityFee: ${ethers.formatUnits(maxPriorityFeePerGas, "gwei")} Gwei`);
  
  return { maxFeePerGas, maxPriorityFeePerGas };
}

/**
 * Estima el costo de deployment
 * @param {any} contractFactory - Factory del contrato
 * @param {Array} constructorArgs - Argumentos del constructor
 * @param {bigint} maxFeePerGas - Precio máximo de gas
 * @returns {Promise<{gasEstimate: bigint, estimatedCost: bigint}>}
 */
async function estimateDeploymentCost(contractFactory, constructorArgs, maxFeePerGas) {
  try {
    const deployTx = contractFactory.getDeployTransaction(...constructorArgs);
    const gasEstimate = await ethers.provider.estimateGas({
      data: deployTx.data
    });
    const estimatedCost = (gasEstimate * maxFeePerGas) / BigInt(10**18);
    
    return { gasEstimate, estimatedCost };
  } catch (error) {
    console.warn("⚠️  No se pudo estimar el gas:", error.message);
    return { gasEstimate: BigInt(0), estimatedCost: BigInt(0) };
  }
}

/**
 * Obtiene información detallada de la transacción después del deployment
 * @param {any} contract - Contrato desplegado
 * @param {string} networkName - Nombre de la red
 * @returns {Promise<object>}
 */
async function getDeploymentInfo(contract, networkName) {
  const contractAddress = await contract.getAddress();
  const deployTx = contract.deploymentTransaction();
  const receipt = await deployTx.wait();
  
  const gasUsed = receipt.gasUsed;
  const gasPrice = receipt.gasPrice || receipt.effectiveGasPrice;
  const totalCost = gasUsed * gasPrice;
  
  const tokenSymbol = networkName === "polygon" || networkName === "polygonAmoy" ? "POL" : "ETH";
  
  return {
    address: contractAddress,
    txHash: deployTx.hash,
    gasUsed,
    gasPrice,
    totalCost,
    tokenSymbol,
    receipt
  };
}

module.exports = {
  getOptimizedGasPrice,
  estimateDeploymentCost,
  getDeploymentInfo
};
