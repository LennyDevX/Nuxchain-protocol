// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IStakingIntegration.sol";

/**
 * @title XPLibrary
 * @dev Library para cálculos de XP y niveles
 */
library XPLibrary {
    uint8 private constant BASE_MAX_SKILLS = 3;
    
    function calculateLevel(uint256 totalXP) internal pure returns (uint8) {
        if (totalXP >= 3000) return 5;
        if (totalXP >= 1500) return 4;
        if (totalXP >= 700) return 3;
        if (totalXP >= 300) return 2;
        if (totalXP >= 100) return 1;
        return 0;
    }
    
    function calculateMaxSkills(uint8 level) internal pure returns (uint8) {
        return BASE_MAX_SKILLS + (level / 2);
    }
    
    function rarityToStars(IStakingIntegration.Rarity rarity) internal pure returns (uint8) {
        if (rarity == IStakingIntegration.Rarity.LEGENDARY) return 5;
        if (rarity == IStakingIntegration.Rarity.EPIC) return 4;
        if (rarity == IStakingIntegration.Rarity.RARE) return 3;
        if (rarity == IStakingIntegration.Rarity.UNCOMMON) return 2;
        return 1;
    }
}

/**
 * @title GameifiedMarketplace
 * @dev NFT Marketplace con Sistema de Gamificación Integrado
 * @notice Versión 2.0 - Marketplace Base + Gamificación + Staking Integration
 * @dev IMPORTANTE: Este contrato reemplaza completamente a Marketplace.sol
 *      No mantiene herencia para evitar duplicación de código
 */
