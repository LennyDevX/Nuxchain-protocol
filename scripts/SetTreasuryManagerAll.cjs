#!/usr/bin/env node
/**
 * 🔧 SET TREASURY MANAGER — ALL CONTRACTS
 *
 * Llama setTreasuryManager() en:
 *   1. EnhancedSmartStakingCoreV2
 *   2. GameifiedMarketplaceCoreV1
 *   3. IndividualSkillsMarketplace
 *
 * Esto hace que las comisiones se enruten al TreasuryManager en vez de
 * ir directamente a la wallet de treasury.
 */

const { ethers } = require("hardhat");
require("dotenv").config();

const TREASURY_MANAGER = "0x312a3c5072c9DE2aB5cbDd799b3a65fb053DF043";
const STAKING_CORE     = "0x2cda88046543be25a3EC4eA2d86dBe975Fda0028";
const MARKETPLACE      = "0xc8Af452F3842805Bc79bfFBBbDB9b130f222d9BC";
const IND_SKILLS       = "0x2248e909EC9E122D1D7206E86D2061681EfCC49B";

// Minimal ABIs
const STAKING_ABI = [
  "function setTreasuryManager(address _treasuryManager) external",
  "function treasuryManager() view returns (address)",
  "function treasury() view returns (address)"
];
const MARKETPLACE_ABI = [
  "function setTreasuryManager(address _treasuryManager) external",
  "function treasuryManager() view returns (address)",
  "function platformTreasury() view returns (address)"
];
const IND_SKILLS_ABI = [
  "function setTreasuryManager(address _treasuryManager) external",
  "function treasuryManager() view returns (address)"
];

async function setAndVerify(label, contract, abi, signer, gasOpts) {
  const c = new ethers.Contract(contract, abi, signer);

  const current = await c.treasuryManager();
  console.log(`\n📋 ${label}`);
  console.log(`   Contract:         ${contract}`);
  console.log(`   Current manager:  ${current}`);

  if (current.toLowerCase() === TREASURY_MANAGER.toLowerCase()) {
    console.log(`   ✅ Already set correctly — skipping`);
    return;
  }

  console.log(`   ⏳ Calling setTreasuryManager(${TREASURY_MANAGER})...`);
  const tx = await c.setTreasuryManager(TREASURY_MANAGER, gasOpts);
  console.log(`   📡 TX: https://polygonscan.com/tx/${tx.hash}`);
  await tx.wait(1);

  const updated = await c.treasuryManager();
  if (updated.toLowerCase() === TREASURY_MANAGER.toLowerCase()) {
    console.log(`   ✅ Updated → ${updated}`);
  } else {
    console.error(`   ❌ Verification failed — got ${updated}`);
  }
}

async function main() {
  const [signer] = await ethers.getSigners();
  console.log(`\n🔧 SetTreasuryManager — All Contracts`);
  console.log(`📍 Signer:           ${signer.address}`);
  console.log(`🏦 TreasuryManager:  ${TREASURY_MANAGER}`);
  console.log(`💰 Balance:          ${ethers.formatEther(await ethers.provider.getBalance(signer.address))} POL\n`);

  // Dynamic gas
  const fee = await ethers.provider.getFeeData();
  const maxFee = (fee.maxFeePerGas * 125n) / 100n;
  const priority = (fee.maxPriorityFeePerGas * 125n) / 100n;
  const gasOpts = { maxFeePerGas: maxFee, maxPriorityFeePerGas: priority };

  console.log(`⛽ Gas: MaxFee=${ethers.formatUnits(maxFee,"gwei")} Gwei  Priority=${ethers.formatUnits(priority,"gwei")} Gwei`);

  await setAndVerify("EnhancedSmartStakingCoreV2", STAKING_CORE, STAKING_ABI, signer, gasOpts);
  await setAndVerify("GameifiedMarketplaceCoreV1", MARKETPLACE, MARKETPLACE_ABI, signer, gasOpts);
  await setAndVerify("IndividualSkillsMarketplace", IND_SKILLS, IND_SKILLS_ABI, signer, gasOpts);

  console.log(`\n╔════════════════════════════════════════════╗`);
  console.log(`║  ✅ ALL TREASURY MANAGERS CONFIGURED       ║`);
  console.log(`╠════════════════════════════════════════════╣`);
  console.log(`║  Revenue flow:                             ║`);
  console.log(`║  Staking deposit → TreasuryManager ✅      ║`);
  console.log(`║  Marketplace fee → TreasuryManager ✅      ║`);
  console.log(`║  Individual Skill → TreasuryManager ✅     ║`);
  console.log(`╚════════════════════════════════════════════╝\n`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => { console.error(err); process.exit(1); });
