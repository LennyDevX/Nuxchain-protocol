const hre = require("hardhat");
const fs = require("fs");

async function main() {
    const addressPath = "./deployments/polygon-addresses.json";
    const addresses = JSON.parse(fs.readFileSync(addressPath, "utf8"));

    const TREASURY_MANAGER = addresses.treasury.manager;
    const STAKING_CORE = addresses.staking.core;

    console.log("Checking Treasury Manager Authorization Status...");
    const treasuryManager = await hre.ethers.getContractAt("TreasuryManager", TREASURY_MANAGER);

    const isAuth = await treasuryManager.authorizedSources(STAKING_CORE);
    console.log(`StakingCore (${STAKING_CORE}) authorized: ${isAuth}`);

    const firstDeposit = await treasuryManager.firstDepositTime();
    console.log(`First Deposit Time: ${firstDeposit}`);

    const balance = await hre.ethers.provider.getBalance(TREASURY_MANAGER);
    console.log(`Treasury Manager Balance: ${hre.ethers.utils.formatEther(balance)} POL`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
