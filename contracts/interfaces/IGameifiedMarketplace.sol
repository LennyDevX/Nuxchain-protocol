// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IGameifiedMarketplace
 * @dev Interfaz pública del GameifiedMarketplace
 * Usada por el proxy para interactuar con la implementación
 */
interface IGameifiedMarketplace {
    // ============ EVENTS ============
    
    event NFTCreated(uint256 indexed tokenId, address indexed creator, string tokenURI);
    event NFTListed(uint256 indexed tokenId, uint256 price);
    event NFTUnlisted(uint256 indexed tokenId);
    event NFTPriceUpdated(uint256 indexed tokenId, uint256 newPrice);
    event NFTSold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );
    event OfferMade(
        uint256 indexed tokenId,
        address indexed offerer,
        uint256 amount,
        uint256 expirationTime
    );
    event OfferAccepted(
        uint256 indexed tokenId,
        address indexed offerer,
        address indexed seller,
        uint256 amount
    );
    event OfferCancelled(uint256 indexed tokenId, address indexed offerer);
    
    event XPAwarded(address indexed user, uint256 amount, string reason);
    event UserLeveledUp(address indexed user, uint256 newLevel);
    event SkillActivated(uint256 indexed tokenId, uint8 skillType);
    event SkillDeactivated(uint256 indexed tokenId, uint8 skillType);
    event QuestCreated(uint256 indexed questId, string name);
    event QuestCompleted(address indexed user, uint256 indexed questId, uint256 xpReward, uint256 polReward);
    event QuestDeactivated(uint256 indexed questId);
    event QuestReactivated(uint256 indexed questId);
    event StreakMilestone(address indexed user, uint256 streakDays);
    event RewardsWithdrawn(address indexed user, uint256 amount);
    
    // ============ ENUMS ============
    
    enum QuestType {
        CREATE_NFT,
        BUY_NFT,
        SELL_NFT,
        LIKE_NFT,
        COMMENT_NFT,
        ACTIVATE_SKILL,
        REACH_LEVEL,
        STAKE_POL,
        REFERRAL,
        STREAK,
        COMPLETE_QUESTS
    }

    enum QuestFrequency {
        ONE_TIME,
        DAILY,
        WEEKLY,
        MONTHLY,
        SEASONAL
    }

    enum QuestDifficulty {
        EASY,
        MEDIUM,
        HARD,
        EXPERT
    }

    // ============ STRUCTS ============

    struct UserProfile {
        uint256 totalXP;
        uint8 level;
        uint8 maxActiveSkills;
        uint8 skillsLevel;
        uint256 nftsCreated;
        uint256 nftsSold;
        uint256 nftsBought;
        uint256 lastActivityTimestamp;
    }

    struct SkillNFT {
        uint256 tokenId;
        uint8 skillType;
        uint256 effectValue;
        uint8 rarity;
        uint8 stars;
        uint64 mintedAt;
        uint64 lastActivationTime;
        bool isSkillActive;
    }

    struct Quest {
        uint256 id;
        string name;
        string description;
        QuestType questType;
        uint256 targetValue;
        uint256 xpReward;
        uint256 polReward;
        uint256 badgeId;
        QuestFrequency frequency;
        uint64 startTime;
        uint64 endTime;
        QuestDifficulty difficulty;
        string category;
        bool isActive;
        uint8 minLevel;
        uint256 completionCount;
    }

    struct QuestProgress {
        address user;
        uint256 questId;
        uint256 currentProgress;
        uint64 lastProgressUpdate;
        bool isCompleted;
        uint64 completedTime;
    }

    struct UserStreak {
        address user;
        uint256 currentStreak;
        uint256 longestStreak;
        uint64 lastActivityDate;
        uint256 totalQuestsCompleted;
    }

    struct NFTMetadata {
        string category;
        uint256 creationTimestamp;
        address creator;
        bool isListed;
        uint256 listedPrice;
    }

    // ============ PUBLIC FUNCTIONS - NFT CREATION ============

    function createStandardNFT(
        string memory _tokenURI,
        string memory _category,
        uint96 _royaltyPercentage
    ) external returns (uint256);

    function createSkillNFT(
        string memory _tokenURI,
        string memory _category,
        uint96 _royaltyPercentage,
        uint8[] calldata _skills,
        uint256[] calldata _effectValues,
        uint8[] calldata _rarities
    ) external returns (uint256);

    // ============ PUBLIC FUNCTIONS - MARKETPLACE ============

    function listToken(uint256 _tokenId, uint256 _price) external;
    function buyToken(uint256 _tokenId) external payable;
    function unlistToken(uint256 _tokenId) external;
    function updatePrice(uint256 _tokenId, uint256 _newPrice) external;

    // ============ PUBLIC FUNCTIONS - OFFERS ============

    function makeOffer(
        uint256 _tokenId,
        uint256 _offerAmount,
        uint256 _expirationDays
    ) external;

    function acceptOffer(uint256 _tokenId, address _offerer) external;
    function cancelOffer(uint256 _tokenId) external;

    // ============ PUBLIC FUNCTIONS - SKILLS ============

    function activateSkill(uint256 _tokenId) external;
    function deactivateSkill(uint256 _tokenId) external;
    function getActiveSkills(address _user) external view returns (uint256[] memory);
    function getSkillDetails(uint256 _tokenId) external view returns (SkillNFT memory);

    // ============ PUBLIC FUNCTIONS - GAMIFICATION ============

    function toggleLike(uint256 _tokenId) external;
    function addComment(uint256 _tokenId, string memory _comment) external;
    function registerReferral(address _referrer) external;

    // ============ PUBLIC FUNCTIONS - QUESTS ============

    function createQuest(
        string memory _name,
        string memory _description,
        QuestType _questType,
        uint256 _targetValue,
        uint256 _xpReward,
        uint256 _polReward,
        QuestFrequency _frequency,
        QuestDifficulty _difficulty,
        string memory _category,
        uint64 _startTime,
        uint64 _endTime,
        uint8 _minLevel
    ) external returns (uint256);

    function completeQuest(uint256 _questId) external;
    function updateQuestRewards(uint256 _questId, uint256 _xpReward, uint256 _polReward) external;
    function deactivateQuest(uint256 _questId) external;
    function activateQuest(uint256 _questId) external;
    function canCompleteQuestNow(uint256 _questId) external view returns (bool);

    // ============ PUBLIC FUNCTIONS - REWARDS ============

    function withdrawRewards() external;

    // ============ PUBLIC FUNCTIONS - LEADERBOARDS ============

    function getCreatorLeaderboard(uint256 _limit) external view returns (address[] memory, uint256[] memory);
    function getCollectorLeaderboard(uint256 _limit) external view returns (address[] memory, uint256[] memory);

    // ============ VIEW FUNCTIONS ============

    function getUserProfile(address _user) external view returns (UserProfile memory);
    function getUserCompleteInfo(address _user) external view returns (
        UserProfile memory profile,
        uint256[] memory activeSkills,
        UserStreak memory streak
    );
    
    function getNFTMetadata(uint256 _tokenId) external view returns (NFTMetadata memory);
    function getNFTComments(uint256 _tokenId) external view returns (string[] memory);
    function getNFTOffers(uint256 _tokenId) external view returns (address[] memory, uint256[] memory);
    function getQuestProgress(address _user, uint256 _questId) external view returns (QuestProgress memory);

    // ============ ADMIN FUNCTIONS ============

    function setStakingContractAddress(address _stakingContract) external;
    function setCommunityTreasuryAddress(address _treasury) external;
    function setRoyaltyStakingPoolAddress(address _pool) external;
    function setPOLTokenAddress(address _polToken) external;
    function setStakingTreasuryAddress(address _treasury) external;
    function setPlatformTreasuryAddress(address _platformTreasury) external;
    function pause() external;
    function unpause() external;

    // ============ INITIALIZATION ============

    function initialize(
        address _polTokenAddress,
        address _stakingContractAddress,
        address _communityTreasuryAddress,
        address _royaltyStakingPoolAddress,
        address _stakingTreasuryAddress,
        address _platformTreasuryAddress
    ) external;
}
