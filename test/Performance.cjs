const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingContract Advanced Performance Tests", function () {
  let stakingContract;
  let owner, users;
  const USERS_COUNT = 19;
  const DEPOSITS_PER_USER = 10;

  before(async function () {
    [owner, ...users] = await ethers.getSigners();
    // Ensure we have enough users for testing
    expect(users.length).to.be.gte(USERS_COUNT);

    const StakingContract = await ethers.getContractFactory("StakingContract");
    stakingContract = await StakingContract.deploy(owner.address);
    await stakingContract.deployed();

    // Fund contract with initial balance
    await owner.sendTransaction({
      to: stakingContract.address,
      value: ethers.utils.parseEther("1000")
    });
  });

  it("Should handle multiple concurrent deposits efficiently", async function () {
    this.timeout(300000); // 5 minutes timeout

    console.log("\nTesting concurrent deposits performance:");
    const startTime = Date.now();
    const depositAmount = ethers.utils.parseEther("10");
    const depositPromises = [];

    // Create multiple deposit promises
    for (let i = 0; i < USERS_COUNT; i++) {
      for (let j = 0; j < DEPOSITS_PER_USER; j++) {
        depositPromises.push(
          stakingContract.connect(users[i]).deposit({ value: depositAmount })
        );
      }
    }

    // Execute all deposits concurrently
    const deposits = await Promise.all(depositPromises);
    const endTime = Date.now();

    console.log(`Total deposits: ${deposits.length}`);
    console.log(`Time taken: ${(endTime - startTime) / 1000} seconds`);
    console.log(`Average time per deposit: ${(endTime - startTime) / deposits.length} ms`);

    // Verify deposits
    const uniqueUsers = await stakingContract.uniqueUsersCount();
    expect(uniqueUsers).to.equal(USERS_COUNT);
  });

  it("Should measure reward calculation performance under load", async function () {
    this.timeout(300000);

    console.log("\nTesting reward calculations performance:");
    
    // Advance time by 7 days to accumulate rewards
    await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    const startTime = Date.now();
    const rewardPromises = [];

    // Calculate rewards for all users
    for (let i = 0; i < USERS_COUNT; i++) {
      rewardPromises.push(stakingContract.calculateRewards(users[i].address));
    }

    const rewards = await Promise.all(rewardPromises);
    const endTime = Date.now();

    console.log(`Total reward calculations: ${rewards.length}`);
    console.log(`Time taken: ${(endTime - startTime) / 1000} seconds`);
    console.log(`Average time per calculation: ${(endTime - startTime) / rewards.length} ms`);
    
    // Verify rewards are being calculated
    expect(rewards[0]).to.be.gt(0);
  });

  it("Should handle concurrent withdrawals efficiently", async function () {
    this.timeout(300000);

    console.log("\nTesting concurrent withdrawals performance:");
    const startTime = Date.now();
    const withdrawPromises = [];

    // Create withdrawal promises for half of the users
    for (let i = 0; i < USERS_COUNT / 2; i++) {
      withdrawPromises.push(stakingContract.connect(users[i]).withdraw());
    }

    // Execute all withdrawals concurrently
    const withdrawals = await Promise.all(withdrawPromises);
    const endTime = Date.now();

    console.log(`Total withdrawals: ${withdrawals.length}`);
    console.log(`Time taken: ${(endTime - startTime) / 1000} seconds`);
    console.log(`Average time per withdrawal: ${(endTime - startTime) / withdrawals.length} ms`);
  });

  it("Should analyze gas consumption patterns", async function () {
    console.log("\nAnalyzing gas consumption patterns:");
    
    const depositAmount = ethers.utils.parseEther("10");
    const gasStats = {
      deposits: [],
      withdrawals: []
    };

    // Measure gas for different number of deposits
    for (let i = 0; i < 5; i++) {
      const tx = await stakingContract.connect(users[10 + i]).deposit({ value: depositAmount });
      const receipt = await tx.wait();
      gasStats.deposits.push(receipt.gasUsed.toString());
    }

    // Advance time
    await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    // Measure gas for withdrawals
    for (let i = 0; i < 5; i++) {
      const tx = await stakingContract.connect(users[10 + i]).withdraw();
      const receipt = await tx.wait();
      gasStats.withdrawals.push(receipt.gasUsed.toString());
    }

    console.log("Gas consumption for deposits:", gasStats.deposits);
    console.log("Gas consumption for withdrawals:", gasStats.withdrawals);
  });

  it("Should test contract limits", async function () {
    console.log("\nTesting contract limits:");
    
    // Test maximum deposit
    const maxDeposit = ethers.utils.parseEther("10000");
    await expect(
      stakingContract.connect(users[15]).deposit({ value: maxDeposit.add(1) })
    ).to.be.revertedWith("Deposit amount exceeds maximum limit");

    // Test minimum deposit
    const minDeposit = ethers.utils.parseEther("4");
    await expect(
      stakingContract.connect(users[16]).deposit({ value: minDeposit })
    ).to.be.revertedWith("Deposit amount below minimum");

    // Test maximum ROI
    const largeDeposit = ethers.utils.parseEther("1000");
    await stakingContract.connect(users[17]).deposit({ value: largeDeposit });
    
    // Advance time significantly to test MAX_ROI_PERCENTAGE
    await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    const rewards = await stakingContract.calculateRewards(users[17].address);
    const maxReward = largeDeposit.mul(130).div(100); // 130% max ROI
    expect(rewards).to.be.lte(maxReward);
  });
});