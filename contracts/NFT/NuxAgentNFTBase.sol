// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/INuxAgentNFT.sol";

interface IAgentRevenueTreasury {
    function depositRevenue(string calldata revenueType) external payable;
}

/**
 * @title NuxAgentNFTBase
 * @notice Abstract base contract for all NuxChain AI Agent NFTs
 * @dev Implements ERC-721 + ERC-7662 (AI Agent NFTs) + ERC-6551 TBA creation
 *      + ERC-2981 royalties + ERC-8004 identity (agentURI)
 *
 * ARCHITECTURE:
 * - Each minted NFT is an AI agent with a Token Bound Account (ERC-6551 TBA)
 * - The TBA is the agent's on-chain wallet — it can hold funds, pay APIs, execute transactions
 * - Prompts stored as encrypted IPFS URIs (ERC-7662 specification)
 * - agentURI points to ERC-8004 registration file (services, endpoints, trust models)
 * - Minting revenue routed to the dedicated NuxTap treasury
 * - Optional progression hooks may still award XP to the creator on mint
 *
 * SECURITY:
 * - UUPS upgradeable proxies (only UPGRADER_ROLE can upgrade)
 * - ReentrancyGuard on payment-handling functions
 * - Ownership cycle prevention: cannot transfer NFT to its own TBA
 */
