# 🏦 EnhancedSmartStaking - Complete Technical Reference

## Contract Address
**Polygon Mainnet**: `0xae57acBf4efE2F6536D992F86145a20e11DB8C3D`

---

## 📋 Core Parameters

### Deposit Limits
```solidity
MIN_DEPOSIT = 10 ETH
MAX_DEPOSIT = 10000 ETH
DAILY_WITHDRAWAL_LIMIT = 1000 ETH
```

### Reward Configuration
```solidity
HOURLY_ROI_PERCENTAGE = 50 (0.005% per hour)
MAX_ROI_PERCENTAGE = 12500 (125% cap)
COMMISSION_PERCENTAGE = 600 (6%)
BASIS_POINTS = 10000
```

### Time Parameters
```solidity
WITHDRAWAL_LIMIT_PERIOD = 1 days
AUTO_COMPOUND_INTERVAL = 1 days
QUEST_REWARD_EXPIRATION = 30 days
ACHIEVEMENT_REWARD_EXPIRATION = 30 days
```

---

## 🎮 Skill System

### Skill Types Enum
```solidity
enum SkillType {
    NONE = 0,
    STAKE_BOOST_I = 1,
    STAKE_BOOST_II = 2,
    STAKE_BOOST_III = 3,
    AUTO_COMPOUND = 4,
    LOCK_REDUCER = 5,
    FEE_REDUCER_I = 6,
    FEE_REDUCER_II = 7
}
```

### Rarity Levels
```solidity
enum Rarity {
    COMMON = 0,      // 1.0x multiplier
    UNCOMMON = 1,    // 1.1x multiplier
    RARE = 2,        // 1.2x multiplier
    EPIC = 3,        // 1.4x multiplier
    LEGENDARY = 4    // 1.8x multiplier
}
```

### Skill Effects (Basis Points)
```
STAKE_BOOST_I:    500 bp    (+5%)
STAKE_BOOST_II:   1000 bp   (+10%)
STAKE_BOOST_III:  2000 bp   (+20%)
FEE_REDUCER_I:    1000 bp   (-10%)
FEE_REDUCER_II:   2500 bp   (-25%)
LOCK_REDUCER:     2500 bp   (-25%)
AUTO_COMPOUND:    0 bp      (special)
```

---

## 💰 Reward Calculation Formula

### Base Reward
```
baseReward = (depositAmount × hourlyROI × elapsedHours) / 1,000,000
```

### With Time Bonus
```
timeBonus = {
    365 days:  +5%
    180 days:  +3%
    90 days:   +1%
    30 days:   +0.5%
}
```

### With Skill Boosts
```
skillBoost = baseReward × (stakingBoostTotal / 10000)
feeDiscount = commission × (1 - feeDiscountTotal / 10000)
```

### Final Calculation
```
totalReward = (baseReward + timeBonus + questRewards + achievementRewards)
            × (1 + skillBoost / 10000)
            × rarityMultiplier
            - (commission × (1 - feeDiscount / 10000))
```

---

## 📊 Data Structures

### Deposit Struct
```solidity
struct Deposit {
    uint128 amount;           // Deposit amount
    uint64 timestamp;         // Deposit time
    uint64 lastClaimTime;     // Last claim time
    uint64 lockupDuration;    // Lock-up period in seconds
}
```

### User Struct
```solidity
struct User {
    Deposit[] deposits;       // Array of deposits
    uint128 totalDeposited;   // Cumulative total
    uint64 lastWithdrawTime;  // Last withdrawal
}
```

### UserSkillProfile Struct
```solidity
struct UserSkillProfile {
    uint256 totalXP;               // Accumulated XP
    uint8 level;                   // Level 1-5
    uint16 stakingBoostTotal;      // Combined boost (bp)
    uint16 feeDiscountTotal;       // Combined discount (bp)
    uint16 lockupReduction;        // Lock reduction (bp)
    bool hasAutoCompound;          // Auto-compound active
    uint16 currentBoostPercentage; // Current boost %
}
```

### NFTSkill Struct
```solidity
struct NFTSkill {
    SkillType skillType;       // Type of skill
    uint16 effectValue;        // Effect magnitude (bp)
    Rarity rarity;             // Rarity level
    uint64 activatedAt;        // Activation time
    bool isActive;             // Current status
}
```

---

## 🔑 Main Functions

### Write Functions

#### Deposits
```solidity
deposit(uint64 _lockupDuration) external payable
depositWithBoosts(uint64 _lockupDuration) external payable
```

#### Withdrawals
```solidity
withdraw() external
withdrawBoosted() external
withdrawAll() external
```

