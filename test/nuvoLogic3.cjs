const { expect } = require("chai");
const hardhat = require("hardhat");

describe("SmartStaking", function () {
    let ethers, SmartStaking, nuvo, owner, treasury, user1, user2, other;
    let MIN_DEPOSIT, MAX_DEPOSIT, DAILY_WITHDRAWAL_LIMIT;

    beforeEach(async function () {
        ethers = hardhat.ethers;
        [owner, treasury, user1, user2, other] = await ethers.getSigners();
        SmartStaking = await ethers.getContractFactory("SmartStaking");
        nuvo = await SmartStaking.deploy(treasury.address);

        // Usando ethers v6
        MIN_DEPOSIT = ethers.parseEther("5");
        MAX_DEPOSIT = ethers.parseEther("10000");
        DAILY_WITHDRAWAL_LIMIT = ethers.parseEther("1000");
    });

    it("should set the correct treasury address", async function () {
        expect(await nuvo.treasury()).to.equal(treasury.address);
    });

    it("should allow deposit within limits and emit events", async function () {
        await expect(
            nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT })
        ).to.emit(nuvo, "DepositMade");
        expect(await nuvo.uniqueUsersCount()).to.equal(1n);
        
        // En ethers v6, no hay .sub o .mul, usamos operadores aritméticos normales
        const commission = MIN_DEPOSIT * BigInt(600) / BigInt(10000);
        const depositAmount = MIN_DEPOSIT - commission;
        expect(await nuvo.totalPoolBalance()).to.equal(depositAmount);
    });

    it("should allow deposit with lockup periods", async function () {
        // Test 30-day lockup
        await expect(
            nuvo.connect(user1).deposit(30, { value: MIN_DEPOSIT })
        ).to.emit(nuvo, "DepositMade");
        
        // Test 90-day lockup
        await expect(
            nuvo.connect(user1).deposit(90, { value: MIN_DEPOSIT })
        ).to.emit(nuvo, "DepositMade");
        
        // Test 180-day lockup
        await expect(
            nuvo.connect(user1).deposit(180, { value: MIN_DEPOSIT })
        ).to.emit(nuvo, "DepositMade");
        
        // Test 365-day lockup
        await expect(
            nuvo.connect(user1).deposit(365, { value: MIN_DEPOSIT })
        ).to.emit(nuvo, "DepositMade");
        
        const deposits = await nuvo.getUserDeposits(user1.address);
        expect(deposits.length).to.equal(4);
        expect(deposits[0].lockupDuration).to.equal(30 * 24 * 3600); // 30 days in seconds
        expect(deposits[1].lockupDuration).to.equal(90 * 24 * 3600); // 90 days in seconds
        expect(deposits[2].lockupDuration).to.equal(180 * 24 * 3600); // 180 days in seconds
        expect(deposits[3].lockupDuration).to.equal(365 * 24 * 3600); // 365 days in seconds
    });

    it("should revert deposit with invalid lockup duration", async function () {
        await expect(
            nuvo.connect(user1).deposit(45, { value: MIN_DEPOSIT })
        ).to.be.revertedWithCustomError(nuvo, "InvalidLockupDuration");
        
        await expect(
            nuvo.connect(user1).deposit(100, { value: MIN_DEPOSIT })
        ).to.be.revertedWithCustomError(nuvo, "InvalidLockupDuration");
    });

    it("should revert deposit below minimum", async function () {
        await expect(
            nuvo.connect(user1).deposit(0, { value: ethers.parseEther("1") })
        ).to.be.revertedWithCustomError(nuvo, "DepositTooLow").withArgs(ethers.parseEther("1"), MIN_DEPOSIT);
    });

    it("should revert deposit above maximum", async function () {
        await expect(
            nuvo.connect(user1).deposit(0, { value: MAX_DEPOSIT })
        ).to.not.be.reverted;
        
        // Para valores que exceden el máximo
        await expect(
            nuvo.connect(user1).deposit(0, { value: ethers.parseEther("10001") })
        ).to.be.revertedWithCustomError(nuvo, "DepositTooHigh").withArgs(ethers.parseEther("10001"), MAX_DEPOSIT);
    });

    it("should revert if max deposits per user is reached", async function () {
        const MAX_DEPOSITS_PER_USER = 300; // Constant from contract
        for (let i = 0; i < MAX_DEPOSITS_PER_USER; i++) {
            await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        }
        await expect(
            nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT })
        ).to.be.revertedWithCustomError(nuvo, "MaxDepositsReached").withArgs(user1.address, MAX_DEPOSITS_PER_USER);
    });

    it("should calculate rewards correctly with time bonus", async function () {
        const initialDeposit = ethers.parseEther("100");
        const commission = (initialDeposit * BigInt(600)) / BigInt(10000);
        const depositAmount = initialDeposit - commission;

        await nuvo.connect(user1).deposit(0, { value: initialDeposit });
        
        // Avanzar 30 días para obtener el bonus del 0.5%
        await ethers.provider.send("evm_increaseTime", [30 * 24 * 3600]);
        await ethers.provider.send("evm_mine");

        const rewards = await nuvo.calculateRewards(user1.address);
        const baseReward = (depositAmount * BigInt(100) * BigInt(30 * 24)) / BigInt(1000000);
        const bonus = (baseReward * BigInt(50)) / BigInt(10000);
        const expectedRewards = baseReward + bonus;

        // Usamos una tolerancia para comparar por la posible imprecisión
        expect(rewards).to.be.closeTo(expectedRewards, ethers.parseEther("0.001"));
    });

    it("should calculate higher rewards for lockup periods", async function () {
        const depositAmount = ethers.parseEther("100");
        
        // Deposit without lockup
        await nuvo.connect(user1).deposit(0, { value: depositAmount });
        
        // Deposit with 365-day lockup
        await nuvo.connect(user2).deposit(365, { value: depositAmount });
        
        // Advance time by 24 hours
        await ethers.provider.send("evm_increaseTime", [24 * 3600]);
        await ethers.provider.send("evm_mine");

        const rewardsNoLockup = await nuvo.calculateRewards(user1.address);
        const rewardsWithLockup = await nuvo.calculateRewards(user2.address);
        
        // Lockup should provide higher rewards
        expect(rewardsWithLockup).to.be.gt(rewardsNoLockup);
    });

    it("should allow compound rewards", async function () {
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        
        // Advance time to generate rewards
        await ethers.provider.send("evm_increaseTime", [3600 * 24]); // 24 hours
        await ethers.provider.send("evm_mine");
        
        const rewardsBefore = await nuvo.calculateRewards(user1.address);
        const totalDepositedBefore = await nuvo.getTotalDeposit(user1.address);
        
        await expect(nuvo.connect(user1).compound())
            .to.emit(nuvo, "RewardsCompounded")
            .withArgs(user1.address, rewardsBefore);
        
        const totalDepositedAfter = await nuvo.getTotalDeposit(user1.address);
        const rewardsAfter = await nuvo.calculateRewards(user1.address);
        
        // Total deposited should increase by rewards amount
        expect(totalDepositedAfter).to.equal(totalDepositedBefore + rewardsBefore);
        
        // Rewards should be reset to 0 after compounding
        expect(rewardsAfter).to.equal(0);
    });

    it("should revert compound if no rewards available", async function () {
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        
        // No time passed, no rewards
        await expect(
            nuvo.connect(user1).compound()
        ).to.be.revertedWithCustomError(nuvo, "NoRewardsAvailable");
    });

    it("should calculate rewards correctly", async function () {
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        // Simulate time passing
        await ethers.provider.send("evm_increaseTime", [3600 * 10]); // 10 hours
        await ethers.provider.send("evm_mine");
        const rewards = await nuvo.calculateRewards(user1.address);
        expect(rewards).to.be.gt(0);
    });

    it("should allow withdraw of rewards and update lastClaimTime", async function () {
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        await ethers.provider.send("evm_increaseTime", [3600 * 10]);
        await ethers.provider.send("evm_mine");
        const before = await ethers.provider.getBalance(user1.address);
        await expect(nuvo.connect(user1).withdraw())
            .to.emit(nuvo, "WithdrawalMade");
        const after = await ethers.provider.getBalance(user1.address);
        expect(after).to.be.gt(before);
    });

    it("should revert withdraw if no rewards are available", async function () {
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        // Sin pasar el tiempo, no hay recompensas
        await expect(
            nuvo.connect(user1).withdraw()
        ).to.be.revertedWithCustomError(nuvo, "NoRewardsAvailable");
    });

    it("should revert withdraw if funds are locked", async function () {
        await nuvo.connect(user1).deposit(30, { value: MIN_DEPOSIT });
        
        // Advance time but not enough to unlock (less than 30 days)
        await ethers.provider.send("evm_increaseTime", [15 * 24 * 3600]); // 15 days
        await ethers.provider.send("evm_mine");
        
        await expect(
            nuvo.connect(user1).withdraw()
        ).to.be.revertedWithCustomError(nuvo, "FundsAreLocked");
    });

    it("should allow withdraw after lockup period expires", async function () {
        await nuvo.connect(user1).deposit(30, { value: MIN_DEPOSIT });
        
        // Advance time past lockup period
        await ethers.provider.send("evm_increaseTime", [31 * 24 * 3600]); // 31 days
        await ethers.provider.send("evm_mine");
        
        await expect(nuvo.connect(user1).withdraw())
            .to.emit(nuvo, "WithdrawalMade");
    });

    it("should allow withdrawAll and delete user", async function () {
        // Depositar y agregar un balance adicional para cubrir las recompensas
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        await nuvo.connect(owner).addBalance({ value: ethers.parseEther("10") });
        
        await ethers.provider.send("evm_increaseTime", [3600 * 10]);
        await ethers.provider.send("evm_mine");
        await expect(nuvo.connect(user1).withdrawAll())
            .to.emit(nuvo, "WithdrawalMade");
        const info = await nuvo.getUserInfo(user1.address);
        expect(info.totalDeposited).to.equal(0);
    });

    it("should enforce daily withdrawal limits", async function () {
        // Deposit a large amount
        const largeDeposit = ethers.parseEther("2000");
        await nuvo.connect(user1).deposit(0, { value: largeDeposit });
        await nuvo.connect(owner).addBalance({ value: ethers.parseEther("1000") });
        
        // Generate significant rewards
        await ethers.provider.send("evm_increaseTime", [24 * 3600]); // 24 hours
        await ethers.provider.send("evm_mine");
        
        // Try to withdraw all - should fail due to daily limit
        await expect(
            nuvo.connect(user1).withdrawAll()
        ).to.be.revertedWithCustomError(nuvo, "DailyWithdrawalLimitExceeded");
    });

    it("should reset daily withdrawal limit after 24 hours", async function () {
        await nuvo.connect(user1).deposit(0, { value: ethers.parseEther("500") });
        await nuvo.connect(owner).addBalance({ value: ethers.parseEther("100") });
        
        // Generate rewards
        await ethers.provider.send("evm_increaseTime", [12 * 3600]); // 12 hours
        await ethers.provider.send("evm_mine");
        
        // First withdrawal
        await nuvo.connect(user1).withdraw();
        
        // Advance time by more than 24 hours
        await ethers.provider.send("evm_increaseTime", [25 * 3600]); // 25 hours
        await ethers.provider.send("evm_mine");
        
        // Should be able to withdraw again
        await expect(nuvo.connect(user1).withdraw()).to.not.be.reverted;
    });

    it("should revert withdrawAll if user has no deposits", async function () {
        await expect(
            nuvo.connect(user1).withdrawAll()
        ).to.be.revertedWithCustomError(nuvo, "NoDepositsFound");
    });

    it("should allow emergencyUserWithdraw when paused", async function () {
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        await nuvo.connect(owner).pause();
        await expect(nuvo.connect(user1).emergencyUserWithdraw())
            .to.emit(nuvo, "EmergencyWithdrawUser");
        const info = await nuvo.getUserInfo(user1.address);
        expect(info.totalDeposited).to.equal(0);
    });

    it("should allow owner to emergencyWithdraw contract balance", async function () {
        // Primero depositamos fondos
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
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

    it("should allow unpausing and resume normal operations", async function () {
        await nuvo.connect(owner).pause();
        await expect(nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT })).to.be.revertedWith("Pausable: paused");
        
        await nuvo.connect(owner).unpause();
        await expect(nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT })).to.not.be.reverted;
    });

    it("should migrate contract and block further actions", async function () {
        await nuvo.connect(owner).migrateToNewContract(other.address);
        await expect(
            nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT })
        ).to.be.revertedWithCustomError(nuvo, "ContractIsMigrated");
    });

    it("should accumulate pendingCommission if commission transfer fails", async function () {
        // Crear contrato Rejector manualmente en vez de usar getContractFactory
        const RejectorFactory = await ethers.getContractFactory("Rejector");
        const rejector = await RejectorFactory.deploy();
        
        // Espera a que se despliegue
        await rejector.waitForDeployment();
        
        await nuvo.connect(owner).changeTreasuryAddress(await rejector.getAddress());
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        expect(await nuvo.pendingCommission()).to.be.gt(0);
    });

    it("should allow owner to withdraw pendingCommission", async function () {
        // Crear contrato Rejector manualmente
        const RejectorFactory = await ethers.getContractFactory("Rejector");
        const rejector = await RejectorFactory.deploy();
        
        // Espera a que se despliegue
        await rejector.waitForDeployment();
        
        await nuvo.connect(owner).changeTreasuryAddress(await rejector.getAddress());
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        
        // Set treasury back to a valid address
        await nuvo.connect(owner).changeTreasuryAddress(treasury.address);
        await expect(nuvo.connect(owner).withdrawPendingCommission())
            .to.emit(nuvo, "CommissionPaid");
        expect(await nuvo.pendingCommission()).to.equal(0);
    });

    it("should revert withdrawPendingCommission if none pending", async function () {
        await expect(nuvo.connect(owner).withdrawPendingCommission())
            .to.be.revertedWithCustomError(nuvo, "NoPendingCommission");
    });

    it("should revert if non-treasury sends ETH to contract", async function () {
        await expect(
            user1.sendTransaction({ to: await nuvo.getAddress(), value: ethers.parseEther("1") })
        ).to.be.revertedWithCustomError(nuvo, "UnauthorizedSender");
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
        ).to.be.revertedWithCustomError(nuvo, "DepositTooLow").withArgs(0, 1);
    });

    it("should return correct contract version", async function () {
        expect(await nuvo.getContractVersion()).to.equal(3n);
    });

    it("should revert with InvalidAddress for zero address", async function () {
        const zeroAddress = ethers.ZeroAddress;
        await expect(nuvo.connect(owner).changeTreasuryAddress(zeroAddress)).to.be.revertedWithCustomError(nuvo, "InvalidAddress");
        await expect(nuvo.connect(owner).migrateToNewContract(zeroAddress)).to.be.revertedWithCustomError(nuvo, "InvalidAddress");
    });

    // Tests para funciones de vista
    it("should return correct total deposit for user", async function () {
        const deposit1 = ethers.parseEther("100");
        const deposit2 = ethers.parseEther("200");
        
        await nuvo.connect(user1).deposit(0, { value: deposit1 });
        await nuvo.connect(user1).deposit(30, { value: deposit2 });
        
        const totalDeposit = await nuvo.getTotalDeposit(user1.address);
        
        // Calculate expected total after commissions
        const commission1 = (deposit1 * BigInt(600)) / BigInt(10000);
        const commission2 = (deposit2 * BigInt(600)) / BigInt(10000);
        const expectedTotal = (deposit1 - commission1) + (deposit2 - commission2);
        
        expect(totalDeposit).to.equal(expectedTotal);
    });

    it("should return user deposits array correctly", async function () {
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        await nuvo.connect(user1).deposit(90, { value: ethers.parseEther("100") });
        
        const deposits = await nuvo.getUserDeposits(user1.address);
        
        expect(deposits.length).to.equal(2);
        expect(deposits[0].lockupDuration).to.equal(0);
        expect(deposits[1].lockupDuration).to.equal(90 * 24 * 3600);
    });

    it("should return comprehensive user info", async function () {
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        
        // Advance time to generate rewards
        await ethers.provider.send("evm_increaseTime", [3600 * 10]); // 10 hours
        await ethers.provider.send("evm_mine");
        
        const userInfo = await nuvo.getUserInfo(user1.address);
        
        expect(userInfo.totalDeposited).to.be.gt(0);
        expect(userInfo.pendingRewards).to.be.gt(0);
        expect(userInfo.lastWithdraw).to.equal(0); // No withdrawals yet
    });

    it("should return correct contract balance", async function () {
        const initialBalance = await nuvo.getContractBalance();
        
        await nuvo.connect(user1).deposit(0, { value: MIN_DEPOSIT });
        
        const afterDepositBalance = await nuvo.getContractBalance();
        expect(afterDepositBalance).to.be.gt(initialBalance);
    });

    it("should return correct contract version", async function () {
        const version = await nuvo.getContractVersion();
        expect(version).to.equal(3n);
    });

    it("should revert getUserDeposits with invalid address", async function () {
        await expect(
            nuvo.getUserDeposits(ethers.ZeroAddress)
        ).to.be.revertedWithCustomError(nuvo, "InvalidAddress");
    });

    it("should handle multiple lockup periods correctly", async function () {
        // Test all lockup periods and their ROI rates
        const depositAmount = ethers.parseEther("100");
        
        await nuvo.connect(user1).deposit(0, { value: depositAmount });    // No lockup
        await nuvo.connect(user2).deposit(30, { value: depositAmount });   // 30 days
        await nuvo.connect(other).deposit(365, { value: depositAmount });  // 365 days
        
        // Advance time
        await ethers.provider.send("evm_increaseTime", [24 * 3600]); // 24 hours
        await ethers.provider.send("evm_mine");
        
        const rewardsNoLockup = await nuvo.calculateRewards(user1.address);
        const rewards30Days = await nuvo.calculateRewards(user2.address);
        const rewards365Days = await nuvo.calculateRewards(other.address);
        
        // Higher lockup periods should yield higher rewards
        expect(rewards30Days).to.be.gt(rewardsNoLockup);
        expect(rewards365Days).to.be.gt(rewards30Days);
    });

    it("should handle receive function correctly", async function () {
        // Treasury should be able to send ETH
        await expect(
            treasury.sendTransaction({ 
                to: await nuvo.getAddress(), 
                value: ethers.parseEther("1") 
            })
        ).to.not.be.reverted;
        
        // Non-treasury should be rejected
        await expect(
            user1.sendTransaction({ 
                to: await nuvo.getAddress(), 
                value: ethers.parseEther("1") 
            })
        ).to.be.revertedWithCustomError(nuvo, "UnauthorizedSender");
    });

    it("should handle edge case: withdraw with exactly daily limit", async function () {
        // Deposit exactly the daily withdrawal limit
        await nuvo.connect(user1).deposit(0, { value: DAILY_WITHDRAWAL_LIMIT });
        await nuvo.connect(owner).addBalance({ value: ethers.parseEther("100") });
        
        // Generate small rewards
        await ethers.provider.send("evm_increaseTime", [3600]); // 1 hour
        await ethers.provider.send("evm_mine");
        
        // Should be able to withdraw rewards (small amount)
        await expect(nuvo.connect(user1).withdraw()).to.not.be.reverted;
    });
});

