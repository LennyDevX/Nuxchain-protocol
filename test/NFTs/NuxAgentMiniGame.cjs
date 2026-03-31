"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("NuxAgentMiniGame", function () {
  async function deployFixture() {
    const [admin, player, validator, other] = await ethers.getSigners();

    const Registry = await ethers.getContractFactory("NuxAgentRegistry");
    const registry = await upgrades.deployProxy(Registry, [admin.address], {
      initializer: "initialize",
      kind: "uups"
    });
    await registry.waitForDeployment();

    const Treasury = await ethers.getContractFactory("MockTreasury");
    const treasury = await Treasury.deploy();
    await treasury.waitForDeployment();

    const MockGameNFT = await ethers.getContractFactory("MockGameNFT");
    const mockNFT = await MockGameNFT.deploy();
    await mockNFT.waitForDeployment();
    await mockNFT.setOwner(1, other.address);
    await mockNFT.setController(1, player.address);
    await mockNFT.setOwner(2, player.address);

    await registry.registerNFTContract(await mockNFT.getAddress());

    const Game = await ethers.getContractFactory("NuxAgentMiniGame");
    const game = await upgrades.deployProxy(Game, [
      admin.address,
      await registry.getAddress(),
      validator.address
    ], {
      initializer: "initialize",
      kind: "uups"
    });
    await game.waitForDeployment();

    await registry.grantGameRole(await game.getAddress());
    await game.grantRole(await game.VALIDATOR_ROLE(), validator.address);
    await game.setTreasuryManager(await treasury.getAddress());

    return { game, registry, treasury, mockNFT, admin, player, validator, other };
  }

  function taskParams(overrides = {}) {
    return {
      metadataURI: "ipfs://nuxtap-agent-task",
      taskType: 0,
      xpReward: 100,
      tokenReward: 0,
      requiredMinReputation: 0,
      maxCompletionsPerAgent: 0,
      totalMaxCompletions: 0,
      validationRequired: false,
      startTime: 0,
      deadline: 0,
      ...overrides
    };
  }

  it("initializes the NuxTap-native admin and validator roles", async function () {
    const { game, admin, validator } = await loadFixture(deployFixture);

    expect(await game.hasRole(await game.ADMIN_ROLE(), admin.address)).to.equal(true);
    expect(await game.hasRole(await game.VALIDATOR_ROLE(), admin.address)).to.equal(true);
    expect(await game.defaultValidator()).to.equal(validator.address);
    expect(await game.rewardPool()).to.equal(0n);
  });

  it("auto-approves controller submissions and records mission XP", async function () {
    const { game, registry, mockNFT, admin, player } = await loadFixture(deployFixture);

    await game.connect(admin).createTask(taskParams({ xpReward: 50 }));

    await expect(
      game.connect(player).submitTask(
        1,
        await mockNFT.getAddress(),
        1,
        "ipfs://nuxtap-agent-result",
        ethers.id("nuxtap-agent-result")
      )
    ).to.emit(game, "SubmissionApproved");

    const submission = await game.getSubmission(1);
    expect(submission.status).to.equal(1n);
    expect(await game.getAgentGameStats(await mockNFT.getAddress(), 1)).to.equal(50n);
    expect(await game.userMissionXP(player.address)).to.equal(50n);

    const profile = await registry.getAgentOperationalProfile(1);
    expect(profile.totalTasksRun).to.equal(1n);
  });

  it("keeps validated submissions pending until approval and routes claim fees to treasury", async function () {
    const { game, treasury, mockNFT, admin, player, validator } = await loadFixture(deployFixture);

    await game.connect(admin).setMiniGameFee(500);
    await game.connect(admin).depositRewards({ value: ethers.parseEther("1") });
    await game.connect(admin).createTask(
      taskParams({
        validationRequired: true,
        xpReward: 75,
        tokenReward: ethers.parseEther("1")
      })
    );

    await game.connect(player).submitTask(
      1,
      await mockNFT.getAddress(),
      2,
      "ipfs://nuxtap-agent-claimable",
      ethers.id("nuxtap-agent-claimable")
    );

    expect((await game.getSubmission(1)).status).to.equal(0n);

    await expect(game.connect(validator).validateSubmission(1, true, ""))
      .to.emit(game, "SubmissionApproved");

    await expect(game.connect(player).claimReward(1))
      .to.emit(game, "RewardClaimed")
      .withArgs(1n, player.address, ethers.parseEther("0.95"));

    expect(await ethers.provider.getBalance(await treasury.getAddress())).to.equal(ethers.parseEther("0.05"));
    expect((await game.getSubmission(1)).rewardClaimed).to.equal(true);
    expect(await game.userMissionXP(player.address)).to.equal(75n);
  });

  it("rejects submissions for NFT contracts outside the NuxTap agent set", async function () {
    const { game, admin, player } = await loadFixture(deployFixture);

    const OtherMockNFT = await ethers.getContractFactory("MockGameNFT");
    const otherMockNFT = await OtherMockNFT.deploy();
    await otherMockNFT.waitForDeployment();
    await otherMockNFT.setOwner(9, player.address);

    await game.connect(admin).createTask(taskParams());

    await expect(
      game.connect(player).submitTask(1, await otherMockNFT.getAddress(), 9, "ipfs://unsupported", ethers.id("unsupported"))
    ).to.be.revertedWith("Game: unsupported NFT contract");
  });
});
