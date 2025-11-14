// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title GameifiedMarketplaceCoreV1
 * @dev Contrato base UPGRADEABLE para NFT creation, marketplace y XP tracking
 * - Usar con UUPS Proxy pattern
 * - Versión 1 del contrato
 */
contract GameifiedMarketplaceCoreV1 is
    ERC721,
    ERC721URIStorage,
    ERC721Royalty,
    AccessControl,
    ReentrancyGuard,
    Pausable,
    Initializable,
    UUPSUpgradeable
{
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC721("GameifiedNFT", "GNFT") {
        _disableInitializers();
    }

    Counters.Counter private _tokenIdCounter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 5;
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
    mapping(address => UserProfile) public userProfiles;
    mapping(address => EnumerableSet.UintSet) private _ownedTokens;
    mapping(address => EnumerableSet.UintSet) private _createdTokens;
    EnumerableSet.UintSet private _listedTokenIds;
    
    address public platformTreasury;
    address public skillsContractAddress;
    address public questsContractAddress;
    address public stakingContractAddress;

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

    error TokenNotFound();
    error NotTokenOwner();
    error TokenNotListed();
    error InsufficientPayment();
    error NoOffersAvailable();

    function initialize(address _platformTreasury) public initializer {
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
        require(_royaltyPercentage <= 10000, "Invalid royalty");
        
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
        
        emit TokenCreated(msg.sender, tokenId, _tokenURI);
        emit XPGained(msg.sender, 10, "NFT_CREATED");
        
        return tokenId;
    }

    function listTokenForSale(
        uint256 _tokenId,
        uint256 _price
    ) external whenNotPaused {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(_price > 0, "Invalid price");
        
        isListed[_tokenId] = true;
        listedPrice[_tokenId] = _price;
        _listedTokenIds.add(_tokenId);
        
        emit TokenListed(msg.sender, _tokenId, _price);
    }

    function unlistToken(uint256 _tokenId) external whenNotPaused {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(isListed[_tokenId], "Not listed");
        
        isListed[_tokenId] = false;
        listedPrice[_tokenId] = 0;
        _listedTokenIds.remove(_tokenId);
        
        emit TokenUnlisted(msg.sender, _tokenId);
    }

    function updatePrice(uint256 _tokenId, uint256 _newPrice) external whenNotPaused {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(isListed[_tokenId], "Not listed");
        require(_newPrice > 0, "Invalid price");
        
        listedPrice[_tokenId] = _newPrice;
        emit PriceUpdated(msg.sender, _tokenId, _newPrice);
    }

    function buyToken(uint256 _tokenId) public payable whenNotPaused nonReentrant {
        require(isListed[_tokenId], "Not listed");
        require(msg.value >= listedPrice[_tokenId], "Insufficient payment");
        
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
        
        (bool treasurySuccess, ) = payable(platformTreasury).call{value: platformFee}("");
        require(treasurySuccess, "Treasury transfer failed");
        
        (bool sellerSuccess, ) = payable(seller).call{value: sellerAmount}("");
        require(sellerSuccess, "Seller transfer failed");
        
        emit PlatformFeeTransferred(msg.sender, platformFee, platformTreasury, "TOKEN_SALE");
        emit TokenSold(seller, msg.sender, _tokenId, price);
        emit XPGained(seller, 20, "NFT_SOLD");
        emit XPGained(msg.sender, 15, "NFT_BOUGHT");
    }

    function makeOffer(
        uint256 _tokenId,
        uint8 _expiresInDays
    ) external payable whenNotPaused {
        require(isListed[_tokenId], "Not listed");
        require(msg.value > 0, "Invalid offer");
        require(_expiresInDays > 0 && _expiresInDays <= 30, "Invalid expiry");
        
        nftOffers[_tokenId].push(Offer({
            offeror: msg.sender,
            amount: msg.value,
            expiresInDays: _expiresInDays,
            timestamp: block.timestamp
        }));
        
        emit OfferMade(msg.sender, _tokenId, msg.value);
    }

    function acceptOffer(uint256 _tokenId, uint256 _offerIndex) external nonReentrant {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(_offerIndex < nftOffers[_tokenId].length, "Invalid offer");
        
        Offer memory offer = nftOffers[_tokenId][_offerIndex];
        require(
            block.timestamp <= offer.timestamp + (offer.expiresInDays * 1 days),
            "Offer expired"
        );
        
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
        
        (bool treasurySuccess, ) = payable(platformTreasury).call{value: platformFee}("");
        require(treasurySuccess, "Treasury transfer failed");
        
        (bool sellerSuccess, ) = payable(msg.sender).call{value: sellerAmount}("");
        require(sellerSuccess, "Seller transfer failed");
        
        emit PlatformFeeTransferred(buyer, platformFee, platformTreasury, "OFFER_ACCEPTED");
        emit OfferAccepted(msg.sender, buyer, _tokenId, amount);
    }

    function cancelOffer(uint256 _tokenId, uint256 _offerIndex) external nonReentrant {
        require(_offerIndex < nftOffers[_tokenId].length, "Invalid offer");
        
        Offer memory offer = nftOffers[_tokenId][_offerIndex];
        require(offer.offeror == msg.sender, "Not offeror");
        
        uint256 amount = offer.amount;
        
        nftOffers[_tokenId][_offerIndex] = nftOffers[_tokenId][nftOffers[_tokenId].length - 1];
        nftOffers[_tokenId].pop();
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Refund failed");
    }

    function toggleLike(uint256 _tokenId) external whenNotPaused {
        require(ownerOf(_tokenId) != address(0), "Not exists");
        
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
        require(ownerOf(_tokenId) != address(0), "Not exists");
        require(bytes(_text).length > 0 && bytes(_text).length <= 280, "Invalid comment length");
        require(nftComments[_tokenId].length < MAX_COMMENTS_PER_NFT, "Too many comments");
        
        nftComments[_tokenId].push(_text);
        userProfiles[msg.sender].totalXP += 2;
        
        emit CommentAdded(msg.sender, _tokenId, _text);
        emit XPGained(msg.sender, 2, "COMMENT");
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS - NFT DETAILS & MARKETPLACE
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Get user profile (XP, level, NFTs stats)
     */
    function getUserProfile(address _user) external view returns (UserProfile memory) {
        return userProfiles[_user];
    }
    
    /**
     * @dev Get NFT metadata by token ID
     * @param _tokenId Token ID
     * @return NFT metadata including creator, URI, category, created at, royalty
     */
    function getNFTMetadata(uint256 _tokenId) external view returns (NFTMetadata memory) {
        require(_exists(_tokenId), "NFT does not exist");
        return nftMetadata[_tokenId];
    }
    
    /**
     * @dev Get like count for an NFT
     * @param _tokenId Token ID
     * @return Number of likes
     */
    function getNFTLikeCount(uint256 _tokenId) external view returns (uint256) {
        require(_exists(_tokenId), "NFT does not exist");
        return nftLikeCount[_tokenId];
    }
    
    /**
     * @dev Get all comments for an NFT
     * @param _tokenId Token ID
     * @return Array of comment strings
     */
    function getNFTComments(uint256 _tokenId) external view returns (string[] memory) {
        require(_exists(_tokenId), "NFT does not exist");
        return nftComments[_tokenId];
    }
    
    /**
     * @dev Get all offers for an NFT
     * @param _tokenId Token ID
     * @return Array of offers with offeror, amount, expiry, timestamp
     */
    function getNFTOffers(uint256 _tokenId) external view returns (Offer[] memory) {
        require(_exists(_tokenId), "NFT does not exist");
        return nftOffers[_tokenId];
    }
    
    /**
     * @dev Paginate a set of token IDs.
     * @param set The EnumerableSet to paginate.
     * @param cursor The starting index.
     * @param size The number of items to return.
     * @return tokens Array of token IDs in the page.
     * @return newCursor The next cursor position.
     */
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

    /**
     * @dev Get all NFTs created by a user
     * @param _user User address (creator)
     * @return tokens Array of token IDs created by user
     */
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

    /**
     * @dev Get all currently listed NFTs for sale
     * @return tokens Array of token IDs that are listed
     */
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

    /**
     * @dev Get all NFTs owned by a user with their metadata and listing info
     * @param _user User address
     * @return Array of NFT metadata for all user's NFTs
     */
    function getUserNFTsDetailed(address _user) external view returns (NFTMetadata[] memory) {
        uint256 balance = _ownedTokens[_user].length();
        NFTMetadata[] memory result = new NFTMetadata[](balance);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = _ownedTokens[_user].at(i);
            result[i] = nftMetadata[tokenId];
        }

        return result;
    }
    
    /**
     * @dev Check if a user has liked an NFT
     * @param _tokenId Token ID
     * @param _user User address
     * @return Boolean indicating if user liked the NFT
     */
    function getUserNFTLike(uint256 _tokenId, address _user) external view returns (bool) {
        require(_exists(_tokenId), "NFT does not exist");
        return nftLikes[_tokenId][_user];
    }
    
    /**
     * @dev Get NFT market info (price, owner, listing status)
     * @param _tokenId Token ID
     * @return owner Address of NFT owner
     * @return isListedStatus Whether NFT is listed for sale
     * @return price Current listing price (0 if not listed)
     */
    function getNFTMarketInfo(uint256 _tokenId) external view returns (
        address owner,
        bool isListedStatus,
        uint256 price
    ) {
        require(_exists(_tokenId), "NFT does not exist");
        owner = ownerOf(_tokenId);
        isListedStatus = isListed[_tokenId];
        price = isListed[_tokenId] ? listedPrice[_tokenId] : 0;
    }

    function updateUserXP(address _user, uint256 _amount) external onlyRole(ADMIN_ROLE) {
        require(userProfiles[_user].totalXP + _amount <= MAX_XP, "XP overflow protection");
        
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
        require(_skillsAddress != address(0), "Invalid address");
        address oldAddress = skillsContractAddress;
        skillsContractAddress = _skillsAddress;
        emit SkillsContractUpdated(oldAddress, _skillsAddress);
    }

    function setQuestsContract(address _questsAddress) external onlyRole(ADMIN_ROLE) {
        require(_questsAddress != address(0), "Invalid address");
        address oldAddress = questsContractAddress;
        questsContractAddress = _questsAddress;
        emit QuestsContractUpdated(oldAddress, _questsAddress);
    }

    function setStakingContract(address _stakingAddress) external onlyRole(ADMIN_ROLE) {
        require(_stakingAddress != address(0), "Invalid address");
        address oldAddress = stakingContractAddress;
        stakingContractAddress = _stakingAddress;
        emit StakingContractUpdated(oldAddress, _stakingAddress);
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
                _ownedTokens[from].remove(firstTokenId + i);
            }
        }

        if (to != address(0)) {
            for (uint256 i = 0; i < batchSize; i++) {
                _ownedTokens[to].add(firstTokenId + i);
            }
        }
    }

    function _transfer(address from, address to, uint256 tokenId) internal override {
        require(to != address(0), "Cannot transfer to zero address");
        super._transfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage, ERC721Royalty) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public view override(ERC721, ERC721URIStorage) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721URIStorage, ERC721Royalty, AccessControl) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
