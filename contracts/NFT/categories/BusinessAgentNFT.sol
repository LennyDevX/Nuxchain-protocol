// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../NuxAgentNFTBase.sol";

/**
 * @title BusinessAgentNFT
 * @notice AI Agent NFTs specialized for Business Automation & CRM
 * @dev Category: BUSINESS
 */
contract BusinessAgentNFT is NuxAgentNFTBase {

    // ============================================
    // ERRORS
    // ============================================
    error WrongCategory();
    error TokenNotFound();
    error NotAuthorized();
    error MaxClientsReached();
    error MaxWorkflowsReached();
    error InvalidWorkflow();
    error AlreadyFinalized();
    error InvalidClient();

    // ============================================
    // STORAGE
    // ============================================

    enum WorkflowStatus { PENDING, ACTIVE, COMPLETED, FAILED }
    enum DealStage      { PROSPECT, QUALIFIED, PROPOSAL, NEGOTIATION, CLOSED_WON, CLOSED_LOST }

    struct BusinessProfile {
        uint256  clientCount;
        uint256  workflowsCompleted;
        uint256  dealsClosedWon;
        uint256  dealsClosedLost;
        uint256  totalRevenueLocked;
    }

    struct Client {
        address   walletAddress;
        uint256   lifetimeValue;
        DealStage stage;
    }

    struct Workflow {
        WorkflowStatus status;
        uint256        completedAt;
    }

    uint256 public constant MAX_CLIENTS   = 100;
    uint256 public constant MAX_WORKFLOWS = 20;

    mapping(uint256 => BusinessProfile) public businessProfiles;
    mapping(uint256 => Client[])        internal _clients;
    mapping(uint256 => Workflow[])      internal _workflows;

    // ============================================
    // EVENTS
    // ============================================
    event ClientAdded(uint256 indexed tokenId, uint256 clientIndex, string clientName);
    event DealUpdated(uint256 indexed tokenId, uint256 clientIndex, DealStage newStage, uint256 dealValue);
    event WorkflowCreated(uint256 indexed tokenId, uint256 workflowIndex, string workflowName, string executionURI);
    event WorkflowCompleted(uint256 indexed tokenId, uint256 workflowIndex, uint256 xpEarned);
    event WorkflowFailed(uint256 indexed tokenId, uint256 workflowIndex);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(
        address admin_,
        address treasuryManager_,
        address levelingSystem_,
        address erc6551Impl_,
        uint256 mintingFee_
    ) public initializer {
        __NuxAgentNFTBase_init(
            "NuxChain Business Agent", "NXBIZ",
            admin_, treasuryManager_, levelingSystem_, erc6551Impl_, mintingFee_, 500
        );
    }

    // ============================================
    // FACTORY / MINT
    // ============================================

    function mintFromFactory(
        address recipient,
        AgentConfig memory config,
        string memory tokenURI_
    ) external payable onlyRole(FACTORY_ROLE) returns (uint256 tokenId) {
        if (config.category != AgentCategory.BUSINESS) revert WrongCategory();
        _collectMintingFee();
        tokenId = _mintAgent(recipient, config, tokenURI_);
    }

    function mint(
        address recipient,
        AgentConfig memory config,
        string memory tokenURI_
    ) external payable onlyRole(ADMIN_ROLE) nonReentrant returns (uint256 tokenId) {
        if (config.category != AgentCategory.BUSINESS) revert WrongCategory();
        _collectMintingFee();
        tokenId = _mintAgent(recipient, config, tokenURI_);
    }

    // ============================================
    // CONFIGURATION
    // ============================================

    function addClient(uint256 tokenId, string calldata clientName, address wallet) external {
        if (!_exists(tokenId)) revert TokenNotFound();
        if (ownerOf(tokenId) != msg.sender &&
            !(currentRenter[tokenId] == msg.sender && block.timestamp < rentalExpiry[tokenId]))
            revert NotAuthorized();
        if (_clients[tokenId].length >= MAX_CLIENTS) revert MaxClientsReached();

        _clients[tokenId].push(Client({
            walletAddress: wallet,
            lifetimeValue: 0,
            stage:         DealStage.PROSPECT
        }));
        businessProfiles[tokenId].clientCount++;
        emit ClientAdded(tokenId, _clients[tokenId].length - 1, clientName);
    }

    function createWorkflow(uint256 tokenId, string calldata name_, string calldata executionURI) external {
        if (!_exists(tokenId)) revert TokenNotFound();
        if (ownerOf(tokenId) != msg.sender &&
            !(currentRenter[tokenId] == msg.sender && block.timestamp < rentalExpiry[tokenId]))
            revert NotAuthorized();
        if (_workflows[tokenId].length >= MAX_WORKFLOWS) revert MaxWorkflowsReached();

        _workflows[tokenId].push(Workflow({
            status:      WorkflowStatus.PENDING,
            completedAt: 0
        }));
        emit WorkflowCreated(tokenId, _workflows[tokenId].length - 1, name_, executionURI);
    }

    // ============================================
    // TASK RECORDING
    // ============================================

    function recordWorkflowCompleted(uint256 tokenId, uint256 wfIdx, uint256 xpEarned) external onlyRole(REGISTRY_ROLE) {
        if (!_exists(tokenId))                          revert TokenNotFound();
        if (wfIdx >= _workflows[tokenId].length)        revert InvalidWorkflow();
        Workflow storage wf = _workflows[tokenId][wfIdx];
        if (wf.status == WorkflowStatus.COMPLETED || wf.status == WorkflowStatus.FAILED)
            revert AlreadyFinalized();

        wf.status      = WorkflowStatus.COMPLETED;
        wf.completedAt = block.timestamp;
        businessProfiles[tokenId].workflowsCompleted++;
        _awardXP(ownerOf(tokenId), xpEarned);
        emit WorkflowCompleted(tokenId, wfIdx, xpEarned);
    }

    function recordWorkflowFailed(uint256 tokenId, uint256 wfIdx) external onlyRole(REGISTRY_ROLE) {
        if (!_exists(tokenId))                   revert TokenNotFound();
        if (wfIdx >= _workflows[tokenId].length) revert InvalidWorkflow();
        _workflows[tokenId][wfIdx].status = WorkflowStatus.FAILED;
        emit WorkflowFailed(tokenId, wfIdx);
    }

    function recordDealClosed(uint256 tokenId, uint256 clientIdx, bool won, uint256 dealValue, uint256 xpEarned)
        external onlyRole(REGISTRY_ROLE)
    {
        if (!_exists(tokenId))                     revert TokenNotFound();
        if (clientIdx >= _clients[tokenId].length) revert InvalidClient();

        Client storage c          = _clients[tokenId][clientIdx];
        BusinessProfile storage p = businessProfiles[tokenId];

        if (won) {
            c.stage = DealStage.CLOSED_WON;
            c.lifetimeValue += dealValue;
            p.dealsClosedWon++;
            p.totalRevenueLocked += dealValue;
        } else {
            c.stage = DealStage.CLOSED_LOST;
            p.dealsClosedLost++;
        }
        _awardXP(ownerOf(tokenId), xpEarned);
        emit DealUpdated(tokenId, clientIdx, c.stage, dealValue);
    }

    // ============================================
    // VIEW
    // ============================================
    function getClientCount(uint256 tokenId)   external view returns (uint256) { return _clients[tokenId].length;   }
    function getWorkflowCount(uint256 tokenId) external view returns (uint256) { return _workflows[tokenId].length; }
    function getClient(uint256 tokenId, uint256 idx)   external view returns (Client memory)   { return _clients[tokenId][idx];   }
    function getWorkflow(uint256 tokenId, uint256 idx) external view returns (Workflow memory) { return _workflows[tokenId][idx]; }

    uint256[50] private __gap;
}