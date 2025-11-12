const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GameifiedMarketplace Modularized - Complete Test", function () {
    let core, skills, quests;
    let deployer, user1, user2;
    const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

    beforeEach(async function () {
        [deployer, user1, user2] = await ethers.getSigners();

        // Deploy Core
        const GameifiedMarketplaceCore = await ethers.getContractFactory("GameifiedMarketplaceCore");
        core = await GameifiedMarketplaceCore.deploy();
        core = await core.waitForDeployment();

        // Deploy Skills
        const GameifiedMarketplaceSkills = await ethers.getContractFactory("GameifiedMarketplaceSkills");
        skills = await GameifiedMarketplaceSkills.deploy(await core.getAddress());
        skills = await skills.waitForDeployment();

        // Deploy Quests
        const GameifiedMarketplaceQuests = await ethers.getContractFactory("GameifiedMarketplaceQuests");
        quests = await GameifiedMarketplaceQuests.deploy(await core.getAddress());
        quests = await quests.waitForDeployment();

        // Link contracts
        let tx = await core.setSkillsContract(await skills.getAddress());
        await tx.wait();

        tx = await core.setQuestsContract(await quests.getAddress());
        await tx.wait();
    });

    // ==================== CORE TESTS ====================
    describe("GameifiedMarketplaceCore - NFT & Marketplace", function () {
        it("Should create standard NFT and award 10 XP", async function () {
            const tx = await core.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx.wait();

            const profile = await core.userProfiles(user1.address);
            expect(profile.totalXP).to.equal(10);
            expect(profile.nftsCreated).to.equal(1);
        });

        it("Should list NFT for sale", async function () {
            const tx1 = await core.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            const tx2 = await core.connect(user1).listTokenForSale(0, ethers.parseEther("1"), "");
            await tx2.wait();

            const isListed = await core.isListed(0);
            expect(isListed).to.be.true;
        });

        it("Should buy NFT and update XP", async function () {
            const tx1 = await core.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            const tx2 = await core.connect(user1).listTokenForSale(0, ethers.parseEther("1"), "");
            await tx2.wait();

            const tx3 = await core.connect(user2).buyToken(0, {
                value: ethers.parseEther("1")
            });
            await tx3.wait();

            const sellerProfile = await core.userProfiles(user1.address);
            const buyerProfile = await core.userProfiles(user2.address);

            expect(sellerProfile.nftsSold).to.equal(1);
            expect(buyerProfile.nftsBought).to.equal(1);
            expect(sellerProfile.totalXP).to.equal(30); // 10 (create) + 20 (sell)
            expect(buyerProfile.totalXP).to.equal(15); // 15 (buy)
        });

        it("Should toggle like and award 1 XP", async function () {
            const tx1 = await core.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            const tx2 = await core.connect(user2).toggleLike(0);
            await tx2.wait();

            const likeCount = await core.nftLikeCount(0);
            const profile = await core.userProfiles(user2.address);

            expect(likeCount).to.equal(1);
            expect(profile.totalXP).to.equal(1);
        });

        it("Should add comment and award 2 XP", async function () {
            const tx1 = await core.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            const tx2 = await core.connect(user2).addComment(0, "Great NFT!");
            await tx2.wait();

            const profile = await core.userProfiles(user2.address);
            expect(profile.totalXP).to.equal(2);
        });

        it("Should make and accept offer", async function () {
            const tx1 = await core.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            const tx2 = await core.connect(user1).listTokenForSale(0, ethers.parseEther("2"), "");
            await tx2.wait();

            const tx3 = await core.connect(user2).makeOffer(0, 7, {
                value: ethers.parseEther("1.5")
            });
            await tx3.wait();

            const tx4 = await core.connect(user1).acceptOffer(0, 0);
            await tx4.wait();

            const owner = await core.ownerOf(0);
            expect(owner).to.equal(user2.address);
        });
    });

    // ==================== SKILLS TESTS ====================
    describe("GameifiedMarketplaceSkills - NFT Creation with Skills", function () {
        it("Should create skill NFT with proper XP", async function () {
            // 1. User1 creates standard NFT first
            let tx = await core.connect(user1).createStandardNFT(
                "https://example.com/skill1.json",
                "SKILL_NFT",
                500
            );
            await tx.wait();
            
            // 2. Then register skills metadata on it
            tx = await skills.connect(user1).registerSkillsForNFT(
                0, // tokenId
                [0, 1], // CODING, DESIGN
                [0, 1], // COMMON, UNCOMMON
                [1, 2],
                ethers.parseEther("0.5")
            );
            await tx.wait();

            const profile = await core.userProfiles(user1.address);
            // First skill (free): 15 XP
            // Second skill (UNCOMMON): 10 + (1 * 5) = 15 XP
            // Total: 30 XP + 10 from NFT creation = 40 XP
            expect(profile.totalXP).to.equal(40);
        });

        it("Should reject duplicate skill types", async function () {
            let tx = await core.connect(user1).createStandardNFT(
                "https://example.com/skill1.json",
                "SKILL_NFT",
                500
            );
            await tx.wait();
            
            await expect(
                skills.connect(user1).registerSkillsForNFT(
                    0,
                    [0, 0], // Duplicate CODING
                    [0, 1],
                    [1, 2],
                    ethers.parseEther("0.5")
                )
            ).to.be.revertedWith("Duplicate skill type");
        });

        it("Should retrieve skill NFT skills", async function () {
            let tx = await core.connect(user1).createStandardNFT(
                "https://example.com/skill1.json",
                "SKILL_NFT",
                500
            );
            await tx.wait();
            
            tx = await skills.connect(user1).registerSkillsForNFT(
                0,
                [0, 1], // CODING, DESIGN
                [0, 1], // COMMON, UNCOMMON
                [1, 2],
                ethers.parseEther("0.5")
            );
            await tx.wait();

            const skillNFTSkills = await skills.getSkillNFTSkills(0);
            expect(skillNFTSkills.length).to.equal(2);
            expect(skillNFTSkills[0].skillType).to.equal(0); // CODING
        });
    });

    // ==================== QUESTS TESTS ====================
    describe("GameifiedMarketplaceQuests - Quest System", function () {
        it("Should create quest", async function () {
            const QuestType = {
                PURCHASE: 0,
                CREATE: 1,
                SOCIAL: 2,
                LEVEL_UP: 3,
                TRADING: 4
            };

            const tx = await quests.createQuest(
                QuestType.CREATE,
                "Create Master",
                "Create 5 NFTs",
                5,
                100
            );
            await tx.wait();

            const quest = await quests.getQuest(0);
            expect(quest.questId).to.equal(0);
            expect(quest.requirement).to.equal(5);
        });

        it("Should complete quest and award XP", async function () {
            const QuestType = { CREATE: 1 };

            // Create quest: Create 1 NFT
            let tx = await quests.createQuest(QuestType.CREATE, "First NFT", "Create 1 NFT", 1, 50);
            await tx.wait();

            // User creates an NFT
            tx = await core.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx.wait();

            // Complete quest
            tx = await quests.connect(user1).completeQuest(0);
            await tx.wait();

            const progress = await quests.getUserQuestProgress(user1.address, 0);
            expect(progress.completed).to.be.true;

            const profile = await core.userProfiles(user1.address);
            // 10 (NFT create) + 50 (quest reward) = 60 XP
            expect(profile.totalXP).to.equal(60);
        });

        it("Should prevent completing quest twice", async function () {
            const QuestType = { CREATE: 1 };

            let tx = await quests.createQuest(QuestType.CREATE, "First NFT", "Create 1 NFT", 1, 50);
            await tx.wait();

            tx = await core.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx.wait();

            tx = await quests.connect(user1).completeQuest(0);
            await tx.wait();

            // Try to complete again
            await expect(
                quests.connect(user1).completeQuest(0)
            ).to.be.revertedWith("Already completed");
        });
    });

    // ==================== INTEGRATION TESTS ====================
    describe("Integration - Full User Journey", function () {
        it("Should handle complete user workflow", async function () {
            const QuestType = { CREATE: 1, TRADING: 4 };

            // 1. Create quests
            let tx = await quests.createQuest(QuestType.CREATE, "Creator", "Create 2 NFTs", 2, 100);
            await tx.wait();

            tx = await quests.createQuest(QuestType.TRADING, "Seller", "Sell 1 NFT", 1, 75);
            await tx.wait();

            // 2. User1 creates 2 NFTs
            for (let i = 0; i < 2; i++) {
                tx = await core.connect(user1).createStandardNFT(
                    `https://example.com/nft${i}.json`,
                    "ART",
                    500
                );
                await tx.wait();
            }

            // 3. List first NFT
            tx = await core.connect(user1).listTokenForSale(0, ethers.parseEther("1"), "");
            await tx.wait();

            // 4. User2 buys it
            tx = await core.connect(user2).buyToken(0, {
                value: ethers.parseEther("1")
            });
            await tx.wait();

            // 5. Complete quests
            tx = await quests.connect(user1).completeQuest(0); // CREATE quest
            await tx.wait();

            tx = await quests.connect(user1).completeQuest(1); // TRADING quest
            await tx.wait();

            // Verify XP
            const profile = await core.userProfiles(user1.address);
            expect(profile.nftsCreated).to.equal(2);
            expect(profile.nftsSold).to.equal(1);
            // 20 (2 NFTs) + 20 (sell) + 100 (CREATE quest) + 75 (TRADING quest) = 215
            expect(profile.totalXP).to.equal(215);

            // Verify level up
            expect(profile.level).to.equal(2); // 215 XP / 100 = level 2
        });

        it("Should handle multiple skill NFT creation", async function () {
            // Create 2 skill NFTs with different skills
            let tx = await core.connect(user1).createStandardNFT(
                "https://example.com/skill1.json",
                "SKILL_NFT",
                500
            );
            await tx.wait();

            tx = await skills.connect(user1).registerSkillsForNFT(
                0,
                [0, 1], // CODING, DESIGN
                [0, 1],
                [1, 2],
                ethers.parseEther("0.5")
            );
            await tx.wait();

            tx = await core.connect(user1).createStandardNFT(
                "https://example.com/skill2.json",
                "SKILL_NFT",
                500
            );
            await tx.wait();

            tx = await skills.connect(user1).registerSkillsForNFT(
                1,
                [2, 3], // MARKETING, TRADING
                [0, 2],
                [1, 3],
                ethers.parseEther("0.5")
            );
            await tx.wait();

            const userSkills = await skills.getUserSkillNFTs(user1.address);
            expect(userSkills.length).to.equal(2);

            const profile = await core.userProfiles(user1.address);
            expect(profile.totalXP).to.be.greaterThan(0);
        });
    });
});
