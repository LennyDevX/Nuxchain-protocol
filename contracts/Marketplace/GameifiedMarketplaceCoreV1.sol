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

/**
 * @title GameifiedMarketplaceCoreV1
 * @dev Contrato base UPGRADEABLE para NFT creation, marketplace y XP tracking
 * - Usar con UUPS Proxy pattern
 * - Versión 1 del contrato
 */
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
    uint8 private constant MAX_LEVEL = 50;                    // Maximum level cap (synchronized with Quests)
    uint256 private constant MAX_XP = 5000;                   // Max XP: 50 levels × 100 XP per level
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
    mapping(uint256 => mapping(address => bool)) public nftLikes;
    mapping(uint256 => uint256) public nftLikeCount;
    mapping(uint256 => string[]) public nftComments;
    mapping(uint256 => Offer[]) public nftOffers;
    mapping(address => EnumerableSet.UintSet) private _ownedTokens;
    mapping(address => EnumerableSet.UintSet) private _createdTokens;
    EnumerableSet.UintSet private _listedTokenIds;
    
    address public platformTreasury;  // @dev Deprecated: Use treasuryManager instead
    ITreasuryManager public treasuryManager;
    address public skillsContractAddress;
    address public levelingSystemAddress;  // Mantener para compatibilidad
    address public referralSystemAddress;  // Mantener para compatibilidad
    
    // Variables estadísticas - mantener para compatibilidad
    uint256 public totalNFTsSold;
    uint256 public totalTradingVolume;
    uint256 public totalRoyaltiesPaid;
    mapping(address => uint256) public userSalesVolume;
    mapping(address => uint256) public userPurchaseVolume;
    mapping(address => uint256) public userRoyaltiesEarned;
    mapping(address => uint256) public userNFTsSold;
    mapping(address => uint256) public userNFTsBought;
    mapping(string => EnumerableSet.UintSet) private _nftsByCategory;
    mapping(address => uint256) public totalCreators;  // Era mapping en el original
    
    // Nuevas variables V1 (agregadas después del deployment original)
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
    event LikeToggled(address indexed user, uint256 indexed tokenId, bool liked);
    event CommentAdded(address indexed user, uint256 indexed tokenId, string comment);
    event PriceUpdated(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
    event XPGained(address indexed user, uint256 amount, string reason);
    event LevelUp(address indexed user, uint8 newLevel);
    event SkillsContractUpdated(address indexed oldAddress, address indexed newAddress);
    event QuestsContractUpdated(address indexed oldAddress, address indexed newAddress);
    event StakingContractUpdated(address indexed oldAddress, address indexed newAddress);
    event PlatformFeeTransferred(address indexed from, uint256 amount, address indexed to, string operation);
    event TreasuryManagerUpdated(address indexed newManager);

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
    error InvalidCommentLength();
    error TooManyComments();
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
        
        if (_isBadgeCategory(_category)) {
            if (hasBadge[msg.sender]) revert AlreadyHasBadge();
            isBadge[tokenId] = true;
            hasBadge[msg.sender] = true;
        }

        emit TokenCreated(msg.sender, tokenId, _tokenURI);
        emit XPGained(msg.sender, 10, "NFT_CREATED");
        
        return tokenId;
    }

    /**
     * @dev Check if category belongs to a Collaborator Badge
     */
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

    /// @dev Batch mint NFTs
    function createStandardNFTBatch(
        string calldata _tokenURI,
        string calldata _category,
        uint96 _royaltyPercentage,
        uint256 _count
    ) external whenNotPaused returns (uint256[] memory) {
        if (_royaltyPercentage > 10000) revert InvalidRoyalty();
        if (_count == 0 || _count > 500) revert InvalidCount();
        
        uint256[] memory tokenIds = new uint256[](_count);
        
        // Batch mint all tokens
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
        
        // Update user stats (XP scaled with count)
        userProfiles[msg.sender].nftsCreated += _count;
        uint256 xpGained = 10 + (_count > 1 ? (_count - 1) * 5 : 0); // 10 XP + 5 per extra copy
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
        
        if (nftLikes[_tokenId][msg.sender]) {
            nftLikes[_tokenId][msg.sender] = false;
            if (nftLikeCount[_tokenId] > 0) {
                unchecked {
                    nftLikeCount[_tokenId]--;
                }
            }
        } else {
            nftLikes[_tokenId][msg.sender] = true;
            unchecked {
                nftLikeCount[_tokenId]++;
            }
            userProfiles[msg.sender].totalXP += 1;
            emit XPGained(msg.sender, 1, "LIKE");
        }
        
        emit LikeToggled(msg.sender, _tokenId, nftLikes[_tokenId][msg.sender]);
    }

    function addComment(uint256 _tokenId, string calldata _text) external whenNotPaused {
        if (ownerOf(_tokenId) == address(0)) revert NotExists();
        uint256 len = bytes(_text).length;
        if (len == 0 || len > 280) revert InvalidCommentLength();
        if (nftComments[_tokenId].length >= MAX_COMMENTS_PER_NFT) revert TooManyComments();
        
        nftComments[_tokenId].push(_text);
        userProfiles[msg.sender].totalXP += 2;
        
        emit CommentAdded(msg.sender, _tokenId, _text);
        emit XPGained(msg.sender, 2, "COMMENT");
    }

    /// @dev Get user profile
    function getUserProfile(address _user) external view returns (UserProfile memory) {
        return userProfiles[_user];
    }
    
    /// @dev Get NFT metadata
    function getNFTMetadata(uint256 _tokenId) external view returns (NFTMetadata memory) {
        if (!_exists(_tokenId)) revert NotExists();
        return nftMetadata[_tokenId];
    }
    
    /// @dev Get like count
    function getNFTLikeCount(uint256 _tokenId) external view returns (uint256) {
        if (!_exists(_tokenId)) revert NotExists();
        return nftLikeCount[_tokenId];
    }
    
    /// @dev Get comments
    function getNFTComments(uint256 _tokenId) external view returns (string[] memory) {
        if (!_exists(_tokenId)) revert NotExists();
        return nftComments[_tokenId];
    }
    
    /// @dev Get offers
    function getNFTOffers(uint256 _tokenId) external view returns (Offer[] memory) {
        if (!_exists(_tokenId)) revert NotExists();
        return nftOffers[_tokenId];
    }
    
    /// @dev Paginate tokens
    function _paginateTokenSet(
        EnumerableSet.UintSet storage set,
        uint256 cursor,
        uint256 size
    ) internal view returns (uint256[] memory tokens, uint256 newCursor) {
        uint256 length = set.length();
        if (cursor >= length) {
            return (new uint256[](0), length);
        }

        uint256 end = cursor + size;
        if (end > length) {
            end = length;
        }

        uint256 pageSize = end - cursor;
        tokens = new uint256[](pageSize);

        for (uint256 i = 0; i < pageSize; i++) {
            tokens[i] = set.at(cursor + i);
        }

        return (tokens, end);
    }

    function getUserNFTs(address _user) external view returns (uint256[] memory) {
        uint256 balance = _ownedTokens[_user].length();
        uint256[] memory result = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            result[i] = _ownedTokens[_user].at(i);
        }
        return result;
    }

    function getUserNFTsPage(address _user, uint256 cursor, uint256 size)
        external
        view
        returns (uint256[] memory tokens, uint256 nextCursor)
    {
        return _paginateTokenSet(_ownedTokens[_user], cursor, size);
    }

    /// @dev Get created NFTs
    function getUserCreatedNFTs(address _user) external view returns (uint256[] memory) {
        uint256 createdCount = _createdTokens[_user].length();
        uint256[] memory result = new uint256[](createdCount);
        for (uint256 i = 0; i < createdCount; i++) {
            result[i] = _createdTokens[_user].at(i);
        }
        return result;
    }

    function getUserCreatedNFTsPage(address _user, uint256 cursor, uint256 size)
        external
        view
        returns (uint256[] memory tokens, uint256 nextCursor)
    {
        return _paginateTokenSet(_createdTokens[_user], cursor, size);
    }

    /// @dev Get listed NFTs
    function getListedNFTs() external view returns (uint256[] memory) {
        uint256 listedCount = _listedTokenIds.length();
        uint256[] memory result = new uint256[](listedCount);
        for (uint256 i = 0; i < listedCount; i++) {
            result[i] = _listedTokenIds.at(i);
        }
        return result;
    }

    function getListedNFTsPage(uint256 cursor, uint256 size)
        external
        view
        returns (uint256[] memory tokens, uint256 nextCursor)
    {
        return _paginateTokenSet(_listedTokenIds, cursor, size);
    }

    /// @dev Get detailed user NFTs
    function getUserNFTsDetailed(address _user) external view returns (NFTMetadata[] memory) {
        uint256 balance = _ownedTokens[_user].length();
        NFTMetadata[] memory result = new NFTMetadata[](balance);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = _ownedTokens[_user].at(i);
            result[i] = nftMetadata[tokenId];
        }

        return result;
    }
    
    /// @dev Check if user liked NFT
    function getUserNFTLike(uint256 _tokenId, address _user) external view returns (bool) {
        if (!_exists(_tokenId)) revert NotExists();
        return nftLikes[_tokenId][_user];
    }
    
    /// @dev Get market info
    function getNFTMarketInfo(uint256 _tokenId) external view returns (
        address owner,
        bool isListedStatus,
        uint256 price
    ) {
        if (!_exists(_tokenId)) revert NotExists();
        owner = ownerOf(_tokenId);
        isListedStatus = isListed[_tokenId];
        price = isListed[_tokenId] ? listedPrice[_tokenId] : 0;
    }

    function updateUserXP(address _user, uint256 _amount) external onlyRole(ADMIN_ROLE) {
        if (userProfiles[_user].totalXP + _amount > MAX_XP) revert XPOverflow();
        
        userProfiles[_user].totalXP += _amount;
        
        uint8 newLevel = uint8(userProfiles[_user].totalXP / 100);
        // Cap level to MAX_LEVEL (50)
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
        // Send 100% of platform fee to TreasuryManager
        // TreasuryManager automatically distributes: 35% rewards, 25% collaborators, 30% staking, 10% dev
        if (address(treasuryManager) != address(0)) {
            try treasuryManager.receiveRevenue{value: platformFee}("marketplace_fee") {
                // Fee successfully routed to TreasuryManager for integrated distribution
            } catch {
                // Fallback to old platformTreasury
                (bool t,) = payable(platformTreasury).call{value: platformFee}("");
                if (!t) revert TreasuryFailed();
            }
        } else {
            // Use old platformTreasury if treasuryManager not set
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
}