abstract contract NuxAgentNFTBase is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC2981Upgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    INuxAgentNFT
{
    using Counters for Counters.Counter;

    // ============================================
    // ROLES
    // ============================================
    bytes32 public constant ADMIN_ROLE    = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant FACTORY_ROLE  = keccak256("FACTORY_ROLE");
    bytes32 public constant REGISTRY_ROLE = keccak256("REGISTRY_ROLE");
    bytes32 public constant RENTAL_ROLE   = keccak256("RENTAL_ROLE");

    // ============================================
    // ERC-6551 REGISTRY (canonical, same on all EVM chains)
    // ============================================
    address public constant ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;

    // ============================================
    // CONSTANTS
    // ============================================
    uint256 public constant PLATFORM_MINT_FEE_BPS = 600;  // 6% of mintingFee → treasury
    uint256 private constant BASIS_POINTS = 10_000;

    // ============================================
    // STATE — CONFIGURATION
    // ============================================
    address public erc6551Implementation;  // ERC-6551 account implementation to deploy
    uint256 public mintingFee;             // Native token fee per mint (in wei)
    uint96  public defaultRoyaltyBps;      // Default royalty for secondary sales (e.g. 500 = 5%)

    IAgentRevenueTreasury public agentTreasury;
    address public levelingSystemAddress;
    address public agentRegistryAddress;   // NuxAgentRegistry (ERC-8004)

    // ============================================
    // STATE — STORAGE
    // ============================================
    Counters.Counter private _tokenIdCounter;

    // tokenId → complete agent configuration (ERC-7662)
    mapping(uint256 => AgentConfig) internal _agentConfigs;
    // tokenId → ERC-8004 registration file URI
    mapping(uint256 => string) internal _agentURIs;
    // tokenId → ERC-6551 Token Bound Account address
    mapping(uint256 => address) internal _tokenBoundAccounts;

    // Category statistics
    mapping(AgentCategory => uint256) public agentCountByCategory;

    // Rental system: tokenId → current renter address (zero if not rented)
    mapping(uint256 => address) public currentRenter;
    // tokenId → rental expiry timestamp
    mapping(uint256 => uint256) public rentalExpiry;

    // ============================================
    // EVENTS
    // ============================================
    event MintingFeeUpdated(uint256 oldFee, uint256 newFee);
    event TBAccountCreated(uint256 indexed tokenId, address indexed tba);
    event RenterSet(uint256 indexed tokenId, address indexed renter, uint256 expiry);

    // ============================================
    // CONSTRUCTOR
    // ============================================
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============================================
    // INITIALIZER (called by child contracts)
    // ============================================
    function __NuxAgentNFTBase_init(
        string memory name_,
        string memory symbol_,
        address admin_,
        address treasuryManager_,
        address levelingSystem_,
        address erc6551Impl_,
        uint256 mintingFee_,
        uint96  defaultRoyaltyBps_
    ) internal onlyInitializing {
        __ERC721_init(name_, symbol_);
        __ERC721URIStorage_init();
        __ERC2981_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        require(admin_ != address(0),          "NuxBase: invalid admin");
        require(treasuryManager_ != address(0), "NuxBase: invalid treasury");

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);

        agentTreasury         = IAgentRevenueTreasury(treasuryManager_);
        levelingSystemAddress = levelingSystem_;
        erc6551Implementation = erc6551Impl_;
        mintingFee            = mintingFee_;
        defaultRoyaltyBps     = defaultRoyaltyBps_;

        // Set default royalty receiver to admin (creator royalties set per-token at mint)
        _setDefaultRoyalty(admin_, defaultRoyaltyBps_);
    }

    // ============================================
    // INTERNAL MINTING — called by category contracts
    // ============================================

    /**
     * @notice Core minting logic — creates NFT, stores config, deploys TBA
     * @param recipient Owner of the new NFT
     * @param config    AI agent configuration (ERC-7662)
     * @param tokenURI_ IPFS/Arweave metadata URI for the NFT
     * @return tokenId  The newly minted token ID
     */
    function _mintAgent(
        address recipient,
        AgentConfig memory config,
        string memory tokenURI_
    ) internal returns (uint256 tokenId) {
        _tokenIdCounter.increment();
        tokenId = _tokenIdCounter.current();

        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        // Store agent config with metadata
        config.state    = AgentState.INACTIVE;
        config.mintedAt = block.timestamp;
        _agentConfigs[tokenId] = config;

        // ERC-8004: store agentURI separately (can be updated independently)
        _agentURIs[tokenId] = config.agentURI;

        agentCountByCategory[config.category]++;

        // Set per-token royalty: creator receives royalties on resales (ERC-2981)
        _setTokenRoyalty(tokenId, recipient, defaultRoyaltyBps);

        // ERC-6551: deploy Token Bound Account for this agent
        address tba = _deployTokenBoundAccount(tokenId);
        _tokenBoundAccounts[tokenId] = tba;

        // Award creation XP via LevelingSystem (recordAgentMinted tracks agent + grants 50 XP)
        _recordAgentMinted(recipient);

        emit AgentCreated(config.name, config.description, config.model, recipient, tokenId);
        emit TBAccountCreated(tokenId, tba);
    }

    // ============================================
    // ERC-6551: TOKEN BOUND ACCOUNT DEPLOYMENT
    // ============================================

    /**
     * @notice Deploys a deterministic Token Bound Account for a token via ERC-6551 registry
     * @dev Uses CREATE2 — address is deterministic and can be pre-computed before deployment
     */
    function _deployTokenBoundAccount(uint256 tokenId) internal returns (address tba) {
        if (erc6551Implementation == address(0)) return address(0);

        // Call ERC-6551 registry createAccount
        (bool success, bytes memory returnData) = ERC6551_REGISTRY.call(
            abi.encodeWithSignature(
                "createAccount(address,bytes32,uint256,address,uint256)",
                erc6551Implementation,
                bytes32(0),         // salt = 0 (deterministic)
                block.chainid,
                address(this),      // NFT contract
                tokenId
            )
        );

        if (success && returnData.length >= 32) {
            tba = abi.decode(returnData, (address));
        }
    }

    /**
     * @notice Returns the deterministic TBA address for a token (may not be deployed yet)
     */
    function computeTokenBoundAccount(uint256 tokenId) external view returns (address) {
        if (erc6551Implementation == address(0)) return address(0);
        (bool success, bytes memory returnData) = ERC6551_REGISTRY.staticcall(
            abi.encodeWithSignature(
                "account(address,bytes32,uint256,address,uint256)",
                erc6551Implementation,
                bytes32(0),
                block.chainid,
                address(this),
                tokenId
            )
        );
        if (success && returnData.length >= 32) {
            return abi.decode(returnData, (address));
        }
        return address(0);
    }

    // ============================================
    // MINTING FEE COLLECTION
    // ============================================

    /**
    * @notice Collects minting fee and forwards to the NuxTap revenue treasury
     * @dev Refunds excess payment automatically
     */
    function _collectMintingFee() internal {
        require(msg.value >= mintingFee, "NuxBase: insufficient minting fee");

        if (mintingFee > 0) {
            (bool ok,) = address(agentTreasury).call{value: mintingFee}(
                abi.encodeWithSignature("depositRevenue(string)", "nuxtap_agent_mint")
            );
            require(ok, "NuxBase: treasury transfer failed");
        }

        // Refund any excess payment
        uint256 excess = msg.value - mintingFee;
        if (excess > 0) {
            (bool refunded,) = msg.sender.call{value: excess}("");
            require(refunded, "NuxBase: refund failed");
        }
    }

    // ============================================
    // XP AWARD
    // ============================================

    /**
     * @notice Awards XP to a user via LevelingSystem
     * @dev Silently ignores failures to avoid blocking mint/task execution
     */
    function _awardXP(address user, uint256 amount) internal {
        if (levelingSystemAddress == address(0)) return;
        // addXP(address user, uint256 amount) — requires caller to have MARKETPLACE_ROLE
        (bool ok,) = levelingSystemAddress.call(
            abi.encodeWithSignature("addXP(address,uint256)", user, amount)
        );
        // Intentionally ignore failure — XP is a bonus, not critical path
        if (!ok) {} // solhint-disable-line no-empty-blocks
    }

    /**
     * @notice Records an agent mint event in LevelingSystem (tracks count + awards 50 XP)
     * @dev Silently ignores failures to avoid blocking mint
     */
    function _recordAgentMinted(address creator) internal {
        if (levelingSystemAddress == address(0)) return;
        (bool ok,) = levelingSystemAddress.call(
            abi.encodeWithSignature("recordAgentMinted(address)", creator)
        );
        if (!ok) {} // solhint-disable-line no-empty-blocks
    }

    // ============================================
    // INuxAgentNFT IMPLEMENTATION
    // ============================================

    /// @inheritdoc INuxAgentNFT
    function getAgentData(uint256 tokenId) external view override returns (
        string memory name,
        string memory description,
        string memory model,
        string memory userPromptURI,
        string memory systemPromptURI,
        bool promptsEncrypted
    ) {
        require(_exists(tokenId), "NuxBase: token does not exist");
        AgentConfig storage c = _agentConfigs[tokenId];
        return (c.name, c.description, c.model, c.userPromptURI, c.systemPromptURI, c.promptsEncrypted);
    }

    /// @inheritdoc INuxAgentNFT
    function getAgentConfig(uint256 tokenId) external view override returns (AgentConfig memory) {
        require(_exists(tokenId), "NuxBase: token does not exist");
        return _agentConfigs[tokenId];
    }

    /// @inheritdoc INuxAgentNFT
    function getAgentState(uint256 tokenId) external view override returns (AgentState) {
        require(_exists(tokenId), "NuxBase: token does not exist");
        return _agentConfigs[tokenId].state;
    }

    /// @inheritdoc INuxAgentNFT
    function getTokenBoundAccount(uint256 tokenId) external view override returns (address) {
        require(_exists(tokenId), "NuxBase: token does not exist");
        return _tokenBoundAccounts[tokenId];
    }

    /// @inheritdoc INuxAgentNFT
    function setAgentState(uint256 tokenId, AgentState newState) external override {
        require(_exists(tokenId), "NuxBase: token does not exist");
        require(
            ownerOf(tokenId) == msg.sender ||
            hasRole(REGISTRY_ROLE, msg.sender) ||
            hasRole(ADMIN_ROLE, msg.sender),
            "NuxBase: not authorized"
        );
        _agentConfigs[tokenId].state = newState;
        emit AgentStateChanged(tokenId, newState);
    }

    /// @inheritdoc INuxAgentNFT
    function updatePrompts(
        uint256 tokenId,
        string calldata systemPromptURI_,
        string calldata userPromptURI_,
        bool encrypted
    ) external override {
        require(_exists(tokenId), "NuxBase: token does not exist");
        require(ownerOf(tokenId) == msg.sender, "NuxBase: not token owner");
        _agentConfigs[tokenId].systemPromptURI = systemPromptURI_;
        _agentConfigs[tokenId].userPromptURI   = userPromptURI_;
        _agentConfigs[tokenId].promptsEncrypted = encrypted;
        emit AgentUpdated(tokenId);
    }

    // ============================================
    // ERC-8004: IDENTITY (agentURI)
    // ============================================

    /// @inheritdoc INuxAgentNFT
    function getAgentURI(uint256 tokenId) external view override returns (string memory) {
        require(_exists(tokenId), "NuxBase: token does not exist");
        return _agentURIs[tokenId];
    }

    /// @inheritdoc INuxAgentNFT
    function setAgentURI(uint256 tokenId, string calldata newURI) external override {
        require(_exists(tokenId), "NuxBase: token does not exist");
        require(
            ownerOf(tokenId) == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "NuxBase: not authorized"
        );
        _agentURIs[tokenId] = newURI;
        emit AgentURIUpdated(tokenId, newURI);
    }

    // ============================================
    // RENTAL SYSTEM HOOKS
    // ============================================

    /**
     * @notice Set the current renter for an agent NFT (called by NuxAgentRental)
     */
    function setRenter(uint256 tokenId, address renter, uint256 expiry) external onlyRole(RENTAL_ROLE) {
        require(_exists(tokenId), "NuxBase: token does not exist");
        currentRenter[tokenId] = renter;
        rentalExpiry[tokenId]  = expiry;
        emit RenterSet(tokenId, renter, expiry);
    }

    /**
     * @notice Returns the effective controller: renter during active rental, owner otherwise
     */
    function effectiveController(uint256 tokenId) external view returns (address) {
        address renter = currentRenter[tokenId];
        if (renter != address(0) && block.timestamp < rentalExpiry[tokenId]) {
            return renter;
        }
        return ownerOf(tokenId);
    }

    // ============================================
    // REPUTATION (ERC-8004 hook)
    // ============================================

    /**
     * @notice Update on-chain reputation score (called by NuxAgentRegistry)
     */
    function updateReputation(uint256 tokenId, uint256 newScore) external onlyRole(REGISTRY_ROLE) {
        require(_exists(tokenId), "NuxBase: token does not exist");
        _agentConfigs[tokenId].reputation = newScore;
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================

    function setMintingFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        emit MintingFeeUpdated(mintingFee, newFee);
        mintingFee = newFee;
    }

    function setTreasuryManager(address treasury_) external onlyRole(ADMIN_ROLE) {
        require(treasury_ != address(0), "NuxBase: invalid address");
        agentTreasury = IAgentRevenueTreasury(treasury_);
    }

    function setLevelingSystem(address leveling_) external onlyRole(ADMIN_ROLE) {
        levelingSystemAddress = leveling_;
    }

    function setAgentRegistry(address registry_) external onlyRole(ADMIN_ROLE) {
        agentRegistryAddress = registry_;
        if (registry_ != address(0)) {
            _grantRole(REGISTRY_ROLE, registry_);
        }
    }

    function setRentalContract(address rental_) external onlyRole(ADMIN_ROLE) {
        if (rental_ != address(0)) {
            _grantRole(RENTAL_ROLE, rental_);
        }
    }

    function setERC6551Implementation(address impl_) external onlyRole(ADMIN_ROLE) {
        erc6551Implementation = impl_;
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    // ============================================
    // TRANSFER OVERRIDE — anti-ownership-cycle guard
    // ============================================
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override(ERC721Upgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        // ERC-6551 Ownership Cycle Prevention:
        // Prevent transferring NTF to its own Token Bound Account
        require(
            to != _tokenBoundAccounts[tokenId],
            "NuxBase: cannot transfer to own TBA (ownership cycle)"
        );
        // Clear rental on ownership transfer
        if (from != address(0) && to != address(0) && currentRenter[tokenId] != address(0)) {
            delete currentRenter[tokenId];
            delete rentalExpiry[tokenId];
        }
    }

    // ============================================
    // REQUIRED OVERRIDES
    // ============================================
    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
        delete _agentConfigs[tokenId];
        delete _agentURIs[tokenId];
        // Note: TBA persists on-chain after burn — this is by ERC-6551 design
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC2981Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    uint256[50] private __gap;

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    receive() external payable {}
}
