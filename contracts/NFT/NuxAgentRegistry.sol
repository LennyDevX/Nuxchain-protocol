// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../interfaces/INuxAgentNFT.sol";

/**
 * @title NuxAgentRegistry
 * @notice On-chain registry for NuxChain AI agents implementing ERC-8004 (Trustless Agents)
 * @dev All agent state is keyed by the composite identity (nftContract, tokenId).
 *      This avoids collisions across category collections that can mint the same tokenId.
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
 *   - getReputationScore() is used by the marketplace to display agent quality
 */
contract NuxAgentRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    // ============================================
    // ROLES
    // ============================================
    bytes32 public constant ADMIN_ROLE     = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE  = keccak256("UPGRADER_ROLE");
    bytes32 public constant GAME_ROLE      = keccak256("GAME_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    // ============================================
    // STRUCTS
    // ============================================

    struct AgentMetadata {
        address agentWallet;
        uint256 totalTasksRun;
        uint256 totalRevenueEarned;
        uint256 spendingLimitDaily;
        uint256 spentToday;
        uint256 spentDayReset;
        bool    x402Enabled;
        string  mcpEndpoint;
        string  a2aEndpoint;
    }

    struct FeedbackRecord {
        address clientAddress;
        int128  value;
        uint8   valueDecimals;
        string  tag1;
        string  tag2;
        bool    isRevoked;
        uint256 timestamp;
    }

    struct ValidationRecord {
        address validatorAddress;
        address nftContract;
        uint256 tokenId;
        uint8   response;
        bytes32 responseHash;
        string  tag;
        uint256 lastUpdate;
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

    struct AgentPerformanceSnapshot {
        uint256 totalTasksRun;
        uint256 totalRevenueEarned;
        uint256 averageRevenuePerTask;
        uint256 currentReputationScore;
        uint256 totalClients;
        uint256 totalFeedbackCount;
        uint256 activeFeedbackCount;
        uint256 revokedFeedbackCount;
        uint256 validationCount;
        uint256 spendingLimitDaily;
        uint256 spentToday;
        uint256 remainingDailySpend;
        bool    x402Enabled;
    }

    // ============================================
    // STATE — IDENTITY
    // ============================================
    mapping(address => bool) public registeredNFTContracts;
    mapping(address => mapping(uint256 => AgentMetadata)) public agentMetadata;
    mapping(address => mapping(uint256 => mapping(string => bytes))) private _onChainMetadata;
    string private constant RESERVED_AGENT_WALLET_KEY = "agentWallet";

    // ============================================
    // STATE — REPUTATION REGISTRY (ERC-8004)
    // ============================================
    mapping(address => mapping(uint256 => mapping(address => mapping(uint64 => FeedbackRecord)))) private _feedback;
    mapping(address => mapping(uint256 => mapping(address => uint64))) private _lastFeedbackIndex;
    mapping(address => mapping(uint256 => address[])) private _agentClients;
    mapping(address => mapping(uint256 => mapping(address => bool))) private _clientTracked;
    mapping(address => mapping(uint256 => uint256)) public reputationScore;

    // ============================================
    // STATE — VALIDATION REGISTRY (ERC-8004)
    // ============================================
    mapping(bytes32 => ValidationRecord) private _validations;
    mapping(address => mapping(uint256 => bytes32[])) private _agentValidations;
    mapping(address => bytes32[]) private _validatorRequests;

    // ============================================
    // EVENTS — REPUTATION (ERC-8004)
    // ============================================
    event NewFeedback(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed clientAddress,
        uint64  feedbackIndex,
        int128  value,
        uint8   valueDecimals,
        string  tag1,
        string  tag2
    );
    event FeedbackRevoked(address indexed nftContract, uint256 indexed tokenId, address indexed clientAddress, uint64 feedbackIndex);
    event ResponseAppended(address indexed nftContract, uint256 indexed tokenId, address indexed clientAddress, uint64 feedbackIndex, address responder);

    // ============================================
    // EVENTS — VALIDATION (ERC-8004)
    // ============================================
    event ValidationRequest(
        address indexed validatorAddress,
        address indexed nftContract,
        uint256 indexed tokenId,
        string requestURI,
        bytes32 requestHash
    );
    event ValidationResponse(
        address indexed validatorAddress,
        address indexed nftContract,
        uint256 indexed tokenId,
        bytes32 requestHash,
        uint8 response,
        string tag
    );

    // ============================================
    // EVENTS — IDENTITY
    // ============================================
    event AgentMetadataSet(address indexed nftContract, uint256 indexed tokenId, string indexed metadataKey, bytes metadataValue);
    event AgentWalletSet(address indexed nftContract, uint256 indexed tokenId, address indexed newWallet);
    event AgentWalletCleared(address indexed nftContract, uint256 indexed tokenId);
    event NFTContractRegistered(address indexed nftContract);
    event TaskExecutionRecorded(address indexed nftContract, uint256 indexed tokenId, address indexed executor, uint256 rewardPaid);
    event SpendingLimitUpdated(address indexed nftContract, uint256 indexed tokenId, uint256 newDailyLimit);

    // ============================================
    // EIP-712 DOMAIN SEPARATOR for agentWallet signature
    // ============================================
    bytes32 private _domainSeparator;
    bytes32 private constant SET_WALLET_TYPEHASH = keccak256(
        "SetAgentWallet(address nftContract,uint256 tokenId,address newWallet,uint256 deadline)"
    );

    // Storing registered contract addresses
    address[] private _registeredContractList;
    mapping(address => bool) private _inContractList;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin_) public initializer {
        require(admin_ != address(0), "Registry: invalid admin");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

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

    uint256[50] private __gap;

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ============================================
    // IDENTITY REGISTRY — ADMIN
    // ============================================

    function registerNFTContract(address nftContract) external onlyRole(ADMIN_ROLE) {
        _registerNFTContract(nftContract);
    }

    function registerNFTContractWithList(address nftContract) external onlyRole(ADMIN_ROLE) {
        _registerNFTContract(nftContract);
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

    function setMetadata(
        address nftContract,
        uint256 tokenId,
        string calldata metadataKey,
        bytes calldata metadataValue
    ) external {
        require(_isAgentOwnerOrOperator(nftContract, tokenId, msg.sender), "Registry: not authorized");
        require(
            keccak256(bytes(metadataKey)) != keccak256(bytes(RESERVED_AGENT_WALLET_KEY)),
            "Registry: agentWallet is reserved"
        );
        _onChainMetadata[nftContract][tokenId][metadataKey] = metadataValue;
        emit AgentMetadataSet(nftContract, tokenId, metadataKey, metadataValue);
    }

    function getMetadata(
        address nftContract,
        uint256 tokenId,
        string calldata metadataKey
    ) external view returns (bytes memory) {
        return _onChainMetadata[nftContract][tokenId][metadataKey];
    }

    function configureAgent(
        address nftContract,
        uint256 tokenId,
        uint256 dailySpendingLimit,
        bool    x402Enabled,
        string calldata mcpEndpoint,
        string calldata a2aEndpoint
    ) external {
        require(_isAgentOwnerOrOperator(nftContract, tokenId, msg.sender), "Registry: not authorized");
        AgentMetadata storage meta = agentMetadata[nftContract][tokenId];
        meta.spendingLimitDaily = dailySpendingLimit;
        meta.x402Enabled        = x402Enabled;
        meta.mcpEndpoint        = mcpEndpoint;
        meta.a2aEndpoint        = a2aEndpoint;
        emit SpendingLimitUpdated(nftContract, tokenId, dailySpendingLimit);
    }

    // ============================================
    // IDENTITY REGISTRY — AGENT WALLET (ERC-8004)
    // ============================================

    function setAgentWallet(
        address nftContract,
        uint256 tokenId,
        address newWallet,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(_isAgentOwnerOrOperator(nftContract, tokenId, msg.sender), "Registry: not authorized");
        require(block.timestamp <= deadline, "Registry: signature expired");
        require(newWallet != address(0), "Registry: invalid wallet");

        bytes32 structHash = keccak256(abi.encode(SET_WALLET_TYPEHASH, nftContract, tokenId, newWallet, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, structHash));

        address recovered = _recoverSigner(digest, signature);
        require(recovered == newWallet, "Registry: invalid signature");

        agentMetadata[nftContract][tokenId].agentWallet = newWallet;
        emit AgentWalletSet(nftContract, tokenId, newWallet);
    }

    function getAgentWallet(address nftContract, uint256 tokenId) external view returns (address) {
        return agentMetadata[nftContract][tokenId].agentWallet;
    }

    function unsetAgentWallet(address nftContract, uint256 tokenId) external {
        require(_isAgentOwnerOrOperator(nftContract, tokenId, msg.sender), "Registry: not authorized");
        delete agentMetadata[nftContract][tokenId].agentWallet;
        emit AgentWalletCleared(nftContract, tokenId);
    }

    // ============================================
    // REPUTATION REGISTRY (ERC-8004)
    // ============================================

    function giveFeedback(
        address nftContract,
        uint256 tokenId,
        int128  value,
        uint8   valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external nonReentrant {
        require(valueDecimals <= 18, "Registry: invalid valueDecimals");
        require(!_isAgentOwnerOrOperator(nftContract, tokenId, msg.sender), "Registry: owner cannot give feedback");

        uint64 newIndex = _lastFeedbackIndex[nftContract][tokenId][msg.sender] + 1;
        _lastFeedbackIndex[nftContract][tokenId][msg.sender] = newIndex;

        _feedback[nftContract][tokenId][msg.sender][newIndex] = FeedbackRecord({
            clientAddress: msg.sender,
            value: value,
            valueDecimals: valueDecimals,
            tag1: tag1,
            tag2: tag2,
            isRevoked: false,
            timestamp: block.timestamp
        });

        if (!_clientTracked[nftContract][tokenId][msg.sender]) {
            _agentClients[nftContract][tokenId].push(msg.sender);
            _clientTracked[nftContract][tokenId][msg.sender] = true;
        }

        _updateReputationScore(nftContract, tokenId);

        emit NewFeedback(nftContract, tokenId, msg.sender, newIndex, value, valueDecimals, tag1, tag2);

        if (feedbackHash != bytes32(0)) {}
        if (bytes(feedbackURI).length != 0) {}
    }

    function revokeFeedback(address nftContract, uint256 tokenId, uint64 feedbackIndex) external {
        require(
            _feedback[nftContract][tokenId][msg.sender][feedbackIndex].clientAddress == msg.sender,
            "Registry: not feedback owner"
        );
        _feedback[nftContract][tokenId][msg.sender][feedbackIndex].isRevoked = true;
        _updateReputationScore(nftContract, tokenId);
        emit FeedbackRevoked(nftContract, tokenId, msg.sender, feedbackIndex);
    }

    function getSummary(
        address nftContract,
        uint256 tokenId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2
    ) external view returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals) {
        require(clientAddresses.length > 0, "Registry: must provide clientAddresses (anti-Sybil)");

        bool filterTag1 = bytes(tag1).length > 0;
        bool filterTag2 = bytes(tag2).length > 0;

        for (uint256 i = 0; i < clientAddresses.length; i++) {
            address client = clientAddresses[i];
            uint64 lastIdx = _lastFeedbackIndex[nftContract][tokenId][client];
            for (uint64 j = 1; j <= lastIdx; j++) {
                FeedbackRecord storage fb = _feedback[nftContract][tokenId][client][j];
                if (fb.isRevoked) continue;
                if (filterTag1 && keccak256(bytes(fb.tag1)) != keccak256(bytes(tag1))) continue;
                if (filterTag2 && keccak256(bytes(fb.tag2)) != keccak256(bytes(tag2))) continue;
                summaryValue += fb.value;
                summaryValueDecimals = fb.valueDecimals;
                count++;
            }
        }
    }

    function readFeedback(
        address nftContract,
        uint256 tokenId,
        address clientAddress,
        uint64  feedbackIndex
    ) external view returns (int128 value, uint8 valueDecimals, string memory tag1, string memory tag2, bool isRevoked) {
        FeedbackRecord storage fb = _feedback[nftContract][tokenId][clientAddress][feedbackIndex];
        return (fb.value, fb.valueDecimals, fb.tag1, fb.tag2, fb.isRevoked);
    }

    function getClients(address nftContract, uint256 tokenId) external view returns (address[] memory) {
        return _agentClients[nftContract][tokenId];
    }

    function getLastIndex(address nftContract, uint256 tokenId, address clientAddress) external view returns (uint64) {
        return _lastFeedbackIndex[nftContract][tokenId][clientAddress];
    }

    // ============================================
    // VALIDATION REGISTRY (ERC-8004)
    // ============================================

    function validationRequest(
        address validatorAddress,
        address nftContract,
        uint256 tokenId,
        string calldata requestURI,
        bytes32 requestHash
    ) external returns (bytes32) {
        require(_isAgentOwnerOrOperator(nftContract, tokenId, msg.sender), "Registry: not authorized");
        require(validatorAddress != address(0), "Registry: invalid validator");
        require(requestHash != bytes32(0), "Registry: invalid request hash");
        require(_validations[requestHash].validatorAddress == address(0), "Registry: request already exists");

        _validations[requestHash] = ValidationRecord({
            validatorAddress: validatorAddress,
            nftContract: nftContract,
            tokenId: tokenId,
            response: 0,
            responseHash: bytes32(0),
            tag: "",
            lastUpdate: block.timestamp
        });
        _agentValidations[nftContract][tokenId].push(requestHash);
        _validatorRequests[validatorAddress].push(requestHash);

        emit ValidationRequest(validatorAddress, nftContract, tokenId, requestURI, requestHash);
        return requestHash;
    }

    function validationResponse(
        bytes32 requestHash,
        uint8   response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external {
        require(hasRole(VALIDATOR_ROLE, msg.sender), "Registry: not a validator");

        ValidationRecord storage rec = _validations[requestHash];
        require(rec.validatorAddress != address(0), "Registry: unknown request");
        require(rec.validatorAddress == msg.sender, "Registry: wrong validator");

        rec.response = response;
        rec.responseHash = responseHash;
        rec.tag = tag;
        rec.lastUpdate = block.timestamp;

        emit ValidationResponse(msg.sender, rec.nftContract, rec.tokenId, requestHash, response, tag);

        if (bytes(responseURI).length != 0) {}
    }

    function getValidationStatus(bytes32 requestHash) external view returns (
        address validatorAddress,
        address nftContract,
        uint256 tokenId,
        uint8   response,
        bytes32 responseHash,
        string memory tag,
        uint256 lastUpdate
    ) {
        ValidationRecord storage rec = _validations[requestHash];
        return (rec.validatorAddress, rec.nftContract, rec.tokenId, rec.response, rec.responseHash, rec.tag, rec.lastUpdate);
    }

    function getAgentValidations(address nftContract, uint256 tokenId) external view returns (bytes32[] memory) {
        return _agentValidations[nftContract][tokenId];
    }

    function getValidatorRequests(address validatorAddress) external view returns (bytes32[] memory) {
        return _validatorRequests[validatorAddress];
    }

    function getAgentOperationalProfile(
        address nftContract,
        uint256 tokenId
    ) external view returns (AgentOperationalProfile memory profile) {
        AgentMetadata storage meta = agentMetadata[nftContract][tokenId];
        profile.agentWallet = meta.agentWallet;
        profile.totalTasksRun = meta.totalTasksRun;
        profile.totalRevenueEarned = meta.totalRevenueEarned;
        profile.spendingLimitDaily = meta.spendingLimitDaily;
        profile.spentToday = meta.spentToday;
        profile.spentDayReset = meta.spentDayReset;
        profile.x402Enabled = meta.x402Enabled;
        profile.mcpEndpoint = meta.mcpEndpoint;
        profile.a2aEndpoint = meta.a2aEndpoint;
        profile.currentReputationScore = reputationScore[nftContract][tokenId];
        profile.clientCount = _agentClients[nftContract][tokenId].length;
        profile.validationCount = _agentValidations[nftContract][tokenId].length;
    }

    function getFeedbackStats(
        address nftContract,
        uint256 tokenId
    ) external view returns (
        uint256 currentReputationScore,
        uint256 totalClients,
        uint256 totalFeedbackCount,
        uint256 activeFeedbackCount,
        uint256 revokedFeedbackCount
    ) {
        address[] storage clients = _agentClients[nftContract][tokenId];
        totalClients = clients.length;

        for (uint256 i = 0; i < clients.length; i++) {
            uint64 lastIdx = _lastFeedbackIndex[nftContract][tokenId][clients[i]];
            totalFeedbackCount += lastIdx;
            for (uint64 j = 1; j <= lastIdx; j++) {
                if (_feedback[nftContract][tokenId][clients[i]][j].isRevoked) {
                    revokedFeedbackCount++;
                } else {
                    activeFeedbackCount++;
                }
            }
        }

        currentReputationScore = reputationScore[nftContract][tokenId];
    }

    function getAgentPerformanceSnapshot(
        address nftContract,
        uint256 tokenId
    ) external view returns (AgentPerformanceSnapshot memory snapshot) {
        AgentMetadata storage meta = agentMetadata[nftContract][tokenId];
        address[] storage clients = _agentClients[nftContract][tokenId];

        snapshot.totalTasksRun = meta.totalTasksRun;
        snapshot.totalRevenueEarned = meta.totalRevenueEarned;
        snapshot.averageRevenuePerTask = meta.totalTasksRun > 0 ? meta.totalRevenueEarned / meta.totalTasksRun : 0;
        snapshot.currentReputationScore = reputationScore[nftContract][tokenId];
        snapshot.totalClients = clients.length;
        snapshot.validationCount = _agentValidations[nftContract][tokenId].length;
        snapshot.spendingLimitDaily = meta.spendingLimitDaily;
        snapshot.spentToday = meta.spentToday;
        snapshot.remainingDailySpend = meta.spendingLimitDaily > meta.spentToday
            ? meta.spendingLimitDaily - meta.spentToday
            : 0;
        snapshot.x402Enabled = meta.x402Enabled;

        for (uint256 i = 0; i < clients.length; i++) {
            uint64 lastIdx = _lastFeedbackIndex[nftContract][tokenId][clients[i]];
            snapshot.totalFeedbackCount += lastIdx;
            for (uint64 j = 1; j <= lastIdx; j++) {
                if (_feedback[nftContract][tokenId][clients[i]][j].isRevoked) {
                    snapshot.revokedFeedbackCount++;
                } else {
                    snapshot.activeFeedbackCount++;
                }
            }
        }
    }

    function getClientFeedbackPage(
        address nftContract,
        uint256 tokenId,
        address clientAddress,
        uint64 offset,
        uint64 limit
    ) external view returns (FeedbackRecord[] memory feedbackRecords, uint64 total) {
        total = _lastFeedbackIndex[nftContract][tokenId][clientAddress];
        if (limit == 0 || offset >= total) {
            return (new FeedbackRecord[](0), total);
        }

        uint64 end = offset + limit;
        if (end > total) end = total;

        feedbackRecords = new FeedbackRecord[](end - offset);
        uint64 index;
        for (uint64 feedbackIndex = offset + 1; feedbackIndex <= end; feedbackIndex++) {
            feedbackRecords[index] = _feedback[nftContract][tokenId][clientAddress][feedbackIndex];
            index++;
        }
    }

    // ============================================
    // TASK EXECUTION TRACKING (MiniGame integration)
    // ============================================

    function recordTaskExecution(
        address nftContract,
        uint256 tokenId,
        address executor,
        uint256 rewardPaid
    ) external onlyRole(GAME_ROLE) {
        agentMetadata[nftContract][tokenId].totalTasksRun++;
        agentMetadata[nftContract][tokenId].totalRevenueEarned += rewardPaid;
        emit TaskExecutionRecorded(nftContract, tokenId, executor, rewardPaid);
    }

    function authorizeSpend(address nftContract, uint256 tokenId, uint256 amount) external returns (bool) {
        AgentMetadata storage meta = agentMetadata[nftContract][tokenId];

        if (block.timestamp >= meta.spentDayReset + 1 days) {
            meta.spentToday = 0;
            meta.spentDayReset = block.timestamp;
        }

        uint256 limit = meta.spendingLimitDaily;
        if (limit == 0) return true;

        if (meta.spentToday + amount > limit) return false;
        meta.spentToday += amount;
        return true;
    }

    // ============================================
    // INTERNAL HELPERS
    // ============================================

    function _registerNFTContract(address nftContract) internal {
        require(nftContract != address(0), "Registry: invalid contract");
        if (!_inContractList[nftContract]) {
            _registeredContractList.push(nftContract);
            _inContractList[nftContract] = true;
        }
        registeredNFTContracts[nftContract] = true;
        emit NFTContractRegistered(nftContract);
    }

    function _updateReputationScore(address nftContract, uint256 tokenId) internal {
        address[] storage clients = _agentClients[nftContract][tokenId];
        uint256 total;
        uint256 cnt;

        for (uint256 i = 0; i < clients.length; i++) {
            address client = clients[i];
            uint64 lastIdx = _lastFeedbackIndex[nftContract][tokenId][client];
            for (uint64 j = 1; j <= lastIdx; j++) {
                FeedbackRecord storage fb = _feedback[nftContract][tokenId][client][j];
                if (fb.isRevoked) continue;
                int256 normalized = int256(fb.value);
                if (normalized < 0) normalized = 0;
                if (normalized > 100) normalized = 100;
                total += uint256(normalized);
                cnt++;
            }
        }

        reputationScore[nftContract][tokenId] = cnt > 0 ? total / cnt : 0;
    }

    function _isAgentOwnerOrOperator(address nftContract, uint256 tokenId, address caller) internal view returns (bool) {
        if (hasRole(ADMIN_ROLE, caller)) {
            return true;
        }

        if (!registeredNFTContracts[nftContract]) {
            return false;
        }

        (bool success, bytes memory data) = nftContract.staticcall(
            abi.encodeWithSignature("ownerOf(uint256)", tokenId)
        );
        if (!success || data.length < 32) {
            return false;
        }

        address owner = abi.decode(data, (address));
        if (owner == caller) {
            return true;
        }

        (bool approvedForAllOk, bytes memory approvedForAllData) = nftContract.staticcall(
            abi.encodeWithSignature("isApprovedForAll(address,address)", owner, caller)
        );
        if (approvedForAllOk && approvedForAllData.length >= 32 && abi.decode(approvedForAllData, (bool))) {
            return true;
        }

        (bool approvedOk, bytes memory approvedData) = nftContract.staticcall(
            abi.encodeWithSignature("getApproved(uint256)", tokenId)
        );
        return approvedOk && approvedData.length >= 32 && abi.decode(approvedData, (address)) == caller;
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