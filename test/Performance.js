const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingContract Performance", function () {
  let stakingContract;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const StakingContract = await ethers.getContractFactory("StakingContract");
    stakingContract = await StakingContract.deploy(owner.address);
    await stakingContract.deployed();
  });

  it("Should measure transaction time for multiple deposits under high transaction volume", async function () {
    this.timeout(60000);
  
    const numDeposits = 100;
    const depositPromises = [];
    for (let i = 0; i < numDeposits; i++) {
      const depositAmount = ethers.utils.parseEther((i + 1).toString());
      const gasEstimateUser1 = await stakingContract.connect(user1).estimateGas.deposit({ value: depositAmount });
      const gasEstimateUser2 = await stakingContract.connect(user2).estimateGas.deposit({ value: depositAmount });
      depositPromises.push(gasEstimateUser1);
      depositPromises.push(gasEstimateUser2);
    }

    const totalGasEstimate = depositPromises.reduce((acc, curr) => acc.add(curr), ethers.BigNumber.from(0));
    const averageGasPerDeposit = totalGasEstimate.div(numDeposits * 2);

    console.log(`Total gas estimate for ${numDeposits * 2} deposits: ${ethers.utils.formatUnits(totalGasEstimate.toString(), 'gwei')} Gwei`);
    console.log(`Average gas estimate per deposit: ${ethers.utils.formatUnits(averageGasPerDeposit.toString(), 'gwei')} Gwei`);
  });
  
  it("Should measure time to calculate potential earnings efficiently", async function () {
    this.timeout(60000); // Aumentar el tiempo de espera
    const numDeposits = 100;
    const users = [];
    for (let i = 0; i < numDeposits; i++) {
        const user = (await ethers.getSigners())[0];
        users.push(user);

        const depositAmount = ethers.utils.parseEther("101");
        await stakingContract.connect(user).deposit({ value: depositAmount });
    }

    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 7]); // Aumentar el tiempo para que haya recompensas

    const startTime = Date.now();
    for (let i = 0; i < numDeposits; i++) {
        const user = users[i];
        await stakingContract.calculateRewards(user.address);
    }
    const endTime = Date.now();

    const elapsedTime = endTime - startTime;
    console.log(`Time to calculate rewards for ${numDeposits} users: ${elapsedTime}ms`);
});


  

 
});
