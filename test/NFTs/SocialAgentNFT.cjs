"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

// ─────────────────────────────────────────────
//  SocialAgentNFT  —  comprehensive unit tests
//  Also covers NuxAgentNFTBase shared behaviour
// ─────────────────────────────────────────────

describe("SocialAgentNFT (+ NuxAgentNFTBase)", function () {

  // ── Helper: build a minimal AgentConfig ───
  function socialConfig(overrides = {}) {
    return {
      name:             "Test Social Agent",
      description:      "desc",
      model:            "gemini-2.0-flash",
      category:         0, // SOCIAL
      systemPromptURI:  "ipfs://Qmsystem",
      userPromptURI:    "ipfs://Qmuser",
      promptsEncrypted: false,
      geminiConfig:     "0x",
      agentURI:         "ipfs://Qmagent",
      state:            0,  // INACTIVE
      mintedAt:         0,
      reputation:       0,
      ...overrides,
    };
  }

  // ── Fixture ────────────────────────────────
  async function deployFixture() {
    const [admin, user1, user2, renter, other] = await ethers.getSigners();

    const Treasury = await ethers.getContractFactory("MockTreasury");
    const treasury = await Treasury.deploy();

    const Leveling = await ethers.getContractFactory("MockLeveling");
    const leveling = await Leveling.deploy();

    const Social = await ethers.getContractFactory("SocialAgentNFT");
    const social = await upgrades.deployProxy(Social, [
      admin.address,
      await treasury.getAddress(),
      await leveling.getAddress(),
      ethers.ZeroAddress,   // erc6551Impl — zero = skip TBA
      0,                    // mintingFee = 0 for simplicity
    ], { kind: "uups" });
    await social.waitForDeployment();

    const ADMIN_ROLE    = await social.ADMIN_ROLE();
    const FACTORY_ROLE  = await social.FACTORY_ROLE();
    const REGISTRY_ROLE = await social.REGISTRY_ROLE();
    const RENTAL_ROLE   = await social.RENTAL_ROLE();

    return { social, treasury, leveling, admin, user1, user2, renter, other,
             ADMIN_ROLE, FACTORY_ROLE, REGISTRY_ROLE, RENTAL_ROLE };
  }

  // ── Helper: mint one token as admin ───────
  async function mintOne(social, admin, recipient) {
    const cfg = socialConfig();
    const tx = await social.connect(admin).mint(recipient.address, cfg, "ipfs://QmMeta");
    const receipt = await tx.wait();
    const event = receipt.logs.find(l => {
      try { return social.interface.parseLog(l)?.name === "Transfer"; } catch { return false; }
    });
    const parsed = social.interface.parseLog(event);
    return parsed.args.tokenId;
  }

  // ── 1. Deployment ──────────────────────────
  describe("Deployment", function () {
    it("sets correct name and symbol", async function () {
      const { social } = await loadFixture(deployFixture);
      expect(await social.name()).to.equal("NuxChain Social Agent");
      expect(await social.symbol()).to.equal("NXSOC");
    });

    it("admin has all expected roles", async function () {
      const { social, admin, ADMIN_ROLE, FACTORY_ROLE } = await loadFixture(deployFixture);
      expect(await social.hasRole(ADMIN_ROLE, admin.address)).to.equal(true);
    });

    it("cannot initialize twice", async function () {
      const { social, admin, treasury, leveling } = await loadFixture(deployFixture);
      await expect(
        social.initialize(admin.address, await treasury.getAddress(),
                          await leveling.getAddress(), ethers.ZeroAddress, 0)
      ).to.be.reverted;
    });

    it("mint fee starts at 0", async function () {
      const { social } = await loadFixture(deployFixture);
      expect(await social.mintingFee()).to.equal(0);
    });
  });

  // ── 2. Minting (admin.mint) ───────────────
  describe("mint (ADMIN_ROLE)", function () {
    it("mints a token and assigns to recipient", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      expect(await social.ownerOf(tokenId)).to.equal(user1.address);
    });

    it("emits AgentCreated event", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const cfg = socialConfig();
      await expect(social.connect(admin).mint(user1.address, cfg, "ipfs://QmMeta"))
        .to.emit(social, "AgentCreated");
    });

    it("stores AgentConfig correctly", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      const config = await social.getAgentConfig(tokenId);
      expect(config.name).to.equal("Test Social Agent");
      expect(config.model).to.equal("gemini-2.0-flash");
      expect(config.category).to.equal(0); // SOCIAL
    });

    it("initializes social profile", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      const prof = await social.getSocialProfile(tokenId);
      expect(prof.engagementScore).to.equal(0);
      expect(prof.verifiedCreator).to.equal(false);
    });

    it("reverts when minting wrong category", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const cfg = socialConfig({ category: 1 }); // TECH
      await expect(
        social.connect(admin).mint(user1.address, cfg, "ipfs://Q")
      ).to.be.revertedWith("SocialNFT: wrong category");
    });

    it("non-admin cannot call mint", async function () {
      const { social, user1, user2 } = await loadFixture(deployFixture);
      const cfg = socialConfig();
      await expect(
        social.connect(user1).mint(user2.address, cfg, "ipfs://Q")
      ).to.be.reverted;
    });

    it("increments agentCountByCategory", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      await mintOne(social, admin, user1);
      await mintOne(social, admin, user1);
      expect(await social.agentCountByCategory(0)).to.equal(2);
    });
  });

  // ── 3. mintFromFactory ────────────────────
  describe("mintFromFactory (FACTORY_ROLE)", function () {
    it("FACTORY_ROLE can mint", async function () {
      const { social, admin, user1, FACTORY_ROLE } = await loadFixture(deployFixture);
      await social.connect(admin).grantRole(FACTORY_ROLE, admin.address);
      const cfg = socialConfig();
      const tx = await social.connect(admin).mintFromFactory(user1.address, cfg, "ipfs://QmF");
      await expect(tx).to.emit(social, "AgentCreated");
    });

    it("non-factory cannot mintFromFactory", async function () {
      const { social, user1, user2 } = await loadFixture(deployFixture);
      const cfg = socialConfig();
      await expect(
        social.connect(user1).mintFromFactory(user2.address, cfg, "ipfs://Q")
      ).to.be.reverted;
    });
  });

  // ── 4. Minting with fee ───────────────────
  describe("Minting fee", function () {
    it("reverts when insufficient fee sent", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      // Set a non-zero fee via direct storage or re-deploy with fee
      // We test by deploying a fresh proxy with fee=1 ether
      const Social = await ethers.getContractFactory("SocialAgentNFT");
      const Treasury = await ethers.getContractFactory("MockTreasury");
      const Leveling = await ethers.getContractFactory("MockLeveling");
      const treasury2 = await Treasury.deploy();
      const leveling2 = await Leveling.deploy();
      const social2 = await upgrades.deployProxy(Social, [
        admin.address,
        await treasury2.getAddress(),
        await leveling2.getAddress(),
        ethers.ZeroAddress,
        ethers.parseEther("1"),
      ], { kind: "uups" });
      await social2.waitForDeployment();
      const cfg = socialConfig();
      await expect(
        social2.connect(admin).mint(user1.address, cfg, "ipfs://Q", { value: 0 })
      ).to.be.revertedWith("NuxBase: insufficient minting fee");
    });

    it("refunds excess fee to sender", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const Social = await ethers.getContractFactory("SocialAgentNFT");
      const Treasury = await ethers.getContractFactory("MockTreasury");
      const Leveling = await ethers.getContractFactory("MockLeveling");
      const t = await Treasury.deploy();
      const l = await Leveling.deploy();
      const social3 = await upgrades.deployProxy(Social, [
        admin.address, await t.getAddress(), await l.getAddress(),
        ethers.ZeroAddress, ethers.parseEther("0.01"),
      ], { kind: "uups" });
      await social3.waitForDeployment();
      const balBefore = await ethers.provider.getBalance(admin.address);
      const cfg = socialConfig();
      const tx = await social3.connect(admin).mint(
        user1.address, cfg, "ipfs://Q",
        { value: ethers.parseEther("0.05") } // send 5x the fee
      );
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;
      const balAfter = await ethers.provider.getBalance(admin.address);
      // should have paid only 0.01 + gas (not 0.05)
      const spent = balBefore - balAfter;
      expect(spent).to.be.lt(ethers.parseEther("0.02") + gasUsed);
    });
  });

  // ── 5. NuxAgentNFTBase — view functions ───
  describe("Base view functions", function () {
    it("getAgentData returns structured fields", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      const [name, desc, model] = await social.getAgentData(tokenId);
      expect(name).to.equal("Test Social Agent");
      expect(model).to.equal("gemini-2.0-flash");
    });

    it("getAgentState returns INACTIVE on mint", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      expect(await social.getAgentState(tokenId)).to.equal(0); // INACTIVE
    });

    it("getTokenBoundAccount returns address(0) when no impl", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      expect(await social.getTokenBoundAccount(tokenId)).to.equal(ethers.ZeroAddress);
    });

    it("reverts getAgentData for non-existent token", async function () {
      const { social } = await loadFixture(deployFixture);
      await expect(social.getAgentData(999)).to.be.revertedWith("NuxBase: token does not exist");
    });
  });

  // ── 6. setAgentState ──────────────────────
  describe("setAgentState", function () {
    it("owner can set their agent state", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await social.connect(user1).setAgentState(tokenId, 1); // ACTIVE
      expect(await social.getAgentState(tokenId)).to.equal(1);
    });

    it("emits AgentStateChanged", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await expect(social.connect(user1).setAgentState(tokenId, 2))
        .to.emit(social, "AgentStateChanged").withArgs(tokenId, 2);
    });

    it("non-owner cannot set state", async function () {
      const { social, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await expect(
        social.connect(user2).setAgentState(tokenId, 1)
      ).to.be.revertedWith("NuxBase: not authorized");
    });

    it("admin can set state even if not owner", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await expect(social.connect(admin).setAgentState(tokenId, 3))
        .to.emit(social, "AgentStateChanged").withArgs(tokenId, 3);
    });
  });

  // ── 7. updatePrompts ──────────────────────
  describe("updatePrompts", function () {
    it("owner can update prompts", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await social.connect(user1).updatePrompts(tokenId, "ipfs://newSystem", "ipfs://newUser", true);
      const [, , , userURI, systemURI, encrypted] = await social.getAgentData(tokenId);
      expect(systemURI).to.equal("ipfs://newSystem");
      expect(encrypted).to.equal(true);
    });

    it("non-owner cannot update prompts", async function () {
      const { social, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await expect(
        social.connect(user2).updatePrompts(tokenId, "", "", false)
      ).to.be.revertedWith("NuxBase: not token owner");
    });
  });

  // ── 8. setAgentURI ────────────────────────
  describe("setAgentURI", function () {
    it("owner can update agentURI", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await social.connect(user1).setAgentURI(tokenId, "ipfs://newAgent");
      expect(await social.getAgentURI(tokenId)).to.equal("ipfs://newAgent");
    });

    it("emits AgentURIUpdated", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await expect(social.connect(user1).setAgentURI(tokenId, "ipfs://x"))
        .to.emit(social, "AgentURIUpdated").withArgs(tokenId, "ipfs://x");
    });
  });

  // ── 9. setRenter / effectiveController ────
  describe("Rental integration (setRenter)", function () {
    it("RENTAL_ROLE can set renter", async function () {
      const { social, admin, user1, renter, RENTAL_ROLE } = await loadFixture(deployFixture);
      await social.connect(admin).grantRole(RENTAL_ROLE, admin.address);
      const tokenId = await mintOne(social, admin, user1);
      const expiry = (await time.latest()) + 86400;
      await social.connect(admin).setRenter(tokenId, renter.address, expiry);
      expect(await social.currentRenter(tokenId)).to.equal(renter.address);
    });

    it("effectiveController returns renter during active rental", async function () {
      const { social, admin, user1, renter, RENTAL_ROLE } = await loadFixture(deployFixture);
      await social.connect(admin).grantRole(RENTAL_ROLE, admin.address);
      const tokenId = await mintOne(social, admin, user1);
      const expiry = (await time.latest()) + 86400;
      await social.connect(admin).setRenter(tokenId, renter.address, expiry);
      expect(await social.effectiveController(tokenId)).to.equal(renter.address);
    });

    it("effectiveController returns owner after rental expires", async function () {
      const { social, admin, user1, renter, RENTAL_ROLE } = await loadFixture(deployFixture);
      await social.connect(admin).grantRole(RENTAL_ROLE, admin.address);
      const tokenId = await mintOne(social, admin, user1);
      const expiry = (await time.latest()) + 60;
      await social.connect(admin).setRenter(tokenId, renter.address, expiry);
      await time.increase(120);
      expect(await social.effectiveController(tokenId)).to.equal(user1.address);
    });

    it("non-RENTAL_ROLE cannot set renter", async function () {
      const { social, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await expect(
        social.connect(user2).setRenter(tokenId, user2.address, 9999999999)
      ).to.be.reverted;
    });
  });

  // ── 10. Social-specific task recording ────
  describe("Social profile functions", function () {
    it("REGISTRY_ROLE can record social task", async function () {
      const { social, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await social.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(social, admin, user1);
      await expect(social.connect(admin).recordSocialTask(tokenId, "VIRAL_CONTENT", 100, 50))
        .to.emit(social, "SocialTaskCompleted").withArgs(tokenId, "VIRAL_CONTENT", 100);
      const prof = await social.getSocialProfile(tokenId);
      expect(prof.engagementScore).to.equal(50);
    });

    it("REGISTRY_ROLE can record content generated", async function () {
      const { social, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await social.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(social, admin, user1);
      await social.connect(admin).recordContentGenerated(tokenId, "twitter");
      const prof = await social.getSocialProfile(tokenId);
      expect(prof.contentPieces).to.equal(1);
    });

    it("non-REGISTRY_ROLE cannot record social task", async function () {
      const { social, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await expect(
        social.connect(user2).recordSocialTask(tokenId, "task", 10, 5)
      ).to.be.reverted;
    });

    it("owner can add platform", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await social.connect(user1).addPlatform(tokenId, "twitter");
      await social.connect(user1).addPlatform(tokenId, "lens");
      const prof = await social.getSocialProfile(tokenId);
      expect(prof.platforms.length).to.equal(2);
    });

    it("non-owner cannot add platform", async function () {
      const { social, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await expect(
        social.connect(user2).addPlatform(tokenId, "discord")
      ).to.be.revertedWith("SocialNFT: not authorized");
    });

    it("admin can set verified creator", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await social.connect(admin).setVerifiedCreator(tokenId, true);
      const prof = await social.getSocialProfile(tokenId);
      expect(prof.verifiedCreator).to.equal(true);
    });

    it("REGISTRY_ROLE can update community size", async function () {
      const { social, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await social.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(social, admin, user1);
      await social.connect(admin).updateCommunitySize(tokenId, 5000);
      const prof = await social.getSocialProfile(tokenId);
      expect(prof.communitySize).to.equal(5000);
    });

    it("getSocialProfile reverts for non-existent token", async function () {
      const { social } = await loadFixture(deployFixture);
      await expect(social.getSocialProfile(999)).to.be.revertedWith("SocialNFT: token does not exist");
    });
  });

  // ── 11. ERC-721 transfers ─────────────────
  describe("ERC-721 transfers", function () {
    it("owner can transfer token", async function () {
      const { social, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      await social.connect(user1).transferFrom(user1.address, user2.address, tokenId);
      expect(await social.ownerOf(tokenId)).to.equal(user2.address);
    });

    it("tokenURI is set correctly", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const cfg = socialConfig();
      await social.connect(admin).mint(user1.address, cfg, "ipfs://QmSpecificMeta");
      const tokenId = 1n;
      expect(await social.tokenURI(tokenId)).to.equal("ipfs://QmSpecificMeta");
    });
  });

  // ── 12. ERC-2981 Royalties ────────────────
  describe("ERC-2981 Royalties", function () {
    it("correct royalty is calculated for a sale price", async function () {
      const { social, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(social, admin, user1);
      const salePrice = ethers.parseEther("1");
      const [receiver, royaltyAmount] = await social.royaltyInfo(tokenId, salePrice);
      // 500 bps = 5% of 1 ether = 0.05 ether
      expect(royaltyAmount).to.equal(ethers.parseEther("0.05"));
    });
  });

  // ── 13. XP awarded on mint ────────────────
  describe("XP on mint", function () {
    it("awards 50 XP to recipient on mint", async function () {
      const { social, admin, user1, leveling } = await loadFixture(deployFixture);
      await mintOne(social, admin, user1);
      expect(await leveling.xp(user1.address)).to.equal(50);
    });
  });
});
