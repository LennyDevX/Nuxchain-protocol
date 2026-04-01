// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface INFTOwnerQuery {
    function ownerOf(uint256 tokenId) external view returns (address);
    function getTokenBoundAccount(uint256 tokenId) external view returns (address);
}

interface ITreasuryReceiver {
    function receiveRevenue(string calldata revenueType) external payable;
}

/**
 * @title NuxAgentPaymaster
 * @notice x402-inspired micropayment system for AI Agent task execution
 * @dev
 *   Inspired by the x402 HTTP-native payment protocol (https://www.x402.org).
 *   This contract acts as the payment hub for agent tasks, allowing agents to
 *   autonomously spend within pre-authorized budgets — making it compatible
 *   with ERC-8004 proof-of-payment in reputation feedback.
 *
 * ARCHITECTURE:
 *   1. Owner deposits ETH into agent's budget (scoped by nftContract + tokenId)
 *   2. Owner (or agent's TBA) creates spending authorizations per service provider
 *   3. Service providers execute authorized payments off-chain, then prove execution
 *   4. On-chain: Paymaster verifies and settles the payment from agent's balance
 *   5. A PaymentReceipt is emitted — compatible with ERC-8004 feedback x402 proof
 *
 * x402 COMPATIBILITY:
 *   The contract emits standardized PaymentReceipt events that include:
 *     - X-PAYMENT resource URI (as resourceURI)
 *     - amount and currency (native ETH normalized)
 *     - payer agent identity (nftContract + tokenId)
 *   This receipt hash can be included as the `x402Proof` in ERC-8004 giveFeedback().
 *
 * SPENDING POLICIES:
 *   - Per-agent daily spending limit
 *   - Per-task max amount cap
 *   - Allowlisted service provider addresses
 *   - Deadline on each authorization
 *
 * SECURITY:
 *   - Authorization uses EIP-712 typed data signed by the NFT owner
 *   - The same authorization nonce cannot be reused
 *   - Revoked authorizations cannot be executed
 */
