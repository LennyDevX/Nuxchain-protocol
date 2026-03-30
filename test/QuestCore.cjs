const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("QuestCore", function () {
  async function deployQuestCoreFixture() {
    const [admin, reporter, user, otherUser] = await ethers.getSigners();

    const MockQuestLeveling = await ethers.getContractFactory("MockQuestLeveling");
    const leveling = await MockQuestLeveling.deploy();
    await leveling.waitForDeployment();

    const MockQuestRewardsPool = await ethers.getContractFactory("MockQuestRewardsPool");
    const rewardsPool = await MockQuestRewardsPool.deploy();
    await rewardsPool.waitForDeployment();

    const QuestCore = await ethers.getContractFactory("QuestCore");
    const questCore = await upgrades.deployProxy(QuestCore, [admin.address, ethers.ZeroAddress], {
      initializer: "initialize",
      kind: "uups",
    });
    await questCore.waitForDeployment();

    await questCore.setLevelingContract(await leveling.getAddress());
    await questCore.setQuestRewardsPool(await rewardsPool.getAddress());
    await questCore.grantRole(await questCore.REPORTER_ROLE(), reporter.address);

    await admin.sendTransaction({
      to: await rewardsPool.getAddress(),
      value: ethers.parseEther("10"),
    });

    return { admin, reporter, user, otherUser, questCore, leveling, rewardsPool };
  }

  it("calcula progreso live para quests basadas en perfil antes de snapshot manual", async function () {
    const { questCore, leveling, user } = await loadFixture(deployQuestCoreFixture);

    await questCore.createQuest({
      category: 0,
      questType: 0,
      title: "Compra 3 NFTs",
      description: "Quest de compra",
      requirement: 3,
      xpReward: 100,
      polReward: 0,
      startTime: 0,
      deadline: 0,
      completionLimit: 0,
    });

    await leveling.setUserProfile(user.address, {
      totalXP: 0,
      level: 1,
      nftsCreated: 0,
      nftsOwned: 0,
      nftsSold: 0,
      nftsBought: 3,
    });

    const progress = await questCore.getUserQuestProgress(user.address, 1);
    expect(progress.currentProgress).to.equal(3);
    expect(progress.completed).to.equal(false);

    const incomplete = await questCore.getUserIncompleteQuests(user.address);
    expect(incomplete.questIds[0]).to.equal(1);
    expect(incomplete.progressPercentages[0]).to.equal(100);

    const progressByType = await questCore.getUserQuestProgressByType(user.address, 0);
    expect(progressByType.questIds[0]).to.equal(1);
    expect(progressByType.progresses[0].currentProgress).to.equal(3);
  });

  it("completa quests por reporter action y actualiza stats, popularidad y leaderboard", async function () {
    const { questCore, reporter, user, leveling, rewardsPool } = await loadFixture(deployQuestCoreFixture);

    await questCore.createQuest({
      category: 1,
      questType: 2,
      title: "Haz 2 acciones sociales",
      description: "Social quest",
      requirement: 2,
      xpReward: 75,
      polReward: ethers.parseEther("1"),
      startTime: 0,
      deadline: 0,
      completionLimit: 0,
    });

    await questCore.connect(reporter).notifyAction(user.address, 2, 2);

    await expect(questCore.connect(user).completeQuest(1))
      .to.emit(questCore, "QuestCompleted")
      .withArgs(user.address, 1, 75, ethers.parseEther("1"));

    const userProgress = await questCore.getUserQuestProgress(user.address, 1);
    expect(userProgress.completed).to.equal(true);
    expect(userProgress.currentProgress).to.equal(2);

    const stats = await questCore.getUserQuestStats(user.address);
    expect(stats.totalCompleted).to.equal(1);
    expect(stats.totalInProgress).to.equal(0);
    expect(stats.totalXPEarned).to.equal(75);

    const systemStats = await questCore.getQuestSystemStats();
    expect(systemStats.totalQuests).to.equal(1);
    expect(systemStats.totalCompletions).to.equal(1);

    const popular = await questCore.getMostPopularQuests(1);
    expect(popular.questIds[0]).to.equal(1);
    expect(popular.completionCounts[0]).to.equal(1);

    const leaderboard = await questCore.getQuestLeaderboard(1);
    expect(leaderboard.users[0]).to.equal(user.address);
    expect(leaderboard.completedCounts[0]).to.equal(1);
    expect(leaderboard.totalXP[0]).to.equal(75);

    const paidToUser = await rewardsPool.paidTo(user.address);
    expect(paidToUser).to.equal(ethers.parseEther("1"));

    const xpBreakdown = await leveling.getUserXPBreakdown(user.address);
    expect(xpBreakdown[8]).to.equal(75);
  });

  it("respeta startTime, deadline y completionLimit", async function () {
    const { questCore, reporter, user, otherUser } = await loadFixture(deployQuestCoreFixture);
    const now = await time.latest();

    await questCore.createQuest({
      category: 3,
      questType: 2,
      title: "Quest futura",
      description: "Aun no empieza",
      requirement: 1,
      xpReward: 10,
      polReward: 0,
      startTime: now + 3600,
      deadline: 0,
      completionLimit: 0,
    });

    await questCore.connect(reporter).notifyAction(user.address, 2, 1);
    await expect(questCore.connect(user).completeQuest(1)).to.be.revertedWithCustomError(questCore, "QuestNotStarted");

    await questCore.createQuest({
      category: 3,
      questType: 2,
      title: "Quest limitada",
      description: "Solo una vez global",
      requirement: 1,
      xpReward: 10,
      polReward: 0,
      startTime: 0,
      deadline: now + 1000,
      completionLimit: 1,
    });

    await questCore.connect(reporter).notifyAction(user.address, 2, 1);
    await questCore.connect(reporter).notifyAction(otherUser.address, 2, 1);
    await questCore.connect(user).completeQuest(2);
    await expect(questCore.connect(otherUser).completeQuest(2)).to.be.revertedWithCustomError(questCore, "CompletionLimitReached");

    const expiryBase = await time.latest();

    await questCore.createQuest({
      category: 3,
      questType: 2,
      title: "Quest expirable",
      description: "Caduca rapido",
      requirement: 1,
      xpReward: 10,
      polReward: 0,
      startTime: 0,
      deadline: expiryBase + 5,
      completionLimit: 0,
    });

    await questCore.connect(reporter).notifyAction(user.address, 2, 1);
    await time.increaseTo(expiryBase + 10);
    await expect(questCore.connect(user).completeQuest(3)).to.be.revertedWithCustomError(questCore, "QuestExpired");
  });

  it("permite refrescar snapshot manual y protege upgrade UUPS por rol", async function () {
    const { questCore, reporter, user, otherUser } = await loadFixture(deployQuestCoreFixture);

    await questCore.createQuest({
      category: 1,
      questType: 2,
      title: "Snapshot social",
      description: "Refresh manual",
      requirement: 3,
      xpReward: 15,
      polReward: 0,
      startTime: 0,
      deadline: 0,
      completionLimit: 0,
    });

    await questCore.connect(reporter).notifyAction(user.address, 2, 2);
    await expect(questCore.connect(otherUser).updateQuestProgress(user.address, 1)).to.be.reverted;

    await questCore.updateQuestProgress(user.address, 1);
    const updated = await questCore.userQuestProgress(user.address, 1);
    expect(updated.currentProgress).to.equal(2);

    const QuestCoreV2Mock = await ethers.getContractFactory("QuestCoreV2Mock");
    const newImplementation = await QuestCoreV2Mock.deploy();
    await newImplementation.waitForDeployment();

    await expect(questCore.connect(otherUser).upgradeTo(await newImplementation.getAddress())).to.be.reverted;

    const upgraded = await upgrades.upgradeProxy(await questCore.getAddress(), QuestCoreV2Mock, {
      kind: "uups",
    });
    await upgraded.waitForDeployment();

    expect(await upgraded.version()).to.equal(2);
  });
});