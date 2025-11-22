# Marketplace View Functions Analysis

## Executive Summary

Este documento analiza las funciones view existentes en los contratos de Marketplace y propone nuevas funciones para crear un dashboard completo con estadísticas detalladas.

## Contratos Analizados

1. **GameifiedMarketplaceCoreV1.sol** - Core NFT Marketplace (444 líneas)
2. **GameifiedMarketplaceSkillsV2.sol** - NFT-Embedded Skills (959 líneas)
3. **IndividualSkillsMarketplace.sol** - Direct Skill Purchases (1452 líneas)
4. **GameifiedMarketplaceQuests.sol** - Quest System (422 líneas)
5. **LevelingSystem.sol** - XP & Leveling (284 líneas)
6. **ReferralSystem.sol** - Referral Network (171 líneas)

---

## 1. GameifiedMarketplaceCoreV1.sol

### Funciones View Existentes ✅
```solidity
// Basic NFT Data
function getNFTMetadata(uint256 _tokenId) external view returns (NFTMetadata memory)
function getNFTLikeCount(uint256 _tokenId) external view returns (uint256)
function getNFTComments(uint256 _tokenId) external view returns (string[] memory)
function getNFTOffers(uint256 _tokenId) external view returns (Offer[] memory)

// User Data
function getUserNFTs(address _user) external view returns (uint256[] memory)
function getUserCreatedNFTs(address _user) external view returns (uint256[] memory)

// Market Data
function getListedNFTs() external view returns (uint256[] memory)
```

### Funciones Propuestas para Dashboard 📊

```solidity
/**
 * @dev Get comprehensive marketplace statistics
 * @return totalNFTs Total NFTs ever created
 * @return totalListed Currently listed NFTs
 * @return totalSold NFTs sold (all-time)
 * @return totalVolume Trading volume in POL
 * @return totalCreators Unique creators
 * @return totalRoyalties Total royalties paid to creators
 */
function getMarketplaceStats() external view returns (
    uint256 totalNFTs,
    uint256 totalListed,
    uint256 totalSold,
    uint256 totalVolume,
    uint256 totalCreators,
    uint256 totalRoyalties
)

/**
 * @dev Get user trading statistics
 * @return nftsCreated Total NFTs created by user
 * @return nftsOwned Current NFTs owned
 * @return nftsSold NFTs sold by user
 * @return nftsBought NFTs purchased by user
 * @return totalSalesVolume Volume from sales (POL)
 * @return totalPurchaseVolume Volume from purchases (POL)
 * @return totalRoyaltiesEarned Royalties earned as creator
 */
function getUserTradingStats(address _user) external view returns (
    uint256 nftsCreated,
    uint256 nftsOwned,
    uint256 nftsSold,
    uint256 nftsBought,
    uint256 totalSalesVolume,
    uint256 totalPurchaseVolume,
    uint256 totalRoyaltiesEarned
)

/**
 * @dev Get NFTs by category with pagination
 * @param _category Category to filter (Art, Music, etc.)
 * @param _offset Starting index
 * @param _limit Number of results
 */
function getNFTsByCategory(string calldata _category, uint256 _offset, uint256 _limit) 
    external view returns (uint256[] memory tokenIds, NFTMetadata[] memory metadata)

/**
 * @dev Get user's active offers (offers made by user)
 */
function getUserActiveOffers(address _user) external view returns (
    uint256[] memory tokenIds,
    Offer[] memory offers
)

/**
 * @dev Get user's received offers (offers on user's NFTs)
 */
function getUserReceivedOffers(address _user) external view returns (
    uint256[] memory tokenIds,
    Offer[] memory offers
)

/**
 * @dev Get trending NFTs (most liked in last 7 days)
 */
function getTrendingNFTs(uint256 _limit) external view returns (
    uint256[] memory tokenIds,
    uint256[] memory likesCounts
)

/**
 * @dev Get marketplace health metrics
 */
function getMarketplaceHealth() external view returns (
    uint256 activeListingsCount,
    uint256 activeOffersCount,
    uint256 averagePrice,
    uint256 last24hSales,
    uint256 last24hVolume
)
```

---

## 2. GameifiedMarketplaceSkillsV2.sol

