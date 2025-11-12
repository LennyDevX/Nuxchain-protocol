const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GameifiedMarketplace with UUPS Proxy - Complete Test", function () {
    let proxy, implementation, skills, quests;
    let deployer, user1, user2;
    const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

    beforeEach(async function () {
        [deployer, user1, user2] = await ethers.getSigners();

        // Deploy Implementation
        const GameifiedMarketplaceCoreV1 = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
        implementation = await GameifiedMarketplaceCoreV1.deploy();
        implementation = await implementation.waitForDeployment();
        const implementationAddress = await implementation.getAddress();

        // Prepare initialization data
        const initData = GameifiedMarketplaceCoreV1.interface.encodeFunctionData(
            'initialize',
            [deployer.address]
        );

        // Deploy Proxy
        const GameifiedMarketplaceProxy = await ethers.getContractFactory("GameifiedMarketplaceProxy");
        const proxyContract = await GameifiedMarketplaceProxy.deploy(implementationAddress, initData);
        await proxyContract.waitForDeployment();
        const proxyAddress = await proxyContract.getAddress();

        // Attach Core ABI to proxy address
        proxy = GameifiedMarketplaceCoreV1.attach(proxyAddress);

        // Grant UPGRADER_ROLE to deployer
        const UPGRADER_ROLE = await proxy.UPGRADER_ROLE();
        let tx = await proxy.grantRole(UPGRADER_ROLE, deployer.address);
        await tx.wait();

        // Deploy Skills with proxy address
        const GameifiedMarketplaceSkills = await ethers.getContractFactory("GameifiedMarketplaceSkills");
        skills = await GameifiedMarketplaceSkills.deploy(proxyAddress);
        skills = await skills.waitForDeployment();

        // Deploy Quests with proxy address
        const GameifiedMarketplaceQuests = await ethers.getContractFactory("GameifiedMarketplaceQuests");
        quests = await GameifiedMarketplaceQuests.deploy(proxyAddress);
        quests = await quests.waitForDeployment();

        // Link contracts
        tx = await proxy.setSkillsContract(await skills.getAddress());
        await tx.wait();

        tx = await proxy.setQuestsContract(await quests.getAddress());
        await tx.wait();
    });

    // ==================== CORE TESTS ====================
    describe("GameifiedMarketplaceCore - NFT & Marketplace", function () {
        it("Should create standard NFT and award 10 XP", async function () {
            const tx = await proxy.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx.wait();

            const profile = await proxy.userProfiles(user1.address);
            expect(profile.totalXP).to.equal(10);
            expect(profile.nftsCreated).to.equal(1);
        });

        it("Should list NFT for sale", async function () {
            const tx1 = await proxy.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            const tx2 = await proxy.connect(user1).listTokenForSale(0, ethers.parseEther("1"), "");
            await tx2.wait();

            const listed = await proxy.isListed(0);
            const price = await proxy.listedPrice(0);
            expect(listed).to.be.true;
            expect(price).to.equal(ethers.parseEther("1"));
        });

        it("Should buy NFT and transfer ownership", async function () {
            // Create NFT
            const tx1 = await proxy.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            // List for sale
            const tx2 = await proxy.connect(user1).listTokenForSale(0, ethers.parseEther("1"), "");
            await tx2.wait();

            // Buy NFT
            const tx3 = await proxy.connect(user2).buyToken(0, { value: ethers.parseEther("1") });
            await tx3.wait();

            // Verify ownership and XP
            const owner = await proxy.ownerOf(0);
            const profile1 = await proxy.userProfiles(user1.address);
            const profile2 = await proxy.userProfiles(user2.address);

            expect(owner).to.equal(user2.address);
            expect(profile1.nftsSold).to.equal(1);
            expect(profile1.totalXP).to.equal(30); // 10 (create) + 20 (sold)
            expect(profile2.nftsBought).to.equal(1);
            expect(profile2.totalXP).to.equal(15); // 15 (bought)
        });

        it("Should toggle like and award XP", async function () {
            // Create NFT
            const tx1 = await proxy.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            // Like NFT
            const tx2 = await proxy.connect(user2).toggleLike(0);
            await tx2.wait();

            // Verify like and XP
            const liked = await proxy.nftLikes(0, user2.address);
            const likeCount = await proxy.nftLikeCount(0);
            const profile = await proxy.userProfiles(user2.address);

            expect(liked).to.be.true;
            expect(likeCount).to.equal(1);
            expect(profile.totalXP).to.equal(1); // 1 XP for like
        });

        it("Should add comment and award XP", async function () {
            // Create NFT
            const tx1 = await proxy.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            // Get initial XP
            let profile = await proxy.userProfiles(user2.address);
            const initialXP = profile.totalXP;

            // Add comment
            const tx2 = await proxy.connect(user2).addComment(0, "Great artwork!");
            await tx2.wait();

            // Verify XP increased (2 points for comment)
            profile = await proxy.userProfiles(user2.address);
            expect(profile.totalXP).to.be.greaterThan(initialXP);
        });

        it("Should handle offers correctly", async function () {
            // Create and list NFT
            const tx1 = await proxy.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            const tx2 = await proxy.connect(user1).listTokenForSale(0, ethers.parseEther("2"), "");
            await tx2.wait();

            // Make offer
            const tx3 = await proxy.connect(user2).makeOffer(0, 7, {
                value: ethers.parseEther("1.5")
            });
            await tx3.wait();

            // Accept offer
            const tx4 = await proxy.connect(user1).acceptOffer(0, 0);
            await tx4.wait();

            // Verify ownership transfer
            const owner = await proxy.ownerOf(0);
            expect(owner).to.equal(user2.address);
        });
    });

    // ==================== PROXY-SPECIFIC TESTS ====================
    describe("UUPS Proxy Functionality", function () {
        it("Should initialize through proxy", async function () {
            // Verify initialization worked
            const platformTreasury = await proxy.platformTreasury();
            expect(platformTreasury).to.equal(deployer.address);
        });

        it("Should allow authorized upgrade", async function () {
            // Deploy new implementation
            const GameifiedMarketplaceCoreV1 = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
            const newImplementation = await GameifiedMarketplaceCoreV1.deploy();
            await newImplementation.waitForDeployment();
            const newImplementationAddress = await newImplementation.getAddress();

            // Get current implementation
            const proxyAddress = await proxy.getAddress();
            
            // Upgrade
            const tx = await proxy.upgradeTo(newImplementationAddress);
            await tx.wait();

            // Verify proxy still works with new implementation
            const profile = await proxy.userProfiles(deployer.address);
            expect(profile).to.not.be.undefined;
        });

        it("Should preserve state across upgrades", async function () {
            // Create some state
            const tx1 = await proxy.connect(user1).createStandardNFT(
                "https://example.com/nft1.json",
                "ART",
                500
            );
            await tx1.wait();

            const profileBefore = await proxy.userProfiles(user1.address);

            // Upgrade
            const GameifiedMarketplaceCoreV1 = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
            const newImplementation = await GameifiedMarketplaceCoreV1.deploy();
            await newImplementation.waitForDeployment();

            const tx2 = await proxy.upgradeTo(await newImplementation.getAddress());
            await tx2.wait();

            // Verify state preserved
            const profileAfter = await proxy.userProfiles(user1.address);
            expect(profileAfter.nftsCreated).to.equal(profileBefore.nftsCreated);
            expect(profileAfter.totalXP).to.equal(profileBefore.totalXP);
        });

        it("Should prevent unauthorized upgrade", async function () {
            // Deploy new implementation
            const GameifiedMarketplaceCoreV1 = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
            const newImplementation = await GameifiedMarketplaceCoreV1.deploy();
            await newImplementation.waitForDeployment();

            // Try to upgrade as non-authorized user
            await expect(
                proxy.connect(user1).upgradeTo(await newImplementation.getAddress())
            ).to.be.reverted;
        });
    });
});
