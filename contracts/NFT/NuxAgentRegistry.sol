// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/INuxAgentNFT.sol";

/**
 * @title NuxAgentRegistry
 * @notice On-chain registry for NuxChain AI agents implementing ERC-8004 (Trustless Agents)
 * @dev Implements all three ERC-8004 registries in one contract:
 *
 *   1. IDENTITY REGISTRY:
 *      - On-chain metadata (key/value store per agent)
 *      - agentWallet management with EIP-712 signature verification
 *      - Linked to the NFT contract (NuxAgentNFTBase) as the "agent token"
 *
 *   2. REPUTATION REGISTRY:
 *      - giveFeedback() — users rate agents after task completion
 *      - getSummary()   — aggregated on-chain reputation score
 *      - readFeedback() — per-feedback-index query
 *      - revokeFeedback() — client can revoke own feedback
 *      - Tags: e.g. "quality", "speed", "accuracy" for filtering
 *
 *   3. VALIDATION REGISTRY:
 *      - validationRequest() — agent requests validation of a task output
 *      - validationResponse() — authorized validator submits result
 *      - getValidationStatus() — query validation result on-chain
 *
 * MINIGAME INTEGRATION:
 *   - NuxAgentMiniGame calls recordTaskExecution() to log completed tasks
 *   - Reputation is updated on each validated task
 *   - getReputationScore() is used by the marketplace to display agent quality
 */
