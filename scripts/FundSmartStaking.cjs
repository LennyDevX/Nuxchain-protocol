const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log(`Fondeando SmartStaking en la red ${network.name}...`);

  // Obtenemos la wallet que hará el fondeo
  const [deployer] = await ethers.getSigners();
  const deployerBalance = await ethers.provider.getBalance(deployer.address);

  console.log(
    `Cuenta de fondeo: ${deployer.address}`,
    `\nBalance: ${ethers.formatEther(deployerBalance)} ${network.name === 'polygon' ? 'POL' : 'ETH'}`
  );

  // Dirección del contrato SmartStaking desplegado en Polygon
  const contractAddress = "0x21Af69A71611055237B099c915a0aD88a9097A23";
  console.log(`Usando dirección del contrato en Polygon: ${contractAddress}`);

  console.log(`Dirección del contrato SmartStaking: ${contractAddress}`);

  // Conectamos al contrato
  const SmartStaking = await ethers.getContractFactory("SmartStaking");
  const smartStaking = SmartStaking.attach(contractAddress);

  // Verificamos que el deployer sea el owner del contrato
  const owner = await smartStaking.owner();
  if (owner.toLowerCase() !== deployer.address.toLowerCase()) {
    throw new Error(`Solo el owner del contrato puede fondearlo. Owner: ${owner}, Deployer: ${deployer.address}`);
  }

  // Monto a fondear: 10 POL/ETH
  const fundAmount = ethers.parseEther("10");
  console.log(`Monto a fondear: ${ethers.formatEther(fundAmount)} ${network.name === 'polygon' ? 'POL' : 'ETH'}`);

  // Verificamos que tenemos suficiente balance
  if (deployerBalance < fundAmount) {
    throw new Error(`Balance insuficiente. Necesario: ${ethers.formatEther(fundAmount)}, Disponible: ${ethers.formatEther(deployerBalance)}`);
  }

  // Obtenemos el balance del contrato antes del fondeo
  const contractBalanceBefore = await ethers.provider.getBalance(contractAddress);
  console.log(`Balance del contrato antes del fondeo: ${ethers.formatEther(contractBalanceBefore)} ${network.name === 'polygon' ? 'POL' : 'ETH'}`);

  try {
    // Ejecutamos la transacción de fondeo
    console.log("Enviando transacción de fondeo...");
    const tx = await smartStaking.addBalance({ value: fundAmount });
    
    console.log(`Transacción enviada: ${tx.hash}`);
    console.log("Esperando confirmación...");
    
    const receipt = await tx.wait();
    console.log(`Transacción confirmada en el bloque: ${receipt.blockNumber}`);

    // Verificamos el nuevo balance del contrato
    const contractBalanceAfter = await ethers.provider.getBalance(contractAddress);
    console.log(`Balance del contrato después del fondeo: ${ethers.formatEther(contractBalanceAfter)} ${network.name === 'polygon' ? 'POL' : 'ETH'}`);

    // Verificamos el totalPoolBalance del contrato
    const totalPoolBalance = await smartStaking.totalPoolBalance();
    console.log(`Total Pool Balance: ${ethers.formatEther(totalPoolBalance)} ${network.name === 'polygon' ? 'POL' : 'ETH'}`);

    console.log("\n✅ Fondeo completado exitosamente!");
    console.log(`📊 Resumen:`);
    console.log(`   - Monto fondeado: ${ethers.formatEther(fundAmount)} ${network.name === 'polygon' ? 'POL' : 'ETH'}`);
    console.log(`   - Balance anterior: ${ethers.formatEther(contractBalanceBefore)} ${network.name === 'polygon' ? 'POL' : 'ETH'}`);
    console.log(`   - Balance actual: ${ethers.formatEther(contractBalanceAfter)} ${network.name === 'polygon' ? 'POL' : 'ETH'}`);
    console.log(`   - Gas usado: ${receipt.gasUsed.toString()}`);

  } catch (error) {
    console.error("❌ Error durante el fondeo:", error.message);
    throw error;
  }
}

// Función para obtener la dirección del contrato desde deployments (opcional)
function getContractAddress(networkName) {
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  const filePath = path.join(deploymentsDir, `${networkName}.json`);

  if (!fs.existsSync(filePath)) {
    console.log(`Archivo de deployments no encontrado: ${filePath}`);
    return null;
  }

  try {
    const fileContent = fs.readFileSync(filePath, "utf8");
    const deployments = JSON.parse(fileContent);
    return deployments.SmartStaking;
  } catch (error) {
    console.log(`Error leyendo el archivo de deployments: ${error.message}`);
    return null;
  }
}

// Ejecutamos la función principal
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error en el fondeo:", error);
    process.exit(1);
  });