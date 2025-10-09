const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Airdrop Contract", function () {
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

        // Configure initial airdrop parameters
        await airdrop.configureAirdrop(
            0, // AirdropType.MATIC
            ethers.ZeroAddress, // No token address needed for MATIC
            tokenAmount,
            currentTimestamp + 60,
            currentTimestamp + 3600,
            "Test MATIC Airdrop"
        );

        // Fund the contract with initial amount
        await owner.sendTransaction({
            to: await airdrop.getAddress(),
            value: tokenAmount * BigInt(10)
        });
    });

    describe("Deployment", function () {
        it("Should set the correct owner", async function () {
            expect(await airdrop.owner()).to.equal(owner.address);
        });

        it("Should have received the correct MATIC amount", async function () {
            const balance = await ethers.provider.getBalance(await airdrop.getAddress());
            expect(balance).to.equal(tokenAmount * BigInt(10));
        });
    });

    // Update claim tests to use new claim() function instead of claimTokens()
    describe("Claim Functions", function () {
        beforeEach(async function () {
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");
        });

        it("Should allow eligible users to claim tokens", async function () {
            const balanceBefore = await ethers.provider.getBalance(user1.address);
            await airdrop.connect(user1).claim();
            const balanceAfter = await ethers.provider.getBalance(user1.address);
            expect(balanceAfter > balanceBefore).to.be.true;
        });

        it("Should prevent double claims", async function () {
            await airdrop.connect(user1).claim();
            await expect(airdrop.connect(user1).claim())
                .to.be.revertedWithCustomError(airdrop, "AlreadyClaimed");
        });
    });

    describe("Airdrop Configuration", function () {
        it("Should allow owner to configure airdrop", async function () {
            const block = await ethers.provider.getBlock('latest');
            const newStartDate = block.timestamp + 120;
            const newEndDate = newStartDate + 3600;
            
            await expect(
                airdrop.configureAirdrop(
                    0, // MATIC
                    ethers.ZeroAddress,
                    tokenAmount,
                    newStartDate,
                    newEndDate,
                    "New MATIC Airdrop"
                )
            ).to.emit(airdrop, "AirdropConfigured");
        });

        it("Should store airdrop info correctly", async function () {
            const info = await airdrop.getAirdropInfo();
            expect(info.airdropType).to.equal(0); // MATIC
            expect(info.tokenAddress).to.equal(ethers.ZeroAddress);
            expect(info.tokenAmount).to.equal(tokenAmount);
            expect(info.description).to.equal("Test MATIC Airdrop");
        });

        it("Should not allow non-owner to configure airdrop", async function () {
            await expect(
                airdrop.connect(user1).configureAirdrop(0, ethers.ZeroAddress, 0, 0, 0, "")
            ).to.be.revertedWithCustomError(airdrop, "CallerNotOwner");
        });

        it("Should revert if start date is after end date", async function () {
            const currentTime = Math.floor(Date.now() / 1000);
            await expect(
                airdrop.configureAirdrop(0, ethers.ZeroAddress, tokenAmount, currentTime + 3600, currentTime + 60, "")
            ).to.be.revertedWithCustomError(airdrop, "InvalidDates");
        });

        it("Should revert if start date is in the past", async function () {
            const currentTime = Math.floor(Date.now() / 1000);
            await expect(
                airdrop.configureAirdrop(0, ethers.ZeroAddress, tokenAmount, currentTime - 60, currentTime + 3600, "")
            ).to.be.revertedWithCustomError(airdrop, "StartDateMustBeFuture");
        });
    });

    describe("Eligibility Check", function () {
        it("Should return true for EOA accounts", async function () {
            expect(await airdrop.isEligible(user1.address)).to.equal(true);
        });

        it("Should return false for contract accounts", async function () {
            // Deploy a dummy contract to test
            const DummyContract = await ethers.getContractFactory("contracts/mocks/DummyContract.sol:DummyContract");
            const dummy = await DummyContract.deploy();
            await dummy.waitForDeployment();
            expect(await airdrop.isEligible(dummy.getAddress())).to.equal(false);
        });
    });

    describe("Claim Tokens", function () {
        beforeEach(async function () {
            // Move time forward to start the airdrop
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");
        });

        it("Should allow eligible user to claim tokens", async function () {
            const balanceBefore = await ethers.provider.getBalance(user1.address);
            await airdrop.connect(user1).claim();
            const balanceAfter = await ethers.provider.getBalance(user1.address);
            
            // Account for gas costs in the comparison
            expect(balanceAfter > balanceBefore).to.be.true;
            expect(await airdrop.hasClaimed(user1.address)).to.equal(true);
        });

        it("Should not allow user to claim tokens twice", async function () {
            await airdrop.connect(user1).claim();
            await expect(airdrop.connect(user1).claim()).to.be.revertedWithCustomError(airdrop, "AlreadyClaimed");
        });

        it("Should not allow claims before start date", async function () {
            const currentTime = Math.floor(Date.now() / 1000);
            await airdrop.configureAirdrop(0, ethers.ZeroAddress, tokenAmount, currentTime + 3600, currentTime + 7200, "");
            await expect(airdrop.connect(user1).claim()).to.be.revertedWithCustomError(airdrop, "AirdropInactive");
        });

        it("Should not allow claims after end date", async function () {
            // Move time forward to end the airdrop
            await ethers.provider.send("evm_increaseTime", [3601]);
            await ethers.provider.send("evm_mine");
            await expect(airdrop.connect(user1).claim()).to.be.revertedWithCustomError(airdrop, "AirdropInactive");
        });

        it("Should not allow contracts to claim tokens", async function () {
            // Deploy a dummy contract to test
            const DummyContract = await ethers.getContractFactory("contracts/mocks/DummyContract.sol:DummyContract");
            const dummy = await DummyContract.deploy();
            await dummy.waitForDeployment();

            // Have an EOA call the function in DummyContract that calls the Airdrop's claim function
            await expect(dummy.connect(user1).attemptClaim(await airdrop.getAddress()))
                .to.be.revertedWithCustomError(airdrop, "NotEligible");
        });
    });

    describe("Recover Unclaimed Tokens", function () {
        beforeEach(async function () {
            await ethers.provider.send("evm_increaseTime", [3601]);
            await ethers.provider.send("evm_mine");
        });

        it("Should allow owner to recover unclaimed tokens after end date", async function () {
            const contractBalanceBefore = await ethers.provider.getBalance(await airdrop.getAddress());
            const ownerBalanceBefore = await ethers.provider.getBalance(owner);

            await airdrop.pause();
            const tx = await airdrop.emergencyWithdraw(ethers.ZeroAddress);
            const receipt = await tx.wait();
            
            const gasUsed = receipt.gasUsed * receipt.gasPrice;
            const contractBalanceAfter = await ethers.provider.getBalance(await airdrop.getAddress());
            const ownerBalanceAfter = await ethers.provider.getBalance(owner);

            expect(contractBalanceAfter).to.equal(0);
            expect(ownerBalanceAfter + gasUsed).to.be.closeTo(
                ownerBalanceBefore + contractBalanceBefore,
                ethers.parseEther("0.0001")
            );
        });

        it("Should not allow recovery before end date", async function () {
            const block = await ethers.provider.getBlock('latest');
            const startDate = block.timestamp + 60;
            const endDate = startDate + 3600;
            
            await airdrop.configureAirdrop(
                0,
                ethers.ZeroAddress,
                tokenAmount,
                startDate,
                endDate,
                "Test MATIC Airdrop"
            );

            // Move time forward but not past end date
            await ethers.provider.send("evm_increaseTime", [61]); // Just after start
            await ethers.provider.send("evm_mine");

            await airdrop.pause();
            await expect(airdrop.emergencyWithdraw(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(airdrop, "AirdropActive");
        });

        it("Should not allow non-owner to recover unclaimed tokens", async function () {
            await airdrop.pause();
            await expect(airdrop.connect(user1).emergencyWithdraw(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(airdrop, "CallerNotOwner");
        });
    });

    describe("Batch Claim", function () {
        beforeEach(async function () {
            // Move time forward to start the airdrop
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");
        });

        it("Should allow owner to perform batch claims", async function () {
            const users = [user1.address, user2.address, otherUsers[0].address];
            const balancesBefore = await Promise.all(
                users.map(user => ethers.provider.getBalance(user))
            );

            await airdrop.batchClaim(users);

            const balancesAfter = await Promise.all(
                users.map(user => ethers.provider.getBalance(user))
            );

            for (let i = 0; i < users.length; i++) {
                expect(balancesAfter[i]).to.be.gt(balancesBefore[i]);
            }
        });

        it("Should not allow non-owner to perform batch claims", async function () {
            const users = [user1.address, user2.address];
            await expect(airdrop.connect(user1).batchClaim(users))
                .to.be.revertedWithCustomError(airdrop, "CallerNotOwner");
        });

        it("Should not process already claimed addresses", async function () {
            // Get initial balances for user2 only since we only need to verify their claim
            const user2InitialBalance = await ethers.provider.getBalance(user2.address);

            // User1 claims tokens first
            await airdrop.connect(user1).claim();

            // Try batch claim for both users
            const users = [user1.address, user2.address];
            await airdrop.batchClaim(users);

            // Get final balance for user2
            const user2FinalBalance = await ethers.provider.getBalance(user2.address);

            // User2's balance should increase by tokenAmount
            expect(user2FinalBalance).to.be.gt(user2InitialBalance);
            expect(user2FinalBalance - user2InitialBalance).to.equal(tokenAmount);

            // Verify both users are marked as claimed
            expect(await airdrop.hasClaimed(user1.address)).to.be.true;
            expect(await airdrop.hasClaimed(user2.address)).to.be.true;
        });
    });

    describe("Pause Functionality", function () {
        it("Should allow owner to pause and unpause the contract", async function () {
            await airdrop.pause();
            expect(await airdrop.paused()).to.equal(true);

            await airdrop.unpause();
            expect(await airdrop.paused()).to.equal(false);
        });

        it("Should not allow non-owner to pause or unpause", async function () {
            await expect(airdrop.connect(user1).pause()).to.be.revertedWithCustomError(airdrop, "CallerNotOwner");
            await airdrop.pause();
            await expect(airdrop.connect(user1).unpause()).to.be.revertedWithCustomError(airdrop, "CallerNotOwner");
        });

        it("Should prevent claiming tokens when paused", async function () {
            // Get the latest block
            const block = await ethers.provider.getBlock('latest');
            const startDate = block.timestamp + 60;
            const endDate = startDate + 3600;
            
            await airdrop.configureAirdrop(0, ethers.ZeroAddress, tokenAmount, startDate, endDate, "");

            // Advance time
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");

            await airdrop.pause();
            await expect(airdrop.connect(user1).claim())
                .to.be.revertedWith("Pausable: paused");
        });
    });

    describe("Reentrancy Protection", function () {
        it("Should prevent reentrancy attacks on claim", async function () {
            // Deploy malicious contract that tries to reenter
            const MaliciousContract = await ethers.getContractFactory("contracts/mocks/MaliciousAirdropAttacker.sol:MaliciousAirdropAttacker");
            const attacker = await MaliciousContract.deploy(airdrop.getAddress());
            await attacker.waitForDeployment();

            // Move time forward to start the airdrop
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");

            await expect(attacker.attack()).to.be.revertedWithCustomError(airdrop, "NotEligible");
        });
    });

    describe("Contract Protection", function () {
        beforeEach(async function () {
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");
        });

        it("Should not allow contracts to claim tokens", async function () {
            const DummyContract = await ethers.getContractFactory("contracts/mocks/DummyContract.sol:DummyContract");
            const dummy = await DummyContract.deploy();
            await dummy.waitForDeployment();

            await expect(dummy.connect(user1).attemptClaim(await airdrop.getAddress()))
                .to.be.revertedWithCustomError(airdrop, "NotEligible");
        });

        it("Should prevent reentrancy attacks using ReentrancyGuard", async function () {
            const MaliciousContract = await ethers.getContractFactory("contracts/mocks/MaliciousAirdropAttacker.sol:MaliciousAirdropAttacker");
            const attacker = await MaliciousContract.deploy(await airdrop.getAddress());
            await attacker.waitForDeployment();

            // Whitelist the attacker contract
            await airdrop.whitelistContract(await attacker.getAddress(), true);

            // Make sure contract has enough balance for multiple claims
            await owner.sendTransaction({
                to: await airdrop.getAddress(),
                value: tokenAmount * BigInt(10)
            });

            // Fund attacker to pay for gas
            await owner.sendTransaction({
                to: await attacker.getAddress(),
                value: ethers.parseEther("1")
            });

            // Attempt reentrancy attack - use revertedWith instead of revertedWithCustomError
            await expect(attacker.attack())
                .to.be.revertedWith("ReentrancyGuard: reentrant call");
        });
    });
});