#### Auto-Compound
```solidity
compound() external
performAutoCompound(bytes performData) external
batchAutoCompound(address[] userAddresses) external
```

#### Admin
```solidity
setMarketplaceAddress(address _marketplace) external
setSkillEnabled(SkillType _skillType, bool _enabled) external
updateSkillEffect(SkillType _skillType, uint16 _newEffect) external
pause() external
unpause() external
```

### View Functions

#### Reward Calculations
```solidity
calculateRewards(address userAddress) external view returns (uint256)
calculateBoostedRewards(address userAddress) external view returns (uint256)
calculateBoostedRewardsWithRarityMultiplier(address user) external view returns (uint256)
```

#### User Information
```solidity
getUserInfo(address userAddress) external view returns (User memory)
getUserDeposits(address userAddress) external view returns (Deposit[])
getDepositCount(address userAddress) external view returns (uint256)
getTotalDeposit(address userAddress) external view returns (uint256)
getUserDetailedStats(address user) external view returns (...)
```

#### Skill Information
```solidity
getUserSkillProfile(address user) external view returns (UserSkillProfile)
getActiveSkills(address user) external view returns (NFTSkill[])
getActiveSkillNFTIds(address user) external view returns (uint256[])
getNFTSkill(uint256 nftId) external view returns (NFTSkill)
getNFTRarity(uint256 nftId) external view returns (Rarity)
```

#### Contract State
```solidity
getContractBalance() external view returns (uint256)
getUniqueUsersCount() external view returns (uint256)
getTotalPoolBalance() external view returns (uint256)
isPaused() external view returns (bool)
```

---

## 🔗 Marketplace Integration

### Called By Marketplace

```solidity
notifySkillActivation(
    address user,
    uint256 nftId,
    SkillType _skillType
) external

notifySkillDeactivation(
    address user,
    uint256 nftId,
    SkillType _skillType
) external

notifyQuestCompletion(
    address user,
    uint256 questId,
    uint256 rewardAmount
) external

notifyAchievementUnlocked(
    address user,
    uint256 achievementId,
    uint256 rewardAmount
) external

setSkillRarity(
    uint256 nftId,
    Rarity rarity
) external

updateUserXP(
    address user,
    uint256 xpGained
) external
```

---

## 📈 Events

```solidity
event Deposited(address indexed user, uint256 amount, uint256 lockupDuration)
event Withdrawn(address indexed user, uint256 amount)
event WithdrawAll(address indexed user, uint256 totalAmount)
event Compounded(address indexed user, uint256 amount)
event EmergencyWithdrawal(address indexed user, uint256 amount)
event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury)
event MigrationInitiated(address indexed newContract)
event CommissionPaid(address indexed receiver, uint256 amount, uint256 timestamp)
event RewardsCompounded(address indexed user, uint256 amount)
event SkillApplied(address indexed user, uint256 indexed tokenId, SkillType skillType)
event SkillRemoved(address indexed user, uint256 indexed tokenId, SkillType skillType)
```

---

## ⚙️ Modifiers

```solidity
modifier onlyOwner()          // Owner access only
modifier onlyMarketplace()    // Marketplace access only
modifier nonReentrant()       // Reentrancy protection
modifier whenNotPaused()      // Execute only when active
modifier validAddress()       // Address validation
```

---

## 🧪 Usage Examples

### Basic Staking
```javascript
const deposit = ethers.parseEther("50");
const lockupDays = 90;

const tx = await staking.deposit(lockupDays, { value: deposit });
await tx.wait();

const rewards = await staking.calculateRewards(userAddress);
console.log("Rewards:", ethers.formatEther(rewards));
```

### Auto-Compound
```javascript
const canAutoCompound = await staking.checkAutoCompound(userAddress);
if (canAutoCompound) {
    const performData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address"],
        [userAddress]
    );
    const tx = await staking.performAutoCompound(performData);
    await tx.wait();
}
```

### Query User Stats
```javascript
const stats = await staking.getUserDetailedStats(userAddress);
console.log({
    level: stats.skillLevel,
    totalXP: stats.totalXP.toString(),
    boostPercentage: stats.currentBoostPercentage,
    autoCompound: stats.hasAutoCompound
});
```

---

## 🔐 Security

```
✅ ReentrancyGuard: Prevents reentrancy attacks
✅ Pausable: Emergency stop capability
✅ onlyMarketplace: Validates caller
✅ Input validation: All parameters checked
✅ Safe math: BigNumber arithmetic
✅ Storage safety: Gap arrays for upgrades
```

---

Generated: 2025-11-03  
Version: 4.0.0
