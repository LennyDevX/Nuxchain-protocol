// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev Minimal mock for LevelingSystem used in NFT unit tests
contract MockLeveling {
    mapping(address => uint256) public xp;

    event XPAdded(address indexed user, uint256 amount, uint256 total);

    function addXP(address user, uint256 amount) external {
        xp[user] += amount;
        emit XPAdded(user, amount, xp[user]);
    }

    function recordAgentMinted(address user) external {
        xp[user] += 50;
        emit XPAdded(user, 50, xp[user]);
    }

    function recordAgentUpgrade(address user) external {
        xp[user] += 20;
        emit XPAdded(user, 20, xp[user]);
    }

    function recordAgentTask(address user) external {
        xp[user] += 10;
        emit XPAdded(user, 10, xp[user]);
    }
}
