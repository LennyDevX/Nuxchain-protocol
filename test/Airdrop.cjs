const { expect } = require("chai");
const { ethers, network } = require("hardhat");

// Helper para avanzar el tiempo en la blockchain de prueba
async function advanceTime(seconds) {
    await network.provider.send("evm_increaseTime", [seconds]);
    await network.provider.send("evm_mine");
}

describe("Airdrop Contract", function () {
    let Airdrop, airdrop, TestToken, testToken, owner, addr1, addr2;
    const REGISTRATION_DURATION = 60 * 60 * 24; // 1 día
    const CLAIM_DELAY = 60 * 60 * 24; // 1 día
    const TOKENS_PER_USER = ethers.parseEther("100"); // 100 tokens con 18 decimales

    beforeEach(async function () {
        // Obtener cuentas de prueba
        [owner, addr1, addr2] = await ethers.getSigners();

        // Desplegar un contrato ERC20 de prueba (TestToken)
        TestToken = await ethers.getContractFactory("TestToken");
        testToken = await TestToken.deploy("Test Token", "TTK", ethers.parseEther("1000000"));
        await testToken.waitForDeployment();
        const tokenAddress = await testToken.getAddress();

        // Desplegar el contrato Airdrop
        Airdrop = await ethers.getContractFactory("Airdrop");
        airdrop = await Airdrop.deploy(
            tokenAddress,
            REGISTRATION_DURATION,
            CLAIM_DELAY,
            TOKENS_PER_USER
        );
        await airdrop.waitForDeployment();
        const airdropAddress = await airdrop.getAddress();

        // Fondea el contrato de Airdrop con suficientes tokens
        await testToken.transfer(airdropAddress, ethers.parseEther("10000"));
    });

    describe("Deployment", function () {
        it("Should set the correct owner", async function () {
            expect(await airdrop.owner()).to.equal(owner.address);
        });

        it("Should set the correct token address", async function () {
            expect(await airdrop.token()).to.equal(await testToken.getAddress());
        });

        it("Should set the correct airdrop amount per user", async function () {
            expect(await airdrop.airdropAmount()).to.equal(TOKENS_PER_USER);
        });

        it("Should set the registration end time correctly", async function () {
            const block = await ethers.provider.getBlock("latest");
            const expectedEndTime = block.timestamp + REGISTRATION_DURATION;
            expect(await airdrop.registrationEndTime()).to.be.closeTo(expectedEndTime, 2);
        });
    });

    describe("Registration", function () {
        it("Should allow a user to register", async function () {
            await expect(airdrop.connect(addr1).register())
                .to.emit(airdrop, "UserRegistered")
                .withArgs(addr1.address);
            expect(await airdrop.isRegistered(addr1.address)).to.be.true;
            expect(await airdrop.registeredUserCount()).to.equal(1);
        });

        it("Should not allow a user to register twice", async function () {
            await airdrop.connect(addr1).register();
            await expect(airdrop.connect(addr1).register()).to.be.revertedWith("Airdrop: User already registered");
        });

        it("Should not allow registration after the registration period ends", async function () {
            await advanceTime(REGISTRATION_DURATION + 1);
            await expect(airdrop.connect(addr1).register()).to.be.revertedWith("Airdrop: Registration period has ended");
        });
    });

    describe("Claiming", function () {
        beforeEach(async function () {
            // addr1 se registra para las pruebas de reclamo
            await airdrop.connect(addr1).register();
        });

        it("Should not allow claiming before the claim period starts", async function () {
            await expect(airdrop.connect(addr1).claim()).to.be.revertedWith("Airdrop: Claim period has not started yet");
        });

        it("Should not allow an unregistered user to claim", async function () {
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);
            await expect(airdrop.connect(addr2).claim()).to.be.revertedWith("Airdrop: User is not registered");
        });

        it("Should allow a registered user to claim their tokens", async function () {
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);

            const initialBalance = await testToken.balanceOf(addr1.address);
            await expect(airdrop.connect(addr1).claim())
                .to.emit(airdrop, "TokensClaimed")
                .withArgs(addr1.address, TOKENS_PER_USER);

            const finalBalance = await testToken.balanceOf(addr1.address);
            expect(finalBalance - initialBalance).to.equal(TOKENS_PER_USER);
            expect(await airdrop.hasClaimed(addr1.address)).to.be.true;
        });

        it("Should not allow a user to claim twice", async function () {
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);
            await airdrop.connect(addr1).claim();
            await expect(airdrop.connect(addr1).claim()).to.be.revertedWith("Airdrop: Tokens already claimed");
        });

        it("Should fail to claim if contract has insufficient funds", async function () {
            // Vaciar el contrato de airdrop
            const airdropBalance = await testToken.balanceOf(await airdrop.getAddress());
            await airdrop.withdrawRemainingTokens();
            expect(await testToken.balanceOf(await airdrop.getAddress())).to.equal(0);

            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);
            await expect(airdrop.connect(addr1).claim()).to.be.revertedWith("Airdrop: Insufficient token balance in contract");
        });
    });

    describe("Withdrawal", function () {
        it("Should not allow a non-owner to withdraw tokens", async function () {
            await expect(airdrop.connect(addr1).withdrawRemainingTokens()).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should allow the owner to withdraw remaining tokens", async function () {
            const initialOwnerBalance = await testToken.balanceOf(owner.address);
            const contractBalance = await testToken.balanceOf(await airdrop.getAddress());

            await expect(airdrop.withdrawRemainingTokens())
                .to.emit(airdrop, "TokensWithdrawn")
                .withArgs(owner.address, contractBalance);

            const finalOwnerBalance = await testToken.balanceOf(owner.address);
            expect(await testToken.balanceOf(await airdrop.getAddress())).to.equal(0);
            expect(finalOwnerBalance - initialOwnerBalance).to.equal(contractBalance);
        });

        it("Should handle withdrawal when balance is zero", async function () {
            // Vaciar el contrato primero
            await airdrop.withdrawRemainingTokens();
            expect(await testToken.balanceOf(await airdrop.getAddress())).to.equal(0);

            // Intentar retirar de nuevo no debería revertir ni emitir evento
            const tx = await airdrop.withdrawRemainingTokens();
            const receipt = await tx.wait();
            expect(receipt.logs.length).to.equal(0); // No events should be emitted
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
