// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title INuxAgentNFT
 * @notice Interface for NuxChain AI Agent NFTs
 * @dev Combines ERC-7662 (AI Agent NFTs) + ERC-8004 (Trustless Agents) + ERC-6551 (Token Bound Accounts)
 *
 * STANDARDS IMPLEMENTED:
 * - ERC-7662: Stores AI agent prompts (encrypted) and model info on-chain / decentralized storage
 * - ERC-8004: agentURI resolves to a registration file with services, trust models, x402Support
 * - ERC-6551: Each NFT gets a deterministic Token Bound Account (TBA/wallet)
 * - ERC-2981: Royalties on secondary sales
 * - x402:     Agent TBAs can pay for API calls autonomously using x402 pattern
 *
 * CATEGORIES:
 * Five specialization domains that determine an agent's pre-configured skills:
 *   SOCIAL      - Community management, engagement, content creation
 *   TECH        - Smart contract auditing, monitoring, DevOps automation
 *   MARKETING   - Campaigns, analytics, referral optimization, copywriting
 *   FINANCE     - DeFi automation, portfolio management, yield strategies
 *   BUSINESS    - CRM, workflow automation, contract management, analytics
 */
interface INuxAgentNFT {

    // ============================================
    // ENUMS
    // ============================================

    /// @notice The 5 primary specialization categories for NuxChain agents
    enum AgentCategory {
        SOCIAL,     // 0 - Social engagement & community
        TECH,       // 1 - Technology & development
        MARKETING,  // 2 - Marketing & growth
        FINANCE,    // 3 - Finance & DeFi
        BUSINESS    // 4 - Business & operations
    }

    /// @notice Current operational state of an agent
    enum AgentState {
        INACTIVE,   // 0 - Deployed but not activated
        ACTIVE,     // 1 - Running and executing tasks
        LEARNING,   // 2 - In training/fine-tuning mode
        SUSPENDED   // 3 - Paused by owner or platform
    }

    // ============================================
    // STRUCTS
    // ============================================

    /**
     * @notice Complete agent configuration stored on-chain
     * @dev ERC-7662 compliant: prompts stored as encrypted IPFS/Arweave URIs
     *      ERC-8004 compatible: agentURI points to registration file
     */
    struct AgentConfig {
        string name;              // Agent display name
        string description;       // Natural language description of capabilities
        string model;             // AI model identifier (e.g., "gemini-2.0-flash")
        AgentCategory category;   // Specialization category
        string systemPromptURI;   // IPFS/Arweave URI to encrypted system prompt (ERC-7662)
        string userPromptURI;     // IPFS/Arweave URI to encrypted user prompt template (ERC-7662)
        bool promptsEncrypted;    // True if prompts use Lit Protocol or similar encryption
        bytes geminiConfig;       // ABI-encoded Gemini SDK parameters (temperature, tools, etc.)
        string agentURI;          // ERC-8004 registration file URI (services, endpoints, trust)
        AgentState state;         // Current operational state
        uint256 mintedAt;         // Block timestamp of minting
        uint256 reputation;       // On-chain reputation score (ERC-8004 aggregated)
    }

    struct AgentView {
        uint256 tokenId;
        address owner;
        address effectiveController;
        address tokenBoundAccount;
        address renter;
        uint256 rentalExpiry;
        uint256 remainingRentalTime;
        bool isCurrentlyRented;
        string tokenMetadataURI;
        string agentRegistrationURI;
        AgentConfig config;
    }

    struct CollectionStats {
        uint256 totalAgents;
        uint256 activeAgents;
        uint256 rentedAgents;
        uint256[5] categoryCounts;
    }

    // ============================================
    // EVENTS (ERC-7662 required)
    // ============================================

    /// @notice Emitted when a new agent NFT is minted (ERC-7662)
    event AgentCreated(
        string name,
        string description,
        string model,
        address indexed recipient,
        uint256 indexed tokenId
    );

    /// @notice Emitted when agent data is updated (ERC-7662)
    event AgentUpdated(uint256 indexed tokenId);

    /// @notice Emitted when agent state changes
    event AgentStateChanged(uint256 indexed tokenId, AgentState newState);

    /// @notice Emitted when ERC-8004 agentURI is updated
    event AgentURIUpdated(uint256 indexed tokenId, string newURI);

    // ============================================
    // ERC-7662: AI AGENT NFT FUNCTIONS
    // ============================================

    /**
     * @notice Returns all AI agent data for a token (ERC-7662 required function)
     * @param tokenId The NFT token ID
     * @return name Agent display name
     * @return description Agent description
     * @return model AI model identifier
     * @return userPromptURI URI to user prompt (may be encrypted)
     * @return systemPromptURI URI to system prompt (may be encrypted)
     * @return promptsEncrypted Whether prompts are encrypted
     */
    function getAgentData(uint256 tokenId) external view returns (
        string memory name,
        string memory description,
        string memory model,
        string memory userPromptURI,
        string memory systemPromptURI,
        bool promptsEncrypted
    );

    /**
     * @notice Returns complete agent configuration struct
     * @param tokenId The NFT token ID
     */
    function getAgentConfig(uint256 tokenId) external view returns (AgentConfig memory);

    /**
     * @notice Returns current operational state of an agent
     * @param tokenId The NFT token ID
     */
    function getAgentState(uint256 tokenId) external view returns (AgentState);

    /**
     * @notice Returns the ERC-6551 Token Bound Account address for this agent
     * @param tokenId The NFT token ID
     * @dev This is the Ethereum address where the agent can receive funds and execute transactions
     */
    function getTokenBoundAccount(uint256 tokenId) external view returns (address);

    /**
     * @notice Change the operational state of an agent (owner or registry only)
     * @param tokenId The NFT token ID
     * @param newState New operational state
     */
    function setAgentState(uint256 tokenId, AgentState newState) external;

    /**
     * @notice Update encrypted prompts for an agent (owner only)
     * @param tokenId The NFT token ID
     * @param systemPromptURI New system prompt URI
     * @param userPromptURI New user prompt URI
     * @param encrypted True if using encrypted storage (e.g., Lit Protocol)
     */
    function updatePrompts(
        uint256 tokenId,
        string calldata systemPromptURI,
        string calldata userPromptURI,
        bool encrypted
    ) external;

    // ============================================
    // ERC-8004: IDENTITY FUNCTIONS
    // ============================================

    /**
     * @notice Returns the ERC-8004 agent registration file URI
     * @dev URI resolves to JSON file with services, endpoints, trust models, x402Support flag
     * @param tokenId The agent ID (same as NFT token ID)
     */
    function getAgentURI(uint256 tokenId) external view returns (string memory);

    /**
     * @notice Update the ERC-8004 registration file URI (owner or admin)
     * @param tokenId The agent ID
     * @param newURI New registration file URI (IPFS, HTTPS, or base64 data URI)
     */
    function setAgentURI(uint256 tokenId, string calldata newURI) external;

}
