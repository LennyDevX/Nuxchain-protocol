// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../NuxAgentNFTBase.sol";

/**
 * @title FinanceAgentNFT
 * @notice AI Agent NFTs specialized for DeFi & Financial Automation
 * @dev Category: FINANCE
 *
 * CAPABILITIES:
 *   - Portfolio management with configurable risk profiles (CONSERVATIVE/MODERATE/AGGRESSIVE)
 *   - Automated staking strategies (integrates with SmartStakingCore.sol)
 *   - Yield optimization recommendations across multiple DeFi protocols
 *   - Price alert triggers (on-chain oracle integration)
 *   - Automated rebalancing proposals (off-chain via Gemini, executed by owner signature)
 *   - Risk-adjusted return calculations and reports
 *
 * STAKING INTEGRATION:
 *   The agent's TBA (Token Bound Account via ERC-6551) can hold staking positions.
 *   The Finance agent can trigger AUTO_COMPOUND on the owner's staking positions
 *   if granted operator approval on SmartStakingCore.
 *
 * GEMINI INTEGRATION:
 *   - Model: gemini-2.5-pro (deep financial reasoning)
 *   - Temperature: 0.2 (very precise, conservative for financial advice)
 *   - No web grounding (uses on-chain data from oracles)
 *   - System prompt: Quantitative finance + DeFi specialist
 *
 * MINI-GAME TASKS:
 *   - TASK_PORTFOLIO_ANALYSIS: Generate detailed portfolio health report
 *   - TASK_YIELD_STRATEGY: Propose yield strategy saving >5% vs current
 *   - TASK_RISK_ASSESSMENT: Complete a DeFi protocol risk assessment
 *   - TASK_PRICE_ALERT: Successfully predict + alert price move within 5%
 */
