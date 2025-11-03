# 🎮 GameifiedMarketplace - Complete Technical Reference

## Contract Address
**Polygon Mainnet**: `0xB948cC766CBE97Ce822bF4c915D2319fbc48Ad38`

---

## 📋 Core Parameters

### Marketplace Configuration
```solidity
PLATFORM_FEE_PERCENTAGE = 5              // 5% on sales
STAKING_REWARD_COMMISSION_PERCENTAGE = 200  // 2% (bp)
```

### Skill NFT Configuration
```solidity
MIN_POL_FOR_SKILL_NFT = 200 * 10^18     // 200 POL required
FIRST_SKILL_FREE = 1                     // First skill free
ADDITIONAL_SKILL_MIN_FEE = 25 * 10^18   // 25 POL minimum
ADDITIONAL_SKILL_MAX_FEE = 100 * 10^18  // 100 POL maximum
SKILL_CHANGE_COOLDOWN = 7 days           // 7-day cooldown
SKILL_CHANGE_FEE = 10 * 10^18           // 10 POL to bypass
```

### Skill Levels System
```solidity
MAX_SKILLS_LEVEL_1 = 1    // Level 1: 1 active skill
MAX_SKILLS_LEVEL_2 = 2    // Level 2: 2 active skills
MAX_SKILLS_LEVEL_3 = 3    // Level 3: 3 active skills
MAX_SKILLS_LEVEL_4 = 4    // Level 4: 4 active skills
MAX_SKILLS_LEVEL_5 = 5    // Level 5: 5 active skills
```

### XP Configuration
```solidity
XP_CREATE_NFT = 10        // Create NFT
XP_SELL_NFT = 20          // Sell NFT
XP_BUY_NFT = 15           // Buy NFT
XP_LIKE = 1               // Like NFT
XP_COMMENT = 2            // Comment
XP_REFERRAL = 50          // Referral reward
```

---

## 🎮 Gamification System

### Level Thresholds
```
Level  │ XP Required │ Max Skills │ Special Benefits
───────┼─────────────┼────────────┼─────────────────
   1   │ 100+        │ 1          │ Basic trading
   2   │ 300+        │ 2          │ Reduced fees
   3   │ 700+        │ 3          │ Higher earnings
   4   │ 1500+       │ 4          │ Quest access
   5   │ 3000+       │ 5          │ Full features
```

### Rarity System
```solidity
enum Rarity {
    COMMON = 0,        // 1 star     • Base effect
    UNCOMMON = 1,      // 2 stars    • 1.1x boost
    RARE = 2,          // 3 stars    • 1.2x boost
    EPIC = 3,          // 4 stars    • 1.4x boost
    LEGENDARY = 4      // 5 stars    • 1.8x boost
}
```

---

## 📊 Data Structures

### NFTMetadata Struct
```solidity
struct NFTMetadata {
    string category;           // NFT category
    uint256 creationTimestamp; // Created at
    address creator;           // Creator address
    bool isListed;             // Listed for sale?
    uint256 listedPrice;       // Sale price
}
```

### Offer Struct
```solidity
struct Offer {
    uint256 nftId;             // NFT being offered
    address offeror;           // Who made offer
    uint256 offerAmount;       // Offer price
}
```

### SkillNFT Struct
```solidity
struct SkillNFT {
    uint256 tokenId;           // NFT ID
    SkillType skillType;       // Skill type
    uint16 effectValue;        // Effect (bp)
    Rarity rarity;             // Rarity level
    uint8 stars;               // Star rating (1-5)
    uint64 mintedAt;           // Minted time
    uint64 lastActivationTime; // Last activation
    bool isSkillActive;        // Currently active?
}
```

### UserProfile Struct
```solidity
struct UserProfile {
    uint256 totalXP;           // Total XP accumulated
    uint8 level;               // Level 1-5
    uint8 maxActiveSkills;     // Available skill slots
    uint8 skillsLevel;         // Skill tier
    uint32 nftsCreated;        // Total created
    uint32 nftsSold;           // Total sold
    uint32 nftsBought;         // Total bought
    uint64 lastActivityTime;   // Last action
}
```