### Funciones View Existentes ✅
```solidity
// Skill NFT Data
function isSkillExpired(uint256 _tokenId) external view returns (bool)
function getSkillExpiryTime(uint256 _tokenId) external view returns (uint256)
function getSkillNFTSkills(uint256 _tokenId) external view returns (Skill[] memory)
function getSkillNFT(uint256 _tokenId) external view returns (SkillNFT memory)

// User Data
function getUserSkillNFTs(address _user) external view returns (uint256[] memory)
function getActiveSkillsForUser(address _user) external view returns (uint256[] memory)
function getUserTotalActiveSkills(address _user) external view returns (uint256)
function getUserSkillNFTsWithDetails(address _user) external view returns (...)

// Market Data
function getAllSkillNFTs() external view returns (uint256[] memory)
function getSkillTypeCount(IStakingIntegration.SkillType _skillType) external view returns (uint256)

// Pricing
function getSkillPrice(SkillType, Rarity) external view returns (uint256)
function getSkillPricesAllRarities(SkillType) external view returns (uint256[5] memory)
```

### Funciones Propuestas para Dashboard 📊

```solidity
/**
 * @dev Get skill marketplace statistics
 */
function getSkillMarketStats() external view returns (
    uint256 totalSkillNFTs,
    uint256 totalActiveSkills,
    uint256 totalExpiredSkills,
    uint256 totalSkillsSold,
    uint256 totalRevenue,
    uint256 averageSkillsPerNFT
)

/**
 * @dev Get user skill portfolio summary
 */
function getUserSkillPortfolio(address _user) external view returns (
    uint256 totalSkillNFTs,
    uint256 activeSkillNFTs,
    uint256 expiredSkillNFTs,
    uint256 totalActiveSkills,
    uint256 stakingSkillsCount,
    uint256 platformSkillsCount,
    uint256 expiringIn24h,
    uint256 totalSpentOnSkills
)

/**
 * @dev Get skills expiring soon for a user
 * @param _user User address
 * @param _hoursThreshold Hours until expiry (e.g., 24 for next day)
 */
function getExpiringSkills(address _user, uint256 _hoursThreshold) 
    external view returns (
        uint256[] memory tokenIds,
        uint256[] memory expiryTimes,
        Skill[][] memory skills
    )

/**
 * @dev Get popular skills by purchase count
 */
function getPopularSkills(uint256 _limit) external view returns (
    IStakingIntegration.SkillType[] memory skillTypes,
    uint256[] memory purchaseCounts,
    IStakingIntegration.Rarity[] memory mostBoughtRarity
)

/**
 * @dev Get skill breakdown by rarity
 */
function getSkillRarityDistribution() external view returns (
    uint256 commonCount,
    uint256 uncommonCount,
    uint256 rareCount,
    uint256 epicCount,
    uint256 legendaryCount
)

/**
 * @dev Get all user skills grouped by type and rarity
 */
function getUserSkillsGrouped(address _user) external view returns (
    IStakingIntegration.SkillType[] memory skillTypes,
    IStakingIntegration.Rarity[] memory rarities,
    uint256[] memory counts
)
```

---

## 3. IndividualSkillsMarketplace.sol

### Funciones View Existentes ✅
```solidity
// Skill Data
function getIndividualSkill(uint256 _skillId) external view returns (IndividualSkill memory)
function getUserIndividualSkills(address _user) external view returns (uint256[] memory)
function getUserActiveIndividualSkills(address _user) external view returns (uint256[] memory)
function getUserIndividualSkillsDetailed(address _user) external view returns (...)
function getActiveIndividualSkills(address _user) external view returns (uint256[] memory)

// User Stats (✅ Already comprehensive!)
function getUserSkillStats(address _user) external view returns (...)
function getUserSkillsByCategory(address _user) external view returns (...)
function getUserStakingSkills(address _user) external view returns (...)
function getUserPlatformSkills(address _user) external view returns (...)
function getUserSkillsComprehensive(address _user) external view returns (...)

// Pricing
function getIndividualSkillPrice(Rarity) external view returns (uint256)
function getSkillPrice(SkillType, Rarity) external view returns (uint256)
function getSkillPricesAllRarities(SkillType) external view returns (uint256[5] memory)
function getAllSkillsPricing() external view returns (...)
function getCurrentBasePrices() external view returns (uint256[5] memory)
```

### Funciones Propuestas para Dashboard 📊

