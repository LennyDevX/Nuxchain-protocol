const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingContract", function () {
    let StakingContract, staking;
    let owner, addr1, addrs;
    let _treasury;

    beforeEach(async function () {
        StakingContract = await ethers.getContractFactory("StakingContract");
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
        _treasury = owner.address;
        staking = await StakingContract.deploy(_treasury);
        await staking.deployed();
        
        // Fund contract with initial balance for rewards
        await owner.sendTransaction({
            to: staking.address,
            value: ethers.utils.parseEther("1000")
        });
    });

    // Access control tests
    it("should not allow non-owner to call emergencyWithdraw", async function () {
        await expect(
            staking.connect(addr1).emergencyWithdraw(addr1.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should not allow non-owner to change treasury address", async function () {
        await expect(
            staking.connect(addr1).changeTreasuryAddress(addr1.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should not allow non-owner to pause the contract", async function () {
        await expect(
            staking.connect(addr1).pause()
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should not allow non-owner to unpause the contract", async function () {
        await expect(
            staking.connect(addr1).unpause()
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    // Deposit and withdrawal tests
    it("should allow emergency withdrawal of deposits when paused", async function () {
        const depositAmount = ethers.utils.parseEther("100");
        await staking.connect(addr1).deposit({ value: depositAmount });

        // Accumulate some rewards
        await ethers.provider.send("evm_increaseTime", [24 * 3600]);
        await ethers.provider.send("evm_mine");

        // Pause contract
        await staking.connect(owner).pause();

        // Get initial balances
        const initialBalance = await addr1.getBalance();
        const initialDeposit = await staking.getTotalDeposit(addr1.address);

        // Emergency withdraw
        const tx = await staking.connect(addr1).emergencyUserWithdraw();
        const receipt = await tx.wait();
        const gasCost = receipt.gasUsed.mul(tx.gasPrice);

        // Check final balances
        const finalBalance = await addr1.getBalance();

        // Verify full deposit was returned
        expect(finalBalance.add(gasCost).sub(initialBalance)).to.equal(initialDeposit);

        // Verify user data was cleared
        const userDeposits = await staking.getUserDeposits(addr1.address);
        expect(userDeposits.length).to.equal(0);
    });

    it("should not allow emergency withdrawal when not paused", async function () {
        const depositAmount = ethers.utils.parseEther("100");
        await staking.connect(addr1).deposit({ value: depositAmount });

        await expect(
            staking.connect(addr1).emergencyUserWithdraw()
        ).to.be.revertedWith("Pausable: not paused");
    });

    it("should not allow regular withdrawal when paused", async function () {
        const depositAmount = ethers.utils.parseEther("100");
        await staking.connect(addr1).deposit({ value: depositAmount });

        await staking.connect(owner).pause();

        await expect(
            staking.connect(addr1).withdraw()
        ).to.be.revertedWith("Pausable: paused");
    });

    // Update overflow/underflow test
    it("should prevent overflow/underflow", async function () {
        const depositAmount = ethers.utils.parseEther("100");
        await staking.connect(addr1).deposit({ value: depositAmount });

        // Test overflow protection
        const largeAmount = ethers.utils.parseEther("1000000");
        await expect(
            staking.connect(owner).addBalance({ value: largeAmount })
        ).to.not.be.reverted;

        // Test underflow protection
        await staking.connect(owner).pause();
        await staking.connect(addr1).emergencyUserWithdraw();

        // Try to withdraw again when balance is 0
        await expect(
            staking.connect(addr1).emergencyUserWithdraw()
        ).to.be.revertedWith("No deposits to withdraw");
    });
});
