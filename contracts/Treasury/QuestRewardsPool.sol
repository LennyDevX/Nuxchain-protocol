// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IQuestRewardsPool.sol";

interface IQuestTreasury {
    enum TreasuryType { REWARDS, STAKING, COLLABORATORS, DEVELOPMENT, MARKETPLACE }
    function requestEmergencyFunds(TreasuryType treasuryType, uint256 amount) external returns (bool);
}

/**
 * @title QuestRewardsPool
 * @notice Central pool that holds all protocol quest & task rewards.
 *
 * ARCHITECTURE:
 *   - TreasuryManager's REWARDS treasury address should point to this contract.
 *   - Weekly distribution from TreasuryManager sends the REWARDS allocation here.
 *   - Authorized modules (MODULE_ROLE) call requestPayout() to pay users.
 *   - Sources: staking quests, collaborator badge quests, NFT mini-game tasks.
 *
 * REVENUE FLOW:
 *   TreasuryManager ──(REWARDS %)──▶ QuestRewardsPool
 *        ▲                                  │
 *   (all protocol fees)         requestPayout(user, amount, source)
 *                                           │
 *   SmartStakingRewards ────────────┤
 *   CollaboratorBadgeRewards ───────────────┤
 *   NuxAgentMiniGame ───────────────────────┘
 */
contract QuestRewardsPool is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IQuestRewardsPool
{
    // ============================================
    // ROLES
    // ============================================

    bytes32 public constant ADMIN_ROLE    = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Role granted to quest modules that are allowed to request payouts.
    bytes32 public constant MODULE_ROLE   = keccak256("MODULE_ROLE");

    // ============================================
    // STATE
    // ============================================

    uint256 public totalReceived;
    uint256 public totalDistributed;

    IQuestTreasury public treasuryManager;

    // ============================================
    // EVENTS (additional; interface events are reused)
    // ============================================

    event TreasuryManagerUpdated(address indexed oldAddr, address indexed newAddr);
    event EmergencyFundsRequested(uint256 deficit, bool success);

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address treasuryManager_
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);

        if (treasuryManager_ != address(0)) {
            treasuryManager = IQuestTreasury(treasuryManager_);
        }
    }

    // ============================================
    // FUND RECEPTION
    // ============================================

    /// @notice Accept any direct ETH transfers (e.g. from TreasuryManager distribution).
    receive() external payable {
        totalReceived += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    /// @inheritdoc IQuestRewardsPool
    function depositFromTreasury() external payable override {
        totalReceived += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    // ============================================
    // PAYOUT
    // ============================================

    /// @inheritdoc IQuestRewardsPool
    function requestPayout(
        address recipient,
        uint256 amount,
        string calldata source
    ) external override nonReentrant onlyRole(MODULE_ROLE) {
        require(recipient != address(0), "Pool: invalid recipient");
        require(amount > 0, "Pool: zero amount");

        // If pool is short, request emergency funds from TreasuryManager
        if (address(this).balance < amount && address(treasuryManager) != address(0)) {
            uint256 deficit = amount - address(this).balance;
            bool emergencySuccess;
            try treasuryManager.requestEmergencyFunds(IQuestTreasury.TreasuryType.REWARDS, deficit)
                returns (bool result)
            {
                emergencySuccess = result;
            } catch {
                emergencySuccess = false;
            }
            emit EmergencyFundsRequested(deficit, emergencySuccess);
        }

        require(address(this).balance >= amount, "Pool: insufficient balance");

        totalDistributed += amount;

        (bool ok, ) = payable(recipient).call{value: amount}("");
        require(ok, "Pool: transfer failed");

        emit RewardPaid(recipient, amount, source, msg.sender);
    }

    // ============================================
    // ADMIN
    // ============================================

    function setTreasuryManager(address tm_) external onlyRole(ADMIN_ROLE) {
        require(tm_ != address(0), "Pool: invalid address");
        emit TreasuryManagerUpdated(address(treasuryManager), tm_);
        treasuryManager = IQuestTreasury(tm_);
    }

    /// @notice Emergency ETH withdraw to admin (safety valve)
    function emergencyWithdraw(address recipient, uint256 amount) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(recipient != address(0), "Pool: invalid recipient");
        require(amount <= address(this).balance, "Pool: insufficient balance");
        (bool ok, ) = payable(recipient).call{value: amount}("");
        require(ok, "Pool: withdraw failed");
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ============================================
    // VIEW
    // ============================================

    /// @inheritdoc IQuestRewardsPool
    function getPoolStats()
        external
        view
        override
        returns (uint256 balance, uint256 received, uint256 distributed)
    {
        return (address(this).balance, totalReceived, totalDistributed);
    }
}