contract FinanceAgentNFT is NuxAgentNFTBase {

    // ============================================
    // ERRORS
    // ============================================
    error WrongCategory();
    error TokenNotFound();
    error NotOwner();
    error NotAuthorized();
    error MaxAlertsReached();
    error InvalidAlert();
    error AlreadyTriggered();

    // ============================================
    // FINANCE-SPECIFIC STORAGE
    // ============================================

    enum RiskProfile { CONSERVATIVE, MODERATE, AGGRESSIVE }

    struct FinanceProfile {
        RiskProfile riskProfile;
        uint256     portfolioValue;
        uint256     yieldOptimized;
        uint256     analysesCompleted;
        uint256     alertsTriggered;
        uint256     stakingAPYBoost;
        bool        autoCompoundEnabled;  // Whether agent auto-compounds staking for owner
        address     stakingContract;      // SmartStakingCore address
    }

    struct PriceAlert {
        address token;
        uint256 targetPrice;     // In USD * 1e8 (Chainlink compatible)
        bool    alertAbove;      // True = alert when price > target, False = below
        bool    triggered;
        bool    active;
    }

    mapping(uint256 => FinanceProfile)   public financeProfiles;
    mapping(uint256 => PriceAlert[])     public priceAlerts;

    // ============================================
    // EVENTS
    // ============================================
    event PortfolioAnalysisCompleted(uint256 indexed tokenId, uint256 portfolioValue, uint256 xpEarned);
    event YieldStrategyProposed(uint256 indexed tokenId, string strategyURI, uint256 estimatedAPY);
    event PriceAlertSet(uint256 indexed tokenId, address indexed token, uint256 targetPrice, bool alertAbove);
    event PriceAlertTriggered(uint256 indexed tokenId, address indexed token, uint256 actualPrice);
    event RiskProfileUpdated(uint256 indexed tokenId, RiskProfile newProfile);
    event AutoCompoundEnabled(uint256 indexed tokenId, address stakingContract);
    event StakingAPYBoostGranted(uint256 indexed tokenId, uint256 boostBps);

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
            "NuxChain Finance Agent",
            "NXFIN",
            admin_,
            treasuryManager_,
            levelingSystem_,
            erc6551Impl_,
            mintingFee_,
            500
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
        if (config.category != AgentCategory.FINANCE) revert WrongCategory();
        _collectMintingFee();
        tokenId = _mintAgent(recipient, config, tokenURI_);
        financeProfiles[tokenId] = FinanceProfile({
            riskProfile:          RiskProfile.MODERATE,
            portfolioValue:       0,
            yieldOptimized:       0,
            analysesCompleted:    0,
            alertsTriggered:      0,
            stakingAPYBoost:      0,
            autoCompoundEnabled:  false,
            stakingContract:      address(0)
        });
    }

    function mint(
        address recipient,
        AgentConfig memory config,
        string memory tokenURI_
    ) external payable onlyRole(ADMIN_ROLE) nonReentrant returns (uint256 tokenId) {
        if (config.category != AgentCategory.FINANCE) revert WrongCategory();
        _collectMintingFee();
        tokenId = _mintAgent(recipient, config, tokenURI_);
        financeProfiles[tokenId] = FinanceProfile({
            riskProfile:          RiskProfile.MODERATE,
            portfolioValue:       0,
            yieldOptimized:       0,
            analysesCompleted:    0,
            alertsTriggered:      0,
            stakingAPYBoost:      0,
            autoCompoundEnabled:  false,
            stakingContract:      address(0)
        });
    }

    // ============================================
    // AGENT CONFIGURATION
    // ============================================

    function setRiskProfile(uint256 tokenId, RiskProfile profile) external {
        if (!_exists(tokenId)) revert TokenNotFound();
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();
        financeProfiles[tokenId].riskProfile = profile;
        emit RiskProfileUpdated(tokenId, profile);
    }

    /**
     * @notice Enable auto-compound — agent will propose compound calls for owner's staking
        * @param stakingContract_ Address of SmartStakingCore
     */
    function enableAutoCompound(uint256 tokenId, address stakingContract_) external {
        if (!_exists(tokenId)) revert TokenNotFound();
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (stakingContract_ == address(0)) revert InvalidAlert();
        financeProfiles[tokenId].autoCompoundEnabled = true;
        financeProfiles[tokenId].stakingContract = stakingContract_;
        emit AutoCompoundEnabled(tokenId, stakingContract_);
    }

    /**
     * @notice Set a price alert for a token (monitored off-chain, triggered on-chain)
     */
    function setPriceAlert(
        uint256 tokenId,
        address token,
        uint256 targetPrice,
        bool alertAbove
    ) external {
        if (!_exists(tokenId)) revert TokenNotFound();
        if (ownerOf(tokenId) != msg.sender &&
            !(currentRenter[tokenId] == msg.sender && block.timestamp < rentalExpiry[tokenId]))
            revert NotAuthorized();
        if (priceAlerts[tokenId].length >= 20) revert MaxAlertsReached();

        priceAlerts[tokenId].push(PriceAlert({
            token:        token,
            targetPrice:  targetPrice,
            alertAbove:   alertAbove,
            triggered:    false,
            active:       true
        }));

        emit PriceAlertSet(tokenId, token, targetPrice, alertAbove);
    }

    // ============================================
    // TASK RECORDING
    // ============================================

    function recordPortfolioAnalysis(
        uint256 tokenId,
        uint256 portfolioValue,
        uint256 xpEarned
    ) external onlyRole(REGISTRY_ROLE) {
        if (!_exists(tokenId)) revert TokenNotFound();
        financeProfiles[tokenId].portfolioValue = portfolioValue;
        financeProfiles[tokenId].analysesCompleted++;
        _awardXP(ownerOf(tokenId), xpEarned);
        emit PortfolioAnalysisCompleted(tokenId, portfolioValue, xpEarned);
    }

    function recordYieldStrategy(
        uint256 tokenId,
        string calldata strategyURI,
        uint256 estimatedAPY,
        uint256 xpEarned
    ) external onlyRole(REGISTRY_ROLE) {
        if (!_exists(tokenId)) revert TokenNotFound();
        financeProfiles[tokenId].yieldOptimized += estimatedAPY;
        _awardXP(ownerOf(tokenId), xpEarned);
        emit YieldStrategyProposed(tokenId, strategyURI, estimatedAPY);
    }

    function triggerPriceAlert(
        uint256 tokenId,
        uint256 alertIndex,
        uint256 actualPrice
    ) external onlyRole(REGISTRY_ROLE) {
        if (!_exists(tokenId)) revert TokenNotFound();
        if (alertIndex >= priceAlerts[tokenId].length) revert InvalidAlert();
        PriceAlert storage alert = priceAlerts[tokenId][alertIndex];
        if (!alert.active || alert.triggered) revert AlreadyTriggered();
        alert.triggered = true;
        financeProfiles[tokenId].alertsTriggered++;
        _awardXP(ownerOf(tokenId), 25);
        emit PriceAlertTriggered(tokenId, alert.token, actualPrice);
    }

    function grantStakingAPYBoost(uint256 tokenId, uint256 boostBps) external onlyRole(ADMIN_ROLE) {
        if (!_exists(tokenId)) revert TokenNotFound();
        financeProfiles[tokenId].stakingAPYBoost = boostBps;
        emit StakingAPYBoostGranted(tokenId, boostBps);
    }

    uint256[50] private __gap;

}
