const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("TreasuryManager", function () {
    
    // Treasury Type enum
    const TreasuryType = {
        REWARDS: 0,
        STAKING: 1,
        COLLABORATORS: 2,
        DEVELOPMENT: 3,
        MARKETPLACE: 4
    };
    
    const DISTRIBUTION_INTERVAL = 7 * 24 * 60 * 60; // 7 days
    const DEFAULT_RESERVE_PERCENTAGE = 2000; // 20%
    
    async function deployTreasuryFixture() {
        const [owner, rewards, staking, collaborators, development, marketplace, user1, user2] = 
            await ethers.getSigners();
        
        const TreasuryManager = await ethers.getContractFactory("TreasuryManager");
        const treasury = await TreasuryManager.deploy();
        await treasury.deploymentTransaction().wait();
        
        // Set treasury addresses
        await treasury.setTreasury(TreasuryType.REWARDS, rewards.address);
        await treasury.setTreasury(TreasuryType.STAKING, staking.address);
        await treasury.setTreasury(TreasuryType.COLLABORATORS, collaborators.address);
        await treasury.setTreasury(TreasuryType.DEVELOPMENT, development.address);
        await treasury.setTreasury(TreasuryType.MARKETPLACE, marketplace.address);
        
        return {
            treasury,
            owner,
            rewards,
            staking,
            collaborators,
            development,
            marketplace,
            user1,
            user2
        };
    }
    
    async function deployTreasuryWithFunds() {
        const contracts = await deployTreasuryFixture();
        
        // Fund the treasury
        await contracts.owner.sendTransaction({
            to: await contracts.treasury.getAddress(),
            value: ethers.parseEther("100")
        });
        
        return contracts;
    }
    
    describe("Deployment & Initialization", function () {
        
        it("Should deploy successfully", async function () {
            const { treasury } = await loadFixture(deployTreasuryFixture);
            expect(await treasury.getAddress()).to.be.properAddress;
        });
        
        it("Should set treasury addresses correctly", async function () {
            const { treasury, rewards, staking } = await loadFixture(deployTreasuryFixture);
            
            expect(await treasury.treasuries(TreasuryType.REWARDS)).to.equal(rewards.address);
            expect(await treasury.treasuries(TreasuryType.STAKING)).to.equal(staking.address);
        });
        
        it("Should initialize with correct reserve percentage", async function () {
            const { treasury } = await loadFixture(deployTreasuryFixture);
            expect(await treasury.reserveAllocationPercentage()).to.equal(DEFAULT_RESERVE_PERCENTAGE);
        });
        
        it("Should initialize with emergency mode disabled", async function () {
            const { treasury } = await loadFixture(deployTreasuryFixture);
            expect(await treasury.emergencyModeEnabled()).to.be.false;
        });
    });
    
    describe("Receive & Funding", function () {
        
        it("Should receive ETH and update total revenue", async function () {
            const { treasury, owner } = await loadFixture(deployTreasuryFixture);
            
            const depositAmount = ethers.parseEther("10");
            await owner.sendTransaction({
                to: await treasury.getAddress(),
                value: depositAmount
            });
            
            expect(await treasury.totalRevenueReceived()).to.equal(depositAmount);
        });
        
        it("Should emit RevenueReceived event", async function () {
            const { treasury, owner } = await loadFixture(deployTreasuryFixture);
            
            const depositAmount = ethers.parseEther("5");
            const treasuryAddr = await treasury.getAddress();
            
            await expect(
                owner.sendTransaction({
                    to: treasuryAddr,
                    value: depositAmount
                })
            ).to.emit(treasury, "RevenueReceived");
        });
        
        it("Should set firstDepositTime on first deposit", async function () {
            const { treasury, owner } = await loadFixture(deployTreasuryFixture);
            
            await owner.sendTransaction({
                to: await treasury.getAddress(),
                value: ethers.parseEther("1")
            });
            
            const firstDepositTime = await treasury.firstDepositTime();
            expect(firstDepositTime).to.be.gt(0);
        });
        
        it("Should set nextDistrib utionTime 7 days after first deposit", async function () {
            const { treasury, owner } = await loadFixture(deployTreasuryFixture);
            
            const depositTime = await time.latest();
            
            await owner.sendTransaction({
                to: await treasury.getAddress(),
                value: ethers.parseEther("10")
            });
            
            const nextDistTime = await treasury.nextDistributionTime();
            expect(nextDistTime).to.be.gte(depositTime + DISTRIBUTION_INTERVAL);
        });
    });
    
    describe("Distribution Timeline", function () {
        
        it("Should not allow distribution before 7 days", async function () {
            const { treasury } = await loadFixture(deployTreasuryWithFunds);
            
            // Try to distribute immediately
            await expect(treasury.triggerDistribution())
                .to.be.revertedWith("Distribution not ready");
        });
        
        it("isDistributionReady should return false initially", async function () {
            const { treasury } = await loadFixture(deployTreasuryWithFunds);
            
            const [ready] = await treasury.isDistributionReady();
            expect(ready).to.be.false;
        });
        
        it("Should allow distribution after 7 days", async function () {
            const { treasury } = await loadFixture(deployTreasuryWithFunds);
            
            // Fast forward 7 days
            await time.increase(DISTRIBUTION_INTERVAL);
            
            await expect(treasury.triggerDistribution()).to.not.be.reverted;
        });
        
        it("isDistributionReady should return true after 7 days", async function () {
            const { treasury } = await loadFixture(deployTreasuryWithFunds);
            
            await time.increase(DISTRIBUTION_INTERVAL);
            
            const [ready] = await treasury.isDistributionReady();
            expect(ready).to.be.true;
        });
        
        it("Should update nextDistributionTime after distribution", async function () {
            const { treasury } = await loadFixture(deployTreasuryWithFunds);
            
            await time.increase(DISTRIBUTION_INTERVAL);
            const firstNext = await treasury.nextDistributionTime();
            
            await treasury.triggerDistribution();
            
            const secondNext = await treasury.nextDistributionTime();
            // Allow for 1-2 second difference due to block timestamp advancement
            expect(secondNext).to.be.closeTo(firstNext + BigInt(DISTRIBUTION_INTERVAL), 2);
        });

        it("Should continue distribution when one treasury rejects ETH", async function () {
            const [owner, rewards, staking, collaborators, development, marketplace] = await ethers.getSigners();

            const TreasuryManager = await ethers.getContractFactory("TreasuryManager");
            const treasury = await TreasuryManager.deploy();
            await treasury.deploymentTransaction().wait();

            const MockQuestLeveling = await ethers.getContractFactory("MockQuestLeveling");
            const rejectingTreasury = await MockQuestLeveling.deploy();
            await rejectingTreasury.waitForDeployment();

            await treasury.setTreasury(TreasuryType.REWARDS, rewards.address);
            await treasury.setTreasury(TreasuryType.STAKING, staking.address);
            await treasury.setTreasury(TreasuryType.COLLABORATORS, await rejectingTreasury.getAddress());
            await treasury.setTreasury(TreasuryType.DEVELOPMENT, development.address);
            await treasury.setTreasury(TreasuryType.MARKETPLACE, marketplace.address);

            await owner.sendTransaction({
                to: await treasury.getAddress(),
                value: ethers.parseEther("100")
            });

            const rewardsBefore = await ethers.provider.getBalance(rewards.address);
            const stakingBefore = await ethers.provider.getBalance(staking.address);
            const developmentBefore = await ethers.provider.getBalance(development.address);

            await time.increase(DISTRIBUTION_INTERVAL);

            await expect(treasury.triggerDistribution())
                .to.emit(treasury, "RevenueDistributionFailed")
                .withArgs(TreasuryType.COLLABORATORS, await rejectingTreasury.getAddress(), ethers.parseEther("16"));

            expect(await ethers.provider.getBalance(rewards.address)).to.equal(rewardsBefore + ethers.parseEther("24"));
            expect(await ethers.provider.getBalance(staking.address)).to.equal(stakingBefore + ethers.parseEther("28"));
            expect(await ethers.provider.getBalance(development.address)).to.equal(developmentBefore + ethers.parseEther("12"));
            expect(await treasury.totalDistributed()).to.equal(ethers.parseEther("64"));
            expect(await treasury.protocolDeficit(TreasuryType.COLLABORATORS)).to.equal(ethers.parseEther("16"));
            expect(await ethers.provider.getBalance(await treasury.getAddress())).to.equal(ethers.parseEther("36"));
        });
        
        it("getDistributionTimeline should return correct values", async function () {
            const { treasury } = await loadFixture(deployTreasuryWithFunds);
            
            const timeline = await treasury.getDistributionTimeline();
            
            expect(timeline.firstDeposit).to.be.gt(0);
            expect(timeline.nextDistribution).to.be.gt(0);
            expect(timeline.isReady).to.be.false;
        });
    });
    
    describe("Reserve Fund", function () {
        
        it("Should allocate 20% to reserve on distribution", async function () {
            const { treasury } = await loadFixture(deployTreasuryWithFunds);
            
            const depositAmount = ethers.parseEther("100");
            const expectedReserve = depositAmount * BigInt(DEFAULT_RESERVE_PERCENTAGE) / BigInt(10000);
            
            await time.increase(DISTRIBUTION_INTERVAL);
            await treasury.triggerDistribution();
            
            const reserveBalance = await treasury.reserveFundBalance();
            expect(reserveBalance).to.equal(expectedReserve);
        });
        
        it("Should allow owner to update reserve percentage", async function () {
            const { treasury } = await loadFixture(deployTreasuryFixture);
            
            const newPercentage = 2500; // 25%
            await treasury.setReserveAllocation(newPercentage);
            
            expect(await treasury.reserveAllocationPercentage()).to.equal(newPercentage);
        });
        
        it("Should allow owner to withdraw from reserve", async function () {
            const { treasury, user1 } = await loadFixture(deployTreasuryWithFunds);
            
            await time.increase(DISTRIBUTION_INTERVAL);
            await treasury.triggerDistribution();
            
            const reserveBalance = await treasury.reserveFundBalance();
            const withdrawAmount = reserveBalance / BigInt(2);
            
            const beforeBalance = await ethers.provider.getBalance(user1.address);
            
            await treasury.withdrawFromReserve(user1.address, withdrawAmount, "Test withdrawal");
            
            const afterBalance = await ethers.provider.getBalance(user1.address);
            expect(afterBalance - beforeBalance).to.equal(withdrawAmount);
        });
        
        it("Should emit ReserveWithdrawn event", async function () {
            const { treasury, user1 } = await loadFixture(deployTreasuryWithFunds);
            
            await time.increase(DISTRIBUTION_INTERVAL);
            await treasury.triggerDistribution();
            
            const withdrawAmount = ethers.parseEther("1");
            
            await expect(treasury.withdrawFromReserve(user1.address, withdrawAmount, "Test"))
                .to.emit(treasury, "ReserveFundWithdrawal");
        });
        
        it("getReserveStats should return correct values", async function () {
            const { treasury } = await loadFixture(deployTreasuryWithFunds);
            
            await time.increase(DISTRIBUTION_INTERVAL);
            await treasury.triggerDistribution();
            
            const stats = await treasury.getReserveStats();
            
            expect(stats.currentBalance).to.be.gt(0);
            expect(stats.totalAccumulated).to.be.gt(0);
            expect(stats.allocationPercentage).to.equal(DEFAULT_RESERVE_PERCENTAGE);
            expect(stats.isEnabled).to.be.true;
        });
    });
    
    describe("Emergency System", function () {
        
        it("Should allow owner to declare emergency", async function () {
            const { treasury } = await loadFixture(deployTreasuryFixture);
            
            await treasury.declareEmergency("Test emergency");
            
            expect(await treasury.emergencyModeEnabled()).to.be.true;
        });
        
        it("Should emit EmergencyModeActivated event", async function () {
            const { treasury } = await loadFixture(deployTreasuryFixture);
            
            await expect(treasury.declareEmergency("Protocol issue"))
                .to.emit(treasury, "EmergencyModeActivated");
        });
        
        it("Should allow owner to end emergency", async function () {
            const { treasury } = await loadFixture(deployTreasuryFixture);
            
            await treasury.declareEmergency("Test");
            await treasury.endEmergency();
            
            expect(await treasury.emergencyModeEnabled()).to.be.false;
        });
        
        it("Should emit EmergencyModeDeactivated event", async function () {
            const { treasury } = await loadFixture(deployTreasuryFixture);
            
            await treasury.declareEmergency("Test");
            
            await expect(treasury.endEmergency())
                .to.emit(treasury, "EmergencyModeDeactivated");
        });
        
        it("Should allow emergency fund requests when emergency active", async function () {
            const { treasury, rewards, owner } = await loadFixture(deployTreasuryWithFunds);
            
            // Distribute to build reserve
            await time.increase(DISTRIBUTION_INTERVAL);
            await treasury.triggerDistribution();
            
            // Authorize rewards contract
            await treasury.setAuthorizedRequester(rewards.address, true);
            
            // Declare emergency
            await treasury.declareEmergency("Protocol instability");
            
            const requestAmount = ethers.parseEther("1");
            
            await expect(
                treasury.connect(rewards).requestEmergencyFunds(TreasuryType.REWARDS, requestAmount)
            ).to.not.be.reverted;
        });
        
        it("Should revert emergency request when emergency not active", async function () {
            const { treasury, rewards } = await loadFixture(deployTreasuryWithFunds);
            
            await treasury.setAuthorizedRequester(rewards.address, true);
            
            await expect(
                treasury.connect(rewards).requestEmergencyFunds(TreasuryType.REWARDS, ethers.parseEther("1"))
            ).to.be.revertedWith("Emergency mode not active");
        });
        
        it("getEmergencyInfo should return correct state", async function () {
            const { treasury } = await loadFixture(deployTreasuryFixture);
            
            await treasury.declareEmergency("Test");
            
            const info = await treasury.getEmergencyInfo();
            
            expect(info.isActive).to.be.true;
            expect(info.timestamp).to.be.gt(0);
        });
    });
    
    describe("Authorization", function () {
        
        it("Should allow owner to authorize requesters", async function () {
            const { treasury, user1 } = await loadFixture(deployTreasuryFixture);
            
            await treasury.setAuthorizedRequester(user1.address, true);
            expect(await treasury.authorizedRequester(user1.address)).to.be.true;
        });
        
        it("Should allow owner to revoke authorization", async function () {
            const { treasury, user1 } = await loadFixture(deployTreasuryFixture);
            
            await treasury.setAuthorizedRequester(user1.address, true);
            await treasury.setAuthorizedRequester(user1.address, false);
            
            expect(await treasury.authorizedRequester(user1.address)).to.be.false;
        });
        
        it("Should revert if unauthorized caller requests funds", async function () {
            const { treasury, user1 } = await loadFixture(deployTreasuryWithFunds);
            
            await expect(
                treasury.connect(user1).requestRewardFunds(ethers.parseEther("1"))
            ).to.be.revertedWith("Not authorized requester");
        });
    });
    
    describe("View Functions", function () {
        
        it("getStats should return correct values", async function () {
            const { treasury } = await loadFixture(deployTreasuryWithFunds);
            
            const stats = await treasury.getStats();
            
            expect(stats.totalReceived).to.equal(ethers.parseEther("100"));
            expect(stats.totalDist).to.equal(0); // Not distributed yet
            expect(stats.currentBalance).to.be.gt(0);
        });
        
        it("getAllAllocations should return all treasury allocations", async function () {
            const { treasury } = await loadFixture(deployTreasuryFixture);
            
            const allocs = await treasury.getAllAllocations();
            
            // Should return 5 values (one for each treasury type)
            expect(allocs.rewardsAlloc).to.be.gte(0);
            expect(allocs.stakingAlloc).to.be.gte(0);
            expect(allocs.collaboratorsAlloc).to.be.gte(0);
        });
        
        it("getTreasuryConfig should return address and allocation", async function () {
            const { treasury, rewards } = await loadFixture(deployTreasuryFixture);
            
            const config = await treasury.getTreasuryConfig(TreasuryType.REWARDS);
            
            expect(config.treasuryAddress).to.equal(rewards.address);
            expect(config.allocation).to.be.gte(0);
        });
        
        it("getBalance should return contract balance", async function () {
            const { treasury } = await loadFixture(deployTreasuryWithFunds);
            
            const balance = await treasury.getBalance();
            expect(balance).to.equal(ethers.parseEther("100"));
        });
    });
    
    describe("Integration Tests", function () {
        
        it("Should handle full lifecycle: deposit -> distribute -> emergency -> recovery", async function () {
            const { treasury, rewards } = await loadFixture(deployTreasuryWithFunds);
            
            // 1. Distribute
            await time.increase(DISTRIBUTION_INTERVAL);
            await treasury.triggerDistribution();
            
            const reserveAfterDist = await treasury.reserveFundBalance();
            expect(reserveAfterDist).to.be.gt(0);
            
            // 2. Emergency
            await treasury.declareEmergency("Protocol issue");
            await treasury.setAuthorizedRequester(rewards.address, true);
            
            await treasury.connect(rewards).requestEmergencyFunds(
                TreasuryType.REWARDS,
                ethers.parseEther("1")
            );
            
            // 3. Recovery
            await treasury.endEmergency();
            
            expect(await treasury.emergencyModeEnabled()).to.be.false;
        });
        
        it("Should handle multiple distributions over time", async function () {
            const { treasury, owner } = await loadFixture(deployTreasuryFixture);
            
            // First cycle
            await owner.sendTransaction({
                to: await treasury.getAddress(),
                value: ethers.parseEther("50")
            });
            
            await time.increase(DISTRIBUTION_INTERVAL);
            await treasury.triggerDistribution();
            
            // Second cycle
            await owner.sendTransaction({
                to: await treasury.getAddress(),
                value: ethers.parseEther("50")
            });
            
            await time.increase(DISTRIBUTION_INTERVAL);
            await treasury.triggerDistribution();
            
            const totalDistributed = await treasury.totalDistributed();
            expect(totalDistributed).to.be.gt(0);
        });
    });
});


