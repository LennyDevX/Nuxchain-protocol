"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("MarketingAgentNFT", function () {

  function mktConfig(overrides = {}) {
    return {
      name: "Test Mkt Agent", description: "growth bot", model: "gemini-2.0-flash",
      category: 2, // MARKETING
      systemPromptURI: "ipfs://Qmsys", userPromptURI: "ipfs://Qmuser",
      promptsEncrypted: false, geminiConfig: "0x", agentURI: "ipfs://Qmagent",
      state: 0, mintedAt: 0, reputation: 0,
      ...overrides,
    };
  }

  async function deployFixture() {
    const [admin, user1, user2, renter] = await ethers.getSigners();

    const Treasury = await ethers.getContractFactory("MockTreasury");
    const treasury = await Treasury.deploy();
    const Leveling = await ethers.getContractFactory("MockLeveling");
    const leveling = await Leveling.deploy();

    const Mkt = await ethers.getContractFactory("MarketingAgentNFT");
    const mkt = await upgrades.deployProxy(Mkt, [
      admin.address, await treasury.getAddress(),
      await leveling.getAddress(), ethers.ZeroAddress, 0,
    ], { kind: "uups" });
    await mkt.waitForDeployment();

    const REGISTRY_ROLE = await mkt.REGISTRY_ROLE();
    const RENTAL_ROLE   = await mkt.RENTAL_ROLE();
    return { mkt, admin, user1, user2, renter, REGISTRY_ROLE, RENTAL_ROLE };
  }

  async function mintOne(mkt, admin, recipient) {
    const cfg = mktConfig();
    const tx = await mkt.connect(admin).mint(recipient.address, cfg, "ipfs://Q");
    const receipt = await tx.wait();
    const event = receipt.logs.find(l => {
      try { return mkt.interface.parseLog(l)?.name === "Transfer"; } catch { return false; }
    });
    return mkt.interface.parseLog(event).args.tokenId;
  }

  describe("Deployment", function () {
    it("name and symbol are correct", async function () {
      const { mkt } = await loadFixture(deployFixture);
      expect(await mkt.name()).to.equal("NuxChain Marketing Agent");
      expect(await mkt.symbol()).to.equal("NXMKT");
    });
  });

  describe("mint", function () {
    it("mints to recipient and initializes profile", async function () {
      const { mkt, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(mkt, admin, user1);
      expect(await mkt.ownerOf(tokenId)).to.equal(user1.address);
      const prof = await mkt.marketingProfiles(tokenId);
      expect(prof.referralMultiplier).to.equal(100);
    });

    it("reverts for wrong category", async function () {
      const { mkt, admin, user1 } = await loadFixture(deployFixture);
      await expect(
        mkt.connect(admin).mint(user1.address, mktConfig({ category: 0 }), "ipfs://Q")
      ).to.be.reverted;
    });
  });

  describe("launchCampaign", function () {
    it("owner can launch a campaign", async function () {
      const { mkt, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(mkt, admin, user1);
      await expect(
        mkt.connect(user1).launchCampaign(tokenId, "Q4 Push", "NFT holders", 0, 30)
      ).to.emit(mkt, "CampaignLaunched");
      const prof = await mkt.marketingProfiles(tokenId);
      expect(prof.campaignsLaunched).to.equal(1);
    });

    it("active renter can launch a campaign", async function () {
      const { mkt, admin, user1, renter, RENTAL_ROLE } = await loadFixture(deployFixture);
      const RENTAL_ROLE_BYTES = await mkt.RENTAL_ROLE();
      await mkt.connect(admin).grantRole(RENTAL_ROLE_BYTES, admin.address);
      const tokenId = await mintOne(mkt, admin, user1);
      const expiry  = (await time.latest()) + 86400 * 30;
      await mkt.connect(admin).setRenter(tokenId, renter.address, expiry);
      await expect(
        mkt.connect(renter).launchCampaign(tokenId, "Renter Camp", "all", 0, 10)
      ).to.emit(mkt, "CampaignLaunched");
    });

    it("reverts for non-owner non-renter", async function () {
      const { mkt, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(mkt, admin, user1);
      await expect(
        mkt.connect(user2).launchCampaign(tokenId, "X", "y", 0, 5)
      ).to.be.revertedWithCustomError(mkt, "NotAuthorized");
    });

    it("reverts on invalid duration (0 days)", async function () {
      const { mkt, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(mkt, admin, user1);
      await expect(
        mkt.connect(user1).launchCampaign(tokenId, "X", "y", 0, 0)
      ).to.be.revertedWithCustomError(mkt, "InvalidDuration");
    });

    it("reverts on duration > 365 days", async function () {
      const { mkt, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(mkt, admin, user1);
      await expect(
        mkt.connect(user1).launchCampaign(tokenId, "X", "y", 0, 400)
      ).to.be.revertedWithCustomError(mkt, "InvalidDuration");
    });

    it("reverts after max 50 campaigns", async function () {
      const { mkt, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(mkt, admin, user1);
      for (let i = 0; i < 50; i++) {
        await mkt.connect(user1).launchCampaign(tokenId, `Camp${i}`, "all", 0, 1);
      }
      await expect(
        mkt.connect(user1).launchCampaign(tokenId, "Over", "all", 0, 1)
      ).to.be.revertedWithCustomError(mkt, "MaxCampaignsReached");
    });
  });

  describe("REGISTRY_ROLE task recording", function () {
    it("recordConversion increments counters", async function () {
      const { mkt, admin, user1, user2, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await mkt.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(mkt, admin, user1);
      await mkt.connect(user1).launchCampaign(tokenId, "Camp", "all", 0, 7);
      await mkt.connect(admin).recordConversion(tokenId, 0, user2.address, 25);
      const prof = await mkt.marketingProfiles(tokenId);
      expect(prof.conversionsTracked).to.equal(1);
    });

    it("recordConversion reverts for invalid campaign index", async function () {
      const { mkt, admin, user1, user2, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await mkt.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(mkt, admin, user1);
      await expect(
        mkt.connect(admin).recordConversion(tokenId, 99, user2.address, 10)
      ).to.be.revertedWithCustomError(mkt, "InvalidCampaign");
    });

    it("recordCopyCreated increments copyPiecesCreated", async function () {
      const { mkt, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await mkt.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(mkt, admin, user1);
      await mkt.connect(admin).recordCopyCreated(tokenId, "NFT_LISTING", 20);
      const prof = await mkt.marketingProfiles(tokenId);
      expect(prof.copyPiecesCreated).to.equal(1);
    });

    it("updateReferralMultiplier caps at MAX (200)", async function () {
      const { mkt, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await mkt.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(mkt, admin, user1);
      await mkt.connect(admin).updateReferralMultiplier(tokenId, 999);
      const prof = await mkt.marketingProfiles(tokenId);
      expect(prof.referralMultiplier).to.equal(200);
    });

    it("updateReferralMultiplier below cap sets correctly", async function () {
      const { mkt, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await mkt.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(mkt, admin, user1);
      await mkt.connect(admin).updateReferralMultiplier(tokenId, 150);
      const prof = await mkt.marketingProfiles(tokenId);
      expect(prof.referralMultiplier).to.equal(150);
    });

    it("recordMarketAnalysis emits event", async function () {
      const { mkt, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await mkt.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(mkt, admin, user1);
      await expect(
        mkt.connect(admin).recordMarketAnalysis(tokenId, "ipfs://QmReport", 30)
      ).to.emit(mkt, "MarketAnalysisGenerated").withArgs(tokenId, "ipfs://QmReport");
    });
  });
});
