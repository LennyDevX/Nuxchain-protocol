const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Airdrop Extended Features", function () {
    let airdrop;
    let owner, user1, user2, otherUsers;
    const tokenAmount = ethers.parseEther("0.1"); // 0.1 MATIC
    const maxParticipants = 1000;

    beforeEach(async function () {
        [owner, user1, user2, ...otherUsers] = await ethers.getSigners();

        // Deploy airdrop with maxParticipants
        const Airdrop = await ethers.getContractFactory("Airdrop");
        airdrop = await Airdrop.deploy(maxParticipants);
        await airdrop.waitForDeployment();

        // Get latest block timestamp
        const latestBlock = await ethers.provider.getBlock('latest');
        const currentTimestamp = latestBlock.timestamp;

        // Configure initial airdrop parameters with correct arguments
        await airdrop.configureAirdrop(
            0, // AirdropType.MATIC
            ethers.ZeroAddress, // No token address needed for MATIC
            tokenAmount,
            currentTimestamp + 60,
            currentTimestamp + 3600,
            "Test MATIC Airdrop"
        );
    });

    describe("Balance Management", function () {
        it("Should correctly report contract balance", async function () {
            const fundAmount = tokenAmount * BigInt(100);
            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: fundAmount
            });
            expect(await airdrop.getContractBalance()).to.equal(fundAmount);
        });

        it("Should verify sufficient funds correctly", async function () {
            expect(await airdrop.hasSufficientFunds()).to.equal(false);

            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: tokenAmount * BigInt(maxParticipants)
            });
            expect(await airdrop.hasSufficientFunds()).to.equal(true);
        });

        it("Should allow owner to fund airdrop", async function () {
            const fundAmount = ethers.parseEther("0.1");
            await expect(airdrop.fundContract({ value: fundAmount }))
                .to.emit(airdrop, "FundsReceived")
                .withArgs(owner.address, fundAmount);
        });

        it("Should revert funding with zero amount", async function () {
            await expect(airdrop.fundContract({ value: 0 }))
                .to.be.revertedWithCustomError(airdrop, "InvalidAmount");
        });
    });

    describe("Security Limits", function () {
        beforeEach(async function () {
            // Fund the contract
            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: tokenAmount * BigInt(100)
            });
        });

        it("Should enforce max participants limit", async function () {
            // Ensure contract has enough funds
            expect(await airdrop.hasSufficientFunds()).to.equal(true);

            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");

            // Set max participants to a small number for testing
            await airdrop.setMaxParticipants(2);

            // Claim tokens using claim() instead of claimTokens()
            await airdrop.connect(otherUsers[0]).claim();
            await airdrop.connect(otherUsers[1]).claim();

            // Attempt to exceed the max participants
            await expect(airdrop.connect(otherUsers[2]).claim())
                .to.be.revertedWithCustomError(airdrop, "TransferLimitExceeded");
        });

        it("Should enforce batch claim size limit", async function () {
            const users = Array(101).fill(user1.address);
            await expect(airdrop.batchClaim(users))
                .to.be.revertedWith("Batch too large");
        });
    });

    describe("Monitoring and Statistics", function () {
        beforeEach(async function () {
            // Fund the contract
            const fundAmount = tokenAmount * BigInt(10);
            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: fundAmount
            });
        });

        it("Should return correct airdrop stats", async function () {
            // Move time forward to start the airdrop
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");

            const info = await airdrop.getAirdropInfo();
            const stats = await airdrop.getAirdropStats();
            const fundAmount = tokenAmount * BigInt(10);

            expect(await airdrop.getContractBalance()).to.equal(fundAmount);
            expect(stats.remainingTokens).to.equal(fundAmount);
            expect(stats.claimedCount).to.equal(0);
            expect(stats.isAirdropActive).to.equal(true); // Now should be true since we moved time forward
            expect(stats.isFunded).to.equal(true);
            expect(stats.remainingTime).to.be.gt(0);
        });

        it("Should check user eligibility correctly", async function () {
            const eligibility = await airdrop.checkUserEligibility(user1.address);
            expect(eligibility.isEligible_).to.equal(true);
            expect(eligibility.hasClaimed_).to.equal(false);
        });
    });

    describe("Emergency Functions", function () {
        it("Should allow emergency withdrawal when paused", async function () {
            const withdrawAmount = ethers.parseEther("0.1");
            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: withdrawAmount
            });

            await airdrop.pause();

            // Call emergencyWithdraw with address(0) for MATIC withdrawal
            await expect(airdrop.emergencyWithdraw(ethers.ZeroAddress))
                .to.emit(airdrop, "EmergencyWithdrawal")
                .withArgs(ethers.ZeroAddress, withdrawAmount);

            // Verify contract balance is zero
            const contractBalance = await ethers.provider.getBalance(await airdrop.getAddress());
            expect(contractBalance).to.equal(0);
        });

        it("Should recover different tokens sent by mistake", async function () {
            // Deploy another token to test recovery
            const OtherToken = await ethers.getContractFactory("ERC20TokenMock");
            const otherToken = await OtherToken.deploy("Other", "OTH", ethers.parseEther("1000000"));
            await otherToken.waitForDeployment();

            const withdrawAmount = tokenAmount;
            await otherToken.transfer(await airdrop.getAddress(), withdrawAmount);
            await airdrop.pause();

            const tx = await airdrop.emergencyWithdraw(otherToken.target);

            await expect(tx)
                .to.emit(airdrop, "EmergencyWithdrawal")
                .withArgs(otherToken.target, withdrawAmount);
        });
    });

    describe("Validation Checks", function () {
        it("Should prevent claims when insufficient funds", async function () {
            await ethers.provider.send("evm_increaseTime", [61]);
            await expect(airdrop.connect(user1).claim())
                .to.be.revertedWithCustomError(airdrop, "InsufficientContractBalance");
        });

        it("Should track total participants correctly", async function () {
            // Fund contract first with sufficient tokens
            const fundAmount = tokenAmount * BigInt(10);
            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: fundAmount
            });

            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");

            // Claim tokens
            await airdrop.connect(user1).claim();

            // Verify stats
            const stats = await airdrop.getAirdropStats();
            expect(stats.claimedCount).to.equal(1);
        });

        it("Should validate minimum balance requirement", async function () {
            // Create a new wallet with minimal balance
            const emptyWallet = ethers.Wallet.createRandom().connect(ethers.provider);

            // Fund the wallet with less than MIN_CONTRACT_BALANCE (e.g., 0.5 Ether)
            await owner.sendTransaction({
                to: emptyWallet.address,
                value: ethers.parseEther("0.5")
            });

            const minBalance = await airdrop.MIN_BALANCE();

            // Initial check - should be false
            const initialEligibility = await airdrop.checkUserEligibility(emptyWallet.address);
            expect(initialEligibility.hasMinBalance_).to.equal(false);

            // Transfer additional funds to reach MIN_CONTRACT_BALANCE
            const requiredAdditionalFunds = minBalance - (await ethers.provider.getBalance(emptyWallet.address));
            await owner.sendTransaction({
                to: emptyWallet.address,
                value: requiredAdditionalFunds
            });

            // Check eligibility after funding
            const finalEligibility = await airdrop.checkUserEligibility(emptyWallet.address);
            expect(finalEligibility.hasMinBalance_).to.equal(true);
            expect(await ethers.provider.getBalance(emptyWallet.address)).to.be.gte(minBalance);
        });

        it("Should not allow user to claim tokens twice", async function () {
            // Fund the contract first
            const fundAmount = tokenAmount * BigInt(10);
            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: fundAmount
            });

            // Advance time to start the airdrop
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");

            // First claim should succeed
            await airdrop.connect(user1).claim();

            // Second claim should fail
            await expect(airdrop.connect(user1).claim())
                .to.be.revertedWithCustomError(airdrop, "AlreadyClaimed");
        });

        it("Should not allow claims before start date", async function () {
            // Get current airdrop config
            const currentTime = Math.floor(Date.now() / 1000);
            await airdrop.configureAirdrop(
                0, // AirdropType.MATIC
                ethers.ZeroAddress,
                tokenAmount,
                currentTime + 3600, // Start in 1 hour
                currentTime + 7200, // End in 2 hours
                "Test Airdrop"
            );

            await expect(airdrop.connect(user1).claim())
                .to.be.revertedWithCustomError(airdrop, "AirdropInactive");
        });

        it("Should not allow claims after end date", async function () {
            // Get latest block timestamp
            const latestBlock = await ethers.provider.getBlock('latest');
            const currentTimestamp = latestBlock.timestamp;

            await airdrop.configureAirdrop(
                0, // AirdropType.MATIC
                ethers.ZeroAddress,
                tokenAmount,
                currentTimestamp + 60,  // Start in 1 minute
                currentTimestamp + 120, // End in 2 minutes
                "Test Airdrop"
            );

            // Move time to after end date
            await ethers.provider.send("evm_increaseTime", [180]); // 3 minutes
            await ethers.provider.send("evm_mine");

            await expect(airdrop.connect(user1).claim())
                .to.be.revertedWithCustomError(airdrop, "AirdropInactive");
        });
    });

    describe("Gas Optimizations", function () {
        it("Should maintain gas efficiency for batch operations", async function () {
            // Setup batch claims with different sizes
            const smallBatch = Array(5).fill(otherUsers[0].address);
            const mediumBatch = Array(25).fill(otherUsers[0].address);
            const largeBatch = Array(50).fill(otherUsers[0].address);

            // Fund contract
            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: tokenAmount * BigInt(100)
            });

            // Move time forward to start the airdrop
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");

            // Measure gas usage for different batch sizes
            const smallBatchTx = await airdrop.batchClaim(smallBatch);
            const mediumBatchTx = await airdrop.batchClaim(mediumBatch);
            const largeBatchTx = await airdrop.batchClaim(largeBatch);

            const smallReceipt = await smallBatchTx.wait();
            const mediumReceipt = await mediumBatchTx.wait();
            const largeReceipt = await largeBatchTx.wait();

            // Calculate average gas per operation
            const gasPerClaimSmall = Number(smallReceipt.gasUsed) / smallBatch.length;
            const gasPerClaimMedium = Number(mediumReceipt.gasUsed) / mediumBatch.length;
            const gasPerClaimLarge = Number(largeReceipt.gasUsed) / largeBatch.length;

            // Calculate percentage differences
            const mediumDiffPercent = Math.abs((gasPerClaimMedium - gasPerClaimSmall) / gasPerClaimSmall * 100);
            const largeDiffPercent = Math.abs((gasPerClaimLarge - gasPerClaimSmall) / gasPerClaimSmall * 100);

            // Allow for up to 50% variation in gas usage per claim
            // This accounts for initialization costs and other fixed overheads
            expect(mediumDiffPercent).to.be.lessThan(50);
            expect(largeDiffPercent).to.be.lessThan(50);

            // Log gas usage for transparency
            console.log(`Gas per claim (small batch): ${Math.floor(gasPerClaimSmall)}`);
            console.log(`Gas per claim (medium batch): ${Math.floor(gasPerClaimMedium)}`);
            console.log(`Gas per claim (large batch): ${Math.floor(gasPerClaimLarge)}`);
        });
    });

    describe("Event Testing", function () {
        it("Should emit correct events", async function () {
            const fundAmount = tokenAmount * BigInt(10);
            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: fundAmount
            });

            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");

            // Test TokensClaimed event
            await expect(airdrop.connect(user1).claim())
                .to.emit(airdrop, "TokensClaimed")
                .withArgs(user1.address, tokenAmount);

            // Test AirdropConfigured event
            const block = await ethers.provider.getBlock('latest');
            const startDate = block.timestamp + 60;
            const endDate = startDate + 3600;

            await expect(airdrop.configureAirdrop(
                0,
                ethers.ZeroAddress,
                tokenAmount,
                startDate,
                endDate,
                "New Config"
            )).to.emit(airdrop, "AirdropConfigured")
              .withArgs(0, ethers.ZeroAddress, tokenAmount, "New Config");

            // Test EmergencyWithdrawal event
            await airdrop.pause();
            await expect(airdrop.emergencyWithdraw(ethers.ZeroAddress))
                .to.emit(airdrop, "EmergencyWithdrawal")
                .withArgs(ethers.ZeroAddress, await airdrop.getContractBalance());
        });
    });

    describe("Token Type Variations", function () {
        let mockERC20;
        let mockNFT;

        beforeEach(async function () {
            // Deploy mock tokens
            const MockERC20 = await ethers.getContractFactory("MockERC20");
            mockERC20 = await MockERC20.deploy("Mock", "MCK", ethers.parseEther("1000000"));
            await mockERC20.waitForDeployment();

            const MockNFT = await ethers.getContractFactory("MockNFT");
            mockNFT = await MockNFT.deploy();
            await mockNFT.waitForDeployment();
        });

        it("Should handle ERC20 claims correctly", async function () {
            const amount = ethers.parseEther("100");
            await mockERC20.transfer(await airdrop.getAddress(), amount);

            const block = await ethers.provider.getBlock('latest');
            await airdrop.configureAirdrop(
                1, // ERC20
                await mockERC20.getAddress(),
                amount,
                block.timestamp + 60,
                block.timestamp + 3600,
                "ERC20 Airdrop"
            );

            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");

            const balanceBefore = await mockERC20.balanceOf(user1.address);
            await airdrop.connect(user1).claim();
            const balanceAfter = await mockERC20.balanceOf(user1.address);

            expect(balanceAfter - balanceBefore).to.equal(amount);
        });

        it("Should handle NFT claims correctly", async function () {
            // Mint and approve NFTs
            await mockNFT.mint(owner.address, 1);
            await mockNFT.approve(await airdrop.getAddress(), 1);

            const block = await ethers.provider.getBlock('latest');
            await airdrop.configureAirdrop(
                2, // NFT
                await mockNFT.getAddress(),
                1, // tokenId
                block.timestamp + 60,
                block.timestamp + 3600,
                "NFT Airdrop"
            );

            await airdrop.depositNFTs([1]);

            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");

            await airdrop.connect(user1).claim();
            expect(await mockNFT.ownerOf(1)).to.equal(user1.address);
        });
    });

    describe("Edge Cases", function () {
        beforeEach(async function () {
            // Move time forward to start the airdrop
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");
        });

        it("Should handle zero token amount gracefully", async function () {
            await expect(airdrop.fundContract({ value: 0 }))
                .to.be.revertedWithCustomError(airdrop, "InvalidAmount");
        });

        it("Should prevent claims with insufficient contract balance", async function () {
            await ethers.provider.send("evm_increaseTime", [61]);
            await expect(airdrop.connect(user1).claim())
                .to.be.revertedWithCustomError(airdrop, "InsufficientContractBalance");
        });

        it("Should handle maximum participants correctly", async function () {
            // Fund contract
            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: tokenAmount * BigInt(10)
            });

            // Set max participants to 1
            await airdrop.setMaxParticipants(1);

            // First claim should succeed
            await airdrop.connect(user1).claim();

            // Second claim should fail due to max participants
            await expect(airdrop.connect(user2).claim())
                .to.be.revertedWithCustomError(airdrop, "TransferLimitExceeded");
        });
    });
});
