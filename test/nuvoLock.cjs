const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingContract", function () {
  let StakingContract, staking;
  let owner, addr1, addr2, addrs;
  let _treasury;

  beforeEach(async function () {
    StakingContract = await ethers.getContractFactory("StakingContract");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    _treasury = owner.address;
    staking = await StakingContract.deploy(_treasury);
    await staking.deployed();
    
    // Fund contract with initial balance for rewards
    await owner.sendTransaction({
      to: staking.address,
      value: ethers.utils.parseEther("1000")
    });
  });

  it("Should not allow deposits below minimum", async function () {
    const depositAmount = ethers.utils.parseEther("4");
    await expect(
      staking.connect(addr1).deposit({ value: depositAmount })
    ).to.be.revertedWith("Deposit below minimum");
  });

  it("Should not allow more than MAX_DEPOSITS_PER_USER deposits", async function () {
    const depositAmount = ethers.utils.parseEther("5");
    const MAX_DEPOSITS_PER_USER = 300;
    for (let i = 0; i < MAX_DEPOSITS_PER_USER; i++) {
      await staking.connect(addr1).deposit({ value: depositAmount });
    }
    await expect(
      staking.connect(addr1).deposit({ value: depositAmount })
    ).to.be.revertedWith("Max deposits reached");
  });

  it("Should validate deposit amounts and commission calculation", async function () {
    const depositAmount = ethers.utils.parseEther("100");
    await staking.connect(addr1).deposit({ value: depositAmount });

    const depositInContract = await staking.getTotalDeposit(addr1.address);
    // Commission is 6% (600 basis points), so deposited amount should be 94%
    const expectedAmount = depositAmount.mul(9400).div(10000);
    expect(depositInContract).to.equal(expectedAmount);
  });

  it("Should track rewards over 7 days with correct ROI", async function () {
    const depositAmount = ethers.utils.parseEther("100");
    await staking.connect(addr1).deposit({ value: depositAmount });
    
    console.log("\nRewards Tracking Test");
    console.log("Initial deposit: 100 MATIC");
    
    for (let day = 1; day <= 7; day++) {
      await ethers.provider.send("evm_increaseTime", [24 * 3600]);
      await ethers.provider.send("evm_mine");
      
      const rewards = await staking.calculateRewards(addr1.address);
      console.log(`Day ${day} rewards: ${ethers.utils.formatEther(rewards)} MATIC`);
    }

    const balanceBefore = await addr1.getBalance();
    const tx = await staking.connect(addr1).withdraw();
    const receipt = await tx.wait();
    const gasCost = receipt.gasUsed.mul(tx.gasPrice);
    const balanceAfter = await addr1.getBalance();
    
    expect(balanceAfter.add(gasCost).gt(balanceBefore)).to.be.true;
  });

  it("Should validate reward calculation based on tiers", async function () {
    const depositAmountTier1 = ethers.utils.parseEther("50");
    const depositAmountTier2 = ethers.utils.parseEther("150");

    await staking.connect(addr1).deposit({ value: depositAmountTier1 });
    await staking.connect(addr2).deposit({ value: depositAmountTier2 });

    await ethers.provider.send("evm_increaseTime", [24 * 3600 * 7]);
    await ethers.provider.send("evm_mine");

    const rewardsTier1 = await staking.calculateRewards(addr1.address);
    const rewardsTier2 = await staking.calculateRewards(addr2.address);

    console.log(`Tier 1 rewards: ${ethers.utils.formatEther(rewardsTier1)} MATIC`);
    console.log(`Tier 2 rewards: ${ethers.utils.formatEther(rewardsTier2)} MATIC`);

    expect(rewardsTier2).to.be.gt(rewardsTier1);
  });

  it("Should allow withdrawing deposits and rewards", async function () {
    const depositAmount = ethers.utils.parseEther("100");
    await staking.connect(addr1).deposit({ value: depositAmount });

    await ethers.provider.send("evm_increaseTime", [24 * 3600 * 7]);
    await ethers.provider.send("evm_mine");

    const balanceBefore = await addr1.getBalance();
    const tx = await staking.connect(addr1).withdraw();
    const receipt = await tx.wait();
    const gasCost = receipt.gasUsed.mul(tx.gasPrice);
    const balanceAfter = await addr1.getBalance();

    expect(balanceAfter.add(gasCost).gt(balanceBefore)).to.be.true;
  });

  it("Should allow withdrawing only rewards", async function () {
    const depositAmount = ethers.utils.parseEther("100");
    await staking.connect(addr1).deposit({ value: depositAmount });

    // Advance time by 7 days to accumulate rewards
    await ethers.provider.send("evm_increaseTime", [24 * 3600 * 7]);
    await ethers.provider.send("evm_mine");

    // Get initial balances and deposits
    const initialBalance = await addr1.getBalance();
    const initialDeposit = await staking.getTotalDeposit(addr1.address);
    const expectedRewards = await staking.calculateRewards(addr1.address);

    // Withdraw rewards
    const tx = await staking.connect(addr1).withdraw();
    const receipt = await tx.wait();
    const gasCost = receipt.gasUsed.mul(tx.gasPrice);

    // Check balances after withdrawal
    const finalBalance = await addr1.getBalance();
    const finalDeposit = await staking.getTotalDeposit(addr1.address);

    // Verify deposit remains unchanged
    expect(finalDeposit).to.equal(initialDeposit);
    
    // Verify rewards were received (accounting for gas and commission)
    const commission = expectedRewards.mul(600).div(10000); // Using basis points (600) for 6%
    const expectedReceived = expectedRewards.sub(commission);
    // Use closeTo for floating point comparison with a small margin of error
    expect(finalBalance.add(gasCost).sub(initialBalance)).to.be.closeTo(expectedReceived, ethers.utils.parseUnits("0.1", "gwei"));
  });

  it("Should allow emergency withdrawal of deposits when paused", async function () {
    const depositAmount = ethers.utils.parseEther("100");
    await staking.connect(addr1).deposit({ value: depositAmount });

    // Accumulate some rewards
    await ethers.provider.send("evm_increaseTime", [24 * 3600]);
    await ethers.provider.send("evm_mine");

    // Pause contract
    await staking.connect(owner).pause();

    // Get initial balances
    const initialBalance = await addr1.getBalance();
    const initialDeposit = await staking.getTotalDeposit(addr1.address);

    // Emergency withdraw
    const tx = await staking.connect(addr1).emergencyUserWithdraw();
    const receipt = await tx.wait();
    const gasCost = receipt.gasUsed.mul(tx.gasPrice);

    // Check final balances
    const finalBalance = await addr1.getBalance();

    // Verify full deposit was returned
    expect(finalBalance.add(gasCost).sub(initialBalance)).to.equal(initialDeposit);

    // Verify user data was cleared
    const userDeposits = await staking.getUserDeposits(addr1.address);
    expect(userDeposits.length).to.equal(0);
  });

  it("Should not allow emergency withdrawal when not paused", async function () {
    const depositAmount = ethers.utils.parseEther("100");
    await staking.connect(addr1).deposit({ value: depositAmount });

    await expect(
      staking.connect(addr1).emergencyUserWithdraw()
    ).to.be.revertedWith("Pausable: not paused");
  });

  it("Should not allow regular withdrawal when paused", async function () {
    const depositAmount = ethers.utils.parseEther("100");
    await staking.connect(addr1).deposit({ value: depositAmount });

    await staking.connect(owner).pause();

    await expect(
      staking.connect(addr1).withdraw()
    ).to.be.revertedWith("Pausable: paused");
  });

});