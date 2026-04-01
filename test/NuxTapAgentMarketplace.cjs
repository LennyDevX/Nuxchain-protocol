const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("NuxTapAgentMarketplace", function () {
  function findLogIndex(receipt, contract, eventName) {
    const event = contract.interface.getEvent(eventName);
    return receipt.logs.findIndex(
      (log) =>
        log.address.toLowerCase() === contract.target.toLowerCase() &&
        log.topics[0] === event.topicHash
    );
  }

  async function deployFixture() {
    const [admin, seller, buyer] = await ethers.getSigners();

    const Treasury = await ethers.getContractFactory("MockTreasury");
    const treasury = await Treasury.deploy();
    await treasury.waitForDeployment();

    const Marketplace = await ethers.getContractFactory("NuxTapAgentMarketplace");
    const marketplace = await upgrades.deployProxy(Marketplace, [
      admin.address,
      await treasury.getAddress(),
      ethers.ZeroAddress
    ], {
      initializer: "initialize",
      kind: "uups"
    });
    await marketplace.waitForDeployment();

    const MockTapAgentNFT = await ethers.getContractFactory("MockTapAgentNFT");
    const agentNft = await MockTapAgentNFT.deploy();
    await agentNft.waitForDeployment();
    await agentNft.mint(seller.address);

    await marketplace.connect(admin).setSupportedNFTContract(await agentNft.getAddress(), true);

    return { admin, seller, buyer, treasury, marketplace, agentNft };
  }

  it("lists and reprices supported AI agent NFTs", async function () {
    const { seller, marketplace, agentNft } = await loadFixture(deployFixture);

    await agentNft.connect(seller).approve(await marketplace.getAddress(), 0);

    await expect(
      marketplace.connect(seller).listAgent(await agentNft.getAddress(), 0, ethers.parseEther("1"))
    ).to.emit(marketplace, "AgentListed");

    await expect(marketplace.connect(seller).updateListingPrice(1, ethers.parseEther("1.25")))
      .to.emit(marketplace, "AgentListingUpdated")
      .withArgs(1n, ethers.parseEther("1"), ethers.parseEther("1.25"));

    const listing = await marketplace.listings(1);
    expect(listing.active).to.equal(true);
    expect(listing.price).to.equal(ethers.parseEther("1.25"));
  });

  it("sells listed agents and routes the platform fee to treasury", async function () {
    const { seller, buyer, treasury, marketplace, agentNft } = await loadFixture(deployFixture);

    await agentNft.connect(seller).approve(await marketplace.getAddress(), 0);
    await marketplace.connect(seller).listAgent(await agentNft.getAddress(), 0, ethers.parseEther("1"));

    const sellerBalanceBefore = await ethers.provider.getBalance(seller.address);
    const tx = await marketplace.connect(buyer).buyAgent(1, { value: ethers.parseEther("1") });

    await expect(tx).to.emit(marketplace, "AgentSold");

    const receipt = await tx.wait();

    const sellerBalanceAfter = await ethers.provider.getBalance(seller.address);
    const transferLogIndex = findLogIndex(receipt, agentNft, "Transfer");
    const revenueLogIndex = findLogIndex(receipt, treasury, "RevenueReceived");

    expect(await agentNft.ownerOf(0)).to.equal(buyer.address);
    expect((await marketplace.listings(1)).active).to.equal(false);
    expect(await ethers.provider.getBalance(await treasury.getAddress())).to.equal(ethers.parseEther("0.05"));
    expect(sellerBalanceAfter - sellerBalanceBefore).to.equal(ethers.parseEther("0.95"));
    expect(transferLogIndex).to.not.equal(-1);
    expect(revenueLogIndex).to.not.equal(-1);
    expect(transferLogIndex).to.be.lessThan(revenueLogIndex);
  });

  it("rejects listings for unsupported agent contracts", async function () {
    const { seller, marketplace } = await loadFixture(deployFixture);

    const MockTapAgentNFT = await ethers.getContractFactory("MockTapAgentNFT");
    const otherAgentNft = await MockTapAgentNFT.deploy();
    await otherAgentNft.waitForDeployment();
    await otherAgentNft.mint(seller.address);
    await otherAgentNft.connect(seller).approve(await marketplace.getAddress(), 0);

    await expect(
      marketplace.connect(seller).listAgent(await otherAgentNft.getAddress(), 0, ethers.parseEther("1"))
    ).to.be.revertedWith("NuxTapAgentMarketplace: unsupported NFT contract");
  });
});