### Achievement Struct
```solidity
struct Achievement {
    uint256 id;                // Achievement ID
    string title;              // Achievement name
    string description;        // Description
    uint256 xpReward;          // XP reward
    bool isActive;             // Is active?
}
```

### Quest Struct
```solidity
struct Quest {
    uint256 id;                // Quest ID
    string title;              // Quest name
    uint256 targetCount;       // Target count
    uint256 xpReward;          // XP reward
    uint256 rewardAmount;      // POL reward
    bool isActive;             // Is active?
}
```

---

## 🔑 Main Functions

### Write Functions - NFT Creation

#### Create Skill NFT
```solidity
createSkillNFT(
    string memory _tokenURI,
    string memory category,
    uint96 royaltyPercentage,
    SkillType[] memory _skills,
    uint16[] memory _effectValues,
    Rarity[] memory _rarities
) external returns (uint256 tokenId)
```

### Write Functions - Trading

#### List NFT
```solidity
listTokenForSale(
    uint256 _tokenId,
    uint256 _price
) external
```

#### Buy NFT
```solidity
buyToken(uint256 _tokenId) external payable
```

#### Make Offer
```solidity
makeOffer(
    uint256 _tokenId,
    uint256 _offerAmount,
    uint8 _expiresInDays
) external payable
```

#### Accept Offer
```solidity
acceptOffer(
    uint256 _tokenId,
    uint256 _offerIndex
) external
```

#### Update Price
```solidity
updatePrice(
    uint256 _tokenId,
    uint256 _newPrice
) external
```

### Write Functions - Skills

#### Activate Skill
```solidity
activateSkill(uint256 _tokenId) external
```

#### Deactivate Skill
```solidity
deactivateSkill(uint256 _tokenId) external
```

#### Change Skill NFT
```solidity
changeSkillNFT(
    uint256 _oldTokenId,
    uint256 _newTokenId
) external payable
```

### Write Functions - Social

#### Like/Unlike
```solidity
toggleLike(uint256 _tokenId) external
```

#### Comment
```solidity
addComment(
    uint256 _tokenId,
    string memory _comment
) external
```

### View Functions - User Information

#### Get Profile
```solidity
getUserProfile(address _user) external view returns (UserProfile)
```

#### Check Permissions
```solidity
canUserCreateSkillNFT(address _user) external view returns (bool)
canUserActivateSkill(address _user) external view returns (bool)
```

### View Functions - NFT Information

#### Get Skill Details
```solidity
getSkillDetails(uint256 _tokenId) external view returns (SkillNFT)
```

#### Get Metadata
```solidity
getNFTMetadata(uint256 _tokenId) external view returns (NFTMetadata)
```

#### Get Trading Info
```solidity
getNFTOffers(uint256 _tokenId) external view returns (Offer[])
getNFTComments(uint256 _tokenId) external view returns (string[])
getNFTLikeCount(uint256 _tokenId) external view returns (uint256)
```

### View Functions - Staking Integration

#### Get Staking Balance
```solidity
getUserStakingBalance(address _user) external view returns (uint256)
```

#### Calculate Rewards
```solidity
calculateCommissionFromRewards(uint256 _rewardAmount) external view returns (uint256)
```

---

## 🔗 Staking Integration Functions

### Called By Marketplace

```solidity
// Notify quest completion
notifyQuestCompletion(
    address user,
    uint256 questId,
    uint256 rewardAmount
) external

// Notify achievement unlock
notifyAchievementUnlocked(
    address user,
    uint256 achievementId,
    uint256 rewardAmount
) external

// Update user XP
updateUserXP(
    address user,
    uint256 xpGained
) external
```

### Called By External (Admin)