```solidity
/**
 * @dev Get individual skills marketplace statistics
 */
function getIndividualSkillsMarketStats() external view returns (
    uint256 totalSkillsSold,
    uint256 totalActiveSkills,
    uint256 totalRevenue,
    uint256 averagePricePerSkill,
    uint256 uniqueBuyers
)

/**
 * @dev Get skill revenue breakdown by type
 */
function getSkillRevenueByType() external view returns (
    IStakingIntegration.SkillType[] memory skillTypes,
    uint256[] memory revenue,
    uint256[] memory salesCount
)

/**
 * @dev Get skill revenue breakdown by rarity
 */
function getSkillRevenueByRarity() external view returns (
    IStakingIntegration.Rarity[] memory rarities,
    uint256[] memory revenue,
    uint256[] memory salesCount
)

/**
 * @dev Get user's total spending on skills
 */
function getUserSkillSpending(address _user) external view returns (
    uint256 totalSpent,
    uint256 skillsPurchased,
    uint256 averageSpentPerSkill,
    IStakingIntegration.SkillType mostPurchasedType
)

/**
 * @dev Get skill adoption rate (percentage of users with each skill)
 */
function getSkillAdoptionRates() external view returns (
    IStakingIntegration.SkillType[] memory skillTypes,
    uint256[] memory userCounts,
    uint256[] memory percentages
)
```

---

## 4. GameifiedMarketplaceQuests.sol

### Funciones View Existentes ✅
```solidity
function getUserCompletedQuests(address _user) external view returns (uint256[] memory)
function getQuest(uint256 _questId) external view returns (Quest memory)
function getUserSocialActions(address _user) external view returns (uint256)
function getAllActiveQuests() external view returns (Quest[] memory)
function getQuestsByType(QuestType _questType) external view returns (Quest[] memory)
function getUserQuestProgress(address _user, uint256 _questId) external view returns (...)
function getUserQuestProgressByType(address _user, QuestType _questType) external view returns (...)
```

### Funciones Propuestas para Dashboard 📊

```solidity
/**
 * @dev Get quest system statistics
 */
function getQuestSystemStats() external view returns (
    uint256 totalQuests,
    uint256 activeQuests,
    uint256 totalCompletions,
    uint256 totalXPAwarded,
    uint256 averageCompletionRate
)

/**
 * @dev Get user quest statistics
 */
function getUserQuestStats(address _user) external view returns (
    uint256 totalCompleted,
    uint256 totalInProgress,
    uint256 totalXPEarned,
    uint256 completionRate,
    QuestType favoriteType
)

/**
 * @dev Get most popular quests
 */
function getMostPopularQuests(uint256 _limit) external view returns (
    uint256[] memory questIds,
    uint256[] memory completionCounts,
    string[] memory titles
)

/**
 * @dev Get user's incomplete quests with progress
 */
function getUserIncompleteQuests(address _user) external view returns (
    uint256[] memory questIds,
    Quest[] memory quests,
    uint256[] memory progressPercentages
)

/**
 * @dev Get quest leaderboard
 */
function getQuestLeaderboard(uint256 _limit) external view returns (
    address[] memory users,
    uint256[] memory completedCounts,
    uint256[] memory totalXP
)
```

---

## 5. LevelingSystem.sol

### Funciones View Existentes ✅
```solidity
function getUserProfile(address user) external view returns (UserProfile memory)
function getUserProfileDetailed(address user) external view returns (...)
function getUserBadges(address user) external view returns (Badge[] memory)
function getXPRequiredForLevel(uint8 _level) public pure returns (uint256)
function getLevelFromXP(uint256 _totalXP) public pure returns (uint8)
```

### Funciones Propuestas para Dashboard 📊

```solidity
/**
 * @dev Get leveling system statistics
 */
function getLevelingStats() external view returns (
    uint256 totalUsers,
    uint256 totalXPAwarded,
    uint8 averageLevel,
    uint8 highestLevel,
    uint256 maxLevelUsers
)

/**
 * @dev Get level distribution (how many users at each level)
 */
function getLevelDistribution() external view returns (
    uint8[] memory levels,
    uint256[] memory userCounts
)

/**
 * @dev Get user ranking by XP
 */
function getUserRanking(address _user) external view returns (
    uint256 rank,
    uint256 totalUsers,
    uint256 percentile
)

/**
 * @dev Get XP leaderboard
 */
function getXPLeaderboard(uint256 _limit) external view returns (
    address[] memory users,
    uint256[] memory xpAmounts,
    uint8[] memory levels
)

/**
 * @dev Get badge statistics
 */
function getBadgeStats() external view returns (
    uint256 totalBadgesAwarded,
    uint256 uniqueBadgeTypes,
    uint256[] memory badgeIds,
    uint256[] memory awardCounts
)

/**
 * @dev Get user's XP progress percentage for current level
 */
function getUserLevelProgress(address _user) external view returns (
    uint8 currentLevel,
    uint256 currentLevelXP,
    uint256 xpInCurrentLevel,
    uint256 xpNeededForNext,
    uint256 progressPercentage
)
```

