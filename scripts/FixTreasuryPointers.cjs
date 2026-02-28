/**
 * FixTreasuryPointers.cjs
 * 
 * Redirects all revenue contracts to point at TreasuryManager instead of the old wallet.
 * 
 * What this does:
 *   StakingCore    → setTreasuryManager(TM)  +  changeTreasuryAddress(TM)
 *   Marketplace    → setTreasuryManager(TM)
 *   IndividualSkills → setTreasuryManager(TM)
 * 
 * Run:
 *   npx hardhat run scripts/FixTreasuryPointers.cjs --network polygon
 */

const { ethers } = require("hardhat");

// ── Addresses ─────────────────────────────────────────────────────────────────
const TREASURY_MANAGER   = "0x0cfad488352beA84621a4CA4D7764041Da34C079";
const STAKING_CORE       = "0x642E60a50d8b61Cf44A671F20ac03301bE55104B";
const MARKETPLACE        = "0x65BD8E08c02c1121cE44210C249E0760f18eB64f";
const INDIVIDUAL_SKILLS  = "0x21dC162354576fd359535D584B3c72C3cc251939";

// ── Minimal ABIs ──────────────────────────────────────────────────────────────
const STAKING_ABI = [
  "function setTreasuryManager(address _treasuryManager) external",
  "function changeTreasuryAddress(address _newTreasury) external",
  "function treasury() view returns (address)",
  "function treasuryManager() view returns (address)",
  "function owner() view returns (address)",
];

const MARKETPLACE_ABI = [
  "function setTreasuryManager(address _treasuryManager) external",
  "function treasuryManager() view returns (address)",
  "function platformTreasury() view returns (address)",
];

const SKILLS_ABI = [
  "function setTreasuryManager(address _treasuryManager) external",
  "function treasuryManager() view returns (address)",
];

// ── Helpers ───────────────────────────────────────────────────────────────────
function short(addr) {
  return addr.slice(0, 6) + "..." + addr.slice(-4);
}

function checkMark(addr, expected) {
  return addr.toLowerCase() === expected.toLowerCase() ? "✅" : "❌";
}

async function fixContract(label, contract, callFn, ...args) {
  process.stdout.write(`  [${label}] ${callFn}(${args.map(short).join(", ")})... `);
  try {
    const tx = await contract[callFn](...args);
    const receipt = await tx.wait();
    console.log(`✅  tx: ${receipt.hash}`);
    return true;
  } catch (err) {
    console.log(`❌  FAILED: ${err.message.split("\n")[0]}`);
    return false;
  }
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  const [signer] = await ethers.getSigners();
  console.log("\n════════════════════════════════════════════════════════");
  console.log("        FIX TREASURY POINTERS — Polygon Mainnet");
  console.log("════════════════════════════════════════════════════════");
  console.log(`  Signer        : ${signer.address}`);
  console.log(`  TreasuryManager: ${TREASURY_MANAGER}`);
  console.log("────────────────────────────────────────────────────────\n");

  const staking  = new ethers.Contract(STAKING_CORE,      STAKING_ABI,    signer);
  const market   = new ethers.Contract(MARKETPLACE,       MARKETPLACE_ABI, signer);
  const skills   = new ethers.Contract(INDIVIDUAL_SKILLS, SKILLS_ABI,     signer);

  // ── BEFORE snapshot ──────────────────────────────────────────────────────
  console.log("BEFORE:");
  const [sTM, sTreasury, mTM, mPT, skTM] = await Promise.all([
    staking.treasuryManager(),
    staking.treasury(),
    market.treasuryManager(),
    market.platformTreasury(),
    skills.treasuryManager(),
  ]);
  console.log(`  StakingCore.treasuryManager  : ${sTM}`);
  console.log(`  StakingCore.treasury         : ${sTreasury}`);
  console.log(`  Marketplace.treasuryManager  : ${mTM}`);
  console.log(`  Marketplace.platformTreasury : ${mPT}`);
  console.log(`  IndividualSkills.treasuryMgr : ${skTM}`);
  console.log();

  // ── FIXES ────────────────────────────────────────────────────────────────
  console.log("APPLYING FIXES:");

  // StakingCore — onlyOwner
  await fixContract("StakingCore",       staking, "setTreasuryManager",    TREASURY_MANAGER);
  await fixContract("StakingCore",       staking, "changeTreasuryAddress", TREASURY_MANAGER);

  // Marketplace — onlyRole(ADMIN_ROLE)
  await fixContract("Marketplace",       market,  "setTreasuryManager",    TREASURY_MANAGER);

  // IndividualSkills — onlyRole(ADMIN_ROLE)
  await fixContract("IndividualSkills",  skills,  "setTreasuryManager",    TREASURY_MANAGER);

  console.log();

  // ── AFTER snapshot ───────────────────────────────────────────────────────
  console.log("AFTER:");
  const [sTM2, sTreasury2, mTM2, mPT2, skTM2] = await Promise.all([
    staking.treasuryManager(),
    staking.treasury(),
    market.treasuryManager(),
    market.platformTreasury(),
    skills.treasuryManager(),
  ]);

  const TM = TREASURY_MANAGER.toLowerCase();
  console.log(`  StakingCore.treasuryManager  : ${sTM2}  ${checkMark(sTM2, TM)}`);
  console.log(`  StakingCore.treasury         : ${sTreasury2}  ${checkMark(sTreasury2, TM)}`);
  console.log(`  Marketplace.treasuryManager  : ${mTM2}  ${checkMark(mTM2, TM)}`);
  console.log(`  Marketplace.platformTreasury : ${mPT2}  (not updated — no setter on contract)`);
  console.log(`  IndividualSkills.treasuryMgr : ${skTM2}  ${checkMark(skTM2, TM)}`);
  console.log();

  const allOk =
    sTM2.toLowerCase()  === TM &&
    sTreasury2.toLowerCase() === TM &&
    mTM2.toLowerCase()  === TM &&
    skTM2.toLowerCase() === TM;

  if (allOk) {
    console.log("✅  All pointers updated. Future commissions → TreasuryManager");
  } else {
    console.log("⚠️  One or more pointers could not be updated. Check errors above.");
  }

  console.log("════════════════════════════════════════════════════════\n");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
