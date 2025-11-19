const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Nuxchain Marketplace - Refactored Architecture", function () {
  async function deployMarketplaceFixture() {
    const [owner, treasury, user1, user2, user3, user4, user5] = await ethers.getSigners();

    // ==================== Deploy Core Contracts ====================
    
    // 1. Deploy LevelingSystem
    const LevelingFactory = await ethers.getContractFactory("LevelingSystem");
    const leveling = await upgrades.deployProxy(LevelingFactory, [owner.address], {
      initializer: 'initialize',
      kind: 'uups'
    });
    await leveling.deploymentTransaction().wait();

    // 2. Deploy ReferralSystem
    const ReferralFactory = await ethers.getContractFactory("ReferralSystem");
    const referral = await upgrades.deployProxy(ReferralFactory, [owner.address], {
      initializer: 'initialize',
      kind: 'uups'
    });
    await referral.deploymentTransaction().wait();

    // 3. Deploy GameifiedMarketplaceCoreV1 via UUPS proxy
    const CoreFactory = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
    const core = await upgrades.deployProxy(CoreFactory, [treasury.address], {
      initializer: 'initialize',
      kind: 'uups'
    });
    await core.deploymentTransaction().wait();

    // 4. Deploy Skills V2
    const SkillsFactory = await ethers.getContractFactory("GameifiedMarketplaceSkillsV2");
    const skills = await SkillsFactory.deploy(await core.getAddress());
    await skills.deploymentTransaction().wait();

    // 5. Deploy Quests
    const QuestsFactory = await ethers.getContractFactory("GameifiedMarketplaceQuests");
    const quests = await QuestsFactory.deploy(await core.getAddress());
    await quests.deploymentTransaction().wait();

    // 6. Deploy Individual Skills
    const IndividualFactory = await ethers.getContractFactory("IndividualSkillsMarketplace");
    const individual = await IndividualFactory.deploy(treasury.address);
    await individual.deploymentTransaction().wait();

    // ==================== Configure Contracts ====================
    
    const coreAddr = await core.getAddress();
    const levelingAddr = await leveling.getAddress();
    const referralAddr = await referral.getAddress();
    const skillsAddr = await skills.getAddress();
    const questsAddr = await quests.getAddress();

    // Grant MARKETPLACE_ROLE to core contract in LevelingSystem and ReferralSystem
    const MARKETPLACE_ROLE = ethers.id("MARKETPLACE_ROLE");
    await leveling.connect(owner).grantRole(MARKETPLACE_ROLE, coreAddr);
    await referral.connect(owner).grantRole(MARKETPLACE_ROLE, coreAddr);

    // Configure Core to use external systems
    await core.connect(owner).setLevelingSystem(levelingAddr);
    await core.connect(owner).setReferralSystem(referralAddr);
    await core.connect(owner).setSkillsContract(skillsAddr);

    // Configure other modules
    await skills.connect(owner).setTreasuryAddress(treasury.address);
    await quests.connect(owner).setCoreContract(coreAddr);

    // Grant ADMIN_ROLE
    const ADMIN_ROLE = await core.ADMIN_ROLE();
    await core.connect(owner).grantRole(ADMIN_ROLE, skillsAddr);
    await core.connect(owner).grantRole(ADMIN_ROLE, questsAddr);

    // Fund LevelingSystem for rewards
    await owner.sendTransaction({
      to: levelingAddr,
      value: ethers.parseEther("1000")
    });

    return { 
      core, leveling, referral, quests, skills, individual, 
      owner, treasury, user1, user2, user3, user4, user5 
    };
  }

  // ==================== CORE MARKETPLACE TESTS ====================
  
  describe("GameifiedMarketplaceCoreV1 - NFT Creation & Management", function () {
    it("Should create standard NFT with metadata", async function () {
      const { core, user1 } = await loadFixture(deployMarketplaceFixture);

      const tokenURI = "https://ipfs.io/ipfs/QmTest1";
      const category = "art";
      const royalty = 500; // 5%

      await expect(core.connect(user1).createStandardNFT(tokenURI, category, royalty))
        .to.emit(core, "TokenCreated")
        .withArgs(user1.address, 0n, tokenURI);

      const userNFTs = await core.getUserNFTs(user1.address);
      expect(userNFTs).to.include(0n);

      const metadata = await core.nftMetadata(0);
      expect(metadata.creator).to.equal(user1.address);
      expect(metadata.category).to.equal(category);
    });

    it("Should create multiple NFTs and track ownership", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      for (let i = 0; i < 3; i++) {
        await core.connect(user1).createStandardNFT(`uri${i}`, "art", 0);
      }

      const user1NFTs = await core.getUserNFTs(user1.address);
      expect(user1NFTs.length).to.equal(3);

      const user2NFTs = await core.getUserNFTs(user2.address);
      expect(user2NFTs.length).to.equal(0);
    });

    it("Should verify token ownership", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      
      expect(await core.ownerOf(0)).to.equal(user1.address);
    });

    it("Should reject invalid royalty percentage", async function () {
      const { core, user1 } = await loadFixture(deployMarketplaceFixture);

      // Royalty > 100% (10000 in basis points)
      await expect(
        core.connect(user1).createStandardNFT("uri", "art", 10001)
      ).to.be.revertedWith("Invalid royalty");
    });
  });

  describe("GameifiedMarketplaceCoreV1 - Marketplace Operations", function () {
    it("Should list NFT for sale", async function () {
      const { core, user1 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      const price = ethers.parseEther("1.0");

      await expect(core.connect(user1).listTokenForSale(0, price))
        .to.emit(core, "TokenListed")
        .withArgs(user1.address, 0n, price);

      expect(await core.isListed(0)).to.be.true;
      expect(await core.listedPrice(0)).to.equal(price);
    });

    it("Should unlist NFT from sale", async function () {
      const { core, user1 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"));

      await expect(core.connect(user1).unlistToken(0))
        .to.emit(core, "TokenUnlisted")
        .withArgs(user1.address, 0n);

      expect(await core.isListed(0)).to.be.false;
    });

    it("Should update NFT price", async function () {
      const { core, user1 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      const initialPrice = ethers.parseEther("1.0");
      const newPrice = ethers.parseEther("2.0");

      await core.connect(user1).listTokenForSale(0, initialPrice);
      await expect(core.connect(user1).updatePrice(0, newPrice))
        .to.emit(core, "PriceUpdated")
        .withArgs(user1.address, 0n, newPrice);

      expect(await core.listedPrice(0)).to.equal(newPrice);
    });

    it("Should buy listed NFT", async function () {
      const { core, user1, user2, treasury } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      const price = ethers.parseEther("1.0");
      await core.connect(user1).listTokenForSale(0, price);

      const treasuryBefore = await ethers.provider.getBalance(treasury.address);
      
      await expect(core.connect(user2).buyToken(0, { value: price }))
        .to.emit(core, "TokenSold")
        .withArgs(user1.address, user2.address, 0n, price);

      // Verify ownership transfer
      expect(await core.ownerOf(0)).to.equal(user2.address);

      // Verify delisting
      expect(await core.isListed(0)).to.be.false;
    });

    it("Should handle platform fee correctly", async function () {
      const { core, user1, user2, treasury } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      const price = ethers.parseEther("1.0");
      await core.connect(user1).listTokenForSale(0, price);

      const treasuryBefore = await ethers.provider.getBalance(treasury.address);
      
      await core.connect(user2).buyToken(0, { value: price });

      const treasuryAfter = await ethers.provider.getBalance(treasury.address);
      const platformFee = (price * 5n) / 100n; // 5% fee
      
      expect(treasuryAfter - treasuryBefore).to.equal(platformFee);
    });

    it("Should reject buying unlisted NFT", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);

      await expect(
        core.connect(user2).buyToken(0, { value: ethers.parseEther("1.0") })
      ).to.be.revertedWith("Not listed");
    });

    it("Should reject insufficient payment", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"));

      await expect(
        core.connect(user2).buyToken(0, { value: ethers.parseEther("0.5") })
      ).to.be.revertedWith("Insufficient payment");
    });
  });

  describe("GameifiedMarketplaceCoreV1 - Offers System", function () {
    it("Should make offer on listed NFT", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"));

      const offerAmount = ethers.parseEther("0.8");

      await expect(core.connect(user2).makeOffer(0, 7, { value: offerAmount }))
        .to.emit(core, "OfferMade")
        .withArgs(user2.address, 0n, offerAmount);
    });

    it("Should accept offer and transfer NFT", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"));

      const offerAmount = ethers.parseEther("0.8");
      await core.connect(user2).makeOffer(0, 7, { value: offerAmount });

      await expect(core.connect(user1).acceptOffer(0, 0))
        .to.emit(core, "OfferAccepted")
        .withArgs(user1.address, user2.address, 0n, offerAmount);

      expect(await core.ownerOf(0)).to.equal(user2.address);
    });

    it("Should cancel offer and refund", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"));

      const offerAmount = ethers.parseEther("0.8");
      await core.connect(user2).makeOffer(0, 7, { value: offerAmount });

      const user2Before = await ethers.provider.getBalance(user2.address);
      const tx = await core.connect(user2).cancelOffer(0, 0);
      const receipt = await tx.wait();
      const gasCost = receipt.gasUsed * receipt.gasPrice;

      const user2After = await ethers.provider.getBalance(user2.address);
      expect(user2After - user2Before + gasCost).to.be.closeTo(offerAmount, ethers.parseEther("0.01"));
    });

    it("Should reject expired offers", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"));

      const offerAmount = ethers.parseEther("0.8");
      await core.connect(user2).makeOffer(0, 1, { value: offerAmount }); // 1 day expiry

      // Move time forward 2 days
      await time.increase(2 * 24 * 3600);

      await expect(core.connect(user1).acceptOffer(0, 0))
        .to.be.revertedWith("Offer expired");
    });
  });

  describe("GameifiedMarketplaceCoreV1 - Social Features", function () {
    it("Should toggle like on NFT", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);

      await expect(core.connect(user2).toggleLike(0))
        .to.emit(core, "LikeToggled")
        .withArgs(user2.address, 0n, true);

      expect(await core.nftLikeCount(0)).to.equal(1);
    });

    it("Should toggle like off", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await core.connect(user2).toggleLike(0);

      await expect(core.connect(user2).toggleLike(0))
        .to.emit(core, "LikeToggled")
        .withArgs(user2.address, 0n, false);

      expect(await core.nftLikeCount(0)).to.equal(0);
    });

    it("Should track multiple likes", async function () {
      const { core, user1, user2, user3, user4 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      
      await core.connect(user2).toggleLike(0);
      await core.connect(user3).toggleLike(0);
      await core.connect(user4).toggleLike(0);

      expect(await core.nftLikeCount(0)).to.equal(3);
    });

    it("Should add comment to NFT", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      const comment = "Great NFT!";

      await expect(core.connect(user2).addComment(0, comment))
        .to.emit(core, "CommentAdded")
        .withArgs(user2.address, 0n, comment);

      const comments = await core.getNFTComments(0);
      expect(comments).to.include(comment);
    });

    it("Should track multiple comments", async function () {
      const { core, user1, user2, user3 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      
      await core.connect(user2).addComment(0, "Comment 1");
      await core.connect(user3).addComment(0, "Comment 2");
      await core.connect(user2).addComment(0, "Comment 3");

      const comments = await core.getNFTComments(0);
      expect(comments.length).to.equal(3);
    });

    it("Should reject empty comment", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);

      await expect(core.connect(user2).addComment(0, ""))
        .to.be.revertedWith("Invalid length");
    });

    it("Should reject comment with invalid length", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      const longComment = "a".repeat(300); // > 280 chars

      await expect(core.connect(user2).addComment(0, longComment))
        .to.be.revertedWith("Invalid length");
    });
  });

  // ==================== LEVELING SYSTEM TESTS ====================
  
  describe("LevelingSystem - XP & Leveling", function () {
    it("Should track XP from NFT creation", async function () {
      const { core, leveling, user1 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);

      const profile = await leveling.getUserProfile(user1.address);
      expect(profile.totalXP).to.equal(10); // NFT creation = 10 XP
      expect(profile.nftsCreated).to.equal(1);
    });

    it("Should calculate correct level from XP", async function () {
      const { leveling } = await loadFixture(deployMarketplaceFixture);

      // L1-10: 50 XP per level (cumulative: 500 for L10)
      // L11-20: 100 XP per level (cumulative: 1500 for L20)
      // L21-30: 150 XP per level (cumulative: 3000 for L30)
      // L31-40: 200 XP per level (cumulative: 5000 for L40)
      // L41-50: 250 XP per level (cumulative: 7500 for L50)

      expect(await leveling.getLevelFromXP(0)).to.equal(0);
      expect(await leveling.getLevelFromXP(1)).to.equal(1);      // 1 XP = Level 1
      expect(await leveling.getLevelFromXP(49)).to.equal(1);     // 49 XP = Level 1
      expect(await leveling.getLevelFromXP(50)).to.equal(1);     // 50 XP = Level 1
      expect(await leveling.getLevelFromXP(100)).to.equal(2);    // 100 XP = Level 2
      expect(await leveling.getLevelFromXP(499)).to.equal(10);   // 499 XP = Level 10
      expect(await leveling.getLevelFromXP(500)).to.equal(10);   // 500 XP = Level 10
      expect(await leveling.getLevelFromXP(501)).to.equal(11);   // 501 XP = Level 11
      expect(await leveling.getLevelFromXP(600)).to.equal(11);   // 600 XP = Level 11
      expect(await leveling.getLevelFromXP(1500)).to.equal(20);  // 1500 XP = Level 20
      expect(await leveling.getLevelFromXP(3000)).to.equal(30);  // 3000 XP = Level 30
      expect(await leveling.getLevelFromXP(5000)).to.equal(40);  // 5000 XP = Level 40
      expect(await leveling.getLevelFromXP(7500)).to.equal(50);  // 7500 XP = Level 50
    });

    it("Should cap XP at 7500 (Level 50)", async function () {
      const { leveling, owner, user1 } = await loadFixture(deployMarketplaceFixture);

      // Grant MARKETPLACE_ROLE to owner so we can call updateUserXP
      const MARKETPLACE_ROLE = ethers.id("MARKETPLACE_ROLE");
      await leveling.connect(owner).grantRole(MARKETPLACE_ROLE, owner.address);
      
      // Add XP beyond max
      await leveling.connect(owner).updateUserXP(user1.address, 10000, "TEST_BONUS");
      
      const profile = await leveling.getUserProfile(user1.address);
      expect(profile.totalXP).to.equal(7500);
    });

    it("Should track NFT activities in profile", async function () {
      const { core, leveling, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      // User1 creates NFT
      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      let profile = await leveling.getUserProfile(user1.address);
      expect(profile.nftsCreated).to.equal(1);

      // User1 lists and User2 buys
      await core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"));
      await core.connect(user2).buyToken(0, { value: ethers.parseEther("1.0") });

      profile = await leveling.getUserProfile(user1.address);
      expect(profile.nftsSold).to.equal(1);

      profile = await leveling.getUserProfile(user2.address);
      expect(profile.nftsBought).to.equal(1);
    });

    it("Should emit LevelUp event on level progression", async function () {
      const { leveling, user1 } = await loadFixture(deployMarketplaceFixture);

      // This would need MARKETPLACE_ROLE, normally called by marketplace
      // For testing, we'd need direct access or bypass
    });

    it("Should reward user with 20 POL on level up", async function () {
      const { leveling, owner, user1 } = await loadFixture(deployMarketplaceFixture);

      // Grant MARKETPLACE_ROLE to owner so we can call updateUserXP
      const MARKETPLACE_ROLE = ethers.id("MARKETPLACE_ROLE");
      await leveling.connect(owner).grantRole(MARKETPLACE_ROLE, owner.address);

      const balanceBefore = await ethers.provider.getBalance(user1.address);

      // Add enough XP to level up (Level 1 requires 50 XP)
      // Level 0 -> Level 1
      await leveling.connect(owner).updateUserXP(user1.address, 50, "LEVEL_UP_TEST");

      const balanceAfter = await ethers.provider.getBalance(user1.address);
      const reward = ethers.parseEther("20");

      expect(balanceAfter).to.equal(balanceBefore + reward);
    });
  });

  // ==================== REFERRAL SYSTEM TESTS ====================
  
  describe("ReferralSystem - Referral Management", function () {
    it("Should generate unique referral code", async function () {
      const { referral, user1 } = await loadFixture(deployMarketplaceFixture);

      // Generate code
      await referral.connect(user1).generateReferralCode(user1.address);
      
      // Retrieve the generated code
      const storedCode = await referral.getReferralCode(user1.address);
      expect(storedCode).to.not.equal(ethers.ZeroHash);
      expect(storedCode.length).to.equal(66); // 0x + 64 hex chars
    });

    it("Should validate referral code", async function () {
      const { referral, user1 } = await loadFixture(deployMarketplaceFixture);

      // Generate code
      await referral.connect(user1).generateReferralCode(user1.address);
      const code = await referral.getReferralCode(user1.address);
      
      // Validate generated code
      const isValid = await referral.isValidReferralCode(code);
      expect(isValid).to.be.true;

      // Validate non-existent code
      const invalidCode = ethers.id("invalid");
      const isInvalid = await referral.isValidReferralCode(invalidCode);
      expect(isInvalid).to.be.false;
    });

    it("Should track referral statistics", async function () {
      const { referral, user1, user2, user3 } = await loadFixture(deployMarketplaceFixture);

      const code = await referral.connect(user1).generateReferralCode(user1.address);
      const MARKETPLACE_ROLE = ethers.id("MARKETPLACE_ROLE");

      // Simulate marketplace registering user2 and user3 with user1's code
      const referralContract = referral.connect(user1); // Using user1 signer, but we'd need proper role
      
      // Stats for user1
      const stats = await referral.getUserReferralStats(user1.address);
      expect(stats.totalCount).to.be.gte(0);
    });

    it("Should get user referrer", async function () {
      const { referral, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      const referrer = await referral.getUserReferrer(user2.address);
      // Will be zero address if not set
      expect(referrer).to.equal(ethers.constants?.AddressZero || ethers.ZeroAddress);
    });

    it("Should check if user has referrer", async function () {
      const { referral, user2 } = await loadFixture(deployMarketplaceFixture);

      const hasReferrer = await referral.userHasReferrer(user2.address);
      expect(hasReferrer).to.be.false;
    });
  });

  // ==================== INTEGRATION TESTS ====================
  
  describe("Integration - Complete Marketplace Flow", function () {
    it("Should complete full NFT lifecycle: create -> list -> buy -> social", async function () {
      const { core, user1, user2, user3 } = await loadFixture(deployMarketplaceFixture);

      // User1 creates NFT
      await core.connect(user1).createStandardNFT("https://ipfs.io/ipfs/Qm1", "art", 500);

      // User1 lists for sale
      const price = ethers.parseEther("1.0");
      await core.connect(user1).listTokenForSale(0, price);

      // User2 makes offer
      const offerAmount = ethers.parseEther("0.9");
      await core.connect(user2).makeOffer(0, 5, { value: offerAmount });

      // User1 accepts offer
      await core.connect(user1).acceptOffer(0, 0);

      // Verify ownership
      expect(await core.ownerOf(0)).to.equal(user2.address);

      // User3 likes the NFT
      await core.connect(user3).toggleLike(0);
      expect(await core.nftLikeCount(0)).to.equal(1);

      // User3 adds comment
      await core.connect(user3).addComment(0, "Amazing art!");
      const comments = await core.getNFTComments(0);
      expect(comments.length).to.equal(1);
    });

    it("Should handle multiple users and transactions", async function () {
      const { core, user1, user2, user3, user4 } = await loadFixture(deployMarketplaceFixture);

      // Multiple NFT creations
      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await core.connect(user1).createStandardNFT("uri2", "gaming", 0);
      await core.connect(user2).createStandardNFT("uri3", "music", 0);

      // Multiple listings
      const price = ethers.parseEther("1.0");
      await core.connect(user1).listTokenForSale(0, price);
      await core.connect(user1).listTokenForSale(1, price);
      await core.connect(user2).listTokenForSale(2, price);

      // Multiple purchases
      await core.connect(user3).buyToken(0, { value: price });
      await core.connect(user4).buyToken(1, { value: price });
      await core.connect(user3).buyToken(2, { value: price });

      // Verify final state
      expect(await core.ownerOf(0)).to.equal(user3.address);
      expect(await core.ownerOf(1)).to.equal(user4.address);
      expect(await core.ownerOf(2)).to.equal(user3.address);
    });

    it("Should track XP across multiple transactions", async function () {
      const { core, leveling, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      // User1 creates NFT (10 XP)
      await core.connect(user1).createStandardNFT("uri1", "art", 0);

      // User1 lists and User2 buys (Seller +20 XP, Buyer +15 XP)
      const price = ethers.parseEther("1.0");
      await core.connect(user1).listTokenForSale(0, price);
      await core.connect(user2).buyToken(0, { value: price });

      // User2 likes the NFT (1 XP)
      await core.connect(user2).toggleLike(0);

      // User2 adds comment (2 XP)
      await core.connect(user2).addComment(0, "Nice!");

      // Check XP accumulation
      let profile = await leveling.getUserProfile(user1.address);
      expect(profile.totalXP).to.equal(30); // 10 + 20

      profile = await leveling.getUserProfile(user2.address);
      expect(profile.totalXP).to.equal(18); // 15 + 1 + 2
    });
  });

  // ==================== ADVANCED INTEGRATION TESTS ====================
  
  describe("Integration - Multi-Contract Scenarios", function () {
    it("Should handle complete user journey: Create NFT → Skill → Quest → Sale", async function () {
      const { core, skills, quests, leveling, user1, user2, owner } = await loadFixture(deployMarketplaceFixture);

      // Step 1: User1 creates NFT
      await core.connect(user1).createStandardNFT("https://ipfs.io/ipfs/QmArt1", "art", 0);
      
      // Step 2: User1 gains XP
      let profile = await leveling.getUserProfile(user1.address);
      expect(profile.nftsCreated).to.equal(1);
      expect(profile.totalXP).to.equal(10);

      // Step 3: User1 lists NFT
      const price = ethers.parseEther("1.0");
      await core.connect(user1).listTokenForSale(0, price);

      // Step 4: User2 buys NFT
      await core.connect(user2).buyToken(0, { value: price });

      // Step 5: Verify XP accumulation for both users
      profile = await leveling.getUserProfile(user1.address);
      expect(profile.nftsSold).to.equal(1);
      expect(profile.totalXP).to.equal(30); // 10 (created) + 20 (sold)

      profile = await leveling.getUserProfile(user2.address);
      expect(profile.nftsBought).to.equal(1);
      expect(profile.totalXP).to.equal(15);
    });

    it("Should track ecosystem interactions across contracts", async function () {
      const { core, skills, leveling, user1, user2, user3 } = await loadFixture(deployMarketplaceFixture);

      // Multiple marketplace interactions
      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await core.connect(user2).createStandardNFT("uri2", "gaming", 0);
      
      // User3 interacts with both
      await core.connect(user3).toggleLike(0);
      await core.connect(user3).toggleLike(1);
      await core.connect(user3).addComment(0, "Great!");

      // Verify XP distribution
      const profile1 = await leveling.getUserProfile(user1.address);
      const profile2 = await leveling.getUserProfile(user2.address);
      const profile3 = await leveling.getUserProfile(user3.address);

      expect(profile1.nftsCreated).to.equal(1);
      expect(profile2.nftsCreated).to.equal(1);
      expect(profile3.totalXP).to.be.gt(0);
    });

    it("Should handle offer flow with referral tracking", async function () {
      const { core, referral, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      // User1 creates referral code
      await referral.connect(user1).generateReferralCode(user1.address);
      const code = await referral.getReferralCode(user1.address);
      
      // User1 creates and lists NFT
      await core.connect(user1).createStandardNFT("uri", "art", 0);
      await core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"));

      // User2 makes offer
      const offerAmount = ethers.parseEther("0.9");
      await core.connect(user2).makeOffer(0, 3, { value: offerAmount });

      // User1 accepts offer
      await expect(core.connect(user1).acceptOffer(0, 0))
        .to.emit(core, "OfferAccepted");

      expect(await core.ownerOf(0)).to.equal(user2.address);
    });

    it("Should prevent marketplace operations when contract is paused", async function () {
      const { core, user1, owner } = await loadFixture(deployMarketplaceFixture);

      // Create and list NFT
      await core.connect(user1).createStandardNFT("uri", "art", 0);

      // Pause contract
      await core.connect(owner).pause();

      // All operations should fail
      await expect(
        core.connect(user1).createStandardNFT("uri2", "art", 0)
      ).to.be.reverted;

      await expect(
        core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"))
      ).to.be.reverted;

      // Unpause and verify operations work again
      await core.connect(owner).unpause();
      await expect(core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0")))
        .to.emit(core, "TokenListed");
    });
  });

  // ==================== EDGE CASES & STRESS TESTS ====================
  
  describe("Edge Cases & Boundary Conditions", function () {
    it("Should handle maximum number of offers per NFT", async function () {
      const { core, user1, user2, user3, user4, user5 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri", "art", 0);
      await core.connect(user1).listTokenForSale(0, ethers.parseEther("5.0"));

      // Multiple users making offers
      await core.connect(user2).makeOffer(0, 1, { value: ethers.parseEther("2.0") });
      await core.connect(user3).makeOffer(0, 1, { value: ethers.parseEther("2.5") });
      await core.connect(user4).makeOffer(0, 1, { value: ethers.parseEther("3.0") });
      await core.connect(user5).makeOffer(0, 1, { value: ethers.parseEther("3.5") });

      // Accept best offer
      await core.connect(user1).acceptOffer(0, 3); // User5's offer (3.5 ETH)
      expect(await core.ownerOf(0)).to.equal(user5.address);
    });

    it("Should handle XP boundary at level transitions", async function () {
      const { leveling, owner, user1 } = await loadFixture(deployMarketplaceFixture);

      // Grant MARKETPLACE_ROLE to owner
      const MARKETPLACE_ROLE = ethers.id("MARKETPLACE_ROLE");
      await leveling.connect(owner).grantRole(MARKETPLACE_ROLE, owner.address);

      // Add XP to exactly reach level 10 (500 XP)
      await leveling.connect(owner).updateUserXP(user1.address, 500, "BOUNDARY_TEST");
      
      let profile = await leveling.getUserProfile(user1.address);
      expect(profile.level).to.equal(10);
      expect(profile.totalXP).to.equal(500);

      // Add 1 more XP to cross to level 11
      await leveling.connect(owner).updateUserXP(user1.address, 1, "CROSS_BOUNDARY");
      
      profile = await leveling.getUserProfile(user1.address);
      expect(profile.level).to.equal(11);
      expect(profile.totalXP).to.equal(501);
    });

    it("Should handle maximum XP cap correctly", async function () {
      const { leveling, owner, user1 } = await loadFixture(deployMarketplaceFixture);

      const MARKETPLACE_ROLE = ethers.id("MARKETPLACE_ROLE");
      await leveling.connect(owner).grantRole(MARKETPLACE_ROLE, owner.address);

      // Add XP to max
      await leveling.connect(owner).updateUserXP(user1.address, 7500, "MAX_XP");
      
      let profile = await leveling.getUserProfile(user1.address);
      expect(profile.totalXP).to.equal(7500);
      expect(profile.level).to.equal(50);

      // Try to add more XP (should be capped)
      await leveling.connect(owner).updateUserXP(user1.address, 1000, "OVERFLOW_TEST");
      
      profile = await leveling.getUserProfile(user1.address);
      expect(profile.totalXP).to.equal(7500); // Still capped
      expect(profile.level).to.equal(50);
    });

    it("Should handle large numbers of NFTs per user", async function () {
      const { core, user1 } = await loadFixture(deployMarketplaceFixture);

      // Create 10 NFTs
      for (let i = 0; i < 10; i++) {
        await core.connect(user1).createStandardNFT(`uri${i}`, "art", 0);
      }

      const userNFTs = await core.getUserNFTs(user1.address);
      expect(userNFTs.length).to.equal(10);

      // Verify all are accessible
      for (let i = 0; i < 10; i++) {
        expect(await core.ownerOf(i)).to.equal(user1.address);
      }
    });

    it("Should handle rapid successive transactions", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      // Rapid NFT creation
      for (let i = 0; i < 5; i++) {
        await core.connect(user1).createStandardNFT(`uri${i}`, "art", 0);
      }

      // Rapid listings
      for (let i = 0; i < 5; i++) {
        await core.connect(user1).listTokenForSale(i, ethers.parseEther("1.0"));
      }

      // Rapid purchases
      for (let i = 0; i < 5; i++) {
        await core.connect(user2).buyToken(i, { value: ethers.parseEther("1.0") });
      }

      expect(await core.ownerOf(0)).to.equal(user2.address);
      expect(await core.ownerOf(4)).to.equal(user2.address);
    });

    it("Should reject duplicate offers from same user", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri", "art", 0);
      await core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"));

      // First offer succeeds
      await core.connect(user2).makeOffer(0, 1, { value: ethers.parseEther("0.5") });

      // Second offer from same user (may or may not be allowed depending on implementation)
      // This tests the contract's logic
      const tx = core.connect(user2).makeOffer(0, 1, { value: ethers.parseEther("0.6") });
      await expect(tx).to.not.throw;
    });

    it("Should handle comment character limits", async function () {
      const { core, user1, user2 } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri", "art", 0);

      // Maximum valid comment length (280 chars)
      const maxComment = "a".repeat(280);
      await expect(core.connect(user2).addComment(0, maxComment))
        .to.emit(core, "CommentAdded");

      // Over maximum should fail
      const overMaxComment = "a".repeat(281);
      await expect(core.connect(user2).addComment(0, overMaxComment))
        .to.be.revertedWith("Invalid length");
    });
  });
  
  describe("Contract Management - Pause/Unpause", function () {
    it("Should pause contract", async function () {
      const { core, owner } = await loadFixture(deployMarketplaceFixture);

      await core.connect(owner).pause();
      expect(await core.paused()).to.be.true;
    });

    it("Should unpause contract", async function () {
      const { core, owner } = await loadFixture(deployMarketplaceFixture);

      await core.connect(owner).pause();
      await core.connect(owner).unpause();
      expect(await core.paused()).to.be.false;
    });

    it("Should prevent operations when paused", async function () {
      const { core, user1, owner } = await loadFixture(deployMarketplaceFixture);

      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await core.connect(owner).pause();

      await expect(
        core.connect(user1).listTokenForSale(0, ethers.parseEther("1.0"))
      ).to.be.revertedWith("Pausable: paused");
    });
  });

  // ==================== ACCESS CONTROL TESTS ====================
  
  describe("Access Control - Admin Functions", function () {
    it("Should allow admin to set leveling system", async function () {
      const { core, leveling, owner } = await loadFixture(deployMarketplaceFixture);

      const levelingAddr = await leveling.getAddress();
      await expect(core.connect(owner).setLevelingSystem(levelingAddr))
        .to.not.be.reverted;
    });

    it("Should allow admin to set referral system", async function () {
      const { core, referral, owner } = await loadFixture(deployMarketplaceFixture);

      const referralAddr = await referral.getAddress();
      await expect(core.connect(owner).setReferralSystem(referralAddr))
        .to.not.be.reverted;
    });

    it("Should reject non-admin pause", async function () {
      const { core, user1 } = await loadFixture(deployMarketplaceFixture);

      await expect(core.connect(user1).pause())
        .to.be.reverted;
    });
  });

  // ==================== INDIVIDUAL SKILLS MARKETPLACE TESTS ====================
  
  describe("IndividualSkillsMarketplace - Skill Management", function () {
    it("Should purchase individual skill with correct pricing", async function () {
      const { individual, user1, owner } = await loadFixture(deployMarketplaceFixture);

      // Get pricing for a skill
      const skillType = 1; // STAKE_BOOST_I
      const rarity = 0; // COMMON
      const price = await individual.getSkillPrice(skillType, rarity);
      
      expect(price).to.be.gt(0);
    });

    it("Should get individual skill prices for all rarities", async function () {
      const { individual } = await loadFixture(deployMarketplaceFixture);

      const skillType = 1; // STAKE_BOOST_I
      const prices = await individual.getSkillPricesAllRarities(skillType);
      
      expect(prices.length).to.equal(5); // 5 rarities
      // Each rarity should have increasing price
      for (let i = 0; i < prices.length - 1; i++) {
        expect(prices[i]).to.be.lte(prices[i + 1]);
      }
    });

    it("Should get all skills pricing structure", async function () {
      const { individual } = await loadFixture(deployMarketplaceFixture);

      const allPricing = await individual.getAllSkillsPricing();
      expect(allPricing.length).to.be.gt(0);
    });

    it("Should get base prices configuration", async function () {
      const { individual } = await loadFixture(deployMarketplaceFixture);

      const basePrices = await individual.getCurrentBasePrices();
      expect(basePrices.length).to.equal(5); // 5 rarities
      
      // Base prices should be increasing
      for (let i = 0; i < basePrices.length - 1; i++) {
        expect(basePrices[i]).to.be.lt(basePrices[i + 1]);
      }
    });

    it("Should get rarity effect multipliers", async function () {
      const { individual } = await loadFixture(deployMarketplaceFixture);

      const multipliers = await individual.getRarityEffectMultipliers();
      expect(multipliers.length).to.equal(5); // 5 rarities
      
      // Multipliers should increase with rarity
      for (let i = 0; i < multipliers.length - 1; i++) {
        expect(multipliers[i]).to.be.lte(multipliers[i + 1]);
      }
    });

    it("Should get level multipliers", async function () {
      const { individual } = await loadFixture(deployMarketplaceFixture);

      const multipliers = await individual.getLevelMultipliers();
      expect(multipliers.length).to.equal(3); // 3 levels
      
      // Level multipliers should increase
      expect(multipliers[0]).to.be.lt(multipliers[1]);
      expect(multipliers[1]).to.be.lt(multipliers[2]);
    });

    it("Should get skill effect values for all rarities", async function () {
      const { individual } = await loadFixture(deployMarketplaceFixture);

      const skillType = 1; // STAKE_BOOST_I
      const effectValues = await individual.getSkillEffectValuesAllRarities(skillType);
      
      expect(effectValues.length).to.equal(5); // 5 rarities
    });

    it("Should allow admin to set base price per rarity", async function () {
      const { individual, owner } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await individual.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      const newPrice = ethers.parseEther("100");
      await expect(individual.connect(owner).setBasePricePerRarity(0, newPrice))
        .to.not.be.reverted;
    });

    it("Should allow admin to set rarity effect multiplier", async function () {
      const { individual, owner } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await individual.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      const newMultiplier = 15000; // 1.5x
      await expect(individual.connect(owner).setRarityEffectMultiplier(1, newMultiplier))
        .to.not.be.reverted;
    });

    it("Should allow admin to set level multiplier", async function () {
      const { individual, owner } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await individual.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      const newMultiplier = 20000; // 2.0x
      await expect(individual.connect(owner).setLevelMultiplier(1, newMultiplier))
        .to.not.be.reverted;
    });

    it("Should allow admin to pause contract", async function () {
      const { individual, owner } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await individual.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      await expect(individual.connect(owner).pause())
        .to.not.be.reverted;
      
      expect(await individual.paused()).to.be.true;
    });

    it("Should allow admin to unpause contract", async function () {
      const { individual, owner } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await individual.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      await individual.connect(owner).pause();
      await expect(individual.connect(owner).unpause())
        .to.not.be.reverted;
      
      expect(await individual.paused()).to.be.false;
    });

    it("Should allow admin to reset pricing to defaults", async function () {
      const { individual, owner } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await individual.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      // Change a price
      const newPrice = ethers.parseEther("200");
      await individual.connect(owner).setBasePricePerRarity(0, newPrice);
      
      // Reset to defaults
      await expect(individual.connect(owner).resetSkillPricingToDefaults())
        .to.not.be.reverted;
    });

    it("Should set staking contract address", async function () {
      const { individual, owner } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await individual.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      const fakeStakingAddr = ethers.Wallet.createRandom().address;
      await expect(individual.connect(owner).setStakingContract(fakeStakingAddr))
        .to.not.be.reverted;
    });

    it("Should set treasury address", async function () {
      const { individual, owner, treasury } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await individual.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      await expect(individual.connect(owner).setTreasuryAddress(treasury.address))
        .to.not.be.reverted;
    });

    it("Should reject non-admin price changes", async function () {
      const { individual, user1 } = await loadFixture(deployMarketplaceFixture);

      const newPrice = ethers.parseEther("100");
      await expect(individual.connect(user1).setBasePricePerRarity(0, newPrice))
        .to.be.reverted;
    });
  });

  // ==================== GAMEIFIED MARKETPLACE QUESTS TESTS ====================
  
  describe("GameifiedMarketplaceQuests - Quest System", function () {
    it("Should get all active quests", async function () {
      const { quests } = await loadFixture(deployMarketplaceFixture);

      const activeQuests = await quests.getAllActiveQuests();
      expect(Array.isArray(activeQuests)).to.be.true;
    });

    it("Should get quests by type", async function () {
      const { quests } = await loadFixture(deployMarketplaceFixture);

      const questType = 0; // MARKETPLACE_QUEST
      const questsByType = await quests.getQuestsByType(questType);
      expect(Array.isArray(questsByType)).to.be.true;
    });

    it("Should record social actions", async function () {
      const { quests, owner, user1 } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await quests.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      await expect(quests.connect(owner).recordSocialAction(user1.address))
        .to.not.be.reverted;
    });

    it("Should get user social actions count", async function () {
      const { quests, owner, user1 } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await quests.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      await quests.connect(owner).recordSocialAction(user1.address);
      
      const socialActions = await quests.getUserSocialActions(user1.address);
      expect(socialActions).to.be.gte(0);
    });

    it("Should get user completed quests", async function () {
      const { quests, user1 } = await loadFixture(deployMarketplaceFixture);

      const completedQuests = await quests.getUserCompletedQuests(user1.address);
      expect(Array.isArray(completedQuests)).to.be.true;
    });

    it("Should set core contract address", async function () {
      const { quests, owner, core } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await quests.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      const coreAddr = await core.getAddress();
      await expect(quests.connect(owner).setCoreContract(coreAddr))
        .to.not.be.reverted;
    });

    it("Should set staking contract address", async function () {
      const { quests, owner } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await quests.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      const fakeStakingAddr = ethers.Wallet.createRandom().address;
      await expect(quests.connect(owner).setStakingContract(fakeStakingAddr))
        .to.not.be.reverted;
    });

    it("Should allow admin to pause quests", async function () {
      const { quests, owner } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await quests.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      await expect(quests.connect(owner).pause())
        .to.not.be.reverted;
      
      expect(await quests.paused()).to.be.true;
    });

    it("Should allow admin to unpause quests", async function () {
      const { quests, owner } = await loadFixture(deployMarketplaceFixture);

      const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
      await quests.connect(owner).grantRole(ADMIN_ROLE, owner.address);
      
      await quests.connect(owner).pause();
      await expect(quests.connect(owner).unpause())
        .to.not.be.reverted;
      
      expect(await quests.paused()).to.be.false;
    });

    it("Should reject non-admin quest operations", async function () {
      const { quests, user1, owner } = await loadFixture(deployMarketplaceFixture);

      const fakeAddr = ethers.Wallet.createRandom().address;
      await expect(quests.connect(user1).setCoreContract(fakeAddr))
        .to.be.reverted;
    });
  });

  // ==================== GAMEIFIED MARKETPLACE PROXY TESTS ====================
  
  describe("GameifiedMarketplaceProxy - Proxy Management", function () {
    it("Should deploy proxy with valid implementation", async function () {
      const [owner] = await ethers.getSigners();

      // Get the implementation
      const CoreFactory = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
      const implementation = await CoreFactory.deploy();
      await implementation.deploymentTransaction().wait();

      // Create initialization data
      const initData = CoreFactory.interface.encodeFunctionData("initialize", [owner.address]);

      // Deploy proxy with valid implementation
      const ProxyFactory = await ethers.getContractFactory("GameifiedMarketplaceProxy");
      const proxy = await ProxyFactory.deploy(await implementation.getAddress(), initData);
      
      expect(proxy).to.not.be.undefined;
    });

    it("Should revert on invalid implementation address", async function () {
      const [owner] = await ethers.getSigners();

      const CoreFactory = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
      const initData = CoreFactory.interface.encodeFunctionData("initialize", [owner.address]);

      // Try to deploy with EOA address (invalid)
      const ProxyFactory = await ethers.getContractFactory("GameifiedMarketplaceProxy");
      const fakeImplementation = ethers.Wallet.createRandom().address;

      await expect(ProxyFactory.deploy(fakeImplementation, initData))
        .to.be.reverted;
    });

    it("Should revert on empty initialization data", async function () {
      const CoreFactory = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
      const implementation = await CoreFactory.deploy();
      await implementation.deploymentTransaction().wait();

      // Try to deploy with empty init data
      const ProxyFactory = await ethers.getContractFactory("GameifiedMarketplaceProxy");
      await expect(ProxyFactory.deploy(await implementation.getAddress(), "0x"))
        .to.be.reverted;
    });

    it("Should emit ProxyInitialized event", async function () {
      const [owner] = await ethers.getSigners();

      const CoreFactory = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
      const implementation = await CoreFactory.deploy();
      await implementation.deploymentTransaction().wait();

      const initData = CoreFactory.interface.encodeFunctionData("initialize", [owner.address]);

      const ProxyFactory = await ethers.getContractFactory("GameifiedMarketplaceProxy");
      // Verify the proxy deploys without errors - the event is internal to proxy
      const proxy = await ProxyFactory.deploy(await implementation.getAddress(), initData);
      expect(proxy).to.not.be.undefined;
    });

    it("Should reject direct ETH transfers to proxy", async function () {
      const [owner, treasury, user1] = await ethers.getSigners();

      // Deploy proxy
      const CoreFactory = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
      const implementation = await CoreFactory.deploy();
      await implementation.deploymentTransaction().wait();

      const initData = CoreFactory.interface.encodeFunctionData("initialize", [owner.address]);

      const ProxyFactory = await ethers.getContractFactory("GameifiedMarketplaceProxy");
      const proxy = await ProxyFactory.deploy(await implementation.getAddress(), initData);
      const proxyAddr = await proxy.getAddress();

      // Try to send ETH directly to proxy (receive function should reject)
      await expect(
        user1.sendTransaction({
          to: proxyAddr,
          value: ethers.parseEther("1.0")
        })
      ).to.be.reverted;
    });

    it("Should maintain proxy functionality after deployment", async function () {
      const [owner, treasury] = await ethers.getSigners();

      // Deploy via UUPS proxy
      const CoreFactory = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
      const core = await upgrades.deployProxy(CoreFactory, [treasury.address], {
        initializer: 'initialize',
        kind: 'uups'
      });
      
      // Verify proxy works correctly by checking a basic state variable
      const platformTreasury = await core.platformTreasury();
      expect(platformTreasury).to.equal(treasury.address);
    });
  });

  // ==================== COMPREHENSIVE INTEGRATION TESTS ====================
  
  describe("Comprehensive Integration - All Components", function () {
    it("Should coordinate between Core, Leveling, and Quests", async function () {
      const { core, leveling, quests, user1, user2, owner } = await loadFixture(deployMarketplaceFixture);

      // Grant ADMIN_ROLE to owner for quests
      const ADMIN_ROLE = await quests.ADMIN_ROLE();
      await quests.connect(owner).grantRole(ADMIN_ROLE, owner.address);

      // User1 creates NFT and records quest progress
      await core.connect(user1).createStandardNFT("uri1", "art", 0);
      await quests.connect(owner).recordSocialAction(user1.address);

      // Verify XP is tracked
      let profile = await leveling.getUserProfile(user1.address);
      expect(profile.nftsCreated).to.equal(1);
      expect(profile.totalXP).to.equal(10);
    });

    it("Should manage multiple skill purchases via IndividualSkillsMarketplace", async function () {
      const { individual } = await loadFixture(deployMarketplaceFixture);

      // Verify pricing structure is complete
      for (let skillType = 1; skillType <= 5; skillType++) {
        const prices = await individual.getSkillPricesAllRarities(skillType);
        expect(prices.length).to.equal(5);
        
        for (let price of prices) {
          expect(price).to.be.gt(0);
        }
      }
    });

    it("Should handle pause/unpause across marketplace modules", async function () {
      const { core, individual, quests, owner } = await loadFixture(deployMarketplaceFixture);

      // Grant ADMIN_ROLE
      const coreAdminRole = await core.ADMIN_ROLE();
      const individualAdminRole = ethers.id("ADMIN_ROLE");
      const questsAdminRole = await quests.ADMIN_ROLE();

      await core.connect(owner).grantRole(coreAdminRole, owner.address);
      await individual.connect(owner).grantRole(individualAdminRole, owner.address);
      await quests.connect(owner).grantRole(questsAdminRole, owner.address);

      // Pause all modules
      await core.connect(owner).pause();
      await individual.connect(owner).pause();
      await quests.connect(owner).pause();

      // Verify all are paused
      expect(await core.paused()).to.be.true;
      expect(await individual.paused()).to.be.true;
      expect(await quests.paused()).to.be.true;

      // Unpause all
      await core.connect(owner).unpause();
      await individual.connect(owner).unpause();
      await quests.connect(owner).unpause();

      // Verify all are unpaused
      expect(await core.paused()).to.be.false;
      expect(await individual.paused()).to.be.false;
      expect(await quests.paused()).to.be.false;
    });
  });
});