---

## 6. ReferralSystem.sol

### Funciones View Existentes ✅
```solidity
function getReferralCode(address user) external view returns (bytes32)
function isValidReferralCode(bytes32 code) public view returns (bool)
function getUserReferrer(address user) external view returns (address)
function userHasReferrer(address user) external view returns (bool)
function getUserReferralStats(address user) external view returns (...)
```

### Funciones Propuestas para Dashboard 📊

```solidity
/**
 * @dev Get referral system statistics
 */
function getReferralSystemStats() external view returns (
    uint256 totalReferrals,
    uint256 totalUsers,
    uint256 totalXPEarned,
    uint256 averageReferralsPerUser,
    uint256 conversionRate
)

/**
 * @dev Get top referrers leaderboard
 */
function getTopReferrers(uint256 _limit) external view returns (
    address[] memory referrers,
    uint256[] memory referralCounts,
    uint256[] memory xpEarned
)

/**
 * @dev Get user's referral network depth (tree structure)
 */
function getUserReferralNetwork(address _user) external view returns (
    uint256 directReferrals,
    uint256 totalXPFromReferrals,
    address[] memory referralAddresses,
    bool[] memory activeStatus
)

/**
 * @dev Get referral activity statistics
 */
function getReferralActivity() external view returns (
    uint256 last24hReferrals,
    uint256 last7dReferrals,
    uint256 last30dReferrals,
    uint256 trendPercentage
)

/**
 * @dev Get referral conversion metrics
 */
function getReferralConversionMetrics() external view returns (
    uint256 codesGenerated,
    uint256 codesUsed,
    uint256 conversionRate,
    uint256 averageTimeToConvert
)
```

---

## Summary of Proposed Functions

### Total New Functions: **55 functions**

| Contract | Existing | Proposed | Total |
|----------|----------|----------|-------|
| GameifiedMarketplaceCoreV1 | 7 | 8 | 15 |
| GameifiedMarketplaceSkillsV2 | 13 | 6 | 19 |
| IndividualSkillsMarketplace | 19 | 5 | 24 |
| GameifiedMarketplaceQuests | 7 | 5 | 12 |
| LevelingSystem | 5 | 6 | 11 |
| ReferralSystem | 5 | 5 | 10 |
| **TOTAL** | **56** | **35** | **91** |

---

## Implementation Priority

### High Priority (Core Dashboard) 🔴
1. `getMarketplaceStats()` - GameifiedMarketplaceCoreV1
2. `getUserTradingStats()` - GameifiedMarketplaceCoreV1
3. `getSkillMarketStats()` - GameifiedMarketplaceSkillsV2
4. `getUserSkillPortfolio()` - GameifiedMarketplaceSkillsV2
5. `getUserQuestStats()` - GameifiedMarketplaceQuests
6. `getLevelingStats()` - LevelingSystem
7. `getReferralSystemStats()` - ReferralSystem

### Medium Priority (Analytics) 🟡
8. `getMarketplaceHealth()` - GameifiedMarketplaceCoreV1
9. `getTrendingNFTs()` - GameifiedMarketplaceCoreV1
10. `getExpiringSkills()` - GameifiedMarketplaceSkillsV2
11. `getPopularSkills()` - GameifiedMarketplaceSkillsV2
12. `getMostPopularQuests()` - GameifiedMarketplaceQuests
13. `getXPLeaderboard()` - LevelingSystem
14. `getTopReferrers()` - ReferralSystem

### Low Priority (Advanced Features) 🟢
15. All remaining leaderboard functions
16. All distribution/breakdown functions
17. Network analysis functions

---

## Gas Optimization Notes

Para funciones que recorren arrays grandes:
- Implementar paginación (`offset`, `limit`)
- Usar mappings auxiliares para tracking
- Considerar eventos históricos en lugar de lectura de estado

Para agregaciones costosas:
- Mantener contadores incrementales
- Evitar loops sobre estructuras grandes
- Cachear resultados comunes

---

## Next Steps

1. ✅ Review y aprobación del análisis
2. ⏳ Implementar funciones High Priority
3. ⏳ Testing de las nuevas funciones
4. ⏳ Integración con frontend
5. ⏳ Documentación de API completa
