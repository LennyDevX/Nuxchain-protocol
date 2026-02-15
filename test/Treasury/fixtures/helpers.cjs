const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

/**
 * Increase blockchain time by specified seconds
 * @param {number} seconds - Seconds to advance
 */
async function increaseTime(seconds) {
    await time.increase(seconds);
}

/**
 * Increase blockchain time to specific timestamp
 * @param {number} timestamp - Target timestamp
 */
async function increaseTimeTo(timestamp) {
    await time.increaseTo(timestamp);
}

/**
 * Get current block timestamp
 * @returns {Promise<number>}
 */
async function getCurrentTimestamp() {
    return await time.latest();
}

/**
 * Calculate expected distribution amounts based on total and allocations
 * @param {BigNumber} totalAmount - Total amount to distribute
 * @param {number} reservePercentage - Reserve percentage in basis points
 * @returns {Object} Expected distribution amounts for each treasury
 */
function calculateExpectedDistribution(totalAmount, reservePercentage = 2000) {
    const { DEFAULT_ALLOCATIONS, BASIS_POINTS } = require("./constants.cjs");
    
    // Calculate reserve
    const reserve = totalAmount.mul(reservePercentage).div(BASIS_POINTS);
    const distributable = totalAmount.sub(reserve);
    
    return {
        reserve,
        distributable,
        rewards: distributable.mul(DEFAULT_ALLOCATIONS.REWARDS).div(BASIS_POINTS),
        staking: distributable.mul(DEFAULT_ALLOCATIONS.STAKING).div(BASIS_POINTS),
        collaborators: distributable.mul(DEFAULT_ALLOCATIONS.COLLABORATORS).div(BASIS_POINTS),
        development: distributable.mul(DEFAULT_ALLOCATIONS.DEVELOPMENT).div(BASIS_POINTS),
        marketplace: distributable.mul(DEFAULT_ALLOCATIONS.MARKETPLACE).div(BASIS_POINTS)
    };
}

/**
 * Expect a transaction to emit specific event with args
 * @param {Promise} tx - Transaction promise
 * @param {string} eventName - Event name
 * @param {Array} expectedArgs - Expected arguments (can use null for any value)
 */
async function expectEvent(tx, eventName, expectedArgs = []) {
    const receipt = await tx.wait();
    const event = receipt.events?.find(e => e.event === eventName);
    
    if (!event) {
        throw new Error(`Event ${eventName} not found in transaction`);
    }
    
    if (expectedArgs.length > 0) {
        expectedArgs.forEach((expectedArg, index) => {
            if (expectedArg !== null && event.args[index] !== expectedArg) {
                throw new Error(`Event ${eventName} arg ${index} mismatch: expected ${expectedArg}, got ${event.args[index]}`);
            }
        });
    }
    
    return event;
}

/**
 * Get balance of an address
 * @param {string} address - Address to check
 * @returns {Promise<BigNumber>}
 */
async function getBalance(address) {
    return await ethers.provider.getBalance(address);
}

/**
 * Format ether amount to string with decimals
 * @param {BigNumber} amount - Amount in wei
 * @param {number} decimals - Number of decimals to show
 * @returns {string}
 */
function formatEther(amount, decimals = 4) {
    const formatted = ethers.utils.formatEther(amount);
    return parseFloat(formatted).toFixed(decimals);
}

module.exports = {
    increaseTime,
    increaseTimeTo,
    getCurrentTimestamp,
    calculateExpectedDistribution,
    expectEvent,
    getBalance,
    formatEther
};
