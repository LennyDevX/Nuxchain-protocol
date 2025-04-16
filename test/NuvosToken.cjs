const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("NUVOToken Contract", function() {
  // Constants (converted to BigInt for large number precision)
  const MAX_SUPPLY = ethers.parseEther("21000000");
  const INITIAL_SUPPLY = ethers.parseEther("1000000");
  const FINAL_SUPPLY = ethers.parseEther("10000000");
  const BURN_TARGET = ethers.parseEther("11000000");

  // Fixture to deploy and get fresh contract instances for each test
  async function deployTokenFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners();
    
    const NUVOToken = await ethers.getContractFactory("NUVOToken");
    const token = await NUVOToken.deploy(owner.address);
    
    return { token, owner, addr1, addr2 };
  }

  describe("Deployment", function() {
    it("Should set the right name and symbol", async function() {
      const { token } = await loadFixture(deployTokenFixture);
      
      expect(await token.name()).to.equal("NUVOS");
      expect(await token.symbol()).to.equal("NUVOS");
    });

    it("Should assign initial supply to the owner", async function() {
      const { token, owner } = await loadFixture(deployTokenFixture);
      
      expect(await token.totalSupply()).to.equal(INITIAL_SUPPLY);
      expect(await token.balanceOf(owner.address)).to.equal(INITIAL_SUPPLY);
    });

    it("Should set the right cap", async function() {
      const { token } = await loadFixture(deployTokenFixture);
      
      expect(await token.cap()).to.equal(MAX_SUPPLY);
    });
  });

  describe("Minting", function() {
    it("Should mint tokens correctly when owner calls", async function() {
      const { token, owner, addr1 } = await loadFixture(deployTokenFixture);
      
      // Mint 1000 tokens to addr1
      const mintAmount = ethers.parseEther("1000");
      await expect(token.mint(addr1.address, mintAmount))
        .to.emit(token, "TokensMinted")
        .withArgs(addr1.address, mintAmount);
        
      // Verify balances updated correctly
      expect(await token.balanceOf(addr1.address)).to.equal(mintAmount);
      expect(await token.totalSupply()).to.equal(INITIAL_SUPPLY + mintAmount);
    });

    it("Should revert when non-owner tries to mint", async function() {
      const { token, addr1 } = await loadFixture(deployTokenFixture);
      
      const mintAmount = ethers.parseEther("1000");
      // Update the expected error to OwnableUnauthorized
      await expect(token.connect(addr1).mint(addr1.address, mintAmount))
        .to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should revert when trying to mint more than the cap", async function() {
      const { token, owner } = await loadFixture(deployTokenFixture);
      
      // Try to mint more than the remaining cap
      const excessiveAmount = MAX_SUPPLY;
      
      // Use a more generic revert check instead of a specific error name
      await expect(token.mint(owner.address, excessiveAmount))
        .to.be.revertedWith("ERC20Capped: cap exceeded");
    });

    it("Should correctly return remaining mintable supply", async function() {
      const { token, addr1 } = await loadFixture(deployTokenFixture);
      
      // Initial remaining mintable supply
      let expected = MAX_SUPPLY - INITIAL_SUPPLY;
      expect(await token.remainingMintableSupply()).to.equal(expected);
      
      // Mint some more tokens
      const mintAmount = ethers.parseEther("5000000");
      await token.mint(addr1.address, mintAmount);
      
      // Updated remaining mintable supply
      expected = expected - mintAmount;
      expect(await token.remainingMintableSupply()).to.equal(expected);
    });
  });

  describe("Burning", function() {
    it("Should burn tokens correctly when holder calls", async function() {
      const { token, owner } = await loadFixture(deployTokenFixture);
      
      const burnAmount = ethers.parseEther("100000");
      await expect(token.burn(burnAmount))
        .to.emit(token, "TokensBurned")
        .withArgs(owner.address, burnAmount);
        
      // Verify balance and supply updated correctly
      expect(await token.balanceOf(owner.address)).to.equal(INITIAL_SUPPLY - burnAmount);
      expect(await token.totalSupply()).to.equal(INITIAL_SUPPLY - burnAmount);
      expect(await token.totalBurnedTokens()).to.equal(burnAmount);
    });

    it("Should burn tokens from another account with allowance", async function() {
      const { token, owner, addr1 } = await loadFixture(deployTokenFixture);
      
      // Transfer tokens to addr1
      const transferAmount = ethers.parseEther("200000");
      await token.transfer(addr1.address, transferAmount);
      
      // Approve owner to burn tokens from addr1
      const burnAmount = ethers.parseEther("50000");
      await token.connect(addr1).approve(owner.address, burnAmount);
      
      // Owner burns tokens from addr1
      await expect(token.burnFrom(addr1.address, burnAmount))
        .to.emit(token, "TokensBurned")
        .withArgs(addr1.address, burnAmount);
        
      // Verify balances
      expect(await token.balanceOf(addr1.address)).to.equal(transferAmount - burnAmount);
      expect(await token.totalBurnedTokens()).to.equal(burnAmount);
    });

    it("Should revert burnFrom when exceeding allowance", async function() {
      const { token, owner, addr1 } = await loadFixture(deployTokenFixture);
      
      // Transfer tokens to addr1
      const transferAmount = ethers.parseEther("100000");
      await token.transfer(addr1.address, transferAmount);
      
      // Approve owner to burn tokens from addr1
      const approveAmount = ethers.parseEther("30000");
      await token.connect(addr1).approve(owner.address, approveAmount);
      
      // Try to burn more than the approved amount
      const burnAmount = ethers.parseEther("50000");
      await expect(token.burnFrom(addr1.address, burnAmount))
        .to.be.revertedWith("ERC20: insufficient allowance");
    });
  });

  describe("Burn Tracking and Statistics", function() {
    it("Should correctly track total burned tokens", async function() {
      const { token, owner } = await loadFixture(deployTokenFixture);
      
      // Initial burn amount
      const burnAmount1 = ethers.parseEther("100000");
      await token.burn(burnAmount1);
      expect(await token.totalBurnedTokens()).to.equal(burnAmount1);
      
      // Burn more tokens
      const burnAmount2 = ethers.parseEther("200000");
      await token.burn(burnAmount2);
      expect(await token.totalBurnedTokens()).to.equal(burnAmount1 + burnAmount2);
    });

    it("Should correctly calculate remainingToBurn", async function() {
      const { token } = await loadFixture(deployTokenFixture);
      
      // Initially, no tokens burned
      expect(await token.remainingToBurn()).to.equal(BURN_TARGET);
      
      // After burning some tokens
      const burnAmount = ethers.parseEther("1000000");
      await token.burn(burnAmount);
      expect(await token.remainingToBurn()).to.equal(BURN_TARGET - burnAmount);
    });

    it("Should correctly calculate burn progress percentage", async function() {
      const { token, owner } = await loadFixture(deployTokenFixture);
      
      // Mint additional tokens to the owner to allow burning large amounts
      await token.mint(owner.address, ethers.parseEther("20000000"));
      
      // Initially 0%
      expect(await token.burnProgress()).to.equal(0);
      
      // After burning 10% of the target
      const tenPercent = BURN_TARGET / 10n;
      await token.burn(tenPercent);
      expect(await token.burnProgress()).to.equal(10);
      
      // After burning another 15% of the target
      const fifteenPercent = (BURN_TARGET * 15n) / 100n;
      await token.burn(fifteenPercent);
      expect(await token.burnProgress()).to.equal(25); // Total: 10% + 15% = 25%
    });

    it("Should handle remainingToBurn and burnProgress when burn target is reached", async function() {
      const { token, owner } = await loadFixture(deployTokenFixture);
      
      // Mint more tokens to be able to burn enough
      await token.mint(owner.address, ethers.parseEther("10000000"));
      
      // Burn exactly the burn target amount
      await token.burn(BURN_TARGET);
      
      expect(await token.remainingToBurn()).to.equal(0);
      expect(await token.burnProgress()).to.equal(100);
    });

    it("Should correctly return target supply", async function() {
      const { token } = await loadFixture(deployTokenFixture);
      expect(await token.targetSupply()).to.equal(FINAL_SUPPLY);
    });

    it("Should correctly return burn target", async function() {
      const { token } = await loadFixture(deployTokenFixture);
      expect(await token.getBurnTarget()).to.equal(BURN_TARGET);
    });

    it("Should correctly return token stats", async function() {
      const { token } = await loadFixture(deployTokenFixture);
      
      // Burn some tokens
      const burnAmount = ethers.parseEther("550000"); // 5.5% of burn target
      await token.burn(burnAmount);
      
      const stats = await token.getTokenStats();
      
      expect(stats[0]).to.equal(MAX_SUPPLY); // maxSupply
      expect(stats[1]).to.equal(INITIAL_SUPPLY - burnAmount); // currentSupply
      expect(stats[2]).to.equal(FINAL_SUPPLY); // targetFinalSupply
      expect(stats[3]).to.equal(burnAmount); // totalBurned
      expect(stats[4]).to.equal(BURN_TARGET); // burnTarget
      expect(stats[5]).to.equal(5); // currentBurnProgress (5%)
      expect(stats[6]).to.equal(BURN_TARGET - burnAmount); // currentRemainingToBurn
    });
  });
  
  describe("Edge cases and transfers", function() {
    it("Should handle standard ERC20 transfers correctly", async function() {
      const { token, owner, addr1 } = await loadFixture(deployTokenFixture);
      
      const transferAmount = ethers.parseEther("50000");
      await token.transfer(addr1.address, transferAmount);
      
      expect(await token.balanceOf(addr1.address)).to.equal(transferAmount);
      expect(await token.balanceOf(owner.address)).to.equal(INITIAL_SUPPLY - transferAmount);
    });
    
    it("Should handle transferFrom with approval correctly", async function() {
      const { token, owner, addr1, addr2 } = await loadFixture(deployTokenFixture);
      
      // Transfer tokens to addr1
      const initialAmount = ethers.parseEther("100000");
      await token.transfer(addr1.address, initialAmount);
      
      // addr1 approves addr2 to spend tokens
      const approveAmount = ethers.parseEther("30000");
      await token.connect(addr1).approve(addr2.address, approveAmount);
      
      // addr2 transfers tokens from addr1 to themselves
      const transferAmount = ethers.parseEther("25000");
      await token.connect(addr2).transferFrom(addr1.address, addr2.address, transferAmount);
      
      expect(await token.balanceOf(addr1.address)).to.equal(initialAmount - transferAmount);
      expect(await token.balanceOf(addr2.address)).to.equal(transferAmount);
      expect(await token.allowance(addr1.address, addr2.address)).to.equal(approveAmount - transferAmount);
    });
  });
});