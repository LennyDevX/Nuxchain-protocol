const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingContract", function () {
  let StakingContract, staking;
  let owner, addr1, addr2, addrs;
  let _treasury;

  beforeEach(async function () {
      StakingContract = await ethers.getContractFactory("StakingContract");
      [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
      _treasury = owner.address; // assuming owner is the treasury

      staking = await StakingContract.deploy(_treasury);
  });

  it("Should deposit successfully and increase the total pool balance", async function () {
    // Make deposits from the owner account
    const depositAmount = ethers.utils.parseEther("100");
    await staking.connect(owner).deposit({ value: depositAmount });

    const depositInContract = await staking.getTotalDeposit(owner.address);
    expect(ethers.utils.formatEther(depositInContract)).to.equal('94.9');  // 11 - 5%

    console.log(`Deposit amount (after commision): ${ethers.utils.formatEther(depositInContract)}`);
  });

  it("Simulates a user process: deposit, rewards accrual and withdrawal, with commissions and calculate ROI", async function() {
    // Create a deposit of 100 Matic
    const depositAmount = ethers.utils.parseEther("100");
    await staking.connect(owner).deposit({value: depositAmount});

    // Check deposited amount after commission
    let balanceAfterDeposit = await staking.getTotalDeposit(owner.address);
    console.log(`Deposited amount after commission: ${ethers.utils.formatEther(balanceAfterDeposit)}`);

    // Advance time by 7 days
    await ethers.provider.send("evm_increaseTime", [7 * 86400]); 
    await ethers.provider.send("evm_mine");  
  
    // Calcular recompensas antes de la comisión
    const rewardsBeforeCommission = await staking.calculateRewards(owner.address);
  
    // Calcular recompensas después de la comisión (5%)
    const commissionPercentage = 5;
    const commission = rewardsBeforeCommission.mul(commissionPercentage).div(100);
    const rewardsAfterCommission = rewardsBeforeCommission.sub(commission);
  
    // Reclamar recompensas (retirar pero mantener en saldo del contrato, tomar comisión del 5%)
    await staking.connect(owner).claimRewards();
  
    // Ver saldo en contrato después del retiro (y comisión)
    let balanceContractAfterWithdraw = await staking.getTotalDeposit(owner.address);
    console.log(`Balance in contract after withdrawal: ${ethers.utils.formatEther(balanceContractAfterWithdraw)}`);
  
    // Calcular y mostrar ROI (Return on Investment), en porcentaje
    const totalDeposit = await staking.getTotalDeposit(owner.address);
    const ROI = rewardsAfterCommission.mul(10000).div(totalDeposit); // Multiplicar por 10000 para obtener más decimales
    console.log(`ROI after 7 days: ${ROI.toString()} basis points`); // "basis points" representa decimales adicionales
  
    // Calcular y mostrar ganancia neta, en porcentaje
    const netGain = rewardsAfterCommission.sub(commission).mul(10000).div(totalDeposit);
    console.log(`Net gain after 7 days: ${netGain.toString()} basis points`);
  
    // Retiro real al monedero del propietario
    let balanceBefore = await ethers.provider.getBalance(owner.address);
    await staking.connect(owner).withdrawRewards();
    let balanceAfter = await ethers.provider.getBalance(owner.address);
    
    console.log(`Rewards withdrawn to the wallet: ${ethers.utils.formatEther(balanceAfter.sub(balanceBefore))}`);
  });
  
  it("Should not allow deposit when contract is paused", async function () {
    // Pause the contract
    await staking.connect(owner).pause();

    // Try to deposit
    const depositAmount = ethers.utils.parseEther("50");
    await expect(staking.connect(addr1).deposit({value: depositAmount})).to.be.revertedWith("Pausable: paused");
    console.log(`Deposit failed when contract is paused`)
  });

  it("Should allow claim rewards when there are rewards to claim", async function () {
    // Simulate a deposit and wait for some time
    const depositAmount = ethers.utils.parseEther("50");
    await staking.connect(owner).deposit({value: depositAmount});
    await ethers.provider.send("evm_increaseTime", [7 * 86400]); // Advance 7 days
    await ethers.provider.send("evm_mine"); 

    // Claim rewards
    await staking.connect(owner).claimRewards();
    console.log(`Rewards claimed successfully`);
  });

  it("Should not allow claims (rewards) when contract is paused", async function () {
    // Pause the contract
    await staking.connect(owner).pause();

    // Try to claim rewards
    await expect(staking.connect(owner).claimRewards()).to.be.revertedWith("Pausable: paused");
    console.log(`Claim rewards failed when contract is paused`)
  });

  it("Should calculate accumulated rewards over 7 days and allow to claim and withdraw them with commission", async function () {
    // Simulate a deposit and wait for some time
    const depositAmount = ethers.utils.parseEther("50");
    await staking.connect(owner).deposit({value: depositAmount});
    await ethers.provider.send("evm_increaseTime", [1 * 86400]); // Advance 7 days
    await ethers.provider.send("evm_mine"); 

    // Claim rewards and withdraw them
    await staking.connect(owner).claimRewards();
    await staking.connect(owner).withdrawRewards();
    console.log(`Rewards claimed and withdrawn successfully`);
  });

  it("User deposits, accumulates rewards for 24 hours, and prints hourly rewards", async function () {
    const depositAmount = ethers.utils.parseEther("50");
  
    // Usuario realiza un depósito
    await staking.connect(addr1).deposit({ value: depositAmount });
  
    // Imprime en consola el monto del depósito
    console.log("Depósito del usuario:", ethers.utils.formatEther(depositAmount), "Matic");
  
    // Bucle para simular 24 horas y calcular/imprimir recompensas cada hora
    for (let hour = 1; hour <= 24; hour++) {
      // Avanza el tiempo en 1 hora
      await ethers.provider.send("evm_increaseTime", [60 * 60]);
      await ethers.provider.send("evm_mine");
  
      // Calcula las recompensas acumuladas hasta ahora
      const accumulatedRewards = await staking.calculateRewards(addr1.address);
  
      // Imprime en consola las recompensas acumuladas en la hora actual
      console.log(`Recompensas acumuladas en la hora ${hour}:`, ethers.utils.formatEther(accumulatedRewards), "Matic");
    }
  });

  it("User deposits, accumulates rewards for 24 hours, claims rewards, makes another deposit, accumulates rewards for another 24 hours, and claims rewards again", async function () {
    // Usuario realiza un depósito de 100 Matic
    const depositAmount = ethers.utils.parseEther("50");
    await staking.connect(addr1).deposit({ value: depositAmount });
    console.log("Depósito inicial del usuario:", ethers.utils.formatEther(depositAmount), "Matic");
  
    // Bucle para simular 24 horas y acumular recompensas cada hora
    for (let hour = 1; hour <= 24; hour++) {
      // Avanza el tiempo en 1 hora
      await ethers.provider.send("evm_increaseTime", [60 * 60]);
      await ethers.provider.send("evm_mine");
  
      // Calcula las recompensas acumuladas hasta ahora
      const accumulatedRewards = await staking.calculateRewards(addr1.address);
  
      // Imprime en consola las recompensas acumuladas en la hora actual
      console.log(`Recompensas acumuladas en la hora ${hour}:`, ethers.utils.formatEther(accumulatedRewards), "Matic");
    }
  
    // Usuario reclama las recompensas acumuladas
    await staking.connect(addr1).claimRewards();
    console.log("Recompensas reclamadas después de 24 horas.");
  
    // Usuario realiza otro depósito de 100 Matic
    await staking.connect(addr1).deposit({ value: depositAmount });
    console.log("Segundo depósito del usuario:", ethers.utils.formatEther(depositAmount), "Matic");
  
    // Bucle para simular otras 24 horas y acumular recompensas cada hora
    for (let hour = 25; hour <= 48; hour++) {
      // Avanza el tiempo en 1 hora
      await ethers.provider.send("evm_increaseTime", [60 * 60]);
      await ethers.provider.send("evm_mine");
  
      // Calcula las recompensas acumuladas hasta ahora
      const accumulatedRewards = await staking.calculateRewards(addr1.address);
  
      // Imprime en consola las recompensas acumuladas en la hora actual
      console.log(`Recompensas acumuladas en la hora ${hour}:`, ethers.utils.formatEther(accumulatedRewards), "Matic");
    }
  
    // Usuario reclama las recompensas acumuladas después del segundo depósito
    await staking.connect(addr1).claimRewards();
    console.log("Recompensas reclamadas después de otros 24 horas con el segundo depósito.");
  });
  
  
});
