// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
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

contract GameifiedMarketplaceCoreV1 is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721RoyaltyUpgradeable,
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
    
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 6;
    uint8 private constant MAX_LEVEL = 50;
    uint256 private constant MAX_XP = 5000;
    uint256 private constant MAX_COMMENTS_PER_NFT = 1000;
    
    struct NFTMetadata {
        address creator;
        string uri;
        string category;
        uint256 createdAt;
        uint96 royaltyPercentage;
    }
    
    struct Offer {
        address offeror;
        uint256 amount;
        uint8 expiresInDays;
        uint256 timestamp;
    }
    
    struct UserProfile {
        uint256 totalXP;
        uint8 level;
        uint256 nftsCreated;
        uint256 nftsOwned;
        uint32 nftsSold;
        uint32 nftsBought;
    }
    
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
    
    mapping(address => uint256) public totalCreators;
    
    address public questsContractAddress;
    address public stakingContractAddress;
    mapping(address => UserProfile) public userProfiles;
    mapping(uint256 => bool) public isBadge;
    mapping(address => bool) public hasBadge;
    address public collaboratorRewardsContract;

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
    event QuestsContractUpdated(address indexed oldAddress, address indexed newAddress);
    event StakingContractUpdated(address indexed oldAddress, address indexed newAddress);
    event PlatformFeeTransferred(address indexed from, uint256 amount, address indexed to, string operation);
    event TreasuryManagerUpdated(address indexed newManager);
    event ModuleUpdated(string indexed moduleName, address indexed oldModule, address indexed newModule);

    error TokenNotFound();
    error NotTokenOwner();
    error TokenNotListed();
    error InsufficientPayment();
    error NoOffersAvailable();
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
    error CollaboratorFailed();
    error FallbackFailed();
    error SellerFailed();
    error RefundFailed();
    error BadgeSoulbound();

    function initialize(address _platformTreasury) public initializer {
        __ERC721_init("GameifiedNFT", "GNFT");
        __ERC721URIStorage_init();
        __ERC721Royalty_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(UPGRADER_ROLE, msg.sender);
        
        platformTreasury = _platformTreasury != address(0) ? _platformTreasury : msg.sender;
    }
    
    function setStatisticsModule(address _statistics) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_statistics == address(0)) revert InvalidAddress();
        address oldModule = address(statisticsModule);
        statisticsModule = IMarketplaceStatistics(_statistics);
        emit ModuleUpdated("Statistics", oldModule, _statistics);
    }
    
    function setViewModule(address _view) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_view == address(0)) revert InvalidAddress();
        address oldModule = address(viewModule);
        viewModule = IMarketplaceView(_view);
        emit ModuleUpdated("View", oldModule, _view);
    }
    
    function setSocialModule(address _social) external onlyRole(DEFAULT_ADMIN_ROLE) {
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
        
        if (_royaltyPercentage > 0) {
            _setTokenRoyalty(tokenId, msg.sender, _royaltyPercentage);
        }
        
        userProfiles[msg.sender].nftsCreated++;
        userProfiles[msg.sender].totalXP += 10;
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
        bytes32 catHash = keccak256(abi.encodePacked(_category));
        return (
            catHash == keccak256(abi.encodePacked("Mods")) ||
            catHash == keccak256(abi.encodePacked("Influencer")) ||
            catHash == keccak256(abi.encodePacked("Ambassador")) ||
            catHash == keccak256(abi.encodePacked("BetaTester")) ||
            catHash == keccak256(abi.encodePacked("VIPPartner"))
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
            
            if (_royaltyPercentage > 0) {
                _setTokenRoyalty(tokenId, msg.sender, _royaltyPercentage);
            }
            
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
        userProfiles[msg.sender].totalXP += xpGained;
        
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

    function buyToken(uint256 _tokenId) public payable whenNotPaused nonReentrant {
        if (!isListed[_tokenId]) revert TokenNotListed();
        if (msg.value < listedPrice[_tokenId]) revert InsufficientPayment();
        
        address seller = ownerOf(_tokenId);
        uint256 price = listedPrice[_tokenId];
        
        _transfer(seller, msg.sender, _tokenId);
        
        uint256 platformFee = (price * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 sellerAmount = price - platformFee;
        
        userProfiles[seller].nftsSold++;
        userProfiles[msg.sender].nftsBought++;
        userProfiles[seller].totalXP += 20;
        userProfiles[msg.sender].totalXP += 15;
        
        if (address(statisticsModule) != address(0)) {
            statisticsModule.recordSale(seller, msg.sender, _tokenId, price);
        }
        
        isListed[_tokenId] = false;
        listedPrice[_tokenId] = 0;
        _listedTokenIds.remove(_tokenId);
        delete nftOffers[_tokenId];
        
        _distributeFee(platformFee);
        
        (bool s,) = payable(seller).call{value: sellerAmount}("");
        if (!s) revert SellerFailed();
        
        emit PlatformFeeTransferred(msg.sender, platformFee, platformTreasury, "TOKEN_SALE");
        emit TokenSold(seller, msg.sender, _tokenId, price);
        emit XPGained(seller, 20, "NFT_SOLD");
        emit XPGained(msg.sender, 15, "NFT_BOUGHT");
    }

    function makeOffer(
        uint256 _tokenId,
        uint8 _expiresInDays
    ) external payable whenNotPaused {
        if (!isListed[_tokenId]) revert TokenNotListed();
        if (msg.value == 0) revert InvalidOffer();
        if (_expiresInDays == 0 || _expiresInDays > 30) revert InvalidOfferExpiry();
        
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
        
        _transfer(msg.sender, buyer, _tokenId);
        
        uint256 platformFee = (amount * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 sellerAmount = amount - platformFee;
        
        userProfiles[msg.sender].nftsSold++;
        userProfiles[buyer].nftsBought++;
        userProfiles[msg.sender].totalXP += 20;
        userProfiles[buyer].totalXP += 15;
        
        if (address(statisticsModule) != address(0)) {
            statisticsModule.recordSale(msg.sender, buyer, _tokenId, amount);
        }
        
        isListed[_tokenId] = false;
        listedPrice[_tokenId] = 0;
        delete nftOffers[_tokenId];
        
        _distributeFee(platformFee);
        
        (bool s,) = payable(msg.sender).call{value: sellerAmount}("");
        if (!s) revert SellerFailed();
        
        emit PlatformFeeTransferred(buyer, platformFee, platformTreasury, "OFFER_ACCEPTED");
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
        if (!s) revert RefundFailed();
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
            userProfiles[msg.sender].totalXP += 1;
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
        
        userProfiles[msg.sender].totalXP += 2;
        emit XPGained(msg.sender, 2, "COMMENT");
    }

    function getOwnedTokensArray(address user) external view returns (uint256[] memory) {
        uint256 count = _ownedTokens[user].length();
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = _ownedTokens[user].at(i);
        }
        return result;
    }

    function getCreatedTokensArray(address user) external view returns (uint256[] memory) {
        uint256 count = _createdTokens[user].length();
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = _createdTokens[user].at(i);
        }
        return result;
    }

    function getOffersArray(uint256 tokenId) external view returns (Offer[] memory) {
        return nftOffers[tokenId];
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // SOCIAL MODULE DELEGATORS (for backward compatibility with tests)
    // ════════════════════════════════════════════════════════════════════════════════════════

    function nftLikeCount(uint256 _tokenId) external view returns (uint256) {
        if (address(socialModule) != address(0)) {
            return socialModule.getLikeCount(_tokenId);
        }
        return 0;
    }

    function totalTradingVolume() external view returns (uint256) {
        if (address(statisticsModule) != address(0)) {
            return statisticsModule.totalTradingVolume();
        }
        return 0;
    }

    function updateUserXP(address _user, uint256 _amount) external onlyRole(ADMIN_ROLE) {
        if (userProfiles[_user].totalXP + _amount > MAX_XP) revert XPOverflow();
        
        userProfiles[_user].totalXP += _amount;
        
        uint8 newLevel = uint8(userProfiles[_user].totalXP / 100);
        if (newLevel > MAX_LEVEL) {
            newLevel = MAX_LEVEL;
        }
        
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

    function setQuestsContract(address _questsAddress) external onlyRole(ADMIN_ROLE) {
        if (_questsAddress == address(0)) revert InvalidAddress();
        address oldAddress = questsContractAddress;
        questsContractAddress = _questsAddress;
        emit QuestsContractUpdated(oldAddress, _questsAddress);
    }

    function setStakingContract(address _stakingAddress) external onlyRole(ADMIN_ROLE) {
        if (_stakingAddress == address(0)) revert InvalidAddress();
        address oldAddress = stakingContractAddress;
        stakingContractAddress = _stakingAddress;
        emit StakingContractUpdated(oldAddress, _stakingAddress);
    }

    function setCollaboratorRewardsContract(address _collaboratorRewards) external onlyRole(ADMIN_ROLE) {
        if (_collaboratorRewards == address(0)) revert InvalidAddress();
        collaboratorRewardsContract = _collaboratorRewards;
    }

    function setTreasuryManager(address _treasuryManager) external onlyRole(ADMIN_ROLE) {
        if (_treasuryManager == address(0)) revert InvalidAddress();
        treasuryManager = ITreasuryManager(_treasuryManager);
        emit TreasuryManagerUpdated(_treasuryManager);
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

    /// @dev Internal fee distribution (100% to TreasuryManager integrated model)
    function _distributeFee(uint256 platformFee) internal {
        if (address(treasuryManager) != address(0)) {
            try treasuryManager.receiveRevenue{value: platformFee}("marketplace_fee") {
            } catch {
                (bool t,) = payable(platformTreasury).call{value: platformFee}("");
                if (!t) revert TreasuryFailed();
            }
        } else {
            (bool t,) = payable(platformTreasury).call{value: platformFee}("");
            if (!t) revert TreasuryFailed();
        }
    }

    function _transfer(address from, address to, uint256 tokenId) internal override {
        if (to == address(0)) revert InvalidAddress();
        super._transfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721RoyaltyUpgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721RoyaltyUpgradeable, AccessControlUpgradeable) returns (bool)
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
