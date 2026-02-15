// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ReferralSystem
 * @dev Sistema de referidos optimizado para wallet-only (sin login convencional)
 * - Cada wallet genera un código referido único permanente
 * - Código se comparte para invitar otros usuarios
 * - Descuento en PRIMERA compra de NFT (buyer)
 * - XP para ambos: referrer cuando referido hace PRIMERA venta, buyer en primera compra
 * - Integración con GameifiedMarketplaceCore y LevelingSystem
 */
contract ReferralSystem is AccessControl, Initializable, UUPSUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    // XP Rewards
    uint256 public constant REFERRER_FIRST_SALE_XP = 30;     // XP cuando referido vende su 1er NFT
    uint256 public constant BUYER_FIRST_PURCHASE_XP = 25;    // XP para buyer en 1era compra con referral
    
    // Descuento
    uint256 public constant FIRST_PURCHASE_DISCOUNT_PERCENTAGE = 10; // 10% descuento en 1era compra
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    // Mapeos de referidos
    mapping(bytes32 => address) public referralCodeOwner;  // code → wallet address
    mapping(address => bytes32) public referralCode;       // wallet → su código único
    mapping(address => address) public referrer;           // buyer → referrer wallet
    mapping(address => address[]) public referrals;        // referrer → lista de buyers referidos
    mapping(address => bool) public hasReferrer;           // buyer → tiene referrer asignado
    
    // Seguimiento de compras y ventas
    mapping(address => bool) public hasMadeFirstPurchase;  // buyer → ha comprado con descuento referral
    mapping(address => bool) public hasMadeFirstSale;      // seller → ha vendido su 1er NFT
    mapping(address => uint256) public successfulReferrals; // referrer → count de referrals exitosos
    
    // Estadísticas de XP
    mapping(address => uint256) public referralXPEarned;   // referrer → total XP earned
    
    // Direcciones de contratos relacionados
    address public levelingSystemAddress;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    event ReferralCodeGenerated(address indexed wallet, bytes32 indexed code);
    event ReferralRegistered(address indexed buyer, address indexed referrer, bytes32 indexed code);
    event FirstPurchaseWithReferral(address indexed buyer, address indexed referrer, uint256 discount, uint256 xpAwarded);
    event FirstSaleByReferral(address indexed referrer, address indexed referredSeller, uint256 xpAwarded);
    event ReferrerXPEarned(address indexed referrer, uint256 xpAmount, string reason);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address platformAdmin) public initializer {
        require(platformAdmin != address(0), "Invalid admin");
        _grantRole(DEFAULT_ADMIN_ROLE, platformAdmin);
        _grantRole(ADMIN_ROLE, platformAdmin);
        _grantRole(UPGRADER_ROLE, platformAdmin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @dev Genera código referido único para una wallet (sin login)
     * - Llamado por el usuario la primera vez que conecta su wallet
     * - El código es permanente e inmutable
     * - Se puede reutilizar ilimitadamente para invitar otros usuarios
     */
    function generateReferralCode(address wallet) external returns (bytes32) {
        require(wallet != address(0), "Invalid wallet");
        require(referralCode[wallet] == bytes32(0), "Wallet already has code");

        // Generar código único: hash(wallet + blockhash)
        bytes32 code = keccak256(abi.encodePacked(wallet, blockhash(block.number - 1), block.timestamp));
        
        // Validar que el código sea único (extremadamente improbable colisión)
        require(referralCodeOwner[code] == address(0), "Code collision");
        
        // Almacenar mapeos bidireccionales
        referralCodeOwner[code] = wallet;
        referralCode[wallet] = code;

        emit ReferralCodeGenerated(wallet, code);
        return code;
    }

    /**
     * @dev Registra un buyer (referido) con código de referrer
     * - Debe ser llamado por GameifiedMarketplaceCore antes de PRIMERA compra
     * - One-time: un usuario solo puede tener UN referrer
     * - Sin contrato: usado cuando buyer clicea enlace de referral + conecta wallet
     */
    function registerWithReferralCode(address buyer, bytes32 code) 
        external 
        onlyRole(MARKETPLACE_ROLE) 
        returns (bool) 
    {
        require(buyer != address(0), "Invalid buyer");
        require(code != bytes32(0), "Invalid code");
        require(!hasReferrer[buyer], "Buyer already registered with referrer");
        require(isValidReferralCode(code), "Invalid/expired referral code");
        
        address referrerAddr = referralCodeOwner[code];
        require(referrerAddr != buyer, "Cannot register with own code");
        require(referrerAddr != address(0), "Referrer wallet not found");

        // Establecer relación de referido
        referrer[buyer] = referrerAddr;
        hasReferrer[buyer] = true;
        referrals[referrerAddr].push(buyer);

        emit ReferralRegistered(buyer, referrerAddr, code);
        return true;
    }

    /**
     * @dev Procesa la PRIMERA COMPRA con descuento referral
     * - Retorna descuento en POL para aplicar en buyToken()
     * - Solo aplica si buyer tiene referrer y es su 1era compra
     * - Otorga XP a buyer
     * - IMPORTANTE: Debe ser llamado desde GameifiedMarketplaceCore.buyToken()
     */
    function processFirstPurchaseDiscount(address buyer, uint256 nftPrice) 
        external 
        onlyRole(MARKETPLACE_ROLE) 
        returns (uint256 discountAmount) 
    {
        require(buyer != address(0), "Invalid buyer");
        require(nftPrice > 0, "Invalid price");
        
        // Validar que buyer tiene referrer y no ha comprado antes con descuento
        if (!hasReferrer[buyer] || hasMadeFirstPurchase[buyer]) {
            return 0; // Sin descuento
        }

        // Calcular descuento (10% de precio)
        discountAmount = (nftPrice * FIRST_PURCHASE_DISCOUNT_PERCENTAGE) / 100;
        
        // Marcar que buyer ya hizo su 1era compra referida
        hasMadeFirstPurchase[buyer] = true;
        
        // Otorgar XP a buyer
        // Nota: El contrato debe tener interfaz ILevelingSystem para llamar updateUserXP()
        
        emit FirstPurchaseWithReferral(buyer, referrer[buyer], discountAmount, BUYER_FIRST_PURCHASE_XP);
        return discountAmount;
    }

    /**
     * @dev Procesa la PRIMERA VENTA del referido
     * - Llamado desde GameifiedMarketplaceCore cuando referido vende su 1er NFT
     * - Otorga XP al referrer
     * - Incrementa contador de referrals exitosos
     */
    function processFirstSaleByReferral(address seller) 
        external 
        onlyRole(MARKETPLACE_ROLE) 
        returns (bool) 
    {
        require(seller != address(0), "Invalid seller");
        
        // Solo procesar si seller tiene referrer y no ha vendido antes
        if (!hasReferrer[seller] || hasMadeFirstSale[seller]) {
            return false;
        }

        address referrerAddr = referrer[seller];
        
        // Marcar que seller hizo su 1era venta
        hasMadeFirstSale[seller] = true;
        
        // Incrementar contador de referrals exitosos
        successfulReferrals[referrerAddr]++;
        referralXPEarned[referrerAddr] += REFERRER_FIRST_SALE_XP;

        emit FirstSaleByReferral(referrerAddr, seller, REFERRER_FIRST_SALE_XP);
        emit ReferrerXPEarned(referrerAddr, REFERRER_FIRST_SALE_XP, "REFERRAL_FIRST_SALE");
        
        return true;
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // GETTER FUNCTIONS (Sin roles, públicas)
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Obtener el código referido de una wallet
     */
    function getReferralCode(address wallet) external view returns (bytes32) {
        return referralCode[wallet];
    }

    /**
     * @dev Validar si un código de referral es válido
     */
    function isValidReferralCode(bytes32 code) public view returns (bool) {
        return referralCodeOwner[code] != address(0);
    }

    /**
     * @dev Obtener referrer de un buyer
     */
    function getReferrer(address buyer) external view returns (address) {
        return referrer[buyer];
    }

    /**
     * @dev Obtener lista de wallets referidas por un referrer
     */
    function getReferralsList(address referrerAddr) external view returns (address[] memory) {
        return referrals[referrerAddr];
    }

    /**
     * @dev Obtener estadísticas completas de referral para un referrer
     */
    function getReferrerStats(address referrerAddr) external view returns (
        uint256 totalReferrals,
        uint256 successfulReferrals_,
        uint256 totalXPEarned
    ) {
        return (
            referrals[referrerAddr].length,
            successfulReferrals[referrerAddr],
            referralXPEarned[referrerAddr]
        );
    }

    /**
     * @dev Obtener estado de compra/venta referida de un usuario
     */
    function getUserReferralStatus(address user) external view returns (
        address userReferrer,
        bool hasPurchased,
        bool hasSold
    ) {
        return (
            referrer[user],
            hasMadeFirstPurchase[user],
            hasMadeFirstSale[user]
        );
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Establecer dirección del LevelingSystem para otorgar XP
     */
    function setLevelingSystem(address _levelingSystem) external onlyRole(ADMIN_ROLE) {
        require(_levelingSystem != address(0), "Invalid address");
        levelingSystemAddress = _levelingSystem;
    }

    /**
     * @dev Permitir MARKETPLACE_ROLE a un contrato (GameifiedMarketplaceCore)
     */
    function grantMarketplaceRole(address marketplace) external onlyRole(ADMIN_ROLE) {
        require(marketplace != address(0), "Invalid address");
        _grantRole(MARKETPLACE_ROLE, marketplace);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // DASHBOARD / ANALYTICS VIEW FUNCTIONS (Deprecated, mantener para compatibilidad)
    // ════════════════════════════════════════════════════════════════════════════════════════

    function getReferralSystemStats() external pure returns (
        uint256 totalReferrals,
        uint256 totalUsers,
        uint256 totalXPEarned,
        uint256 averageReferralsPerUser,
        uint256 conversionRate
    ) {
        totalReferrals = 0;
        totalUsers = 0;
        totalXPEarned = 0;
        averageReferralsPerUser = 0;
        conversionRate = 0;
    }

    function getTopReferrers(uint256 _limit) external pure returns (
        address[] memory referrers,
        uint256[] memory referralCounts,
        uint256[] memory xpEarned
    ) {
        referrers = new address[](_limit);
        referralCounts = new uint256[](_limit);
        xpEarned = new uint256[](_limit);
    }

    function getUserReferralNetwork(address _user) external view returns (
        uint256 directReferrals,
        uint256 totalXPFromReferrals,
        address[] memory referralAddresses,
        bool[] memory activeStatus
    ) {
        directReferrals = referrals[_user].length;
        totalXPFromReferrals = referralXPEarned[_user];
        referralAddresses = referrals[_user];
        
        activeStatus = new bool[](referralAddresses.length);
        for (uint256 i = 0; i < referralAddresses.length; i++) {
            activeStatus[i] = !hasMadeFirstPurchase[referralAddresses[i]];
        }
    }

    function getReferralActivity() external pure returns (
        uint256 last24hReferrals,
        uint256 last7dReferrals,
        uint256 last30dReferrals,
        uint256 trendPercentage
    ) {
        last24hReferrals = 0;
        last7dReferrals = 0;
        last30dReferrals = 0;
        trendPercentage = 0;
    }

    function getReferralConversionMetrics() external pure returns (
        uint256 codesGenerated,
        uint256 codesUsed,
        uint256 conversionRate,
        uint256 averageTimeToConvert
    ) {
        codesGenerated = 0;
        codesUsed = 0;
        conversionRate = 0;
        averageTimeToConvert = 0;
    }

    /// @notice Get referral statistics for a user
    /// @param user The address to query
    /// @return totalReferrals Number of users referred
    /// @return xpEarned Total XP earned from referrals
    /// @return successfulCount Number of successful referrals
    function getUserReferralStats(address user) external view returns (
        uint256 totalReferrals,
        uint256 xpEarned,
        uint256 successfulCount
    ) {
        totalReferrals = referrals[user].length;
        xpEarned = referralXPEarned[user];
        successfulCount = successfulReferrals[user];
    }

    /// @notice Get the referrer of a user
    /// @param user The address to query
    /// @return The address of the referrer, or address(0) if none
    function getUserReferrer(address user) external view returns (address) {
        return referrer[user];
    }

    /// @notice Check if a user has a referrer
    /// @param user The address to query
    /// @return True if the user has a referrer
    function userHasReferrer(address user) external view returns (bool) {
        return hasReferrer[user];
    }
}