contract GameifiedMarketplace is
    ERC721,
    ERC721URIStorage,
    ERC721Royalty,
    AccessControl,
    ReentrancyGuard,
    Pausable
{
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    using XPLibrary for uint256;
    using Address for address payable;

    // ════════════════════════════════════════════════════════════════════════════════════════
    // MARKETPLACE BASE STATE
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _questIdCounter;
    Counters.Counter private _achievementIdCounter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 5; // 5% fee
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // POL STAKING CONFIGURATION
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    uint256 public constant MIN_POL_FOR_SKILL_NFT = 200 * 10**18; // 200 POL tokens (assuming 18 decimals)
    uint256 public constant FIRST_SKILL_FREE = 1; // First skill is free
    uint256 public constant ADDITIONAL_SKILL_MIN_FEE = 25 * 10**18; // 25 POL
    uint256 public constant ADDITIONAL_SKILL_MAX_FEE = 100 * 10**18; // 100 POL
    uint256 public constant SKILL_CHANGE_COOLDOWN = 7 days;
    uint256 public constant SKILL_CHANGE_FEE = 10 * 10**18; // 10 POL to change before cooldown
    uint256 public constant STAKING_REWARD_COMMISSION_PERCENTAGE = 200; // 2% (in basis points)
    
    // Skills Level System (1-5)
    // Level 1: 1 skill active
    // Level 2: 2 skills active
    // Level 3: 3 skills active
    // Level 4: 4 skills active
    // Level 5: 5 skills active
    uint8 public constant MAX_SKILLS_LEVEL_1 = 1;
    uint8 public constant MAX_SKILLS_LEVEL_2 = 2;
    uint8 public constant MAX_SKILLS_LEVEL_3 = 3;
    uint8 public constant MAX_SKILLS_LEVEL_4 = 4;
    uint8 public constant MAX_SKILLS_LEVEL_5 = 5;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MARKETPLACE STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    struct NFTMetadata {
        string category;
        uint256 creationTimestamp;
        address creator;
        bool isListed;
        uint256 listedPrice;
    }
    
    struct Offer {
        uint256 nftId;
        address offeror;
        uint256 offerAmount;
        uint64 expiresAt;
        bool isActive;
    }
    
    struct SkillNFT {
        uint256 tokenId;
        IStakingIntegration.SkillType skillType;
        uint16 effectValue;
        IStakingIntegration.Rarity rarity;
        uint8 stars;
        uint64 mintedAt;
        uint64 lastActivationTime;
        bool isSkillActive;
    }
    
    struct UserProfile {
        uint256 totalXP;
        uint8 level;
        uint8 maxActiveSkills;
        uint8 skillsLevel;
        uint32 nftsCreated;
        uint32 nftsSold;
        uint32 nftsBought;
        uint64 lastActivityTimestamp;
    }
    
    struct SkillFeeConfig {
        IStakingIntegration.SkillType skillType;
        uint256 minFee;
        uint256 maxFee;
        uint16 boostPercentage;
    }
    
    struct Achievement {
        uint256 id;
        string name;
        string description;
        uint256 xpReward;
        bool isActive;
    }
    
    struct Quest {
        uint256 id;
        string name;
        uint256 xpReward;
        uint64 startTime;
        uint64 endTime;
        bool isActive;
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MARKETPLACE MAPPINGS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    // Marketplace mappings
    mapping(uint256 => NFTMetadata) public nftMetadata;
    mapping(uint256 => mapping(address => bool)) public nftLikes;
    mapping(uint256 => uint256) public nftLikeCount;
    mapping(uint256 => string[]) public nftComments;
    mapping(uint256 => Offer[]) public nftOffers;
    mapping(address => uint256) public userBalance;
    
    // Gamification mappings
    mapping(uint256 => SkillNFT) public tokenSkills;
    mapping(address => UserProfile) public userProfiles;
    mapping(address => EnumerableSet.UintSet) private _userActiveSkills;
    mapping(uint256 => Achievement) public achievements;
    mapping(address => mapping(uint256 => bool)) public userAchievements;
    mapping(uint256 => Quest) public quests;
    mapping(address => mapping(uint256 => bool)) public userQuestCompleted;
    mapping(address => address[]) public referrals;
    
    // POL Staking & Skills Integration
    address public polTokenAddress;
    address public stakingContractAddress;
    mapping(address => uint256) public userSkillNFTCount; // Total skill NFTs per user
    mapping(address => uint256) public userSkillsActivatedCount; // Number of skills user has activated for free
    mapping(uint256 => uint256) public skillNFTSkillCount; // How many skills are in each NFT
    mapping(uint256 => uint256) public lastSkillActivationTime; // Track last activation time per NFT
    mapping(address => SkillFeeConfig[]) public skillFeeConfigs; // Fee configurations per skill type
    
    // Treasury
    address public platformTreasury;
    address public stakingTreasuryAddress;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // XP CONFIGURATION
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    uint256 public constant XP_CREATE_NFT = 10;
    uint256 public constant XP_SELL_NFT = 20;
    uint256 public constant XP_BUY_NFT = 15;
    uint256 public constant XP_LIKE = 1;
    uint256 public constant XP_COMMENT = 2;
    uint256 public constant XP_REFERRAL = 50;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    // Marketplace events
    event TokenCreated(address indexed creator, uint256 indexed tokenId, string uri);
    event TokenListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event TokenUnlisted(address indexed seller, uint256 indexed tokenId);
    event TokenSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event OfferMade(address indexed offeror, uint256 indexed tokenId, uint256 amount);
    event OfferAccepted(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 amount);
    event LikeToggled(address indexed user, uint256 indexed tokenId, bool liked);
    event CommentAdded(address indexed user, uint256 indexed tokenId, string comment);
    event PriceUpdated(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
    
    // Gamification events
    event SkillNFTCreated(uint256 indexed tokenId, address indexed creator, IStakingIntegration.SkillType skillType);
    event SkillActivated(address indexed user, uint256 indexed tokenId);
    event SkillDeactivated(address indexed user, uint256 indexed tokenId);
    event XPGained(address indexed user, uint256 amount, string reason);
    event LevelUp(address indexed user, uint8 newLevel);
    event AchievementUnlocked(address indexed user, uint256 indexed achievementId);
    event QuestCompleted(address indexed user, uint256 indexed questId);
    event ReferralRegistered(address indexed referrer, address indexed referred);
    
    // POL Fee Events
    event SkillFeeCharged(address indexed user, uint256 indexed tokenId, uint256 feeAmount, string reason);
    event SkillAdded(address indexed user, uint256 indexed tokenId, IStakingIntegration.SkillType skillType, uint256 fee);
    event SkillActivationCooldownFeeCharged(address indexed user, uint256 indexed tokenId, uint256 feeAmount);
    event RewardsCommissionCharged(address indexed user, uint256 rewardsAmount, uint256 commissionAmount);
    event MinimumStakingRequirementNotMet(address indexed user, uint256 userBalance, uint256 requiredBalance);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    error MaxSkillsReached();
    error SkillAlreadyActive();
    error InvalidSkillType();
    error TokenNotFound();
    error NotTokenOwner();
    error TokenNotListed();
    error InsufficientPayment();
    error NoOffersAvailable();
    error InsufficientStakingBalance();
    error SkillCooldownNotMet();
    error InsufficientPOLForFee();
    error InvalidSkillConfiguration();
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Constructor initializes GameifiedMarketplace with POL token and staking integration
     * @param _polTokenAddress Address of the POL token contract
     * @param _stakingContractAddress Address of EnhancedSmartStaking contract
     * @param _stakingTreasuryAddress Address of staking treasury for commissions
     */
    constructor(
        address _polTokenAddress,
        address _stakingContractAddress,
        address _stakingTreasuryAddress
    ) ERC721("GameifiedNFT", "GNFT") {
        require(_polTokenAddress != address(0), "Invalid POL token address");
        require(_stakingContractAddress != address(0), "Invalid staking contract");
        require(_stakingTreasuryAddress != address(0), "Invalid staking treasury");
        
        // Setup admin roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        
        // Initialize marketplace
        platformTreasury = msg.sender;
        polTokenAddress = _polTokenAddress;
        stakingContractAddress = _stakingContractAddress;
        stakingTreasuryAddress = _stakingTreasuryAddress;
        
        // Initialize first user skill level to 1 (for new users)
        // This ensures default skill activation level is set
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MARKETPLACE CORE FUNCTIONS (BASE) - ONLY SKILL NFTs
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Verifica el balance de POL en staking del usuario
     * @param _user Dirección del usuario
     * @return balanceInStaking Balance total bloqueado en staking
     */
    function _getStakingBalance(address _user) internal view returns (uint256) {
        // Interface call to staking contract to get locked balance
        // This assumes EnhancedSmartStaking has a getTotalDeposit function
        (bool success, bytes memory data) = stakingContractAddress.staticcall(
            abi.encodeWithSignature("getTotalDeposit(address)", _user)
        );
        
        if (success && data.length > 0) {
            return abi.decode(data, (uint256));
        }
        return 0;
    }
    
    /**
     * @dev Calcula el fee para agregar habilidades adicionales basado en el tipo y poder
     * @param _rarity Raridad del skill
     * @return fee Cantidad de POL a cobrar
     */
    function _calculateSkillFee(
        IStakingIntegration.SkillType,
        IStakingIntegration.Rarity _rarity
    ) internal pure returns (uint256) {
        uint8 stars = _rarityToStarsStatic(_rarity);
        // Base fee depends on rarity (stars)
        // COMMON (1 star) = 25 POL, UNCOMMON (2 stars) = 40 POL, RARE (3 stars) = 60 POL
        // EPIC (4 stars) = 80 POL, LEGENDARY (5 stars) = 100 POL
        
        if (stars == 1) return 25 * 10**18;
        if (stars == 2) return 40 * 10**18;
        if (stars == 3) return 60 * 10**18;
        if (stars == 4) return 80 * 10**18;
        if (stars == 5) return 100 * 10**18;
        
        return 25 * 10**18; // Default
    }
    
    /**
     * @dev Helper static function para calcular stars (usado en pure functions)
     */
    function _rarityToStarsStatic(IStakingIntegration.Rarity _rarity) internal pure returns (uint8) {
        if (_rarity == IStakingIntegration.Rarity.LEGENDARY) return 5;
        if (_rarity == IStakingIntegration.Rarity.EPIC) return 4;
        if (_rarity == IStakingIntegration.Rarity.RARE) return 3;
        if (_rarity == IStakingIntegration.Rarity.UNCOMMON) return 2;
        return 1;
    }
    
    /**
     * @dev Crea un NFT con skill embebido - VERSIÓN V3 CON MONETIZACIÓN POL
     * Solo usuarios con mínimo 200 POL en staking pueden crear skills NFTs
     * Primer skill es gratis, skills adicionales requieren fee en POL
     * 
     * @param _tokenURI URI del NFT
     * @param category Categoría del NFT
     * @param royaltyPercentage Royalty para el creator
     * @param _skills Array de tipos de skills a agregar
     * @param _effectValues Array de valores de efectos para cada skill
     * @param _rarities Array de raridades para cada skill
     */
    function createSkillNFT(
        string calldata _tokenURI,
        string calldata category,
        uint96 royaltyPercentage,
        IStakingIntegration.SkillType[] calldata _skills,
        uint16[] calldata _effectValues,
        IStakingIntegration.Rarity[] calldata _rarities
    )
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        // Validate inputs
        require(_skills.length > 0, "Must have at least 1 skill");
        require(_skills.length <= 5, "Max 5 skills per NFT");
        require(_skills.length == _effectValues.length, "Skills and effects length mismatch");
        require(_skills.length == _rarities.length, "Skills and rarities length mismatch");
        require(royaltyPercentage <= 10000, "Invalid royalty");
        
        // CHECK: User must have min 200 POL in staking
        uint256 stakingBalance = _getStakingBalance(msg.sender);
        if (stakingBalance < MIN_POL_FOR_SKILL_NFT) {
            emit MinimumStakingRequirementNotMet(msg.sender, stakingBalance, MIN_POL_FOR_SKILL_NFT);
            revert InsufficientStakingBalance();
        }
        
        // Calculate total fees (first skill free, rest charged)
        uint256 totalFee = 0;
        for (uint i = 1; i < _skills.length; i++) {
            require(_skills[i] != IStakingIntegration.SkillType.NONE, "Invalid skill type");
            totalFee += _calculateSkillFee(_skills[i], _rarities[i]);
        }
        
        // Transfer POL fees to treasury if needed
        if (totalFee > 0) {
            IERC20 polToken = IERC20(polTokenAddress);
            require(polToken.balanceOf(msg.sender) >= totalFee, "Insufficient POL for skills fee");
            require(
                polToken.transferFrom(msg.sender, platformTreasury, totalFee),
                "POL transfer failed"
            );
        }
        
        // Mint the NFT
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        
        if (royaltyPercentage > 0) {
            _setTokenRoyalty(tokenId, msg.sender, royaltyPercentage);
        }
        
        nftMetadata[tokenId] = NFTMetadata({
            category: category,
            creationTimestamp: block.timestamp,
            creator: msg.sender,
            isListed: false,
            listedPrice: 0
        });
        
        // Add skills to NFT
        uint8 skillsAdded = 0;
        for (uint i = 0; i < _skills.length; i++) {
            require(_skills[i] != IStakingIntegration.SkillType.NONE, "Invalid skill");
            
            tokenSkills[tokenId] = SkillNFT({
                tokenId: tokenId,
                skillType: _skills[i],
                effectValue: _effectValues[i],
                rarity: _rarities[i],
                stars: _rarityToStars(_rarities[i]),
                mintedAt: uint64(block.timestamp),
                lastActivationTime: 0,
                isSkillActive: false
            });
            
            skillsAdded++;
            
            if (i == 0) {
                // First skill is free
                emit SkillAdded(msg.sender, tokenId, _skills[i], 0);
            } else {
                // Additional skills charged
                uint256 fee = _calculateSkillFee(_skills[i], _rarities[i]);
                emit SkillAdded(msg.sender, tokenId, _skills[i], fee);
            }
        }
        
        skillNFTSkillCount[tokenId] = skillsAdded;
        userSkillNFTCount[msg.sender]++;
        
        // Award XP
        _awardXP(msg.sender, XP_CREATE_NFT, "Skill NFT Created");
        
        UserProfile storage profile = userProfiles[msg.sender];
        profile.nftsCreated += 1;
        
        emit TokenCreated(msg.sender, tokenId, _tokenURI);
        emit SkillNFTCreated(tokenId, msg.sender, _skills[0]);
        
        return tokenId;
    }
    
    /**
     * @dev Lista un NFT para venta
     */
    function listTokenForSale(
        uint256 _tokenId,
        uint256 _price,
        string calldata category
    ) external whenNotPaused {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(_price > 0, "Price must be > 0");
        
        nftMetadata[_tokenId].isListed = true;
        nftMetadata[_tokenId].listedPrice = _price;
        nftMetadata[_tokenId].category = category;
        
        emit TokenListed(msg.sender, _tokenId, _price);
    }
    
    /**
     * @dev Deslistar un NFT
     */
    function unlistToken(uint256 _tokenId) external whenNotPaused {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(nftMetadata[_tokenId].isListed, "Not listed");
        
        nftMetadata[_tokenId].isListed = false;
        nftMetadata[_tokenId].listedPrice = 0;
        
        emit TokenUnlisted(msg.sender, _tokenId);
    }
    
    /**
     * @dev Actualiza precio de un NFT listado
     */
    function updatePrice(uint256 _tokenId, uint256 _newPrice) external whenNotPaused {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(nftMetadata[_tokenId].isListed, "Not listed");
        require(_newPrice > 0, "Price must be > 0");
        
        nftMetadata[_tokenId].listedPrice = _newPrice;
        
        emit PriceUpdated(msg.sender, _tokenId, _newPrice);
    }
    
    /**
     * @dev Compra un NFT listado
     */
    function buyToken(uint256 _tokenId) public payable whenNotPaused nonReentrant {
        NFTMetadata storage metadata = nftMetadata[_tokenId];
        
        require(metadata.isListed, "Not listed");
        require(msg.value >= metadata.listedPrice, "Insufficient payment");
        
        address seller = ownerOf(_tokenId);
        require(seller != msg.sender, "Cannot buy own");
        
        uint256 price = metadata.listedPrice;
        uint256 platformFee = (price * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 sellerAmount = price - platformFee;
        
        // Transfer token
        _transfer(seller, msg.sender, _tokenId);
        
        // Update metadata
        metadata.isListed = false;
        metadata.listedPrice = 0;
        
        // Send funds
        payable(platformTreasury).sendValue(platformFee);
        payable(seller).sendValue(sellerAmount);
        
        // Refund excess
        if (msg.value > price) {
            payable(msg.sender).sendValue(msg.value - price);
        }
        
        // Award XP
        _awardXP(seller, XP_SELL_NFT, "NFT Sold");
        _awardXP(msg.sender, XP_BUY_NFT, "NFT Bought");
        
        UserProfile storage buyerProfile = userProfiles[msg.sender];
        buyerProfile.nftsBought += 1;
        
        UserProfile storage sellerProfile = userProfiles[seller];
        sellerProfile.nftsSold += 1;
        
        emit TokenSold(seller, msg.sender, _tokenId, price);
    }
    
    /**
     * @dev Compra mejorada con XP tracking
     */
    function buyTokenEnhanced(uint256 _tokenId) external payable {
        buyToken(_tokenId);
    }
    
    /**
     * @dev Hace una oferta para un NFT
     */
    function makeOffer(
        uint256 _tokenId,
        uint8 _expiresInDays
    ) external payable whenNotPaused {
        require(msg.value > 0, "Offer must be > 0");
        require(_expiresInDays > 0 && _expiresInDays <= 30, "Invalid expiry");
        require(ownerOf(_tokenId) != msg.sender, "Cannot offer own");
        
        uint64 expiresAt = uint64(block.timestamp + (_expiresInDays * 1 days));
        
        nftOffers[_tokenId].push(Offer({
            nftId: _tokenId,
            offeror: msg.sender,
            offerAmount: msg.value,
            expiresAt: expiresAt,
            isActive: true
        }));
        
        emit OfferMade(msg.sender, _tokenId, msg.value);
    }
    
    /**
     * @dev Acepta una oferta
     */
    function acceptOffer(uint256 _tokenId, uint256 _offerIndex) external nonReentrant {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(_offerIndex < nftOffers[_tokenId].length, "Invalid offer");
        
        Offer storage offer = nftOffers[_tokenId][_offerIndex];
        require(offer.isActive, "Offer not active");
        require(block.timestamp <= offer.expiresAt, "Offer expired");
        
        address buyer = offer.offeror;
        uint256 amount = offer.offerAmount;
        
        offer.isActive = false;
        
        uint256 platformFee = (amount * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 sellerAmount = amount - platformFee;
        
        _transfer(msg.sender, buyer, _tokenId);
        
        nftMetadata[_tokenId].isListed = false;
        nftMetadata[_tokenId].listedPrice = 0;
        
        payable(platformTreasury).sendValue(platformFee);
        payable(msg.sender).sendValue(sellerAmount);
        
        _awardXP(msg.sender, XP_SELL_NFT, "NFT Sold");
        _awardXP(buyer, XP_BUY_NFT, "NFT Bought");
        
        UserProfile storage buyerProfile = userProfiles[buyer];
        buyerProfile.nftsBought += 1;
        
        UserProfile storage sellerProfile = userProfiles[msg.sender];
        sellerProfile.nftsSold += 1;
        
        emit OfferAccepted(msg.sender, buyer, _tokenId, amount);
    }
    
    /**
     * @dev Cancela una oferta
     */
    function cancelOffer(uint256 _tokenId, uint256 _offerIndex) external nonReentrant {
        require(_offerIndex < nftOffers[_tokenId].length, "Invalid offer");
        
        Offer storage offer = nftOffers[_tokenId][_offerIndex];
        require(offer.offeror == msg.sender, "Not offeror");
        require(offer.isActive, "Offer not active");
        
        offer.isActive = false;
        
        payable(msg.sender).sendValue(offer.offerAmount);
    }
    
    /**
     * @dev Da like a un NFT (con XP)
     */
    function _likeNFT(uint256 _tokenId) internal {
        require(_exists(_tokenId), "Token not found");
        
        bool liked = nftLikes[_tokenId][msg.sender];
        
        if (!liked) {
            nftLikes[_tokenId][msg.sender] = true;
            nftLikeCount[_tokenId]++;
            _awardXP(msg.sender, XP_LIKE, "NFT Liked");
            emit LikeToggled(msg.sender, _tokenId, true);
        } else {
            nftLikes[_tokenId][msg.sender] = false;
            if (nftLikeCount[_tokenId] > 0) {
                nftLikeCount[_tokenId]--;
            }
            emit LikeToggled(msg.sender, _tokenId, false);
        }
    }
    
    /**
     * @dev Comenta en un NFT (con XP)
     */
    function _commentNFT(uint256 _tokenId, string calldata _comment) internal {
        require(_exists(_tokenId), "Token not found");
        require(bytes(_comment).length > 0, "Comment empty");
        
        nftComments[_tokenId].push(_comment);
        _awardXP(msg.sender, XP_COMMENT, "NFT Commented");
        
        emit CommentAdded(msg.sender, _tokenId, _comment);
    }
    
    /**
     * @dev Toggle like (compatible con versión anterior)
     */
    function toggleLike(uint256 _tokenId) external whenNotPaused {
        _likeNFT(_tokenId);
    }
    
    /**
     * @dev Agregar comentario (compatible)
     */
    function addComment(uint256 _tokenId, string calldata _text) external whenNotPaused {
        _commentNFT(_tokenId, _text);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // GAMIFICATION FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Calcula el máximo número de skills activos según el nivel de skills del usuario
     * @param _skillLevel Nivel de skills (1-5)
     * @return maxSkills Número máximo de skills activos permitidos
     */
    function _getMaxSkillsByLevel(uint8 _skillLevel) internal pure returns (uint8) {
        if (_skillLevel >= 5) return MAX_SKILLS_LEVEL_5;
        if (_skillLevel >= 4) return MAX_SKILLS_LEVEL_4;
        if (_skillLevel >= 3) return MAX_SKILLS_LEVEL_3;
        if (_skillLevel >= 2) return MAX_SKILLS_LEVEL_2;
        if (_skillLevel >= 1) return MAX_SKILLS_LEVEL_1;
        return 0;
    }
    
    /**
     * @dev Calcula el nivel de skills basado en el XP del usuario
     * Nivel 1: 100 XP, Nivel 2: 300 XP, Nivel 3: 700 XP, Nivel 4: 1500 XP, Nivel 5: 3000 XP
     * @param _totalXP XP total del usuario
     * @return skillLevel Nivel de skills (0-5)
     */
    function _calculateSkillLevel(uint256 _totalXP) internal pure returns (uint8) {
        if (_totalXP >= 3000) return 5;
        if (_totalXP >= 1500) return 4;
        if (_totalXP >= 700) return 3;
        if (_totalXP >= 300) return 2;
        if (_totalXP >= 100) return 1;
        return 0;
    }
    
    /**
     * @dev Activa un skill con control de cooldown y comisión
     * 
     * Requiere:
     * - Usuario es propietario del NFT
     * - El NFT tiene un skill
     * - No está ya activo
     * - No se alcanzó el límite de skills activos según nivel
     * - Si intenta cambiar antes de 7 días, debe pagar fee en POL
     */
    function activateSkill(uint256 _tokenId) external whenNotPaused nonReentrant {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        
        SkillNFT storage skillNFT = tokenSkills[_tokenId];
        require(skillNFT.skillType != IStakingIntegration.SkillType.NONE, "Not a skill NFT");
        require(!skillNFT.isSkillActive, "Already active");
        
        UserProfile storage profile = userProfiles[msg.sender];
        
        // Initialize skill level if not set
        if (profile.skillsLevel == 0) {
            profile.skillsLevel = _calculateSkillLevel(profile.totalXP);
        }
        
        // Get max skills for current level
        uint8 maxSkillsForLevel = _getMaxSkillsByLevel(profile.skillsLevel);
        require(_userActiveSkills[msg.sender].length() < maxSkillsForLevel, "Max skills reached for your level");
        
        // Check cooldown: if last activation was less than 7 days ago and user has other active skills
        if (lastSkillActivationTime[_tokenId] > 0) {
            uint256 timeSinceLastActivation = block.timestamp - skillNFT.lastActivationTime;
            
            if (timeSinceLastActivation < SKILL_CHANGE_COOLDOWN) {
                // Must pay fee to change before cooldown expires
                IERC20 polToken = IERC20(polTokenAddress);
                require(
                    polToken.balanceOf(msg.sender) >= SKILL_CHANGE_FEE,
                    "Insufficient POL for skill change fee"
                );
                require(
                    polToken.transferFrom(msg.sender, platformTreasury, SKILL_CHANGE_FEE),
                    "POL transfer failed"
                );
                
                emit SkillActivationCooldownFeeCharged(msg.sender, _tokenId, SKILL_CHANGE_FEE);
            }
        }
        
        // Activate skill
        skillNFT.isSkillActive = true;
        skillNFT.lastActivationTime = uint64(block.timestamp);
        _userActiveSkills[msg.sender].add(_tokenId);
        lastSkillActivationTime[_tokenId] = block.timestamp;
        
        emit SkillActivated(msg.sender, _tokenId);
    }
    
    /**
     * @dev Desactiva un skill
     */
    function deactivateSkill(uint256 _tokenId) external {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        
        SkillNFT storage skillNFT = tokenSkills[_tokenId];
        require(skillNFT.isSkillActive, "Not active");
        
        skillNFT.isSkillActive = false;
        _userActiveSkills[msg.sender].remove(_tokenId);
        
        emit SkillDeactivated(msg.sender, _tokenId);
    }
    
    /**
     * @dev Notifica al marketplace sobre comisión de rewards del staking
     * Llamado por EnhancedSmartStaking cuando el usuario reclama recompensas
     * Aplica 2% de comisión adicional
     * 
     * @param _user Usuario que reclama recompensas
     * @param _rewardAmount Cantidad de recompensas
     * @return commission Cantidad de comisión cobrada
     */
    function notifyRewardsClaimed(address _user, uint256 _rewardAmount) external returns (uint256) {
        require(msg.sender == stakingContractAddress, "Only staking contract");
        
        // Check if user has active skills
        uint256 activeSkillsCount = _userActiveSkills[_user].length();
        
        if (activeSkillsCount > 0) {
            // Charge 2% commission
            uint256 commission = (_rewardAmount * STAKING_REWARD_COMMISSION_PERCENTAGE) / 10000;
            
            // Transfer commission to staking treasury
            IERC20 polToken = IERC20(polTokenAddress);
            if (polToken.balanceOf(_user) >= commission) {
                polToken.transferFrom(_user, stakingTreasuryAddress, commission);
            }
            
            emit RewardsCommissionCharged(_user, _rewardAmount, commission);
            return commission;
        }
        
        return 0;
    }
    
    /**
     * @dev Registra un referral
     */
    function registerReferral(address _referrer) external {
        require(_referrer != msg.sender, "Cannot refer yourself");
        require(_referrer != address(0), "Invalid referrer");
        
        referrals[_referrer].push(msg.sender);
        _awardXP(_referrer, XP_REFERRAL, "Referral Registered");
        
        emit ReferralRegistered(_referrer, msg.sender);
    }
    
    /**
     * @dev Verifica completitud de quest
     */
    function checkQuestCompletion(uint256 _questId) external {
        Quest storage quest = quests[_questId];
        require(quest.isActive, "Quest not active");
        require(!userQuestCompleted[msg.sender][_questId], "Already completed");
        require(block.timestamp >= quest.startTime, "Quest not started");
        require(block.timestamp <= quest.endTime, "Quest expired");
        
        userQuestCompleted[msg.sender][_questId] = true;
        _awardXP(msg.sender, quest.xpReward, "Quest Completed");
        
        emit QuestCompleted(msg.sender, _questId);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // XP & LEVELING
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Otorga XP a un usuario y actualiza nivel y skills level
     */
    function _awardXP(address _user, uint256 _amount, string memory _reason) internal {
        UserProfile storage profile = userProfiles[_user];
        
        // Initialize if first time
        if (profile.skillsLevel == 0 && profile.totalXP == 0) {
            profile.skillsLevel = 1; // Start at level 1 with 1 max skill
        }
        
        profile.totalXP += _amount;
        profile.lastActivityTimestamp = uint64(block.timestamp);
        
        // Update skill level based on XP
        uint8 newSkillLevel = _calculateSkillLevel(profile.totalXP);
        if (newSkillLevel > profile.skillsLevel) {
            profile.skillsLevel = newSkillLevel;
        }
        
        emit XPGained(_user, _amount, _reason);
    }
    
    function _calculateLevel(uint256 _totalXP) internal pure returns (uint8) {
        return XPLibrary.calculateLevel(_totalXP);
    }
    
    function _calculateMaxSkills(uint8 _level) internal pure returns (uint8) {
        return XPLibrary.calculateMaxSkills(_level);
    }
    
    function _rarityToStars(IStakingIntegration.Rarity _rarity) internal pure returns (uint8) {
        return XPLibrary.rarityToStars(_rarity);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Obtiene skills activos de un usuario
     */
    function getUserActiveSkills(address _user) external view returns (SkillNFT[] memory) {
        uint256 length = _userActiveSkills[_user].length();
        SkillNFT[] memory skills = new SkillNFT[](length);
        
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = _userActiveSkills[_user].at(i);
            skills[i] = tokenSkills[tokenId];
        }
        
        return skills;
    }
    
    /**
     * @dev Obtiene detalles del skill
     */
    function getSkillDetails(uint256 _tokenId) external view returns (SkillNFT memory) {
        return tokenSkills[_tokenId];
    }
    
    /**
     * @dev Obtiene el máximo de skills activos permitidos para un usuario
     * @param _user Dirección del usuario
     * @return maxSkills Número máximo de skills que puede tener activos
     */
    function getMaxActiveSkillsForUser(address _user) external view returns (uint8) {
        UserProfile memory profile = userProfiles[_user];
        return _getMaxSkillsByLevel(profile.skillsLevel);
    }
    
    /**
     * @dev Obtiene el nivel de skills actual del usuario
     * @param _user Dirección del usuario
     * @return level Nivel de skills (0-5)
     */
    function getUserSkillsLevel(address _user) external view returns (uint8) {
        UserProfile memory profile = userProfiles[_user];
        return profile.skillsLevel;
    }
    
    /**
     * @dev Verifica si un usuario puede crear Skill NFTs
     * @param _user Dirección del usuario
     * @return canCreate true si tiene mínimo 200 POL en staking
     */
    function canUserCreateSkillNFT(address _user) external view returns (bool) {
        uint256 stakingBalance = _getStakingBalance(_user);
        return stakingBalance >= MIN_POL_FOR_SKILL_NFT;
    }
    
    /**
     * @dev Obtiene el balance de staking del usuario
     * @param _user Dirección del usuario
     * @return balance Balance total en staking
     */
    function getUserStakingBalance(address _user) external view returns (uint256) {
        return _getStakingBalance(_user);
    }
    
    /**
     * @dev Obtiene información completa del usuario incluyendo skills
     * @param _user Dirección del usuario
     * @return profile Perfil del usuario
     * @return activeSkillsCount Número de skills activos
     * @return skillsLevel Nivel actual de skills
     * @return maxSkills Máximo de skills permitidos
     */
    function getUserCompleteInfo(address _user) external view returns (
        UserProfile memory profile,
        uint256 activeSkillsCount,
        uint8 skillsLevel,
        uint8 maxSkills
    ) {
        profile = userProfiles[_user];
        activeSkillsCount = _userActiveSkills[_user].length();
        skillsLevel = profile.skillsLevel;
        maxSkills = _getMaxSkillsByLevel(skillsLevel);
    }
    
    /**
     * @dev Obtiene el fee requerido para agregar un skill adicional
     * @param _rarity Raridad del skill
     * @return fee Cantidad de POL a cobrar
     */
    function getSkillFeeForRarity(IStakingIntegration.Rarity _rarity) external pure returns (uint256) {
        return _calculateSkillFee(IStakingIntegration.SkillType.NONE, _rarity);
    }
    
    /**
     * @dev Obtiene el perfil de usuario
     */
    function getUserProfile(address _user) external view returns (UserProfile memory) {
        return userProfiles[_user];
    }
    
    /**
     * @dev Obtiene comentarios de un NFT
     */
    function getNFTComments(uint256 _tokenId) external view returns (string[] memory) {
        return nftComments[_tokenId];
    }
    
    /**
     * @dev Obtiene ofertas de un NFT
     */
    function getNFTOffers(uint256 _tokenId) external view returns (Offer[] memory) {
        return nftOffers[_tokenId];
    }
    
    /**
     * @dev Obtiene metadata de un NFT
     */
    function getNFTMetadata(uint256 _tokenId) external view returns (NFTMetadata memory) {
        return nftMetadata[_tokenId];
    }
    
    /**
     * @dev Verifica si un token existe
     */
    function _exists(uint256 _tokenId) internal view override returns (bool) {
        try this.ownerOf(_tokenId) {
            return true;
        } catch {
            return false;
        }
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Configura dirección del contrato de staking
     */
    function setStakingContractAddress(address _stakingAddress) external onlyRole(ADMIN_ROLE) {
        require(_stakingAddress != address(0), "Invalid address");
        stakingContractAddress = _stakingAddress;
    }
    
    /**
     * @dev Configura dirección del token POL
     */
    function setPolTokenAddress(address _polAddress) external onlyRole(ADMIN_ROLE) {
        require(_polAddress != address(0), "Invalid address");
        polTokenAddress = _polAddress;
    }
    
    /**
     * @dev Configura dirección de tesorería del staking
     */
    function setStakingTreasuryAddress(address _stakingTreasuryAddress) external onlyRole(ADMIN_ROLE) {
        require(_stakingTreasuryAddress != address(0), "Invalid address");
        stakingTreasuryAddress = _stakingTreasuryAddress;
    }
    
    /**
     * @dev Configura treasury
     */
    function setPlatformTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid address");
        platformTreasury = _treasury;
    }
    
    /**
     * @dev Pausar/Reanudar contrato
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ERC721 OVERRIDES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, ERC721Royalty, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage, ERC721Royalty) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}