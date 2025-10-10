const { ethers, network } = require("hardhat");

async function main() {
  console.log("🚫 Cancelando transacción pendiente...");
  
  const [deployer] = await ethers.getSigners();
  
  // Obtener el nonce actual
  const currentNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  const latestNonce = await ethers.provider.getTransactionCount(deployer.address, "latest");
  
  console.log(`Nonce actual (pending): ${currentNonce}`);
  console.log(`Nonce latest: ${latestNonce}`);
  
  if (currentNonce === latestNonce) {
    console.log("✅ No hay transacciones pendientes");
    return;
  }
  
  console.log(`⚠️  Hay ${currentNonce - latestNonce} transacción(es) pendiente(s)`);
  console.log("💰 Enviando transacción de cancelación con gas alto...");
  
  // Enviar una transacción a ti mismo con el mismo nonce pero gas más alto
  const cancelTx = await deployer.sendTransaction({
    to: deployer.address,
    value: 0,
    nonce: latestNonce,
    gasLimit: 21000,
    maxFeePerGas: ethers.parseUnits("200", "gwei"),
    maxPriorityFeePerGas: ethers.parseUnits("50", "gwei")
  });
  
  console.log(`📤 Transacción de cancelación enviada: ${cancelTx.hash}`);
  console.log("⏳ Esperando confirmación...");
  
  await cancelTx.wait();
  console.log("✅ Transacción cancelada exitosamente");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error:", error);
    process.exit(1);
  });
