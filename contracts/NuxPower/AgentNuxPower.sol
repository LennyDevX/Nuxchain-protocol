// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/INuxAgentNFT.sol";
import "../interfaces/ITreasuryManager.sol";
import "../interfaces/IXPHub.sol";

/// @dev Minimal ERC-721 interface used to verify token ownership
interface IERC721Minimal {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title AgentNuxPower
 * @notice NuxPower upgrades for AI Agent NFTs — 10 powers per category, 5 categories = 50 total.
 * @dev UUPS upgradeable, AccessControl, dynamic demand-based pricing.
 *
 * ARCHITECTURE:
 * - Each NuxPower upgrade is tied to a specific AgentCategory
 * - Users purchase a power and equip it to their Agent NFT (by tokenId + nftContract)
 * - Each agent can have up to MAX_POWERS_PER_AGENT active upgrades at a time
 * - Dynamic pricing: base price × demandMultiplier (rises with demand, decays over time)
 * - Revenue routed 100% to TreasuryManager
 * - Grants XP to buyer via LevelingSystem
 *
 * POWER TYPES (10 per category):
 * ── SOCIAL ──────────────────────────────────────────────────────────────
 *  0  VIRAL_AMPLIFIER       +30% social reach bonus
 *  1  SENTIMENT_ANALYZER    Detects optimal post timing   
 *  2  COMMUNITY_BUILDER     +25% like/comment XP
 *  3  TREND_SCOUT           Early trend detection
 *  4  ENGAGEMENT_BOOSTER    +35% engagement XP
 *  5  CONTENT_CURATOR       Auto-curate featured posts
 *  6  FOLLOWER_MAGNET       +40% follower acquisition rate
 *  7  BRAND_SIGNAL          Enhanced brand visibility
 *  8  SOCIAL_PROOF_ENGINE   Authenticity score +20%
 *  9  REPUTATION_SHIELD     Reputation decay protection
 * ── TECH ────────────────────────────────────────────────────────────────
 * 10  CODE_OPTIMIZER        +20% execution speed
 * 11  CONTRACT_AUDITOR      Auto security scan bonus
 * 12  API_ACCELERATOR       +50% API call efficiency
 * 13  DEBUG_MASTER          Error detection precision +30%
 * 14  DEVOPS_ENGINE         Deployment automation
 * 15  DATA_PIPELINE         Data processing throughput +40%
 * 16  PROTOCOL_INTEGRATOR   Multi-chain bridge bonus
 * 17  GAS_OPTIMIZER         Gas cost reduction -15%
 * 18  TEST_AUTOMATOR        Automated QA score boost
 * 19  SECURITY_SENTINEL     Real-time threat monitor
 * ── MARKETING ───────────────────────────────────────────────────────────
 * 20  CONVERSION_AMPLIFIER  +25% conversion rate
 * 21  GROWTH_HACKER         Viral loop multiplier
 * 22  AD_OPTIMIZER          +30% ad campaign efficiency
 * 23  CAMPAIGN_MAESTRO      Multi-channel coordination
 * 24  PERSONA_BUILDER       Advanced audience targeting
 * 25  FUNNEL_ACCELERATOR    Lead pipeline +35%
 * 26  BRAND_STORYTELLER     Narrative engagement +30%
 * 27  RETENTION_ENGINE      Churn reduction -20%
 * 28  ROI_MAXIMIZER         Campaign cost -20%
 * 29  INFLUENCER_NETWORK    Partner reach multiplier
 * ── FINANCE ─────────────────────────────────────────────────────────────
 * 30  YIELD_OPTIMIZER       +15% DeFi yield boost
 * 31  RISK_ANALYZER         Portfolio risk scoring
 * 32  ARBITRAGE_SCOUT       Cross-protocol opportunity finder
 * 33  COMPOUND_MASTER       Auto-reinvest at optimal rates
 * 34  PORTFOLIO_REBALANCER  Automated rebalancing
 * 35  TAX_OPTIMIZER         Tax-efficient routing
 * 36  LP_OPTIMIZER          Liquidity position optimizer
 * 37  PRICE_ORACLE          Real-time pricing signals
 * 38  FLASH_SHIELD          MEV & front-run protection
 * 39  TREASURY_GUARD        Fund security +25%
 * ── BUSINESS ────────────────────────────────────────────────────────────
 * 40  DEAL_CLOSER           +30% negotiation success rate
 * 41  REVENUE_FORECASTER    Predictive revenue modeling
 * 42  PROCESS_AUTOMATOR     Workflow efficiency +25%
 * 43  PARTNERSHIP_SCOUT     Alliance opportunity detection
 * 44  MARKET_ANALYZER       Competitive intelligence boost
 * 45  COST_REDUCER          Operational cost -20%
 * 46  PROPOSAL_WRITER       Automated pitch generation
 * 47  COMPLIANCE_GUARD      Regulatory compliance monitor
 * 48  KPI_TRACKER           Performance metrics automation
 * 49  STRATEGY_PLANNER      Long-term planning optimizer
 *
 * DYNAMIC PRICING:
 * - Each power type has a configurable basePrice (set in constructor, adjustable by admin)
 * - purchasesInWindow[powerType]: rolling 24 h purchase count
 * - If purchasesInWindow >= demandThreshold: currentMultiplier += DEMAND_STEP_BPS (max: MAX_MULTIPLIER_BPS)
 * - currentMultiplier decays by DECAY_PER_PERIOD every DECAY_PERIOD_SECONDS with 0 purchases
 * - finalPrice = basePrice × currentMultiplier / BASIS_POINTS
 *
 * @custom:security-contact security@nuvo.com
 * @custom:version 1.0.0
 */
contract AgentNuxPower is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ROLES
    // ════════════════════════════════════════════════════════════════════════════════════════

