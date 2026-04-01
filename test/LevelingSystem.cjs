const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("LevelingSystem", function () {
  async function deployLevelingFixture() {
    const [owner, user] = await ethers.getSigners();

    const LevelingFactory = await ethers.getContractFactory("LevelingSystem");
    const leveling = await upgrades.deployProxy(LevelingFactory, [owner.address], {
      initializer: "initialize",
      kind: "uups"
    });
    await leveling.waitForDeployment();

    return { owner, user, leveling };
  }

  it("defers a level-up reward when the contract lacks funds and allows claiming later", async function () {
    const { owner, user, leveling } = await loadFixture(deployLevelingFixture);
    const rewardAmount = ethers.parseEther("0.05");

    await expect(leveling.connect(owner).updateUserXP(user.address, 50, "TEST_LEVEL"))
      .to.emit(leveling, "RewardDeferred")
      .withArgs(user.address, 1n, rewardAmount, "Insufficient funds");

    expect(await leveling.deferredRewardAmount(user.address)).to.equal(rewardAmount);
    expect(await leveling.totalPendingRewards()).to.equal(rewardAmount);

    await owner.sendTransaction({
      to: await leveling.getAddress(),
      value: rewardAmount
    });

    await expect(leveling.connect(user).claimDeferredReward())
      .to.emit(leveling, "DeferredRewardClaimed")
      .withArgs(user.address, rewardAmount);

    expect(await leveling.deferredRewardAmount(user.address)).to.equal(0);
    expect(await leveling.totalPendingRewards()).to.equal(0);
  });

  it("defers a level-up reward when the recipient rejects ETH and allows claiming later", async function () {
    const { owner, leveling } = await loadFixture(deployLevelingFixture);
    const rewardAmount = ethers.parseEther("0.05");

    const RejectingWallet = await ethers.getContractFactory("MockRejectingWallet");
    const rejectingWallet = await RejectingWallet.connect(owner).deploy();
    await rejectingWallet.waitForDeployment();

    await owner.sendTransaction({
      to: await leveling.getAddress(),
      value: ethers.parseEther("10")
    });

    await expect(leveling.connect(owner).updateUserXP(await rejectingWallet.getAddress(), 50, "TEST_REJECT"))
      .to.emit(leveling, "RewardDeferred")
      .withArgs(await rejectingWallet.getAddress(), 1n, rewardAmount, "Transfer failed");

    expect(await leveling.deferredRewardAmount(await rejectingWallet.getAddress())).to.equal(rewardAmount);

    await rejectingWallet.connect(owner).setRejectPayments(false);

    await expect(rejectingWallet.connect(owner).claimLevelingReward(await leveling.getAddress()))
      .to.emit(leveling, "DeferredRewardClaimed")
      .withArgs(await rejectingWallet.getAddress(), rewardAmount);

    expect(await leveling.deferredRewardAmount(await rejectingWallet.getAddress())).to.equal(0);
    expect(await leveling.totalPendingRewards()).to.equal(0);
  });
});