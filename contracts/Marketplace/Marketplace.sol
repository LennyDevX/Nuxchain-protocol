// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Marketplace
 * @dev Un contrato para un marketplace de NFTs donde cualquier usuario puede
 * crear, listar y vender sus propios NFTs. Incluye funcionalidades de
 * likes, gestión de ventas y royalties.
 */
contract Marketplace is 
    ERC721, 
    ERC721URIStorage, 
    ERC721Royalty,
    ReentrancyGuard,
    Pausable,
    AccessControl 
{
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    
    // Constantes almacenadas como inmutables para ahorro de gas
    bytes32 public immutable ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public immutable MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    
    // Contadores
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _offerIdCounter;
    
    // Dirección para recibir las comisiones de la plataforma
    address public platformTreasury;

    // Comisión por ventas para la plataforma (5%)
    uint256 public platformFeePercentage = 5;
    
    // Royalty por defecto para creadores (2.5%)
    uint96 public defaultRoyaltyPercentage = 250; // Base 10000
    
    // Límite máximo de NFTs por transacción para prevenir ataques de gas
    uint256 public constant MAX_BATCH_SIZE = 20;
    
    // Límite máximo de NFTs por batch de minteo
    uint256 public constant MAX_BATCH_MINT_SIZE = 1000;
    
    // Precio mínimo para prevenir errores y manipulación
    uint256 public constant MIN_PRICE = 1000 wei;
    
    // Pausabilidad por sección (0 = listado, 1 = compras, 2 = ofertas, 3 = creación)
    mapping(uint8 => bool) public sectionPaused;
    
    // Estructura para NFTs listados en el marketplace
    struct ListedToken {
        uint256 tokenId;
        address payable seller;
        address owner;
        uint256 price;
        bool isForSale;
        uint256 listedTimestamp;
        string category;
    }
    
    // Estructura para ofertas sobre tokens
    struct Offer {
        uint256 offerId;
        uint256 tokenId;
        address payable buyer;
        uint256 offerAmount;
        uint256 expiresAt;
        bool isActive;
    }
    
    // Estructura para registro de likes
    struct TokenLikes {
        uint256 count;
        mapping(address => bool) userLikes;
    }
    
    // Estructura para comentarios
    struct Comment {
        address commenter;
        string text;
        uint256 timestamp;
    }
    
    // Mappings optimizados
    mapping(uint256 => ListedToken) private _listedTokens;
    mapping(uint256 => TokenLikes) private _tokenLikes;
    mapping(uint256 => Comment[]) private _tokenComments;
    mapping(uint256 => Offer) private _offers;
    mapping(uint256 => mapping(address => uint256[])) private _userOfferIds;
    mapping(address => bool) private _blacklistedAddresses;
    mapping(bytes32 => bool) private _registeredCategoriesHashed; // Uso de hashes para categorías
    mapping(uint256 => address) private _originalCreators;
    
    // Sets enumerables para consultas más eficientes
    mapping(address => EnumerableSet.UintSet) private _creatorTokensSet;
    mapping(uint256 => EnumerableSet.UintSet) private _tokenActiveOffers;
    EnumerableSet.AddressSet private _blacklistedAddressesSet;
    
    // Error personalizado (custom errors - más eficientes en gas que require con strings)
    error Unauthorized();
    error InvalidInput();
    error TokenNotForSale();
    error InsufficientFunds();
    error TransferFailed();
    error OfferNotActive();
    error CategoryNotValid();
    error TokenDoesNotExist();
    error BlacklistedAddress();
    error SectionPaused();
    error RoyaltyTooHigh();
    error AlreadyListed();
    
    // Eventos
    event TokenMinted(uint256 indexed tokenId, address indexed creator, string tokenURI, string category);
    event TokenListed(uint256 indexed tokenId, address indexed seller, uint256 price, string category);
    event TokenSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event TokenPriceUpdated(uint256 indexed tokenId, uint256 newPrice);
    event TokenUnlisted(uint256 indexed tokenId);
    event OfferCreated(uint256 indexed offerId, uint256 indexed tokenId, address indexed buyer, uint256 amount, uint256 expiresAt);
    event OfferAccepted(uint256 indexed offerId, uint256 indexed tokenId, address seller, address buyer, uint256 amount);
    event OfferRejected(uint256 indexed offerId);
    event OfferCancelled(uint256 indexed offerId);
    event TokenLiked(uint256 indexed tokenId, address user, uint256 totalLikes);
    event TokenUnLiked(uint256 indexed tokenId, address user, uint256 totalLikes);
    event CommentAdded(uint256 indexed tokenId, address commenter, string comment);
    event CategoryRegistered(string category);
    event EmergencyWithdrawal(address to, uint256 amount);
    event RoyaltyPaid(uint256 indexed tokenId, address indexed creator, uint256 amount);

    /**
     * @dev Constructor que inicializa el nombre y símbolo del NFT.
     */
    constructor() 
        ERC721("Nuvos NFTs", "NFT+")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MODERATOR_ROLE, msg.sender);
        
        platformTreasury = msg.sender; // Por defecto, la tesorería es el deployer

       // Register initial categories
            _registerCategory("art");
            _registerCategory("photography");
            _registerCategory("music");
            _registerCategory("video");
            _registerCategory("collectibles");
        }

    // Modificadores
    
    /**
     * @dev Verifica que un token exista y no sea un token quemado.
     */
    modifier tokenExists(uint256 tokenId) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        _;
    }
    
    /**
     * @dev Verifica que el remitente no esté en la lista negra.
     */
    modifier notBlacklisted() {
        if (_blacklistedAddresses[msg.sender]) revert BlacklistedAddress();
        _;
    }
    
    /**
     * @dev Verifica que una sección específica no esté pausada.
     */
    modifier whenSectionNotPaused(uint8 section) {
        if (sectionPaused[section]) revert SectionPaused();
        _;
    }
    
    /**
     * @dev Verifica que una categoría esté registrada.
     */
    modifier validCategory(string memory category) {
        bytes32 categoryHash = keccak256(abi.encodePacked(category));
        if (!_registeredCategoriesHashed[categoryHash]) revert CategoryNotValid();
        _;
    }

    // Funciones principales
    
    /**
     * @dev Permite a cualquier usuario crear un NFT con su propia imagen.
     * @param _tokenURI La URI que apunta a los metadatos del NFT.
     * @param category La categoría del NFT.
     * @param royaltyPercentage El porcentaje de royalty para ventas secundarias (base 10000).
     * @return El ID del nuevo token minteado.
     */
    function createNFT(
        string calldata _tokenURI, 
        string calldata category,
        uint96 royaltyPercentage
    )
        public
        virtual
        whenNotPaused
        whenSectionNotPaused(3)
        notBlacklisted
        validCategory(category)
        returns (uint256)
    {
        if (bytes(_tokenURI).length == 0) revert InvalidInput();
        if (royaltyPercentage > 1000) revert RoyaltyTooHigh(); // Max 10%
        
        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();
        
        // Usar el royalty específico o el predeterminado
        uint96 finalRoyalty = royaltyPercentage > 0 ? royaltyPercentage : defaultRoyaltyPercentage;
        _setTokenRoyalty(newTokenId, msg.sender, finalRoyalty);
        
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        
        // Registrar creator original para royalties
        _originalCreators[newTokenId] = msg.sender;
        _creatorTokensSet[msg.sender].add(newTokenId);
        
        emit TokenMinted(newTokenId, msg.sender, _tokenURI, category);
        return newTokenId;
    }
    
    /**
     * @dev Permite a cualquier usuario crear múltiples copias de un NFT con la misma URI.
     * @param _tokenURI La URI que apunta a los metadatos del NFT.
     * @param category La categoría del NFT.
     * @param royaltyPercentage El porcentaje de royalty para ventas secundarias (base 10000).
     * @param quantity Número de copias a crear (1-1000).
     * @return Array con los IDs de los nuevos tokens minteados.
     */
    function createNFTBatch(
        string calldata _tokenURI,
        string calldata category,
        uint96 royaltyPercentage,
        uint256 quantity
    )
        public
        whenNotPaused
        whenSectionNotPaused(3)
        notBlacklisted
        validCategory(category)
        returns (uint256[] memory)
    {
        if (bytes(_tokenURI).length == 0) revert InvalidInput();
        if (royaltyPercentage > 1000) revert RoyaltyTooHigh(); // Max 10%
        if (quantity == 0 || quantity > MAX_BATCH_MINT_SIZE) revert InvalidInput();
        
        uint256[] memory tokenIds = new uint256[](quantity);
        
        // Usar el royalty específico o el predeterminado
        uint96 finalRoyalty = royaltyPercentage > 0 ? royaltyPercentage : defaultRoyaltyPercentage;
        
        for (uint256 i = 0; i < quantity; i++) {
            _tokenIdCounter.increment();
            uint256 newTokenId = _tokenIdCounter.current();
            
            _setTokenRoyalty(newTokenId, msg.sender, finalRoyalty);
            _safeMint(msg.sender, newTokenId);
            _setTokenURI(newTokenId, _tokenURI);
            
            // Registrar creator original para royalties
            _originalCreators[newTokenId] = msg.sender;
            _creatorTokensSet[msg.sender].add(newTokenId);
            
            tokenIds[i] = newTokenId;
        }
        
        // Emitir eventos después del loop para evitar stack too deep
        _emitBatchMintEvents(tokenIds, _tokenURI, category);
        
        return tokenIds;
    }
    
    /**
     * @dev Permite al propietario de un NFT ponerlo a la venta.
     * @param tokenId ID del token a listar.
     * @param price Precio en wei.
     * @param category Categoría del NFT para clasificación.
     */
    function listTokenForSale(
        uint256 tokenId, 
        uint256 price,
        string calldata category
    )
        public
        whenNotPaused
        whenSectionNotPaused(0)
        notBlacklisted
        tokenExists(tokenId)
        validCategory(category)
    {
        if (ownerOf(tokenId) != msg.sender) revert Unauthorized();
        if (price < MIN_PRICE) revert InvalidInput();
        
        _listedTokens[tokenId] = ListedToken(
            tokenId,
            payable(msg.sender),
            msg.sender,
            price,
            true,
            block.timestamp,
            category
        );
        
        emit TokenListed(tokenId, msg.sender, price, category);
    }
    
    /**
     * @dev Permite al propietario de un NFT retirarlo de la venta.
     * @param tokenId ID del token a deslistar.
     */
    function unlistedToken(uint256 tokenId)
        public
        whenNotPaused
        notBlacklisted
        tokenExists(tokenId)
    {
        ListedToken storage listedToken = _listedTokens[tokenId];
        if (ownerOf(tokenId) != msg.sender) revert Unauthorized();
        if (!listedToken.isForSale) revert TokenNotForSale();

        listedToken.isForSale = false;
        emit TokenUnlisted(tokenId);
    }

    /**
     * @dev Permite al vendedor actualizar el precio de un NFT listado.
     * @param tokenId ID del token.
     * @param newPrice Nuevo precio en wei.
     */
    function updatePrice(uint256 tokenId, uint256 newPrice)
        public
        whenNotPaused
        notBlacklisted
        tokenExists(tokenId)
    {
        ListedToken storage listedToken = _listedTokens[tokenId];
        if (ownerOf(tokenId) != msg.sender) revert Unauthorized();
        if (!listedToken.isForSale) revert TokenNotForSale();
        if (newPrice < MIN_PRICE) revert InvalidInput();

        listedToken.price = newPrice;
        emit TokenPriceUpdated(tokenId, newPrice);
    }

    /**
     * @dev Permite a un usuario comprar un NFT listado.
     * @param tokenId ID del token a comprar.
     */
    function buyToken(uint256 tokenId)
        public
        payable
        nonReentrant
        whenNotPaused
        whenSectionNotPaused(1)
        notBlacklisted
        tokenExists(tokenId)
    {
        ListedToken storage listedToken = _listedTokens[tokenId];
        if (!listedToken.isForSale) revert TokenNotForSale();
        if (msg.value < listedToken.price) revert InsufficientFunds();
        if (listedToken.seller == msg.sender) revert InvalidInput();
        
        address payable seller = listedToken.seller;
        uint256 price = listedToken.price;
        
        // Calcular comisión de plataforma y enviarla a la tesorería
        uint256 platformFee = (price * platformFeePercentage) / 100;
        if (platformFee > 0) {
            _sendValue(payable(platformTreasury), platformFee);
        }
        
        // Calcular royalty para el creador original si es venta secundaria
        uint256 royaltyAmount = 0;
        address originalCreator = _originalCreators[tokenId];
        
        if (originalCreator != address(0) && originalCreator != seller) {
            // Obtener información de royalty
            (address receiver, uint256 royaltyValue) = royaltyInfo(tokenId, price);
            royaltyAmount = royaltyValue;
            
            // Transferir royalty al creador original
            if (royaltyAmount > 0 && receiver != address(0)) {
                bool sentRoyalty = _sendValue(payable(receiver), royaltyAmount);
                if (sentRoyalty) {
                    emit RoyaltyPaid(tokenId, receiver, royaltyAmount);
                }
            }
        }
        
        // Calcular pago final al vendedor
        uint256 sellerProceeds = price - platformFee - royaltyAmount;
        
        // Actualizar estado antes de transferencias para evitar reentrancy
        listedToken.owner = msg.sender;
        listedToken.seller = payable(msg.sender);
        listedToken.isForSale = false;
        
        // Cancelar ofertas existentes
        _cancelAllOffersForToken(tokenId);
        
        // Transferir NFT al comprador
        _transfer(seller, msg.sender, tokenId);
        
        // Transferir pagos
        bool sentSeller = _sendValue(seller, sellerProceeds);
        if (!sentSeller) revert TransferFailed();
        
        // Devolver exceso de pago si lo hay
        if (msg.value > price) {
            bool sentBuyer = _sendValue(payable(msg.sender), msg.value - price);
            if (!sentBuyer) revert TransferFailed();
        }
        
        emit TokenSold(tokenId, seller, msg.sender, price);
    }
    
    /**
     * @dev Permite a un usuario hacer una oferta por un NFT.
     * @param tokenId ID del token.
     * @param expiresInDays Días hasta que expire la oferta.
     */
    function makeOffer(uint256 tokenId, uint8 expiresInDays)
        public
        payable
        nonReentrant
        whenNotPaused
        whenSectionNotPaused(2)
        notBlacklisted
        tokenExists(tokenId)
    {
        if (msg.value <= MIN_PRICE) revert InvalidInput();
        if (expiresInDays == 0 || expiresInDays > 30) revert InvalidInput();
        if (ownerOf(tokenId) == msg.sender) revert InvalidInput();
        
        uint256 expirationTime = block.timestamp + (expiresInDays * 1 days);
        
        _offerIdCounter.increment();
        uint256 offerId = _offerIdCounter.current();
        
        _offers[offerId] = Offer(
            offerId,
            tokenId,
            payable(msg.sender),
            msg.value,
            expirationTime,
            true
        );
        
        _userOfferIds[tokenId][msg.sender].push(offerId);
        _tokenActiveOffers[tokenId].add(offerId);
        
        emit OfferCreated(offerId, tokenId, msg.sender, msg.value, expirationTime);
    }
    
    /**
     * @dev Permite al propietario de un NFT aceptar una oferta.
     * @param offerId ID de la oferta.
     */
    function acceptOffer(uint256 offerId)
        public
        nonReentrant
        whenNotPaused
        whenSectionNotPaused(2)
        notBlacklisted
    {
        Offer storage offer = _offers[offerId];
        if (!offer.isActive) revert OfferNotActive();
        if (block.timestamp >= offer.expiresAt) revert InvalidInput();
        if (ownerOf(offer.tokenId) != msg.sender) revert Unauthorized();
        
        uint256 tokenId = offer.tokenId;
        address payable buyer = offer.buyer;
        uint256 offerAmount = offer.offerAmount;
        
        // Calcular comisión de plataforma y enviarla a la tesorería
        uint256 platformFee = (offerAmount * platformFeePercentage) / 100;
        if (platformFee > 0) {
            _sendValue(payable(platformTreasury), platformFee);
        }
        
        // Calcular royalty para el creador original
        uint256 royaltyAmount = 0;
        address originalCreator = _originalCreators[tokenId];
        
        if (originalCreator != address(0) && originalCreator != msg.sender) {
            (address receiver, uint256 royaltyValue) = royaltyInfo(tokenId, offerAmount);
            royaltyAmount = royaltyValue;
            
            if (royaltyAmount > 0 && receiver != address(0)) {
                bool sentRoyalty = _sendValue(payable(receiver), royaltyAmount);
                if (sentRoyalty) {
                    emit RoyaltyPaid(tokenId, receiver, royaltyAmount);
                }
            }
        }
        
        // Calcular pago al vendedor
        uint256 sellerProceeds = offerAmount - platformFee - royaltyAmount;
        
        // Marcar como no disponible si estaba listado
        if (_listedTokens[tokenId].isForSale) {
            _listedTokens[tokenId].isForSale = false;
        }
        
        // Marcar oferta como inactiva
        offer.isActive = false;
        
        // Cancelar otras ofertas
        _cancelAllOffersForToken(tokenId);
        
        // Transferir NFT al comprador
        _transfer(msg.sender, buyer, tokenId);
        
        // Transferir pago al vendedor
        bool sentSeller = _sendValue(payable(msg.sender), sellerProceeds);
        if (!sentSeller) revert TransferFailed();
        
        emit OfferAccepted(offerId, tokenId, msg.sender, buyer, offerAmount);
    }
    
    /**
     * @dev Permite al propietario de un NFT rechazar una oferta.
     * @param offerId ID de la oferta a rechazar.
     */
    function rejectOffer(uint256 offerId)
        public
        whenNotPaused
        notBlacklisted
    {
        Offer storage offer = _offers[offerId];
        if (!offer.isActive) revert OfferNotActive();
        if (ownerOf(offer.tokenId) != msg.sender) revert Unauthorized();

        offer.isActive = false;
        _tokenActiveOffers[offer.tokenId].remove(offerId);

        emit OfferRejected(offerId);
    }

    /**
     * @dev Permite a un usuario cancelar su oferta y recibir reembolso.
     * @param offerId ID de la oferta.
     */
    function cancelOffer(uint256 offerId)
        public
        nonReentrant
        whenNotPaused
    {
        Offer storage offer = _offers[offerId];
        if (!offer.isActive) revert OfferNotActive();
        if (offer.buyer != msg.sender) revert Unauthorized();
        
        uint256 refundAmount = offer.offerAmount;
        offer.isActive = false;
        _tokenActiveOffers[offer.tokenId].remove(offerId);
        
        bool sent = _sendValue(offer.buyer, refundAmount);
        if (!sent) revert TransferFailed();
        
        emit OfferCancelled(offerId);
    }
    
    /**
     * @dev Añade un comentario a un NFT.
     * @param tokenId ID del token.
     * @param text Texto del comentario.
     */
    function addComment(uint256 tokenId, string calldata text)
        public
        whenNotPaused
        notBlacklisted
        tokenExists(tokenId)
    {
        if (bytes(text).length == 0 || bytes(text).length > 280) revert InvalidInput();
        
        Comment memory newComment = Comment({
            commenter: msg.sender,
            text: text,
            timestamp: block.timestamp
        });
        
        _tokenComments[tokenId].push(newComment);
        
        emit CommentAdded(tokenId, msg.sender, text);
    }
    
    /**
     * @dev Permite a un usuario dar/quitar like a un NFT.
     * @param tokenId ID del token.
     * @param like true para dar like, false para quitar like.
     */
    function toggleLike(uint256 tokenId, bool like)
        public
        whenNotPaused
        notBlacklisted
        tokenExists(tokenId)
    {
        TokenLikes storage tokenLikes = _tokenLikes[tokenId];
        
        if (like && !tokenLikes.userLikes[msg.sender]) {
            tokenLikes.userLikes[msg.sender] = true;
            tokenLikes.count++;
            emit TokenLiked(tokenId, msg.sender, tokenLikes.count);
        } else if (!like && tokenLikes.userLikes[msg.sender]) {
            tokenLikes.userLikes[msg.sender] = false;
            tokenLikes.count--;
            emit TokenUnLiked(tokenId, msg.sender, tokenLikes.count);
        }
    }

    // Funciones de vista y gestión
    
    /**
     * @dev Obtiene los detalles de un NFT listado.
     * @param tokenId ID del token.
     * @return Los detalles del NFT listado.
     */
    function getListedToken(uint256 tokenId) 
        public 
        view 
        tokenExists(tokenId)
        returns (
            uint256, 
            address, 
            address, 
            uint256, 
            bool, 
            uint256, 
            string memory
        ) 
    {
        ListedToken storage token = _listedTokens[tokenId];
        return (
            token.tokenId,
            token.seller,
            token.owner,
            token.price,
            token.isForSale,
            token.listedTimestamp,
            token.category
        );
    }
    
    /**
     * @dev Obtiene los detalles de una oferta.
     * @param offerId ID de la oferta.
     * @return Los detalles de la oferta.
     */
    function getOffer(uint256 offerId) 
        public 
        view 
        returns (
            uint256, 
            uint256, 
            address, 
            uint256, 
            uint256, 
            bool
        ) 
    {
        Offer storage offer = _offers[offerId];
        return (
            offer.offerId,
            offer.tokenId,
            offer.buyer,
            offer.offerAmount,
            offer.expiresAt,
            offer.isActive
        );
    }
    
    /**
     * @dev Obtiene el número de likes de un token.
     * @param tokenId ID del token.
     * @return El número de likes.
     */
    function getLikesCount(uint256 tokenId) 
        public 
        view 
        tokenExists(tokenId)
        returns (uint256) 
    {
        return _tokenLikes[tokenId].count;
    }
    
    /**
     * @dev Verifica si un usuario ha dado like a un token.
     * @param tokenId ID del token.
     * @param user Dirección del usuario.
     * @return true si el usuario ha dado like, false en caso contrario.
     */
    function hasUserLiked(uint256 tokenId, address user) 
        public 
        view 
        tokenExists(tokenId)
        returns (bool) 
    {
        return _tokenLikes[tokenId].userLikes[user];
    }
    
    /**
     * @dev Obtiene la lista de comentarios de un token.
     * @param tokenId ID del token.
     * @param startIndex Índice de inicio para paginación.
     * @param count Número de comentarios a obtener.
     * @return Arreglos con información de los comentarios.
     */
    function getComments(uint256 tokenId, uint256 startIndex, uint256 count)
        public
        view
        tokenExists(tokenId)
        returns (
            address[] memory,
            string[] memory,
            uint256[] memory
        )
    {
        Comment[] storage comments = _tokenComments[tokenId];
        
        uint256 endIndex = startIndex + count;
        if (endIndex > comments.length) {
            endIndex = comments.length;
        }
        
        uint256 resultCount = endIndex - startIndex;
        
        address[] memory commenters = new address[](resultCount);
        string[] memory texts = new string[](resultCount);
        uint256[] memory timestamps = new uint256[](resultCount);
        
        for (uint256 i = 0; i < resultCount; i++) {
            Comment storage comment = comments[startIndex + i];
            commenters[i] = comment.commenter;
            texts[i] = comment.text;
            timestamps[i] = comment.timestamp;
        }
        
        return (commenters, texts, timestamps);
    }
    
    /**
     * @dev Obtiene la lista de tokens creados por un usuario.
     * @param creator Dirección del creador.
     * @return Array con los IDs de los tokens.
     */
    function getTokensByCreator(address creator)
        public
        view
        returns (uint256[] memory)
    {
        return _creatorTokensSet[creator].values();
    }

    // Funciones administrativas
    
    /**
     * @dev Permite al dueño de la plataforma cambiar la comisión.
     * @param newFeePercentage Nuevo porcentaje de comisión.
     */
    function setPlatformFee(uint256 newFeePercentage) 
        public 
        onlyRole(ADMIN_ROLE)
    {
        if (newFeePercentage > 10) revert InvalidInput(); // Límite del 10%
        platformFeePercentage = newFeePercentage;
    }
    
    /**
     * @dev Permite al admin establecer la dirección de la tesorería.
     * @param _treasury Nueva dirección de la tesorería.
     */
    function setPlatformTreasury(address _treasury)
        public
        onlyRole(ADMIN_ROLE)
    {
        if (_treasury == address(0)) revert InvalidInput();
        platformTreasury = _treasury;
    }

    /**
     * @dev Permite al dueño de la plataforma cambiar el royalty por defecto.
     * @param newRoyaltyPercentage Nuevo porcentaje de royalty (base 10000).
     */
    function setDefaultRoyalty(uint96 newRoyaltyPercentage)
        public
        onlyRole(ADMIN_ROLE)
    {
        if (newRoyaltyPercentage > 1000) revert RoyaltyTooHigh();
        defaultRoyaltyPercentage = newRoyaltyPercentage;
    }
    
    /**
     * @dev Permite al dueño de la plataforma retirar las comisiones acumuladas.
     */
    function withdrawPlatformFees() 
        public 
        onlyRole(ADMIN_ROLE)
        nonReentrant 
    {
        uint256 balance = address(this).balance;
        if (balance == 0) revert InvalidInput();
        
        (bool success, ) = payable(platformTreasury).call{value: balance}("");
        if (!success) revert TransferFailed();
    }
    
    /**
     * @dev Agrega una dirección a la lista negra.
     * @param user Dirección a añadir a la lista negra.
     */
    function blacklistAddress(address user)
        public
        onlyRole(MODERATOR_ROLE)
    {
        _blacklistedAddresses[user] = true;
        _blacklistedAddressesSet.add(user);
    }
    
    /**
     * @dev Remueve una dirección de la lista negra.
     * @param user Dirección a remover de la lista negra.
     */
    function removeFromBlacklist(address user)
        public
        onlyRole(ADMIN_ROLE)
    {
        _blacklistedAddresses[user] = false;
        _blacklistedAddressesSet.remove(user);
    }
    
    /**
     * @dev Registra una nueva categoría.
     * @param category Nombre de la categoría.
     */
    function registerCategory(string memory category)
        public
        onlyRole(MODERATOR_ROLE)
    {
        _registerCategory(category);
    }
    
    /**
     * @dev Pausa o despausa una sección específica del contrato.
     * @param section ID de la sección (0=listado, 1=compras, 2=ofertas, 3=creación).
     * @param paused Si la sección debe estar pausada.
     */
    function setSectionPaused(uint8 section, bool paused)
        public
        onlyRole(ADMIN_ROLE)
    {
        if (section > 3) revert InvalidInput();
        sectionPaused[section] = paused;
    }
    
    /**
     * @dev Pausa todo el contrato.
     */
    function pause() 
        public 
        onlyRole(ADMIN_ROLE) 
    {
        _pause();
    }
    
    /**
     * @dev Despausa todo el contrato.
     */
    function unpause() 
        public 
        onlyRole(ADMIN_ROLE) 
    {
        _unpause();
    }
    
    /**
     * @dev Recuperación de emergencia de ETH.
     * @param to Dirección a la que enviar los fondos.
     */
    function emergencyWithdraw(address payable to) 
        public 
        onlyRole(ADMIN_ROLE)
        nonReentrant
    {
        if (to == address(0)) revert InvalidInput();
        
        uint256 balance = address(this).balance;
        if (balance == 0) revert InvalidInput();
        
        emit EmergencyWithdrawal(to, balance);
        
        bool sent = _sendValue(to, balance);
        if (!sent) revert TransferFailed();
    }

    // Funciones internas auxiliares
    
    /**
     * @dev Registra una nueva categoría internamente.
     * @param category Nombre de la categoría.
     */
    function _registerCategory(string memory category) internal {
        if (bytes(category).length == 0) revert InvalidInput();
        
        bytes32 categoryHash = keccak256(abi.encodePacked(category));
        if (_registeredCategoriesHashed[categoryHash]) revert InvalidInput();
        
        _registeredCategoriesHashed[categoryHash] = true;
        emit CategoryRegistered(category);
    }
    
    /**
     * @dev Cancela todas las ofertas activas para un token, optimizado.
     * @param tokenId ID del token.
     */
    function _cancelAllOffersForToken(uint256 tokenId) internal {
        uint256[] memory activeOffers = _tokenActiveOffers[tokenId].values();
        
        for (uint256 i = 0; i < activeOffers.length; i++) {
            Offer storage offer = _offers[activeOffers[i]];
            // Solo se marcan como inactivas. El reembolso lo gestiona el usuario con cancelOffer.
            if (offer.isActive) {
                offer.isActive = false;
                emit OfferRejected(offer.offerId); // Se puede usar un evento genérico o uno nuevo
            }
        }
        
        // Limpiar todas las ofertas del set para este token
        while (_tokenActiveOffers[tokenId].length() > 0) {
            _tokenActiveOffers[tokenId].remove(_tokenActiveOffers[tokenId].at(0));
        }
    }

    /**
     * @dev Función auxiliar para enviar ETH de forma segura
     */
    function _sendValue(address payable recipient, uint256 amount) internal returns (bool) {
        (bool success, ) = recipient.call{value: amount}("");
        return success;
    }

    // Overrides requeridos por Solidity
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, ERC721Royalty, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) 
        internal 
        override(ERC721, ERC721URIStorage, ERC721Royalty) 
    {
        super._burn(tokenId);
    }

    /**
     * @dev Emite eventos para el minteo en lote para evitar stack too deep.
     * @param tokenIds Array de IDs de tokens minteados.
     * @param tokenURIValue URI de los tokens.
     * @param category Categoría de los tokens.
     */
    function _emitBatchMintEvents(
        uint256[] memory tokenIds,
        string memory tokenURIValue,
        string memory category
    ) internal {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            emit TokenMinted(tokenIds[i], msg.sender, tokenURIValue, category);
        }
    }
}