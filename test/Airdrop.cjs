const { expect } = require("chai");
const { ethers, network } = require("hardhat");

// Helper para avanzar el tiempo en la blockchain de prueba
async function advanceTime(seconds) {
    await network.provider.send("evm_increaseTime", [seconds]);
    await network.provider.send("evm_mine");
}

describe("Enhanced Airdrop Contract", function () {
    let Airdrop, airdrop, TestToken, testToken, owner, addr1, addr2, addr3;
    const REGISTRATION_DURATION = 60 * 60 * 24 * 7; // 7 días
    const CLAIM_DELAY = 60 * 60 * 24; // 1 día
    const CLAIM_DURATION = 60 * 60 * 24 * 30; // 30 días (0 = ilimitado)
    const AIRDROP_AMOUNT = ethers.parseEther("5"); // 5 tokens fijos

    beforeEach(async function () {
        // Obtener cuentas de prueba
        [owner, addr1, addr2, addr3] = await ethers.getSigners();

        // Desplegar un contrato ERC20 de prueba
        TestToken = await ethers.getContractFactory("contracts/TestToken.sol:TestToken");
        testToken = await TestToken.deploy("Test Token", "TTK", ethers.parseEther("1000000"));
        await testToken.waitForDeployment();

        // Desplegar el contrato Airdrop
        Airdrop = await ethers.getContractFactory("Airdrop");
        airdrop = await Airdrop.deploy(
            await testToken.getAddress(),
            REGISTRATION_DURATION,
            CLAIM_DELAY,
            CLAIM_DURATION
        );
        await airdrop.waitForDeployment();
    });

    describe("Deployment", function () {
        it("Should set the correct owner", async function () {
            expect(await airdrop.owner()).to.equal(owner.address);
        });

        it("Should set the correct token address", async function () {
            expect(await airdrop.token()).to.equal(await testToken.getAddress());
        });

        it("Should set the correct airdrop amount (5 tokens)", async function () {
            expect(await airdrop.airdropAmount()).to.equal(AIRDROP_AMOUNT);
        });

        it("Should set the correct time parameters", async function () {
            const blockTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
            
            expect(await airdrop.registrationEndTime()).to.be.closeTo(
                blockTimestamp + REGISTRATION_DURATION, 5
            );
            expect(await airdrop.claimStartTime()).to.be.closeTo(
                blockTimestamp + REGISTRATION_DURATION + CLAIM_DELAY, 5
            );
            expect(await airdrop.claimEndTime()).to.be.closeTo(
                blockTimestamp + REGISTRATION_DURATION + CLAIM_DELAY + CLAIM_DURATION, 5
            );
        });

        it("Should initialize counters to zero", async function () {
            expect(await airdrop.registeredUserCount()).to.equal(0);
            expect(await airdrop.claimedUserCount()).to.equal(0);
            expect(await airdrop.totalTokensClaimed()).to.equal(0);
        });
    });

    describe("Contract Funding", function () {
        it("Should allow owner to fund the contract", async function () {
            const fundAmount = ethers.parseEther("1000");
            
            // Aprobar tokens al contrato
            await testToken.approve(await airdrop.getAddress(), fundAmount);
            
            await expect(airdrop.fundContract(fundAmount))
                .to.emit(airdrop, "ContractFunded")
                .withArgs(owner.address, fundAmount);
                
            expect(await testToken.balanceOf(await airdrop.getAddress())).to.equal(fundAmount);
        });

        it("Should revert if non-owner tries to fund", async function () {
            const fundAmount = ethers.parseEther("100");
            await testToken.transfer(addr1.address, fundAmount);
            await testToken.connect(addr1).approve(await airdrop.getAddress(), fundAmount);
            
            await expect(airdrop.connect(addr1).fundContract(fundAmount))
                .to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should revert with zero amount", async function () {
            await expect(airdrop.fundContract(0))
                .to.be.revertedWithCustomError(airdrop, "InvalidAmount");
        });

        it("Should revert with insufficient allowance", async function () {
            const fundAmount = ethers.parseEther("100");
            
            await expect(airdrop.fundContract(fundAmount))
                .to.be.revertedWith("Airdrop: Insufficient allowance");
        });
    });

    describe("Registration", function () {
        it("Should allow a user to register", async function () {
            await expect(airdrop.connect(addr1).register())
                .to.emit(airdrop, "UserRegistered")
                .withArgs(addr1.address, await ethers.provider.getBlock("latest").then(b => b.timestamp + 1));
                
            expect(await airdrop.isRegistered(addr1.address)).to.be.true;
            expect(await airdrop.registeredUserCount()).to.equal(1);
        });

        it("Should not allow a user to register twice", async function () {
            await airdrop.connect(addr1).register();
            
            await expect(airdrop.connect(addr1).register())
                .to.be.revertedWithCustomError(airdrop, "AlreadyRegistered");
        });

        it("Should not allow registration after the registration period ends", async function () {
            await advanceTime(REGISTRATION_DURATION + 1);
            
            await expect(airdrop.connect(addr1).register())
                .to.be.revertedWithCustomError(airdrop, "RegistrationClosed");
        });

        it("Should not allow blacklisted users to register", async function () {
            await airdrop.blacklistUser(addr1.address);
            
            await expect(airdrop.connect(addr1).register())
                .to.be.revertedWithCustomError(airdrop, "UserIsBlacklisted");
        });

        it("Should not allow registration when paused", async function () {
            await airdrop.pause();
            
            await expect(airdrop.connect(addr1).register())
                .to.be.revertedWith("Pausable: paused");
        });
    });

    describe("Claiming", function () {
        beforeEach(async function () {
            // Fund contract and register user for claiming tests
            const fundAmount = ethers.parseEther("1000");
            await testToken.approve(await airdrop.getAddress(), fundAmount);
            await airdrop.fundContract(fundAmount);
            
            await airdrop.connect(addr1).register();
        });

        it("Should not allow claiming before the claim period starts", async function () {
            await expect(airdrop.connect(addr1).claim())
                .to.be.revertedWithCustomError(airdrop, "ClaimNotStarted");
        });

        it("Should not allow an unregistered user to claim", async function () {
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);
            
            await expect(airdrop.connect(addr2).claim())
                .to.be.revertedWithCustomError(airdrop, "NotRegistered");
        });

        it("Should allow a registered user to claim their tokens", async function () {
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);

            const initialBalance = await testToken.balanceOf(addr1.address);
            
            await expect(airdrop.connect(addr1).claim())
                .to.emit(airdrop, "TokensClaimed")
                .withArgs(addr1.address, AIRDROP_AMOUNT, await ethers.provider.getBlock("latest").then(b => b.timestamp + 1));

            const finalBalance = await testToken.balanceOf(addr1.address);
            expect(finalBalance - initialBalance).to.equal(AIRDROP_AMOUNT);
            expect(await airdrop.hasClaimed(addr1.address)).to.be.true;
            expect(await airdrop.claimedUserCount()).to.equal(1);
            expect(await airdrop.totalTokensClaimed()).to.equal(AIRDROP_AMOUNT);
        });

        it("Should not allow a user to claim twice", async function () {
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);
            await airdrop.connect(addr1).claim();
            
            await expect(airdrop.connect(addr1).claim())
                .to.be.revertedWithCustomError(airdrop, "AlreadyClaimed");
        });

        it("Should not allow claiming after claim period expires", async function () {
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + CLAIM_DURATION + 1);
            
            await expect(airdrop.connect(addr1).claim())
                .to.be.revertedWithCustomError(airdrop, "ClaimExpired");
        });

        it("Should fail to claim if contract has insufficient funds", async function () {
            // Withdraw all tokens from contract
            await airdrop.withdrawRemainingTokens();
            
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);
            
            await expect(airdrop.connect(addr1).claim())
                .to.be.revertedWithCustomError(airdrop, "InsufficientContractBalance");
        });

        it("Should not allow blacklisted users to claim", async function () {
            await airdrop.blacklistUser(addr1.address);
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);
            
            await expect(airdrop.connect(addr1).claim())
                .to.be.revertedWithCustomError(airdrop, "UserIsBlacklisted");
        });
    });

    describe("View Functions", function () {
        beforeEach(async function () {
            // Setup some test data
            const fundAmount = ethers.parseEther("1000");
            await testToken.approve(await airdrop.getAddress(), fundAmount);
            await airdrop.fundContract(fundAmount);
            
            await airdrop.connect(addr1).register();
            await airdrop.connect(addr2).register();
        });

        it("Should return correct airdrop info", async function () {
            const info = await airdrop.getAirdropInfo();
            
            expect(info.registeredUsersCount).to.equal(2);
            expect(info.claimedUsersCount).to.equal(0);
            expect(info._airdropAmount).to.equal(AIRDROP_AMOUNT);
            expect(info._contractBalance).to.equal(ethers.parseEther("1000"));
            expect(info._isRegistrationOpen).to.be.true;
            expect(info._isClaimOpen).to.be.false;
        });

        it("Should return correct user info", async function () {
            const userInfo = await airdrop.getUserInfo(addr1.address);
            
            expect(userInfo._isRegistered).to.be.true;
            expect(userInfo._hasClaimed).to.be.false;
            expect(userInfo._canClaim).to.be.false; // Claim period hasn't started
            expect(userInfo._isBlacklisted).to.be.false;
        });

        it("Should return correct time info", async function () {
            const timeInfo = await airdrop.getTimeInfo();
            
            expect(timeInfo.timeUntilRegistrationEnd).to.be.greaterThan(0);
            expect(timeInfo.timeUntilClaimStart).to.be.greaterThan(REGISTRATION_DURATION);
        });

        it("Should return registered users with pagination", async function () {
            const users = await airdrop.getRegisteredUsers(0, 10);
            
            expect(users.length).to.equal(2);
            expect(users).to.include(addr1.address);
            expect(users).to.include(addr2.address);
        });

        it("Should return estimated tokens needed", async function () {
            const estimated = await airdrop.getEstimatedTokensNeeded();
            
            expect(estimated).to.equal(BigInt(2) * AIRDROP_AMOUNT);
        });

        it("Should return user counts", async function () {
            const counts = await airdrop.getUserCounts();
            
            expect(counts.totalRegistered).to.equal(2);
            expect(counts.totalClaimed).to.equal(0);
            expect(counts.totalBlacklisted).to.equal(0);
            expect(counts.pendingClaims).to.equal(2);
        });
    });

    describe("Blacklist Management", function () {
        it("Should allow owner to blacklist a user", async function () {
            await expect(airdrop.blacklistUser(addr1.address))
                .to.emit(airdrop, "UserBlacklisted")
                .withArgs(addr1.address);
                
            const userInfo = await airdrop.getUserInfo(addr1.address);
            expect(userInfo._isBlacklisted).to.be.true;
        });

        it("Should allow owner to unblacklist a user", async function () {
            await airdrop.blacklistUser(addr1.address);
            
            await expect(airdrop.unblacklistUser(addr1.address))
                .to.emit(airdrop, "UserUnblacklisted")
                .withArgs(addr1.address);
                
            const userInfo = await airdrop.getUserInfo(addr1.address);
            expect(userInfo._isBlacklisted).to.be.false;
        });

        it("Should not allow non-owner to blacklist", async function () {
            await expect(airdrop.connect(addr1).blacklistUser(addr2.address))
                .to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should not allow blacklisting zero address", async function () {
            await expect(airdrop.blacklistUser(ethers.ZeroAddress))
                .to.be.revertedWith("Airdrop: Cannot blacklist zero address");
        });
    });

    describe("Pause/Unpause", function () {
        it("Should allow owner to pause and unpause", async function () {
            await airdrop.pause();
            expect(await airdrop.paused()).to.be.true;
            
            await airdrop.unpause();
            expect(await airdrop.paused()).to.be.false;
        });

        it("Should not allow non-owner to pause", async function () {
            await expect(airdrop.connect(addr1).pause())
                .to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should prevent registration when paused", async function () {
            await airdrop.pause();
            
            await expect(airdrop.connect(addr1).register())
                .to.be.revertedWith("Pausable: paused");
        });
    });

    describe("Withdrawal Functions", function () {
        beforeEach(async function () {
            // Fund the contract
            const fundAmount = ethers.parseEther("1000");
            await testToken.approve(await airdrop.getAddress(), fundAmount);
            await airdrop.fundContract(fundAmount);
        });

        it("Should allow owner to withdraw remaining tokens", async function () {
            const initialOwnerBalance = await testToken.balanceOf(owner.address);
            const contractBalance = await testToken.balanceOf(await airdrop.getAddress());

            await expect(airdrop.withdrawRemainingTokens())
                .to.emit(airdrop, "TokensWithdrawn")
                .withArgs(owner.address, contractBalance);

            const finalOwnerBalance = await testToken.balanceOf(owner.address);
            expect(await testToken.balanceOf(await airdrop.getAddress())).to.equal(0);
            expect(finalOwnerBalance - initialOwnerBalance).to.equal(contractBalance);
        });

        it("Should allow emergency withdrawal", async function () {
            const withdrawAmount = ethers.parseEther("500");
            const initialBalance = await testToken.balanceOf(addr3.address);

            await expect(airdrop.emergencyWithdraw(addr3.address, withdrawAmount))
                .to.emit(airdrop, "EmergencyWithdrawal")
                .withArgs(addr3.address, withdrawAmount);

            const finalBalance = await testToken.balanceOf(addr3.address);
            expect(finalBalance - initialBalance).to.equal(withdrawAmount);
        });

        it("Should not allow non-owner to withdraw", async function () {
            await expect(airdrop.connect(addr1).withdrawRemainingTokens())
                .to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should not allow emergency withdrawal to zero address", async function () {
            await expect(airdrop.emergencyWithdraw(ethers.ZeroAddress, ethers.parseEther("100")))
                .to.be.revertedWith("Airdrop: Cannot withdraw to zero address");
        });

        it("Should not allow emergency withdrawal of more than balance", async function () {
            const excessiveAmount = ethers.parseEther("2000");
            
            await expect(airdrop.emergencyWithdraw(addr3.address, excessiveAmount))
                .to.be.revertedWith("Airdrop: Insufficient balance");
        });
    });

    describe("Edge Cases and Error Handling", function () {
        it("Should handle zero registration duration in constructor", async function () {
            await expect(
                Airdrop.deploy(
                    await testToken.getAddress(),
                    0, // Invalid duration
                    CLAIM_DELAY,
                    CLAIM_DURATION
                )
            ).to.be.revertedWith("Airdrop: Registration duration must be greater than zero");
        });

        it("Should handle zero token address in constructor", async function () {
            await expect(
                Airdrop.deploy(
                    ethers.ZeroAddress,
                    REGISTRATION_DURATION,
                    CLAIM_DELAY,
                    CLAIM_DURATION
                )
            ).to.be.revertedWith("Airdrop: Token address cannot be zero");
        });

        it("Should handle unlimited claim duration", async function () {
            const unlimitedAirdrop = await Airdrop.deploy(
                await testToken.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                0 // Unlimited duration
            );
            
            expect(await unlimitedAirdrop.claimEndTime()).to.equal(0);
        });

        it("Should handle empty user lists in pagination", async function () {
            const users = await airdrop.getRegisteredUsers(0, 10);
            expect(users.length).to.equal(0);
        });

        it("Should handle pagination beyond available users", async function () {
            await airdrop.connect(addr1).register();
            
            const users = await airdrop.getRegisteredUsers(10, 10);
            expect(users.length).to.equal(0);
        });
    });

    describe("Integration Test", function () {
        it("Should handle complete airdrop lifecycle", async function () {
            // 1. Fund contract
            const fundAmount = ethers.parseEther("1000");
            await testToken.approve(await airdrop.getAddress(), fundAmount);
            await airdrop.fundContract(fundAmount);

            // 2. Users register
            await airdrop.connect(addr1).register();
            await airdrop.connect(addr2).register();

            // 3. Wait for claim period
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);

            // 4. Users claim
            await airdrop.connect(addr1).claim();
            await airdrop.connect(addr2).claim();

            // 5. Verify final state
            expect(await airdrop.claimedUserCount()).to.equal(2);
            expect(await airdrop.totalTokensClaimed()).to.equal(BigInt(2) * AIRDROP_AMOUNT);
            expect(await testToken.balanceOf(addr1.address)).to.equal(AIRDROP_AMOUNT);
            expect(await testToken.balanceOf(addr2.address)).to.equal(AIRDROP_AMOUNT);

            // 6. Owner withdraws remaining tokens
            const remainingBalance = await testToken.balanceOf(await airdrop.getAddress());
            await airdrop.withdrawRemainingTokens();
            expect(await testToken.balanceOf(await airdrop.getAddress())).to.equal(0);
        });
    });
});

// Nota: Para que esta prueba funcione, necesitas un contrato TestToken.sol.
// Puedes usar una implementación simple de ERC20 de OpenZeppelin.
// Ejemplo de contracts/TestToken.sol:
/*
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}
*/
