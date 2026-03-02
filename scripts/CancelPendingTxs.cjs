#!/usr/bin/env node
/**
 * 🔧 CANCEL PENDING TRANSACTIONS
 * Cancela transacciones pendientes stuck en el mempool
 * enviando self-transfers (0 POL) en los mismos nonces con gas más alto
 */

const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`\n🔧 Canceling pending transactions for: ${deployer.address}`);

    // Obtener nonce confirmado (en chain)
    const confirmedNonce = await ethers.provider.getTransactionCount(deployer.address, "latest");
    // Obtener nonce pending (incluyendo mempool)
    const pendingNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");

    console.log(`📊 Confirmed nonce (on-chain): ${confirmedNonce}`);
    console.log(`📊 Pending nonce (mempool):    ${pendingNonce}`);

    if (pendingNonce <= confirmedNonce) {
        console.log(`\n✅ No pending transactions found. Wallet is clean!`);
        return;
    }

    const pendingCount = pendingNonce - confirmedNonce;
    console.log(`\n⚠️  Found ${pendingCount} stuck pending transaction(s) at nonces ${confirmedNonce} to ${pendingNonce - 1}`);

    // Gas price alto para reemplazar las pendientes (2x el fee actual)
    const feeData = await ethers.provider.getFeeData();
    const baseMaxFee = feeData.maxFeePerGas || feeData.gasPrice;
    const replacementMaxFee = (baseMaxFee * 300n) / 100n; // 3x para asegurar reemplazo
    const replacementPriority = ethers.parseUnits("200", "gwei"); // Priority fee alto

    console.log(`\n⛽ Replacement gas price: ${ethers.formatUnits(replacementMaxFee, "gwei")} Gwei (3x current)`);
    console.log(`⛽ Replacement priority:  ${ethers.formatUnits(replacementPriority, "gwei")} Gwei\n`);

    for (let nonce = confirmedNonce; nonce < pendingNonce; nonce++) {
        console.log(`🚫 Canceling TX at nonce ${nonce}...`);
        try {
            const cancelTx = await deployer.sendTransaction({
                to: deployer.address, // Self-transfer
                value: 0n,
                nonce: nonce,
                maxFeePerGas: replacementMaxFee,
                maxPriorityFeePerGas: replacementPriority,
                gasLimit: 21000n // Gas mínimo para transferencia simple
            });
            console.log(`   📡 Cancel TX Hash: ${cancelTx.hash}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${cancelTx.hash}`);
            console.log(`   ⏳ Waiting for confirmation...`);
            await cancelTx.wait(1);
            console.log(`   ✅ Nonce ${nonce} cancelled!\n`);
        } catch (err) {
            console.error(`   ❌ Error canceling nonce ${nonce}: ${err.message}\n`);
        }
    }

    const finalNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
    console.log(`\n✅ Done! Wallet nonce now: ${finalNonce}`);
    console.log(`🚀 Ready for fresh deployment!\n`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
