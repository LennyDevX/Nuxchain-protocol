const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("NuxTapGame", function () {
  async function deployFixture() {
    const [owner, player, buyer, dashboardAdmin] = await ethers.getSigners();

    const RegistryFactory = await ethers.getContractFactory("NuxAgentRegistry");
    const registry = await upgrades.deployProxy(RegistryFactory, [owner.address], {
      initializer: "initialize",
      kind: "uups"
    });
    await registry.waitForDeployment();

    const TreasuryFactory = await ethers.getContractFactory("NuxTapTreasury");
    const treasury = await upgrades.deployProxy(TreasuryFactory, [owner.address], {
      initializer: "initialize",
      kind: "uups"
    });
    await treasury.waitForDeployment();

    const StoreFactory = await ethers.getContractFactory("NuxTapItemStore");
    const store = await upgrades.deployProxy(StoreFactory, [
      owner.address,
      await treasury.getAddress(),
      "ipfs://nuxtap-items/{id}.json"
    ], {
      initializer: "initialize",
      kind: "uups"
    });
    await store.waitForDeployment();

    const GameFactory = await ethers.getContractFactory("NuxTapGame");
    const game = await upgrades.deployProxy(GameFactory, [
      owner.address,
      await treasury.getAddress(),
      await store.getAddress(),
      await registry.getAddress()
    ], {
      initializer: "initialize",
      kind: "uups"
    });
    await game.waitForDeployment();

    await treasury.grantStoreRole(await store.getAddress());
    await treasury.grantGameRole(await game.getAddress());
    await store.grantGameRole(await game.getAddress());

    await owner.sendTransaction({
      to: await treasury.getAddress(),
      value: ethers.parseEther("25")
    });

    await store.configureItem(1, 1, ethers.parseEther("0.01"), 4, 0, 0, true, true, ethers.ZeroAddress);
    await store.configureItem(2, 2, ethers.parseEther("0.02"), 2500, 3600, 0, true, true, ethers.ZeroAddress);
    await store.configureItem(3, 3, ethers.parseEther("0.005"), 1, 0, 0, true, true, ethers.ZeroAddress);

    const MockTapAgentNFT = await ethers.getContractFactory("MockTapAgentNFT");
    const agentNft = await MockTapAgentNFT.deploy();
    await agentNft.waitForDeployment();

    await registry.registerNFTContract(await agentNft.getAddress());
    await game.setSupportedNFTContract(await agentNft.getAddress(), true);

    await store.configureItem(4, 4, ethers.parseEther("0.5"), 0, 0, 0, true, false, await agentNft.getAddress());

    return {
      owner,
      player,
      buyer,
      dashboardAdmin,
      registry,
      treasury,
      store,
      game,
      agentNft
    };
  }

  it("settles tap sessions, applies upgrades, and claims with a withdraw pass", async function () {
    const { player, treasury, store, game } = await loadFixture(deployFixture);

    await store.connect(player).purchaseItem(1, 1, { value: ethers.parseEther("0.01") });
    await store.connect(player).purchaseItem(2, 1, { value: ethers.parseEther("0.02") });
    await store.connect(player).purchaseItem(3, 1, { value: ethers.parseEther("0.005") });

    await game.connect(player).settleTapSession(100);
    await game.connect(player).applyAutoTapItem(1);
    await game.connect(player).activateBooster(2);

    await time.increase(900);
    await game.connect(player).settleTapSession(50);

    const profileBeforeClaim = await game.getPlayerProfile(player.address);
    expect(profileBeforeClaim.autoTapRate).to.equal(4n);
    expect(profileBeforeClaim.unclaimedRewards).to.be.gt(0n);
    expect(profileBeforeClaim.totalSessions).to.equal(2n);

    await expect(game.connect(player).claimRewards(profileBeforeClaim.unclaimedRewards, 3)).to.not.be.reverted;

    const profileAfterClaim = await game.getPlayerProfile(player.address);
    expect(profileAfterClaim.unclaimedRewards).to.equal(0n);
    expect(profileAfterClaim.claimedRewards).to.equal(profileBeforeClaim.unclaimedRewards);

    const stats = await treasury.getTreasuryStats();
    expect(stats.distributed).to.equal(profileBeforeClaim.unclaimedRewards);
    expect(stats.feesRetained).to.equal(0n);
  });

  it("links a registered NFT agent to the player profile", async function () {
    const { player, game, agentNft } = await loadFixture(deployFixture);

    await agentNft.mint(player.address);
    await game.connect(player).linkAgent(await agentNft.getAddress(), 0);

    const profile = await game.getPlayerProfile(player.address);
    expect(profile.linkedNftContract).to.equal(await agentNft.getAddress());
    expect(profile.linkedTokenId).to.equal(0n);
  });

  it("gives linked agents a real tap reward bonus based on registry activity", async function () {
    const { owner, player, buyer, registry, game, agentNft } = await loadFixture(deployFixture);

    await registry.grantGameRole(owner.address);
    await agentNft.mint(player.address);

    for (let count = 0; count < 10; count++) {
      await registry.recordTaskExecution(0, player.address, 0);
    }

    await game.connect(player).linkAgent(await agentNft.getAddress(), 0);

    expect(await game.previewLinkedAgentBonusBps(player.address)).to.be.gt(await game.linkedAgentBaseBonusBps());

    await game.connect(player).settleTapSession(100);
    await game.connect(buyer).settleTapSession(100);

    const linkedProfile = await game.getPlayerProfile(player.address);
    const baseProfile = await game.getPlayerProfile(buyer.address);

    expect(linkedProfile.unclaimedRewards).to.be.gt(baseProfile.unclaimedRewards);
    expect(linkedProfile.totalScore).to.be.gt(baseProfile.totalScore);
  });

  it("sells agent NFTs through the NuxTap store", async function () {
    const { owner, buyer, store, agentNft } = await loadFixture(deployFixture);

    await agentNft.mint(owner.address);
    await agentNft.approve(await store.getAddress(), 0);
    await store.depositAgentInventory(4, 0);

    await store.connect(buyer).purchaseItem(4, 1, { value: ethers.parseEther("0.5") });

    expect(await agentNft.ownerOf(0)).to.equal(buyer.address);
    expect(await store.agentInventoryCount(4)).to.equal(0n);
  });
});