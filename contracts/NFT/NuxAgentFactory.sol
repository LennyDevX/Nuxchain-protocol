// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../interfaces/INuxAgentNFT.sol";
import "../interfaces/ITreasuryManager.sol";

/**
 * @title NuxAgentFactory
 * @notice User-facing factory that creates AI Agent NFTs for any of the 5 NuxChain categories
 * @dev Routes minting to the appropriate category contract based on AgentCategory enum
 *      Pre-configured templates reduce friction for new users while allowing full customization
 *
 * CATEGORY TEMPLATES:
 *   Each category has a default system prompt URI (IPFS) with pre-configured Gemini settings.
 *   Advanced users can override all fields for fully custom agents.
 *
 * MINTING FLOW:
 *   1. User selects category + configures agent (name, description, prompts, model)
 *   2. Factory routes to appropriate category contract
 *   3. Category contract calls _mintAgent() in NuxAgentNFTBase
 *   4. TBA (Token Bound Account) deployed via ERC-6551
 *   5. ERC-8004 registration file URI stored
 *   6. Minting fee → TreasuryManager (revenue type: "nft_agent_mint")
 *   7. 50 XP → creator via LevelingSystem
 *   8. NuxAgentRegistry registers the agent
 *
 * RENTAL SUPPORT:
 *   Users can create rental offers immediately after minting by calling
 *   NuxAgentRental.createRentalOffer() with the returned tokenId.
 */
interface ICategoryNFT {
    function mintFromFactory(
        address recipient,
        INuxAgentNFT.AgentConfig memory config,
        string memory tokenURI_
    ) external payable returns (uint256 tokenId);

    function mintingFee() external view returns (uint256);
}

