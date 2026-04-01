// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract NuxTapTreasury is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");
    bytes32 public constant STORE_ROLE = keccak256("STORE_ROLE");

    uint256 public totalRevenueReceived;
    uint256 public totalRewardFundingReceived;
    uint256 public totalRewardsDistributed;
    uint256 public totalProtocolFeesRetained;
    uint256 public totalEmergencyWithdrawn;
    uint256 public rewardLiquidity;
    uint256 public reservedLiquidity;
    uint256 public maxSinglePayout;
    uint256 public dailyPayoutCap;
    uint256 public dailyPayoutSpent;
    uint256 public payoutDay;

    event RevenueDeposited(address indexed sender, uint256 amount, string revenueType, bool rewardFunding);
    event RewardPaid(address indexed recipient, uint256 grossAmount, uint256 feeAmount, string reason);
    event DailyPayoutCapUpdated(uint256 oldCap, uint256 newCap);
    event MaxSinglePayoutUpdated(uint256 oldCap, uint256 newCap);
    event LiquidityReserved(uint256 amount, uint256 totalReserved);
    event ReservedLiquidityReleased(uint256 amount, uint256 totalReserved);
    event EmergencyWithdrawal(address indexed recipient, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin_) external initializer {
        require(admin_ != address(0), "NuxTapTreasury: invalid admin");

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(TREASURER_ROLE, admin_);
        _grantRole(GAME_ROLE, admin_);
        _grantRole(STORE_ROLE, admin_);

        maxSinglePayout = 250 ether;
        dailyPayoutCap = 2_500 ether;
        payoutDay = block.timestamp / 1 days;
    }

    receive() external payable {
        _depositRevenue("direct_funding", true);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function depositRevenue(string calldata revenueType) external payable onlyRole(STORE_ROLE) whenNotPaused {
        _depositRevenue(revenueType, false);
    }

    function fundRewards(string calldata source) external payable onlyRole(TREASURER_ROLE) whenNotPaused {
        _depositRevenue(source, true);
    }

    function reserveLiquidity(uint256 amount) external onlyRole(GAME_ROLE) whenNotPaused {
        require(amount <= availableLiquidity(), "NuxTapTreasury: insufficient liquidity");
        reservedLiquidity += amount;
        emit LiquidityReserved(amount, reservedLiquidity);
    }

    function releaseReservedLiquidity(uint256 amount) external onlyRole(GAME_ROLE) {
        require(amount <= reservedLiquidity, "NuxTapTreasury: insufficient reserved");
        reservedLiquidity -= amount;
        emit ReservedLiquidityReleased(amount, reservedLiquidity);
    }

    function payReward(
        address recipient,
        uint256 grossAmount,
        uint256 feeAmount,
        string calldata reason
    ) external onlyRole(GAME_ROLE) whenNotPaused nonReentrant {
        require(recipient != address(0), "NuxTapTreasury: invalid recipient");
        require(grossAmount > 0, "NuxTapTreasury: zero reward");
        require(feeAmount <= grossAmount, "NuxTapTreasury: invalid fee");
        require(grossAmount <= maxSinglePayout, "NuxTapTreasury: payout too large");

        _syncDailyPayoutWindow();
        require(dailyPayoutSpent + grossAmount <= dailyPayoutCap, "NuxTapTreasury: daily cap exceeded");
        require(grossAmount <= rewardLiquidity, "NuxTapTreasury: insufficient reward liquidity");

        uint256 netAmount = grossAmount - feeAmount;

        rewardLiquidity -= grossAmount;
        if (reservedLiquidity >= grossAmount) {
            reservedLiquidity -= grossAmount;
        }

        dailyPayoutSpent += grossAmount;
        totalRewardsDistributed += grossAmount;
        totalProtocolFeesRetained += feeAmount;

        (bool ok, ) = payable(recipient).call{value: netAmount}("");
        require(ok, "NuxTapTreasury: transfer failed");

        emit RewardPaid(recipient, grossAmount, feeAmount, reason);
    }

    function setDailyPayoutCap(uint256 newCap) external onlyRole(ADMIN_ROLE) {
        emit DailyPayoutCapUpdated(dailyPayoutCap, newCap);
        dailyPayoutCap = newCap;
    }

    function setMaxSinglePayout(uint256 newCap) external onlyRole(ADMIN_ROLE) {
        emit MaxSinglePayoutUpdated(maxSinglePayout, newCap);
        maxSinglePayout = newCap;
    }

    function grantGameRole(address game_) external onlyRole(ADMIN_ROLE) {
        _grantRole(GAME_ROLE, game_);
    }

    function grantStoreRole(address store_) external onlyRole(ADMIN_ROLE) {
        _grantRole(STORE_ROLE, store_);
    }

    function emergencyWithdraw(address recipient, uint256 amount) external onlyRole(TREASURER_ROLE) nonReentrant {
        require(recipient != address(0), "NuxTapTreasury: invalid recipient");
        require(amount <= address(this).balance, "NuxTapTreasury: insufficient balance");
        if (amount <= rewardLiquidity) {
            rewardLiquidity -= amount;
        } else {
            rewardLiquidity = 0;
        }
        totalEmergencyWithdrawn += amount;

        (bool ok, ) = payable(recipient).call{value: amount}("");
        require(ok, "NuxTapTreasury: withdrawal failed");

        emit EmergencyWithdrawal(recipient, amount);
    }

    function getTreasuryStats()
        external
        view
        returns (
            uint256 balance,
            uint256 rewardBalance,
            uint256 available,
            uint256 reserved,
            uint256 distributed,
            uint256 feesRetained,
            uint256 revenueReceived
        )
    {
        return (
            address(this).balance,
            rewardLiquidity,
            availableLiquidity(),
            reservedLiquidity,
            totalRewardsDistributed,
            totalProtocolFeesRetained,
            totalRevenueReceived
        );
    }

    function availableLiquidity() public view returns (uint256) {
        if (rewardLiquidity <= reservedLiquidity) {
            return 0;
        }
        return rewardLiquidity - reservedLiquidity;
    }

    function _depositRevenue(string memory revenueType, bool rewardFunding) internal {
        require(msg.value > 0, "NuxTapTreasury: zero deposit");

        totalRevenueReceived += msg.value;
        rewardLiquidity += msg.value;

        if (rewardFunding) {
            totalRewardFundingReceived += msg.value;
        }

        emit RevenueDeposited(msg.sender, msg.value, revenueType, rewardFunding);
    }

    function _syncDailyPayoutWindow() internal {
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay != payoutDay) {
            payoutDay = currentDay;
            dailyPayoutSpent = 0;
        }
    }

    uint256[50] private __gap;

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}