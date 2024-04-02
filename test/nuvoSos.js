const { expect } = require("chai");

describe("StakingContract", function () {
    let accounts;
    let owner;
    let nonOwner;
    let StakingContract;

    beforeEach(async () => {
        accounts = await ethers.getSigners();
        owner = accounts[0];
        nonOwner = accounts[1];

        const Contract = await ethers.getContractFactory("StakingContract");
        StakingContract = await Contract.deploy(accounts[0].address);
        await StakingContract.deployed();
    });

    // Pruebas de control de acceso

    it("no puede llamar a emergencyWithdraw por un no propietario", async function () {
        await expect(
            StakingContract.connect(nonOwner).emergencyWithdraw(nonOwner.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("no puede establecer la dirección de tesorería por un no propietario", async function () {
        await expect(
            StakingContract.connect(nonOwner).changeTreasuryAddress(nonOwner.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });
    

    it("no puede pausar el contrato por un no propietario", async function () {
        await expect(
            StakingContract.connect(nonOwner).pause()
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("no puede reanudar el contrato por un no propietario", async function () {
        await expect(
            StakingContract.connect(nonOwner).unpause()
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    // Pruebas de depósito y retiro

    it("revierte el depósito que excede el límite máximo", async function() {
      const maxDeposit = await StakingContract.MAX_DEPOSIT();
      const depositAmount = maxDeposit.add(10); // Excede MAX_DEPOSIT por 10
  
      await expect(
          StakingContract.connect(owner).deposit({ value: depositAmount })
      ).to.be.revertedWith("Deposit exceeds the maximum");
    });

    it("revierte el reclamo de recompensas sin recompensas acumuladas", async function () {
        await expect(
            StakingContract.connect(owner).claimRewards()
        ).to.be.revertedWith("No rewards to claim");
    });

    it("revierte el retiro de recompensas sin recompensas en el saldo del usuario", async function () {
        await expect(
            StakingContract.connect(owner).withdrawRewards()
        ).to.be.revertedWith("No claimed rewards to withdraw");
    });

    // Pruebas de cálculo de recompensas


    // Otras pruebas de seguridad

    // ... (Pruebas para vulnerabilidades de reentrada, desbordamiento/subdesbordamiento, etc.)
});
