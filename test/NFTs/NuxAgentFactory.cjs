"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

// Category enum values must match Solidity enum AgentCategory
const CATEGORY = { SOCIAL: 0, TECH: 1, MARKETING: 2, FINANCE: 3, BUSINESS: 4 };

describe("NuxAgentFactory", function () {

  async function deployFullFixture() {
    const [admin, user1, user2] = await ethers.getSigners();

    const Treasury = await ethers.getContractFactory("MockTreasury");
    const treasury = await Treasury.deploy();
    const Leveling = await ethers.getContractFactory("MockLeveling");
    const leveling = await Leveling.deploy();
    const treasuryAddr  = await treasury.getAddress();
    const levelingAddr  = await leveling.getAddress();

    // Deploy the factory (non-upgradeable imports but OK with unsafeAllow)
    const Factory = await ethers.getContractFactory("NuxAgentFactory");
    const factory = await upgrades.deployProxy(
      Factory,
      [admin.address, treasuryAddr],
      { kind: "uups", unsafeAllow: ["constructor"] }
    );
    await factory.waitForDeployment();
    const factoryAddr = await factory.getAddress();

    // Deploy all 5 category NFTs
    async function deployCategory(name, args) {
      const CF = await ethers.getContractFactory(name);
      const c  = await upgrades.deployProxy(CF, args, { kind: "uups" });
      await c.waitForDeployment();
      return c;
    }
    const initArgs = [admin.address, treasuryAddr, levelingAddr, ethers.ZeroAddress, 0];

    const social   = await deployCategory("SocialAgentNFT",   initArgs);
    const tech     = await deployCategory("TechAgentNFT",     initArgs);
    const mkt      = await deployCategory("MarketingAgentNFT",initArgs);
    const fin      = await deployCategory("FinanceAgentNFT",  initArgs);
    const biz      = await deployCategory("BusinessAgentNFT", initArgs);

    const FACTORY_ROLE = ethers.id("FACTORY_ROLE");

    // Wire up: grant FACTORY_ROLE on each NFT, then register in factory
    for (const [cat, nft] of [
      [CATEGORY.SOCIAL,    social],
      [CATEGORY.TECH,      tech],
      [CATEGORY.MARKETING, mkt],
      [CATEGORY.FINANCE,   fin],
      [CATEGORY.BUSINESS,  biz],
    ]) {
      await nft.connect(admin).grantRole(FACTORY_ROLE, factoryAddr);
      await factory.connect(admin).setCategoryContract(cat, await nft.getAddress());
    }

    return { factory, social, tech, mkt, fin, biz, treasury, leveling, admin, user1, user2 };
  }

  function socialParams(overrides = {}) {
    return {
      name: "My Social Agent", description: "social", model: "",
      category: CATEGORY.SOCIAL,
      systemPromptURI: "", userPromptURI: "", promptsEncrypted: false,
      geminiConfig: "0x", agentURI: "ipfs://Qmagent", tokenURI: "ipfs://Qmtoken",
      ...overrides,
    };
  }

  // ============================================================
  describe("Deployment", function () {
    it("initializes admin roles", async function () {
      const { factory, admin } = await loadFixture(deployFullFixture);
      const ADMIN_ROLE = await factory.ADMIN_ROLE();
      expect(await factory.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
    });

    it("all 5 category contracts are active", async function () {
      const { factory } = await loadFixture(deployFullFixture);
      for (const cat of [0, 1, 2, 3, 4]) {
        const tmpl = await factory.getTemplate(cat);
        expect(tmpl.active).to.be.true;
        expect(tmpl.nftContract).to.not.equal(ethers.ZeroAddress);
      }
    });

    it("reverts re-initialization", async function () {
      const { factory, admin, treasury } = await loadFixture(deployFullFixture);
      await expect(factory.initialize(admin.address, await treasury.getAddress()))
        .to.be.reverted;
    });
  });

  // ============================================================
  describe("setCategoryContract", function () {
    it("admin can update a category contract", async function () {
      const { factory, social, admin } = await loadFixture(deployFullFixture);
      await expect(
        factory.connect(admin).setCategoryContract(CATEGORY.SOCIAL, await social.getAddress())
      ).to.emit(factory, "CategoryContractSet");
    });

    it("non-admin cannot set category contract", async function () {
      const { factory, social, user1 } = await loadFixture(deployFullFixture);
      await expect(
        factory.connect(user1).setCategoryContract(CATEGORY.SOCIAL, await social.getAddress())
      ).to.be.reverted;
    });

    it("reverts with zero address", async function () {
      const { factory, admin } = await loadFixture(deployFullFixture);
      await expect(
        factory.connect(admin).setCategoryContract(CATEGORY.SOCIAL, ethers.ZeroAddress)
      ).to.be.revertedWith("Factory: invalid contract");
    });
  });

  // ============================================================
  describe("mintAgent — routing", function () {
    it("mints a SOCIAL agent and records statistics", async function () {
      const { factory, social, user1 } = await loadFixture(deployFullFixture);
      const [tokenId] = await factory.connect(user1).mintAgent.staticCall(socialParams(), user1.address);
      const tx = await factory.connect(user1).mintAgent(socialParams(), user1.address);
      const receipt = await tx.wait();
      expect(await factory.totalAgentsMinted()).to.equal(1n);
      expect(await factory.mintsByCategory(CATEGORY.SOCIAL)).to.equal(1n);
      const agentsOfUser = await factory.getAgentsByOwner(user1.address);
      expect(agentsOfUser.length).to.equal(1);
    });

    it("emits AgentMintedViaFactory with correct category", async function () {
      const { factory, social, user1 } = await loadFixture(deployFullFixture);
      const socialAddr = await social.getAddress();
      await expect(factory.connect(user1).mintAgent(socialParams(), user1.address))
        .to.emit(factory, "AgentMintedViaFactory")
        .withArgs(user1.address, 1n, CATEGORY.SOCIAL, socialAddr);
    });

    it("routes TECH mint to TechAgentNFT", async function () {
      const { factory, tech, user1 } = await loadFixture(deployFullFixture);
      const tx = await factory.connect(user1).mintAgent(socialParams({ category: CATEGORY.TECH }), user1.address);
      await expect(tx).to.emit(factory, "AgentMintedViaFactory");
      expect(await tech.balanceOf(user1.address)).to.equal(1n);
    });

    it("routes MARKETING mint to MarketingAgentNFT", async function () {
      const { factory, mkt, user1 } = await loadFixture(deployFullFixture);
      await factory.connect(user1).mintAgent(socialParams({ category: CATEGORY.MARKETING }), user1.address);
      expect(await mkt.balanceOf(user1.address)).to.equal(1n);
    });

    it("routes FINANCE mint to FinanceAgentNFT", async function () {
      const { factory, fin, user1 } = await loadFixture(deployFullFixture);
      await factory.connect(user1).mintAgent(socialParams({ category: CATEGORY.FINANCE }), user1.address);
      expect(await fin.balanceOf(user1.address)).to.equal(1n);
    });

    it("routes BUSINESS mint to BusinessAgentNFT", async function () {
      const { factory, biz, user1 } = await loadFixture(deployFullFixture);
      await factory.connect(user1).mintAgent(socialParams({ category: CATEGORY.BUSINESS }), user1.address);
      expect(await biz.balanceOf(user1.address)).to.equal(1n);
    });

    it("reverts for zero recipient address", async function () {
      const { factory, user1 } = await loadFixture(deployFullFixture);
      await expect(
        factory.connect(user1).mintAgent(socialParams(), ethers.ZeroAddress)
      ).to.be.revertedWith("Factory: invalid recipient");
    });

    it("uses template defaults when model/systemPromptURI are empty", async function () {
      const { factory, social, user1 } = await loadFixture(deployFullFixture);
      // model="" → uses template default "gemini-2.0-flash"
      // No revert = defaults applied
      await expect(factory.connect(user1).mintAgent(socialParams({ model: "" }), user1.address))
        .to.not.be.reverted;
    });
  });

  // ============================================================
  describe("mintAgentBatch", function () {
    it("mints 3 agents in one batch", async function () {
      const { factory, social, tech, mkt, user1 } = await loadFixture(deployFullFixture);
      const batch = [
        socialParams({ category: CATEGORY.SOCIAL }),
        socialParams({ category: CATEGORY.TECH }),
        socialParams({ category: CATEGORY.MARKETING }),
      ];
      const tx = await factory.connect(user1).mintAgentBatch(batch, user1.address);
      await tx.wait();
      expect(await factory.totalAgentsMinted()).to.equal(3n);
      expect(await social.balanceOf(user1.address)).to.equal(1n);
      expect(await tech.balanceOf(user1.address)).to.equal(1n);
      expect(await mkt.balanceOf(user1.address)).to.equal(1n);
    });

    it("reverts for empty batch", async function () {
      const { factory, user1 } = await loadFixture(deployFullFixture);
      await expect(factory.connect(user1).mintAgentBatch([], user1.address))
        .to.be.revertedWith("Factory: batch 1-10");
    });

    it("reverts for batch > 10", async function () {
      const { factory, user1 } = await loadFixture(deployFullFixture);
      const batch = new Array(11).fill(socialParams());
      await expect(factory.connect(user1).mintAgentBatch(batch, user1.address))
        .to.be.revertedWith("Factory: batch 1-10");
    });

    it("reverts for zero recipient", async function () {
      const { factory, user1 } = await loadFixture(deployFullFixture);
      await expect(factory.connect(user1).mintAgentBatch([socialParams()], ethers.ZeroAddress))
        .to.be.revertedWith("Factory: invalid recipient");
    });

    it("refunds excess ETH on batch", async function () {
      const { factory, user1 } = await loadFixture(deployFullFixture);
      const balBefore = await ethers.provider.getBalance(user1.address);
      // mintingFee = 0, so any sent ETH is excess
      const tx = await factory.connect(user1).mintAgentBatch(
        [socialParams()], user1.address,
        { value: ethers.parseEther("0.01") }
      );
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;
      const balAfter = await ethers.provider.getBalance(user1.address);
      // After refund, user should only be down by gas
      expect(balBefore - balAfter).to.be.closeTo(gasUsed, ethers.parseEther("0.0001"));
    });
  });

  // ============================================================
  describe("updateCategoryTemplate", function () {
    it("admin can update template fields", async function () {
      const { factory, admin } = await loadFixture(deployFullFixture);
      await factory.connect(admin).updateCategoryTemplate(
        CATEGORY.SOCIAL, "ipfs://QmNewSoc", "gemini-2.0-ultra", "0x"
      );
      const tmpl = await factory.getTemplate(CATEGORY.SOCIAL);
      expect(tmpl.defaultSystemPromptURI).to.equal("ipfs://QmNewSoc");
      expect(tmpl.defaultModel).to.equal("gemini-2.0-ultra");
    });

    it("non-admin cannot update template", async function () {
      const { factory, user1 } = await loadFixture(deployFullFixture);
      await expect(
        factory.connect(user1).updateCategoryTemplate(CATEGORY.SOCIAL, "", "", "0x")
      ).to.be.reverted;
    });
  });

  // ============================================================
  describe("getMintingFee / getAllCategoryContracts", function () {
    it("getMintingFee returns 0 for fee-free categories", async function () {
      const { factory } = await loadFixture(deployFullFixture);
      expect(await factory.getMintingFee(CATEGORY.SOCIAL)).to.equal(0n);
    });

    it("getAllCategoryContracts returns 5 non-zero addresses", async function () {
      const { factory } = await loadFixture(deployFullFixture);
      const addresses = await factory.getAllCategoryContracts();
      expect(addresses.length).to.equal(5);
      for (const addr of addresses) {
        expect(addr).to.not.equal(ethers.ZeroAddress);
      }
    });
  });
});
