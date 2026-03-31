"use strict";
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("NuxAgentRental", function () {

  async function deployFixture() {
    const [admin, owner, renter, other] = await ethers.getSigners();

    const Treasury = await ethers.getContractFactory("MockTreasury");
    const treasury = await Treasury.deploy();

    const Rental = await ethers.getContractFactory("NuxAgentRental");
    const rental = await upgrades.deployProxy(Rental, [
      admin.address, await treasury.getAddress()
    ], { kind: "uups" });
    await rental.waitForDeployment();

    // Deploy mock NFT hook
    const MockHook = await ethers.getContractFactory("MockNFTRentalHook");
    const mockNFT = await MockHook.deploy();

    // Mint token 1 to owner
    await mockNFT.setOwner(1, owner.address);
    await rental.connect(admin).setSupportedNFTContract(await mockNFT.getAddress(), true);

    const ADMIN_ROLE  = await rental.ADMIN_ROLE();
    const PAUSER_ROLE = await rental.PAUSER_ROLE();
    return { rental, mockNFT, treasury, admin, owner, renter, other, ADMIN_ROLE, PAUSER_ROLE };
  }

  // Convenience: create an offer for tokenId 1 at 0.01 ETH/day, min 1 day, max 30 days
  async function createOffer(rental, mockNFT, owner, pricePerDay = ethers.parseEther("0.01"), minDays = 1, maxDays = 30) {
    const tx = await rental.connect(owner).createRentalOffer(
      await mockNFT.getAddress(), 1, pricePerDay, minDays, maxDays
    );
    const receipt = await tx.wait();
    return 1n; // first offer ID
  }

  // ============================================================
  describe("Deployment", function () {
    it("initializes revenue shares correctly", async function () {
      const { rental } = await loadFixture(deployFixture);
      expect(await rental.ownerShareBps()).to.equal(8000n);
      expect(await rental.treasuryBps()).to.equal(1400n);
      expect(await rental.platformBps()).to.equal(600n);
    });

    it("is not paused", async function () {
      const { rental } = await loadFixture(deployFixture);
      expect(await rental.paused()).to.be.false;
    });
  });

  // ============================================================
  describe("createRentalOffer", function () {
    it("owner can create a rental offer", async function () {
      const { rental, mockNFT, owner } = await loadFixture(deployFixture);
      const nftAddr = await mockNFT.getAddress();
      await expect(rental.connect(owner).createRentalOffer(nftAddr, 1, ethers.parseEther("0.01"), 1, 30))
        .to.emit(rental, "RentalOfferCreated").withArgs(1n, nftAddr, 1n, ethers.parseEther("0.01"));
      const offer = await rental.rentalOffers(1);
      expect(offer.active).to.be.true;
      expect(offer.owner).to.equal(owner.address);
    });

    it("reverts if caller is not token owner", async function () {
      const { rental, mockNFT, renter } = await loadFixture(deployFixture);
      await expect(
        rental.connect(renter).createRentalOffer(await mockNFT.getAddress(), 1, ethers.parseEther("0.01"), 1, 30)
      ).to.be.revertedWith("Rental: not token owner");
    });

    it("reverts if price is zero", async function () {
      const { rental, mockNFT, owner } = await loadFixture(deployFixture);
      await expect(
        rental.connect(owner).createRentalOffer(await mockNFT.getAddress(), 1, 0, 1, 30)
      ).to.be.revertedWith("Rental: price must be > 0");
    });

    it("reverts if minDays > maxDays", async function () {
      const { rental, mockNFT, owner } = await loadFixture(deployFixture);
      await expect(
        rental.connect(owner).createRentalOffer(await mockNFT.getAddress(), 1, ethers.parseEther("0.01"), 5, 3)
      ).to.be.revertedWith("Rental: invalid duration range");
    });

    it("reverts if maxDays > 365", async function () {
      const { rental, mockNFT, owner } = await loadFixture(deployFixture);
      await expect(
        rental.connect(owner).createRentalOffer(await mockNFT.getAddress(), 1, ethers.parseEther("0.01"), 1, 400)
      ).to.be.revertedWith("Rental: max 365 days");
    });

    it("reverts when contract address is zero", async function () {
      const { rental, owner } = await loadFixture(deployFixture);
      await expect(
        rental.connect(owner).createRentalOffer(ethers.ZeroAddress, 1, ethers.parseEther("0.01"), 1, 10)
      ).to.be.revertedWith("Rental: invalid contract");
    });

    it("reverts when paused", async function () {
      const { rental, mockNFT, owner, admin } = await loadFixture(deployFixture);
      await rental.connect(admin).setPaused(true);
      await expect(
        rental.connect(owner).createRentalOffer(await mockNFT.getAddress(), 1, ethers.parseEther("0.01"), 1, 10)
      ).to.be.revertedWith("Rental: paused");
    });
  });

  // ============================================================
  describe("cancelRentalOffer", function () {
    it("owner can cancel an inactive offer", async function () {
      const { rental, mockNFT, owner } = await loadFixture(deployFixture);
      const offerId = await createOffer(rental, mockNFT, owner);
      await expect(rental.connect(owner).cancelRentalOffer(offerId))
        .to.emit(rental, "RentalOfferCancelled").withArgs(offerId);
      const offer = await rental.rentalOffers(offerId);
      expect(offer.active).to.be.false;
    });

    it("reverts if caller is not offer owner", async function () {
      const { rental, mockNFT, owner, renter } = await loadFixture(deployFixture);
      const offerId = await createOffer(rental, mockNFT, owner);
      await expect(rental.connect(renter).cancelRentalOffer(offerId))
        .to.be.revertedWith("Rental: not offer owner");
    });

    it("reverts if offer is already inactive", async function () {
      const { rental, mockNFT, owner } = await loadFixture(deployFixture);
      const offerId = await createOffer(rental, mockNFT, owner);
      await rental.connect(owner).cancelRentalOffer(offerId);
      await expect(rental.connect(owner).cancelRentalOffer(offerId))
        .to.be.revertedWith("Rental: already inactive");
    });
  });

  // ============================================================
  describe("rentAgent", function () {
    it("renter can rent an agent for specified days", async function () {
      const { rental, mockNFT, owner, renter } = await loadFixture(deployFixture);
      const offerId = await createOffer(rental, mockNFT, owner);
      const cost = ethers.parseEther("0.01") * 7n; // 7 days
      await expect(
        rental.connect(renter).rentAgent(offerId, 7, { value: cost })
      ).to.emit(rental, "RentalStarted");
      const rentalId = 1n;
      const activeRental = await rental.activeRentals(rentalId);
      expect(activeRental.renter).to.equal(renter.address);
      expect(activeRental.active).to.be.true;
    });

    it("setRenter is called on the NFT contract", async function () {
      const { rental, mockNFT, owner, renter } = await loadFixture(deployFixture);
      const offerId = await createOffer(rental, mockNFT, owner);
      const cost = ethers.parseEther("0.01") * 7n;
      await rental.connect(renter).rentAgent(offerId, 7, { value: cost });
      expect(await mockNFT.renters(1)).to.equal(renter.address);
      expect(await mockNFT.rentalExpiry(1)).to.be.gt(0n);
    });

    it("refunds excess payment", async function () {
      const { rental, mockNFT, owner, renter } = await loadFixture(deployFixture);
      const offerId = await createOffer(rental, mockNFT, owner);
      const cost = ethers.parseEther("0.01") * 7n;
      const overpay = cost + ethers.parseEther("0.5"); // 0.5 ETH excess
      const balBefore = await ethers.provider.getBalance(renter.address);
      const tx = await rental.connect(renter).rentAgent(offerId, 7, { value: overpay });
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;
      const balAfter = await ethers.provider.getBalance(renter.address);
      expect(balBefore - balAfter).to.be.closeTo(cost + gasUsed, ethers.parseEther("0.0001"));
    });

    it("distributes 80% to owner", async function () {
      const { rental, mockNFT, owner, renter } = await loadFixture(deployFixture);
      const offerId = await createOffer(rental, mockNFT, owner);
      const cost = ethers.parseEther("0.01");
      const balBefore = await ethers.provider.getBalance(owner.address);
      await rental.connect(renter).rentAgent(offerId, 1, { value: cost });
      const balAfter = await ethers.provider.getBalance(owner.address);
      const expectedOwnerShare = cost * 8000n / 10000n;
      expect(balAfter - balBefore).to.equal(expectedOwnerShare);
    });

    it("reverts if duration is below minDays", async function () {
      const { rental, mockNFT, owner, renter } = await loadFixture(deployFixture);
      // Create offer with minDays=3
      await rental.connect(owner).createRentalOffer(await mockNFT.getAddress(), 1, ethers.parseEther("0.01"), 3, 30);
      await expect(
        rental.connect(renter).rentAgent(1n, 2, { value: ethers.parseEther("0.02") })
      ).to.be.revertedWith("Rental: invalid duration");
    });

    it("reverts if owner tries to rent own token", async function () {
      const { rental, mockNFT, owner } = await loadFixture(deployFixture);
      const offerId = await createOffer(rental, mockNFT, owner);
      await expect(
        rental.connect(owner).rentAgent(offerId, 1, { value: ethers.parseEther("0.01") })
      ).to.be.revertedWith("Rental: owner can't rent own token");
    });

    it("reverts with insufficient payment", async function () {
      const { rental, mockNFT, owner, renter } = await loadFixture(deployFixture);
      const offerId = await createOffer(rental, mockNFT, owner);
      await expect(
        rental.connect(renter).rentAgent(offerId, 7, { value: ethers.parseEther("0.001") })
      ).to.be.revertedWith("Rental: insufficient payment");
    });

    it("reverts when paused", async function () {
      const { rental, mockNFT, owner, renter, admin } = await loadFixture(deployFixture);
      const offerId = await createOffer(rental, mockNFT, owner);
      await rental.connect(admin).setPaused(true);
      await expect(
        rental.connect(renter).rentAgent(offerId, 1, { value: ethers.parseEther("0.01") })
      ).to.be.revertedWith("Rental: paused");
    });
  });

  // ============================================================
  describe("extendRental", function () {
    async function withActiveRental(fixture) {
      const { rental, mockNFT, owner, renter } = fixture;
      await createOffer(rental, mockNFT, owner);
      const cost = ethers.parseEther("0.01") * 7n;
      await rental.connect(renter).rentAgent(1n, 7, { value: cost });
      return { rentalId: 1n };
    }

    it("renter can extend an active rental", async function () {
      const fixture = await loadFixture(deployFixture);
      const { rental, mockNFT, owner, renter } = fixture;
      await withActiveRental(fixture);
      const extraCost = ethers.parseEther("0.01") * 3n;
      await expect(rental.connect(renter).extendRental(1n, 3, { value: extraCost }))
        .to.emit(rental, "RentalExtended");
    });

    it("reverts if non-renter tries to extend", async function () {
      const fixture = await loadFixture(deployFixture);
      const { rental, other } = fixture;
      await withActiveRental(fixture);
      await expect(rental.connect(other).extendRental(1n, 2, { value: ethers.parseEther("0.02") }))
        .to.be.revertedWith("Rental: not renter");
    });

    it("reverts if rental already expired", async function () {
      const fixture = await loadFixture(deployFixture);
      const { rental, renter } = fixture;
      await withActiveRental(fixture);
      await time.increase(8 * 86400); // advance 8 days
      await expect(rental.connect(renter).extendRental(1n, 2, { value: ethers.parseEther("0.02") }))
        .to.be.revertedWith("Rental: already expired");
    });
  });

  // ============================================================
  describe("claimExpiredRental", function () {
    it("anyone can claim an expired rental", async function () {
      const fixture = await loadFixture(deployFixture);
      const { rental, mockNFT, owner, renter, other } = fixture;
      await createOffer(rental, mockNFT, owner);
      await rental.connect(renter).rentAgent(1n, 7, { value: ethers.parseEther("0.07") });
      await time.increase(8 * 86400); // advance past 7 days
      await expect(rental.connect(other).claimExpiredRental(1n))
        .to.emit(rental, "RentalEnded").withArgs(1n);
      const activeRental = await rental.activeRentals(1n);
      expect(activeRental.active).to.be.false;
    });

    it("reverts if rental not yet expired", async function () {
      const fixture = await loadFixture(deployFixture);
      const { rental, mockNFT, owner, renter, other } = fixture;
      await createOffer(rental, mockNFT, owner);
      await rental.connect(renter).rentAgent(1n, 7, { value: ethers.parseEther("0.07") });
      await expect(rental.connect(other).claimExpiredRental(1n))
        .to.be.revertedWith("Rental: not expired yet");
    });
  });

  // ============================================================
  describe("endRentalEarly", function () {
    it("renter can end rental early", async function () {
      const fixture = await loadFixture(deployFixture);
      const { rental, mockNFT, owner, renter } = fixture;
      await createOffer(rental, mockNFT, owner);
      await rental.connect(renter).rentAgent(1n, 7, { value: ethers.parseEther("0.07") });
      await expect(rental.connect(renter).endRentalEarly(1n))
        .to.emit(rental, "RentalEnded");
      expect((await rental.activeRentals(1n)).active).to.be.false;
    });

    it("non-renter cannot end early", async function () {
      const fixture = await loadFixture(deployFixture);
      const { rental, mockNFT, owner, renter, other } = fixture;
      await createOffer(rental, mockNFT, owner);
      await rental.connect(renter).rentAgent(1n, 7, { value: ethers.parseEther("0.07") });
      await expect(rental.connect(other).endRentalEarly(1n))
        .to.be.revertedWith("Rental: not renter");
    });

    it("clears renter on NFT contract after end", async function () {
      const fixture = await loadFixture(deployFixture);
      const { rental, mockNFT, owner, renter } = fixture;
      await createOffer(rental, mockNFT, owner);
      await rental.connect(renter).rentAgent(1n, 7, { value: ethers.parseEther("0.07") });
      await rental.connect(renter).endRentalEarly(1n);
      expect(await mockNFT.renters(1)).to.equal(ethers.ZeroAddress);
      expect(await mockNFT.rentalExpiry(1)).to.equal(0n);
    });
  });

  // ============================================================
  describe("setPaused / setRevenueShares", function () {
    it("admin can pause and unpause", async function () {
      const { rental, admin } = await loadFixture(deployFixture);
      await rental.connect(admin).setPaused(true);
      expect(await rental.paused()).to.be.true;
      await rental.connect(admin).setPaused(false);
      expect(await rental.paused()).to.be.false;
    });

    it("non-admin cannot pause", async function () {
      const { rental, other } = await loadFixture(deployFixture);
      await expect(rental.connect(other).setPaused(true)).to.be.reverted;
    });
  });
});