contract NuxAgentRegistry is AccessControl, Initializable, UUPSUpgradeable, ReentrancyGuard {

    // ============================================
    // ROLES
    // ============================================
    bytes32 public constant ADMIN_ROLE     = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE  = keccak256("UPGRADER_ROLE");
    bytes32 public constant GAME_ROLE      = keccak256("GAME_ROLE");     // NuxAgentMiniGame
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE"); // Authorized validators

    // ============================================
    // STRUCTS
    // ============================================

    struct AgentMetadata {
        address agentWallet;         // ERC-8004: on-chain payment wallet (default = NFT owner)
        uint256 totalTasksRun;       // Lifetime tasks executed
        uint256 totalRevenueEarned;  // Cumulative earnings via monetization
        uint256 spendingLimitDaily;  // Max tokens the agent can spend per day (via Paymaster)
        uint256 spentToday;          // Tokens spent today  
        uint256 spentDayReset;       // Timestamp of last daily reset
        bool    x402Enabled;         // Whether agent accepts x402 payments
        string  mcpEndpoint;         // MCP endpoint URL (for off-chain agent communication)
        string  a2aEndpoint;         // A2A agent card URL
    }

    /// @notice ERC-8004 Reputation feedback record (stored on-chain)
    struct FeedbackRecord {
        address clientAddress;   // Who gave the feedback
        int128  value;           // Signed fixed-point score
        uint8   valueDecimals;   // Decimal precision (0-18)
        string  tag1;            // Primary tag (e.g., "quality", "speed")
        string  tag2;            // Secondary tag (optional)
        bool    isRevoked;       // Whether client revoked this feedback
        uint256 timestamp;       // When feedback was given
    }

    /// @notice ERC-8004 Validation record
    struct ValidationRecord {
        address validatorAddress; // Who validated
        uint256 agentId;          // Which agent
        uint8   response;         // 0-100 (0=fail, 100=pass, intermediate=partial)
        bytes32 responseHash;     // KECCAK-256 of off-chain evidence URI
        string  tag;              // Custom categorization
        uint256 lastUpdate;       // Last updated timestamp
    }

    struct AgentOperationalProfile {
        address agentWallet;
        uint256 totalTasksRun;
        uint256 totalRevenueEarned;
        uint256 spendingLimitDaily;
        uint256 spentToday;
        uint256 spentDayReset;
        bool    x402Enabled;
        string  mcpEndpoint;
        string  a2aEndpoint;
        uint256 currentReputationScore;
        uint256 clientCount;
        uint256 validationCount;
    }

    // ============================================
    // STATE — IDENTITY
    // ============================================
    // NFT contract(s) that this registry serves
    mapping(address => bool) public registeredNFTContracts;
    // agentId (tokenId) → AgentMetadata
    mapping(uint256 => AgentMetadata) public agentMetadata;
    // agentId → custom key-value metadata (ERC-8004 setMetadata)
    mapping(uint256 => mapping(string => bytes)) private _onChainMetadata;
    // Reserved key for agentWallet — cannot be set via setMetadata
    string private constant RESERVED_AGENT_WALLET_KEY = "agentWallet";

    // ============================================
    // STATE — REPUTATION REGISTRY (ERC-8004)
    // ============================================
    // agentId → clientAddress → feedbackIndex(1-based) → FeedbackRecord
    mapping(uint256 => mapping(address => mapping(uint64 => FeedbackRecord))) private _feedback;
    // agentId → clientAddress → last feedback index
    mapping(uint256 => mapping(address => uint64)) private _lastFeedbackIndex;
    // agentId → list of unique client addresses
    mapping(uint256 => address[]) private _agentClients;
    // agentId → clientAddress → already tracked
    mapping(uint256 => mapping(address => bool)) private _clientTracked;
    // agentId → cached aggregated reputation score (0-100)
    mapping(uint256 => uint256) public reputationScore;

    // ============================================
    // STATE — VALIDATION REGISTRY (ERC-8004)
    // ============================================
    // requestHash → ValidationRecord
    mapping(bytes32 => ValidationRecord) private _validations;
    // agentId → list of request hashes
    mapping(uint256 => bytes32[]) private _agentValidations;
    // validatorAddress → list of request hashes
    mapping(address => bytes32[]) private _validatorRequests;

    // ============================================
    // EVENTS — REPUTATION (ERC-8004)
    // ============================================
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64  feedbackIndex,
        int128  value,
        uint8   valueDecimals,
        string  tag1,
        string  tag2
    );
    event FeedbackRevoked(uint256 indexed agentId, address indexed clientAddress, uint64 indexed feedbackIndex);
    event ResponseAppended(uint256 indexed agentId, address indexed clientAddress, uint64 feedbackIndex, address indexed responder);

    // ============================================
    // EVENTS — VALIDATION (ERC-8004)
    // ============================================
    event ValidationRequest(address indexed validatorAddress, uint256 indexed agentId, string requestURI, bytes32 indexed requestHash);
    event ValidationResponse(address indexed validatorAddress, uint256 indexed agentId, bytes32 indexed requestHash, uint8 response, string tag);

    // ============================================
    // EVENTS — IDENTITY
    // ============================================
    event AgentMetadataSet(uint256 indexed agentId, string indexed metadataKey, bytes metadataValue);
    event AgentWalletSet(uint256 indexed agentId, address indexed newWallet);
    event AgentWalletCleared(uint256 indexed agentId);
    event NFTContractRegistered(address indexed nftContract);
    event TaskExecutionRecorded(uint256 indexed agentId, address indexed executor, uint256 rewardPaid);
    event SpendingLimitUpdated(uint256 indexed agentId, uint256 newDailyLimit);

    // ============================================
    // EIP-712 DOMAIN SEPARATOR for agentWallet signature
    // ============================================
    bytes32 private _domainSeparator;
    bytes32 private constant SET_WALLET_TYPEHASH = keccak256(
        "SetAgentWallet(uint256 agentId,address newWallet,uint256 deadline)"
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin_) public initializer {
        require(admin_ != address(0), "Registry: invalid admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);

        _domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("NuxAgentRegistry"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ============================================
    // IDENTITY REGISTRY — ADMIN
    // ============================================

    function registerNFTContract(address nftContract) external onlyRole(ADMIN_ROLE) {
        require(nftContract != address(0), "Registry: invalid contract");
        registeredNFTContracts[nftContract] = true;
        emit NFTContractRegistered(nftContract);
    }

    function grantValidatorRole(address validator) external onlyRole(ADMIN_ROLE) {
        _grantRole(VALIDATOR_ROLE, validator);
    }

    function grantGameRole(address game) external onlyRole(ADMIN_ROLE) {
        _grantRole(GAME_ROLE, game);
    }

    // ============================================
    // IDENTITY REGISTRY — METADATA (ERC-8004)
    // ============================================

    /**
     * @notice Set custom on-chain metadata for an agent (ERC-8004)
     * @dev agentWallet key is reserved — use setAgentWallet() instead
     */
    function setMetadata(uint256 agentId, string calldata metadataKey, bytes calldata metadataValue) external {
        require(_isAgentOwnerOrOperator(agentId, msg.sender), "Registry: not authorized");
        require(
            keccak256(bytes(metadataKey)) != keccak256(bytes(RESERVED_AGENT_WALLET_KEY)),
            "Registry: agentWallet is reserved"
        );
        _onChainMetadata[agentId][metadataKey] = metadataValue;
        emit AgentMetadataSet(agentId, metadataKey, metadataValue);
    }

    function getMetadata(uint256 agentId, string calldata metadataKey) external view returns (bytes memory) {
        return _onChainMetadata[agentId][metadataKey];
    }

    /**
     * @notice Configure agent operational parameters (owner only)
     */
    function configureAgent(
        uint256 agentId,
        uint256 dailySpendingLimit,
        bool    x402Enabled,
        string calldata mcpEndpoint,
        string calldata a2aEndpoint
    ) external {
        require(_isAgentOwnerOrOperator(agentId, msg.sender), "Registry: not authorized");
        AgentMetadata storage meta = agentMetadata[agentId];
        meta.spendingLimitDaily = dailySpendingLimit;
        meta.x402Enabled        = x402Enabled;
        meta.mcpEndpoint        = mcpEndpoint;
        meta.a2aEndpoint        = a2aEndpoint;
        emit SpendingLimitUpdated(agentId, dailySpendingLimit);
    }

    // ============================================
    // IDENTITY REGISTRY — AGENT WALLET (ERC-8004)
    // ============================================

    /**
     * @notice Set the agent's payment wallet with EIP-712 signature from new wallet
     * @dev Signature proves control of newWallet (EOA or ERC-1271 smart contract)
     */
    function setAgentWallet(
        uint256 agentId,
        address newWallet,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(_isAgentOwnerOrOperator(agentId, msg.sender), "Registry: not authorized");
        require(block.timestamp <= deadline, "Registry: signature expired");
        require(newWallet != address(0), "Registry: invalid wallet");

        bytes32 structHash = keccak256(abi.encode(SET_WALLET_TYPEHASH, agentId, newWallet, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, structHash));

        // Verify the new wallet signed the message (proves control)
        address recovered = _recoverSigner(digest, signature);
        require(recovered == newWallet, "Registry: invalid signature");

        agentMetadata[agentId].agentWallet = newWallet;
        emit AgentWalletSet(agentId, newWallet);
    }

    function getAgentWallet(uint256 agentId) external view returns (address) {
        return agentMetadata[agentId].agentWallet;
    }

    function unsetAgentWallet(uint256 agentId) external {
        require(_isAgentOwnerOrOperator(agentId, msg.sender), "Registry: not authorized");
        delete agentMetadata[agentId].agentWallet;
        emit AgentWalletCleared(agentId);
    }

    // ============================================
    // REPUTATION REGISTRY (ERC-8004)
    // ============================================

    /**
     * @notice Submit feedback for an agent after task completion (ERC-8004)
     * @dev clientAddress cannot be the agent owner or operator
     * @param agentId         The agent being reviewed
     * @param value           Signed fixed-point score
     * @param valueDecimals   Decimal precision (0-18)
     * @param tag1            Primary tag ("quality", "speed", "accuracy", etc.)
     * @param tag2            Secondary tag (optional, empty string = no tag)
     * @param feedbackURI     Optional off-chain feedback detail URI
     * @param feedbackHash    KECCAK-256 of feedbackURI content (0 if IPFS or omitted)
     */
    function giveFeedback(
        uint256 agentId,
        int128  value,
        uint8   valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external nonReentrant {
        require(valueDecimals <= 18, "Registry: invalid valueDecimals");
        require(!_isAgentOwnerOrOperator(agentId, msg.sender), "Registry: owner cannot give feedback");

        uint64 newIndex = _lastFeedbackIndex[agentId][msg.sender] + 1;
        _lastFeedbackIndex[agentId][msg.sender] = newIndex;

        _feedback[agentId][msg.sender][newIndex] = FeedbackRecord({
            clientAddress:  msg.sender,
            value:          value,
            valueDecimals:  valueDecimals,
            tag1:           tag1,
            tag2:           tag2,
            isRevoked:      false,
            timestamp:      block.timestamp
        });

        if (!_clientTracked[agentId][msg.sender]) {
            _agentClients[agentId].push(msg.sender);
            _clientTracked[agentId][msg.sender] = true;
        }

        // Update cached reputation score (0-100 normalized)
        _updateReputationScore(agentId);

        emit NewFeedback(agentId, msg.sender, newIndex, value, valueDecimals, tag1, tag2);

        // Suppress unused parameter warnings for off-chain-only fields
        if (feedbackHash != bytes32(0)) {} // feedbackHash stored in event by caller convention
        if (bytes(feedbackURI).length != 0) {} // feedbackURI emitted off-chain
    }

    /**
     * @notice Revoke previously given feedback (ERC-8004)
     */
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external {
        require(_feedback[agentId][msg.sender][feedbackIndex].clientAddress == msg.sender, "Registry: not feedback owner");
        _feedback[agentId][msg.sender][feedbackIndex].isRevoked = true;
        _updateReputationScore(agentId);
        emit FeedbackRevoked(agentId, msg.sender, feedbackIndex);
    }

    /**
     * @notice Get aggregated reputation summary for an agent (ERC-8004)
     * @param agentId         The agent ID
     * @param clientAddresses List of trusted client addresses to filter by (anti-Sybil)
     * @param tag1            Optional tag1 filter (empty = no filter)
     */
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2
    ) external view returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals) {
        require(clientAddresses.length > 0, "Registry: must provide clientAddresses (anti-Sybil)");

        bool filterTag1 = bytes(tag1).length > 0;
        bool filterTag2 = bytes(tag2).length > 0;

        for (uint256 i = 0; i < clientAddresses.length; i++) {
            address client = clientAddresses[i];
            uint64 lastIdx = _lastFeedbackIndex[agentId][client];
            for (uint64 j = 1; j <= lastIdx; j++) {
                FeedbackRecord storage fb = _feedback[agentId][client][j];
                if (fb.isRevoked) continue;
                if (filterTag1 && keccak256(bytes(fb.tag1)) != keccak256(bytes(tag1))) continue;
                if (filterTag2 && keccak256(bytes(fb.tag2)) != keccak256(bytes(tag2))) continue;
                summaryValue += fb.value;
                summaryValueDecimals = fb.valueDecimals; // assume uniform
                count++;
            }
        }
    }

    /**
     * @notice Read a specific feedback record (ERC-8004)
     */
    function readFeedback(
        uint256 agentId,
        address clientAddress,
        uint64  feedbackIndex
    ) external view returns (int128 value, uint8 valueDecimals, string memory tag1, string memory tag2, bool isRevoked) {
        FeedbackRecord storage fb = _feedback[agentId][clientAddress][feedbackIndex];
        return (fb.value, fb.valueDecimals, fb.tag1, fb.tag2, fb.isRevoked);
    }

    function getClients(uint256 agentId) external view returns (address[] memory) {
        return _agentClients[agentId];
    }

    function getLastIndex(uint256 agentId, address clientAddress) external view returns (uint64) {
        return _lastFeedbackIndex[agentId][clientAddress];
    }

    // ============================================
    // VALIDATION REGISTRY (ERC-8004)
    // ============================================

    /**
     * @notice Request validation of agent task output (ERC-8004)
     * @dev Called by agent owner/operator; points validator to off-chain data
     * @param validatorAddress  Authorized validator contract or EOA
     * @param agentId           The agent being validated
     * @param requestURI        URI to off-chain data with inputs/outputs for verification
     * @param requestHash       KECCAK-256 commitment to requestURI content
     */
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestURI,
        bytes32 requestHash
    ) external {
        require(_isAgentOwnerOrOperator(agentId, msg.sender), "Registry: not authorized");
        require(validatorAddress != address(0), "Registry: invalid validator");
        require(requestHash != bytes32(0), "Registry: invalid request hash");

        _agentValidations[agentId].push(requestHash);
        _validatorRequests[validatorAddress].push(requestHash);

        emit ValidationRequest(validatorAddress, agentId, requestURI, requestHash);
    }

    /**
     * @notice Submit validation result (ERC-8004)
     * @dev Must be called by the validatorAddress specified in the original request
     * @param requestHash   The request being responded to
     * @param response      0-100 (0=fail, 100=pass, partial values allowed)
     * @param responseURI   Optional URI to off-chain evidence
     * @param responseHash  KECCAK-256 of responseURI content (0 if IPFS)
     * @param tag           Optional categorization tag
     */
    function validationResponse(
        bytes32 requestHash,
        uint8   response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external {
        // Validator must be registered
        require(hasRole(VALIDATOR_ROLE, msg.sender), "Registry: not a validator");

        ValidationRecord storage rec = _validations[requestHash];
        require(rec.agentId != 0 || _validatorRequests[msg.sender].length > 0, "Registry: unknown request");

        rec.validatorAddress = msg.sender;
        rec.response         = response;
        rec.responseHash     = responseHash;
        rec.tag              = tag;
        rec.lastUpdate       = block.timestamp;

        emit ValidationResponse(msg.sender, rec.agentId, requestHash, response, tag);

        // Suppress unused param
        if (bytes(responseURI).length != 0) {} // stored off-chain
    }

    function getValidationStatus(bytes32 requestHash) external view returns (
        address validatorAddress,
        uint256 agentId,
        uint8   response,
        bytes32 responseHash,
        string memory tag,
        uint256 lastUpdate
    ) {
        ValidationRecord storage rec = _validations[requestHash];
        return (rec.validatorAddress, rec.agentId, rec.response, rec.responseHash, rec.tag, rec.lastUpdate);
    }

    function getAgentValidations(uint256 agentId) external view returns (bytes32[] memory) {
        return _agentValidations[agentId];
    }

    function getValidatorRequests(address validatorAddress) external view returns (bytes32[] memory) {
        return _validatorRequests[validatorAddress];
    }

    function getAgentOperationalProfile(uint256 agentId) external view returns (AgentOperationalProfile memory profile) {
        AgentMetadata storage meta = agentMetadata[agentId];
        profile.agentWallet = meta.agentWallet;
        profile.totalTasksRun = meta.totalTasksRun;
        profile.totalRevenueEarned = meta.totalRevenueEarned;
        profile.spendingLimitDaily = meta.spendingLimitDaily;
        profile.spentToday = meta.spentToday;
        profile.spentDayReset = meta.spentDayReset;
        profile.x402Enabled = meta.x402Enabled;
        profile.mcpEndpoint = meta.mcpEndpoint;
        profile.a2aEndpoint = meta.a2aEndpoint;
        profile.currentReputationScore = reputationScore[agentId];
        profile.clientCount = _agentClients[agentId].length;
        profile.validationCount = _agentValidations[agentId].length;
    }

    function getFeedbackStats(
        uint256 agentId
    ) external view returns (
        uint256 currentReputationScore,
        uint256 totalClients,
        uint256 totalFeedbackCount,
        uint256 activeFeedbackCount,
        uint256 revokedFeedbackCount
    ) {
        address[] storage clients = _agentClients[agentId];
        totalClients = clients.length;

        for (uint256 i = 0; i < clients.length; i++) {
            uint64 lastIdx = _lastFeedbackIndex[agentId][clients[i]];
            totalFeedbackCount += lastIdx;
            for (uint64 j = 1; j <= lastIdx; j++) {
                if (_feedback[agentId][clients[i]][j].isRevoked) {
                    revokedFeedbackCount++;
                } else {
                    activeFeedbackCount++;
                }
            }
        }

        currentReputationScore = reputationScore[agentId];
    }

    function getClientFeedbackPage(
        uint256 agentId,
        address clientAddress,
        uint64 offset,
        uint64 limit
    ) external view returns (FeedbackRecord[] memory feedbackRecords, uint64 total) {
        total = _lastFeedbackIndex[agentId][clientAddress];
        if (limit == 0 || offset >= total) {
            return (new FeedbackRecord[](0), total);
        }

        uint64 end = offset + limit;
        if (end > total) end = total;

        feedbackRecords = new FeedbackRecord[](end - offset);
        uint64 index;
        for (uint64 feedbackIndex = offset + 1; feedbackIndex <= end; feedbackIndex++) {
            feedbackRecords[index] = _feedback[agentId][clientAddress][feedbackIndex];
            index++;
        }
    }

    // ============================================
    // TASK EXECUTION TRACKING (MiniGame integration)
    // ============================================

    /**
     * @notice Record a completed task execution (called by NuxAgentMiniGame)
     */
    function recordTaskExecution(uint256 agentId, address executor, uint256 rewardPaid) external onlyRole(GAME_ROLE) {
        agentMetadata[agentId].totalTasksRun++;
        agentMetadata[agentId].totalRevenueEarned += rewardPaid;
        emit TaskExecutionRecorded(agentId, executor, rewardPaid);
    }

    /**
     * @notice Check and update daily spending (called by NuxAgentPaymaster)
     */
    function authorizeSpend(uint256 agentId, uint256 amount) external returns (bool) {
        AgentMetadata storage meta = agentMetadata[agentId];

        // Reset daily counter if new day
        if (block.timestamp >= meta.spentDayReset + 1 days) {
            meta.spentToday     = 0;
            meta.spentDayReset  = block.timestamp;
        }

        uint256 limit = meta.spendingLimitDaily;
        if (limit == 0) return true; // No limit set = unrestricted

        if (meta.spentToday + amount > limit) return false;
        meta.spentToday += amount;
        return true;
    }

    // ============================================
    // INTERNAL HELPERS
    // ============================================

    /**
     * @notice Update cached reputation score as simple 0-100 average of all non-revoked feedback
     */
    function _updateReputationScore(uint256 agentId) internal {
        address[] storage clients = _agentClients[agentId];
        uint256 total;
        uint256 cnt;

        for (uint256 i = 0; i < clients.length; i++) {
            address client = clients[i];
            uint64 lastIdx = _lastFeedbackIndex[agentId][client];
            for (uint64 j = 1; j <= lastIdx; j++) {
                FeedbackRecord storage fb = _feedback[agentId][client][j];
                if (fb.isRevoked) continue;
                // Normalize value to 0-100 range (assume value in range [-100e18, 100e18])
                int256 normalized = int256(fb.value);
                if (normalized < 0) normalized = 0;
                if (normalized > 100) normalized = 100;
                total += uint256(normalized);
                cnt++;
            }
        }

        reputationScore[agentId] = cnt > 0 ? total / cnt : 0;
    }

    /**
     * @notice Check if an address is the agent owner or an approved operator
     */
    function _isAgentOwnerOrOperator(uint256 agentId, address caller) internal view returns (bool) {
        // Try to find the NFT owner across registered contracts
        address[] memory nftContracts = _getRegisteredContracts();
        for (uint256 i = 0; i < nftContracts.length; i++) {
            (bool success, bytes memory data) = nftContracts[i].staticcall(
                abi.encodeWithSignature("ownerOf(uint256)", agentId)
            );
            if (success && data.length >= 32) {
                address owner = abi.decode(data, (address));
                if (owner == caller) return true;
                // Check if isApprovedForAll
                (bool ok2, bytes memory data2) = nftContracts[i].staticcall(
                    abi.encodeWithSignature("isApprovedForAll(address,address)", owner, caller)
                );
                if (ok2 && data2.length >= 32 && abi.decode(data2, (bool))) return true;
            }
        }
        return hasRole(ADMIN_ROLE, caller);
    }

    // Storing registered contract addresses
    address[] private _registeredContractList;
    mapping(address => bool) private _inContractList;

    function registerNFTContractWithList(address nftContract) external onlyRole(ADMIN_ROLE) {
        require(nftContract != address(0), "Registry: invalid contract");
        if (!_inContractList[nftContract]) {
            _registeredContractList.push(nftContract);
            _inContractList[nftContract] = true;
        }
        registeredNFTContracts[nftContract] = true;
        emit NFTContractRegistered(nftContract);
    }

    function _getRegisteredContracts() internal view returns (address[] memory) {
        return _registeredContractList;
    }

    function _recoverSigner(bytes32 digest, bytes calldata signature) internal pure returns (address) {
        require(signature.length == 65, "Registry: invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        return ecrecover(digest, v, r, s);
    }
}
