const { ethers } = require("hardhat");

async function main() {
  const viewStatsAddress = "0xb1F6fae50d34cb273392937955aF4Efc938CB46a";
  const coreAddress = "0x5F084a3E35eca396B5216d67D31CB0c8dcC22703";
  
  const viewStats = await ethers.getContractAt("SmartStakingViewStats", viewStatsAddress);
  
  const currentStaking = await viewStats.stakingContract();
  const owner = await viewStats.owner();
  
  console.log("📍 ViewStats Address:", viewStatsAddress);
  console.log("🔧 Owner:", owner);
  console.log("🔗 Current stakingContract:", currentStaking);
  console.log("✅ Expected Core:", coreAddress);
  console.log("🚨 Match:", currentStaking.toLowerCase() === coreAddress.toLowerCase() ? "YES" : "NO - NEEDS UPDATE");
}

main().catch(console.error);
