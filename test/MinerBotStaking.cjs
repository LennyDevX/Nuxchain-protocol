const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("MinerBotStaking", function () {
  // Fixture para desplegar todos los contratos
  async function deployMinerBotStakingFixture() {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // Deploy token contract
    const MinerBotToken = await ethers.getContractFactory("MinerBotToken");
    const token = await MinerBotToken.deploy(
      owner.address, // gameRewardsWallet
      owner.address, // teamWallet
      owner.address, // marketingWallet
      owner.address, // treasuryWallet
      owner.address, // airdropWallet
      owner.address  // advisorWallet
    );

    // Deploy staking contract
    const MinerBotStaking = await ethers.getContractFactory("MinerBotStaking");
    const staking = await MinerBotStaking.deploy(await token.getAddress());

    // Authorize staking contract to mint rewards
    await token.authorizeGameContract(await staking.getAddress(), true);

    // Transfer tokens to users for testing
    const transferAmount = ethers.parseEther("100000");
    await token.transfer(addr1.address, transferAmount);
    await token.transfer(addr2.address, transferAmount);
    await token.transfer(addr3.address, transferAmount);

    return { staking, token, owner, addr1, addr2, addr3 };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { staking, owner } = await loadFixture(deployMinerBotStakingFixture);
      expect(await staking.owner()).to.equal(owner.address);
    });

    it("Should set correct token address", async function () {
      const { staking, token } = await loadFixture(deployMinerBotStakingFixture);
      expect(await staking.minerBotToken()).to.equal(await token.getAddress());
    });

    it("Should initialize staking pools correctly", async function () {
      const { staking } = await loadFixture(deployMinerBotStakingFixture);
      
      // Check 30-day pool
      const pool0 = await staking.stakingPools(0);
      expect(pool0.duration).to.equal(30 * 24 * 3600); // 30 days
      expect(pool0.apy).to.equal(1000); // 10%
      expect(pool0.minStake).to.equal(ethers.parseEther("100"));
      expect(pool0.maxStake).to.equal(ethers.parseEther("10000"));
      expect(pool0.isActive).to.be.true;
      
      // Check 365-day pool
      const pool3 = await staking.stakingPools(3);
      expect(pool3.duration).to.equal(365 * 24 * 3600); // 365 days
      expect(pool3.apy).to.equal(2500); // 25%
      expect(pool3.minStake).to.equal(ethers.parseEther("1000"));
      expect(pool3.maxStake).to.equal(ethers.parseEther("100000"));
      expect(pool3.isActive).to.be.true;
    });

    it("Should have correct initial values", async function () {
      const { staking } = await loadFixture(deployMinerBotStakingFixture);
      
      expect(await staking.earlyWithdrawalPenalty()).to.equal(1000); // 10%
      expect(await staking.nextStakeId()).to.equal(1);
      expect(await staking.maxActionsPerDay()).to.equal(10);
      expect(await staking.suspiciousThreshold()).to.equal(20);
    });
  });

  describe("Staking", function () {
    it("Should stake tokens successfully", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0; // 30-day pool
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      
      await expect(staking.connect(addr1).stake(poolId, amount))
        .to.emit(staking, "Staked")
        .withArgs(1, addr1.address, poolId, amount);
      
      const stakeInfo = await staking.stakes(1);
      expect(stakeInfo.user).to.equal(addr1.address);
      expect(stakeInfo.poolId).to.equal(poolId);
      expect(stakeInfo.amount).to.equal(amount);
      expect(stakeInfo.isActive).to.be.true;
      
      // Check pool stats
      const poolStats = await staking.poolStats(poolId);
      expect(poolStats.totalStaked).to.equal(amount);
      expect(poolStats.totalStakers).to.equal(1);
    });

    it("Should fail to stake below minimum amount", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("50"); // Below minimum of 100
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      
      await expect(
        staking.connect(addr1).stake(poolId, amount)
      ).to.be.revertedWith("Amount below minimum");
    });

    it("Should fail to stake above maximum amount", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("15000"); // Above maximum of 10000
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      
      await expect(
        staking.connect(addr1).stake(poolId, amount)
      ).to.be.revertedWith("Amount above maximum");
    });

    it("Should fail to stake in inactive pool", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      // Deactivate pool
      await staking.togglePoolStatus(0);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      
      await expect(
        staking.connect(addr1).stake(poolId, amount)
      ).to.be.revertedWith("Pool not active");
    });

    it("Should handle multiple stakes from same user", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount1 = ethers.parseEther("1000");
      const amount2 = ethers.parseEther("2000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount1 + amount2);
      
      // First stake
      await staking.connect(addr1).stake(poolId, amount1);
      
      // Second stake
      await staking.connect(addr1).stake(poolId, amount2);
      
      expect(await staking.nextStakeId()).to.equal(3);
      
      const poolStats = await staking.poolStats(poolId);
      expect(poolStats.totalStaked).to.equal(amount1 + amount2);
      expect(poolStats.totalStakers).to.equal(2); // Two separate stakes
    });
  });

  describe("Reward Calculation", function () {
    it("Should calculate rewards correctly", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0; // 10% APY
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      await staking.connect(addr1).stake(poolId, amount);
      
      // Fast forward 30 days (full duration)
      await time.increase(30 * 24 * 3600);
      
      const stakeId = 1;
      const calculatedReward = await staking.calculateRewards(addr1.address, stakeId);
      
      // Expected reward: 1000 * 0.10 * (30/365) ≈ 8.22 tokens
      const expectedReward = amount * 1000n / 10000n * 30n / 365n;
      expect(calculatedReward).to.be.closeTo(expectedReward, ethers.parseEther("1"));
    });

    it("Should apply loyalty bonus correctly", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 1; // 90-day pool
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      await staking.connect(addr1).stake(poolId, amount);
      
      // Fast forward 90 days (full duration)
      await time.increase(90 * 24 * 3600);
      
      const stakeId = 1;
      const calculatedReward = await staking.calculateRewards(addr1.address, stakeId);
      
      // Should include loyalty bonus for completing full duration
      expect(calculatedReward).to.be.greaterThan(0);
    });

    it("Should calculate partial rewards correctly", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0; // 30-day pool
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      await staking.connect(addr1).stake(poolId, amount);
      
      // Fast forward 15 days (half duration)
      await time.increase(15 * 24 * 3600);
      
      const stakeId = 1;
      const calculatedReward = await staking.calculateRewards(addr1.address, stakeId);
      
      // Should be approximately half of full reward
      const expectedReward = amount * 1000n / 10000n * 15n / 365n;
      expect(calculatedReward).to.be.closeTo(expectedReward, ethers.parseEther("0.5"));
    });
  });

  describe("Claiming Rewards", function () {
    it("Should claim rewards successfully after full duration", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      await staking.connect(addr1).stake(poolId, amount);
      
      // Fast forward full duration
      await time.increase(30 * 24 * 3600);
      
      const initialBalance = await token.balanceOf(addr1.address);
      const stakeId = 1;
      
      await expect(staking.connect(addr1).claimReward(stakeId))
        .to.emit(staking, "RewardClaimed");
      
      const finalBalance = await token.balanceOf(addr1.address);
      expect(finalBalance).to.be.greaterThan(initialBalance);
      
      // Stake should be marked as inactive
      const stakeInfo = await staking.stakes(stakeId);
      expect(stakeInfo.isActive).to.be.false;
    });

    it("Should allow early withdrawal with penalty", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      await staking.connect(addr1).stake(poolId, amount);
      
      // Fast forward only 15 days (half duration)
      await time.increase(15 * 24 * 3600);
      
      const initialBalance = await token.balanceOf(addr1.address);
      const stakeId = 1;
      
      await expect(staking.connect(addr1).claimReward(stakeId))
        .to.emit(staking, "EarlyWithdrawal");
      
      const finalBalance = await token.balanceOf(addr1.address);
      
      // Should receive less than full amount due to penalty
      const received = finalBalance - initialBalance;
      expect(received).to.be.lessThan(amount);
    });

    it("Should fail to claim reward twice", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      await staking.connect(addr1).stake(poolId, amount);
      
      await time.increase(30 * 24 * 3600);
      
      const stakeId = 1;
      
      // First claim should succeed
      await staking.connect(addr1).claimReward(stakeId);
      
      // Second claim should fail
      await expect(
        staking.connect(addr1).claimReward(stakeId)
      ).to.be.revertedWith("Stake not active");
    });

    it("Should fail to claim reward from different user", async function () {
      const { staking, token, addr1, addr2 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      await staking.connect(addr1).stake(poolId, amount);
      
      await time.increase(30 * 24 * 3600);
      
      await expect(
        staking.connect(addr2).claimReward(1)
      ).to.be.revertedWith("Not stake owner");
    });
  });

  describe("Anti-Fraud Measures", function () {
    it("Should track user actions", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount * 3n);
      
      // Perform multiple actions
      await staking.connect(addr1).stake(poolId, amount);
      await staking.connect(addr1).stake(poolId, amount);
      await staking.connect(addr1).stake(poolId, amount);
      
      const userActivity = await staking.userActivity(addr1.address);
      expect(userActivity.actionsToday).to.equal(3);
    });

    it("Should prevent excessive actions per day", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount * 15n);
      
      // Perform maximum allowed actions
      for (let i = 0; i < 10; i++) {
        await staking.connect(addr1).stake(poolId, amount);
      }
      
      // 11th action should fail
      await expect(
        staking.connect(addr1).stake(poolId, amount)
      ).to.be.revertedWith("Too many actions today");
    });

    it("Should detect and flag suspicious activity", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount * 30n);
      
      // Perform actions at maximum rate for multiple days
      for (let day = 0; day < 3; day++) {
        for (let i = 0; i < 10; i++) {
          await staking.connect(addr1).stake(poolId, amount);
        }
        // Advance to next day
        await time.increase(24 * 3600);
      }
      
      const userActivity = await staking.userActivity(addr1.address);
      expect(userActivity.suspiciousScore).to.be.greaterThan(0);
    });

    it("Should ban user for suspicious activity", async function () {
      const { staking, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      await expect(staking.banUser(addr1.address, "Suspicious activity"))
        .to.emit(staking, "UserBanned")
        .withArgs(addr1.address, "Suspicious activity");
      
      expect(await staking.bannedUsers(addr1.address)).to.be.true;
    });

    it("Should prevent banned users from staking", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      // Ban user
      await staking.banUser(addr1.address, "Test ban");
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      
      await expect(
        staking.connect(addr1).stake(poolId, amount)
      ).to.be.revertedWith("User is banned");
    });
  });

  describe("Emergency Functions", function () {
    it("Should allow emergency withdrawal", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      await staking.connect(addr1).stake(poolId, amount);
      
      const stakeId = 1;
      const initialBalance = await token.balanceOf(addr1.address);
      
      // Emergency withdrawal has 5% penalty (emergencyWithdrawalFee = 50/1000 = 5%)
      const expectedWithdrawAmount = amount * 95n / 100n; // 95% of original amount
      
      await expect(staking.connect(addr1).emergencyWithdraw(stakeId))
        .to.emit(staking, "EmergencyWithdrawal")
        .withArgs(stakeId, addr1.address, expectedWithdrawAmount);
      
      const finalBalance = await token.balanceOf(addr1.address);
      expect(finalBalance).to.equal(initialBalance + expectedWithdrawAmount);
      
      // Stake should be marked as inactive
      const stakeInfo = await staking.stakes(stakeId);
      expect(stakeInfo.isActive).to.be.false;
    });

    it("Should fail emergency withdrawal for non-owner", async function () {
      const { staking, token, addr1, addr2 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      await staking.connect(addr1).stake(poolId, amount);
      
      await expect(
        staking.connect(addr2).emergencyWithdraw(1)
      ).to.be.revertedWith("Not stake owner");
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to toggle pool status", async function () {
      const { staking } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const initialStatus = (await staking.stakingPools(poolId)).isActive;
      
      await staking.togglePoolStatus(poolId);
      
      const newStatus = (await staking.stakingPools(poolId)).isActive;
      expect(newStatus).to.equal(!initialStatus);
    });

    it("Should allow owner to update pool parameters", async function () {
      const { staking } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const newAPY = 1500; // 15%
      const newMinStake = ethers.parseEther("200");
      const newMaxStake = ethers.parseEther("20000");
      
      await staking.updatePoolAPY(poolId, newAPY);
      await staking.updatePoolLimits(poolId, newMinStake, newMaxStake);
      
      const pool = await staking.stakingPools(poolId);
      expect(pool.apy).to.equal(newAPY);
      expect(pool.minStake).to.equal(newMinStake);
      expect(pool.maxStake).to.equal(newMaxStake);
    });

    it("Should allow owner to update anti-fraud parameters", async function () {
      const { staking } = await loadFixture(deployMinerBotStakingFixture);
      
      const newMaxActions = 15;
      const newThreshold = 30;
      const newPenalty = 1500; // 15%
      
      await staking.setMaxActionsPerDay(newMaxActions);
      await staking.setSuspiciousThreshold(newThreshold);
      await staking.setEarlyWithdrawalPenalty(newPenalty);
      
      expect(await staking.maxActionsPerDay()).to.equal(newMaxActions);
      expect(await staking.suspiciousThreshold()).to.equal(newThreshold);
      expect(await staking.earlyWithdrawalPenalty()).to.equal(newPenalty);
    });

    it("Should prevent non-owner from admin functions", async function () {
      const { staking, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      await expect(
        staking.connect(addr1).togglePoolStatus(0)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      
      await expect(
        staking.connect(addr1).updatePoolAPY(0, 1500)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow pausing and unpausing", async function () {
      const { staking } = await loadFixture(deployMinerBotStakingFixture);
      
      await expect(staking.pause())
        .to.emit(staking, "Paused");
      
      expect(await staking.paused()).to.be.true;
      
      await expect(staking.unpause())
        .to.emit(staking, "Unpaused");
      
      expect(await staking.paused()).to.be.false;
    });
  });

  describe("Edge Cases and Gas Optimization", function () {
    it("Should handle zero amount staking", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = 0;
      
      await expect(
        staking.connect(addr1).stake(poolId, amount)
      ).to.be.revertedWith("Amount must be greater than 0");
    });

    it("Should handle invalid pool ID", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 999; // Non-existent pool
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount);
      
      await expect(
        staking.connect(addr1).stake(poolId, amount)
      ).to.be.reverted;
    });

    it("Should handle large number of stakes efficiently", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      const numStakes = 5;
      
      await token.connect(addr1).approve(await staking.getAddress(), amount * BigInt(numStakes));
      
      // Create multiple stakes
      for (let i = 0; i < numStakes; i++) {
        await staking.connect(addr1).stake(poolId, amount);
      }
      
      expect(await staking.nextStakeId()).to.equal(numStakes + 1);
      
      const poolStats = await staking.poolStats(poolId);
      expect(poolStats.totalStaked).to.equal(amount * BigInt(numStakes));
      expect(poolStats.totalStakers).to.equal(numStakes);
    });

    it("Should reset daily actions counter", async function () {
      const { staking, token, addr1 } = await loadFixture(deployMinerBotStakingFixture);
      
      const poolId = 0;
      const amount = ethers.parseEther("1000");
      
      await token.connect(addr1).approve(await staking.getAddress(), amount * 15n);
      
      // Perform maximum actions
      for (let i = 0; i < 10; i++) {
        await staking.connect(addr1).stake(poolId, amount);
      }
      
      // Advance to next day
      await time.increase(24 * 3600);
      
      // Should be able to perform actions again
      await expect(staking.connect(addr1).stake(poolId, amount))
        .to.not.be.reverted;
      
      const userActivity = await staking.userActivity(addr1.address);
      expect(userActivity.actionsToday).to.equal(1);
    });
  });
});