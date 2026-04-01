"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("NuxAgentRegistry", function () {
  async function deployRegistryFixture() {
    const [admin, user1, user2, validator, game, other] = await ethers.getSigners();

    const RegistryFactory = await ethers.getContractFactory("NuxAgentRegistry");
    const registry = await upgrades.deployProxy(
      RegistryFactory,
      [admin.address],
      { kind: "uups", unsafeAllow: ["constructor"] }
    );
    await registry.waitForDeployment();

    const MockGameNFT = await ethers.getContractFactory("MockGameNFT");
    const primaryNft = await MockGameNFT.deploy();
    await primaryNft.waitForDeployment();
    const secondaryNft = await MockGameNFT.deploy();
    await secondaryNft.waitForDeployment();

    await primaryNft.setOwner(1, admin.address);
    await primaryNft.setOwner(42, admin.address);
    await secondaryNft.setOwner(1, other.address);

    await registry.connect(admin).registerNFTContract(await primaryNft.getAddress());
    await registry.connect(admin).registerNFTContract(await secondaryNft.getAddress());

    const ADMIN_ROLE = await registry.ADMIN_ROLE();
    const VALIDATOR_ROLE = await registry.VALIDATOR_ROLE();
    const GAME_ROLE = await registry.GAME_ROLE();

    return {
      registry,
      primaryNft,
      secondaryNft,
      admin,
      user1,
      user2,
      validator,
      game,
      other,
      ADMIN_ROLE,
      VALIDATOR_ROLE,
      GAME_ROLE
    };
  }

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

  describe("setMetadata / getMetadata", function () {
    it("owner can set and retrieve custom metadata", async function () {
      const { registry, primaryNft, admin } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      const encoded = ethers.toUtf8Bytes("some-value");
      await registry.connect(admin).setMetadata(nftContract, 1, "model", encoded);
      const result = await registry.getMetadata(nftContract, 1, "model");
      expect(result).to.equal(ethers.hexlify(encoded));
    });

    it("reverts when using reserved 'agentWallet' key", async function () {
      const { registry, primaryNft, admin } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(admin).setMetadata(await primaryNft.getAddress(), 1, "agentWallet", ethers.toUtf8Bytes("0x"))
      ).to.be.revertedWith("Registry: agentWallet is reserved");
    });

    it("unauthorized address cannot set metadata", async function () {
      const { registry, primaryNft, user1 } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(user1).setMetadata(await primaryNft.getAddress(), 1, "key", ethers.toUtf8Bytes("val"))
      ).to.be.revertedWith("Registry: not authorized");
    });
  });

  describe("configureAgent", function () {
    it("stores daily spending limit and endpoints", async function () {
      const { registry, primaryNft, admin } = await loadFixture(deployRegistryFixture);
      await registry.connect(admin).configureAgent(
        await primaryNft.getAddress(),
        42,
        ethers.parseEther("1"),
        true,
        "https://mcp.example.com",
        "https://a2a.example.com"
      );
      const meta = await registry.agentMetadata(await primaryNft.getAddress(), 42);
      expect(meta.spendingLimitDaily).to.equal(ethers.parseEther("1"));
      expect(meta.x402Enabled).to.equal(true);
      expect(meta.mcpEndpoint).to.equal("https://mcp.example.com");
    });

    it("keeps identical tokenIds isolated per NFT contract", async function () {
      const { registry, primaryNft, secondaryNft, admin, other, user1 } = await loadFixture(deployRegistryFixture);

      await registry.connect(admin).configureAgent(
        await primaryNft.getAddress(),
        1,
        100,
        true,
        "https://primary.example",
        "https://primary-a2a.example"
      );
      await registry.connect(other).configureAgent(
        await secondaryNft.getAddress(),
        1,
        200,
        false,
        "https://secondary.example",
        "https://secondary-a2a.example"
      );
      await registry.connect(user1).giveFeedback(await primaryNft.getAddress(), 1, 88, 0, "quality", "", "", ethers.ZeroHash);

      const primaryMeta = await registry.agentMetadata(await primaryNft.getAddress(), 1);
      const secondaryMeta = await registry.agentMetadata(await secondaryNft.getAddress(), 1);

      expect(primaryMeta.spendingLimitDaily).to.equal(100n);
      expect(secondaryMeta.spendingLimitDaily).to.equal(200n);
      expect(primaryMeta.mcpEndpoint).to.equal("https://primary.example");
      expect(secondaryMeta.mcpEndpoint).to.equal("https://secondary.example");
      expect(await registry.reputationScore(await primaryNft.getAddress(), 1)).to.equal(88n);
      expect(await registry.reputationScore(await secondaryNft.getAddress(), 1)).to.equal(0n);
    });

    it("unauthorized address cannot configure", async function () {
      const { registry, primaryNft, user1 } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(user1).configureAgent(await primaryNft.getAddress(), 1, 0, false, "", "")
      ).to.be.revertedWith("Registry: not authorized");
    });
  });

  describe("setAgentWallet", function () {
    it("reverts with expired deadline", async function () {
      const { registry, primaryNft, admin, user1 } = await loadFixture(deployRegistryFixture);
      const deadline = (await time.latest()) - 1;
      await expect(
        registry.connect(admin).setAgentWallet(await primaryNft.getAddress(), 1, user1.address, deadline, "0x" + "00".repeat(65))
      ).to.be.revertedWith("Registry: signature expired");
    });

    it("reverts for zero wallet address", async function () {
      const { registry, primaryNft, admin } = await loadFixture(deployRegistryFixture);
      const deadline = (await time.latest()) + 3600;
      await expect(
        registry.connect(admin).setAgentWallet(await primaryNft.getAddress(), 1, ethers.ZeroAddress, deadline, "0x" + "00".repeat(65))
      ).to.be.revertedWith("Registry: invalid wallet");
    });
  });

  describe("giveFeedback", function () {
    it("user can give feedback to an agent they don't own", async function () {
      const { registry, primaryNft, user1 } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      const tx = await registry.connect(user1).giveFeedback(
        nftContract, 1, 80, 0, "quality", "speed", "", ethers.ZeroHash
      );
      await expect(tx).to.emit(registry, "NewFeedback")
        .withArgs(nftContract, 1, user1.address, 1, 80, 0, "quality", "speed");
      expect(await registry.reputationScore(nftContract, 1)).to.equal(80n);
    });

    it("owner/admin cannot give feedback to own agent (anti-Sybil)", async function () {
      const { registry, primaryNft, admin } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(admin).giveFeedback(await primaryNft.getAddress(), 1, 90, 0, "quality", "", "", ethers.ZeroHash)
      ).to.be.revertedWith("Registry: owner cannot give feedback");
    });

    it("tracks feedback index per client", async function () {
      const { registry, primaryNft, user1 } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      await registry.connect(user1).giveFeedback(nftContract, 1, 70, 0, "quality", "", "", ethers.ZeroHash);
      await registry.connect(user1).giveFeedback(nftContract, 1, 80, 0, "speed", "", "", ethers.ZeroHash);
      expect(await registry.getLastIndex(nftContract, 1, user1.address)).to.equal(2);
    });

    it("reverts when valueDecimals > 18", async function () {
      const { registry, primaryNft, user1 } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.connect(user1).giveFeedback(await primaryNft.getAddress(), 1, 70, 19, "quality", "", "", ethers.ZeroHash)
      ).to.be.revertedWith("Registry: invalid valueDecimals");
    });
  });

  describe("revokeFeedback", function () {
    it("client can revoke own feedback", async function () {
      const { registry, primaryNft, user1 } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      await registry.connect(user1).giveFeedback(nftContract, 1, 80, 0, "quality", "", "", ethers.ZeroHash);
      const tx = await registry.connect(user1).revokeFeedback(nftContract, 1, 1);
      await expect(tx).to.emit(registry, "FeedbackRevoked").withArgs(nftContract, 1, user1.address, 1);
      const [, , , , isRevoked] = await registry.readFeedback(nftContract, 1, user1.address, 1);
      expect(isRevoked).to.equal(true);
    });

    it("other user cannot revoke someone else's feedback", async function () {
      const { registry, primaryNft, user1, user2 } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      await registry.connect(user1).giveFeedback(nftContract, 1, 80, 0, "quality", "", "", ethers.ZeroHash);
      await expect(
        registry.connect(user2).revokeFeedback(nftContract, 1, 1)
      ).to.be.revertedWith("Registry: not feedback owner");
    });
  });

  describe("getSummary", function () {
    it("aggregates feedback from provided addresses", async function () {
      const { registry, primaryNft, user1, user2 } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      await registry.connect(user1).giveFeedback(nftContract, 1, 80, 0, "quality", "", "", ethers.ZeroHash);
      await registry.connect(user2).giveFeedback(nftContract, 1, 60, 0, "quality", "", "", ethers.ZeroHash);
      const [count, summaryValue] = await registry.getSummary(
        nftContract, 1, [user1.address, user2.address], "", ""
      );
      expect(count).to.equal(2);
      expect(summaryValue).to.equal(140);
    });

    it("filters by tag1", async function () {
      const { registry, primaryNft, user1, user2 } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      await registry.connect(user1).giveFeedback(nftContract, 1, 80, 0, "quality", "", "", ethers.ZeroHash);
      await registry.connect(user2).giveFeedback(nftContract, 1, 60, 0, "speed", "", "", ethers.ZeroHash);
      const [count] = await registry.getSummary(nftContract, 1, [user1.address, user2.address], "quality", "");
      expect(count).to.equal(1);
    });

    it("reverts when no clientAddresses provided", async function () {
      const { registry, primaryNft } = await loadFixture(deployRegistryFixture);
      await expect(
        registry.getSummary(await primaryNft.getAddress(), 1, [], "", "")
      ).to.be.revertedWith("Registry: must provide clientAddresses (anti-Sybil)");
    });

    it("excludes revoked feedback", async function () {
      const { registry, primaryNft, user1 } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      await registry.connect(user1).giveFeedback(nftContract, 1, 80, 0, "quality", "", "", ethers.ZeroHash);
      await registry.connect(user1).revokeFeedback(nftContract, 1, 1);
      const [count] = await registry.getSummary(nftContract, 1, [user1.address], "", "");
      expect(count).to.equal(0);
    });
  });

  describe("Validation Registry (ERC-8004)", function () {
    it("admin can submit a validation request", async function () {
      const { registry, primaryNft, admin, validator } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      await registry.connect(admin).grantValidatorRole(validator.address);
      const reqHash = ethers.keccak256(ethers.toUtf8Bytes("evidence-content"));
      const tx = await registry.connect(admin).validationRequest(
        validator.address,
        nftContract,
        1,
        "ipfs://QmEvidence",
        reqHash
      );
      await expect(tx).to.emit(registry, "ValidationRequest")
        .withArgs(validator.address, nftContract, 1, "ipfs://QmEvidence", reqHash);
    });

    it("reverts for zero validator address", async function () {
      const { registry, primaryNft, admin } = await loadFixture(deployRegistryFixture);
      const reqHash = ethers.keccak256(ethers.toUtf8Bytes("x"));
      await expect(
        registry.connect(admin).validationRequest(ethers.ZeroAddress, await primaryNft.getAddress(), 1, "", reqHash)
      ).to.be.revertedWith("Registry: invalid validator");
    });

    it("reverts for zero request hash", async function () {
      const { registry, primaryNft, admin, validator } = await loadFixture(deployRegistryFixture);
      await registry.connect(admin).grantValidatorRole(validator.address);
      await expect(
        registry.connect(admin).validationRequest(validator.address, await primaryNft.getAddress(), 1, "", ethers.ZeroHash)
      ).to.be.revertedWith("Registry: invalid request hash");
    });

    it("validator can submit a response", async function () {
      const { registry, primaryNft, admin, validator } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      await registry.connect(admin).grantValidatorRole(validator.address);
      const reqHash = ethers.keccak256(ethers.toUtf8Bytes("evidence-content"));
      await registry.connect(admin).validationRequest(validator.address, nftContract, 1, "ipfs://Q", reqHash);

      const tx = await registry.connect(validator).validationResponse(
        reqHash, 100, "", ethers.ZeroHash, "audit"
      );
      await expect(tx).to.emit(registry, "ValidationResponse")
        .withArgs(validator.address, nftContract, 1, reqHash, 100, "audit");
    });

    it("non-validator cannot respond", async function () {
      const { registry, primaryNft, admin, validator, user1 } = await loadFixture(deployRegistryFixture);
      const reqHash = ethers.keccak256(ethers.toUtf8Bytes("x"));
      await registry.connect(admin).grantValidatorRole(validator.address);
      await registry.connect(admin).validationRequest(validator.address, await primaryNft.getAddress(), 1, "", reqHash);
      await expect(
        registry.connect(user1).validationResponse(reqHash, 100, "", ethers.ZeroHash, "")
      ).to.be.revertedWith("Registry: not a validator");
    });
  });

  describe("View functions", function () {
    it("getClients returns all clients that gave feedback", async function () {
      const { registry, primaryNft, user1, user2 } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      await registry.connect(user1).giveFeedback(nftContract, 1, 80, 0, "q", "", "", ethers.ZeroHash);
      await registry.connect(user2).giveFeedback(nftContract, 1, 70, 0, "q", "", "", ethers.ZeroHash);
      const clients = await registry.getClients(nftContract, 1);
      expect(clients).to.include(user1.address);
      expect(clients).to.include(user2.address);
    });

    it("readFeedback returns correct data", async function () {
      const { registry, primaryNft, user1 } = await loadFixture(deployRegistryFixture);
      const nftContract = await primaryNft.getAddress();
      await registry.connect(user1).giveFeedback(nftContract, 1, 75, 2, "accuracy", "helpful", "", ethers.ZeroHash);
      const [value, decimals, tag1, tag2, isRevoked] = await registry.readFeedback(nftContract, 1, user1.address, 1);
      expect(value).to.equal(75);
      expect(decimals).to.equal(2);
      expect(tag1).to.equal("accuracy");
      expect(tag2).to.equal("helpful");
      expect(isRevoked).to.equal(false);
    });
  });
});