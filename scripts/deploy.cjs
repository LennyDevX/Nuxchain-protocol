// scripts/deploy.cjs
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("====================================");
  console.log("🚀 Deploying contracts with the account:", deployer.address);
  console.log("====================================");

  const balance = await deployer.getBalance();
  console.log("💰 Account balance:", hre.ethers.utils.formatEther(balance), "ETH");
  console.log("====================================");

  const treasuryAddress = "0x3dad473a5e9adec61b2de61505b9cfae7466196e"; // Replace with the actual treasury address
  console.log("🏦 Treasury address:", treasuryAddress);
  console.log("====================================");

  const StakingContract = await hre.ethers.getContractFactory("StakingContract");
  const stakingContract = await StakingContract.deploy(treasuryAddress);

  await stakingContract.deployed();

  console.log("====================================");
  console.log("✅ StakingContract deployed successfully!");
  console.log("📜 Contract address:", stakingContract.address);
  console.log("====================================");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });