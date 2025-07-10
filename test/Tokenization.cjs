const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenizationApp Contract", function () {
  let TokenizationApp;
  let tokenizationApp;
  let owner;
  let creator;
  let buyer;
  let anotherUser;
  let royaltyReceiver;
  let moderator;
  let treasury;
  
  // Constants for testing
  const tokenURI = "ipfs://QmXyNMhV8bQFp6wzoVpkz3NUAcbP3Qwx4Cfep1kAh8xjqv";
  let initialPrice;
  let offerAmount;
  const platformFee = 5; // 5%
  const defaultCategory = "art"; // Updated to English
  const defaultRoyaltyPercentage = 250; // 2.5% (base 10000)
  let ADMIN_ROLE;
  let MODERATOR_ROLE;
  let DEFAULT_ADMIN_ROLE;

  beforeEach(async function () {
    [owner, creator, buyer, anotherUser, royaltyReceiver, moderator, treasury] = await ethers.getSigners();
    
    // Deploy the contract first
    const TokenizationAppFactory = await ethers.getContractFactory("TokenizationApp");
    tokenizationApp = await TokenizationAppFactory.deploy();
    await tokenizationApp.waitForDeployment();

    // Setup constants that require ethers
    initialPrice = ethers.parseEther("0.1");
    offerAmount = ethers.parseEther("0.08");
    ADMIN_ROLE = await tokenizationApp.ADMIN_ROLE();
    MODERATOR_ROLE = await tokenizationApp.MODERATOR_ROLE();
    DEFAULT_ADMIN_ROLE = await tokenizationApp.DEFAULT_ADMIN_ROLE();
    
    // Grant moderator role
    await tokenizationApp.grantRole(MODERATOR_ROLE, moderator.address);
    // Set a separate treasury for testing fee collection
    await tokenizationApp.setPlatformTreasury(treasury.address);
  });

  // Helper function to extract events from transaction receipt in ethers v6
  async function extractEvent(receipt, eventName) {
    const contractInterface = tokenizationApp.interface;
    
    // Loop through the logs to find the event we're looking for
    for (const log of receipt.logs) {
      try {
        const parsedLog = contractInterface.parseLog({
          topics: log.topics,
          data: log.data
        });
        
        if (parsedLog && parsedLog.name === eventName) {
          return {
            event: eventName,
            args: parsedLog.args
          };
        }
      } catch (e) {
        // Skip logs that cannot be parsed
        continue;
      }
    }
    return null;
  }

  describe("Deployment", function () {
    it("Should set the right admin role", async function () {
      expect(await tokenizationApp.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
    });

    it("Should set initial platform fee to 5%", async function () {
      expect(await tokenizationApp.platformFeePercentage()).to.equal(platformFee);
    });

    it("Should set initial default royalty to 2.5%", async function () {
      expect(await tokenizationApp.defaultRoyaltyPercentage()).to.equal(defaultRoyaltyPercentage);
    });

    it("Should register initial categories", async function () {
      // Test one of the pre-registered categories
      const testCategory = defaultCategory;
      await expect(tokenizationApp.connect(creator).createNFT(tokenURI, testCategory, 0)).to.not.be.reverted;
    });
  });

  describe("NFT Creation", function () {
    it("Should allow users to create NFTs", async function () {
      const tx = await tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 0);
      const receipt = await tx.wait();
      
      // Find the TokenMinted event using the helper
      const event = await extractEvent(receipt, 'TokenMinted');
      const tokenId = event.args.tokenId;
      
      expect(await tokenizationApp.ownerOf(tokenId)).to.equal(creator.address);
      expect(await tokenizationApp.tokenURI(tokenId)).to.equal(tokenURI);
    });

    it("Should allow setting custom royalty percentage", async function () {
      const customRoyaltyPercentage = 500; // 5%
      const tx = await tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, customRoyaltyPercentage);
      const receipt = await tx.wait();
      
      const event = await extractEvent(receipt, 'TokenMinted');
      const tokenId = event.args.tokenId;
      
      // Check if royalty info is set correctly
      const royaltyInfo = await tokenizationApp.royaltyInfo(tokenId, ethers.parseEther("1.0"));
      expect(royaltyInfo[0]).to.equal(creator.address); // Receiver
      expect(royaltyInfo[1]).to.equal(ethers.parseEther("0.05")); // 5% of 1 ETH
    });

    it("Should reject creation with invalid category", async function () {
      await expect(
        tokenizationApp.connect(creator).createNFT(tokenURI, "invalidCategory", 0)
      ).to.be.revertedWithCustomError(tokenizationApp, "CategoryNotValid");
    });

    it("Should reject creation with too high royalty", async function () {
      await expect(
        tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 1001) // > 10%
      ).to.be.revertedWithCustomError(tokenizationApp, "RoyaltyTooHigh");
    });
  });

  describe("Token Listing and Sales", function () {
    let tokenId;

    beforeEach(async function () {
      // Create a token first
      const tx = await tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 0);
      const receipt = await tx.wait();
      const event = await extractEvent(receipt, 'TokenMinted');
      tokenId = event.args.tokenId;
    });

    it("Should allow token owner to list a token for sale", async function () {
      await expect(tokenizationApp.connect(creator).listTokenForSale(tokenId, initialPrice, defaultCategory))
        .to.emit(tokenizationApp, "TokenListed")
        .withArgs(tokenId, creator.address, initialPrice, defaultCategory);
      
      const listedToken = await tokenizationApp.getListedToken(tokenId);
      expect(listedToken[3]).to.equal(initialPrice); // price
      expect(listedToken[4]).to.be.true; // isForSale
    });

    it("Should allow unlisting a token", async function () {
      await tokenizationApp.connect(creator).listTokenForSale(tokenId, initialPrice, defaultCategory);
      await expect(tokenizationApp.connect(creator).unlistedToken(tokenId))
        .to.emit(tokenizationApp, "TokenUnlisted")
        .withArgs(tokenId);

      const listedToken = await tokenizationApp.getListedToken(tokenId);
      expect(listedToken[4]).to.be.false; // isForSale
    });

    it("Should allow updating the price of a listed token", async function () {
      const newPrice = ethers.parseEther("0.2");
      await tokenizationApp.connect(creator).listTokenForSale(tokenId, initialPrice, defaultCategory);
      await expect(tokenizationApp.connect(creator).updatePrice(tokenId, newPrice))
        .to.emit(tokenizationApp, "TokenPriceUpdated")
        .withArgs(tokenId, newPrice);

      const listedToken = await tokenizationApp.getListedToken(tokenId);
      expect(listedToken[3]).to.equal(newPrice); // price
    });

    it("Should allow buying a listed token", async function () {
      // List the token
      await tokenizationApp.connect(creator).listTokenForSale(tokenId, initialPrice, defaultCategory);
      
      const creatorInitialBalance = await ethers.provider.getBalance(creator.address);
      const treasuryInitialBalance = await ethers.provider.getBalance(treasury.address);
      
      // Buy the token
      const tx = await tokenizationApp.connect(buyer).buyToken(tokenId, {
        value: initialPrice
      });
      await tx.wait();
      
      // Check ownership
      expect(await tokenizationApp.ownerOf(tokenId)).to.equal(buyer.address);
      
      // Check balances
      const creatorFinalBalance = await ethers.provider.getBalance(creator.address);
      const treasuryFinalBalance = await ethers.provider.getBalance(treasury.address);
      const platformFeeAmount = (initialPrice * BigInt(platformFee)) / 100n;
      const sellerProceeds = initialPrice - platformFeeAmount;

      expect(creatorFinalBalance - creatorInitialBalance).to.equal(sellerProceeds);
      expect(treasuryFinalBalance - treasuryInitialBalance).to.equal(platformFeeAmount);
    });

    it("Should not allow buying a token that's not for sale", async function () {
      await expect(
        tokenizationApp.connect(buyer).buyToken(tokenId, { value: initialPrice })
      ).to.be.revertedWithCustomError(tokenizationApp, "TokenNotForSale");
    });

    it("Should not allow buying with insufficient funds", async function () {
      // List the token
      await tokenizationApp.connect(creator).listTokenForSale(tokenId, initialPrice, defaultCategory);
      
      // Try to buy with less than the price
      await expect(
        tokenizationApp.connect(buyer).buyToken(tokenId, { 
          value: initialPrice / 2n 
        })
      ).to.be.revertedWithCustomError(tokenizationApp, "InsufficientFunds");
    });
  });

  describe("Offers", function () {
    let tokenId;
    let offerId;

    beforeEach(async function () {
      // Create and list a token
      const tx = await tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 0);
      const receipt = await tx.wait();
      const event = await extractEvent(receipt, 'TokenMinted');
      tokenId = event.args.tokenId;
      
      // Make an offer
      const offerTx = await tokenizationApp.connect(buyer).makeOffer(tokenId, 7, { value: offerAmount });
      const offerReceipt = await offerTx.wait();
      const offerEvent = await extractEvent(offerReceipt, 'OfferCreated');
      offerId = offerEvent.args.offerId;
    });

    it("Should allow making an offer for a token", async function () {
      const offer = await tokenizationApp.getOffer(offerId);
      expect(offer[0]).to.equal(offerId); // offerId
      expect(offer[1]).to.equal(tokenId); // tokenId
      expect(offer[2]).to.equal(buyer.address); // buyer
      expect(offer[3]).to.equal(offerAmount); // offerAmount
      expect(offer[5]).to.be.true; // isActive
    });

    it("Should allow token owner to accept an offer", async function () {
      const creatorInitialBalance = await ethers.provider.getBalance(creator.address);
      const treasuryInitialBalance = await ethers.provider.getBalance(treasury.address);

      const tx = await tokenizationApp.connect(creator).acceptOffer(offerId);
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      expect(await tokenizationApp.ownerOf(tokenId)).to.equal(buyer.address);

      const creatorFinalBalance = await ethers.provider.getBalance(creator.address);
      const treasuryFinalBalance = await ethers.provider.getBalance(treasury.address);
      const platformFeeAmount = (offerAmount * BigInt(platformFee)) / 100n;
      const sellerProceeds = offerAmount - platformFeeAmount;

      expect(creatorFinalBalance).to.equal(creatorInitialBalance - gasUsed + sellerProceeds);
      expect(treasuryFinalBalance - treasuryInitialBalance).to.equal(platformFeeAmount);
    });

    it("Should allow token owner to reject an offer", async function () {
      await expect(tokenizationApp.connect(creator).rejectOffer(offerId))
        .to.emit(tokenizationApp, "OfferRejected")
        .withArgs(offerId);
      
      const offer = await tokenizationApp.getOffer(offerId);
      expect(offer[5]).to.be.false; // isActive
    });

    it("Should allow buyer to cancel an offer", async function () {
      const buyerInitialBalance = await ethers.provider.getBalance(buyer.address);
      
      const tx = await tokenizationApp.connect(buyer).cancelOffer(offerId);
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      const buyerFinalBalance = await ethers.provider.getBalance(buyer.address);
      expect(buyerFinalBalance).to.equal(buyerInitialBalance - gasUsed + offerAmount);
    });

    it("Should not allow non-owner to accept an offer", async function () {
      await expect(
        tokenizationApp.connect(anotherUser).acceptOffer(offerId)
      ).to.be.revertedWithCustomError(tokenizationApp, "Unauthorized");
    });
  });

  describe("Likes and Comments", function () {
    let tokenId;

    beforeEach(async function () {
      // Create a token
      const tx = await tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 0);
      const receipt = await tx.wait();
      const event = await extractEvent(receipt, 'TokenMinted');
      tokenId = event.args.tokenId;
    });

    it("Should allow users to like a token", async function () {
      await tokenizationApp.connect(buyer).toggleLike(tokenId, true);
      
      expect(await tokenizationApp.getLikesCount(tokenId)).to.equal(1);
      expect(await tokenizationApp.hasUserLiked(tokenId, buyer.address)).to.be.true;
    });

    it("Should allow users to unlike a token", async function () {
      // Like first
      await tokenizationApp.connect(buyer).toggleLike(tokenId, true);
      
      // Then unlike
      await tokenizationApp.connect(buyer).toggleLike(tokenId, false);
      
      expect(await tokenizationApp.getLikesCount(tokenId)).to.equal(0);
      expect(await tokenizationApp.hasUserLiked(tokenId, buyer.address)).to.be.false;
    });

    it("Should allow adding comments to a token", async function () {
      const comment = "This is a great NFT!";
      
      await tokenizationApp.connect(buyer).addComment(tokenId, comment);
      
      const comments = await tokenizationApp.getComments(tokenId, 0, 10);
      expect(comments[0][0]).to.equal(buyer.address); // commenter
      expect(comments[1][0]).to.equal(comment); // text
    });
  });

  describe("Royalties", function () {
    it("Should pay royalties on secondary sales", async function () {
      // Create a token with 5% royalty
      const royaltyPercentage = 500; // 5%
      const tx = await tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, royaltyPercentage);
      const receipt = await tx.wait();
      const event = await extractEvent(receipt, 'TokenMinted');
      const tokenId = event.args.tokenId;
      
      // List the token
      await tokenizationApp.connect(creator).listTokenForSale(tokenId, initialPrice, defaultCategory);
      
      // Buy the token (first sale)
      await tokenizationApp.connect(buyer).buyToken(tokenId, { value: initialPrice });
      
      // Buyer lists the token for a higher price
      const newPrice = ethers.parseEther("0.2");
      await tokenizationApp.connect(buyer).listTokenForSale(tokenId, newPrice, defaultCategory);
      
      // Creator's initial balance before secondary sale
      const creatorInitialBalance = await ethers.provider.getBalance(creator.address);
      
      // Another user buys the token (secondary sale)
      await tokenizationApp.connect(anotherUser).buyToken(tokenId, { value: newPrice });
      
      // Check creator received royalties
      const creatorFinalBalance = await ethers.provider.getBalance(creator.address);
      const expectedRoyalty = (newPrice * BigInt(royaltyPercentage)) / 10000n;
      
      expect(creatorFinalBalance - creatorInitialBalance).to.equal(expectedRoyalty);
    });
  });

  describe("Administrative Functions", function () {
    it("Should allow admin to set platform fee", async function () {
      const newFee = 7; // 7%
      await tokenizationApp.connect(owner).setPlatformFee(newFee);
      
      expect(await tokenizationApp.platformFeePercentage()).to.equal(newFee);
    });

    it("Should allow admin to set default royalty", async function () {
      const newRoyalty = 300; // 3%
      await tokenizationApp.connect(owner).setDefaultRoyalty(newRoyalty);
      
      expect(await tokenizationApp.defaultRoyaltyPercentage()).to.equal(newRoyalty);
    });

    it("Should allow admin to set platform treasury", async function () {
      const newTreasury = anotherUser.address;
      await tokenizationApp.connect(owner).setPlatformTreasury(newTreasury);
      expect(await tokenizationApp.platformTreasury()).to.equal(newTreasury);
    });

    it("Should allow moderator to blacklist an address", async function () {
      await tokenizationApp.connect(moderator).blacklistAddress(anotherUser.address);
      
      // Try to create an NFT from blacklisted address
      await expect(
        tokenizationApp.connect(anotherUser).createNFT(tokenURI, defaultCategory, 0)
      ).to.be.revertedWithCustomError(tokenizationApp, "BlacklistedAddress");
    });

    it("Should allow admin to remove address from blacklist", async function () {
      // Blacklist first
      await tokenizationApp.connect(moderator).blacklistAddress(anotherUser.address);
      
      // Then remove from blacklist
      await tokenizationApp.connect(owner).removeFromBlacklist(anotherUser.address);
      
      // Should now be able to create an NFT
      await expect(tokenizationApp.connect(anotherUser).createNFT(tokenURI, defaultCategory, 0)).to.not.be.reverted;
    });

    it("Should allow admin to register new categories", async function () {
      const newCategory = "deportes";
      await tokenizationApp.connect(moderator).registerCategory(newCategory);
      
      // Try to use the new category
      await expect(tokenizationApp.connect(creator).createNFT(tokenURI, newCategory, 0)).to.not.be.reverted;
    });

    it("Should allow pausing and unpausing the contract", async function () {
      // Pause the contract
      await tokenizationApp.connect(owner).pause();
      
      // Try to create an NFT
      await expect(
        tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 0)
      ).to.be.revertedWith("Pausable: paused");
      
      // Unpause the contract
      await tokenizationApp.connect(owner).unpause();
      
      // Should now be able to create an NFT
      await expect(tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 0)).to.not.be.reverted;
    });

    it("Should allow pausing specific sections", async function () {
      // Pause the NFT creation section (3)
      await tokenizationApp.connect(owner).setSectionPaused(3, true);
      
      // Try to create an NFT
      await expect(
        tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 0)
      ).to.be.revertedWithCustomError(tokenizationApp, "SectionPaused");
      
      // Unpause the section
      await tokenizationApp.connect(owner).setSectionPaused(3, false);
      
      // Should now be able to create an NFT
      await expect(tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 0)).to.not.be.reverted;
    });
  });

  describe("Edge Cases", function () {
    it("Should handle offer cancellation after a sale", async function () {
      // Create and list a token
      const tx = await tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 0);
      const receipt = await tx.wait();
      const event = await extractEvent(receipt, 'TokenMinted');
      const tokenId = event.args.tokenId;
      await tokenizationApp.connect(creator).listTokenForSale(tokenId, initialPrice, defaultCategory);

      // anotherUser makes an offer
      const offerTx = await tokenizationApp.connect(anotherUser).makeOffer(tokenId, 1, { value: offerAmount });
      const offerReceipt = await offerTx.wait();
      const offerEvent = await extractEvent(offerReceipt, 'OfferCreated');
      const offerId = offerEvent.args.offerId;

      // buyer buys the token
      await tokenizationApp.connect(buyer).buyToken(tokenId, { value: initialPrice });

      // anotherUser tries to cancel their now-inactive offer
      await expect(tokenizationApp.connect(anotherUser).cancelOffer(offerId))
        .to.be.revertedWithCustomError(tokenizationApp, "OfferNotActive");
    });

    it("Should not allow creating tokens with invalid inputs", async function () {
      // Empty token URI
      await expect(
        tokenizationApp.connect(creator).createNFT("", defaultCategory, 0)
      ).to.be.revertedWithCustomError(tokenizationApp, "InvalidInput");
    });

    it("Should not allow listing tokens with price too low", async function () {
      // Create a token
      const tx = await tokenizationApp.connect(creator).createNFT(tokenURI, defaultCategory, 0);
      const receipt = await tx.wait();
      const event = await extractEvent(receipt, 'TokenMinted');
      const tokenId = event.args.tokenId;
      
      // Try to list with price too low
      await expect(
        tokenizationApp.connect(creator).listTokenForSale(tokenId, 10, defaultCategory) // price < MIN_PRICE
      ).to.be.revertedWithCustomError(tokenizationApp, "InvalidInput");
    });
  });
});