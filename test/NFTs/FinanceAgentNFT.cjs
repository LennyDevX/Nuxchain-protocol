"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("FinanceAgentNFT", function () {

  function finConfig(overrides = {}) {
    return {
      name: "Finance Bot", description: "defi agent", model: "gemini-2.5-pro",
      category: 3, // FINANCE
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

    const Fin = await ethers.getContractFactory("FinanceAgentNFT");
    const fin = await upgrades.deployProxy(Fin, [
      admin.address, await treasury.getAddress(),
      await leveling.getAddress(), ethers.ZeroAddress, 0,
    ], { kind: "uups" });
    await fin.waitForDeployment();

    const REGISTRY_ROLE = await fin.REGISTRY_ROLE();
    const ADMIN_ROLE    = await fin.ADMIN_ROLE();
    const RENTAL_ROLE   = await fin.RENTAL_ROLE();
    return { fin, admin, user1, user2, renter, REGISTRY_ROLE, ADMIN_ROLE, RENTAL_ROLE };
  }

  async function mintOne(fin, admin, recipient) {
    const tx = await fin.connect(admin).mint(recipient.address, finConfig(), "ipfs://Q");
    const receipt = await tx.wait();
    const event = receipt.logs.find(l => {
      try { return fin.interface.parseLog(l)?.name === "Transfer"; } catch { return false; }
    });
    return fin.interface.parseLog(event).args.tokenId;
  }

  // ============================================================
  describe("Deployment", function () {
    it("name and symbol are correct", async function () {
      const { fin } = await loadFixture(deployFixture);
      expect(await fin.name()).to.equal("NuxChain Finance Agent");
      expect(await fin.symbol()).to.equal("NXFIN");
    });
  });

  // ============================================================
  describe("mint", function () {
    it("mints to recipient and initializes profile with MODERATE risk", async function () {
      const { fin, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      expect(await fin.ownerOf(tokenId)).to.equal(user1.address);
      const prof = await fin.financeProfiles(tokenId);
      expect(prof.riskProfile).to.equal(1); // MODERATE = 1
      expect(prof.autoCompoundEnabled).to.equal(false);
    });

    it("reverts when category != FINANCE", async function () {
      const { fin, admin, user1 } = await loadFixture(deployFixture);
      await expect(
        fin.connect(admin).mint(user1.address, finConfig({ category: 0 }), "ipfs://Q")
      ).to.be.revertedWithCustomError(fin, "WrongCategory");
    });

    it("reverts for non-admin caller", async function () {
      const { fin, user1, user2 } = await loadFixture(deployFixture);
      await expect(
        fin.connect(user2).mint(user1.address, finConfig(), "ipfs://Q")
      ).to.be.reverted;
    });
  });

  // ============================================================
  describe("setRiskProfile", function () {
    it("owner can change risk profile", async function () {
      const { fin, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      await expect(fin.connect(user1).setRiskProfile(tokenId, 0))
        .to.emit(fin, "RiskProfileUpdated").withArgs(tokenId, 0);
      const prof = await fin.financeProfiles(tokenId);
      expect(prof.riskProfile).to.equal(0); // CONSERVATIVE
    });

    it("non-owner cannot change risk profile", async function () {
      const { fin, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      await expect(fin.connect(user2).setRiskProfile(tokenId, 2))
        .to.be.revertedWithCustomError(fin, "NotOwner");
    });

    it("reverts for nonexistent token", async function () {
      const { fin, user1 } = await loadFixture(deployFixture);
      await expect(fin.connect(user1).setRiskProfile(9999, 0))
        .to.be.revertedWithCustomError(fin, "TokenNotFound");
    });
  });

  // ============================================================
  describe("enableAutoCompound", function () {
    it("owner can enable auto-compound with a staking contract", async function () {
      const { fin, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      const fakeStaking = user2.address;
      await expect(fin.connect(user1).enableAutoCompound(tokenId, fakeStaking))
        .to.emit(fin, "AutoCompoundEnabled").withArgs(tokenId, fakeStaking);
      const prof = await fin.financeProfiles(tokenId);
      expect(prof.autoCompoundEnabled).to.equal(true);
      expect(prof.stakingContract).to.equal(fakeStaking);
    });

    it("reverts with zero address staking contract", async function () {
      const { fin, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      await expect(fin.connect(user1).enableAutoCompound(tokenId, ethers.ZeroAddress))
        .to.be.revertedWithCustomError(fin, "InvalidAlert");
    });

    it("non-owner cannot enable auto-compound", async function () {
      const { fin, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      await expect(fin.connect(user2).enableAutoCompound(tokenId, user2.address))
        .to.be.revertedWithCustomError(fin, "NotOwner");
    });
  });

  // ============================================================
  describe("setPriceAlert", function () {
    it("owner can set a price alert", async function () {
      const { fin, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      const fakeToken = user2.address;
      await expect(fin.connect(user1).setPriceAlert(tokenId, fakeToken, 3000_00000000n, true))
        .to.emit(fin, "PriceAlertSet").withArgs(tokenId, fakeToken, 3000_00000000n, true);
    });

    it("active renter can set a price alert", async function () {
      const { fin, admin, user1, renter, RENTAL_ROLE } = await loadFixture(deployFixture);
      await fin.connect(admin).grantRole(RENTAL_ROLE, admin.address);
      const tokenId = await mintOne(fin, admin, user1);
      const expiry = (await time.latest()) + 86400;
      await fin.connect(admin).setRenter(tokenId, renter.address, expiry);
      await expect(fin.connect(renter).setPriceAlert(tokenId, renter.address, 1000n, false))
        .to.emit(fin, "PriceAlertSet");
    });

    it("reverts after 20 alerts", async function () {
      const { fin, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      for (let i = 0; i < 20; i++) {
        await fin.connect(user1).setPriceAlert(tokenId, user2.address, BigInt(i + 1) * 100n, i % 2 === 0);
      }
      await expect(fin.connect(user1).setPriceAlert(tokenId, user2.address, 9999n, true))
        .to.be.revertedWithCustomError(fin, "MaxAlertsReached");
    });

    it("reverts for unauthorized caller", async function () {
      const { fin, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      await expect(fin.connect(user2).setPriceAlert(tokenId, user2.address, 100n, true))
        .to.be.revertedWithCustomError(fin, "NotAuthorized");
    });
  });

  // ============================================================
  describe("REGISTRY_ROLE task recording", function () {
    it("recordPortfolioAnalysis updates value and emits event", async function () {
      const { fin, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await fin.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(fin, admin, user1);
      await expect(fin.connect(admin).recordPortfolioAnalysis(tokenId, 50000n, 40))
        .to.emit(fin, "PortfolioAnalysisCompleted").withArgs(tokenId, 50000n, 40);
      const prof = await fin.financeProfiles(tokenId);
      expect(prof.portfolioValue).to.equal(50000n);
      expect(prof.analysesCompleted).to.equal(1);
    });

    it("recordYieldStrategy accumulates estimatedAPY", async function () {
      const { fin, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await fin.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(fin, admin, user1);
      await fin.connect(admin).recordYieldStrategy(tokenId, "ipfs://Qm1", 500, 30);
      await fin.connect(admin).recordYieldStrategy(tokenId, "ipfs://Qm2", 300, 30);
      const prof = await fin.financeProfiles(tokenId);
      expect(prof.yieldOptimized).to.equal(800n);
    });

    it("triggerPriceAlert marks alert triggered and increments counter", async function () {
      const { fin, admin, user1, user2, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await fin.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(fin, admin, user1);
      await fin.connect(user1).setPriceAlert(tokenId, user2.address, 3000n, true);
      await expect(fin.connect(admin).triggerPriceAlert(tokenId, 0, 3200n))
        .to.emit(fin, "PriceAlertTriggered");
      const prof = await fin.financeProfiles(tokenId);
      expect(prof.alertsTriggered).to.equal(1n);
    });

    it("triggerPriceAlert reverts on AlreadyTriggered", async function () {
      const { fin, admin, user1, user2, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await fin.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(fin, admin, user1);
      await fin.connect(user1).setPriceAlert(tokenId, user2.address, 3000n, true);
      await fin.connect(admin).triggerPriceAlert(tokenId, 0, 3200n);
      await expect(fin.connect(admin).triggerPriceAlert(tokenId, 0, 3100n))
        .to.be.revertedWithCustomError(fin, "AlreadyTriggered");
    });

    it("triggerPriceAlert reverts for invalid alert index", async function () {
      const { fin, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await fin.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(fin, admin, user1);
      await expect(fin.connect(admin).triggerPriceAlert(tokenId, 99, 100n))
        .to.be.revertedWithCustomError(fin, "InvalidAlert");
    });
  });

  // ============================================================
  describe("grantStakingAPYBoost", function () {
    it("admin can grant APY boost", async function () {
      const { fin, admin, user1, ADMIN_ROLE } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      await expect(fin.connect(admin).grantStakingAPYBoost(tokenId, 500))
        .to.emit(fin, "StakingAPYBoostGranted").withArgs(tokenId, 500);
      const prof = await fin.financeProfiles(tokenId);
      expect(prof.stakingAPYBoost).to.equal(500n);
    });

    it("non-admin cannot grant APY boost", async function () {
      const { fin, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(fin, admin, user1);
      await expect(fin.connect(user2).grantStakingAPYBoost(tokenId, 100))
        .to.be.reverted;
    });
  });

  // ============================================================
  describe("mintFromFactory", function () {
    it("reverts if called without FACTORY_ROLE", async function () {
      const { fin, user1 } = await loadFixture(deployFixture);
      await expect(
        fin.connect(user1).mintFromFactory(user1.address, finConfig(), "ipfs://Q")
      ).to.be.reverted;
    });

    it("FACTORY_ROLE can mint", async function () {
      const { fin, admin, user1 } = await loadFixture(deployFixture);
      const FACTORY_ROLE = await fin.FACTORY_ROLE();
      await fin.connect(admin).grantRole(FACTORY_ROLE, admin.address);
      const tx = await fin.connect(admin).mintFromFactory(user1.address, finConfig(), "ipfs://Q");
      await expect(tx).to.emit(fin, "Transfer");
    });
  });
});
