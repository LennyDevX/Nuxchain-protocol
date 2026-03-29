"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("TechAgentNFT", function () {

  function techConfig(overrides = {}) {
    return {
      name: "Test Tech Agent", description: "dev bot", model: "gemini-2.5-pro",
      category: 1, // TECH
      systemPromptURI: "ipfs://Qmsystem", userPromptURI: "ipfs://Qmuser",
      promptsEncrypted: false, geminiConfig: "0x", agentURI: "ipfs://Qmagent",
      state: 0, mintedAt: 0, reputation: 0,
      ...overrides,
    };
  }

  async function deployFixture() {
    const [admin, user1, user2, other] = await ethers.getSigners();

    const Treasury = await ethers.getContractFactory("MockTreasury");
    const treasury = await Treasury.deploy();
    const Leveling = await ethers.getContractFactory("MockLeveling");
    const leveling = await Leveling.deploy();

    const Tech = await ethers.getContractFactory("TechAgentNFT");
    const tech = await upgrades.deployProxy(Tech, [
      admin.address, await treasury.getAddress(),
      await leveling.getAddress(), ethers.ZeroAddress, 0,
    ], { kind: "uups" });
    await tech.waitForDeployment();

    const ADMIN_ROLE    = await tech.ADMIN_ROLE();
    const REGISTRY_ROLE = await tech.REGISTRY_ROLE();
    const FACTORY_ROLE  = await tech.FACTORY_ROLE();

    return { tech, treasury, leveling, admin, user1, user2, other,
             ADMIN_ROLE, REGISTRY_ROLE, FACTORY_ROLE };
  }

  async function mintOne(tech, admin, recipient) {
    const cfg = techConfig();
    const tx = await tech.connect(admin).mint(recipient.address, cfg, "ipfs://Q");
    const receipt = await tx.wait();
    const event = receipt.logs.find(l => {
      try { return tech.interface.parseLog(l)?.name === "Transfer"; } catch { return false; }
    });
    return tech.interface.parseLog(event).args.tokenId;
  }

  // ── 1. Deployment ──────────────────────────
  describe("Deployment", function () {
    it("sets correct name/symbol", async function () {
      const { tech } = await loadFixture(deployFixture);
      expect(await tech.name()).to.equal("NuxChain Tech Agent");
      expect(await tech.symbol()).to.equal("NXTECH");
    });
  });

  // ── 2. Minting ────────────────────────────
  describe("mint", function () {
    it("mints successfully to recipient", async function () {
      const { tech, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(tech, admin, user1);
      expect(await tech.ownerOf(tokenId)).to.equal(user1.address);
    });

    it("reverts for wrong category", async function () {
      const { tech, admin, user1 } = await loadFixture(deployFixture);
      const cfg = techConfig({ category: 0 }); // SOCIAL
      await expect(tech.connect(admin).mint(user1.address, cfg, "ipfs://Q"))
        .to.be.reverted; // custom error WrongCategory()
    });

    it("initializes techProfile with zero values", async function () {
      const { tech, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(tech, admin, user1);
      const prof = await tech.techProfiles(tokenId);
      expect(prof.auditsCompleted).to.equal(0);
      expect(prof.oracleEnabled).to.equal(false);
    });
  });

  // ── 3. mintFromFactory ────────────────────
  describe("mintFromFactory", function () {
    it("FACTORY_ROLE can mint via factory", async function () {
      const { tech, admin, user1, FACTORY_ROLE } = await loadFixture(deployFixture);
      await tech.connect(admin).grantRole(FACTORY_ROLE, admin.address);
      const cfg = techConfig();
      await expect(tech.connect(admin).mintFromFactory(user1.address, cfg, "ipfs://Q"))
        .to.emit(tech, "AgentCreated");
    });
  });

  // ── 4. addMonitoringRule ──────────────────
  describe("addMonitoringRule", function () {
    it("owner can add a monitoring rule", async function () {
      const { tech, admin, user1, other } = await loadFixture(deployFixture);
      const tokenId = await mintOne(tech, admin, user1);
      await expect(
        tech.connect(user1).addMonitoringRule(tokenId, other.address, "Transfer(address,address,uint256)", 1000)
      ).to.emit(tech, "MonitoringRuleAdded").withArgs(tokenId, other.address, "Transfer(address,address,uint256)");
    });

    it("admin can add a monitoring rule for any token", async function () {
      const { tech, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(tech, admin, user1);
      await tech.connect(admin).addMonitoringRule(tokenId, user1.address, "Approval(address,address,uint256)", 0);
      const rule = await tech.monitoringRules(tokenId, 0);
      expect(rule.active).to.equal(true);
    });

    it("reverts for zero target contract", async function () {
      const { tech, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(tech, admin, user1);
      await expect(
        tech.connect(user1).addMonitoringRule(tokenId, ethers.ZeroAddress, "Transfer()", 0)
      ).to.be.reverted; // InvalidTarget()
    });

    it("reverts after max 20 rules", async function () {
      const { tech, admin, user1, other } = await loadFixture(deployFixture);
      const tokenId = await mintOne(tech, admin, user1);
      for (let i = 0; i < 20; i++) {
        await tech.connect(user1).addMonitoringRule(tokenId, other.address, `Event${i}()`, i);
      }
      await expect(
        tech.connect(user1).addMonitoringRule(tokenId, other.address, "Event21()", 0)
      ).to.be.reverted; // MaxRulesReached()
    });

    it("non-owner non-admin cannot add rule", async function () {
      const { tech, admin, user1, user2, other } = await loadFixture(deployFixture);
      const tokenId = await mintOne(tech, admin, user1);
      await expect(
        tech.connect(user2).addMonitoringRule(tokenId, other.address, "T()", 0)
      ).to.be.reverted; // NotAuthorized()
    });
  });

  // ── 5. isMonitored deduplication ─────────
  describe("isMonitored deduplication", function () {
    it("same contract not added twice to monitoredContracts", async function () {
      const { tech, admin, user1, other } = await loadFixture(deployFixture);
      const tokenId = await mintOne(tech, admin, user1);
      await tech.connect(user1).addMonitoringRule(tokenId, other.address, "Event1()", 100);
      await tech.connect(user1).addMonitoringRule(tokenId, other.address, "Event2()", 200);
      expect(await tech.isMonitored(tokenId, other.address)).to.equal(true);
    });
  });

  // ── 6. REGISTRY_ROLE task recording ───────
  describe("Task recording (REGISTRY_ROLE)", function () {
    it("recordAudit increments auditsCompleted and bugsFound", async function () {
      const { tech, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await tech.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(tech, admin, user1);
      await tech.connect(admin).recordAudit(tokenId, user1.address, 3, 50);
      const prof = await tech.techProfiles(tokenId);
      expect(prof.auditsCompleted).to.equal(1);
      expect(prof.bugsFound).to.equal(3);
    });

    it("emits AuditCompleted event", async function () {
      const { tech, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await tech.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(tech, admin, user1);
      await expect(tech.connect(admin).recordAudit(tokenId, user1.address, 2, 100))
        .to.emit(tech, "AuditCompleted").withArgs(tokenId, user1.address, 2, 100);
    });

    it("recordAlert increments alertsTriggered", async function () {
      const { tech, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await tech.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(tech, admin, user1);
      await tech.connect(admin).recordAlert(tokenId, user1.address, "ANOMALY", 1000000n);
      const prof = await tech.techProfiles(tokenId);
      expect(prof.alertsTriggered).to.equal(1);
    });

    it("recordGasOptimization adds to gasOptimizationsSaved", async function () {
      const { tech, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await tech.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(tech, admin, user1);
      await tech.connect(admin).recordGasOptimization(tokenId, 500_000);
      const prof = await tech.techProfiles(tokenId);
      expect(prof.gasOptimizationsSaved).to.equal(500_000);
    });

    it("setOracleEnabled toggles the flag", async function () {
      const { tech, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(tech, admin, user1);
      await tech.connect(admin).setOracleEnabled(tokenId, true);
      const prof = await tech.techProfiles(tokenId);
      expect(prof.oracleEnabled).to.equal(true);
    });

    it("non-REGISTRY_ROLE reverts on recordAudit", async function () {
      const { tech, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(tech, admin, user1);
      await expect(tech.connect(user2).recordAudit(tokenId, user2.address, 1, 10)).to.be.reverted;
    });
  });
});
