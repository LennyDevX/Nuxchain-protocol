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
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

interface ILevelingSystem {
    function updateUserXP(address user, uint256 xpAmount, string memory reason) external;
    function recordNFTCreated(address creator) external;
    function recordNFTSold(address seller) external;
    function recordNFTBought(address buyer) external;
}

interface IReferralSystem {
    function recordReferralXP(address referrerAddress, uint256 xpAmount, string memory reason) external;
    function recordBuyerReferralBonus(address buyer, uint256 xpAmount) external;
    function userHasReferrer(address user) external view returns (bool);
    function getUserReferrer(address user) external view returns (address);
}

interface ISkillsContractInterface {
    function getAmbassadorSkillMultiplier(address user) external view 
        returns (bool hasSkill, uint16 multiplier, string memory rarity);
}

/**
 * @title GameifiedMarketplaceCoreV1  
 * @dev Core NFT marketplace with likes, comments, and offers
 * - Minimal bytecode: all XP/referral logic delegated to external contracts
 * - UUPS upgradeable proxy pattern
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
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    
    CountersUpgradeable.Counter private _tokenIdCounter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 5;
    uint256 private constant MAX_COMMENTS_PER_NFT = 1000;
    uint256 private constant REFERRER_BASE_XP = 5;
    uint256 private constant BUYER_REFERRAL_BONUS_XP = 10;
    
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
    
    mapping(uint256 => NFTMetadata) public nftMetadata;
    mapping(uint256 => bool) public isListed;
    mapping(uint256 => uint256) public listedPrice;
    mapping(uint256 => mapping(address => bool)) public nftLikes;
    mapping(uint256 => uint256) public nftLikeCount;
    mapping(uint256 => string[]) public nftComments;
    mapping(uint256 => Offer[]) public nftOffers;
    mapping(address => EnumerableSetUpgradeable.UintSet) private _ownedTokens;
    mapping(address => EnumerableSetUpgradeable.UintSet) private _createdTokens;
    EnumerableSetUpgradeable.UintSet private _listedTokenIds;
    
    address public platformTreasury;
    address public skillsContractAddress;
    address public levelingSystemAddress;
    address public referralSystemAddress;
    
    // Dashboard statistics tracking
    uint256 public totalNFTsSold;
    uint256 public totalTradingVolume;
    uint256 public totalRoyaltiesPaid;
    mapping(address => uint256) public userSalesVolume;
    mapping(address => uint256) public userPurchaseVolume;
    mapping(address => uint256) public userRoyaltiesEarned;
    mapping(address => uint256) public userNFTsSold;
    mapping(address => uint256) public userNFTsBought;
    mapping(string => EnumerableSetUpgradeable.UintSet) private _nftsByCategory;
    mapping(address => uint256) public totalCreators;

    event TokenCreated(address indexed creator, uint256 indexed tokenId, string uri);
    event TokenListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event TokenUnlisted(address indexed seller, uint256 indexed tokenId);
    event TokenSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event OfferMade(address indexed offeror, uint256 indexed tokenId, uint256 amount);
    event OfferAccepted(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 amount);
    event LikeToggled(address indexed user, uint256 indexed tokenId, bool liked);
    event CommentAdded(address indexed user, uint256 indexed tokenId, string comment);
    event PriceUpdated(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
    event PlatformFeeTransferred(address indexed from, uint256 amount, address indexed to, string operation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _platformTreasury) public initializer {
        __ERC721_init("GameifiedNFT", "GNFT");
        __ERC721URIStorage_init();
        __ERC721Royalty_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        // Set platform treasury (handle zero address)
        platformTreasury = _platformTreasury != address(0) ? _platformTreasury : msg.sender;
        
        // Grant roles to the deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
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
        
        _createdTokens[msg.sender].add(tokenId);
        _nftsByCategory[_category].add(tokenId);
        
        // Track unique creators
        if (_createdTokens[msg.sender].length() == 1) {
            totalCreators[msg.sender] = 1;
        }
        
        if (levelingSystemAddress != address(0)) {
            ILevelingSystem(levelingSystemAddress).recordNFTCreated(msg.sender);
        }
        
        emit TokenCreated(msg.sender, tokenId, _tokenURI);
        return tokenId;
    }

    function listTokenForSale(uint256 _tokenId, uint256 _price) external whenNotPaused {
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
        address buyer = msg.sender;
        uint256 price = listedPrice[_tokenId];
        
        _transfer(seller, buyer, _tokenId);
        
        uint256 platformFee = (price * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 sellerAmount = price - platformFee;
        
        // Track sales statistics
        totalNFTsSold++;
        totalTradingVolume += price;
        userSalesVolume[seller] += price;
        userPurchaseVolume[buyer] += price;
        userNFTsSold[seller]++;
        userNFTsBought[buyer]++;
        
        // Calculate and track royalties
        (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(_tokenId, price);
        if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
            totalRoyaltiesPaid += royaltyAmount;
            userRoyaltiesEarned[royaltyReceiver] += royaltyAmount;
        }
        
        // Record sale in leveling system
        if (levelingSystemAddress != address(0)) {
            ILevelingSystem(levelingSystemAddress).recordNFTSold(seller);
            ILevelingSystem(levelingSystemAddress).recordNFTBought(buyer);
        }
        
        // Process referral bonus if buyer has referrer
        if (referralSystemAddress != address(0) && IReferralSystem(referralSystemAddress).userHasReferrer(buyer)) {
            address buyerReferrer = IReferralSystem(referralSystemAddress).getUserReferrer(buyer);
            
            // Get AMBASSADOR multiplier
            uint16 multiplier = 10000; // 1.0x base
            if (skillsContractAddress != address(0)) {
                try ISkillsContractInterface(skillsContractAddress).getAmbassadorSkillMultiplier(buyerReferrer) 
                    returns (bool hasSkill, uint16 mult, string memory) {
                    if (hasSkill && mult > 0) {
                        multiplier = mult;
                    }
                } catch {}
            }
            
            // Calculate bonuses
            uint256 referrerBonus = (REFERRER_BASE_XP * multiplier) / 10000;
            uint256 buyerBonus = (BUYER_REFERRAL_BONUS_XP * multiplier) / 10000;
            
            // Record bonuses
            IReferralSystem(referralSystemAddress).recordReferralXP(buyerReferrer, referrerBonus, "REFERRAL_NFT_PURCHASE");
            IReferralSystem(referralSystemAddress).recordBuyerReferralBonus(buyer, buyerBonus);
            
            // Update XP in leveling system
            if (levelingSystemAddress != address(0)) {
                ILevelingSystem(levelingSystemAddress).updateUserXP(buyerReferrer, referrerBonus, "REFERRAL_NFT_PURCHASE");
                ILevelingSystem(levelingSystemAddress).updateUserXP(buyer, buyerBonus, "REFERRAL_BONUS");
            }
        }
        
        isListed[_tokenId] = false;
        listedPrice[_tokenId] = 0;
        _listedTokenIds.remove(_tokenId);
        delete nftOffers[_tokenId];
        
        (bool treasurySuccess, ) = payable(platformTreasury).call{value: platformFee}("");
        require(treasurySuccess, "Treasury transfer failed");
        
        (bool sellerSuccess, ) = payable(seller).call{value: sellerAmount}("");
        require(sellerSuccess, "Seller transfer failed");
        
        emit PlatformFeeTransferred(buyer, platformFee, platformTreasury, "TOKEN_SALE");
        emit TokenSold(seller, buyer, _tokenId, price);
    }

    function makeOffer(uint256 _tokenId, uint8 _expiresInDays) external payable whenNotPaused {
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
        require(block.timestamp <= offer.timestamp + (offer.expiresInDays * 1 days), "Offer expired");
        
        address buyer = offer.offeror;
        uint256 amount = offer.amount;
        
        _transfer(msg.sender, buyer, _tokenId);
        
        uint256 platformFee = (amount * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 sellerAmount = amount - platformFee;
        
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
        require(_exists(_tokenId), "Not exists");
        
        if (nftLikes[_tokenId][msg.sender]) {
            nftLikes[_tokenId][msg.sender] = false;
            if (nftLikeCount[_tokenId] > 0) {
                unchecked { nftLikeCount[_tokenId]--; }
            }
        } else {
            nftLikes[_tokenId][msg.sender] = true;
            unchecked { nftLikeCount[_tokenId]++; }
            if (levelingSystemAddress != address(0)) {
                ILevelingSystem(levelingSystemAddress).updateUserXP(msg.sender, 1, "LIKE");
            }
        }
        emit LikeToggled(msg.sender, _tokenId, nftLikes[_tokenId][msg.sender]);
    }

    function addComment(uint256 _tokenId, string calldata _text) external whenNotPaused {
        require(_exists(_tokenId), "Not exists");
        require(bytes(_text).length > 0 && bytes(_text).length <= 280, "Invalid length");
        require(nftComments[_tokenId].length < MAX_COMMENTS_PER_NFT, "Too many comments");
        
        nftComments[_tokenId].push(_text);
        if (levelingSystemAddress != address(0)) {
            ILevelingSystem(levelingSystemAddress).updateUserXP(msg.sender, 2, "COMMENT");
        }
        emit CommentAdded(msg.sender, _tokenId, _text);
    }

    function getNFTMetadata(uint256 _tokenId) external view returns (NFTMetadata memory) {
        require(_exists(_tokenId), "NFT does not exist");
        return nftMetadata[_tokenId];
    }

    function getNFTLikeCount(uint256 _tokenId) external view returns (uint256) {
        require(_exists(_tokenId), "NFT does not exist");
        return nftLikeCount[_tokenId];
    }

    function getNFTComments(uint256 _tokenId) external view returns (string[] memory) {
        require(_exists(_tokenId), "NFT does not exist");
        return nftComments[_tokenId];
    }

    function getNFTOffers(uint256 _tokenId) external view returns (Offer[] memory) {
        require(_exists(_tokenId), "NFT does not exist");
        return nftOffers[_tokenId];
    }

    function getUserNFTs(address _user) external view returns (uint256[] memory) {
        uint256 balance = _ownedTokens[_user].length();
        uint256[] memory result = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            result[i] = _ownedTokens[_user].at(i);
        }
        return result;
    }

    function getUserCreatedNFTs(address _user) external view returns (uint256[] memory) {
        uint256 createdCount = _createdTokens[_user].length();
        uint256[] memory result = new uint256[](createdCount);
        for (uint256 i = 0; i < createdCount; i++) {
            result[i] = _createdTokens[_user].at(i);
        }
        return result;
    }

    function getListedNFTs() external view returns (uint256[] memory) {
        uint256 listedCount = _listedTokenIds.length();
        uint256[] memory result = new uint256[](listedCount);
        for (uint256 i = 0; i < listedCount; i++) {
            result[i] = _listedTokenIds.at(i);
        }
        return result;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // DASHBOARD VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @dev Get comprehensive marketplace statistics
     * @return totalNFTs Total NFTs ever created
     * @return totalListed Currently listed NFTs
     * @return totalSold NFTs sold (all-time)
     * @return totalVolume Trading volume in POL
     * @return uniqueCreators Unique creators count
     * @return totalRoyalties Total royalties paid to creators
     */
    function getMarketplaceStats() external view returns (
        uint256 totalNFTs,
        uint256 totalListed,
        uint256 totalSold,
        uint256 totalVolume,
        uint256 uniqueCreators,
        uint256 totalRoyalties
    ) {
        totalNFTs = _tokenIdCounter.current();
        totalListed = _listedTokenIds.length();
        totalSold = totalNFTsSold;
        totalVolume = totalTradingVolume;
        
        // Count unique creators
        uint256 creatorCount = 0;
        for (uint256 i = 0; i < totalNFTs; i++) {
            if (_exists(i)) {
                address creator = nftMetadata[i].creator;
                if (totalCreators[creator] > 0 && _createdTokens[creator].length() > 0) {
                    creatorCount++;
                }
            }
        }
        uniqueCreators = creatorCount;
        totalRoyalties = totalRoyaltiesPaid;
    }

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
    ) {
        nftsCreated = _createdTokens[_user].length();
        nftsOwned = _ownedTokens[_user].length();
        nftsSold = userNFTsSold[_user];
        nftsBought = userNFTsBought[_user];
        totalSalesVolume = userSalesVolume[_user];
        totalPurchaseVolume = userPurchaseVolume[_user];
        totalRoyaltiesEarned = userRoyaltiesEarned[_user];
    }

    /**
     * @dev Get NFTs by category with pagination
     * @param _category Category to filter (Art, Music, etc.)
     * @param _offset Starting index
     * @param _limit Number of results
     */
    function getNFTsByCategory(string calldata _category, uint256 _offset, uint256 _limit) 
        external view returns (uint256[] memory tokenIds, NFTMetadata[] memory metadata)
    {
        uint256 categorySize = _nftsByCategory[_category].length();
        require(_offset < categorySize, "Offset out of bounds");
        
        uint256 end = _offset + _limit;
        if (end > categorySize) {
            end = categorySize;
        }
        uint256 resultSize = end - _offset;
        
        tokenIds = new uint256[](resultSize);
        metadata = new NFTMetadata[](resultSize);
        
        for (uint256 i = 0; i < resultSize; i++) {
            uint256 tokenId = _nftsByCategory[_category].at(_offset + i);
            tokenIds[i] = tokenId;
            metadata[i] = nftMetadata[tokenId];
        }
    }

    /**
     * @dev Get user's active offers (offers made by user)
     */
    function getUserActiveOffers(address _user) external view returns (
        uint256[] memory tokenIds,
        Offer[] memory offers
    ) {
        uint256 totalTokens = _tokenIdCounter.current();
        uint256 count = 0;
        
        // Count user's offers
        for (uint256 i = 0; i < totalTokens; i++) {
            if (_exists(i)) {
                Offer[] memory tokenOffers = nftOffers[i];
                for (uint256 j = 0; j < tokenOffers.length; j++) {
                    if (tokenOffers[j].offeror == _user) {
                        // Check if not expired
                        if (block.timestamp <= tokenOffers[j].timestamp + (tokenOffers[j].expiresInDays * 1 days)) {
                            count++;
                        }
                    }
                }
            }
        }
        
        tokenIds = new uint256[](count);
        offers = new Offer[](count);
        uint256 index = 0;
        
        // Populate arrays
        for (uint256 i = 0; i < totalTokens; i++) {
            if (_exists(i)) {
                Offer[] memory tokenOffers = nftOffers[i];
                for (uint256 j = 0; j < tokenOffers.length; j++) {
                    if (tokenOffers[j].offeror == _user) {
                        if (block.timestamp <= tokenOffers[j].timestamp + (tokenOffers[j].expiresInDays * 1 days)) {
                            tokenIds[index] = i;
                            offers[index] = tokenOffers[j];
                            index++;
                        }
                    }
                }
            }
        }
    }

    /**
     * @dev Get user's received offers (offers on user's NFTs)
     */
    function getUserReceivedOffers(address _user) external view returns (
        uint256[] memory tokenIds,
        Offer[] memory offers
    ) {
        uint256[] memory ownedTokens = new uint256[](_ownedTokens[_user].length());
        for (uint256 i = 0; i < _ownedTokens[_user].length(); i++) {
            ownedTokens[i] = _ownedTokens[_user].at(i);
        }
        
        uint256 count = 0;
        // Count all non-expired offers on user's NFTs
        for (uint256 i = 0; i < ownedTokens.length; i++) {
            Offer[] memory tokenOffers = nftOffers[ownedTokens[i]];
            for (uint256 j = 0; j < tokenOffers.length; j++) {
                if (block.timestamp <= tokenOffers[j].timestamp + (tokenOffers[j].expiresInDays * 1 days)) {
                    count++;
                }
            }
        }
        
        tokenIds = new uint256[](count);
        offers = new Offer[](count);
        uint256 index = 0;
        
        // Populate arrays
        for (uint256 i = 0; i < ownedTokens.length; i++) {
            Offer[] memory tokenOffers = nftOffers[ownedTokens[i]];
            for (uint256 j = 0; j < tokenOffers.length; j++) {
                if (block.timestamp <= tokenOffers[j].timestamp + (tokenOffers[j].expiresInDays * 1 days)) {
                    tokenIds[index] = ownedTokens[i];
                    offers[index] = tokenOffers[j];
                    index++;
                }
            }
        }
    }

    /**
     * @dev Get trending NFTs (most liked in last 7 days)
     */
    function getTrendingNFTs(uint256 _limit) external view returns (
        uint256[] memory tokenIds,
        uint256[] memory likesCounts
    ) {
        uint256 totalTokens = _tokenIdCounter.current();
        uint256 resultSize = _limit < totalTokens ? _limit : totalTokens;
        
        tokenIds = new uint256[](resultSize);
        likesCounts = new uint256[](resultSize);
        
        // Simple bubble sort for top liked NFTs (can be optimized)
        uint256[] memory allTokens = new uint256[](totalTokens);
        uint256[] memory allLikes = new uint256[](totalTokens);
        uint256 validCount = 0;
        
        for (uint256 i = 0; i < totalTokens; i++) {
            if (_exists(i)) {
                allTokens[validCount] = i;
                allLikes[validCount] = nftLikeCount[i];
                validCount++;
            }
        }
        
        // Sort by likes (descending)
        for (uint256 i = 0; i < validCount && i < resultSize; i++) {
            for (uint256 j = i + 1; j < validCount; j++) {
                if (allLikes[j] > allLikes[i]) {
                    // Swap
                    (allLikes[i], allLikes[j]) = (allLikes[j], allLikes[i]);
                    (allTokens[i], allTokens[j]) = (allTokens[j], allTokens[i]);
                }
            }
        }
        
        // Get top N
        for (uint256 i = 0; i < resultSize && i < validCount; i++) {
            tokenIds[i] = allTokens[i];
            likesCounts[i] = allLikes[i];
        }
    }

    /**
     * @dev Get marketplace health metrics
     */
    function getMarketplaceHealth() external view returns (
        uint256 activeListingsCount,
        uint256 activeOffersCount,
        uint256 averagePrice,
        uint256 last24hSales,
        uint256 last24hVolume
    ) {
        activeListingsCount = _listedTokenIds.length();
        
        // Count active offers
        uint256 totalTokens = _tokenIdCounter.current();
        uint256 offerCount = 0;
        uint256 totalListedPrice = 0;
        uint256 listedCount = 0;
        
        for (uint256 i = 0; i < totalTokens; i++) {
            if (_exists(i)) {
                // Count non-expired offers
                Offer[] memory tokenOffers = nftOffers[i];
                for (uint256 j = 0; j < tokenOffers.length; j++) {
                    if (block.timestamp <= tokenOffers[j].timestamp + (tokenOffers[j].expiresInDays * 1 days)) {
                        offerCount++;
                    }
                }
                
                // Sum listed prices
                if (isListed[i]) {
                    totalListedPrice += listedPrice[i];
                    listedCount++;
                }
            }
        }
        
        activeOffersCount = offerCount;
        averagePrice = listedCount > 0 ? totalListedPrice / listedCount : 0;
        
        // Note: last24hSales and last24hVolume would require event tracking or timestamp mapping
        // For now, returning 0 as placeholder (can be implemented with additional storage)
        last24hSales = 0;
        last24hVolume = 0;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    function setLevelingSystem(address _addr) external onlyRole(ADMIN_ROLE) {
        require(_addr != address(0), "Invalid address");
        levelingSystemAddress = _addr;
    }

    function setReferralSystem(address _addr) external onlyRole(ADMIN_ROLE) {
        require(_addr != address(0), "Invalid address");
        referralSystemAddress = _addr;
    }

    function setSkillsContract(address _addr) external onlyRole(ADMIN_ROLE) {
        require(_addr != address(0), "Invalid address");
        skillsContractAddress = _addr;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) 
        internal override {
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

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721RoyaltyUpgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721RoyaltyUpgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
