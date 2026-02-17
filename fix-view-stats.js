const { ethers } = require("hardhat");

async function main() {
  const viewStatsAddress = "0xb1F6fae50d34cb273392937955aF4Efc938CB46a";
  const coreAddress = "0x5F084a3E35eca396B5216d67D31CB0c8dcC22703";
  
  const [deployer] = await ethers.getSigners();
  console.log("Using account:", deployer.address);
  
  const viewStats = await ethers.getContractAt("EnhancedSmartStakingViewStats", viewStatsAddress);
  
  console.log("Updating stakingContract to:", coreAddress);
  const tx = await viewStats.setStakingContract(coreAddress);
  await tx.wait();
  
  console.log("✅ Updated! New stakingContract:", await viewStats.stakingContract());
}

main().catch(console.error);
