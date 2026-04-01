// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../NuxAgentNFTBase.sol";

/**
 * @title TechAgentNFT
 * @notice AI Agent NFTs specialized for Technology & Development Automation
 * @dev Category: TECH
 *
 * CAPABILITIES:
 *   - Smart contract security auditing (static analysis + AI review)
 *   - On-chain event monitoring with configurable alert thresholds
 *   - Automated DevOps: deployment scripts, CI/CD pipeline management
 *   - Code review and generation (Solidity, TypeScript, Python)
 *   - Protocol health monitoring (TVL, liquidity, anomaly detection)
 *   - Gas optimization recommendations
 *
 * GEMINI INTEGRATION:
 *   - Model: gemini-2.5-pro (deep reasoning for code analysis)
 *   - Temperature: 0.1 (precise, deterministic for code tasks)
 *   - Tools: code execution (for testing snippets), no web grounding (accuracy)
 *   - System prompt: Senior blockchain security engineer + Solidity expert
 *
 * MINI-GAME TASKS:
 *   - TASK_AUDIT_CONTRACT: Run AI audit on a given contract address
 *   - TASK_MONITOR_PROTOCOL: Set up monitoring for N contracts, detect anomaly
 *   - TASK_OPTIMIZE_GAS: Suggest gas optimizations saving >20%
 *   - TASK_GENERATE_TESTS: Generate test suite with >80% coverage metrics
 */
contract TechAgentNFT is NuxAgentNFTBase {

    // ============================================
    // ERRORS
    // ============================================
    error WrongCategory();
    error TokenNotFound();
    error NotAuthorized();
    error InvalidTarget();
    error MaxRulesReached();

    // ============================================
    // TECH-SPECIFIC STORAGE
    // ============================================

    struct TechProfile {
        address[] monitoredContracts;   // Contracts this agent monitors on-chain
        uint256   auditsCompleted;       // Total audits performed
        uint256   bugsFound;             // Total issues flagged across audits
        uint256   gasOptimizationsSaved; // Cumulative gas units saved via suggestions
        bool      oracleEnabled;         // Whether agent can trigger on-chain alerts
        uint256   alertsTriggered;       // Total alerts fired
    }

    struct MonitoringRule {
        address targetContract;
        string  eventSignature;         // e.g., "Transfer(address,address,uint256)"
        uint256 thresholdValue;         // e.g., alert if transfer > threshold
        bool    active;
    }

    mapping(uint256 => TechProfile)                    public techProfiles;
    mapping(uint256 => MonitoringRule[])               public monitoringRules;
    mapping(uint256 => mapping(address => bool))       public isMonitored;  // tokenId → contract → monitored

    // ============================================
    // EVENTS
    // ============================================
    event AuditCompleted(uint256 indexed tokenId, address indexed target, uint256 issuesFound, uint256 xpEarned);
    event MonitoringRuleAdded(uint256 indexed tokenId, address indexed target, string eventSig);
    event AlertTriggered(uint256 indexed tokenId, address indexed target, string alertType, uint256 value);
    event GasOptimizationReported(uint256 indexed tokenId, uint256 gasSaved);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address treasuryManager_,
        address levelingSystem_,
        address erc6551Impl_,
        uint256 mintingFee_
    ) public initializer {
        __NuxAgentNFTBase_init(
            "NuxChain Tech Agent",
            "NXTECH",
            admin_,
            treasuryManager_,
            levelingSystem_,
            erc6551Impl_,
            mintingFee_,
            500 // 5% royalty
        );
    }

    // ============================================
    // FACTORY ENTRY POINT
    // ============================================

    function mintFromFactory(
        address recipient,
        AgentConfig memory config,
        string memory tokenURI_
    ) external payable onlyRole(FACTORY_ROLE) returns (uint256 tokenId) {
        if (config.category != AgentCategory.TECH) revert WrongCategory();
        _collectMintingFee();
        tokenId = _mintAgent(recipient, config, tokenURI_);
        techProfiles[tokenId] = TechProfile({
            monitoredContracts:   new address[](0),
            auditsCompleted:      0,
            bugsFound:            0,
            gasOptimizationsSaved: 0,
            oracleEnabled:        false,
            alertsTriggered:      0
        });
    }

    function mint(
        address recipient,
        AgentConfig memory config,
        string memory tokenURI_
    ) external payable onlyRole(ADMIN_ROLE) nonReentrant returns (uint256 tokenId) {
        if (config.category != AgentCategory.TECH) revert WrongCategory();
        _collectMintingFee();
        tokenId = _mintAgent(recipient, config, tokenURI_);
        techProfiles[tokenId] = TechProfile({
            monitoredContracts:   new address[](0),
            auditsCompleted:      0,
            bugsFound:            0,
            gasOptimizationsSaved: 0,
            oracleEnabled:        false,
            alertsTriggered:      0
        });
    }

    // ============================================
    // MONITORING MANAGEMENT
    // ============================================

    /**
     * @notice Register a contract for on-chain monitoring by this agent
     */
    function addMonitoringRule(
        uint256 tokenId,
        address targetContract,
        string calldata eventSignature,
        uint256 thresholdValue
    ) external {
        if (!_exists(tokenId)) revert TokenNotFound();
        if (ownerOf(tokenId) != msg.sender && !hasRole(ADMIN_ROLE, msg.sender)) revert NotAuthorized();
        if (targetContract == address(0)) revert InvalidTarget();
        if (monitoringRules[tokenId].length >= 20) revert MaxRulesReached();

        monitoringRules[tokenId].push(MonitoringRule({
            targetContract: targetContract,
            eventSignature: eventSignature,
            thresholdValue: thresholdValue,
            active:         true
        }));

        if (!isMonitored[tokenId][targetContract]) {
            techProfiles[tokenId].monitoredContracts.push(targetContract);
            isMonitored[tokenId][targetContract] = true;
        }

        emit MonitoringRuleAdded(tokenId, targetContract, eventSignature);
    }

    // ============================================
    // TASK RECORDING (called by NuxAgentMiniGame)
    // ============================================

    function recordAudit(
        uint256 tokenId,
        address auditedContract,
        uint256 issuesFound,
        uint256 xpEarned
    ) external onlyRole(REGISTRY_ROLE) {
        if (!_exists(tokenId)) revert TokenNotFound();
        techProfiles[tokenId].auditsCompleted++;
        techProfiles[tokenId].bugsFound += issuesFound;
        _awardXP(ownerOf(tokenId), xpEarned);
        emit AuditCompleted(tokenId, auditedContract, issuesFound, xpEarned);
    }

    function recordAlert(
        uint256 tokenId,
        address targetContract,
        string calldata alertType,
        uint256 value
    ) external onlyRole(REGISTRY_ROLE) {
        if (!_exists(tokenId)) revert TokenNotFound();
        techProfiles[tokenId].alertsTriggered++;
        emit AlertTriggered(tokenId, targetContract, alertType, value);
    }

    function recordGasOptimization(uint256 tokenId, uint256 gasSaved) external onlyRole(REGISTRY_ROLE) {
        if (!_exists(tokenId)) revert TokenNotFound();
        techProfiles[tokenId].gasOptimizationsSaved += gasSaved;
        _awardXP(ownerOf(tokenId), gasSaved / 10_000); // XP scaled by gas saved
        emit GasOptimizationReported(tokenId, gasSaved);
    }

    function setOracleEnabled(uint256 tokenId, bool enabled) external onlyRole(ADMIN_ROLE) {
        if (!_exists(tokenId)) revert TokenNotFound();
        techProfiles[tokenId].oracleEnabled = enabled;
    }

    uint256[50] private __gap;

}
