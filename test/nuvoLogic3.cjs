const { expect } = require("chai");
const hardhat = require("hardhat");

describe("NuvoLogic", function () {
    let ethers, NuvoLogic, nuvo, owner, treasury, user1, user2, other;
    let MIN_DEPOSIT, MAX_DEPOSIT;

    beforeEach(async function () {
        ethers = hardhat.ethers;
        [owner, treasury, user1, user2, other] = await ethers.getSigners();
        NuvoLogic = await ethers.getContractFactory("contracts/nuvoLogic3.sol:NuvoLogic");
        nuvo = await NuvoLogic.deploy(treasury.address);
        
        // Usando ethers v6
        MIN_DEPOSIT = ethers.parseEther("5");
        MAX_DEPOSIT = ethers.parseEther("10000");
    });

    it("should set the correct treasury address", async function () {
        expect(await nuvo.treasury()).to.equal(treasury.address);
    });

    it("should allow deposit within limits and emit events", async function () {
        await expect(
            nuvo.connect(user1).deposit({ value: MIN_DEPOSIT })
        ).to.emit(nuvo, "DepositMade");
        expect(await nuvo.uniqueUsersCount()).to.equal(1n);
        
        // En ethers v6, no hay .sub o .mul, usamos operadores aritméticos normales
        const commission = MIN_DEPOSIT * BigInt(600) / BigInt(10000);
        const depositAmount = MIN_DEPOSIT - commission;
        expect(await nuvo.totalPoolBalance()).to.equal(depositAmount);
    });

    it("should revert deposit below minimum", async function () {
        await expect(
            nuvo.connect(user1).deposit({ value: ethers.parseEther("1") })
        ).to.be.revertedWith("Deposit below minimum");
    });

    it("should revert deposit above maximum", async function () {
        // En ethers v6, usamos .staticCall() directamente en la función
        await expect(
            nuvo.connect(user1).deposit.staticCall({ value: MAX_DEPOSIT })
        ).to.not.be.reverted;
        
        // Para valores que exceden el máximo
        await expect(
            nuvo.connect(user1).deposit.staticCall({ value: ethers.parseEther("10001") })
        ).to.be.revertedWith("Deposit exceeds maximum");
    });

    it("should calculate rewards correctly", async function () {
        await nuvo.connect(user1).deposit({ value: MIN_DEPOSIT });
        // Simulate time passing
        await ethers.provider.send("evm_increaseTime", [3600 * 10]); // 10 hours
        await ethers.provider.send("evm_mine");
        const rewards = await nuvo.calculateRewards(user1.address);
        expect(rewards).to.be.gt(0);
    });

    it("should allow withdraw of rewards and update lastClaimTime", async function () {
        await nuvo.connect(user1).deposit({ value: MIN_DEPOSIT });
        await ethers.provider.send("evm_increaseTime", [3600 * 10]);
        await ethers.provider.send("evm_mine");
        const before = await ethers.provider.getBalance(user1.address);
        await expect(nuvo.connect(user1).withdraw())
            .to.emit(nuvo, "WithdrawalMade");
        const after = await ethers.provider.getBalance(user1.address);
        expect(after).to.be.gt(before);
    });

    it("should allow withdrawAll and delete user", async function () {
        // Depositar y agregar un balance adicional para cubrir las recompensas
        await nuvo.connect(user1).deposit({ value: MIN_DEPOSIT });
        await nuvo.connect(owner).addBalance({ value: ethers.parseEther("10") });
        
        await ethers.provider.send("evm_increaseTime", [3600 * 10]);
        await ethers.provider.send("evm_mine");
        await expect(nuvo.connect(user1).withdrawAll())
            .to.emit(nuvo, "WithdrawalMade");
        const info = await nuvo.getUserInfo(user1.address);
        expect(info.totalDeposited).to.equal(0);
    });

    it("should allow emergencyUserWithdraw when paused", async function () {
        await nuvo.connect(user1).deposit({ value: MIN_DEPOSIT });
        await nuvo.connect(owner).pause();
        await expect(nuvo.connect(user1).emergencyUserWithdraw())
            .to.emit(nuvo, "EmergencyWithdrawUser");
        const info = await nuvo.getUserInfo(user1.address);
        expect(info.totalDeposited).to.equal(0);
    });

    it("should allow owner to emergencyWithdraw contract balance", async function () {
        // Primero depositamos fondos
        await nuvo.connect(user1).deposit({ value: MIN_DEPOSIT });
        await nuvo.connect(owner).pause();
        
        // Guardamos el balance inicial del destinatario
        const initialBalance = await ethers.provider.getBalance(other.address);
        
        // Obtenemos la dirección del contrato correctamente para ethers v6
        const contractAddress = await nuvo.getAddress();
        const contractBalance = await ethers.provider.getBalance(contractAddress);
        
        // Ejecutamos el emergencyWithdraw y verificamos el evento
        await expect(nuvo.connect(owner).emergencyWithdraw(other.address))
            .to.emit(nuvo, "EmergencyWithdrawOwner");
        
        // Verificamos que el contrato quede sin fondos
        expect(await ethers.provider.getBalance(contractAddress)).to.equal(0);
        
        // Verificamos que el destinatario recibió los fondos
        const finalBalance = await ethers.provider.getBalance(other.address);
        expect(finalBalance - initialBalance).to.equal(contractBalance);
    });

    it("should allow owner to change treasury address", async function () {
        await nuvo.connect(owner).changeTreasuryAddress(other.address);
        expect(await nuvo.treasury()).to.equal(other.address);
    });

    it("should migrate contract and block further actions", async function () {
        await nuvo.connect(owner).migrateToNewContract(other.address);
        await expect(
            nuvo.connect(user1).deposit({ value: MIN_DEPOSIT })
        ).to.be.revertedWith("Contract has been migrated");
    });

    it("should accumulate pendingCommission if commission transfer fails", async function () {
        // Crear contrato Rejector manualmente en vez de usar getContractFactory
        const RejectorFactory = await ethers.getContractFactory("Rejector");
        const rejector = await RejectorFactory.deploy();
        
        // Espera a que se despliegue
        await rejector.waitForDeployment();
        
        await nuvo.connect(owner).changeTreasuryAddress(await rejector.getAddress());
        await nuvo.connect(user1).deposit({ value: MIN_DEPOSIT });
        expect(await nuvo.pendingCommission()).to.be.gt(0);
    });

    it("should allow owner to withdraw pendingCommission", async function () {
        // Crear contrato Rejector manualmente
        const RejectorFactory = await ethers.getContractFactory("Rejector");
        const rejector = await RejectorFactory.deploy();
        
        // Espera a que se despliegue
        await rejector.waitForDeployment();
        
        await nuvo.connect(owner).changeTreasuryAddress(await rejector.getAddress());
        await nuvo.connect(user1).deposit({ value: MIN_DEPOSIT });
        
        // Set treasury back to a valid address
        await nuvo.connect(owner).changeTreasuryAddress(treasury.address);
        await expect(nuvo.connect(owner).withdrawPendingCommission())
            .to.emit(nuvo, "CommissionPaid");
        expect(await nuvo.pendingCommission()).to.equal(0);
    });

    it("should revert withdrawPendingCommission if none pending", async function () {
        await expect(nuvo.connect(owner).withdrawPendingCommission())
            .to.be.revertedWith("No pending commission");
    });

    it("should revert if non-treasury sends ETH to contract", async function () {
        await expect(
            user1.sendTransaction({ to: nuvo.getAddress(), value: ethers.parseEther("1") })
        ).to.be.revertedWith("Only treasury can send funds directly");
    });

    it("should allow owner to add balance", async function () {
        await expect(
            nuvo.connect(owner).addBalance({ value: ethers.parseEther("1") })
        ).to.emit(nuvo, "BalanceAdded");
        expect(await nuvo.totalPoolBalance()).to.equal(ethers.parseEther("1"));
    });

    it("should revert addBalance if not owner", async function () {
        await expect(
            nuvo.connect(user1).addBalance({ value: ethers.parseEther("1") })
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should revert addBalance if value is zero", async function () {
        await expect(
            nuvo.connect(owner).addBalance({ value: 0 })
        ).to.be.revertedWith("Amount must be greater than 0");
    });
});
