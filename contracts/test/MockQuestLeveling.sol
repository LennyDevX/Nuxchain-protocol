// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IXPHub.sol";

contract MockQuestLeveling is IXPHub {
    mapping(address => UserProfile) private _profiles;
    mapping(address => uint256[15]) private _xpBySource;

    function setUserProfile(address user, UserProfile calldata profile) external {
        _profiles[user] = profile;
    }

    function awardXP(address user, uint256 amount, XPSource source)
        external
        override
        returns (bool leveledUp, uint8 newLevel)
    {
        _profiles[user].totalXP += amount;
        _xpBySource[user][uint8(source)] += amount;
        emit XPAwarded(user, amount, uint8(source), _profiles[user].totalXP, block.timestamp);
        return (false, _profiles[user].level);
    }

    function updateUserXP(address user, uint256 xpAmount, string calldata) external override {
        _profiles[user].totalXP += xpAmount;
    }

    function addXP(address user, uint256 amount) external override {
        _profiles[user].totalXP += amount;
    }

    function getUserXP(address user) external view override returns (uint256 totalXP, uint8 level) {
        UserProfile memory profile = _profiles[user];
        return (profile.totalXP, profile.level);
    }

    function getUserProfile(address user) external view override returns (UserProfile memory) {
        return _profiles[user];
    }

    function getUserXPBreakdown(address user) external view override returns (uint256[15] memory xpBySource) {
        return _xpBySource[user];
    }

    function getLevelFromXP(uint256 xp) external pure override returns (uint8 level) {
        if (xp == 0) {
            return 0;
        }

        uint256 derived = xp / 100;
        if (derived > type(uint8).max) {
            return type(uint8).max;
        }

        return uint8(derived);
    }
}