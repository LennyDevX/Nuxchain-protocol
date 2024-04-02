const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("StakingContract", function() {
  let contract, owner, addr1;

  beforeEach(async () => {
    [owner, addr1] = await ethers.getSigners();

    const StakingContract = await ethers.getContractFactory("StakingContract");
    contract = await StakingContract.deploy(owner.address);
    await contract.deployed();
  });

  
  
  it("Should deposit successfully and increase total pool balance", async function () {
  const numOfDeposits = 5;
  let totalDeposit = ethers.utils.parseEther("0");
  let totalCommission = ethers.utils.parseEther("0");

  // Contract should initially acknowledge 0 deposits
  expect(await contract.getTotalDeposit(addr1.address)).to.equal(0);

  // Make deposits from addr1 account
  for(let i = 0; i < numOfDeposits; i++) {
    // Assign random value for deposit (minimum of 10)
    const depositAmount = ethers.utils.parseEther(String(Math.floor(Math.random() * 10) + 10));

    await contract.connect(addr1).deposit({ value: depositAmount });

    const COMMISSION_PERCENTAGE = await contract.COMMISSION_PERCENTAGE(); 
    let commission = depositAmount.mul(COMMISSION_PERCENTAGE).div(10000);
    totalCommission = totalCommission.add(commission);
    let depositAmountAfterCommission = depositAmount.sub(commission);

    totalDeposit = totalDeposit.add(depositAmountAfterCommission);

    // Check the total number of deposits
    const totalDepositsOnContract = await contract.getTotalDeposit(addr1.address);
    expect(totalDepositsOnContract).to.be.at.least(totalDeposit);

    console.log(`Deposit ${i + 1} from addr1: ${ethers.utils.formatEther(depositAmountAfterCommission)} ETH, commission deducted: ${ethers.utils.formatEther(commission)} ETH`);
  }
  
  console.log("Total deposited by addr1 (after commission): ", ethers.utils.formatEther(totalDeposit));
  console.log("Total commission deducted from all deposits: ", ethers.utils.formatEther(totalCommission));
  console.log("Total balance of the pool: ", ethers.utils.formatEther(await contract.totalPoolBalance()));
  console.log("Total contract balance: ", ethers.utils.formatEther(await ethers.provider.getBalance(contract.address)));



  
 })});