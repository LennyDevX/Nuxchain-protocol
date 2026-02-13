const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    
    // Direcciones
    const CORE_ADDRESS = "0xC67F0a0cB719e4f4358D980a5D966878Fd6f3946";
    const TREASURY_ADDRESS = "0xc4EdBeC38204615e85279dc358605462AED58D6A";
    
    console.log("🔧 Test setTreasuryManager()");
    console.log("━".repeat(70));
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Core: ${CORE_ADDRESS}`);
    console.log(`Treasury: ${TREASURY_ADDRESS}\n`);
    
    const core = await ethers.getContractAt("EnhancedSmartStaking", CORE_ADDRESS);
    const treasury = await ethers.getContractAt("TreasuryManager", TREASURY_ADDRESS);
    
    // 1. Verificar owner del Core
    console.log("1️. Verificando owner del Core...");
    const coreOwner = await core.owner();
    console.log(`   Owner: ${coreOwner}`);
    console.log(`   ✓ Match: ${coreOwner.toLowerCase() === deployer.address.toLowerCase()}\n`);
    
    // 2. Verificar que TreasuryManager es contrato válido
    console.log("2️. Verificando TreasuryManager...");
    const treasuryCode = await ethers.provider.getCode(TREASURY_ADDRESS);
    console.log(`   Código deployado: ${treasuryCode.length > 2 ? "✓ Sí" : "✗ No"}`);
    
    // 3. Intentar hacer estática call primero (no gasta gas)
    console.log("\n3️. Haciendo llamada estática (no envía transacción)...");
    try {
        // Intentar hacer un estimateGas
        const gasEstimate = await core.setTreasuryManager.estimateGas(TREASURY_ADDRESS);
        console.log(`   ✓ Gas estimado: ${gasEstimate}\n`);
    } catch (e) {
        console.log(`   ✗ Error en estimateGas: ${e.message}\n`);
    }
    
    // 4. Verificar que el Core tenga el método
    console.log("4️. Verificando métodos en Core...");
    const methods = Object.getOwnPropertyNames(core).filter(m => m.includes('setTreasury'));
    console.log(`   Métodos: ${methods.length > 0 ? methods.join(', ') : 'No encontrados'}`);
    console.log(`   setTreasuryManager en ABI: ${core.interface.has('setTreasuryManager') ? '✓ Sí' : '✗ No'}\n`);
    
    // 5. Intentar hacer el call de verdad
    console.log("5️. Intentando setTreasuryManager()...");
    try {
        // Obtener nonce actual
        const nonce = await ethers.provider.getTransactionCount(deployer.address);
        console.log(`   Nonce: ${nonce}`);
        
        // Obtener fee data
        const feeData = await ethers.provider.getFeeData();
        console.log(`   GasPrice: ${feeData.gasPrice}`);
        
        const tx = await core.setTreasuryManager(TREASURY_ADDRESS, {
            gasLimit: 500000,
            gasPrice: feeData.gasPrice,
        });
        
        console.log(`   TxHash: ${tx.hash}`);
        console.log(`   ⏳ Esperando confirmación...`);
        
        const receipt = await tx.wait();
        console.log(`   ✅ ÉXITO! Gas usado: ${receipt.gasUsed}`);
        
    } catch (error) {
        console.log(`   ❌ ERROR:`, error.message);
        
        if (error.data) {
            console.log(`   Error data: ${error.data}`);
        }
        
        if (error.reason) {
            console.log(`   Reason: ${error.reason}`);
        }
        
        if (error.transaction) {
            console.log(`   Tx: ${JSON.stringify(error.transaction, null, 2)}`);
        }
        
        process.exit(1);
    }
}

main().catch(console.error);
