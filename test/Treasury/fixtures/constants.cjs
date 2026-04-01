const { ethers } = require("hardhat");

// Treasury Types (matching enum in contract)
const TreasuryType = {
    REWARDS: 0,
    STAKING: 1,
    COLLABORATORS: 2,
    DEVELOPMENT: 3,
    MARKETPLACE: 4
};

// Protocol Status (matching enum in contract)
const ProtocolStatus = {
    HEALTHY: 0,
    UNSTABLE: 1,
    CRITICAL: 2,
    EMERGENCY: 3
};

// Default Treasury Allocations (in basis points, 10000 = 100%)
const DEFAULT_ALLOCATIONS = {
    REWARDS: 3000,      // 30%
    STAKING: 2000,      // 20%
    COLLABORATORS: 2000, // 20%
    DEVELOPMENT: 2000,   // 20%
    MARKETPLACE: 1000    // 10%
};

// Time Constants
const DISTRIBUTION_INTERVAL = 7 * 24 * 60 * 60; // 7 days in seconds
const ONE_DAY = 24 * 60 * 60;
const ONE_HOUR = 60 * 60;

// Percentage Constants
const DEFAULT_RESERVE_PERCENTAGE = 2000; // 20% in basis points
const BASIS_POINTS = 10000;

// Common Test Amounts (as strings, to be parsed by tests)
const TEST_AMOUNTS = {
    SMALL: "1",
    MEDIUM: "10",
    LARGE: "100",
    XLARGE: "1000"
};

module.exports = {
    TreasuryType,
    ProtocolStatus,
    DEFAULT_ALLOCATIONS,
    DISTRIBUTION_INTERVAL,
    ONE_DAY,
    ONE_HOUR,
    DEFAULT_RESERVE_PERCENTAGE,
    BASIS_POINTS,
    TEST_AMOUNTS
};
