// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IXPHub.sol";

contract MockQuestLeveling is IXPHub {
    mapping(address => UserProfile) private _profiles;
    mapping(address => uint256[15]) private _xpBySource;

    uint8 private constant MAX_LEVEL = 250;
    uint8 private constant LEVELS_PER_BRACKET = 25;
    uint8 private constant BRACKET_COUNT = 10;
    uint256 private constant XP_PER_BRACKET_STEP = 50;
    uint256 private constant MAX_XP_TOTAL = 68_750;
    uint256 private constant LEVEL_REWARD_STEP = 0.05 ether;

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

    function adminSetUserXP(address user, uint256 totalXP) external override {
        uint256 cappedXP = totalXP > MAX_XP_TOTAL ? MAX_XP_TOTAL : totalXP;
        _profiles[user].totalXP = cappedXP;
        _profiles[user].level = this.getLevelFromXP(cappedXP);
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
        if (xp < XP_PER_BRACKET_STEP) {
            return 0;
        }

        uint256 remainingXP = xp > MAX_XP_TOTAL ? MAX_XP_TOTAL : xp;
        for (uint256 bracket = 1; bracket <= BRACKET_COUNT; bracket++) {
            uint256 xpPerLevel = bracket * XP_PER_BRACKET_STEP;
            uint256 bracketXP = xpPerLevel * LEVELS_PER_BRACKET;
            if (remainingXP <= bracketXP) {
                return uint8(((bracket - 1) * LEVELS_PER_BRACKET) + (remainingXP / xpPerLevel));
            }
            remainingXP -= bracketXP;
        }

        return MAX_LEVEL;
    }

    function getXPRequiredForLevel(uint8 level) external pure override returns (uint256 xpRequired) {
        require(level >= 1 && level <= MAX_LEVEL, "MockQuestLeveling: invalid level");
        uint256 bracket = ((uint256(level) - 1) / LEVELS_PER_BRACKET) + 1;
        return bracket * XP_PER_BRACKET_STEP;
    }

    function getCumulativeXPForLevel(uint8 level) external pure override returns (uint256 cumulativeXP) {
        require(level <= MAX_LEVEL, "MockQuestLeveling: invalid level");
        if (level == 0) {
            return 0;
        }

        uint256 bracket = ((uint256(level) - 1) / LEVELS_PER_BRACKET) + 1;
        uint256 completedBrackets = bracket - 1;
        uint256 levelsBeforeBracket = completedBrackets * LEVELS_PER_BRACKET;
        uint256 xpBeforeBracket = XP_PER_BRACKET_STEP * LEVELS_PER_BRACKET * completedBrackets * bracket / 2;
        uint256 levelsInCurrentBracket = uint256(level) - levelsBeforeBracket;
        return xpBeforeBracket + (levelsInCurrentBracket * bracket * XP_PER_BRACKET_STEP);
    }

    function getRewardForLevel(uint8 level) external pure override returns (uint256 rewardAmount) {
        require(level >= 1 && level <= MAX_LEVEL, "MockQuestLeveling: invalid level");
        uint256 rewardTier = ((uint256(level) - 1) / LEVELS_PER_BRACKET) + 1;
        return rewardTier * LEVEL_REWARD_STEP;
    }
}