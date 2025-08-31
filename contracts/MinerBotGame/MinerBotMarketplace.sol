// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title MinerBotMarketplace
 * @dev Marketplace para trading de robots NFT y componentes
 * @author MinerBot Empire Team
 */
contract MinerBotMarketplace is ReentrancyGuard, Ownable, Pausable, IERC721Receiver {

    IERC721 public immutable minerBotNFT;
    IERC20 public immutable paymentToken;
    
    // Configuración del marketplace
    uint256 public constant MARKETPLACE_FEE = 250; // 2.5% fee
    uint256 public constant MINIMUM_PRICE = 1 * 10**18; // 1 MBT mínimo
    uint256 public constant MAXIMUM_PRICE = 1000000 * 10**18; // 1M MBT máximo
    uint32 public constant LISTING_DURATION = 30 days;
    
    // Tipos de listado
    enum ListingType {
        FixedPrice,
        Auction,
        Bundle
    }
    
    // Estado de listado
    enum ListingStatus {
        Active,
        Sold,
        Cancelled,
        Expired
    }
    
    // Estructura de listado
    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        uint256 startTime;
        uint256 endTime;
        ListingType listingType;
        ListingStatus status;
        uint256 highestBid;
        address highestBidder;
        bool isBundle;
        uint256[] bundleTokenIds;
    }
    
    // Estructura de oferta
    struct Offer {
        address buyer;
        uint256 amount;
        uint256 expiration;
        bool isActive;
    }
    
    // Estructura de subasta
    struct Auction {
        uint256 startingPrice;
        uint256 reservePrice;
        uint256 bidIncrement;
        uint32 duration;         // Duración en segundos (max ~136 años)
        bool hasReserve;
    }
    
    // Mapeos
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => Offer)) public offers;
    mapping(uint256 => address[]) public listingBidders;
    mapping(address => uint256[]) public userListings;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(uint256 => bool) public isTokenListed;
    
    // Variables de estado
    uint256 public nextListingId;
    uint256 public totalVolume;
    uint256 public totalFees;
    address public feeRecipient;
    
    // Eventos
    event ItemListed(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price,
        ListingType listingType
    );
    event ItemSold(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        address buyer,
        uint256 price
    );
    event BidPlaced(
        uint256 indexed listingId,
        address indexed bidder,
        uint256 amount
    );
    event OfferMade(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 amount
    );
    event OfferAccepted(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 amount
    );
    event ListingCancelled(uint256 indexed listingId);
    event AuctionEnded(uint256 indexed listingId, address winner, uint256 amount);
    
    constructor(
        address _minerBotNFT,
        address _paymentToken,
        address _feeRecipient
    ) Ownable() {
        minerBotNFT = IERC721(_minerBotNFT);
        paymentToken = IERC20(_paymentToken);
        feeRecipient = _feeRecipient;
    }
    
    /**
     * @dev Listar NFT a precio fijo
     */
    function listItem(
        uint256 _tokenId,
        uint256 _price
    ) external nonReentrant whenNotPaused {
        require(minerBotNFT.ownerOf(_tokenId) == msg.sender, "Not token owner");
        require(!isTokenListed[_tokenId], "Token already listed");
        require(_price >= MINIMUM_PRICE && _price <= MAXIMUM_PRICE, "Invalid price");
        
        // Transferir NFT al contrato
        minerBotNFT.safeTransferFrom(msg.sender, address(this), _tokenId);
        
        uint256 listingId = nextListingId++;
        
        listings[listingId] = Listing({
            tokenId: _tokenId,
            seller: msg.sender,
            price: _price,
            startTime: block.timestamp,
            endTime: block.timestamp + LISTING_DURATION,
            listingType: ListingType.FixedPrice,
            status: ListingStatus.Active,
            highestBid: 0,
            highestBidder: address(0),
            isBundle: false,
            bundleTokenIds: new uint256[](0)
        });
        
        isTokenListed[_tokenId] = true;
        userListings[msg.sender].push(listingId);
        
        emit ItemListed(listingId, _tokenId, msg.sender, _price, ListingType.FixedPrice);
    }
    
    /**
     * @dev Crear subasta
     */
    function createAuction(
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _reservePrice,
        uint32 _duration
    ) external nonReentrant whenNotPaused {
        require(minerBotNFT.ownerOf(_tokenId) == msg.sender, "Not token owner");
        require(!isTokenListed[_tokenId], "Token already listed");
        require(_startingPrice >= MINIMUM_PRICE, "Starting price too low");
        require(_duration >= 1 hours && _duration <= 7 days, "Invalid duration");
        
        // Transferir NFT al contrato
        minerBotNFT.safeTransferFrom(msg.sender, address(this), _tokenId);
        
        uint256 listingId = nextListingId++;
        
        listings[listingId] = Listing({
            tokenId: _tokenId,
            seller: msg.sender,
            price: _startingPrice,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            listingType: ListingType.Auction,
            status: ListingStatus.Active,
            highestBid: 0,
            highestBidder: address(0),
            isBundle: false,
            bundleTokenIds: new uint256[](0)
        });
        
        auctions[listingId] = Auction({
            startingPrice: _startingPrice,
            reservePrice: _reservePrice,
            bidIncrement: _startingPrice / 20, // 5% incremento mínimo
            duration: _duration,
            hasReserve: _reservePrice > 0
        });
        
        isTokenListed[_tokenId] = true;
        userListings[msg.sender].push(listingId);
        
        emit ItemListed(listingId, _tokenId, msg.sender, _startingPrice, ListingType.Auction);
    }
    
    /**
     * @dev Comprar NFT a precio fijo
     */
    function buyItem(uint256 _listingId) external nonReentrant whenNotPaused {
        Listing storage listing = listings[_listingId];
        require(listing.status == ListingStatus.Active, "Listing not active");
        require(listing.listingType == ListingType.FixedPrice, "Not fixed price listing");
        require(block.timestamp <= listing.endTime, "Listing expired");
        require(msg.sender != listing.seller, "Cannot buy own item");
        
        uint256 totalPrice = listing.price;
        uint256 fee = totalPrice * MARKETPLACE_FEE / 10000;
        uint256 sellerAmount = totalPrice - fee;
        
        // Transferir tokens
        require(paymentToken.transferFrom(msg.sender, listing.seller, sellerAmount), "Payment failed");
        require(paymentToken.transferFrom(msg.sender, feeRecipient, fee), "Fee payment failed");
        
        // Transferir NFT
        minerBotNFT.safeTransferFrom(address(this), msg.sender, listing.tokenId);
        
        // Actualizar estado
        listing.status = ListingStatus.Sold;
        isTokenListed[listing.tokenId] = false;
        totalVolume += totalPrice;
        totalFees += fee;
        
        emit ItemSold(_listingId, listing.tokenId, listing.seller, msg.sender, totalPrice);
    }
    
    /**
     * @dev Hacer oferta en subasta
     */
    function placeBid(uint256 _listingId, uint256 _bidAmount) external nonReentrant whenNotPaused {
        Listing storage listing = listings[_listingId];
        require(listing.status == ListingStatus.Active, "Listing not active");
        require(listing.listingType == ListingType.Auction, "Not auction listing");
        require(block.timestamp <= listing.endTime, "Auction ended");
        require(msg.sender != listing.seller, "Cannot bid on own auction");
        
        Auction storage auction = auctions[_listingId];
        
        // Verificar monto mínimo
        uint256 minimumBid = listing.highestBid > 0 
            ? listing.highestBid + auction.bidIncrement
            : auction.startingPrice;
        require(_bidAmount >= minimumBid, "Bid too low");
        
        // Devolver oferta anterior
        if (listing.highestBidder != address(0)) {
            pendingWithdrawals[listing.highestBidder] += listing.highestBid;
        }
        
        // Transferir nueva oferta
        require(paymentToken.transferFrom(msg.sender, address(this), _bidAmount), "Bid transfer failed");
        
        // Actualizar oferta más alta
        listing.highestBid = _bidAmount;
        listing.highestBidder = msg.sender;
        listingBidders[_listingId].push(msg.sender);
        
        // Extender subasta si queda poco tiempo
        if (listing.endTime - block.timestamp < 15 minutes) {
            listing.endTime = block.timestamp + 15 minutes;
        }
        
        emit BidPlaced(_listingId, msg.sender, _bidAmount);
    }
    
    /**
     * @dev Finalizar subasta
     */
    function finalizeAuction(uint256 _listingId) external nonReentrant {
        Listing storage listing = listings[_listingId];
        require(listing.status == ListingStatus.Active, "Listing not active");
        require(listing.listingType == ListingType.Auction, "Not auction");
        require(block.timestamp > listing.endTime, "Auction still active");
        
        Auction storage auction = auctions[_listingId];
        
        if (listing.highestBidder != address(0) && 
            (!auction.hasReserve || listing.highestBid >= auction.reservePrice)) {
            
            // Subasta exitosa
            uint256 fee = listing.highestBid * MARKETPLACE_FEE / 10000;
            uint256 sellerAmount = listing.highestBid - fee;
            
            // Transferir pagos
            require(paymentToken.transfer(listing.seller, sellerAmount), "Payment failed");
            require(paymentToken.transfer(feeRecipient, fee), "Fee payment failed");
            
            // Transferir NFT
            minerBotNFT.safeTransferFrom(address(this), listing.highestBidder, listing.tokenId);
            
            listing.status = ListingStatus.Sold;
            totalVolume += listing.highestBid;
            totalFees += fee;
            
            emit ItemSold(_listingId, listing.tokenId, listing.seller, listing.highestBidder, listing.highestBid);
            emit AuctionEnded(_listingId, listing.highestBidder, listing.highestBid);
        } else {
            // Subasta fallida - devolver NFT
            minerBotNFT.safeTransferFrom(address(this), listing.seller, listing.tokenId);
            
            // Devolver oferta más alta si existe
            if (listing.highestBidder != address(0)) {
                pendingWithdrawals[listing.highestBidder] += listing.highestBid;
            }
            
            listing.status = ListingStatus.Expired;
            emit AuctionEnded(_listingId, address(0), 0);
        }
        
        isTokenListed[listing.tokenId] = false;
    }
    
    /**
     * @dev Hacer oferta directa en NFT
     */
    function makeOffer(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _expiration
    ) external nonReentrant whenNotPaused {
        require(minerBotNFT.ownerOf(_tokenId) != msg.sender, "Cannot offer on own token");
        require(_amount >= MINIMUM_PRICE, "Offer too low");
        require(_expiration > block.timestamp, "Invalid expiration");
        require(_expiration <= block.timestamp + 30 days, "Expiration too far");
        
        // Cancelar oferta anterior si existe
        if (offers[_tokenId][msg.sender].isActive) {
            pendingWithdrawals[msg.sender] += offers[_tokenId][msg.sender].amount;
        }
        
        // Transferir tokens para la oferta
        require(paymentToken.transferFrom(msg.sender, address(this), _amount), "Offer transfer failed");
        
        offers[_tokenId][msg.sender] = Offer({
            buyer: msg.sender,
            amount: _amount,
            expiration: _expiration,
            isActive: true
        });
        
        emit OfferMade(_tokenId, msg.sender, _amount);
    }
    
    /**
     * @dev Aceptar oferta
     */
    function acceptOffer(uint256 _tokenId, address _buyer) external nonReentrant whenNotPaused {
        require(minerBotNFT.ownerOf(_tokenId) == msg.sender, "Not token owner");
        require(!isTokenListed[_tokenId], "Token is listed");
        
        Offer storage offer = offers[_tokenId][_buyer];
        require(offer.isActive, "Offer not active");
        require(block.timestamp <= offer.expiration, "Offer expired");
        
        uint256 fee = offer.amount * MARKETPLACE_FEE / 10000;
        uint256 sellerAmount = offer.amount - fee;
        
        // Transferir pagos
        require(paymentToken.transfer(msg.sender, sellerAmount), "Payment failed");
        require(paymentToken.transfer(feeRecipient, fee), "Fee payment failed");
        
        // Transferir NFT
        minerBotNFT.safeTransferFrom(msg.sender, _buyer, _tokenId);
        
        // Actualizar estado
        offer.isActive = false;
        totalVolume += offer.amount;
        totalFees += fee;
        
        emit OfferAccepted(_tokenId, msg.sender, _buyer, offer.amount);
    }
    
    /**
     * @dev Cancelar listado
     */
    function cancelListing(uint256 _listingId) external nonReentrant {
        Listing storage listing = listings[_listingId];
        require(listing.seller == msg.sender || msg.sender == owner(), "Not authorized");
        require(listing.status == ListingStatus.Active, "Listing not active");
        
        // Devolver NFT
        minerBotNFT.safeTransferFrom(address(this), listing.seller, listing.tokenId);
        
        // Devolver ofertas en subastas
        if (listing.listingType == ListingType.Auction && listing.highestBidder != address(0)) {
            pendingWithdrawals[listing.highestBidder] += listing.highestBid;
        }
        
        listing.status = ListingStatus.Cancelled;
        isTokenListed[listing.tokenId] = false;
        
        emit ListingCancelled(_listingId);
    }
    
    /**
     * @dev Retirar fondos pendientes
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        pendingWithdrawals[msg.sender] = 0;
        require(paymentToken.transfer(msg.sender, amount), "Withdrawal failed");
    }
    
    /**
     * @dev Obtener listados activos
     */
    function getActiveListings(uint256 _offset, uint256 _limit) external view returns (uint256[] memory) {
        uint256[] memory activeListings = new uint256[](_limit);
        uint256 count = 0;
        uint256 current = 0;
        
        for (uint256 i = 0; i < nextListingId && count < _limit; i++) {
            if (listings[i].status == ListingStatus.Active) {
                if (current >= _offset) {
                    activeListings[count] = i;
                    count++;
                }
                current++;
            }
        }
        
        // Redimensionar array
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeListings[i];
        }
        
        return result;
    }
    
    /**
     * @dev Obtener listados de usuario
     */
    function getUserListings(address _user) external view returns (uint256[] memory) {
        return userListings[_user];
    }
    
    /**
     * @dev Funciones de administración
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid address");
        feeRecipient = _feeRecipient;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Implementación de IERC721Receiver
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
    
    /**
     * @dev Retirar tokens de emergencia
     */
    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }
}