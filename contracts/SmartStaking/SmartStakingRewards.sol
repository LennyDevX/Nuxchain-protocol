// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISmartStakingRewards.sol";
import "../interfaces/ISmartStakingPower.sol";
import "../interfaces/ISmartStakingGamification.sol";
import "../interfaces/ITreasuryManager.sol";
import "../interfaces/IAPYCalculator.sol";
import "../interfaces/IQuestRewardsPool.sol";

/**
 * @title SmartStakingRewards
 * @notice Handles reward payout logic for the SmartStaking system
 * @dev Replaces APY with Quest-based rewards. Holds funds for payouts.
 */
contract SmartStakingRewards is Ownable, ReentrancyGuard, ISmartStakingRewards {
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    uint256 private constant BASIS_POINTS = 10000;
    
    /// @notice Quest reward commission (2%)
    uint256 private constant QUEST_COMMISSION_PERCENTAGE = 200; // 2% in basis points

    // ── Staking-tier thresholds (net deposited, in wei) ──
    uint256 private constant TIER_SILVER   =     100 ether;
    uint256 private constant TIER_GOLD     =   1_000 ether;
    uint256 private constant TIER_PLATINUM =  10_000 ether;

    // ── Tier APY bonuses (basis points) ──
    uint16 private constant TIER_SILVER_BONUS   =  25;   // +0.25%
    uint16 private constant TIER_GOLD_BONUS     =  75;   // +0.75%
    uint16 private constant TIER_PLATINUM_BONUS = 150;   // +1.50%

    // ── Loyalty APY bonuses (basis points) ──────────────
    uint16 private constant LOYALTY_90D_BONUS  =  25;   // +0.25%  (90+ days)
    uint16 private constant LOYALTY_180D_BONUS =  50;   // +0.50%  (180+ days)
    uint16 private constant LOYALTY_365D_BONUS = 100;   // +1.00%  (365+ days)
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    ISmartStakingPower public powerModule;
    ISmartStakingGamification public gamificationModule;
    ITreasuryManager public treasuryManager;
    IAPYCalculator public apyCalculator;

    /// @notice Central quest rewards pool — set by admin after deployment.
    IQuestRewardsPool public questRewardsPool;

    /// @notice Core staking contract authorized to update TVL
    address public coreStakingContract;

    /// @notice Timestamp of when a user made their first-ever deposit (set by Core, never reset until full exit).
    /// Used to compute the loyalty bonus.
    mapping(address => uint256) public stakingSince;
    
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
        
        // Initialize base APYs - v6.3.0 SUSTAINABILITY REDUCTION
        // Flexible: -10% | 30d/90d: -15% | 180d/365d: -20% (over v6.2.0)
        baseAPYs = [
             86,    //  8.60% APY (No Lock)    - was  9.60% (-10%) | v6.2.0  9.60%
            146,    // 14.60% APY (30 Days)    - was 17.20% (-15%) | v6.2.0 17.20%
            193,    // 19.30% APY (90 Days)    - was 22.70% (-15%) | v6.2.0 22.70%
            242,    // 24.20% APY (180 Days)   - was 30.30% (-20%) | v6.2.0 30.30%
            255     // 25.50% APY (365 Days)   - was 31.90% (-20%) | v6.2.0 31.90%
        ];
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    function setPowerModule(address _powerModule) external onlyOwner {
        require(_powerModule != address(0), "Invalid address");
        powerModule = ISmartStakingPower(_powerModule);
    }
    
    function setGamificationModule(address _gamificationModule) external onlyOwner {
        require(_gamificationModule != address(0), "Invalid address");
        gamificationModule = ISmartStakingGamification(_gamificationModule);
    }
    
    /**
     * @notice Set the quest rewards pool contract address
     * @param pool_ The quest rewards pool contract address
     */
    function setQuestRewardsPool(address pool_) external onlyOwner {
        require(pool_ != address(0), "Invalid address");
        questRewardsPool = IQuestRewardsPool(pool_);
    }

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
     * @notice Set the core staking contract authorized to update TVL
     * @param _core The core staking contract address
     */
    function setCoreContract(address _core) external onlyOwner {
        require(_core != address(0), "Invalid address");
        coreStakingContract = _core;
    }

    /**
     * @notice Record a user's first-stake timestamp (called by Core on first deposit).
     * @dev Only callable by Core. Never resets unless Core explicitly calls with 0.
     */
    function recordStakingSince(address user, uint256 timestamp) external {
        require(msg.sender == coreStakingContract || msg.sender == owner(), "Not authorized");
        stakingSince[user] = timestamp;
    }

    /**
     * @notice Clear staking-since on full withdrawal (retain zero = no loyalty yet).
     */
    function clearStakingSince(address user) external {
        require(msg.sender == coreStakingContract || msg.sender == owner(), "Not authorized");
        stakingSince[user] = 0;
    }

    /**
     * @notice Update current TVL (called by Core contract or owner)
     * @param _currentTVL The current total value locked
     */
    function updateCurrentTVL(uint256 _currentTVL) external {
        require(msg.sender == owner() || msg.sender == coreStakingContract, "Not authorized");
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
        ISmartStakingGamification.QuestReward memory reward = gamificationModule.getQuestReward(msg.sender, questId);
        
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
            try treasuryManager.receiveRevenue{value: commission}("quest_reward_commission") {
            } catch {
                // If treasury transfer fails, add back to user reward
                userReward = finalReward;
            }
        } else {
            // No treasury set, user gets full reward
            userReward = finalReward;
        }
        
        // 6. Transfer reward to user
        // Primary: use central QuestRewardsPool if configured.
        // Fallback: pay from this contract's own balance (+ emergency TreasuryManager request).
        if (address(questRewardsPool) != address(0)) {
            questRewardsPool.requestPayout(msg.sender, userReward, "staking_quest");
        } else {
            if (address(this).balance < userReward) {
                uint256 deficit = userReward - address(this).balance;
                bool emergencySuccess = false;
                try treasuryManager.requestEmergencyFunds(
                    ITreasuryManager.TreasuryType.REWARDS,
                    deficit
                ) returns (bool success) {
                    emergencySuccess = success;
                } catch {}
                require(address(this).balance >= userReward, "Insufficient reward funds");
            }
            payable(msg.sender).transfer(userReward);
        }

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
        if (address(powerModule) == address(0)) {
            return baseReward;
        }
        
        // Get user boosts (stakingBoostTotal affects Quest Rewards in this new model)
        // We use stakingBoostTotal as a general "Yield Boost" for quests now that APY is gone
        (,, uint16 effectiveBoost) = powerModule.getUserBoosts(user);
        
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
     * @notice Extended reward calculation with tier and loyalty bonuses.
     * @dev Called by Core when it has the full user context.
     * @param depositAmount       Individual deposit amount.
     * @param lastClaimTime       Last claim timestamp for this deposit.
     * @param lockupPeriodIndex   Lockup tier index (0-4).
     * @param stakingBoostTotal   Skill-based APY boost in bps.
     * @param totalDeposited      User's total net deposited (for tier computation).
     * @param userAddress         User address (for loyalty computation).
     */
    function calculateStakingRewardsWithBonuses(
        uint256 depositAmount,
        uint256 lastClaimTime,
        uint8   lockupPeriodIndex,
        uint16  stakingBoostTotal,
        uint256 totalDeposited,
        address userAddress
    ) external view returns (uint256 rewards) {
        if (lockupPeriodIndex >= baseAPYs.length) return 0;

        uint256 timeElapsed = block.timestamp - lastClaimTime;
        if (timeElapsed == 0) return 0;

        uint256 apy = baseAPYs[lockupPeriodIndex];

        if (address(apyCalculator) != address(0) && currentTVL > 0) {
            apy = apyCalculator.calculateDynamicAPY(apy, currentTVL);
        }

        uint256 totalAPY = apy
            + stakingBoostTotal
            + getTierBonus(totalDeposited)
            + getLoyaltyBonus(userAddress);

        rewards = (depositAmount * totalAPY * timeElapsed) / (365 days * BASIS_POINTS);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // TIER & LOYALTY VIEW HELPERS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Return the tier label for a given total deposited amount.
     * @return tierName   "Bronze" | "Silver" | "Gold" | "Platinum"
     * @return bonusBps   APY bonus in basis points for this tier.
     */
    function getUserTier(uint256 totalDeposited) external pure returns (string memory tierName, uint256 bonusBps) {
        if (totalDeposited >= TIER_PLATINUM) return ("Platinum", TIER_PLATINUM_BONUS);
        if (totalDeposited >= TIER_GOLD)     return ("Gold",     TIER_GOLD_BONUS);
        if (totalDeposited >= TIER_SILVER)   return ("Silver",   TIER_SILVER_BONUS);
        return ("Bronze", 0);
    }

    /// @notice Return tier APY bonus in basis points (pure, no state needed).
    function getTierBonus(uint256 totalDeposited) public pure returns (uint16 bonus) {
        if (totalDeposited >= TIER_PLATINUM) return TIER_PLATINUM_BONUS;
        if (totalDeposited >= TIER_GOLD)     return TIER_GOLD_BONUS;
        if (totalDeposited >= TIER_SILVER)   return TIER_SILVER_BONUS;
        return 0;
    }

    /// @notice Return loyalty APY bonus in basis points based on how long user has been staking.
    function getLoyaltyBonus(address user) public view returns (uint16 bonus) {
        uint256 since = stakingSince[user];
        if (since == 0) return 0;
        uint256 duration = block.timestamp - since;
        if (duration >= 365 days) return LOYALTY_365D_BONUS;
        if (duration >= 180 days) return LOYALTY_180D_BONUS;
        if (duration >= 90  days) return LOYALTY_90D_BONUS;
        return 0;
    }

    /// @notice Return days a user has been continuously staking.
    function getLoyaltyDays(address user) external view returns (uint256 days_) {
        uint256 since = stakingSince[user];
        if (since == 0) return 0;
        return (block.timestamp - since) / 1 days;
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

    /// @notice Return all base APYs as a dynamic array (read by ViewStats / Dashboard).
    function getBaseAPYs() external view returns (uint256[] memory) {
        return baseAPYs;
    }

    /**
     * @notice Simulate effective APY for a user including skills and dynamic APY
     * @param depositAmount The amount to simulate (in wei)
     * @param lockupPeriodIndex The lockup period index (0=flexible, 1=30d, 2=90d, 3=180d, 4=365d)
     * @param user The user address (used to fetch skill boosts)
     * @return effectiveAPY The total APY in basis points (base + dynamic + skills)
     * @return annualRewards Estimated annual rewards in wei for the given deposit amount
     */
    function simulateAPY(
        uint256 depositAmount,
        uint8 lockupPeriodIndex,
        address user
    ) external view returns (uint256 effectiveAPY, uint256 annualRewards) {
        if (lockupPeriodIndex >= baseAPYs.length) return (0, 0);

        // 1. Start with base APY for this period
        uint256 apy = baseAPYs[lockupPeriodIndex];

        // 2. Apply dynamic APY if calculator is set and TVL is available
        if (address(apyCalculator) != address(0) && currentTVL > 0) {
            apy = apyCalculator.calculateDynamicAPY(apy, currentTVL);
        }

        // 3. Add skill boosts for this user
        if (address(powerModule) != address(0) && user != address(0)) {
            (uint16 stakingBoost,,) = powerModule.getUserBoosts(user);
            apy += stakingBoost;
        }

        effectiveAPY = apy;
        // Annual rewards = depositAmount * effectiveAPY / BASIS_POINTS
        annualRewards = (depositAmount * effectiveAPY) / BASIS_POINTS;
    }

    function getLockupPeriodsConfig() external view returns (uint256[] memory periods, uint256[] memory apys) {
        return (lockupPeriods, baseAPYs);
    }

    function calculateBoostedAPY(uint8 lockupIndex, uint16 stakingBoostTotal) external view returns (uint256) {
        if (lockupIndex >= baseAPYs.length) return 0;
        return baseAPYs[lockupIndex] + stakingBoostTotal;
    }
}