    bytes32 public constant ADMIN_ROLE    = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    uint8  public constant POWERS_PER_CATEGORY  = 10;
    uint8  public constant TOTAL_POWERS         = 50;   // 5 categories × 10
    uint8  public constant MAX_POWERS_PER_AGENT = 5;    // max active upgrades per NFT
    uint256 private constant BASIS_POINTS       = 10_000;

    // Dynamic pricing constants
    uint256 private constant DEMAND_WINDOW      = 24 hours;  // rolling demand window
    uint256 private constant DEMAND_THRESHOLD   = 10;        // purchases in window to trigger step
    uint256 private constant DEMAND_STEP_BPS    = 1000;      // +10% per demand threshold crossed
    uint256 private constant MAX_MULTIPLIER_BPS = 30_000;    // 3× max (30000 bps)
    uint256 private constant DECAY_PERIOD       = 12 hours;  // decay check interval
    uint256 private constant DECAY_STEP_BPS     = 500;       // -5% per quiet period

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    struct PowerDefinition {
        INuxAgentNFT.AgentCategory category;  // Which agent category it belongs to
        uint16 effectBps;                      // Effect magnitude in basis points (e.g. 3000 = +30%)
        uint256 basePrice;                     // Base price in POL (wei)
        bool active;                           // Whether it can be purchased
    }

    struct DynamicPricing {
        uint256 currentMultiplierBps;  // Current multiplier (default 10000 = 1×), max 30000 = 3×
        uint256 windowStart;           // Rolling window start timestamp
        uint32  purchasesInWindow;     // Purchases within current DEMAND_WINDOW
        uint256 lastDecayCheck;        // Last time decay was evaluated
    }

    struct EquippedPower {
        uint8   powerId;        // Which power type (0-49)
        uint256 equippedAt;     // Timestamp
        bool    active;         // Still equipped
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // STATE
    // ════════════════════════════════════════════════════════════════════════════════════════

    ITreasuryManager public treasuryManager;
    address          public levelingSystem;     // LevelingSystem for XP rewards

    // Power catalog: powerId (0-49) => definition
    mapping(uint8 => PowerDefinition) public powers;

