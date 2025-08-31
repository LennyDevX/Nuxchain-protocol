const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("MinerBotToken", function () {
  // Fixture para desplegar el contrato
  async function deployMinerBotTokenFixture() {
    const [owner, addr1, addr2, addr3, gameContract, gameRewardsWallet, teamWallet, marketingWallet, treasuryWallet, airdropWallet, advisorWallet] = await ethers.getSigners();

    const MinerBotToken = await ethers.getContractFactory("MinerBotToken");
    const token = await MinerBotToken.deploy(
      gameRewardsWallet.address,
      teamWallet.address,
      marketingWallet.address,
      treasuryWallet.address,
      airdropWallet.address,
      advisorWallet.address
    );

    return { 
      token, 
      owner, 
      addr1, 
      addr2, 
      addr3, 
      gameContract,
      gameRewardsWallet,
      teamWallet,
      marketingWallet,
      treasuryWallet,
      airdropWallet,
      advisorWallet
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { token, owner } = await loadFixture(deployMinerBotTokenFixture);
      expect(await token.owner()).to.equal(owner.address);
    });

    it("Should distribute tokens correctly at deployment", async function () {
      const { token, gameRewardsWallet, marketingWallet, treasuryWallet, airdropWallet } = await loadFixture(deployMinerBotTokenFixture);
      
      // Verificar que los tokens se distribuyeron correctamente
      expect(await token.balanceOf(gameRewardsWallet.address)).to.equal(ethers.parseEther("400000000")); // 400M
      expect(await token.balanceOf(marketingWallet.address)).to.equal(ethers.parseEther("100000000")); // 100M
      expect(await token.balanceOf(treasuryWallet.address)).to.equal(ethers.parseEther("50000000")); // 50M
      expect(await token.balanceOf(airdropWallet.address)).to.equal(ethers.parseEther("30000000")); // 30M
    });

    it("Should have correct initial values", async function () {
      const { token, gameRewardsWallet, marketingWallet, treasuryWallet, airdropWallet } = await loadFixture(deployMinerBotTokenFixture);
      
      expect(await token.name()).to.equal("MinerBot Token");
      expect(await token.symbol()).to.equal("MBT");
      expect(await token.decimals()).to.equal(18);
      expect(await token.totalSupply()).to.equal(ethers.parseEther("580000000")); // Only initially minted tokens
      
      // Check initial distribution
      expect(await token.balanceOf(gameRewardsWallet.address)).to.equal(ethers.parseEther("400000000"));
      expect(await token.balanceOf(marketingWallet.address)).to.equal(ethers.parseEther("100000000"));
      expect(await token.balanceOf(treasuryWallet.address)).to.equal(ethers.parseEther("50000000"));
      expect(await token.balanceOf(airdropWallet.address)).to.equal(ethers.parseEther("30000000"));
    });

    it("Should have correct allocation constants", async function () {
      const { token } = await loadFixture(deployMinerBotTokenFixture);
      
      // Verificar constantes de asignación
      expect(await token.GAME_REWARDS_ALLOCATION()).to.equal(ethers.parseEther("400000000")); // 400M
      expect(await token.STAKING_ALLOCATION()).to.equal(ethers.parseEther("250000000")); // 250M
      expect(await token.TEAM_ALLOCATION()).to.equal(ethers.parseEther("150000000")); // 150M
      expect(await token.MARKETING_ALLOCATION()).to.equal(ethers.parseEther("100000000")); // 100M
      expect(await token.TREASURY_ALLOCATION()).to.equal(ethers.parseEther("50000000")); // 50M
      expect(await token.AIRDROP_ALLOCATION()).to.equal(ethers.parseEther("30000000")); // 30M
      expect(await token.ADVISOR_ALLOCATION()).to.equal(ethers.parseEther("20000000")); // 20M
    });

    it("Should set anti-whale limits correctly", async function () {
      const { token } = await loadFixture(deployMinerBotTokenFixture);
      
      // Verificar límites anti-whale correctos
      expect(await token.maxTransactionAmount()).to.equal(ethers.parseEther("5000000")); // 0.5% del supply
      expect(await token.maxWalletAmount()).to.equal(ethers.parseEther("10000000")); // 1% del supply
    });
  });

  describe("Transfers", function () {
    it("Should transfer tokens between accounts", async function () {
      const { token, marketingWallet, addr1, addr2 } = await loadFixture(deployMinerBotTokenFixture);
      
      const transferAmount = ethers.parseEther("1000");
      
      // Transfer from marketingWallet to addr1
      await expect(token.connect(marketingWallet).transfer(addr1.address, transferAmount))
        .to.changeTokenBalances(token, [marketingWallet, addr1], [-transferAmount, transferAmount]);

      // Transfer from addr1 to addr2
      await expect(token.connect(addr1).transfer(addr2.address, transferAmount))
        .to.changeTokenBalances(token, [addr1, addr2], [-transferAmount, transferAmount]);
    });

    it("Should fail if sender doesn't have enough tokens", async function () {
      const { token, owner, addr1 } = await loadFixture(deployMinerBotTokenFixture);
      const initialOwnerBalance = await token.balanceOf(owner.address);

      await expect(
        token.connect(addr1).transfer(owner.address, 1)
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");

      expect(await token.balanceOf(owner.address)).to.equal(initialOwnerBalance);
    });

    it("Should respect max transaction amount", async function () {
      const { token, marketingWallet, addr1, addr2 } = await loadFixture(deployMinerBotTokenFixture);
      
      // First transfer some tokens to addr1 (not excluded from limits)
      const initialAmount = ethers.parseEther("10000000");
      await token.connect(marketingWallet).transfer(addr1.address, initialAmount);
      
      const maxTxAmount = await token.maxTransactionAmount();
      const excessiveAmount = maxTxAmount + ethers.parseEther("1");
      
      await expect(
        token.connect(addr1).transfer(addr2.address, excessiveAmount)
      ).to.be.revertedWith("MBT: Transfer amount exceeds limit");
    });

    it("Should respect max wallet amount", async function () {
      const { token, marketingWallet, addr1, addr2 } = await loadFixture(deployMinerBotTokenFixture);
      
      const maxWalletAmount = await token.maxWalletAmount();
      const maxTxAmount = await token.maxTransactionAmount();
      
      // First transfer tokens to addr2 (not excluded from limits)
      await token.connect(marketingWallet).transfer(addr2.address, maxWalletAmount);
      
      // Transfer up to max wallet amount to addr1 in two transactions (respecting tx limit)
      await token.connect(addr2).transfer(addr1.address, maxTxAmount);
      const remainingAmount = maxWalletAmount - maxTxAmount;
      await token.connect(addr2).transfer(addr1.address, remainingAmount);
      
      // Second transfer should fail (from addr2 to addr1)
      await expect(
        token.connect(addr2).transfer(addr1.address, ethers.parseEther("1"))
      ).to.be.revertedWith("MBT: Wallet amount exceeds limit");
    });

    it("Should allow excluded wallets to bypass limits", async function () {
      const { token, gameRewardsWallet, addr1 } = await loadFixture(deployMinerBotTokenFixture);
      
      const maxTxAmount = await token.maxTransactionAmount();
      const excessiveAmount = maxTxAmount + ethers.parseEther("1000");
      
      // Excluded wallets should be able to transfer more than max
      await expect(token.connect(gameRewardsWallet).transfer(addr1.address, excessiveAmount))
        .to.not.be.reverted;
    });
  });

  describe("Burning", function () {
    it("Should burn tokens correctly", async function () {
      const { token, marketingWallet } = await loadFixture(deployMinerBotTokenFixture);
      
      const burnAmount = ethers.parseEther("1000");
      const initialSupply = await token.totalSupply();
      const initialBalance = await token.balanceOf(marketingWallet.address);
      
      await expect(token.connect(marketingWallet).burn(burnAmount))
        .to.emit(token, "Transfer")
        .withArgs(marketingWallet.address, ethers.ZeroAddress, burnAmount);
      
      expect(await token.totalSupply()).to.equal(initialSupply - burnAmount);
      expect(await token.balanceOf(marketingWallet.address)).to.equal(initialBalance - burnAmount);
    });

    it("Should update total burned amount", async function () {
      const { token, marketingWallet } = await loadFixture(deployMinerBotTokenFixture);
      
      const burnAmount = ethers.parseEther("1000");
      
      await token.connect(marketingWallet).burn(burnAmount);
      expect(await token.totalBurned()).to.equal(burnAmount);
      
      await token.connect(marketingWallet).burn(burnAmount);
      expect(await token.totalBurned()).to.equal(burnAmount * 2n);
    });

    it("Should fail to burn more than balance", async function () {
      const { token, addr1 } = await loadFixture(deployMinerBotTokenFixture);
      
      await expect(
        token.connect(addr1).burn(ethers.parseEther("1"))
      ).to.be.revertedWith("ERC20: burn amount exceeds balance");
    });
  });

  describe("Game Contract Authorization", function () {
    it("Should allow owner to authorize game contracts", async function () {
      const { token, gameContract } = await loadFixture(deployMinerBotTokenFixture);
      
      await expect(token.authorizeGameContract(gameContract.address, true))
        .to.emit(token, "GameContractAuthorized")
        .withArgs(gameContract.address, true);
      
      expect(await token.authorizedGameContracts(gameContract.address)).to.be.true;
    });

    it("Should allow authorized contracts to mint rewards", async function () {
      const { token, owner, addr1, gameContract } = await loadFixture(deployMinerBotTokenFixture);
      
      await token.authorizeGameContract(gameContract.address, true);
      
      const mintAmount = ethers.parseEther("100");
      const initialSupply = await token.totalSupply();
      
      await expect(token.connect(gameContract).mintGameRewards(addr1.address, mintAmount))
        .to.emit(token, "Transfer")
        .withArgs(ethers.ZeroAddress, addr1.address, mintAmount);
      
      expect(await token.balanceOf(addr1.address)).to.equal(mintAmount);
      expect(await token.totalSupply()).to.equal(initialSupply + mintAmount);
    });

    it("Should prevent unauthorized contracts from minting", async function () {
      const { token, addr1, gameContract } = await loadFixture(deployMinerBotTokenFixture);
      
      await expect(
        token.connect(gameContract).mintGameRewards(addr1.address, ethers.parseEther("100"))
      ).to.be.revertedWith("MBT: Not authorized game contract");
    });


  });

  describe("Vesting", function () {
    it("Should enforce team vesting schedule", async function () {
      const { token } = await loadFixture(deployMinerBotTokenFixture);
      
      // Fast forward to allow some vesting (1 month)
      await time.increase(30 * 24 * 60 * 60);
      
      // Should succeed after some time has passed
      await expect(token.releaseTeamTokens())
        .to.not.be.reverted;
      
      // Check that tokens were released
      const releasedAmount = await token.teamTokensReleased();
      expect(releasedAmount).to.be.greaterThan(0);
    });

    it("Should enforce advisor vesting schedule", async function () {
      const { token } = await loadFixture(deployMinerBotTokenFixture);
      
      // Fast forward to allow some vesting (1 month)
      await time.increase(30 * 24 * 60 * 60);
      
      // Should succeed after some time has passed
      await expect(token.releaseAdvisorTokens())
        .to.not.be.reverted;
      
      // Check that tokens were released
      const releasedAmount = await token.advisorTokensReleased();
      expect(releasedAmount).to.be.greaterThan(0);
    });


  });

  describe("Pausable", function () {
    it("Should allow owner to pause and unpause", async function () {
      const { token } = await loadFixture(deployMinerBotTokenFixture);
      
      await expect(token.pause())
        .to.emit(token, "Paused");
      
      expect(await token.paused()).to.be.true;
      
      await expect(token.unpause())
        .to.emit(token, "Unpaused");
      
      expect(await token.paused()).to.be.false;
    });

    it("Should prevent transfers when paused", async function () {
      const { token, owner, addr1 } = await loadFixture(deployMinerBotTokenFixture);
      
      await token.pause();
      
      await expect(
        token.transfer(addr1.address, ethers.parseEther("100"))
      ).to.be.revertedWith("MBT: Token transfers paused");
    });

    it("Should prevent non-owner from pausing", async function () {
      const { token, addr1 } = await loadFixture(deployMinerBotTokenFixture);
      
      await expect(
        token.connect(addr1).pause()
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Access Control", function () {
    it("Should prevent non-owner from authorizing game contracts", async function () {
      const { token, addr1, gameContract } = await loadFixture(deployMinerBotTokenFixture);
      
      await expect(
        token.connect(addr1).authorizeGameContract(gameContract.address, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow anyone to call vesting release functions", async function () {
      const { token, addr1 } = await loadFixture(deployMinerBotTokenFixture);
      
      // Fast forward to allow some vesting
      await time.increase(30 * 24 * 60 * 60); // 1 month
      
      // Anyone should be able to call release functions
      await expect(token.connect(addr1).releaseTeamTokens())
        .to.not.be.reverted;
    });

    it("Should allow ownership transfer", async function () {
      const { token, owner, addr1 } = await loadFixture(deployMinerBotTokenFixture);
      
      await token.transferOwnership(addr1.address);
      expect(await token.owner()).to.equal(addr1.address);
    });
  });

  describe("New Functions", function () {
    it("Should allow owner to set staking contract", async function () {
      const { token, addr1 } = await loadFixture(deployMinerBotTokenFixture);
      
      await expect(token.setStakingContract(addr1.address))
        .to.not.be.reverted;
    });

    it("Should return correct circulating supply", async function () {
      const { token } = await loadFixture(deployMinerBotTokenFixture);
      
      const circulatingSupply = await token.circulatingSupply();
      expect(circulatingSupply).to.be.greaterThan(0);
    });

    it("Should return correct burn rate", async function () {
      const { token } = await loadFixture(deployMinerBotTokenFixture);
      
      const burnRate = await token.burnRate();
      expect(burnRate).to.equal(0); // Initially no tokens burned
    });

    it("Should update burn rate after burning tokens", async function () {
      const { token, marketingWallet } = await loadFixture(deployMinerBotTokenFixture);
      
      const burnAmount = ethers.parseEther("1000000"); // 1M tokens for noticeable rate
      await token.connect(marketingWallet).burn(burnAmount);
      
      const burnRate = await token.burnRate();
      expect(burnRate).to.be.greaterThan(0);
      
      // Verify calculation: burnRate = (totalBurned * 10000) / TOTAL_SUPPLY
      const totalBurned = await token.totalBurned();
      const expectedRate = (totalBurned * 10000n) / ethers.parseEther("1000000000");
      expect(burnRate).to.equal(expectedRate);
    });
  });

  describe("Edge Cases", function () {
    it("Should handle zero transfers", async function () {
      const { token, addr1 } = await loadFixture(deployMinerBotTokenFixture);
      
      await expect(token.transfer(addr1.address, 0))
        .to.not.be.reverted;
    });

    it("Should handle self transfers", async function () {
      const { token, marketingWallet } = await loadFixture(deployMinerBotTokenFixture);
      
      const amount = ethers.parseEther("100");
      const initialBalance = await token.balanceOf(marketingWallet.address);
      
      await token.connect(marketingWallet).transfer(marketingWallet.address, amount);
      expect(await token.balanceOf(marketingWallet.address)).to.equal(initialBalance);
    });

    it("Should handle maximum values correctly", async function () {
      const { token } = await loadFixture(deployMinerBotTokenFixture);
      
      const maxUint256 = ethers.MaxUint256;
      
      await expect(
        token.burn(maxUint256)
      ).to.be.revertedWith("ERC20: burn amount exceeds balance");
    });
  });
});