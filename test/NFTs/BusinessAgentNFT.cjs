"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("BusinessAgentNFT", function () {

  function bizConfig(overrides = {}) {
    return {
      name: "Biz Bot", description: "business agent", model: "gemini-2.0-flash",
      category: 4, // BUSINESS
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

    const Biz = await ethers.getContractFactory("BusinessAgentNFT");
    const biz = await upgrades.deployProxy(Biz, [
      admin.address, await treasury.getAddress(),
      await leveling.getAddress(), ethers.ZeroAddress, 0,
    ], { kind: "uups" });
    await biz.waitForDeployment();

    const REGISTRY_ROLE = await biz.REGISTRY_ROLE();
    const RENTAL_ROLE   = await biz.RENTAL_ROLE();
    return { biz, admin, user1, user2, renter, REGISTRY_ROLE, RENTAL_ROLE };
  }

  async function mintOne(biz, admin, recipient) {
    const tx = await biz.connect(admin).mint(recipient.address, bizConfig(), "ipfs://Q");
    const receipt = await tx.wait();
    const event = receipt.logs.find(l => {
      try { return biz.interface.parseLog(l)?.name === "Transfer"; } catch { return false; }
    });
    return biz.interface.parseLog(event).args.tokenId;
  }

  // ============================================================
  describe("Deployment", function () {
    it("has correct name and symbol", async function () {
      const { biz } = await loadFixture(deployFixture);
      expect(await biz.name()).to.equal("NuxChain Business Agent");
      expect(await biz.symbol()).to.equal("NXBIZ");
    });
  });

  // ============================================================
  describe("mint", function () {
    it("mints to recipient and zero-initializes profile", async function () {
      const { biz, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(biz, admin, user1);
      expect(await biz.ownerOf(tokenId)).to.equal(user1.address);
      const prof = await biz.businessProfiles(tokenId);
      expect(prof.clientCount).to.equal(0n);
      expect(prof.workflowsCompleted).to.equal(0n);
    });

    it("reverts for wrong category", async function () {
      const { biz, admin, user1 } = await loadFixture(deployFixture);
      await expect(
        biz.connect(admin).mint(user1.address, bizConfig({ category: 0 }), "ipfs://Q")
      ).to.be.revertedWithCustomError(biz, "WrongCategory");
    });

    it("reverts for non-admin", async function () {
      const { biz, user1, user2 } = await loadFixture(deployFixture);
      await expect(
        biz.connect(user2).mint(user1.address, bizConfig(), "ipfs://Q")
      ).to.be.reverted;
    });
  });

  // ============================================================
  describe("mintFromFactory", function () {
    it("reverts without FACTORY_ROLE", async function () {
      const { biz, user1 } = await loadFixture(deployFixture);
      await expect(
        biz.connect(user1).mintFromFactory(user1.address, bizConfig(), "ipfs://Q")
      ).to.be.reverted;
    });

    it("FACTORY_ROLE can mint via factory", async function () {
      const { biz, admin, user1 } = await loadFixture(deployFixture);
      const FACTORY_ROLE = await biz.FACTORY_ROLE();
      await biz.connect(admin).grantRole(FACTORY_ROLE, admin.address);
      await expect(biz.connect(admin).mintFromFactory(user1.address, bizConfig(), "ipfs://Q"))
        .to.emit(biz, "Transfer");
    });
  });

  // ============================================================
  describe("addClient", function () {
    it("owner can add a client", async function () {
      const { biz, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(biz, admin, user1);
      await expect(biz.connect(user1).addClient(tokenId, "Acme Corp", user2.address))
        .to.emit(biz, "ClientAdded").withArgs(tokenId, 0, "Acme Corp");
      expect(await biz.getClientCount(tokenId)).to.equal(1n);
    });

    it("active renter can add a client", async function () {
      const { biz, admin, user1, renter, RENTAL_ROLE } = await loadFixture(deployFixture);
      await biz.connect(admin).grantRole(RENTAL_ROLE, admin.address);
      const tokenId = await mintOne(biz, admin, user1);
      const expiry = (await time.latest()) + 86400;
      await biz.connect(admin).setRenter(tokenId, renter.address, expiry);
      await expect(biz.connect(renter).addClient(tokenId, "RenterClient", renter.address))
        .to.emit(biz, "ClientAdded");
    });

    it("reverts for non-owner non-renter", async function () {
      const { biz, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(biz, admin, user1);
      await expect(biz.connect(user2).addClient(tokenId, "X", user2.address))
        .to.be.revertedWithCustomError(biz, "NotAuthorized");
    });

    it("reverts after MAX_CLIENTS (100)", async function () {
      const { biz, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(biz, admin, user1);
      for (let i = 0; i < 100; i++) {
        await biz.connect(user1).addClient(tokenId, `Client${i}`, user2.address);
      }
      await expect(biz.connect(user1).addClient(tokenId, "One more", user2.address))
        .to.be.revertedWithCustomError(biz, "MaxClientsReached");
    });

    it("getClient returns correct data", async function () {
      const { biz, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(biz, admin, user1);
      await biz.connect(user1).addClient(tokenId, "Bob", user2.address);
      const client = await biz.getClient(tokenId, 0);
      expect(client.walletAddress).to.equal(user2.address);
      expect(client.lifetimeValue).to.equal(0n);
      expect(client.stage).to.equal(0n); // PROSPECT
    });
  });

  // ============================================================
  describe("createWorkflow", function () {
    it("owner can create a workflow", async function () {
      const { biz, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(biz, admin, user1);
      await expect(biz.connect(user1).createWorkflow(tokenId, "Onboarding", "ipfs://Qmwf"))
        .to.emit(biz, "WorkflowCreated").withArgs(tokenId, 0, "Onboarding", "ipfs://Qmwf");
      expect(await biz.getWorkflowCount(tokenId)).to.equal(1n);
    });

    it("active renter can create a workflow", async function () {
      const { biz, admin, user1, renter, RENTAL_ROLE } = await loadFixture(deployFixture);
      await biz.connect(admin).grantRole(RENTAL_ROLE, admin.address);
      const tokenId = await mintOne(biz, admin, user1);
      const expiry = (await time.latest()) + 86400;
      await biz.connect(admin).setRenter(tokenId, renter.address, expiry);
      await expect(biz.connect(renter).createWorkflow(tokenId, "Renter WF", "ipfs://Qmwf2"))
        .to.emit(biz, "WorkflowCreated");
    });

    it("reverts for non-authorized caller", async function () {
      const { biz, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(biz, admin, user1);
      await expect(biz.connect(user2).createWorkflow(tokenId, "Hack", "ipfs://Qmx"))
        .to.be.revertedWithCustomError(biz, "NotAuthorized");
    });

    it("reverts after MAX_WORKFLOWS (20)", async function () {
      const { biz, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(biz, admin, user1);
      for (let i = 0; i < 20; i++) {
        await biz.connect(user1).createWorkflow(tokenId, `WF${i}`, `ipfs://Qm${i}`);
      }
      await expect(biz.connect(user1).createWorkflow(tokenId, "over", "ipfs://Qmover"))
        .to.be.revertedWithCustomError(biz, "MaxWorkflowsReached");
    });

    it("getWorkflow returns PENDING status initially", async function () {
      const { biz, admin, user1 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(biz, admin, user1);
      await biz.connect(user1).createWorkflow(tokenId, "Flow A", "ipfs://Qmwf");
      const wf = await biz.getWorkflow(tokenId, 0);
      expect(wf.status).to.equal(0n); // PENDING
      expect(wf.completedAt).to.equal(0n);
    });
  });

  // ============================================================
  describe("recordWorkflowCompleted", function () {
    it("REGISTRY_ROLE marks workflow COMPLETED and increments counter", async function () {
      const { biz, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await biz.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(biz, admin, user1);
      await biz.connect(user1).createWorkflow(tokenId, "WF A", "ipfs://Q");
      await expect(biz.connect(admin).recordWorkflowCompleted(tokenId, 0, 50))
        .to.emit(biz, "WorkflowCompleted").withArgs(tokenId, 0, 50);
      const wf = await biz.getWorkflow(tokenId, 0);
      expect(wf.status).to.equal(2n); // COMPLETED
      const prof = await biz.businessProfiles(tokenId);
      expect(prof.workflowsCompleted).to.equal(1n);
    });

    it("reverts AlreadyFinalized on second call", async function () {
      const { biz, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await biz.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(biz, admin, user1);
      await biz.connect(user1).createWorkflow(tokenId, "WF", "ipfs://Q");
      await biz.connect(admin).recordWorkflowCompleted(tokenId, 0, 50);
      await expect(biz.connect(admin).recordWorkflowCompleted(tokenId, 0, 50))
        .to.be.revertedWithCustomError(biz, "AlreadyFinalized");
    });

    it("reverts InvalidWorkflow for out-of-bounds wfIdx", async function () {
      const { biz, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await biz.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(biz, admin, user1);
      await expect(biz.connect(admin).recordWorkflowCompleted(tokenId, 99, 50))
        .to.be.revertedWithCustomError(biz, "InvalidWorkflow");
    });

    it("non-REGISTRY_ROLE cannot call", async function () {
      const { biz, admin, user1, user2 } = await loadFixture(deployFixture);
      const tokenId = await mintOne(biz, admin, user1);
      await biz.connect(user1).createWorkflow(tokenId, "WF", "ipfs://Q");
      await expect(biz.connect(user2).recordWorkflowCompleted(tokenId, 0, 50))
        .to.be.reverted;
    });
  });

  // ============================================================
  describe("recordWorkflowFailed", function () {
    it("marks workflow as FAILED", async function () {
      const { biz, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await biz.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(biz, admin, user1);
      await biz.connect(user1).createWorkflow(tokenId, "WF", "ipfs://Q");
      await expect(biz.connect(admin).recordWorkflowFailed(tokenId, 0))
        .to.emit(biz, "WorkflowFailed").withArgs(tokenId, 0);
      const wf = await biz.getWorkflow(tokenId, 0);
      expect(wf.status).to.equal(3n); // FAILED
    });

    it("overwrites status on a completed workflow (no revert)", async function () {
      const { biz, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await biz.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(biz, admin, user1);
      await biz.connect(user1).createWorkflow(tokenId, "WF", "ipfs://Q");
      await biz.connect(admin).recordWorkflowCompleted(tokenId, 0, 10);
      // recordWorkflowFailed does not check AlreadyFinalized — just overwrites
      await expect(biz.connect(admin).recordWorkflowFailed(tokenId, 0))
        .to.emit(biz, "WorkflowFailed");
      const wf = await biz.getWorkflow(tokenId, 0);
      expect(wf.status).to.equal(3n); // FAILED
    });
  });

  // ============================================================
  describe("recordDealClosed", function () {
    it("won=true updates revenue and deal stage", async function () {
      const { biz, admin, user1, user2, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await biz.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(biz, admin, user1);
      await biz.connect(user1).addClient(tokenId, "Acme", user2.address);
      await expect(biz.connect(admin).recordDealClosed(tokenId, 0, true, 5000n, 80))
        .to.emit(biz, "DealUpdated");
      const prof = await biz.businessProfiles(tokenId);
      expect(prof.dealsClosedWon).to.equal(1n);
      expect(prof.totalRevenueLocked).to.equal(5000n);
      const client = await biz.getClient(tokenId, 0);
      expect(client.stage).to.equal(4n); // CLOSED_WON
      expect(client.lifetimeValue).to.equal(5000n);
    });

    it("won=false increments dealsClosedLost", async function () {
      const { biz, admin, user1, user2, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await biz.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(biz, admin, user1);
      await biz.connect(user1).addClient(tokenId, "Lead", user2.address);
      await biz.connect(admin).recordDealClosed(tokenId, 0, false, 0n, 10);
      const prof = await biz.businessProfiles(tokenId);
      expect(prof.dealsClosedLost).to.equal(1n);
    });

    it("reverts for invalid client index", async function () {
      const { biz, admin, user1, REGISTRY_ROLE } = await loadFixture(deployFixture);
      await biz.connect(admin).grantRole(REGISTRY_ROLE, admin.address);
      const tokenId = await mintOne(biz, admin, user1);
      await expect(biz.connect(admin).recordDealClosed(tokenId, 99, true, 100n, 10))
        .to.be.revertedWithCustomError(biz, "InvalidClient");
    });
  });
});