    // Dynamic pricing per power
    mapping(uint8 => DynamicPricing) public pricing;

    // Agent upgrades: nftContract => tokenId => [EquippedPower]
    mapping(address => mapping(uint256 => EquippedPower[])) private _agentPowers;
    // nftContract => tokenId => active power count
    mapping(address => mapping(uint256 => uint8)) public activePowerCount;
    // nftContract => tokenId => powerId => equipped (quick lookup)
    mapping(address => mapping(uint256 => mapping(uint8 => bool))) public hasPower;

    // Global statistics
    uint256 public totalPurchases;
    uint256 public totalRevenue;
    mapping(uint8 => uint256) public purchasesByPower;

    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════

    event PowerPurchased(
        address indexed buyer,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint8   powerId,
        uint256 pricePaid
    );
    event PowerRemoved(
        address indexed owner,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint8 powerId
    );
    /// @notice Emitted during initialization — index off-chain for display metadata\n    event PowerDefined(uint8 indexed powerId, string name, string description);
    event DynamicPriceUpdated(uint8 indexed powerId, uint256 newMultiplierBps, uint256 newPrice);
    event BasePriceUpdated(uint8 indexed powerId, uint256 newBasePrice);
    event TreasuryUpdated(address indexed newTreasury);
    event LevelingSystemUpdated(address indexed newLeveling);

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ════════════════════════════════════════════════════════════════════════════════════════

