const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

/**
 * @title CollaboratorBadgeRewards V2 - Test Suite
 * @notice Comprehensive tests for PHASE 1 & 2 improvements
 */

describe("CollaboratorBadgeRewards V2 - Production Tests", function () {
    let collaboratorRewards;
    let treasuryManager;
    let owner, admin, user1, user2, treasury;

    beforeEach(async function () {
        this.timeout(60000); // 60 seconds for deployments
        [owner, admin, user1, user2, treasury] = await ethers.getSigners();

        // Deploy mock TreasuryManager
        try {
            const TreasuryManager = await ethers.getContractFactory("TreasuryManager");
            treasuryManager = await TreasuryManager.deploy();
            await treasuryManager.waitForDeployment();
            // console.log("TreasuryManager deployed at:", treasuryManager.target || treasuryManager.address);
        } catch (e) {
            console.error("TreasuryManager deployment failed:", e.message);
            throw e;
        }

        // Authorize self
        try {
            const address = treasuryManager.target || treasuryManager.address;
            await treasuryManager.setAuthorizedSource(owner.address, true);
            // console.log("Authorized owner in TreasuryManager");
        } catch (e) {
            console.error("Failed to authorize owner:", e.message);
            throw e;
        }

        // Deploy CollaboratorBadgeRewards
        try {
            const CollaboratorBadgeRewards = await ethers.getContractFactory("CollaboratorBadgeRewards");
            collaboratorRewards = await upgrades.deployProxy(
                CollaboratorBadgeRewards,
                [],
                { initializer: 'initialize', kind: 'uups' }
            );
            await collaboratorRewards.waitForDeployment();
            // console.log("CollaboratorBadgeRewards deployed at:", collaboratorRewards.target || collaboratorRewards.address);
        } catch (e) {
            console.error("CollaboratorBadgeRewards deployment failed:", e.message);
            throw e;
        }

        // Basic setup
        try {
            const treasuryAddr = treasuryManager.target || treasuryManager.address;
            // console.log("Setting Treasury Manager:", treasuryAddr);
            await collaboratorRewards.setTreasuryManager(treasuryAddr);
            // console.log("Treasury Manager set");
        } catch (e) {
            console.error("Failed to set TreasuryManager:", e.message);
            throw e;
        }

        try {
            const cbAddr = collaboratorRewards.target || collaboratorRewards.address;
            // console.log("Authorizing CollaboratorBadgeRewards:", cbAddr);
            await treasuryManager.setAuthorizedSource(cbAddr, true);
            // console.log("Authorized CollaboratorBadgeRewards");
        } catch (e) {
            console.error("Failed to authorize CollaboratorBadgeRewards:", e.message);
            throw e;
        }

        try {
            await collaboratorRewards.setQuestAdmin(admin.address, true);
            // console.log("Set quest admin");
        } catch (e) {
            console.error("Failed to set quest admin:", e.message);
            throw e;
        }

        // Fund contract
        try {
            const cbAddr = collaboratorRewards.target || collaboratorRewards.address;
            await owner.sendTransaction({
                to: cbAddr,
                value: ethers.parseEther("1000")
            });
            // console.log("Funded contract with 1000 ETH");
        } catch (e) {
            console.error("Failed to fund contract:", e.message);
            throw e;
        }
    });

    // ═══════════════════════════════════════════════════════════════════════════════
    // PHASE 1 TESTS: Security Critical
    // ═══════════════════════════════════════════════════════════════════════════════

    describe("PHASE 1: Security Critical", function () {
        
        it("Should prevent address(0) in completeQuestForUser", async function () {
            const questId = await createQuest();
            
            await expect(
                collaboratorRewards.connect(admin).completeQuestForUser(
                    ethers.ZeroAddress,
                    questId
                )
            ).to.be.revertedWithCustomError(collaboratorRewards, "InvalidAddress");
        });

        it("Should enforce MAX_BATCH_SIZE limit", async function () {
            const questId = await createQuest();
            const users = Array(101).fill(user1.address);

            await expect(
                collaboratorRewards.connect(admin).batchCompleteQuest(users, questId)
            ).to.be.revertedWithCustomError(collaboratorRewards, "InvalidBatchSize");
        });

        it("Should validate quest existence (startTime > 0)", async function () {
            const nonExistentQuestId = 999;

            await expect(
                collaboratorRewards.connect(admin).completeQuestForUser(user1.address, nonExistentQuestId)
            ).to.be.revertedWithCustomError(collaboratorRewards, "QuestNotFound");
        });

        it("Should enforce maxRewardLimit in createQuest", async function () {
            const excessiveReward = ethers.parseEther("501");
            const startTime = Math.floor(Date.now() / 1000) + 3600;
            const endTime = startTime + 86400;

            await expect(
                collaboratorRewards.connect(admin).createQuest(
                    "Excessive Quest",
                    excessiveReward,
                    startTime,
                    endTime,
                    0
                )
            ).to.be.revertedWithCustomError(collaboratorRewards, "ExceedsMaxReward");
        });

        it("Should track totalPendingRewards correctly", async function () {
            const questId = await createQuest(ethers.parseEther("10"));
            
            const initialPending = await collaboratorRewards.totalPendingRewards();
            expect(initialPending).to.equal(0);

            await collaboratorRewards.connect(admin).completeQuestForUser(user1.address, questId);
            
            const afterCompletion = await collaboratorRewards.totalPendingRewards();
            expect(afterCompletion).to.equal(ethers.parseEther("10"));

            // Claim rewards
            await collaboratorRewards.connect(user1).claimRewards();

            const afterClaim = await collaboratorRewards.totalPendingRewards();
            expect(afterClaim).to.equal(0);
        });

        it("Should enforce maxPendingRewardsPerUser", async function () {
            // Set low limit for testing
            await collaboratorRewards.setMaxPendingRewardsPerUser(ethers.parseEther("50"));

            const questId1 = await createQuest(ethers.parseEther("30"));
            const questId2 = await createQuest(ethers.parseEther("30"));

            await collaboratorRewards.connect(admin).completeQuestForUser(user1.address, questId1);
            
            await expect(
                collaboratorRewards.connect(admin).completeQuestForUser(user1.address, questId2)
            ).to.be.revertedWithCustomError(collaboratorRewards, "ExceedsMaxPendingRewards");
        });
    });

    // ═══════════════════════════════════════════════════════════════════════════════
    // PHASE 2 TESTS: Stability & Revenue
    // ═══════════════════════════════════════════════════════════════════════════════

    describe("PHASE 2: Stability & Revenue", function () {

        it("Should enforce strict timestamp validation in createQuest", async function () {
            const pastTime = Math.floor(Date.now() / 1000) - 3600;
            const futureTime = Math.floor(Date.now() / 1000) + 3600;

            await expect(
                collaboratorRewards.connect(admin).createQuest(
                    "Past Quest",
                    ethers.parseEther("10"),
                    pastTime,
                    futureTime,
                    0
                )
            ).to.be.revertedWithCustomError(collaboratorRewards, "InvalidTimestamp");
        });

        it("Should enforce MAX_QUEST_DURATION", async function () {
            const startTime = Math.floor(Date.now() / 1000) + 3600;
            const endTime = startTime + (366 * 24 * 60 * 60); // 366 days

            await expect(
                collaboratorRewards.connect(admin).createQuest(
                    "Too Long Quest",
                    ethers.parseEther("10"),
                    startTime,
                    endTime,
                    0
                )
            ).to.be.revertedWithCustomError(collaboratorRewards, "QuestDurationTooLong");
        });

        it("Should track userContributionVolume", async function () {
            const questId1 = await createQuest(ethers.parseEther("10"));
            const questId2 = await createQuest(ethers.parseEther("20"));

            await collaboratorRewards.connect(admin).completeQuestForUser(user1.address, questId1);
            await collaboratorRewards.connect(admin).completeQuestForUser(user1.address, questId2);

            const volume = await collaboratorRewards.getUserContributionVolume(user1.address);
            expect(volume).to.equal(ethers.parseEther("30"));
        });

        it("Should calculate tiered commission correctly", async function () {
            // Complete quests to build volume
            const questId1 = await createQuest(ethers.parseEther("5"));
            const questId2 = await createQuest(ethers.parseEther("10"));
            const questId3 = await createQuest(ethers.parseEther("40"));

            // Tier 1: 0-10 POL → 2% (200 BPS)
            await collaboratorRewards.connect(admin).completeQuestForUser(user1.address, questId1);
            let feeRate = await collaboratorRewards.getClaimFeeForUser(user1.address);
            expect(feeRate).to.equal(200);

            // Tier 2: 10-50 POL → 1.5% (150 BPS)
            await collaboratorRewards.connect(admin).completeQuestForUser(user1.address, questId2);
            feeRate = await collaboratorRewards.getClaimFeeForUser(user1.address);
            expect(feeRate).to.equal(150);

            // Tier 3: 50+ POL → 1% (100 BPS)
            await collaboratorRewards.connect(admin).completeQuestForUser(user1.address, questId3);
            feeRate = await collaboratorRewards.getClaimFeeForUser(user1.address);
            expect(feeRate).to.equal(100);
        });

        it("Should apply tiered fee in claimRewards", async function () {
            // Build volume to Tier 3
            const quest1 = await createQuest(ethers.parseEther("60"));
            await collaboratorRewards.connect(admin).completeQuestForUser(user1.address, quest1);

            const grossAmount = await collaboratorRewards.pendingRewards(user1.address);
            const feeRate = await collaboratorRewards.getClaimFeeForUser(user1.address);
            
            // Verify fee rate is Tier 3 (1% = 100 BPS)
            expect(feeRate).to.equal(100);

            // Verify gross amount is 60 ETH
            expect(grossAmount).to.equal(ethers.parseEther("60"));

            const balanceBefore = await ethers.provider.getBalance(user1.address);
            const tx = await collaboratorRewards.connect(user1).claimRewards();
            const receipt = await tx.wait();
            
            const balanceAfter = await ethers.provider.getBalance(user1.address);

            // User should have received rewards minus gas and fee
            expect(balanceAfter).to.be.gt(balanceBefore);
            
            // Pending rewards should be 0 after claiming
            const pendingAfter = await collaboratorRewards.pendingRewards(user1.address);
            expect(pendingAfter).to.equal(0);
        });

        it("Should allow admin to set custom commission tiers", async function () {
            await collaboratorRewards.setCommissionTier(
                ethers.parseEther("200"),
                25  // 0.25%
            );

            const tiers = await collaboratorRewards.getAllCommissionTiers();
            
            // Should have at least 4 tiers (3 default + 1 new)
            expect(tiers.thresholds.length).to.be.gte(4);
        });

        it("Should update claimFeePercent correctly", async function () {
            const oldFee = await collaboratorRewards.claimFeePercent();
            
            await expect(
                collaboratorRewards.setClaimFeePercent(300)  // 3%
            ).to.emit(collaboratorRewards, "ClaimFeeUpdated")
              .withArgs(oldFee, 300);

            const newFee = await collaboratorRewards.claimFeePercent();
            expect(newFee).to.equal(300);
        });

        it("Should reject excessive fee rates", async function () {
            await expect(
                collaboratorRewards.setClaimFeePercent(1001)  // 10.01%
            ).to.be.revertedWith("Fee too high");
        });
    });

    // ═══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    describe("View Functions", function () {

        it("Should return correct contract health", async function () {
            const questId = await createQuest(ethers.parseEther("100"));
            await collaboratorRewards.connect(admin).completeQuestForUser(user1.address, questId);

            const health = await collaboratorRewards.getContractHealth();
            
            expect(health.isHealthy).to.be.true;
            expect(health.solvencyRatio).to.be.gt(10000); // > 100%
            expect(health.deficit).to.equal(0);
        });

        it("Should detect insolvency", async function () {
            // Create debt without funding
            const largeDeploy = await upgrades.deployProxy(
                await ethers.getContractFactory("CollaboratorBadgeRewards"),
                [],
                { initializer: 'initialize', kind: 'uups' }
            );
            await largeDeploy.setQuestAdmin(admin.address, true);

            const questId = await createQuestOn(largeDeploy, ethers.parseEther("100"));
            await largeDeploy.connect(admin).completeQuestForUser(user1.address, questId);

            const health = await largeDeploy.getContractHealth();
            
            expect(health.isHealthy).to.be.false;
            expect(health.solvencyRatio).to.equal(0);
            expect(health.deficit).to.equal(ethers.parseEther("100"));
        });

        it("Should return all commission tiers", async function () {
            const tiers = await collaboratorRewards.getAllCommissionTiers();
            
            expect(tiers.thresholds.length).to.equal(tiers.rates.length);
            expect(tiers.thresholds.length).to.be.gte(3); // At least 3 default tiers
        });

        it("Should return user contribution volume", async function () {
            const questId = await createQuest(ethers.parseEther("25"));
            await collaboratorRewards.connect(admin).completeQuestForUser(user1.address, questId);

            const volume = await collaboratorRewards.getUserContributionVolume(user1.address);
            expect(volume).to.equal(ethers.parseEther("25"));
        });
    });

    // ═══════════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    async function createQuest(rewardAmount) {
        if (!rewardAmount) {
            rewardAmount = ethers.parseEther("10");
        }
        return createQuestOn(collaboratorRewards, rewardAmount);
    }

    async function createQuestOn(contract, rewardAmount) {
        const blockNum = await ethers.provider.getBlockNumber();
        const block = await ethers.provider.getBlock(blockNum);
        const now = block.timestamp;
        
        const startTime = now + 1; // Start in 1 second (will be past by completion)
        const endTime = now + (365 * 24 * 60 * 60); // Expires in 1 year

        const tx = await contract.connect(admin).createQuest(
            "Test Quest",
            rewardAmount,
            startTime,
            endTime,
            0  // unlimited completions
        );

        const receipt = await tx.wait();
        
        // In ethers v6, we need to parse events differently
        const iface = contract.interface;
        let questId = null;
        
        for (const log of receipt.logs) {
            try {
                const parsed = iface.parseLog(log);
                if (parsed && parsed.name === "QuestCreated") {
                    questId = parsed.args.questId;
                    break;
                }
            } catch (e) {
                // Continue to next log
            }
        }
        
        if (questId === null) {
            throw new Error("QuestCreated event not found in transaction receipt");
        }
        
        return questId;
    }
});
