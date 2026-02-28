/**
 * RecoverTreasuryFunds.cjs
 *
 * Sends the full POL balance from the old treasury wallet (0x9a7fac...) to TreasuryManager.
 * TreasuryManager's receive() function processes it as revenue automatically.
 *
 * Prerequisites:
 *   Add TREASURY_PRIVATE_KEY=<key for 0x9a7fac014e2056835878d1866651d673b0ba9407> to .env
 *
 * Run:
 *   npx hardhat run scripts/RecoverTreasuryFunds.cjs --network polygon
 */

require("dotenv").config();
const { ethers } = require("hardhat");

const TREASURY_MANAGER  = "0x0cfad488352beA84621a4CA4D7764041Da34C079";
const OLD_WALLET        = "0x9a7fAc014E2056835878D1866651d673b0ba9407";
const GAS_BUFFER        = ethers.parseUnits("0.002", "ether"); // keep ~0.002 POL for gas

async function main() {
  const TREASURY_PRIVATE_KEY = process.env.TREASURY_PRIVATE_KEY;

  if (!TREASURY_PRIVATE_KEY) {
    console.error("\n❌  TREASURY_PRIVATE_KEY is not set in .env");
    console.error("   Add: TREASURY_PRIVATE_KEY=<private key for 0x9a7fac014e2056835878d1866651d673b0ba9407>\n");
    process.exit(1);
  }

  const provider = ethers.provider;
  const treasurySigner = new ethers.Wallet(TREASURY_PRIVATE_KEY, provider);

  // Verify the key matches the expected address
  if (treasurySigner.address.toLowerCase() !== OLD_WALLET.toLowerCase()) {
    console.error(`\n❌  Key mismatch!`);
    console.error(`   TREASURY_PRIVATE_KEY resolves to : ${treasurySigner.address}`);
    console.error(`   Expected                         : ${OLD_WALLET}\n`);
    process.exit(1);
  }

  console.log("\n════════════════════════════════════════════════════════");
  console.log("        RECOVER TREASURY FUNDS — Polygon Mainnet");
  console.log("════════════════════════════════════════════════════════");
  console.log(`  From (old wallet)  : ${OLD_WALLET}`);
  console.log(`  To (TreasuryMgr)   : ${TREASURY_MANAGER}`);

  const balance = await provider.getBalance(OLD_WALLET);
  console.log(`  Current balance    : ${ethers.formatEther(balance)} POL`);

  if (balance === 0n) {
    console.log("\n⚠️  Nothing to recover — old wallet balance is 0.");
    console.log("════════════════════════════════════════════════════════\n");
    return;
  }

  // Estimate gas cost for a plain transfer
  const feeData     = await provider.getFeeData();
  const gasPrice    = feeData.gasPrice ?? ethers.parseUnits("50", "gwei");
  const gasLimit    = 100_000n; // generous for TreasuryManager.receive()
  const gasCost     = gasPrice * gasLimit;

  const sendAmount  = balance - gasCost;

  if (sendAmount <= 0n) {
    console.error("\n❌  Balance is too low to cover gas.");
    process.exit(1);
  }

  console.log(`  Gas estimate       : ${ethers.formatEther(gasCost)} POL`);
  console.log(`  Amount to send     : ${ethers.formatEther(sendAmount)} POL`);
  console.log("────────────────────────────────────────────────────────");

  const tx = await treasurySigner.sendTransaction({
    to:       TREASURY_MANAGER,
    value:    sendAmount,
    gasLimit: gasLimit,
    gasPrice: gasPrice,
  });

  console.log(`  Tx submitted       : ${tx.hash}`);
  process.stdout.write("  Waiting for confirmation... ");

  const receipt = await tx.wait();
  console.log(`confirmed (block ${receipt.blockNumber})`);

  // Post-transfer balances
  const [newOldBal, newTMBal] = await Promise.all([
    provider.getBalance(OLD_WALLET),
    provider.getBalance(TREASURY_MANAGER),
  ]);

  console.log("\nPOST-TRANSFER BALANCES:");
  console.log(`  Old wallet         : ${ethers.formatEther(newOldBal)} POL`);
  console.log(`  TreasuryManager    : ${ethers.formatEther(newTMBal)} POL`);
  console.log(`\n✅  Recovery complete! TreasuryManager received ${ethers.formatEther(sendAmount)} POL`);
  console.log("════════════════════════════════════════════════════════\n");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
