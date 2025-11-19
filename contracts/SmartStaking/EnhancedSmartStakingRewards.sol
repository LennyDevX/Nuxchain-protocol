// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IEnhancedSmartStakingRewards.sol";
import "../interfaces/IEnhancedSmartStakingSkills.sol";
import "../interfaces/IEnhancedSmartStakingGamification.sol";

/**
 * @title EnhancedSmartStakingRewards
 * @notice Handles reward payout logic for the EnhancedSmartStaking system
 * @dev Replaces APY with Quest-based rewards. Holds funds for payouts.
 */
contract EnhancedSmartStakingRewards is Ownable, ReentrancyGuard, IEnhancedSmartStakingRewards {
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    uint256 private constant BASIS_POINTS = 10000;
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    IEnhancedSmartStakingSkills public skillsModule;
    IEnhancedSmartStakingGamification public gamificationModule;
    
    // Staking Yield Configuration
    uint256[] private lockupPeriods;
    uint256[] private baseAPYs;
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        // Initialize lockup periods: 0, 30, 90, 180, 365 days
        lockupPeriods = [0, 30 days, 90 days, 180 days, 365 days];
        
        // Initialize base APYs (Can be 0 for "Sustainable" model, or low values)
        // Example: 1% base APY for 365 days, 0% for others.
        // Or standard values if user wants hybrid.
        // Let's set conservative base values, assuming skills provide the main boost.
        baseAPYs = [
            100,    // 1% APY (No Lock)
            200,    // 2% APY (30 Days)
            300,    // 3% APY (90 Days)
            500,    // 5% APY (180 Days)
            800     // 8% APY (365 Days)
        ];
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    function setSkillsModule(address _skillsModule) external onlyOwner {
        require(_skillsModule != address(0), "Invalid address");
        skillsModule = IEnhancedSmartStakingSkills(_skillsModule);
    }
    
    function setGamificationModule(address _gamificationModule) external onlyOwner {
        require(_gamificationModule != address(0), "Invalid address");
        gamificationModule = IEnhancedSmartStakingGamification(_gamificationModule);
    }

    /**
     * @notice Fund the rewards contract
     */
    receive() external payable {
        emit RewardFunded(msg.sender, msg.value);
    }
    
    /**
     * @notice Emergency withdraw funds
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner()).transfer(amount);
        emit EmergencyWithdrawal(owner(), amount);
    }
    
    // ============================================
    // MAIN FUNCTIONS
    // ============================================
    
    /**
     * @notice Claim a quest reward with skill boosts applied
     * @param questId The ID of the quest to claim
     */
    function claimQuestReward(uint256 questId) external override nonReentrant {
        require(address(gamificationModule) != address(0), "Gamification not set");
        
        // 1. Verify conditions & Check if already claimed (via Gamification module)
        IEnhancedSmartStakingGamification.QuestReward memory reward = gamificationModule.getQuestReward(msg.sender, questId);
        
        require(reward.amount > 0, "No reward found");
        require(!reward.claimed, "Reward already claimed");
        require(block.timestamp <= reward.expirationTime, "Reward expired");
        
        // 2. Calculate final reward with boosts
        uint256 finalReward = calculateQuestReward(msg.sender, reward.amount);
        
        // 3. Mark as claimed in Gamification module
        gamificationModule.setQuestClaimed(msg.sender, questId);
        
        // 4. Transfer reward
        require(address(this).balance >= finalReward, "Insufficient reward funds");
        payable(msg.sender).transfer(finalReward);
        
        emit QuestRewardClaimed(msg.sender, questId, finalReward, finalReward - reward.amount);
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @notice Calculate quest reward with skill boosts applied
     * @param user The user address
     * @param baseReward The base reward amount
     * @return finalReward The calculated reward with boosts applied
     */
    function calculateQuestReward(address user, uint256 baseReward) public view override returns (uint256 finalReward) {
        if (address(skillsModule) == address(0)) {
            return baseReward;
        }
        
        // Get user boosts (stakingBoostTotal affects Quest Rewards in this new model)
        // We use stakingBoostTotal as a general "Yield Boost" for quests now that APY is gone
        (,, uint16 effectiveBoost) = skillsModule.getUserBoosts(user);
        
        // Apply effective boost (which includes rarity multiplier)
        // Formula: Base + (Base * Boost / 10000)
        if (effectiveBoost > 0) {
            finalReward = baseReward + ((baseReward * effectiveBoost) / BASIS_POINTS);
        } else {
            finalReward = baseReward;
        }
    }
    
    /**
     * @notice Calculate staking rewards (yield) for a deposit
     * @param depositAmount The amount deposited
     * @param lastClaimTime The last time rewards were claimed
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @param stakingBoostTotal The total staking boost from skills (in basis points)
     * @return rewards The calculated rewards
     */
    function calculateStakingRewards(
        uint256 depositAmount,
        uint256 /* depositTime */,
        uint256 lastClaimTime,
        uint8 lockupPeriodIndex,
        uint16 stakingBoostTotal
    ) external view override returns (uint256 rewards) {
        if (lockupPeriodIndex >= baseAPYs.length) return 0;
        
        uint256 timeElapsed = block.timestamp - lastClaimTime;
        if (timeElapsed == 0) return 0;
        
        // Base APY for this lockup period
        uint256 apy = baseAPYs[lockupPeriodIndex];
        
        // Add Skill Boost (e.g., +500 bps = +5%)
        // Total APY = Base APY + Skill Boost
        uint256 totalAPY = apy + stakingBoostTotal;
        
        // Calculate Reward: Amount * TotalAPY * Time / (365 days * 10000)
        // 10000 is BASIS_POINTS
        rewards = (depositAmount * totalAPY * timeElapsed) / (365 days * BASIS_POINTS);
    }

    /**
     * @notice Update base APY for a specific lockup period (admin only)
     * @param lockupPeriodIndex The lockup period index (0-4)
     * @param newAPY The new APY percentage in basis points
     */
    function updateBaseAPY(uint8 lockupPeriodIndex, uint256 newAPY) external onlyOwner {
        require(lockupPeriodIndex < baseAPYs.length, "Invalid lockup period");
        require(newAPY <= 10000, "Invalid APY"); // Max 100%
        baseAPYs[lockupPeriodIndex] = newAPY;
        emit APYUpdated(lockupPeriodIndex, newAPY);
    }

    function getBaseAPY(uint8 index) external view returns (uint256) {
        if (index >= baseAPYs.length) return 0;
        return baseAPYs[index];
    }

    function getLockupPeriodsConfig() external view returns (uint256[] memory periods, uint256[] memory apys) {
        return (lockupPeriods, baseAPYs);
    }

    function calculateBoostedAPY(uint8 lockupIndex, uint16 stakingBoostTotal) external view returns (uint256) {
        if (lockupIndex >= baseAPYs.length) return 0;
        return baseAPYs[lockupIndex] + stakingBoostTotal;
    }
}
