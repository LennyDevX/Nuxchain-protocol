// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface INuxTapStoreTreasury {
    function depositRevenue(string calldata revenueType) external payable;
}

contract NuxTapItemStore is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IERC721Receiver
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

    enum ItemKind {
        NONE,
        AUTO_TAP,
        BOOSTER,
        WITHDRAW_PASS,
        AGENT_NFT
    }

    struct ItemConfig {
        ItemKind kind;
        uint256 price;
        uint256 value;
        uint256 duration;
        uint256 stock;
        bool active;
        bool soulbound;
        address nftContract;
    }

    address public treasury;
    mapping(uint256 => ItemConfig) public itemConfigs;
    mapping(uint256 => uint256[]) private _agentInventory;

    event TreasuryUpdated(address indexed treasury);
    event ItemConfigured(
        uint256 indexed itemId,
        ItemKind kind,
        uint256 price,
        uint256 value,
        uint256 duration,
        uint256 stock,
        bool active,
        bool soulbound,
        address nftContract
    );
    event ItemPurchased(address indexed buyer, uint256 indexed itemId, uint256 quantity, uint256 totalCost);
    event AgentInventoryDeposited(uint256 indexed itemId, uint256 indexed tokenId);
    event ItemConsumed(address indexed account, uint256 indexed itemId, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin_, address treasury_, string calldata baseUri_) external initializer {
        require(admin_ != address(0), "NuxTapItemStore: invalid admin");
        require(treasury_ != address(0), "NuxTapItemStore: invalid treasury");

        __ERC1155_init(baseUri_);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        treasury = treasury_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(GAME_ROLE, admin_);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setTreasury(address treasury_) external onlyRole(ADMIN_ROLE) {
        require(treasury_ != address(0), "NuxTapItemStore: invalid treasury");
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    function grantGameRole(address game_) external onlyRole(ADMIN_ROLE) {
        _grantRole(GAME_ROLE, game_);
    }

    function configureItem(
        uint256 itemId,
        ItemKind kind,
        uint256 price,
        uint256 value,
        uint256 duration,
        uint256 stock,
        bool active,
        bool soulbound,
        address nftContract
    ) external onlyRole(ADMIN_ROLE) {
        if (kind == ItemKind.AGENT_NFT) {
            require(nftContract != address(0), "NuxTapItemStore: invalid NFT contract");
        }

        itemConfigs[itemId] = ItemConfig({
            kind: kind,
            price: price,
            value: value,
            duration: duration,
            stock: stock,
            active: active,
            soulbound: soulbound,
            nftContract: nftContract
        });

        emit ItemConfigured(itemId, kind, price, value, duration, stock, active, soulbound, nftContract);
    }

    function depositAgentInventory(uint256 itemId, uint256 tokenId) external onlyRole(ADMIN_ROLE) {
        ItemConfig storage config = itemConfigs[itemId];
        require(config.kind == ItemKind.AGENT_NFT, "NuxTapItemStore: not agent item");
        IERC721(config.nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        _agentInventory[itemId].push(tokenId);
        config.stock = _agentInventory[itemId].length;
        emit AgentInventoryDeposited(itemId, tokenId);
    }

    function purchaseItem(uint256 itemId, uint256 quantity) external payable whenNotPaused nonReentrant {
        ItemConfig storage config = itemConfigs[itemId];
        require(config.active, "NuxTapItemStore: inactive item");
        require(quantity > 0, "NuxTapItemStore: invalid quantity");

        if (config.kind == ItemKind.AGENT_NFT) {
            require(quantity == 1, "NuxTapItemStore: invalid quantity");
            require(_agentInventory[itemId].length > 0, "NuxTapItemStore: no inventory");
        } else if (config.stock > 0) {
            require(quantity <= config.stock, "NuxTapItemStore: insufficient stock");
        }

        uint256 totalCost = config.price * quantity;
        require(msg.value == totalCost, "NuxTapItemStore: incorrect payment");

        INuxTapStoreTreasury(treasury).depositRevenue{value: msg.value}("nuxtap_store_sale");

        if (config.kind == ItemKind.AGENT_NFT) {
            uint256 tokenId = _popAgentInventory(itemId);
            config.stock = _agentInventory[itemId].length;
            IERC721(config.nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        } else {
            if (config.stock > 0) {
                config.stock -= quantity;
            }
            _mint(msg.sender, itemId, quantity, "");
        }

        emit ItemPurchased(msg.sender, itemId, quantity, totalCost);
    }

    function consumeItem(address account, uint256 itemId, uint256 amount) external onlyRole(GAME_ROLE) {
        _burn(account, itemId, amount);
        emit ItemConsumed(account, itemId, amount);
    }

    function getItemConfig(uint256 itemId)
        external
        view
        returns (uint8 kind, uint256 price, uint256 value, uint256 duration, uint256 stock, bool active, bool soulbound, address nftContract)
    {
        ItemConfig memory config = itemConfigs[itemId];
        return (
            uint8(config.kind),
            config.price,
            config.value,
            config.duration,
            config.stock,
            config.active,
            config.soulbound,
            config.nftContract
        );
    }

    function agentInventoryCount(uint256 itemId) external view returns (uint256) {
        return _agentInventory[itemId].length;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                require(!itemConfigs[ids[i]].soulbound, "NuxTapItemStore: soulbound item");
            }
        }
    }

    function _popAgentInventory(uint256 itemId) internal returns (uint256 tokenId) {
        uint256 lastIndex = _agentInventory[itemId].length - 1;
        tokenId = _agentInventory[itemId][lastIndex];
        _agentInventory[itemId].pop();
    }

    uint256[50] private __gap;

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}