    error InvalidPowerId(uint8 powerId);
    error PowerNotActive(uint8 powerId);
    error WrongCategory(uint8 powerId, INuxAgentNFT.AgentCategory required, INuxAgentNFT.AgentCategory actual);
    error MaxPowersReached(uint256 tokenId, uint8 max);
    error PowerAlreadyEquipped(uint256 tokenId, uint8 powerId);
    error PowerNotEquipped(uint256 tokenId, uint8 powerId);
    error IncorrectPayment(uint256 expected, uint256 sent);
    error NotTokenOwner();
    error InvalidAddress();
    error WithdrawFailed();

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INITIALIZER
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address admin_, address treasury_) external initializer {
        if (admin_ == address(0) || treasury_ == address(0)) revert InvalidAddress();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        treasuryManager = ITreasuryManager(treasury_);
        _initializePowers();
        _initializePricing();
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ════════════════════════════════════════════════════════════════════════════════════════
    // CORE PURCHASE
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Purchase and equip a NuxPower upgrade onto your Agent NFT
     * @param powerId   The upgrade ID (0-49)
     * @param nftContract  Address of the NuxAgent NFT contract
     * @param tokenId   Your agent's token ID
     */
    function purchasePower(
        uint8   powerId,
        address nftContract,
        uint256 tokenId
    ) external payable nonReentrant whenNotPaused {
        if (powerId >= TOTAL_POWERS) revert InvalidPowerId(powerId);
        PowerDefinition storage pd = powers[powerId];
        if (!pd.active) revert PowerNotActive(powerId);

        // Verify caller owns the NFT
        try IERC721Minimal(nftContract).ownerOf(tokenId) returns (address owner) {
            if (owner != msg.sender) revert NotTokenOwner();
        } catch {
            revert NotTokenOwner();
        }

        // Verify NFT is the right category for this power
        try INuxAgentNFT(nftContract).getAgentConfig(tokenId) returns (INuxAgentNFT.AgentConfig memory cfg) {
            if (cfg.category != pd.category) {
                revert WrongCategory(powerId, pd.category, cfg.category);
            }
        } catch {
            revert NotTokenOwner();
        }

        // Check capacity
        if (activePowerCount[nftContract][tokenId] >= MAX_POWERS_PER_AGENT)
            revert MaxPowersReached(tokenId, MAX_POWERS_PER_AGENT);
        if (hasPower[nftContract][tokenId][powerId])
            revert PowerAlreadyEquipped(tokenId, powerId);

        // Verify payment
        uint256 price = getCurrentPrice(powerId);
        if (msg.value != price) revert IncorrectPayment(price, msg.value);

        // Update demand pricing
        _updateDemand(powerId);

        // Record equipped power
        _agentPowers[nftContract][tokenId].push(EquippedPower({
            powerId:    powerId,
            equippedAt: block.timestamp,
            active:     true
        }));
        activePowerCount[nftContract][tokenId]++;
        hasPower[nftContract][tokenId][powerId] = true;

        // Statistics
        totalPurchases++;
        totalRevenue += msg.value;
        purchasesByPower[powerId]++;

        // Notify LevelingSystem: awards 20 XP for AGENT_UPGRADE
        if (levelingSystem != address(0)) {
            try IXPHub(levelingSystem).awardXP(msg.sender, 20, IXPHub.XPSource.AGENT_UPGRADE) {} catch {}
        }

        // Route revenue to treasury
        try treasuryManager.receiveRevenue{value: msg.value}("AgentNuxPower") {} catch {
            // If treasury reverts, keep in contract for manual forwarding
        }

        emit PowerPurchased(msg.sender, nftContract, tokenId, powerId, msg.value);
    }

    /**
     * @notice Remove an equipped power from your agent (no refund)
     */
    function removePower(
        address nftContract,
        uint256 tokenId,
        uint8   powerId
    ) external nonReentrant {
        // Verify caller owns the NFT
        try IERC721Minimal(nftContract).ownerOf(tokenId) returns (address owner) {
            if (owner != msg.sender) revert NotTokenOwner();
        } catch {
            revert NotTokenOwner();
        }
        if (!hasPower[nftContract][tokenId][powerId]) revert PowerNotEquipped(tokenId, powerId);

        EquippedPower[] storage eps = _agentPowers[nftContract][tokenId];
        for (uint256 i = 0; i < eps.length; i++) {
            if (eps[i].powerId == powerId && eps[i].active) {
                eps[i].active = false;
                break;
            }
        }
        activePowerCount[nftContract][tokenId]--;
        hasPower[nftContract][tokenId][powerId] = false;

        emit PowerRemoved(msg.sender, nftContract, tokenId, powerId);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // DYNAMIC PRICING
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Returns the current price for a power, accounting for demand
     */
    function getCurrentPrice(uint8 powerId) public view returns (uint256) {
        if (powerId >= TOTAL_POWERS) revert InvalidPowerId(powerId);
        DynamicPricing storage dp = pricing[powerId];
        uint256 multiplier = _getDecayedMultiplier(dp);
        return powers[powerId].basePrice * multiplier / BASIS_POINTS;
    }

    /**
     * @notice View-only multiplier (applies pending decay without writing state)
     */
    function _getDecayedMultiplier(DynamicPricing storage dp) internal view returns (uint256) {
        uint256 m = dp.currentMultiplierBps;
        if (m <= BASIS_POINTS) return BASIS_POINTS;
        // Apply decay periods that have elapsed since last decay check
        uint256 elapsed = block.timestamp - dp.lastDecayCheck;
        uint256 periods  = elapsed / DECAY_PERIOD;
        if (periods == 0) return m;
        uint256 decay = periods * DECAY_STEP_BPS;
        return m > BASIS_POINTS + decay ? m - decay : BASIS_POINTS;
    }

    /**
     * @dev Updates demand tracking and adjusts current multiplier on purchase
     */
    function _updateDemand(uint8 powerId) internal {
        DynamicPricing storage dp = pricing[powerId];

        // Apply pending decay to multiplier
        uint256 elapsed = block.timestamp - dp.lastDecayCheck;
        if (elapsed >= DECAY_PERIOD) {
            uint256 periods = elapsed / DECAY_PERIOD;
            uint256 decay   = periods * DECAY_STEP_BPS;
            dp.currentMultiplierBps = dp.currentMultiplierBps > BASIS_POINTS + decay
                ? dp.currentMultiplierBps - decay
                : BASIS_POINTS;
            dp.lastDecayCheck = block.timestamp;
        }

        // Roll window if expired
        if (block.timestamp - dp.windowStart >= DEMAND_WINDOW) {
            dp.windowStart       = block.timestamp;
            dp.purchasesInWindow = 0;
        }

        dp.purchasesInWindow++;

        // Check if demand threshold crossed → raise multiplier
        if (dp.purchasesInWindow % DEMAND_THRESHOLD == 0) {
            uint256 newMultiplier = dp.currentMultiplierBps + DEMAND_STEP_BPS;
            if (newMultiplier > MAX_MULTIPLIER_BPS) newMultiplier = MAX_MULTIPLIER_BPS;
            dp.currentMultiplierBps = newMultiplier;
            emit DynamicPriceUpdated(powerId, newMultiplier, powers[powerId].basePrice * newMultiplier / BASIS_POINTS);
        }
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// @notice Get all equipped powers for an agent
    function getAgentPowers(address nftContract, uint256 tokenId)
        external view returns (EquippedPower[] memory)
    {
        return _agentPowers[nftContract][tokenId];
    }

    /// @notice Get all active (not removed) equipped powers for an agent
    function getActiveAgentPowers(address nftContract, uint256 tokenId)
        external view returns (EquippedPower[] memory active)
    {
        EquippedPower[] storage all = _agentPowers[nftContract][tokenId];
        uint256 count;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].active) count++;
        }
        active = new EquippedPower[](count);
        uint256 j;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].active) active[j++] = all[i];
        }
    }

    /// @notice Get all powers available for a category with current prices
    function getPowersByCategory(INuxAgentNFT.AgentCategory category)
        external view
        returns (uint8[] memory ids, uint256[] memory prices, uint16[] memory effects)
    {
        ids     = new uint8[](POWERS_PER_CATEGORY);
        prices  = new uint256[](POWERS_PER_CATEGORY);
        effects = new uint16[](POWERS_PER_CATEGORY);
        uint256 j;
        for (uint8 i = 0; i < TOTAL_POWERS; i++) {
            if (powers[i].category == category) {
                ids[j]     = i;
                prices[j]  = getCurrentPrice(i);
                effects[j] = powers[i].effectBps;
                j++;
                if (j == POWERS_PER_CATEGORY) break;
            }
        }
    }

    /// @notice Total effect bonus (in bps) of all active powers for an agent
    function getTotalEffectBps(address nftContract, uint256 tokenId)
        external view returns (uint256 totalBps)
    {
        EquippedPower[] storage eps = _agentPowers[nftContract][tokenId];
        for (uint256 i = 0; i < eps.length; i++) {
            if (eps[i].active) {
                totalBps += powers[eps[i].powerId].effectBps;
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN
    // ════════════════════════════════════════════════════════════════════════════════════════

    function setBasePrice(uint8 powerId, uint256 newBasePrice) external onlyRole(ADMIN_ROLE) {
        if (powerId >= TOTAL_POWERS) revert InvalidPowerId(powerId);
        powers[powerId].basePrice = newBasePrice;
        emit BasePriceUpdated(powerId, newBasePrice);
    }

    function setPowerActive(uint8 powerId, bool active_) external onlyRole(ADMIN_ROLE) {
        if (powerId >= TOTAL_POWERS) revert InvalidPowerId(powerId);
        powers[powerId].active = active_;
    }

    function setTreasuryManager(address treasury_) external onlyRole(ADMIN_ROLE) {
        if (treasury_ == address(0)) revert InvalidAddress();
        treasuryManager = ITreasuryManager(treasury_);
        emit TreasuryUpdated(treasury_);
    }

    function setLevelingSystem(address leveling_) external onlyRole(ADMIN_ROLE) {
        levelingSystem = leveling_;
        emit LevelingSystemUpdated(leveling_);
    }

    function pause()   external onlyRole(ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(ADMIN_ROLE) { _unpause(); }

    /// @notice Emergency withdraw if treasury call fails
    function emergencyWithdraw(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert InvalidAddress();
        uint256 bal = address(this).balance;
        (bool ok, ) = to.call{value: bal}("");
        if (!ok) revert WithdrawFailed();
    }

    receive() external payable {}

    // ════════════════════════════════════════════════════════════════════════════════════════
    // INITIALIZATION — POWER CATALOG
    // ════════════════════════════════════════════════════════════════════════════════════════

    function _initializePricing() internal {
        for (uint8 i = 0; i < TOTAL_POWERS; i++) {
            pricing[i] = DynamicPricing({
                currentMultiplierBps: BASIS_POINTS,
                windowStart:          block.timestamp,
                purchasesInWindow:    0,
                lastDecayCheck:       block.timestamp
            });
        }
    }

    function _initializePowers() internal {
        // PowerDefined events carry names/descriptions for off-chain indexing.
        // Only functional fields (category, effectBps, basePrice, active) are stored on-chain.

        // ── SOCIAL (0–9) ─────────────────────────────────────────────────
        powers[0]  = PowerDefinition(INuxAgentNFT.AgentCategory.SOCIAL,     3000,  25 ether, true);
        powers[1]  = PowerDefinition(INuxAgentNFT.AgentCategory.SOCIAL,     1500,  35 ether, true);
        powers[2]  = PowerDefinition(INuxAgentNFT.AgentCategory.SOCIAL,     2500,  40 ether, true);
        powers[3]  = PowerDefinition(INuxAgentNFT.AgentCategory.SOCIAL,     2000,  45 ether, true);
        powers[4]  = PowerDefinition(INuxAgentNFT.AgentCategory.SOCIAL,     3500,  50 ether, true);
        powers[5]  = PowerDefinition(INuxAgentNFT.AgentCategory.SOCIAL,     2000,  55 ether, true);
        powers[6]  = PowerDefinition(INuxAgentNFT.AgentCategory.SOCIAL,     4000,  65 ether, true);
        powers[7]  = PowerDefinition(INuxAgentNFT.AgentCategory.SOCIAL,     2500,  70 ether, true);
        powers[8]  = PowerDefinition(INuxAgentNFT.AgentCategory.SOCIAL,     2000,  80 ether, true);
        powers[9]  = PowerDefinition(INuxAgentNFT.AgentCategory.SOCIAL,     1500, 100 ether, true);

        // ── TECH (10–19) ──────────────────────────────────────────────────
        powers[10] = PowerDefinition(INuxAgentNFT.AgentCategory.TECH,       2000,  30 ether, true);
        powers[11] = PowerDefinition(INuxAgentNFT.AgentCategory.TECH,       2500,  45 ether, true);
        powers[12] = PowerDefinition(INuxAgentNFT.AgentCategory.TECH,       5000,  60 ether, true);
        powers[13] = PowerDefinition(INuxAgentNFT.AgentCategory.TECH,       3000,  50 ether, true);
        powers[14] = PowerDefinition(INuxAgentNFT.AgentCategory.TECH,       2000,  55 ether, true);
        powers[15] = PowerDefinition(INuxAgentNFT.AgentCategory.TECH,       4000,  65 ether, true);
        powers[16] = PowerDefinition(INuxAgentNFT.AgentCategory.TECH,       2500,  75 ether, true);
        powers[17] = PowerDefinition(INuxAgentNFT.AgentCategory.TECH,       1500,  80 ether, true);
        powers[18] = PowerDefinition(INuxAgentNFT.AgentCategory.TECH,       3000,  70 ether, true);
        powers[19] = PowerDefinition(INuxAgentNFT.AgentCategory.TECH,       2000, 120 ether, true);

        // ── MARKETING (20–29) ─────────────────────────────────────────────
        powers[20] = PowerDefinition(INuxAgentNFT.AgentCategory.MARKETING,  2500,  35 ether, true);
        powers[21] = PowerDefinition(INuxAgentNFT.AgentCategory.MARKETING,  3000,  45 ether, true);
        powers[22] = PowerDefinition(INuxAgentNFT.AgentCategory.MARKETING,  3000,  55 ether, true);
        powers[23] = PowerDefinition(INuxAgentNFT.AgentCategory.MARKETING,  2000,  60 ether, true);
        powers[24] = PowerDefinition(INuxAgentNFT.AgentCategory.MARKETING,  3500,  65 ether, true);
        powers[25] = PowerDefinition(INuxAgentNFT.AgentCategory.MARKETING,  3500,  70 ether, true);
        powers[26] = PowerDefinition(INuxAgentNFT.AgentCategory.MARKETING,  3000,  75 ether, true);
        powers[27] = PowerDefinition(INuxAgentNFT.AgentCategory.MARKETING,  2000,  80 ether, true);
        powers[28] = PowerDefinition(INuxAgentNFT.AgentCategory.MARKETING,  2000,  90 ether, true);
        powers[29] = PowerDefinition(INuxAgentNFT.AgentCategory.MARKETING,  4500, 110 ether, true);

        // ── FINANCE (30–39) ───────────────────────────────────────────────
        powers[30] = PowerDefinition(INuxAgentNFT.AgentCategory.FINANCE,    1500,  40 ether, true);
        powers[31] = PowerDefinition(INuxAgentNFT.AgentCategory.FINANCE,    2500,  50 ether, true);
        powers[32] = PowerDefinition(INuxAgentNFT.AgentCategory.FINANCE,    3000,  65 ether, true);
        powers[33] = PowerDefinition(INuxAgentNFT.AgentCategory.FINANCE,    2000,  70 ether, true);
        powers[34] = PowerDefinition(INuxAgentNFT.AgentCategory.FINANCE,    2000,  75 ether, true);
        powers[35] = PowerDefinition(INuxAgentNFT.AgentCategory.FINANCE,    1500,  80 ether, true);
        powers[36] = PowerDefinition(INuxAgentNFT.AgentCategory.FINANCE,    2500,  90 ether, true);
        powers[37] = PowerDefinition(INuxAgentNFT.AgentCategory.FINANCE,    3000, 100 ether, true);
        powers[38] = PowerDefinition(INuxAgentNFT.AgentCategory.FINANCE,    2000, 130 ether, true);
        powers[39] = PowerDefinition(INuxAgentNFT.AgentCategory.FINANCE,    2500, 150 ether, true);

        // ── BUSINESS (40–49) ──────────────────────────────────────────────
        powers[40] = PowerDefinition(INuxAgentNFT.AgentCategory.BUSINESS,   3000,  40 ether, true);
        powers[41] = PowerDefinition(INuxAgentNFT.AgentCategory.BUSINESS,   2500,  55 ether, true);
        powers[42] = PowerDefinition(INuxAgentNFT.AgentCategory.BUSINESS,   2500,  60 ether, true);
        powers[43] = PowerDefinition(INuxAgentNFT.AgentCategory.BUSINESS,   3000,  65 ether, true);
        powers[44] = PowerDefinition(INuxAgentNFT.AgentCategory.BUSINESS,   3500,  70 ether, true);
        powers[45] = PowerDefinition(INuxAgentNFT.AgentCategory.BUSINESS,   2000,  75 ether, true);
        powers[46] = PowerDefinition(INuxAgentNFT.AgentCategory.BUSINESS,   3000,  80 ether, true);
        powers[47] = PowerDefinition(INuxAgentNFT.AgentCategory.BUSINESS,   2000,  90 ether, true);
        powers[48] = PowerDefinition(INuxAgentNFT.AgentCategory.BUSINESS,   2500, 100 ether, true);
        powers[49] = PowerDefinition(INuxAgentNFT.AgentCategory.BUSINESS,   4000, 130 ether, true);
        // Power names/descriptions are in export/config/agent-powers-metadata.json
    }
}

