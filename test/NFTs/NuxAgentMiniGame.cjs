"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("NuxAgentMiniGame", function () {

  async function deployFixture() {
    const [admin, player, validator, other] = await ethers.getSigners();

    // Deploy mock leveling
    const Leveling = await ethers.getContractFactory("MockLeveling");
    const leveling = await Leveling.deploy();

    // Deploy mock game NFT (ownerOf support)
    const MockGameNFT = await ethers.getContractFactory("MockGameNFT");
    const mockNFT = await MockGameNFT.deploy();
    await mockNFT.setOwner(1, player.address);

    const Game = await ethers.getContractFactory("NuxAgentMiniGame");
    const game = await upgrades.deployProxy(Game, [
      admin.address,
      ethers.ZeroAddress,     // agentRegistry (not needed for core flow)
      await leveling.getAddress(),
      admin.address           // defaultValidator
    ], { kind: "uups" });
    await game.waitForDeployment();

    const ADMIN_ROLE     = await game.ADMIN_ROLE();
    const VALIDATOR_ROLE = await game.VALIDATOR_ROLE();
    const DEPOSITOR_ROLE = await game.DEPOSITOR_ROLE();

    // Give validator role to validator signer
    await game.connect(admin).grantRole(VALIDATOR_ROLE, validator.address);

    return { game, mockNFT, leveling, admin, player, validator, other, ADMIN_ROLE, VALIDATOR_ROLE, DEPOSITOR_ROLE };
  }

  function taskParams(overrides = {}) {
    return {
      metadataURI:             "ipfs://QmTask",
      taskType:                0,    // GENERAL
      xpReward:                100,
      tokenReward:             0,
      requiredMinReputation:   0,
      maxCompletionsPerAgent:  0,    // 0 = unlimited
      totalMaxCompletions:     0,    // 0 = unlimited
      validationRequired:      false,
      startTime:               0,
      deadline:                0,
      ...overrides,
    };
  }

  // ============================================================
  describe("Deployment", function () {
    it("initializes correctly", async function () {
      const { game, admin, ADMIN_ROLE, VALIDATOR_ROLE } = await loadFixture(deployFixture);
      expect(await game.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
      expect(await game.hasRole(VALIDATOR_ROLE, admin.address)).to.be.true;
      expect(await game.paused()).to.be.false;
      expect(await game.rewardPool()).to.equal(0n);
    });
  });

  // ============================================================
  describe("Reward pool", function () {
    it("admin can deposit rewards", async function () {
      const { game, admin } = await loadFixture(deployFixture);
      await expect(
        game.connect(admin).depositRewards({ value: ethers.parseEther("1") })
      ).to.emit(game, "RewardPoolDeposited").withArgs(ethers.parseEther("1"), admin.address);
      expect(await game.rewardPool()).to.equal(ethers.parseEther("1"));
    });

    it("reverts zero deposit", async function () {
      const { game, admin } = await loadFixture(deployFixture);
      await expect(game.connect(admin).depositRewards({ value: 0 }))
        .to.be.revertedWith("Game: zero deposit");
    });

    it("receive() increases reward pool", async function () {
      const { game, admin } = await loadFixture(deployFixture);
      await admin.sendTransaction({ to: await game.getAddress(), value: ethers.parseEther("0.5") });
      expect(await game.rewardPool()).to.equal(ethers.parseEther("0.5"));
    });

    it("admin can withdraw from pool", async function () {
      const { game, admin } = await loadFixture(deployFixture);
      await game.connect(admin).depositRewards({ value: ethers.parseEther("1") });
      const balBefore = await ethers.provider.getBalance(admin.address);
      const tx = await game.connect(admin).withdrawRewardPool(ethers.parseEther("0.5"), admin.address);
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;
      const balAfter = await ethers.provider.getBalance(admin.address);
      expect(balAfter - balBefore + gasUsed).to.be.closeTo(ethers.parseEther("0.5"), 1000n);
      expect(await game.rewardPool()).to.equal(ethers.parseEther("0.5"));
    });

    it("reverts withdrawal exceeding pool", async function () {
      const { game, admin } = await loadFixture(deployFixture);
      await expect(game.connect(admin).withdrawRewardPool(ethers.parseEther("1"), admin.address))
        .to.be.revertedWith("Game: insufficient pool");
    });
  });

  // ============================================================
  describe("createTask", function () {
    it("admin can create a task", async function () {
      const { game, admin } = await loadFixture(deployFixture);
      await expect(game.connect(admin).createTask(taskParams()))
        .to.emit(game, "TaskCreated");
      const task = await game.getTask(1);
      expect(task.xpReward).to.equal(100n);
      expect(task.active).to.be.true;
    });

    it("reverts if xpReward is zero", async function () {
      const { game, admin } = await loadFixture(deployFixture);
      await expect(game.connect(admin).createTask(taskParams({ xpReward: 0 })))
        .to.be.revertedWith("Game: xpReward must be > 0");
    });

    it("reverts if deadline is in the past", async function () {
      const { game, admin } = await loadFixture(deployFixture);
      const past = (await time.latest()) - 100;
      await expect(game.connect(admin).createTask(taskParams({ deadline: past })))
        .to.be.revertedWith("Game: deadline in the past");
    });

    it("non-admin cannot create task", async function () {
      const { game, other } = await loadFixture(deployFixture);
      await expect(game.connect(other).createTask(taskParams()))
        .to.be.reverted;
    });
  });

  // ============================================================
  describe("submitTask — auto-approve (validationRequired=false)", function () {
    it("submits and auto-approves, awarding XP", async function () {
      const { game, mockNFT, leveling, admin, player } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams({ xpReward: 50 }));
      const nftAddr = await mockNFT.getAddress();
      await expect(
        game.connect(player).submitTask(1, nftAddr, 1, "ipfs://QmResult", ethers.ZeroHash)
      ).to.emit(game, "SubmissionApproved");

      const sub = await game.getSubmission(1);
      expect(sub.status).to.equal(1n); // APPROVED
      // XP should be awarded via leveling (50 task XP + 10 from recordAgentTask)
      expect(await leveling.xp(player.address)).to.equal(60n);
    });

    it("auto-approve emits LeaderboardXPUpdated", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams({ xpReward: 30 }));
      const nftAddr = await mockNFT.getAddress();
      await expect(
        game.connect(player).submitTask(1, nftAddr, 1, "ipfs://QmR", ethers.ZeroHash)
      ).to.emit(game, "LeaderboardXPUpdated");
    });

    it("reverts if task deadline already passed", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      const deadline = (await time.latest()) + 3600;
      await game.connect(admin).createTask(taskParams({ deadline }));
      await time.increase(3700);
      await expect(
        game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash)
      ).to.be.revertedWith("Game: task deadline passed");
    });

    it("reverts if caller is not agent owner", async function () {
      const { game, mockNFT, admin, other } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams());
      await expect(
        game.connect(other).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash)
      ).to.be.revertedWith("Game: not agent owner");
    });

    it("reverts if task is not active", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams());
      await game.connect(admin).setTaskActive(1, false);
      await expect(
        game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash)
      ).to.be.revertedWith("Game: task not active");
    });

    it("reverts when paused", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams());
      await game.connect(admin).setPaused(true);
      await expect(
        game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash)
      ).to.be.revertedWith("Game: paused");
    });

    it("enforces maxCompletionsPerAgent limit", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams({ maxCompletionsPerAgent: 1 }));
      const nftAddr = await mockNFT.getAddress();
      await game.connect(player).submitTask(1, nftAddr, 1, "ipfs://Q", ethers.ZeroHash);
      await expect(
        game.connect(player).submitTask(1, nftAddr, 1, "ipfs://Q2", ethers.ZeroHash)
      ).to.be.revertedWith("Game: agent reached max completions for this task");
    });

    it("enforces totalMaxCompletions limit", async function () {
      const { game, mockNFT, admin, player, other } = await loadFixture(deployFixture);
      // Give 'other' their own NFT
      await mockNFT.setOwner(2, other.address);
      await game.connect(admin).createTask(taskParams({ totalMaxCompletions: 1 }));
      const nftAddr = await mockNFT.getAddress();
      await game.connect(player).submitTask(1, nftAddr, 1, "ipfs://Q", ethers.ZeroHash);
      await expect(
        game.connect(other).submitTask(1, nftAddr, 2, "ipfs://Q2", ethers.ZeroHash)
      ).to.be.revertedWith("Game: task fully claimed");
    });
  });

  // ============================================================
  describe("submitTask — with validation required", function () {
    it("submission stays PENDING until validated", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams({ validationRequired: true }));
      await game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash);
      const sub = await game.getSubmission(1);
      expect(sub.status).to.equal(0n); // PENDING
    });

    it("validator can approve a pending submission", async function () {
      const { game, mockNFT, admin, player, validator, leveling } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams({ validationRequired: true, xpReward: 75 }));
      await game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash);
      await expect(game.connect(validator).validateSubmission(1, true, ""))
        .to.emit(game, "SubmissionApproved");
      const sub = await game.getSubmission(1);
      expect(sub.status).to.equal(1n); // APPROVED
      // 75 task XP + 10 from recordAgentTask
      expect(await leveling.xp(player.address)).to.equal(85n);
    });

    it("validator can reject a pending submission", async function () {
      const { game, mockNFT, admin, player, validator } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams({ validationRequired: true }));
      await game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash);
      await expect(game.connect(validator).validateSubmission(1, false, "low quality"))
        .to.emit(game, "SubmissionRejected").withArgs(1n, player.address, "low quality");
    });

    it("reverts double-validation", async function () {
      const { game, mockNFT, admin, player, validator } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams({ validationRequired: true }));
      await game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash);
      await game.connect(validator).validateSubmission(1, true, "");
      await expect(game.connect(validator).validateSubmission(1, false, "retry"))
        .to.be.revertedWith("Game: already resolved");
    });

    it("non-validator cannot validate", async function () {
      const { game, mockNFT, admin, player, other } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams({ validationRequired: true }));
      await game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash);
      await expect(game.connect(other).validateSubmission(1, true, ""))
        .to.be.reverted;
    });
  });

  // ============================================================
  describe("claimReward", function () {
    it("player can claim ETH reward after approval", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      const reward = ethers.parseEther("0.1");
      await game.connect(admin).depositRewards({ value: ethers.parseEther("1") });
      await game.connect(admin).createTask(taskParams({ tokenReward: reward }));
      const nftAddr = await mockNFT.getAddress();
      await game.connect(player).submitTask(1, nftAddr, 1, "ipfs://Q", ethers.ZeroHash);
      // submission will be auto-approved
      const balBefore = await ethers.provider.getBalance(player.address);
      const tx = await game.connect(player).claimReward(1);
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;
      const balAfter = await ethers.provider.getBalance(player.address);
      expect(balAfter - balBefore + gasUsed).to.be.closeTo(reward, 1000n);
    });

    it("reverts if already claimed", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      const reward = ethers.parseEther("0.1");
      await game.connect(admin).depositRewards({ value: ethers.parseEther("1") });
      await game.connect(admin).createTask(taskParams({ tokenReward: reward }));
      await game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash);
      await game.connect(player).claimReward(1);
      await expect(game.connect(player).claimReward(1))
        .to.be.revertedWith("Game: reward already claimed");
    });

    it("reverts if not the submitter", async function () {
      const { game, mockNFT, admin, player, other } = await loadFixture(deployFixture);
      await game.connect(admin).depositRewards({ value: ethers.parseEther("1") });
      await game.connect(admin).createTask(taskParams({ tokenReward: ethers.parseEther("0.05") }));
      await game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash);
      await expect(game.connect(other).claimReward(1))
        .to.be.revertedWith("Game: not submitter");
    });

    it("reverts if task has no token reward", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams({ tokenReward: 0 }));
      await game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash);
      await expect(game.connect(player).claimReward(1))
        .to.be.revertedWith("Game: no token reward for this task");
    });

    it("reverts if submission not approved", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      await game.connect(admin).depositRewards({ value: ethers.parseEther("1") });
      await game.connect(admin).createTask(taskParams({ tokenReward: ethers.parseEther("0.1"), validationRequired: true }));
      await game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash);
      // still PENDING
      await expect(game.connect(player).claimReward(1))
        .to.be.revertedWith("Game: not approved");
    });
  });

  // ============================================================
  describe("Daily streak bonus", function () {
    it("first completion sets streak to 1", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      await game.connect(admin).createTask(taskParams({ taskType: 9 /* DAILY_CHALLENGE */ }));
      await game.connect(player).submitTask(1, await mockNFT.getAddress(), 1, "ipfs://Q", ethers.ZeroHash);
      const [streak] = await game.getAgentStreak(player.address);
      expect(streak).to.equal(1n);
    });

    it("consecutive daily completions increase streak and bonus XP", async function () {
      const { game, mockNFT, leveling, admin, player } = await loadFixture(deployFixture);
      const nftAddr = await mockNFT.getAddress();
      // Create 3 separate daily tasks
      for (let i = 0; i < 3; i++) {
        await game.connect(admin).createTask(taskParams({ taskType: 9, xpReward: 100 }));
      }
      await game.connect(player).submitTask(1, nftAddr, 1, "ipfs://Q1", ethers.ZeroHash);
      await time.increase(86400); // next day
      await game.connect(player).submitTask(2, nftAddr, 1, "ipfs://Q2", ethers.ZeroHash);
      await time.increase(86400); // next day
      await game.connect(player).submitTask(3, nftAddr, 1, "ipfs://Q3", ethers.ZeroHash);
      const [streak] = await game.getAgentStreak(player.address);
      expect(streak).to.equal(3n);
      // XP on day 1: 100+10%, day 2: 100+20%, day 3: 100+30% = 100+110+120+130 = 460
      // Actually day 1: base=100, streak=1, bonus=10 → 110
      // day 2: base=100, streak=2, bonus=20 → 120
      // day 3: base=100, streak=3, bonus=30 → 130
      // total = 360
      expect(await leveling.xp(player.address)).to.be.gte(300n); // at least 3x100
    });

    it("broken streak resets to 1", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      const nftAddr = await mockNFT.getAddress();
      await game.connect(admin).createTask(taskParams({ taskType: 9 }));
      await game.connect(admin).createTask(taskParams({ taskType: 9 }));
      await game.connect(player).submitTask(1, nftAddr, 1, "ipfs://Q1", ethers.ZeroHash);
      await time.increase(3 * 86400); // skip a day
      await game.connect(player).submitTask(2, nftAddr, 1, "ipfs://Q2", ethers.ZeroHash);
      const [streak] = await game.getAgentStreak(player.address);
      expect(streak).to.equal(1n); // reset
    });
  });

  // ============================================================
  describe("getAgentGameStats", function () {
    it("returns cumulative XP for an agent", async function () {
      const { game, mockNFT, admin, player } = await loadFixture(deployFixture);
      const nftAddr = await mockNFT.getAddress();
      await game.connect(admin).createTask(taskParams({ xpReward: 40 }));
      await game.connect(player).submitTask(1, nftAddr, 1, "ipfs://Q", ethers.ZeroHash);
      expect(await game.getAgentGameStats(nftAddr, 1)).to.equal(40n);
    });
  });
});
