// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IEnhancedSmartStakingRewards
 * @notice Interface for reward calculation logic in the EnhancedSmartStaking system
 * @dev This module handles all reward computations including base rewards, skill boosts, and APY calculations
 */
interface IEnhancedSmartStakingRewards {
    
    // ============================================
    // EVENTS
    // ============================================
    
    event QuestRewardClaimed(address indexed user, uint256 indexed questId, uint256 amount, uint256 boostApplied);
    event RewardFunded(address indexed funder, uint256 amount);
    event EmergencyWithdrawal(address indexed admin, uint256 amount);
    event APYUpdated(uint8 indexed lockupIndex, uint256 newAPY);

    // ============================================
    // STATE-CHANGING FUNCTIONS
    // ============================================

    /**
     * @notice Claim a quest reward with skill boosts applied
     * @param questId The ID of the quest to claim
     */
    function claimQuestReward(uint256 questId) external;

    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @notice Calculate staking rewards (yield) for a deposit
     * @param depositAmount The amount deposited
     * @param depositTime The timestamp of deposit
     * @param lastClaimTime The last time rewards were claimed
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @param stakingBoostTotal The total staking boost from skills (in basis points)
     * @return rewards The calculated rewards
     */
    function calculateStakingRewards(
        uint256 depositAmount,
        uint256 depositTime,
        uint256 lastClaimTime,
        uint8 lockupPeriodIndex,
        uint16 stakingBoostTotal
    ) external view returns (uint256 rewards);

    /**
     * @notice Calculate quest reward with skill boosts applied
     * @param user The user address
     * @param baseReward The base reward amount
     * @return finalReward The calculated reward with boosts applied
     */
    function calculateQuestReward(address user, uint256 baseReward) external view returns (uint256 finalReward);
}
