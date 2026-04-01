// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface INuxTapAgentMarketTreasury {
    function depositRevenue(string calldata revenueType) external payable;
}

interface INuxTapAgentMarketRegistry {
    function registeredNFTContracts(address nftContract) external view returns (bool);
}

interface INuxTapMarketNFT is IERC721 {
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

contract NuxTapAgentMarketplace is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IERC721Receiver
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
        uint256 createdAt;
    }

    address public treasury;
    address public agentRegistry;
    uint256 public platformFeeBps;
    uint256 public listingCounter;

    mapping(uint256 => Listing) public listings;
    mapping(address => mapping(uint256 => uint256)) public activeListingIdByToken;
    mapping(address => bool) public supportedNFTContracts;

    event TreasuryUpdated(address indexed treasury);
    event AgentRegistryUpdated(address indexed agentRegistry);
    event PlatformFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event SupportedNFTContractUpdated(address indexed nftContract, bool supported);
    event AgentListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event AgentListingCancelled(uint256 indexed listingId);
    event AgentListingUpdated(uint256 indexed listingId, uint256 oldPrice, uint256 newPrice);
    event AgentSold(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed nftContract,
        uint256 tokenId,
        uint256 salePrice,
        uint256 sellerProceeds,
        uint256 platformFee,
        uint256 royaltyAmount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin_, address treasury_, address agentRegistry_) external initializer {
        require(admin_ != address(0), "NuxTapAgentMarketplace: invalid admin");
        require(treasury_ != address(0), "NuxTapAgentMarketplace: invalid treasury");

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        treasury = treasury_;
        agentRegistry = agentRegistry_;
        platformFeeBps = 500;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setTreasury(address treasury_) external onlyRole(ADMIN_ROLE) {
        require(treasury_ != address(0), "NuxTapAgentMarketplace: invalid treasury");
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    function setAgentRegistry(address agentRegistry_) external onlyRole(ADMIN_ROLE) {
        agentRegistry = agentRegistry_;
        emit AgentRegistryUpdated(agentRegistry_);
    }

    function setPlatformFeeBps(uint256 newFeeBps) external onlyRole(ADMIN_ROLE) {
        require(newFeeBps <= 1_500, "NuxTapAgentMarketplace: fee too high");
        emit PlatformFeeUpdated(platformFeeBps, newFeeBps);
        platformFeeBps = newFeeBps;
    }

    function setSupportedNFTContract(address nftContract, bool supported) external onlyRole(ADMIN_ROLE) {
        require(nftContract != address(0), "NuxTapAgentMarketplace: invalid NFT contract");
        supportedNFTContracts[nftContract] = supported;
        emit SupportedNFTContractUpdated(nftContract, supported);
    }

    function listAgent(address nftContract, uint256 tokenId, uint256 price) external whenNotPaused nonReentrant returns (uint256 listingId) {
        require(price > 0, "NuxTapAgentMarketplace: invalid price");
        require(_isSupportedAgentContract(nftContract), "NuxTapAgentMarketplace: unsupported NFT contract");
        require(activeListingIdByToken[nftContract][tokenId] == 0, "NuxTapAgentMarketplace: already listed");
        require(INuxTapMarketNFT(nftContract).ownerOf(tokenId) == msg.sender, "NuxTapAgentMarketplace: not token owner");
        require(_isMarketplaceApproved(nftContract, tokenId, msg.sender), "NuxTapAgentMarketplace: marketplace not approved");

        listingCounter++;
        listingId = listingCounter;

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true,
            createdAt: block.timestamp
        });
        activeListingIdByToken[nftContract][tokenId] = listingId;

        emit AgentListed(listingId, msg.sender, nftContract, tokenId, price);
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "NuxTapAgentMarketplace: inactive listing");
        require(listing.seller == msg.sender || hasRole(ADMIN_ROLE, msg.sender), "NuxTapAgentMarketplace: not authorized");

        listing.active = false;
        delete activeListingIdByToken[listing.nftContract][listing.tokenId];

        emit AgentListingCancelled(listingId);
    }

    function updateListingPrice(uint256 listingId, uint256 newPrice) external {
        Listing storage listing = listings[listingId];
        require(listing.active, "NuxTapAgentMarketplace: inactive listing");
        require(listing.seller == msg.sender, "NuxTapAgentMarketplace: not seller");
        require(newPrice > 0, "NuxTapAgentMarketplace: invalid price");

        uint256 previousPrice = listing.price;
        listing.price = newPrice;

        emit AgentListingUpdated(listingId, previousPrice, newPrice);
    }

    function buyAgent(uint256 listingId) external payable whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "NuxTapAgentMarketplace: inactive listing");
        require(msg.value == listing.price, "NuxTapAgentMarketplace: incorrect payment");
        require(INuxTapMarketNFT(listing.nftContract).ownerOf(listing.tokenId) == listing.seller, "NuxTapAgentMarketplace: seller no longer owns token");
        require(_isMarketplaceApproved(listing.nftContract, listing.tokenId, listing.seller), "NuxTapAgentMarketplace: marketplace not approved");

        listing.active = false;
        delete activeListingIdByToken[listing.nftContract][listing.tokenId];

        uint256 platformFee = (msg.value * platformFeeBps) / 10_000;
        (address royaltyRecipient, uint256 royaltyAmount) = _royaltyInfo(listing.nftContract, listing.tokenId, msg.value);
        uint256 sellerProceeds = msg.value - platformFee - royaltyAmount;

        INuxTapMarketNFT(listing.nftContract).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);

        if (sellerProceeds > 0) {
            (bool sellerOk, ) = payable(listing.seller).call{value: sellerProceeds}("");
            require(sellerOk, "NuxTapAgentMarketplace: seller payment failed");
        }

        if (royaltyAmount > 0 && royaltyRecipient != address(0)) {
            (bool royaltyOk, ) = payable(royaltyRecipient).call{value: royaltyAmount}("");
            require(royaltyOk, "NuxTapAgentMarketplace: royalty payment failed");
        }

        if (platformFee > 0) {
            INuxTapAgentMarketTreasury(treasury).depositRevenue{value: platformFee}("nuxtap_agent_marketplace_sale");
        }

        emit AgentSold(
            listingId,
            msg.sender,
            listing.nftContract,
            listing.tokenId,
            msg.value,
            sellerProceeds,
            platformFee,
            royaltyAmount
        );
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _isSupportedAgentContract(address nftContract) internal view returns (bool) {
        if (supportedNFTContracts[nftContract]) {
            return true;
        }

        if (agentRegistry == address(0)) {
            return false;
        }

        try INuxTapAgentMarketRegistry(agentRegistry).registeredNFTContracts(nftContract) returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    function _isMarketplaceApproved(address nftContract, uint256 tokenId, address owner_) internal view returns (bool) {
        return
            INuxTapMarketNFT(nftContract).getApproved(tokenId) == address(this) ||
            INuxTapMarketNFT(nftContract).isApprovedForAll(owner_, address(this));
    }

    function _royaltyInfo(address nftContract, uint256 tokenId, uint256 salePrice) internal view returns (address recipient, uint256 amount) {
        try IERC2981(nftContract).royaltyInfo(tokenId, salePrice) returns (address royaltyRecipient, uint256 royaltyAmount) {
            return (royaltyRecipient, royaltyAmount);
        } catch {
            return (address(0), 0);
        }
    }

    uint256[50] private __gap;

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}