contract NuxAgentFactory is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    // ============================================
    // ROLES
    // ============================================
    bytes32 public constant ADMIN_ROLE    = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ============================================
    // STRUCTS
    // ============================================

    /**
     * @notice User-facing minting parameters (simplified vs full AgentConfig)
     */
    struct MintParams {
        string name;
        string description;
        string model;                             // "gemini-2.0-flash" | "gemini-2.5-pro" etc.
        INuxAgentNFT.AgentCategory category;
        string systemPromptURI;                   // leave empty to use category template
        string userPromptURI;                     // leave empty to use category template
        bool   promptsEncrypted;
        bytes  geminiConfig;                      // ABI-encoded Gemini params, empty = use defaults
        string agentURI;                          // ERC-8004 registration file URI
        string tokenURI;                          // NFT metadata URI (IPFS)
    }

    /**
     * @notice Default template per category
     */
    struct CategoryTemplate {
        string defaultSystemPromptURI;
        string defaultModel;
        bytes  defaultGeminiConfig;
        address nftContract;                      // Category NFT contract address
        bool    active;
    }

    // ============================================
    // STATE
    // ============================================
    mapping(INuxAgentNFT.AgentCategory => CategoryTemplate) public templates;
    address public agentRegistry;
    ITreasuryManager public treasuryManager;

    // Statistics
    uint256 public totalAgentsMinted;
    mapping(INuxAgentNFT.AgentCategory => uint256) public mintsByCategory;
    mapping(address => uint256[]) public agentsByOwner;  // owner → tokenIds minted via factory

    // ============================================
    // EVENTS
    // ============================================
    event AgentMintedViaFactory(
        address indexed creator,
        uint256 indexed tokenId,
        INuxAgentNFT.AgentCategory indexed category,
        address nftContract
    );
    event TemplateUpdated(INuxAgentNFT.AgentCategory indexed category, address nftContract);
    event CategoryContractSet(INuxAgentNFT.AgentCategory indexed category, address indexed nftContract);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address treasuryManager_
    ) public initializer {
        require(admin_ != address(0), "Factory: invalid admin");
        require(treasuryManager_ != address(0), "Factory: invalid treasury");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        treasuryManager = ITreasuryManager(treasuryManager_);
        _initializeDefaultTemplates();
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ============================================
    // DEFAULT TEMPLATE INITIALIZATION
    // ============================================

    function _initializeDefaultTemplates() internal {
        // SOCIAL: Community engagement, content creation, sentiment analysis
        templates[INuxAgentNFT.AgentCategory.SOCIAL] = CategoryTemplate({
            defaultSystemPromptURI: "ipfs://QmNuxSocialTemplate",
            defaultModel:           "gemini-2.0-flash",
            defaultGeminiConfig:    abi.encode(uint8(70), true),  // temperature=0.7, grounding=true
            nftContract:            address(0),
            active:                 false
        });

        // TECH: Code auditing, contract monitoring, DevOps automation
        templates[INuxAgentNFT.AgentCategory.TECH] = CategoryTemplate({
            defaultSystemPromptURI: "ipfs://QmNuxTechTemplate",
            defaultModel:           "gemini-2.5-pro",
            defaultGeminiConfig:    abi.encode(uint8(10), false), // temperature=0.1, grounding=false
            nftContract:            address(0),
            active:                 false
        });

        // MARKETING: Campaigns, analytics, copywriting, referral optimization
        templates[INuxAgentNFT.AgentCategory.MARKETING] = CategoryTemplate({
            defaultSystemPromptURI: "ipfs://QmNuxMarketingTemplate",
            defaultModel:           "gemini-2.0-flash",
            defaultGeminiConfig:    abi.encode(uint8(80), true),  // temperature=0.8, grounding=true
            nftContract:            address(0),
            active:                 false
        });

        // FINANCE: DeFi automation, portfolio management, yield strategies
        templates[INuxAgentNFT.AgentCategory.FINANCE] = CategoryTemplate({
            defaultSystemPromptURI: "ipfs://QmNuxFinanceTemplate",
            defaultModel:           "gemini-2.5-pro",
            defaultGeminiConfig:    abi.encode(uint8(20), false), // temperature=0.2, cautious
            nftContract:            address(0),
            active:                 false
        });

        // BUSINESS: CRM, workflow automation, contract management
        templates[INuxAgentNFT.AgentCategory.BUSINESS] = CategoryTemplate({
            defaultSystemPromptURI: "ipfs://QmNuxBusinessTemplate",
            defaultModel:           "gemini-2.0-flash",
            defaultGeminiConfig:    abi.encode(uint8(50), false), // temperature=0.5, balanced
            nftContract:            address(0),
            active:                 false
        });
    }

    // ============================================
    // PRIMARY MINTING FUNCTION
    // ============================================

    /**
     * @notice Mint a new AI Agent NFT of any category
     * @dev Routes to the appropriate category NFT contract
     *      Passes msg.value to cover the minting fee
     *      Empty systemPromptURI/model uses the category template defaults
     *
     * @param params    Minting parameters (name, category, prompts, model, etc.)
     * @param recipient Address that will receive the NFT (usually msg.sender)
     * @return tokenId  The newly minted NFT token ID
     * @return nftContract The category NFT contract address
     */
    function mintAgent(
        MintParams calldata params,
        address recipient
    ) external payable nonReentrant returns (uint256 tokenId, address nftContract) {
        require(recipient != address(0), "Factory: invalid recipient");

        CategoryTemplate storage tmpl = templates[params.category];
        require(tmpl.active, "Factory: category not deployed yet");
        require(tmpl.nftContract != address(0), "Factory: category contract not set");

        // Build full AgentConfig, using template defaults for empty fields
        string memory resolvedModel;
        string memory resolvedSystemPromptURI;
        bytes memory resolvedGeminiConfig;
        if (bytes(params.model).length > 0)            { resolvedModel           = params.model;           }
        else                                           { resolvedModel           = tmpl.defaultModel;      }
        if (bytes(params.systemPromptURI).length > 0)  { resolvedSystemPromptURI = params.systemPromptURI; }
        else                                           { resolvedSystemPromptURI = tmpl.defaultSystemPromptURI; }
        if (params.geminiConfig.length > 0)            { resolvedGeminiConfig    = params.geminiConfig;    }
        else                                           { resolvedGeminiConfig    = tmpl.defaultGeminiConfig; }

        INuxAgentNFT.AgentConfig memory config = INuxAgentNFT.AgentConfig({
            name:             params.name,
            description:      params.description,
            model:            resolvedModel,
            category:         params.category,
            systemPromptURI:  resolvedSystemPromptURI,
            userPromptURI:    params.userPromptURI,
            promptsEncrypted: params.promptsEncrypted,
            geminiConfig:     resolvedGeminiConfig,
            agentURI:         params.agentURI,
            state:            INuxAgentNFT.AgentState.INACTIVE,
            mintedAt:         0, // set by base contract
            reputation:       0
        });

        nftContract = tmpl.nftContract;

        // Forward payment to category NFT contract for fee collection
        tokenId = ICategoryNFT(nftContract).mintFromFactory{value: msg.value}(
            recipient,
            config,
            params.tokenURI
        );

        // Track statistics
        totalAgentsMinted++;
        mintsByCategory[params.category]++;
        agentsByOwner[recipient].push(tokenId);

        // Register in NuxAgentRegistry if set
        if (agentRegistry != address(0)) {
            // Initialize agent metadata in registry (best-effort)
            (bool ok,) = agentRegistry.call(
                abi.encodeWithSignature(
                    "configureAgent(address,uint256,uint256,bool,string,string)",
                    nftContract, tokenId, 0, false, "", ""
                )
            );
            if (!ok) {} // solhint-disable-line no-empty-blocks
        }

        emit AgentMintedViaFactory(recipient, tokenId, params.category, nftContract);
    }

    // ============================================
    // BATCH MINTING
    // ============================================

    /**
     * @notice Mint multiple agents in one transaction (same category)
     * @dev Maximum 10 per batch to avoid gas limits
     */
    function mintAgentBatch(
        MintParams[] calldata paramsList,
        address recipient
    ) external payable nonReentrant returns (uint256[] memory tokenIds) {
        require(paramsList.length > 0 && paramsList.length <= 10, "Factory: batch 1-10");
        require(recipient != address(0), "Factory: invalid recipient");

        tokenIds = new uint256[](paramsList.length);

        // Calculate total fee
        uint256 totalFee = 0;
        for (uint256 i = 0; i < paramsList.length; i++) {
            CategoryTemplate storage tmpl = templates[paramsList[i].category];
            require(tmpl.active, "Factory: category not deployed");
            totalFee += ICategoryNFT(tmpl.nftContract).mintingFee();
        }
        require(msg.value >= totalFee, "Factory: insufficient fee for batch");

        uint256 remaining = msg.value;
        for (uint256 i = 0; i < paramsList.length; i++) {
            CategoryTemplate storage tmpl = templates[paramsList[i].category];
            uint256 fee = ICategoryNFT(tmpl.nftContract).mintingFee();

            string memory resolvedModel_i;
            string memory resolvedSystemPromptURI_i;
            bytes memory resolvedGeminiConfig_i;
            if (bytes(paramsList[i].model).length > 0)            { resolvedModel_i           = paramsList[i].model;           }
            else                                                   { resolvedModel_i           = tmpl.defaultModel;             }
            if (bytes(paramsList[i].systemPromptURI).length > 0)  { resolvedSystemPromptURI_i = paramsList[i].systemPromptURI; }
            else                                                   { resolvedSystemPromptURI_i = tmpl.defaultSystemPromptURI;   }
            if (paramsList[i].geminiConfig.length > 0)            { resolvedGeminiConfig_i    = paramsList[i].geminiConfig;    }
            else                                                   { resolvedGeminiConfig_i    = tmpl.defaultGeminiConfig;      }

            INuxAgentNFT.AgentConfig memory config = INuxAgentNFT.AgentConfig({
                name:             paramsList[i].name,
                description:      paramsList[i].description,
                model:            resolvedModel_i,
                category:         paramsList[i].category,
                systemPromptURI:  resolvedSystemPromptURI_i,
                userPromptURI:    paramsList[i].userPromptURI,
                promptsEncrypted: paramsList[i].promptsEncrypted,
                geminiConfig:     resolvedGeminiConfig_i,
                agentURI:         paramsList[i].agentURI,
                state:            INuxAgentNFT.AgentState.INACTIVE,
                mintedAt:         0,
                reputation:       0
            });

            tokenIds[i] = ICategoryNFT(tmpl.nftContract).mintFromFactory{value: fee}(
                recipient, config, paramsList[i].tokenURI
            );
            remaining -= fee;

            totalAgentsMinted++;
            mintsByCategory[paramsList[i].category]++;
            agentsByOwner[recipient].push(tokenIds[i]);

            emit AgentMintedViaFactory(recipient, tokenIds[i], paramsList[i].category, tmpl.nftContract);
        }

        // Refund excess
        if (remaining > 0) {
            (bool ok,) = msg.sender.call{value: remaining}("");
            require(ok, "Factory: refund failed");
        }
    }

    // ============================================
    // ADMIN — TEMPLATE & CONTRACT MANAGEMENT
    // ============================================

    function setCategoryContract(
        INuxAgentNFT.AgentCategory category,
        address nftContract
    ) external onlyRole(ADMIN_ROLE) {
        require(nftContract != address(0), "Factory: invalid contract");
        templates[category].nftContract = nftContract;
        templates[category].active = true;
        emit CategoryContractSet(category, nftContract);
    }

    function updateCategoryTemplate(
        INuxAgentNFT.AgentCategory category,
        string calldata defaultSystemPromptURI,
        string calldata defaultModel,
        bytes calldata defaultGeminiConfig
    ) external onlyRole(ADMIN_ROLE) {
        CategoryTemplate storage tmpl = templates[category];
        if (bytes(defaultSystemPromptURI).length > 0) tmpl.defaultSystemPromptURI = defaultSystemPromptURI;
        if (bytes(defaultModel).length > 0) tmpl.defaultModel = defaultModel;
        if (defaultGeminiConfig.length > 0) tmpl.defaultGeminiConfig = defaultGeminiConfig;
        emit TemplateUpdated(category, tmpl.nftContract);
    }

    function setAgentRegistry(address registry_) external onlyRole(ADMIN_ROLE) {
        agentRegistry = registry_;
    }

    function setCategoryActive(INuxAgentNFT.AgentCategory category, bool active) external onlyRole(ADMIN_ROLE) {
        templates[category].active = active;
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    function getTemplate(INuxAgentNFT.AgentCategory category) external view returns (CategoryTemplate memory) {
        return templates[category];
    }

    function getAgentsByOwner(address owner) external view returns (uint256[] memory) {
        return agentsByOwner[owner];
    }

    function getMintingFee(INuxAgentNFT.AgentCategory category) external view returns (uint256) {
        address nftContract = templates[category].nftContract;
        if (nftContract == address(0)) return 0;
        return ICategoryNFT(nftContract).mintingFee();
    }

    function getAllCategoryContracts() external view returns (address[5] memory contracts) {
        contracts[0] = templates[INuxAgentNFT.AgentCategory.SOCIAL].nftContract;
        contracts[1] = templates[INuxAgentNFT.AgentCategory.TECH].nftContract;
        contracts[2] = templates[INuxAgentNFT.AgentCategory.MARKETING].nftContract;
        contracts[3] = templates[INuxAgentNFT.AgentCategory.FINANCE].nftContract;
        contracts[4] = templates[INuxAgentNFT.AgentCategory.BUSINESS].nftContract;
    }

    uint256[50] private __gap;
}