contract NuxAgentPaymaster is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using ECDSA for bytes32;

    // ============================================
    // ROLES
    // ============================================
    bytes32 public constant ADMIN_ROLE    = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ============================================
    // EIP-712
    // ============================================
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant AUTHORIZATION_TYPEHASH = keccak256(
        "PaymentAuthorization(address nftContract,uint256 tokenId,address provider,uint256 maxAmount,string resourceURI,uint256 nonce,uint256 deadline)"
    );

    // ============================================
    // STATE
    // ============================================

    struct SpendingPolicy {
        uint256 dailyLimit;       // Max spend per day across all providers
        uint256 perTaskLimit;     // Max per single task
        uint256 spentToday;
        uint256 dayReset;         // UTC day of last reset
        address[] allowedProviders; // Empty = all providers allowed
    }

    struct PaymentAuthorization {
        address  nftContract;
        uint256  tokenId;
        address  provider;
        uint256  maxAmount;
        string   resourceURI;     // x402 resource identifier
        uint256  nonce;
        uint256  deadline;
        bool     executed;
        bool     revoked;
    }

    struct AgentBudgetStatus {
        uint256 balance;
        uint256 nextNonce;
        uint256 dailyLimit;
        uint256 perTaskLimit;
        uint256 spentToday;
        uint256 remainingDailyBudget;
        uint256 dayReset;
    }

    // nftContract → tokenId → ETH balance
    mapping(address => mapping(uint256 => uint256))  public agentBalances;
    // nftContract → tokenId → SpendingPolicy
    mapping(address => mapping(uint256 => SpendingPolicy)) public spendingPolicies;
    // authorizationId → PaymentAuthorization
    mapping(bytes32 => PaymentAuthorization)          public authorizations;
    // nftContract → tokenId → nonce tracker
    mapping(address => mapping(uint256 => uint256))   public agentNonces;

    uint256 public protocolFeeBps;  // Protocol fee taken from each payment (default 100 = 1%)
    address public feeCollector;

    // ============================================
    // EVENTS
    // ============================================
    event AgentFunded(address indexed nftContract, uint256 indexed tokenId, uint256 amount, address depositor);
    event AgentWithdrawal(address indexed nftContract, uint256 indexed tokenId, uint256 amount, address recipient);
    event AuthorizationCreated(bytes32 indexed authId, address indexed nftContract, uint256 indexed tokenId, address provider, uint256 maxAmount);
    event AuthorizationRevoked(bytes32 indexed authId);
    event PaymentExecuted(bytes32 indexed authId, address indexed provider, uint256 amount, string resourceURI);
    event PaymentReceipt(
        bytes32 indexed receiptHash,
        address indexed nftContract,
        uint256 indexed tokenId,
        address provider,
        uint256 amount,
        string  resourceURI,
        uint256 timestamp
    );
    event SpendingPolicyUpdated(address indexed nftContract, uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address feeCollector_
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);

        feeCollector    = feeCollector_;
        protocolFeeBps  = 100; // 1%

        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("NuxAgentPaymaster"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    // ============================================
    // DEPOSIT / WITHDRAW
    // ============================================

    /**
     * @notice Fund an agent's payment budget
     */
    function depositForAgent(
        address nftContract,
        uint256 tokenId
    ) external payable {
        require(msg.value > 0, "Paymaster: zero deposit");
        agentBalances[nftContract][tokenId] += msg.value;
        emit AgentFunded(nftContract, tokenId, msg.value, msg.sender);
    }

    /**
     * @notice Withdraw unused agent budget (owner only)
     */
    function withdrawAgentBalance(
        address nftContract,
        uint256 tokenId,
        uint256 amount
    ) external nonReentrant {
        require(
            INFTOwnerQuery(nftContract).ownerOf(tokenId) == msg.sender,
            "Paymaster: not agent owner"
        );
        require(agentBalances[nftContract][tokenId] >= amount, "Paymaster: insufficient balance");
        agentBalances[nftContract][tokenId] -= amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Paymaster: withdrawal failed");
        emit AgentWithdrawal(nftContract, tokenId, amount, msg.sender);
    }

    // ============================================
    // SPENDING POLICY
    // ============================================

    /**
     * @notice Configure spending limits for an agent
     * @param allowedProviders Pass empty array to allow any provider
     */
    function setSpendingPolicy(
        address nftContract,
        uint256 tokenId,
        uint256 dailyLimit,
        uint256 perTaskLimit,
        address[] calldata allowedProviders
    ) external {
        require(
            INFTOwnerQuery(nftContract).ownerOf(tokenId) == msg.sender,
            "Paymaster: not agent owner"
        );

        SpendingPolicy storage policy = spendingPolicies[nftContract][tokenId];
        policy.dailyLimit        = dailyLimit;
        policy.perTaskLimit      = perTaskLimit;
        delete policy.allowedProviders;
        for (uint256 i; i < allowedProviders.length; i++)
            policy.allowedProviders.push(allowedProviders[i]);

        emit SpendingPolicyUpdated(nftContract, tokenId);
    }

    // ============================================
    // AUTHORIZATION
    // ============================================

    /**
     * @notice Create a signed payment authorization (owner signs off-chain, authorized caller submits)
     * @dev   The signature is over the EIP-712 PaymentAuthorization typehash.
     *        The agent's TBA or the owner itself can create authorizations.
     */
    function createAuthorization(
        address  nftContract,
        uint256  tokenId,
        address  provider,
        uint256  maxAmount,
        string   calldata resourceURI,
        uint256  deadline,
        bytes    calldata signature
    ) external returns (bytes32 authId) {
        require(deadline > block.timestamp, "Paymaster: authorization expired");
        require(provider != address(0), "Paymaster: invalid provider");

        address owner_ = INFTOwnerQuery(nftContract).ownerOf(tokenId);
        address tba    = INFTOwnerQuery(nftContract).getTokenBoundAccount(tokenId);
        uint256 nonce  = agentNonces[nftContract][tokenId];

        // Recover signer from EIP-712 signature
        bytes32 structHash = keccak256(abi.encode(
            AUTHORIZATION_TYPEHASH,
            nftContract,
            tokenId,
            provider,
            maxAmount,
            keccak256(bytes(resourceURI)),
            nonce,
            deadline
        ));
        bytes32 digest  = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address signer  = digest.recover(signature);
        require(signer == owner_ || signer == tba, "Paymaster: invalid signature");

        agentNonces[nftContract][tokenId]++;

        authId = keccak256(abi.encode(nftContract, tokenId, nonce));
        authorizations[authId] = PaymentAuthorization({
            nftContract: nftContract,
            tokenId:     tokenId,
            provider:    provider,
            maxAmount:   maxAmount,
            resourceURI: resourceURI,
            nonce:       nonce,
            deadline:    deadline,
            executed:    false,
            revoked:     false
        });

        emit AuthorizationCreated(authId, nftContract, tokenId, provider, maxAmount);
    }

    /**
     * @notice Revoke an unused authorization (owner only)
     */
    function revokeAuthorization(bytes32 authId) external {
        PaymentAuthorization storage auth = authorizations[authId];
        address owner_ = INFTOwnerQuery(auth.nftContract).ownerOf(auth.tokenId);
        require(msg.sender == owner_, "Paymaster: not agent owner");
        require(!auth.executed, "Paymaster: already executed");
        auth.revoked = true;
        emit AuthorizationRevoked(authId);
    }

    // ============================================
    // PAYMENT EXECUTION
    // ============================================

    /**
     * @notice Execute a payment for a completed task (provider calls this)
     * @param authId    The authorization ID
     * @param amount    Actual amount to claim (must be <= maxAmount)
     */
    function executePayment(
        bytes32 authId,
        uint256 amount
    ) external nonReentrant {
        PaymentAuthorization storage auth = authorizations[authId];
        require(!auth.executed, "Paymaster: already executed");
        require(!auth.revoked, "Paymaster: revoked");
        require(block.timestamp <= auth.deadline, "Paymaster: expired");
        require(auth.provider == msg.sender, "Paymaster: not authorized provider");
        require(amount <= auth.maxAmount, "Paymaster: exceeds authorization");

        // Check spending policy
        _enforceSpendingPolicy(auth.nftContract, auth.tokenId, auth.provider, amount);

        // Check balance
        require(agentBalances[auth.nftContract][auth.tokenId] >= amount, "Paymaster: insufficient agent balance");

        auth.executed = true;
        agentBalances[auth.nftContract][auth.tokenId] -= amount;

        // Protocol fee
        uint256 fee         = (amount * protocolFeeBps) / 10000;
        uint256 netPayment  = amount - fee;

        if (fee > 0 && feeCollector != address(0)) {
            // Try treasury interface first (labels revenue type); fallback to direct transfer
            try ITreasuryReceiver(feeCollector).receiveRevenue{value: fee}("paymaster_fee") {
            } catch {
                (bool feeOk, ) = payable(feeCollector).call{value: fee}("");
                require(feeOk, "Paymaster: fee transfer failed");
            }
        }

        (bool providerOk, ) = payable(msg.sender).call{value: netPayment}("");
        require(providerOk, "Paymaster: provider payment failed");

        bytes32 receiptHash = keccak256(abi.encode(authId, amount, block.timestamp));

        emit PaymentExecuted(authId, msg.sender, amount, auth.resourceURI);
        emit PaymentReceipt(
            receiptHash,
            auth.nftContract,
            auth.tokenId,
            msg.sender,
            amount,
            auth.resourceURI,
            block.timestamp
        );
    }

    function _enforceSpendingPolicy(
        address nftContract,
        uint256 tokenId,
        address provider,
        uint256 amount
    ) internal {
        SpendingPolicy storage policy = spendingPolicies[nftContract][tokenId];

        // Check per-task limit
        if (policy.perTaskLimit > 0)
            require(amount <= policy.perTaskLimit, "Paymaster: exceeds per-task limit");

        // Reset daily tracking if needed
        uint256 today = block.timestamp / 1 days;
        if (today > policy.dayReset) {
            policy.spentToday = 0;
            policy.dayReset   = today;
        }

        // Check daily limit
        if (policy.dailyLimit > 0)
            require(policy.spentToday + amount <= policy.dailyLimit, "Paymaster: daily limit exceeded");

        policy.spentToday += amount;

        // Check allowed providers (empty list = all allowed)
        if (policy.allowedProviders.length > 0) {
            bool found;
            for (uint256 i; i < policy.allowedProviders.length; i++) {
                if (policy.allowedProviders[i] == provider) { found = true; break; }
            }
            require(found, "Paymaster: provider not allowed");
        }
    }

    // ============================================
    // ADMIN
    // ============================================

    function setProtocolFee(uint256 feeBps) external onlyRole(ADMIN_ROLE) {
        require(feeBps <= 500, "Paymaster: fee too high"); // max 5%
        protocolFeeBps = feeBps;
    }

    function setFeeCollector(address fc) external onlyRole(ADMIN_ROLE) {
        require(fc != address(0), "Paymaster: invalid address");
        feeCollector = fc;
    }

    uint256[50] private __gap;

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ============================================
    // VIEW
    // ============================================

    function getAgentBalance(address nftContract, uint256 tokenId) external view returns (uint256) {
        return agentBalances[nftContract][tokenId];
    }

    function getNextNonce(address nftContract, uint256 tokenId) external view returns (uint256) {
        return agentNonces[nftContract][tokenId];
    }

    function isAuthorizationValid(bytes32 authId) external view returns (bool) {
        PaymentAuthorization storage auth = authorizations[authId];
        return !auth.executed && !auth.revoked && block.timestamp <= auth.deadline;
    }

    function getSpendingPolicy(
        address nftContract,
        uint256 tokenId
    ) external view returns (
        uint256 dailyLimit,
        uint256 perTaskLimit,
        uint256 spentToday,
        uint256 dayReset,
        address[] memory allowedProviders
    ) {
        SpendingPolicy storage policy = spendingPolicies[nftContract][tokenId];
        return (
            policy.dailyLimit,
            policy.perTaskLimit,
            policy.spentToday,
            policy.dayReset,
            policy.allowedProviders
        );
    }

    function getAuthorization(bytes32 authId) external view returns (PaymentAuthorization memory) {
        return authorizations[authId];
    }

    function getAgentBudgetStatus(address nftContract, uint256 tokenId) external view returns (AgentBudgetStatus memory status) {
        SpendingPolicy storage policy = spendingPolicies[nftContract][tokenId];
        uint256 spentToday = policy.spentToday;
        uint256 today = block.timestamp / 1 days;

        if (today > policy.dayReset) {
            spentToday = 0;
        }

        status.balance = agentBalances[nftContract][tokenId];
        status.nextNonce = agentNonces[nftContract][tokenId];
        status.dailyLimit = policy.dailyLimit;
        status.perTaskLimit = policy.perTaskLimit;
        status.spentToday = spentToday;
        status.remainingDailyBudget = policy.dailyLimit > spentToday ? policy.dailyLimit - spentToday : 0;
        status.dayReset = policy.dayReset;
    }
}
