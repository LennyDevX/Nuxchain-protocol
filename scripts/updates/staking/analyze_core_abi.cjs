const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
    // Cargar el ABI del Core desde los artifacts
    const artifactPath = "./artifacts/contracts/SmartStaking/EnhancedSmartStakingCore.sol/EnhancedSmartStaking.json";
    const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
    
    const CORE_ADDRESS = "0xC67F0a0cB719e4f4358D980a5D966878Fd6f3946";
    
    console.log("🔍 Analizando ABI vs Contrato Deployado\n");
    console.log("Core Address:", CORE_ADDRESS);
    
    // Lista de métodos que esperamos
    const expectedMethods = [
        "setRewardsModule",
        "setSkillsModule",
        "setGamificationModule",
        "setTreasuryManager",  // Este es el que está fallando
        "changeTreasuryAddress",
        "deposit",
        "claimRewards"
    ];
    
    console.log("\n📋 Métodos esperados en ABI:");
    const abitMethods = artifact.abi.filter(item => item.type === "function").map(f => f.name);
    
    expectedMethods.forEach(method => {
        const exists = abitMethods.includes(method);
        console.log(`   ${exists ? "✓" : "✗"} ${method}`);
    });
    
    console.log("\n⚠️ NOTA IMPORTANTE:");
    console.log("El Core en la blockchain fue desplegado ANTES de tener setTreasuryManager()");
    console.log("NO es un contrato upgradeable, así que NO se puede actualizar remotamente.\n");
    console.log("SOLUCIONES:");
    console.log("1. Desplegar un NUEVO Core con TreasuryManager preconfigurado");
    console.log("2. Usar changeTreasuryAddress() en lugar de setTreasuryManager()");
    console.log("3. Migrar usuarios manualmente a un nuevo Core");
}

main().catch(console.error);
