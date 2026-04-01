"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

// ─────────────────────────────────────────────
//  NuxAgentRegistry  —  comprehensive unit tests
//  Covers: Identity, Reputation, Validation (ERC-8004)
// ─────────────────────────────────────────────

describe("NuxAgentRegistry", function () {

  // ── Fixture ────────────────────────────────
  async function deployRegistryFixture() {
    const [admin, user1, user2, validator, game, other] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("NuxAgentRegistry");
    // NuxAgentRegistry uses non-upgradeable imports but is deployed as UUPS proxy
    const registry = await upgrades.deployProxy(
      Factory,
      [admin.address],
      { kind: "uups", unsafeAllow: ["constructor"] }
    );
    await registry.waitForDeployment();

    const ADMIN_ROLE     = await registry.ADMIN_ROLE();
    const VALIDATOR_ROLE = await registry.VALIDATOR_ROLE();
    const GAME_ROLE      = await registry.GAME_ROLE();

    return { registry, admin, user1, user2, validator, game, other,
             ADMIN_ROLE, VALIDATOR_ROLE, GAME_ROLE };
  }

  // ── 1. Deployment ──────────────────────────
  describe("Deployment", function () {
    it("grants admin roles to the initializer", async function () {
      const { registry, admin, ADMIN_ROLE } = await loadFixture(deployRegistryFixture);
      expect(await registry.hasRole(ADMIN_ROLE, admin.address)).to.equal(true);
    });

    it("cannot initialize twice", async function () {
      const { registry, admin } = await loadFixture(deployRegistryFixture);
      await expect(registry.initialize(admin.address)).to.be.reverted;
    });
  });

  // ── 2. NFT Contract Registration ──────────
  describe("registerNFTContract", function () {
    it("admin can register an NFT contract", async function () {
      const { registry, admin, user1 } = await loadFixture(deployRegistryFixture);
      await registry.connect(admin).registerNFTContract(user1.address);
      expect(await registry.registeredNFTContracts(user1.address)).to.equal(true);
    });

    it("non-admin cannot register", async function () {
      const { registry, user1, user2 } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(user1).registerNFTContract(user2.address)
      ).to.be.reverted;
    });

    it("reverts for zero address", async function () {
      const { registry, admin } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(admin).registerNFTContract(ethers.ZeroAddress)
      ).to.be.revertedWith("Registry: invalid contract");
    });
  });

  // ── 3. Role Management ────────────────────
  describe("Role management", function () {
    it("admin can grant VALIDATOR_ROLE", async function () {
      const { registry, admin, validator, VALIDATOR_ROLE } = await loadFixture(deployRegistryFixture);
      await registry.connect(admin).grantValidatorRole(validator.address);
      expect(await registry.hasRole(VALIDATOR_ROLE, validator.address)).to.equal(true);
    });

    it("admin can grant GAME_ROLE", async function () {
      const { registry, admin, game, GAME_ROLE } = await loadFixture(deployRegistryFixture);
      await registry.connect(admin).grantGameRole(game.address);
      expect(await registry.hasRole(GAME_ROLE, game.address)).to.equal(true);
    });
  });

  // ── 4. Metadata (ERC-8004) ────────────────
  describe("setMetadata / getMetadata", function () {
    it("owner can set and retrieve custom metadata", async function () {
      const { registry, admin, user1, user2 } = await loadFixture(deployRegistryFixture);
      // user1 is simulated as the owner; registry uses _isAgentOwnerOrOperator
      // which checks all registered NFT contracts — since there's none, only admin passes
      // So we test with admin as the actor
      const encoded = ethers.toUtf8Bytes("some-value");
      await registry.connect(admin).setMetadata(1, "model", encoded);
      const result = await registry.getMetadata(1, "model");
      expect(result).to.equal(ethers.hexlify(encoded));
    });

    it("reverts when using reserved 'agentWallet' key", async function () {
      const { registry, admin } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(admin).setMetadata(1, "agentWallet", ethers.toUtf8Bytes("0x"))
      ).to.be.revertedWith("Registry: agentWallet is reserved");
    });

    it("unauthorized address cannot set metadata", async function () {
      const { registry, user1 } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(user1).setMetadata(1, "key", ethers.toUtf8Bytes("val"))
      ).to.be.revertedWith("Registry: not authorized");
    });
  });

  // ── 5. configureAgent ─────────────────────
  describe("configureAgent", function () {
    it("stores daily spending limit and endpoints", async function () {
      const { registry, admin } = await loadFixture(deployRegistryFixture);
      await registry.connect(admin).configureAgent(
        42,
        ethers.parseEther("1"),
        true,
        "https://mcp.example.com",
        "https://a2a.example.com"
      );
      const meta = await registry.agentMetadata(42);
      expect(meta.spendingLimitDaily).to.equal(ethers.parseEther("1"));
      expect(meta.x402Enabled).to.equal(true);
      expect(meta.mcpEndpoint).to.equal("https://mcp.example.com");
    });

    it("unauthorized address cannot configure", async function () {
      const { registry, user1 } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(user1).configureAgent(1, 0, false, "", "")
      ).to.be.revertedWith("Registry: not authorized");
    });
  });

  // ── 6. setAgentWallet (EIP-712) ───────────
  describe("setAgentWallet", function () {
    it("reverts with expired deadline", async function () {
      const { registry, admin, user1 } = await loadFixture(deployRegistryFixture);
      const deadline = (await time.latest()) - 1;
      const sig = ethers.ZeroHash.slice(0, 132); // 65-byte zero sig
      await expect(
        registry.connect(admin).setAgentWallet(1, user1.address, deadline, "0x" + "00".repeat(65))
      ).to.be.revertedWith("Registry: signature expired");
    });

    it("reverts for zero wallet address", async function () {
      const { registry, admin } = await loadFixture(deployRegistryFixture);
      const deadline = (await time.latest()) + 3600;
      await expect(
        registry.connect(admin).setAgentWallet(1, ethers.ZeroAddress, deadline, "0x" + "00".repeat(65))
      ).to.be.revertedWith("Registry: invalid wallet");
    });
  });

  // ── 7. giveFeedback (Reputation) ─────────
  describe("giveFeedback", function () {
    it("user can give feedback to an agent they don't own", async function () {
      const { registry, user1 } = await loadFixture(deployRegistryFixture);
      // agentId=1 has no owner in registry — _isAgentOwnerOrOperator returns false for user1
      const tx = await registry.connect(user1).giveFeedback(
        1, 80, 0, "quality", "speed", "", ethers.ZeroHash
      );
      await expect(tx).to.emit(registry, "NewFeedback")
        .withArgs(1, user1.address, 1, 80, 0, "quality", "speed");
      expect(await registry.reputationScore(1)).to.be.gt(0);
    });

    it("owner/admin cannot give feedback to own agent (anti-Sybil)", async function () {
      const { registry, admin } = await loadFixture(deployRegistryFixture);
      // admin is treated as agent owner (has ADMIN_ROLE which makes _isAgentOwnerOrOperator true)
      await expect(
        registry.connect(admin).giveFeedback(1, 90, 0, "quality", "", "", ethers.ZeroHash)
      ).to.be.revertedWith("Registry: owner cannot give feedback");
    });

    it("tracks feedback index per client", async function () {
      const { registry, user1 } = await loadFixture(deployRegistryFixture);
      await registry.connect(user1).giveFeedback(1, 70, 0, "quality", "", "", ethers.ZeroHash);
      await registry.connect(user1).giveFeedback(1, 80, 0, "speed", "", "", ethers.ZeroHash);
      expect(await registry.getLastIndex(1, user1.address)).to.equal(2);
    });

    it("reverts when valueDecimals > 18", async function () {
      const { registry, user1 } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(user1).giveFeedback(1, 70, 19, "quality", "", "", ethers.ZeroHash)
      ).to.be.revertedWith("Registry: invalid valueDecimals");
    });
  });

  // ── 8. revokeFeedback ─────────────────────
  describe("revokeFeedback", function () {
    it("client can revoke own feedback", async function () {
      const { registry, user1 } = await loadFixture(deployRegistryFixture);
      await registry.connect(user1).giveFeedback(1, 80, 0, "quality", "", "", ethers.ZeroHash);
      const tx = await registry.connect(user1).revokeFeedback(1, 1);
      await expect(tx).to.emit(registry, "FeedbackRevoked").withArgs(1, user1.address, 1);
      const [, , , , isRevoked] = await registry.readFeedback(1, user1.address, 1);
      expect(isRevoked).to.equal(true);
    });

    it("other user cannot revoke someone else's feedback", async function () {
      const { registry, user1, user2 } = await loadFixture(deployRegistryFixture);
      await registry.connect(user1).giveFeedback(1, 80, 0, "quality", "", "", ethers.ZeroHash);
      await expect(
        registry.connect(user2).revokeFeedback(1, 1)
      ).to.be.revertedWith("Registry: not feedback owner");
    });
  });

  // ── 9. getSummary ─────────────────────────
  describe("getSummary", function () {
    it("aggregates feedback from provided addresses", async function () {
      const { registry, user1, user2 } = await loadFixture(deployRegistryFixture);
      await registry.connect(user1).giveFeedback(1, 80, 0, "quality", "", "", ethers.ZeroHash);
      await registry.connect(user2).giveFeedback(1, 60, 0, "quality", "", "", ethers.ZeroHash);
      const [count, summaryValue] = await registry.getSummary(
        1, [user1.address, user2.address], "", ""
      );
      expect(count).to.equal(2);
      expect(summaryValue).to.equal(140);
    });

    it("filters by tag1", async function () {
      const { registry, user1, user2 } = await loadFixture(deployRegistryFixture);
      await registry.connect(user1).giveFeedback(1, 80, 0, "quality", "", "", ethers.ZeroHash);
      await registry.connect(user2).giveFeedback(1, 60, 0, "speed", "", "", ethers.ZeroHash);
      const [count] = await registry.getSummary(1, [user1.address, user2.address], "quality", "");
      expect(count).to.equal(1);
    });

    it("reverts when no clientAddresses provided", async function () {
      const { registry } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.getSummary(1, [], "", "")
      ).to.be.revertedWith("Registry: must provide clientAddresses (anti-Sybil)");
    });

    it("excludes revoked feedback", async function () {
      const { registry, user1 } = await loadFixture(deployRegistryFixture);
      await registry.connect(user1).giveFeedback(1, 80, 0, "quality", "", "", ethers.ZeroHash);
      await registry.connect(user1).revokeFeedback(1, 1);
      const [count] = await registry.getSummary(1, [user1.address], "", "");
      expect(count).to.equal(0);
    });
  });

  // ── 10. validationRequest / validationResponse ──
  describe("Validation Registry (ERC-8004)", function () {
    it("admin can submit a validation request", async function () {
      const { registry, admin, validator } = await loadFixture(deployRegistryFixture);
      await registry.connect(admin).grantValidatorRole(validator.address);
      const reqHash = ethers.keccak256(ethers.toUtf8Bytes("evidence-content"));
      const tx = await registry.connect(admin).validationRequest(
        validator.address, 1, "ipfs://QmEvidence", reqHash
      );
      await expect(tx).to.emit(registry, "ValidationRequest")
        .withArgs(validator.address, 1, "ipfs://QmEvidence", reqHash);
    });

    it("reverts for zero validator address", async function () {
      const { registry, admin } = await loadFixture(deployRegistryFixture);
      const reqHash = ethers.keccak256(ethers.toUtf8Bytes("x"));
      await expect(
        registry.connect(admin).validationRequest(ethers.ZeroAddress, 1, "", reqHash)
      ).to.be.revertedWith("Registry: invalid validator");
    });

    it("reverts for zero request hash", async function () {
      const { registry, admin, validator } = await loadFixture(deployRegistryFixture);
      await registry.connect(admin).grantValidatorRole(validator.address);
      await expect(
        registry.connect(admin).validationRequest(validator.address, 1, "", ethers.ZeroHash)
      ).to.be.revertedWith("Registry: invalid request hash");
    });

    it("validator can submit a response", async function () {
      const { registry, admin, validator } = await loadFixture(deployRegistryFixture);
      await registry.connect(admin).grantValidatorRole(validator.address);
      const reqHash = ethers.keccak256(ethers.toUtf8Bytes("evidence-content"));
      await registry.connect(admin).validationRequest(validator.address, 1, "ipfs://Q", reqHash);

      const tx = await registry.connect(validator).validationResponse(
        reqHash, 100, "", ethers.ZeroHash, "audit"
      );
      await expect(tx).to.emit(registry, "ValidationResponse")
        .withArgs(validator.address, 0, reqHash, 100, "audit");
    });

    it("non-validator cannot respond", async function () {
      const { registry, admin, validator, user1 } = await loadFixture(deployRegistryFixture);
      await registry.connect(admin).grantValidatorRole(validator.address);
      const reqHash = ethers.keccak256(ethers.toUtf8Bytes("x"));
      await registry.connect(admin).validationRequest(validator.address, 1, "", reqHash);
      await expect(
        registry.connect(user1).validationResponse(reqHash, 100, "", ethers.ZeroHash, "")
      ).to.be.revertedWith("Registry: not a validator");
    });
  });

  // ── 11. getClients + getLastIndex + readFeedback ──
  describe("View functions", function () {
    it("getClients returns all clients that gave feedback", async function () {
      const { registry, user1, user2 } = await loadFixture(deployRegistryFixture);
      await registry.connect(user1).giveFeedback(1, 80, 0, "q", "", "", ethers.ZeroHash);
      await registry.connect(user2).giveFeedback(1, 70, 0, "q", "", "", ethers.ZeroHash);
      const clients = await registry.getClients(1);
      expect(clients).to.include(user1.address);
      expect(clients).to.include(user2.address);
    });

    it("readFeedback returns correct data", async function () {
      const { registry, user1 } = await loadFixture(deployRegistryFixture);
      await registry.connect(user1).giveFeedback(1, 75, 2, "accuracy", "helpful", "", ethers.ZeroHash);
      const [value, decimals, tag1, tag2, isRevoked] = await registry.readFeedback(1, user1.address, 1);
      expect(value).to.equal(75);
      expect(decimals).to.equal(2);
      expect(tag1).to.equal("accuracy");
      expect(tag2).to.equal("helpful");
      expect(isRevoked).to.equal(false);
    });
  });
});