```solidity
// Update staking address
setStakingContractAddress(address _newAddress) external

// Update POL token address
setPolTokenAddress(address _tokenAddress) external

// Update staking treasury
setStakingTreasuryAddress(address _treasuryAddress) external
```

---

## 📈 Events

```solidity
// Marketplace events
event TokenCreated(address indexed creator, uint256 indexed tokenId, string uri)
event TokenListed(address indexed seller, uint256 indexed tokenId, uint256 price)
event TokenUnlisted(address indexed seller, uint256 indexed tokenId)
event TokenSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price)
event OfferMade(address indexed offeror, uint256 indexed tokenId, uint256 amount)
event OfferAccepted(address indexed seller, address indexed buyer, uint256 indexed tokenId)

// Social events
event TokenLiked(address indexed user, uint256 indexed tokenId)
event TokenUnliked(address indexed user, uint256 indexed tokenId)
event CommentAdded(address indexed user, uint256 indexed tokenId, string comment)

// Gamification events
event LevelUp(address indexed user, uint8 newLevel)
event SkillActivated(address indexed user, uint256 indexed tokenId, SkillType skillType)
event SkillDeactivated(address indexed user, uint256 indexed tokenId, SkillType skillType)
event AchievementUnlocked(address indexed user, uint256 indexed achievementId)
event QuestCompleted(address indexed user, uint256 indexed questId)

// Admin events
event StakingContractUpdated(address indexed newContract)
event PolTokenUpdated(address indexed newToken)
event TreasuryUpdated(address indexed newTreasury)
```

---

## ⚙️ Role-Based Access Control

### ADMIN_ROLE
```solidity
// Can perform
├── setStakingContractAddress()
├── setPolTokenAddress()
├── setStakingTreasuryAddress()
├── pause()
├── unpause()
└── Admin functions
```

### MODERATOR_ROLE
```solidity
// Can perform
├── removeComment()
├── removeInappropriateNFT()
└── Moderation functions
```

### PUBLIC (No Role Required)
```solidity
// Can perform
├── createSkillNFT()
├── listTokenForSale()
├── buyToken()
├── activateSkill()
├── toggleLike()
├── addComment()
└── All trading functions
```

---

## 🧪 Usage Examples

### Create Skill NFT
```javascript
const tx = await marketplace.createSkillNFT(
    "ipfs://QmXXX...",      // Token URI
    "combat",                // Category
    500,                     // 5% royalty
    [1, 4, 6],              // Skill types
    [500, 1000, 1000],      // Effects (bp)
    [2, 3, 1]               // Rarities (RARE, EPIC, UNCOMMON)
);
const receipt = await tx.wait();
const tokenId = receipt.events[0].args.tokenId;
```

### Trade NFT
```javascript
// List for sale
await marketplace.listTokenForSale(tokenId, ethers.parseEther("5"));

// Buyer purchases
await marketplace.buyToken(tokenId, { value: ethers.parseEther("5") });

// Or make offer
await marketplace.makeOffer(tokenId, ethers.parseEther("4.5"), 7);

// Seller accepts
await marketplace.acceptOffer(tokenId, 0);
```

### Activate Skill
```javascript
// Activate skill boost
await marketplace.activateSkill(tokenId);

// Deactivate if needed
await marketplace.deactivateSkill(tokenId);
```

### Social Features
```javascript
// Like NFT
await marketplace.toggleLike(tokenId);

// Comment
await marketplace.addComment(tokenId, "Amazing NFT!");

// Get profile
const profile = await marketplace.getUserProfile(userAddress);
console.log(`Level: ${profile.level}, XP: ${profile.totalXP}`);
```

---

## 🔐 Security

```
✅ AccessControl: Role-based permissions
✅ ReentrancyGuard: Prevents reentrancy
✅ Pausable: Emergency stop
✅ ERC721 Standard: Safe transfers
✅ Royalty Support: ERC2981 compliance
✅ Input Validation: All parameters checked
```

---

Generated: 2025-11-03  
Version: 2.0.0
