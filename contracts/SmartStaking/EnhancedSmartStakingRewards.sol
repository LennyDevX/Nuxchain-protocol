// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IEnhancedSmartStakingRewards.sol";
import "../interfaces/IEnhancedSmartStakingSkills.sol";
import "../interfaces/IEnhancedSmartStakingGamification.sol";
import "../interfaces/ITreasuryManager.sol";
import "../interfaces/IAPYCalculator.sol";

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
    
    /// @notice Quest reward commission (2%)
    uint256 private constant QUEST_COMMISSION_PERCENTAGE = 200; // 2% in basis points
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    IEnhancedSmartStakingSkills public skillsModule;
    IEnhancedSmartStakingGamification public gamificationModule;
    ITreasuryManager public treasuryManager;
    IAPYCalculator public apyCalculator;
    
    // Staking Yield Configuration
    uint256[] private lockupPeriods;
    uint256[] private baseAPYs;
    
    /// @notice Current total value locked in the staking system (updated externally)
    uint256 public currentTVL;
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        // Initialize lockup periods: 0, 30, 90, 180, 365 days
        lockupPeriods = [0, 30 days, 90 days, 180 days, 365 days];
        
        // Initialize base APYs - REDUCED 25% FOR SUSTAINABILITY (v5.1.0)
        // Formula: Hourly ROI × 24 hours × 365 days = Annual APY
        // Previous rates reduced by 25% to ensure long-term protocol viability
        baseAPYs = [
            197,    // 19.7% APY (No Lock)     - 0.0022% per hour (was 26.3%)
            328,    // 32.8% APY (30 Days)     - 0.0037% per hour (was 43.8%)
            591,    // 59.1% APY (90 Days)     - 0.0067% per hour (was 78.8%)
            788,    // 78.8% APY (180 Days)    - 0.0090% per hour (was 105.12%)
            1183    // 118.3% APY (365 Days)   - 0.0135% per hour (was 157.68%)
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
     * @notice Set the treasury manager contract address
     * @param _treasuryManager The treasury manager contract address
     */
    function setTreasuryManager(address _treasuryManager) external onlyOwner {
        require(_treasuryManager != address(0), "Invalid address");
        treasuryManager = ITreasuryManager(_treasuryManager);
    }
    
    /**
     * @notice Set the APY calculator contract address
     * @param _apyCalculator The APY calculator contract address
     */
    function setAPYCalculator(address _apyCalculator) external onlyOwner {
        require(_apyCalculator != address(0), "Invalid address");
        apyCalculator = IAPYCalculator(_apyCalculator);
    }
    
    /**
     * @notice Update current TVL (called by Core contract)
     * @param _currentTVL The current total value locked
     */
    function updateCurrentTVL(uint256 _currentTVL) external onlyOwner {
        currentTVL = _currentTVL;
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
        
        // 3. Calculate and deduct 2% commission
        uint256 commission = (finalReward * QUEST_COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 userReward = finalReward - commission;
        
        // 4. Mark as claimed in Gamification module
        gamificationModule.setQuestClaimed(msg.sender, questId);
        
        // 5. Transfer commission to Treasury Manager if available
        if (address(treasuryManager) != address(0) && commission > 0) {
            (bool commissionSent, ) = payable(address(treasuryManager)).call{value: commission}("");
            if (!commissionSent) {
                // If treasury transfer fails, add back to user reward
                userReward = finalReward;
            }
        } else {
            // No treasury set, user gets full reward
            userReward = finalReward;
        }
        
        // 6. Transfer reward to user with emergency fallback
        // If insufficient balance, try to request emergency funds from TreasuryManager
        if (address(this).balance < userReward) {
            // Calculate deficit
            uint256 deficit = userReward - address(this).balance;
            
            // Try to request emergency funds
            bool emergencySuccess = false;
            try treasuryManager.requestEmergencyFunds(
                ITreasuryManager.TreasuryType.REWARDS,
                deficit
            ) returns (bool success) {
                emergencySuccess = success;
            } catch {
                // Emergency funds not available
            }
            
            // Final check after emergency attempt
            require(address(this).balance >= userReward, "Insufficient reward funds");
        }
        
        payable(msg.sender).transfer(userReward);
        
        emit QuestRewardClaimed(msg.sender, questId, userReward, userReward - reward.amount);
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
        
        // Get base APY for this lockup period
        uint256 apy = baseAPYs[lockupPeriodIndex];
        
        // Apply dynamic APY if calculator is set and TVL is available
        if (address(apyCalculator) != address(0) && currentTVL > 0) {
            apy = apyCalculator.calculateDynamicAPY(apy, currentTVL);
        }
        
        // Add Skill Boost (e.g., +500 bps = +5%)
        // Total APY = Dynamic APY + Skill Boost
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
