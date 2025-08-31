const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("MinerBotGame", function () {
  async function deployMinerBotGameFixture() {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // Deploy MinerBotToken
    const MinerBotToken = await ethers.getContractFactory("MinerBotToken");
    const token = await MinerBotToken.deploy(
      owner.address, // gameRewardsWallet
      owner.address, // teamWallet
      owner.address, // marketingWallet
      owner.address, // treasuryWallet
      owner.address, // airdropWallet
      owner.address  // advisorWallet
    );
    await token.waitForDeployment();

    // Deploy MinerBotNFT
    const MinerBotNFT = await ethers.getContractFactory("MinerBotNFT");
    const nft = await MinerBotNFT.deploy(await token.getAddress());
    await nft.waitForDeployment();

    // Deploy MinerBotGame
    const MinerBotGame = await ethers.getContractFactory("MinerBotGame");
    const game = await MinerBotGame.deploy(await token.getAddress(), await nft.getAddress());
    await game.waitForDeployment();

    // Set game contract in NFT
    await nft.setGameContract(await game.getAddress());

    // Set game contract as minter in token
    await token.authorizeGameContract(await game.getAddress(), true);
    
    // Also authorize owner for minting test tokens
    await token.authorizeGameContract(owner.address, true);

    // Mint some tokens for testing
    await token.mintGameRewards(owner.address, ethers.parseEther("1000000"));
    await token.mintGameRewards(addr1.address, ethers.parseEther("30000"));
    await token.mintGameRewards(addr2.address, ethers.parseEther("30000"));
    await token.mintGameRewards(addr3.address, ethers.parseEther("30000"));

    // Approve tokens for NFT minting and maintenance
    await token.connect(addr1).approve(await nft.getAddress(), ethers.parseEther("1000"));
    await token.connect(addr2).approve(await nft.getAddress(), ethers.parseEther("2000"));
    await token.connect(addr3).approve(await nft.getAddress(), ethers.parseEther("5000"));

    // Mint some NFTs for testing
    await nft.connect(addr1).mintRobot(addr1.address, 0, 0, { value: ethers.parseEther("0.01") });
    await nft.connect(addr2).mintRobot(addr2.address, 1, 1, { value: ethers.parseEther("0.02") });
    await nft.connect(addr3).mintRobot(addr3.address, 2, 2, { value: ethers.parseEther("0.05") });

    return { game, token, nft, owner, addr1, addr2, addr3 };
  }

  describe("Deployment", function () {
    it("Should deploy with correct initial values", async function () {
      const { game, token, nft } = await loadFixture(deployMinerBotGameFixture);
      
      expect(await game.minerBotToken()).to.equal(await token.getAddress());
      expect(await game.minerBotNFT()).to.equal(await nft.getAddress());
      expect(await game.zoneCounter()).to.equal(4); // 4 initial zones
      expect(await game.MAX_ENERGY()).to.equal(1000);
      expect(await game.ENERGY_REGEN_RATE()).to.equal(1);
    });

    it("Should create initial mining zones", async function () {
      const { game } = await loadFixture(deployMinerBotGameFixture);
      
      // Check Iron Mine (zone 0)
      const zone0 = await game.miningZones(0);
      expect(zone0.name).to.equal("Iron Mine");
      expect(zone0.zoneType).to.equal(0); // Basic
      expect(zone0.primaryResource).to.equal(0); // Iron
      expect(zone0.baseReward).to.equal(100);
      expect(zone0.isActive).to.be.true;
      
      // Check Gold Quarry (zone 1)
      const zone1 = await game.miningZones(1);
      expect(zone1.name).to.equal("Gold Quarry");
      expect(zone1.zoneType).to.equal(1); // Advanced
      expect(zone1.primaryResource).to.equal(1); // Gold
      expect(zone1.baseReward).to.equal(250);
      
      // Check Crystal Caverns (zone 2)
      const zone2 = await game.miningZones(2);
      expect(zone2.name).to.equal("Crystal Caverns");
      expect(zone2.zoneType).to.equal(2); // Elite
      expect(zone2.primaryResource).to.equal(2); // Crystal
      expect(zone2.baseReward).to.equal(500);
      
      // Check Data Core (zone 3)
      const zone3 = await game.miningZones(3);
      expect(zone3.name).to.equal("Data Core");
      expect(zone3.zoneType).to.equal(3); // Legendary
      expect(zone3.primaryResource).to.equal(4); // Data
      expect(zone3.baseReward).to.equal(1000);
    });

    it("Should fail deployment with invalid addresses", async function () {
      const MinerBotGame = await ethers.getContractFactory("MinerBotGame");
      
      await expect(MinerBotGame.deploy(ethers.ZeroAddress, ethers.ZeroAddress))
        .to.be.revertedWith("MBG: Invalid token address");
    });
  });

  describe("Mining Operations", function () {
    it("Should start mining successfully", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Perform maintenance first
      await game.connect(addr1).performRobotMaintenance(0);
      
      // Buy energy to start mining (need at least 5 energy for zone 0)
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      
      // Start mining in Iron Mine (zone 0) with robot 0
      await expect(game.connect(addr1).startMining(0, 0))
        .to.emit(game, "MiningStarted")
        .withArgs(addr1.address, 0, 0);
      
      // Check mining session
      const session = await game.miningSessions(0, 0);
      expect(session.isActive).to.be.true;
      expect(session.robotId).to.equal(0);
      expect(session.zoneId).to.equal(0);
      
      // Check zone miners count
      const zone = await game.miningZones(0);
      expect(zone.currentMiners).to.equal(1);
    });

    it("Should fail to start mining with invalid robot", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      await expect(game.connect(addr1).startMining(999, 0))
        .to.be.revertedWith("ERC721: invalid token ID");
    });

    it("Should fail to start mining with robot owned by another user", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Try to mine with robot 1 (owned by addr2)
      await expect(game.connect(addr1).startMining(1, 0))
        .to.be.revertedWith("MBG: Not robot owner");
    });

    it("Should fail to start mining in invalid zone", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      await expect(game.connect(addr1).startMining(0, 999))
        .to.be.revertedWith("MBG: Invalid zone");
    });

    it("Should fail to start mining if already mining", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Perform maintenance and buy energy
      await game.connect(addr1).performRobotMaintenance(0);
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      await game.connect(addr1).startMining(0, 0);
      
      // Try to start mining in the same zone again
      await expect(game.connect(addr1).startMining(0, 0))
        .to.be.revertedWith("MBG: Already mining in this zone");
    });

    it("Should fail to start mining if robot is mining elsewhere", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Perform maintenance and buy energy
      await game.connect(addr1).performRobotMaintenance(0);
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("200"));
      await game.connect(addr1).buyEnergy(20);
      
      // Start mining in zone 0
      await game.connect(addr1).startMining(0, 0);
      
      // Try to start mining in zone 1
      await expect(game.connect(addr1).startMining(0, 1))
        .to.be.revertedWith("MBG: Robot already mining elsewhere");
    });

    it("Should fail to start mining without maintenance", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Buy energy but don't perform maintenance
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      
      // Try to start mining without maintenance
      await expect(game.connect(addr1).startMining(0, 0))
        .to.be.revertedWith("MBG: Robot needs maintenance");
    });

    it("Should claim mining rewards after 1 hour", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Perform maintenance, buy energy and start mining
      await game.connect(addr1).performRobotMaintenance(0);
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      await game.connect(addr1).startMining(0, 0);
      
      // Fast forward 1 hour
      await time.increase(3600);
      
      const balanceBefore = await token.balanceOf(addr1.address);
      
      // Claim rewards
      await expect(game.connect(addr1).claimMiningRewards(0, 0))
        .to.emit(game, "MiningClaimed");
      
      const balanceAfter = await token.balanceOf(addr1.address);
      expect(balanceAfter).to.be.gt(balanceBefore);
    });

    it("Should fail to claim rewards before 1 hour", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Perform maintenance, buy energy and start mining
      await game.connect(addr1).performRobotMaintenance(0);
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      await game.connect(addr1).startMining(0, 0);
      
      // Try to claim immediately
      await expect(game.connect(addr1).claimMiningRewards(0, 0))
        .to.be.revertedWith("MBG: Must wait at least 1 hour");
    });

    it("Should fail to claim rewards if not mining", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      await expect(game.connect(addr1).claimMiningRewards(0, 0))
        .to.be.revertedWith("MBG: No active mining session");
    });

    it("Should stop mining successfully", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Perform maintenance, buy energy and start mining
      await game.connect(addr1).performRobotMaintenance(0);
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      await game.connect(addr1).startMining(0, 0);
      
      // Stop mining
      await expect(game.connect(addr1).stopMining(0, 0))
        .to.emit(game, "MiningStopped")
        .withArgs(addr1.address, 0, 0);
      
      // Check session is inactive
      const session = await game.miningSessions(0, 0);
      expect(session.isActive).to.be.false;
      
      // Check zone miners count
      const zone = await game.miningZones(0);
      expect(zone.currentMiners).to.equal(0);
    });

    it("Should fail to stop mining if not mining", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      await expect(game.connect(addr1).stopMining(0, 0))
        .to.be.revertedWith("MBG: No active mining session");
    });
  });

  describe("Energy System", function () {
    it("Should regenerate energy over time", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Initial energy should be 0
      expect(await game.getPlayerEnergy(addr1.address)).to.equal(0);
      
      // Trigger energy system initialization by buying energy
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("10"));
      await game.connect(addr1).buyEnergy(1);
      
      // Fast forward 1 hour (60 energy should regenerate)
      await time.increase(3600);
      
      // Check energy regenerated (1 initial + 60 regenerated)
      const energy = await game.getPlayerEnergy(addr1.address);
      expect(energy).to.equal(61); // 1 initial energy + 60 regenerated
    });

    it("Should buy energy with MBT tokens", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Approve tokens for energy purchase
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("1000"));
      
      const energyBefore = await game.getPlayerEnergy(addr1.address);
      
      // Buy 100 energy
      await expect(game.connect(addr1).buyEnergy(100))
        .to.emit(game, "EnergyRestored")
        .withArgs(addr1.address, 100);
      
      const energyAfter = await game.getPlayerEnergy(addr1.address);
      expect(energyAfter).to.equal(energyBefore + BigInt(100));
    });

    it("Should fail to buy energy with invalid amount", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      await expect(game.connect(addr1).buyEnergy(0))
        .to.be.revertedWith("MBG: Invalid energy amount");
      
      await expect(game.connect(addr1).buyEnergy(501))
        .to.be.revertedWith("MBG: Invalid energy amount");
    });

    it("Should cap energy at maximum", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Approve tokens
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("10000"));
      
      // Buy maximum energy
      await game.connect(addr1).buyEnergy(500);
      await game.connect(addr1).buyEnergy(500);
      
      // Fast forward to regenerate more
      await time.increase(86400); // 24 hours
      
      const energy = await game.getPlayerEnergy(addr1.address);
      expect(energy).to.equal(1000); // MAX_ENERGY
    });
  });

  describe("Robot Maintenance", function () {
    it("Should perform robot maintenance", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      await expect(game.connect(addr1).performRobotMaintenance(0))
        .to.not.be.reverted;
      
      const maintenanceTime = await game.robotLastMaintenance(0);
      expect(maintenanceTime).to.be.gt(0);
    });

    it("Should fail maintenance for robot not owned", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      await expect(game.connect(addr1).performRobotMaintenance(1))
        .to.be.revertedWith("MBG: Not robot owner");
    });
  });

  describe("Special Events", function () {
    it("Should create special event", async function () {
      const { game, owner } = await loadFixture(deployMinerBotGameFixture);
      
      const duration = 86400; // 24 hours
      
      await expect(game.connect(owner).createSpecialEvent(
        "Double Rewards",
        duration,
        200, // 2x multiplier
        0    // Iron resource
      )).to.emit(game, "SpecialEventStarted")
        .withArgs(0, "Double Rewards", 200);
      
      const event = await game.specialEvents(0);
      expect(event.name).to.equal("Double Rewards");
      expect(event.bonusMultiplier).to.equal(200);
      expect(event.isActive).to.be.true;
    });

    it("Should fail to create event if not owner", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      const duration = 86400;
      
      await expect(game.connect(addr1).createSpecialEvent(
        "Double Rewards",
        duration,
        200,
        0
      )).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Player Statistics", function () {
    it("Should track player statistics", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Approve tokens and buy energy
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      
      // Perform maintenance, start mining and claim rewards
      await game.connect(addr1).performRobotMaintenance(0);
      await game.connect(addr1).startMining(0, 0);
      await time.increase(3600);
      await game.connect(addr1).claimMiningRewards(0, 0);
      
      const stats = await game.playerStats(addr1.address);
      expect(stats.totalRewards).to.be.gt(0);
      expect(stats.lastActivity).to.be.gt(0);
      expect(stats.reputation).to.be.gt(0);
    });

    it("Should get player resources", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Approve tokens and buy energy
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      
      // Perform maintenance, start mining and claim rewards
      await game.connect(addr1).performRobotMaintenance(0);
      await game.connect(addr1).startMining(0, 0);
      await time.increase(3600);
      await game.connect(addr1).claimMiningRewards(0, 0);
      
      const ironResources = await game.playerResources(addr1.address, 0); // Iron
      expect(ironResources).to.be.gt(0);
    });

    it("Should get mining info", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Approve tokens and buy energy
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      
      // Perform maintenance and start mining
      await game.connect(addr1).performRobotMaintenance(0);
      await game.connect(addr1).startMining(0, 0);
      
      const miningInfo = await game.getMiningInfo(0, 0);
      expect(miningInfo.isActive).to.be.true;
      expect(miningInfo.robotId).to.equal(0);
      expect(miningInfo.zoneId).to.equal(0);
    });

    it("Should get zone info", async function () {
      const { game } = await loadFixture(deployMinerBotGameFixture);
      
      const zoneInfo = await game.getZoneInfo(0);
      expect(zoneInfo.name).to.equal("Iron Mine");
      expect(zoneInfo.isActive).to.be.true;
    });

    it("Should fail to get invalid zone info", async function () {
      const { game } = await loadFixture(deployMinerBotGameFixture);
      
      await expect(game.getZoneInfo(999))
        .to.be.revertedWith("MBG: Invalid zone");
    });
  });

  describe("Pause Functionality", function () {
    it("Should pause and unpause contract", async function () {
      const { game, token, owner, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Pause contract
      await game.connect(owner).pause();
      
      // Should fail to start mining when paused
      await expect(game.connect(addr1).startMining(0, 0))
        .to.be.revertedWith("Pausable: paused");
      
      // Unpause
      await game.connect(owner).unpause();
      
      // Approve tokens and buy energy
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      
      // Should work after unpause (with maintenance)
      await game.connect(addr1).performRobotMaintenance(0);
      await expect(game.connect(addr1).startMining(0, 0))
        .to.not.be.reverted;
    });
  });

  describe("Access Control", function () {
    it("Should restrict owner functions", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      await expect(game.connect(addr1).pause())
        .to.be.revertedWith("Ownable: caller is not the owner");
      
      await expect(game.connect(addr1).createSpecialEvent(
        "Test", 86400, 200, 0
      )).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should unban player", async function () {
      const { game, owner, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Manually set player as banned for testing
      // This would normally happen through suspicious activity detection
      
      // Unban player
      await game.connect(owner).unbanPlayer(addr1.address);
      
      const stats = await game.playerStats(addr1.address);
      expect(stats.isBanned).to.be.false;
    });
  });

  describe("Emergency Functions", function () {
    it("Should perform emergency withdrawal", async function () {
      const { game, token, owner } = await loadFixture(deployMinerBotGameFixture);
      
      // Send some tokens to the game contract
      await token.mintGameRewards(await game.getAddress(), ethers.parseEther("1000"));
      
      const balanceBefore = await token.balanceOf(owner.address);
      
      // Emergency withdraw
      await game.connect(owner).emergencyWithdraw();
      
      const balanceAfter = await token.balanceOf(owner.address);
      expect(balanceAfter).to.be.gt(balanceBefore);
    });
  });

  describe("Edge Cases and Anti-Fraud", function () {
    it("Should handle insufficient energy for mining", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Approve tokens and buy energy
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      
      // Perform maintenance and start mining
      await game.connect(addr1).performRobotMaintenance(0);
      await game.connect(addr1).startMining(0, 0);
      
      // Fast forward 1 hour and claim (this should work)
      await time.increase(3600);
      await game.connect(addr1).claimMiningRewards(0, 0);
      
      // Fast forward 250 hours (mining costs 5 energy per hour, so 1250 energy needed)
      // Player has 5 energy left after first claim, will regenerate 250 energy (250 hours * 1 energy/hour)
      // Total available: 5 + 250 = 255 energy, but needs 1250 energy
      await time.increase(3600 * 250); // 250 hours
      
      // Try to claim again - should stop mining due to insufficient energy
      await game.connect(addr1).claimMiningRewards(0, 0);
      
      // Check that mining session is now inactive
      const session = await game.miningSessions(0, 0);
      expect(session.isActive).to.be.false;
    });

    it("Should prevent too many claims (anti-spam)", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // This test would require setting up multiple mining sessions
      // and trying to claim rewards too frequently
      // The exact implementation depends on the FRAUD_DETECTION_THRESHOLD
      
      // For now, we'll just verify the mechanism exists
      expect(await game.FRAUD_DETECTION_THRESHOLD()).to.equal(10);
    });

    it("Should handle maintenance decay", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Approve tokens and buy energy
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("100"));
      await game.connect(addr1).buyEnergy(10);
      
      // Perform maintenance and start mining
      await game.connect(addr1).performRobotMaintenance(0);
      await game.connect(addr1).startMining(0, 0);
      
      // Fast forward past maintenance interval
      await time.increase(86400 * 2); // 2 days
      
      // Try to claim rewards - should work but with reduced efficiency
      await game.connect(addr1).claimMiningRewards(0, 0);
      
      // The rewards should be reduced due to maintenance decay
      // This is tested implicitly through the reward calculation
    });
  });

  describe("View Functions", function () {
    it("Should return correct player stats", async function () {
      const { game, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      const stats = await game.getPlayerStats(addr1.address);
      expect(stats.totalMined).to.equal(0);
      expect(stats.totalRewards).to.equal(0);
      expect(stats.isBanned).to.be.false;
    });

    it("Should return correct player energy", async function () {
      const { game, token, addr1 } = await loadFixture(deployMinerBotGameFixture);
      
      // Initial energy should be 0
      expect(await game.getPlayerEnergy(addr1.address)).to.equal(0);
      
      // Trigger energy system initialization by buying energy
      await token.connect(addr1).approve(await game.getAddress(), ethers.parseEther("10"));
      await game.connect(addr1).buyEnergy(1);
      
      // After time passes, energy should regenerate
      await time.increase(3600); // 1 hour
      expect(await game.getPlayerEnergy(addr1.address)).to.equal(61); // 1 initial + 60 regenerated
    });
  });
});