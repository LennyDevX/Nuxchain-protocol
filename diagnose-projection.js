const { ethers } = require("hardhat");

async function main() {
  const viewStatsAddress = "0xb1F6fae50d34cb273392937955aF4Efc938CB46a";
  const coreAddress = "0x5F084a3E35eca396B5216d67D31CB0c8dcC22703";
  
  // Usa una dirección de prueba (puede ser cualquiera, incluso la del owner)
  const testUser = "0xed639e84179FCEcE1d7BEe91ab1C6888fbBdD0cf"; // Tu dirección
  
  console.log("🔍 DIAGNÓSTICO DETALLADO\n");
  
  // 1. Verificar conexión al contrato ViewStats
  const viewStats = await ethers.getContractAt("EnhancedSmartStakingViewStats", viewStatsAddress);
  console.log("✅ ViewStats conectado");
  
  // 2. Verificar conexión al CoreV2 directamente
  const core = await ethers.getContractAt("EnhancedSmartStakingCoreV2", coreAddress);
  console.log("✅ CoreV2 conectado");
  
  // 3. Probar llamadas directas al CoreV2
  try {
    const userInfo = await core.getUserInfo(testUser);
    console.log("\n📊 CoreV2.getUserInfo():", {
      totalDeposited: userInfo[0].toString(),
      totalRewards: userInfo[1].toString(),
      depositCount: userInfo[2].toString(),
      lastWithdrawTime: userInfo[3].toString()
    });
  } catch (e) {
    console.log("❌ CoreV2.getUserInfo() falló:", e.message);
  }
  
  try {
    const rewards = await core.calculateRewards(testUser);
    console.log("📊 CoreV2.calculateRewards():", rewards.toString());
  } catch (e) {
    console.log("❌ CoreV2.calculateRewards() falló:", e.message);
  }
  
  // 4. Probar funciones individuales de ViewStats
  console.log("\n🧪 Probando ViewStats funciones individuales:");
  
  try {
    const poolStats = await viewStats.getPoolStats();
    console.log("✅ getPoolStats() funciona:", {
      totalPoolValue: poolStats[0].toString(),
      activeUsers: poolStats[2].toString()
    });
  } catch (e) {
    console.log("❌ getPoolStats() falló:", e.message);
  }
  
  try {
    const globalStats = await viewStats.getGlobalStats();
    console.log("✅ getGlobalStats() funciona");
  } catch (e) {
    console.log("❌ getGlobalStats() falló:", e.message);
  }
  
  // 5. Ahora probar la función problemática
  console.log("\n🎯 Probando getUserRewardsProjection:");
  try {
    const projection = await viewStats.getUserRewardsProjection(testUser);
    console.log("✅ getUserRewardsProjection() funciona:", {
      hourlyRewards: projection[0].toString(),
      dailyRewards: projection[1].toString(),
      weeklyRewards: projection[2].toString(),
      monthlyRewards: projection[3].toString(),
      yearlyRewards: projection[4].toString(),
      currentPendingRewards: projection[5].toString()
    });
  } catch (e) {
    console.log("❌ getUserRewardsProjection() falló:");
    console.log("   Error:", e.message);
    if (e.data) {
      console.log("   Error data:", e.data);
    }
  }
  
  // 6. Probar con otra dirección que SÍ tenga depósitos
  // Aquí necesitarías poner una dirección real que tenga stakes
}

main().catch(console.error);
