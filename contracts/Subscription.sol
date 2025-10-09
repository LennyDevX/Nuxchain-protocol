// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Subscription is ERC1155, Ownable {
    // IDs para cada tier de NFT
    uint256 public constant FREE_TIER = 0;
    uint256 public constant VIP_TIER = 1;
    uint256 public constant PREMIUM_TIER = 2;
    uint256 public constant SELECTED_TIER = 3;

    // Contrato del token POL (ERC20)
    IERC20 public polToken;

    // Precios para los tiers
    uint256 public vipPrice;
    uint256 public premiumPrice;

    // --- NUEVAS VARIABLES ---
    // Porcentaje de comisión por referido (e.g., 5 para 5%)
    uint256 public referralCommissionRate;
    // Porcentaje de descuento para upgrade de VIP a Premium (e.g., 10 para 10%)
    uint256 public vipToPremiumDiscountRate;

    // Duración de la suscripción premium (en segundos)
    uint256 public premiumDuration = 30 days;

    // Mapeo de direcciones a la fecha de expiración de su suscripción premium
    mapping(address => uint256) public premiumExpirations;

    // Mapeo de ID de token a su URI de metadatos
    mapping(uint256 => string) private _tokenURIs;

    event TierMinted(address indexed user, uint256 indexed tierId);
    event PremiumSubscribed(address indexed user, uint256 expiration);
    // --- NUEVO EVENTO ---
    event ReferralPaid(address indexed referrer, address indexed referee, uint256 commission);

    constructor(
        address _polTokenAddress,
        uint256 _initialVipPrice,
        uint256 _initialPremiumPrice,
        uint256 _initialReferralRate,
        uint256 _initialDiscountRate
    ) ERC1155("https://api.nuvos.com/creators/{id}") Ownable() {
        polToken = IERC20(_polTokenAddress);
        vipPrice = _initialVipPrice;
        premiumPrice = _initialPremiumPrice;
        referralCommissionRate = _initialReferralRate;
        vipToPremiumDiscountRate = _initialDiscountRate;
    }

    // --- Funciones para Usuarios ---

    function mintFreeTier() public {
        require(balanceOf(msg.sender, FREE_TIER) == 0, "Subscription: Ya tienes el tier gratuito.");
        _mint(msg.sender, FREE_TIER, 1, "");
        emit TierMinted(msg.sender, FREE_TIER);
    }

    function purchaseVipTier(address referrer) public {
        require(balanceOf(msg.sender, VIP_TIER) == 0, "Subscription: Ya eres miembro VIP.");
        
        uint256 price = vipPrice;
        require(polToken.allowance(msg.sender, address(this)) >= price, "Subscription: Revisa la aprobacion de POL.");

        // El contrato recibe el pago completo
        polToken.transferFrom(msg.sender, address(this), price);

        // Paga la comisión si hay un referente válido
        if (referrer != address(0) && referrer != msg.sender && referralCommissionRate > 0) {
            uint256 commission = (price * referralCommissionRate) / 100;
            if (commission > 0) {
                polToken.transfer(referrer, commission);
                emit ReferralPaid(referrer, msg.sender, commission);
            }
        }
        
        _mint(msg.sender, VIP_TIER, 1, "");
        emit TierMinted(msg.sender, VIP_TIER);
    }

    function subscribeToPremium(address referrer) public {
        uint256 price = premiumPrice;

        // Lógica de descuento por ser VIP en la primera suscripción
        bool isFirstSubscription = premiumExpirations[msg.sender] == 0;
        if (balanceOf(msg.sender, VIP_TIER) > 0 && isFirstSubscription && vipToPremiumDiscountRate > 0) {
            uint256 discount = (price * vipToPremiumDiscountRate) / 100;
            price -= discount;
        }

        require(polToken.allowance(msg.sender, address(this)) >= price, "Subscription: Revisa la aprobacion de POL.");

        // El contrato recibe el pago completo (con posible descuento)
        polToken.transferFrom(msg.sender, address(this), price);

        // Paga la comisión si hay un referente válido
        if (referrer != address(0) && referrer != msg.sender && referralCommissionRate > 0) {
            uint256 commission = (price * referralCommissionRate) / 100;
            if (commission > 0) {
                polToken.transfer(referrer, commission);
                emit ReferralPaid(referrer, msg.sender, commission);
            }
        }

        if (balanceOf(msg.sender, PREMIUM_TIER) == 0) {
            _mint(msg.sender, PREMIUM_TIER, 1, "");
            emit TierMinted(msg.sender, PREMIUM_TIER);
        }

        uint256 currentExpiration = premiumExpirations[msg.sender];
        uint256 newExpiration = (currentExpiration > block.timestamp ? currentExpiration : block.timestamp) + premiumDuration;
        premiumExpirations[msg.sender] = newExpiration;

        emit PremiumSubscribed(msg.sender, newExpiration);
    }

    function isPremiumActive(address user) public view returns (bool) {
        return premiumExpirations[user] > block.timestamp;
    }

    // --- Funciones de Administrador ---

    function grantSelectedTier(address creator) public onlyOwner {
        require(balanceOf(creator, SELECTED_TIER) == 0, "Subscription: El creador ya tiene este tier.");
        _mint(creator, SELECTED_TIER, 1, "");
        emit TierMinted(creator, SELECTED_TIER);
    }

    function setPrices(uint256 _vipPrice, uint256 _premiumPrice) public onlyOwner {
        vipPrice = _vipPrice;
        premiumPrice = _premiumPrice;
    }

    function setRates(uint256 _referralRate, uint256 _discountRate) public onlyOwner {
        require(_referralRate <= 100, "La comision no puede ser > 100%");
        require(_discountRate <= 100, "El descuento no puede ser > 100%");
        referralCommissionRate = _referralRate;
        vipToPremiumDiscountRate = _discountRate;
    }

    function setPremiumDuration(uint256 _durationInSeconds) public onlyOwner {
        premiumDuration = _durationInSeconds;
    }

    function withdrawTokens() public onlyOwner {
        uint256 balance = polToken.balanceOf(address(this));
        require(balance > 0, "Subscription: No hay tokens para retirar.");
        polToken.transfer(owner(), balance);
    }

    // --- Gestión de URI de Metadatos ---

    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenUri = _tokenURIs[tokenId];
        if (bytes(tokenUri).length > 0) {
            return tokenUri;
        }
        return super.uri(tokenId);
    }

    function setTokenURI(uint256 tokenId, string memory newUri) public onlyOwner {
        _tokenURIs[tokenId] = newUri;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _setURI(newBaseURI);
    }
}
