// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/ITreasuryManager.sol";
import "../interfaces/IMarketplaceStatistics.sol";
import "../interfaces/IMarketplaceView.sol";
import "../interfaces/IMarketplaceSocial.sol";
import { NFTMetadata, Offer, UserProfile, SaleSettlement } from "./MarketplaceCoreTypes.sol";
import { MarketplaceCoreLib } from "./MarketplaceCoreLib.sol";

contract MarketplaceCore is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    Counters.Counter private _tokenIdCounter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 private constant MODS_CATEGORY_HASH = keccak256("Mods");
    bytes32 private constant INFLUENCER_CATEGORY_HASH = keccak256("Influencer");
    bytes32 private constant AMBASSADOR_CATEGORY_HASH = keccak256("Ambassador");
    bytes32 private constant BETA_TESTER_CATEGORY_HASH = keccak256("BetaTester");
    bytes32 private constant VIP_PARTNER_CATEGORY_HASH = keccak256("VIPPartner");
    
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 6;
    uint8 private constant MAX_LEVEL = 250;
    uint8 private constant LEVELS_PER_BRACKET = 25;
    uint8 private constant BRACKET_COUNT = 10;
    uint256 private constant XP_PER_BRACKET_STEP = 50;
    uint256 private constant MAX_XP = 68_750;
    uint256 public constant MAX_OFFERS_PER_TOKEN = 50;
    
    mapping(uint256 => NFTMetadata) public nftMetadata;
    mapping(uint256 => bool) public isListed;
    mapping(uint256 => uint256) public listedPrice;
    mapping(uint256 => Offer[]) public nftOffers;
    mapping(address => EnumerableSet.UintSet) private _ownedTokens;
    mapping(address => EnumerableSet.UintSet) private _createdTokens;
    EnumerableSet.UintSet private _listedTokenIds;
    
    address public platformTreasury;
    ITreasuryManager public treasuryManager;
    address public skillsContractAddress;
    address public levelingSystemAddress;
    address public referralSystemAddress;
    
    IMarketplaceStatistics public statisticsModule;
    IMarketplaceView public viewModule;
    IMarketplaceSocial public socialModule;

    address public stakingContractAddress;
    mapping(address => UserProfile) public userProfiles;
    mapping(address => uint256) public pendingRefunds;
    mapping(uint256 => bool) public isBadge;
    mapping(address => bool) public hasBadge;

    event TokenCreated(address indexed creator, uint256 indexed tokenId, string uri);
    event TokenListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event TokenUnlisted(address indexed seller, uint256 indexed tokenId);
    event TokenSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event OfferMade(address indexed offeror, uint256 indexed tokenId, uint256 amount);
    event OfferAccepted(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 amount);
    event PriceUpdated(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
    event XPGained(address indexed user, uint256 amount, string reason);
    event LevelUp(address indexed user, uint8 newLevel);
    event LikeToggled(address indexed user, uint256 indexed tokenId, bool liked);
    event CommentAdded(address indexed user, uint256 indexed tokenId, string comment);
    event SkillsContractUpdated(address indexed oldAddress, address indexed newAddress);
    event StakingContractUpdated(address indexed oldAddress, address indexed newAddress);
    event LevelingSystemUpdated(address indexed oldAddress, address indexed newAddress);
    event ReferralSystemUpdated(address indexed oldAddress, address indexed newAddress);
    event PlatformFeeTransferred(address indexed from, uint256 amount, address indexed to, string operation);
    event TreasuryManagerUpdated(address indexed newManager);
    event ModuleUpdated(string indexed moduleName, address indexed oldModule, address indexed newModule);
    event RefundClaimed(address indexed user, uint256 amount);

    error NotTokenOwner();
    error TokenNotListed();
    error InsufficientPayment();
    error InvalidRoyalty();
    error InvalidPrice();
    error InvalidOfferId();
    error InvalidOfferExpiry();
    error InvalidOffer();
    error OfferExpired();
    error NotOfferor();
    error NotExists();
    error InvalidCount();
    error AlreadyHasBadge();
    error NotBadge();
    error XPOverflow();
    error InvalidAddress();
    error TreasuryFailed();
    error SellerFailed();
    error RefundFailed();
    error NoPendingRefund();
    error BadgeSoulbound();

    function initialize(address _platformTreasury) public initializer {
        __ERC721_init("NuxMarketNFT", "GNFT");
        __ERC721URIStorage_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(UPGRADER_ROLE, msg.sender);
        
        platformTreasury = _platformTreasury != address(0) ? _platformTreasury : msg.sender;
    }
    
    function setStatisticsModule(address _statistics) external onlyRole(ADMIN_ROLE) {
        if (_statistics == address(0)) revert InvalidAddress();
        address oldModule = address(statisticsModule);
        statisticsModule = IMarketplaceStatistics(_statistics);
        emit ModuleUpdated("Statistics", oldModule, _statistics);
    }
    
    function setViewModule(address _view) external onlyRole(ADMIN_ROLE) {
        if (_view == address(0)) revert InvalidAddress();
        address oldModule = address(viewModule);
        viewModule = IMarketplaceView(_view);
        emit ModuleUpdated("View", oldModule, _view);
    }
    
    function setSocialModule(address _social) external onlyRole(ADMIN_ROLE) {
        if (_social == address(0)) revert InvalidAddress();
        address oldModule = address(socialModule);
        socialModule = IMarketplaceSocial(_social);
        emit ModuleUpdated("Social", oldModule, _social);
    }

    function createStandardNFT(
        string calldata _tokenURI,
        string calldata _category,
        uint96 _royaltyPercentage
    ) external whenNotPaused returns (uint256) {
        if (_royaltyPercentage > 10000) revert InvalidRoyalty();
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        nftMetadata[tokenId] = NFTMetadata({
            creator: msg.sender,
            uri: _tokenURI,
            category: _category,
            createdAt: block.timestamp,
            royaltyPercentage: _royaltyPercentage
        });
        
        userProfiles[msg.sender].nftsCreated++;
        _addXP(msg.sender, 10);
        _createdTokens[msg.sender].add(tokenId);

        if (address(viewModule) != address(0)) {
            viewModule.addNFTToCategory(tokenId, _category);
        }

        if (_isBadgeCategory(_category)) {
            if (hasBadge[msg.sender]) revert AlreadyHasBadge();
            isBadge[tokenId] = true;
            hasBadge[msg.sender] = true;
        }

        emit TokenCreated(msg.sender, tokenId, _tokenURI);
        emit XPGained(msg.sender, 10, "NFT_CREATED");
        
        return tokenId;
    }

    function _isBadgeCategory(string memory _category) internal pure returns (bool) {
        bytes32 catHash = keccak256(bytes(_category));
        return (
            catHash == MODS_CATEGORY_HASH ||
            catHash == INFLUENCER_CATEGORY_HASH ||
            catHash == AMBASSADOR_CATEGORY_HASH ||
            catHash == BETA_TESTER_CATEGORY_HASH ||
            catHash == VIP_PARTNER_CATEGORY_HASH
        );
    }

    function createStandardNFTBatch(
        string calldata _tokenURI,
        string calldata _category,
        uint96 _royaltyPercentage,
        uint256 _count
    ) external whenNotPaused returns (uint256[] memory) {
        if (_royaltyPercentage > 10000) revert InvalidRoyalty();
        if (_count == 0 || _count > 500) revert InvalidCount();
        
        uint256[] memory tokenIds = new uint256[](_count);
        
        for (uint256 i = 0; i < _count; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            tokenIds[i] = tokenId;
            _tokenIdCounter.increment();

            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, _tokenURI);

            nftMetadata[tokenId] = NFTMetadata({
                creator: msg.sender,
                uri: _tokenURI,
                category: _category,
                createdAt: block.timestamp,
                royaltyPercentage: _royaltyPercentage
            });

            _createdTokens[msg.sender].add(tokenId);

            if (_isBadgeCategory(_category)) {
                if (hasBadge[msg.sender]) revert AlreadyHasBadge();
                isBadge[tokenId] = true;
                hasBadge[msg.sender] = true;
            }

            emit TokenCreated(msg.sender, tokenId, _tokenURI);
        }
        
        userProfiles[msg.sender].nftsCreated += _count;
        uint256 xpGained = 10 + (_count > 1 ? (_count - 1) * 5 : 0);
        _addXP(msg.sender, xpGained);
        
        emit XPGained(msg.sender, xpGained, "NFT_BATCH_CREATED");
        
        return tokenIds;
    }

    function listTokenForSale(
        uint256 _tokenId,
        uint256 _price
    ) external whenNotPaused {
        if (ownerOf(_tokenId) != msg.sender) revert NotTokenOwner();
        if (_price == 0) revert InvalidPrice();
        
        isListed[_tokenId] = true;
        listedPrice[_tokenId] = _price;
        _listedTokenIds.add(_tokenId);
        
        emit TokenListed(msg.sender, _tokenId, _price);
    }

    function unlistToken(uint256 _tokenId) external whenNotPaused {
        if (ownerOf(_tokenId) != msg.sender) revert NotTokenOwner();
        if (!isListed[_tokenId]) revert TokenNotListed();
        
        isListed[_tokenId] = false;
        listedPrice[_tokenId] = 0;
        _listedTokenIds.remove(_tokenId);
        
        emit TokenUnlisted(msg.sender, _tokenId);
    }

    function updatePrice(uint256 _tokenId, uint256 _newPrice) external whenNotPaused {
        if (ownerOf(_tokenId) != msg.sender) revert NotTokenOwner();
        if (!isListed[_tokenId]) revert TokenNotListed();
        if (_newPrice == 0) revert InvalidPrice();
        
        listedPrice[_tokenId] = _newPrice;
        emit PriceUpdated(msg.sender, _tokenId, _newPrice);
    }

    function buyToken(uint256 _tokenId) external payable whenNotPaused nonReentrant {
        if (!isListed[_tokenId]) revert TokenNotListed();
        if (msg.value < listedPrice[_tokenId]) revert InsufficientPayment();
        
        address seller = ownerOf(_tokenId);
        uint256 price = listedPrice[_tokenId];
        NFTMetadata memory meta = nftMetadata[_tokenId];
        SaleSettlement memory settlement = MarketplaceCoreLib.buildSaleSettlement(
            seller,
            msg.sender,
            price,
            meta,
            PLATFORM_FEE_PERCENTAGE
        );
        
        _transfer(seller, msg.sender, _tokenId);

        MarketplaceCoreLib.finalizeSale(
            userProfiles,
            pendingRefunds,
            isListed,
            listedPrice,
            nftOffers,
            _listedTokenIds,
            address(statisticsModule),
            address(treasuryManager),
            platformTreasury,
            _tokenId,
            type(uint256).max,
            settlement,
            meta
        );
        
        if (msg.value > price) {
            (bool e,) = payable(msg.sender).call{value: msg.value - price}("");
            if (!e) revert RefundFailed();
        }
        
        emit PlatformFeeTransferred(msg.sender, settlement.platformFee, platformTreasury, "TOKEN_SALE");
        emit TokenSold(seller, msg.sender, _tokenId, price);
        emit XPGained(seller, 20, "NFT_SOLD");
        emit XPGained(msg.sender, 15, "NFT_BOUGHT");
    }

    function makeOffer(
        uint256 _tokenId,
        uint8 _expiresInDays
    ) external payable whenNotPaused nonReentrant {
        if (!isListed[_tokenId]) revert TokenNotListed();
        if (msg.value == 0) revert InvalidOffer();
        if (_expiresInDays == 0 || _expiresInDays > 30) revert InvalidOfferExpiry();
        if (nftOffers[_tokenId].length >= MAX_OFFERS_PER_TOKEN) revert InvalidOffer();
        
        nftOffers[_tokenId].push(Offer({
            offeror: msg.sender,
            amount: msg.value,
            expiresInDays: _expiresInDays,
            timestamp: block.timestamp
        }));
        
        emit OfferMade(msg.sender, _tokenId, msg.value);
    }

    function acceptOffer(uint256 _tokenId, uint256 _offerIndex) external nonReentrant {
        if (ownerOf(_tokenId) != msg.sender) revert NotTokenOwner();
        if (_offerIndex >= nftOffers[_tokenId].length) revert InvalidOfferId();
        
        Offer memory offer = nftOffers[_tokenId][_offerIndex];
        if (block.timestamp > offer.timestamp + (offer.expiresInDays * 1 days)) revert OfferExpired();
        
        address buyer = offer.offeror;
        uint256 amount = offer.amount;
        NFTMetadata memory meta = nftMetadata[_tokenId];
        SaleSettlement memory settlement = MarketplaceCoreLib.buildSaleSettlement(
            msg.sender,
            buyer,
            amount,
            meta,
            PLATFORM_FEE_PERCENTAGE
        );
        
        _transfer(msg.sender, buyer, _tokenId);

        MarketplaceCoreLib.finalizeSale(
            userProfiles,
            pendingRefunds,
            isListed,
            listedPrice,
            nftOffers,
            _listedTokenIds,
            address(statisticsModule),
            address(treasuryManager),
            platformTreasury,
            _tokenId,
            _offerIndex,
            settlement,
            meta
        );
        
        emit PlatformFeeTransferred(buyer, settlement.platformFee, platformTreasury, "OFFER_ACCEPTED");
        emit OfferAccepted(msg.sender, buyer, _tokenId, amount);
    }

    function cancelOffer(uint256 _tokenId, uint256 _offerIndex) external nonReentrant {
        if (_offerIndex >= nftOffers[_tokenId].length) revert InvalidOfferId();
        
        Offer memory offer = nftOffers[_tokenId][_offerIndex];
        if (offer.offeror != msg.sender) revert NotOfferor();
        
        uint256 amount = offer.amount;
        
        nftOffers[_tokenId][_offerIndex] = nftOffers[_tokenId][nftOffers[_tokenId].length - 1];
        nftOffers[_tokenId].pop();
        
        (bool s,) = payable(msg.sender).call{value: amount}("");
        if (!s) {
            pendingRefunds[msg.sender] += amount;
            return;
        }
    }

    function claimPendingRefund() external nonReentrant {
        uint256 amount = pendingRefunds[msg.sender];
        if (amount == 0) revert NoPendingRefund();

        pendingRefunds[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            pendingRefunds[msg.sender] = amount;
            revert RefundFailed();
        }

        emit RefundClaimed(msg.sender, amount);
    }

    function toggleLike(uint256 _tokenId) external whenNotPaused {
        if (ownerOf(_tokenId) == address(0)) revert NotExists();
        bool wasLiked = address(socialModule) != address(0) ? socialModule.hasUserLiked(_tokenId, msg.sender) : false;
        if (address(socialModule) != address(0)) {
            socialModule.toggleLike(_tokenId, msg.sender);
        }
        bool isNowLiked = address(socialModule) != address(0) ? socialModule.hasUserLiked(_tokenId, msg.sender) : false;
        
        // Emit event for test compatibility
        emit LikeToggled(msg.sender, _tokenId, isNowLiked);
        
        if(!wasLiked && isNowLiked) {
            _addXP(msg.sender, 1);
            emit XPGained(msg.sender, 1, "LIKE");
        }
    }

    function addComment(uint256 _tokenId, string calldata _text) external whenNotPaused {
        if (ownerOf(_tokenId) == address(0)) revert NotExists();
        if (address(socialModule) != address(0)) {
            socialModule.addComment(_tokenId, msg.sender, _text);
        }
        // Emit event for test compatibility
        emit CommentAdded(msg.sender, _tokenId, _text);
        
        _addXP(msg.sender, 2);
        emit XPGained(msg.sender, 2, "COMMENT");
    }

    function getOwnedTokensArray(address user) external view returns (uint256[] memory) {
        return _getTokenSetValues(_ownedTokens[user]);
    }

    function getCreatedTokensArray(address user) external view returns (uint256[] memory) {
        return _getTokenSetValues(_createdTokens[user]);
    }

    function getOffersArray(uint256 tokenId) external view returns (Offer[] memory) {
        return nftOffers[tokenId];
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // SOCIAL MODULE DELEGATORS (for backward compatibility with tests)
    // ════════════════════════════════════════════════════════════════════════════════════════

    function updateUserXP(address _user, uint256 _amount) external onlyRole(ADMIN_ROLE) {
        if (userProfiles[_user].totalXP + _amount > MAX_XP) revert XPOverflow();

        userProfiles[_user].totalXP += _amount;

        uint8 newLevel = _levelFromXP(userProfiles[_user].totalXP);
        if (newLevel > userProfiles[_user].level) {
            userProfiles[_user].level = newLevel;
            emit LevelUp(_user, newLevel);
        }
        
        emit XPGained(_user, _amount, "EXTERNAL_SOURCE");
    }

    function setSkillsContract(address _skillsAddress) external onlyRole(ADMIN_ROLE) {
        if (_skillsAddress == address(0)) revert InvalidAddress();
        address oldAddress = skillsContractAddress;
        skillsContractAddress = _skillsAddress;
        emit SkillsContractUpdated(oldAddress, _skillsAddress);
    }

    function setStakingContract(address _stakingAddress) external onlyRole(ADMIN_ROLE) {
        if (_stakingAddress == address(0)) revert InvalidAddress();
        address oldAddress = stakingContractAddress;
        stakingContractAddress = _stakingAddress;
        emit StakingContractUpdated(oldAddress, _stakingAddress);
    }

    function setTreasuryManager(address _treasuryManager) external onlyRole(ADMIN_ROLE) {
        if (_treasuryManager == address(0)) revert InvalidAddress();
        treasuryManager = ITreasuryManager(_treasuryManager);
        emit TreasuryManagerUpdated(_treasuryManager);
    }

    function setLevelingSystem(address _levelingAddress) external onlyRole(ADMIN_ROLE) {
        if (_levelingAddress == address(0)) revert InvalidAddress();
        address oldAddress = levelingSystemAddress;
        levelingSystemAddress = _levelingAddress;
        emit LevelingSystemUpdated(oldAddress, _levelingAddress);
    }

    function setReferralSystem(address _referralAddress) external onlyRole(ADMIN_ROLE) {
        if (_referralAddress == address(0)) revert InvalidAddress();
        address oldAddress = referralSystemAddress;
        referralSystemAddress = _referralAddress;
        emit ReferralSystemUpdated(oldAddress, _referralAddress);
    }

    /// @dev Burn badge
    function burnBadge(uint256 _tokenId) external {
        if (ownerOf(_tokenId) != msg.sender) revert NotTokenOwner();
        if (!isBadge[_tokenId]) revert NotBadge();
        _burn(_tokenId);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        if (from != address(0)) {
            for (uint256 i = 0; i < batchSize; i++) {
                uint256 tokenId = firstTokenId + i;
                if (isBadge[tokenId] && to != address(0)) revert BadgeSoulbound();
                // Reset hasBadge on burn
                if (isBadge[tokenId] && to == address(0)) {
                    hasBadge[from] = false;
                }
                _ownedTokens[from].remove(tokenId);
            }
        }

        if (to != address(0)) {
            for (uint256 i = 0; i < batchSize; i++) {
                _ownedTokens[to].add(firstTokenId + i);
            }
        }
    }

    function _addXP(address user, uint256 amount) private {
        UserProfile storage profile = userProfiles[user];
        uint256 newTotal = profile.totalXP + amount;
        if (newTotal > MAX_XP) newTotal = MAX_XP;
        profile.totalXP = newTotal;
        uint8 newLevel = _levelFromXP(newTotal);
        if (newLevel > profile.level) {
            profile.level = newLevel;
            emit LevelUp(user, newLevel);
        }
    }

    function _levelFromXP(uint256 xp) private pure returns (uint8) {
        if (xp < XP_PER_BRACKET_STEP) return 0;

        uint256 remainingXP = xp > MAX_XP ? MAX_XP : xp;
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

    function _getTokenSetValues(EnumerableSet.UintSet storage tokenSet)
        private
        view
        returns (uint256[] memory result)
    {
        uint256 count = tokenSet.length();
        result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tokenSet.at(i);
        }
    }

    function _transfer(address from, address to, uint256 tokenId) internal override {
        if (to == address(0)) revert InvalidAddress();
        super._transfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable, AccessControlUpgradeable) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    

    function getListedTokenIds() external view returns (uint256[] memory) {
        return _listedTokenIds.values();
    }
    
    function getNFTMetadata(uint256 tokenId) external view returns (
        address creator,
        string memory uri,
        string memory category,
        uint256 createdAt,
        uint96 royaltyPercentage
    ) {
        NFTMetadata memory meta = nftMetadata[tokenId];
        return (meta.creator, meta.uri, meta.category, meta.createdAt, meta.royaltyPercentage);
    }
}
