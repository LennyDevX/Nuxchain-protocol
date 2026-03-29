// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IQuestRewardsPool
 * @notice Interface for the central quest rewards pool.
 * @dev Authorized modules (staking, collaborators, minigame) call requestPayout()
 *      to deliver quest rewards to users. The pool is funded by TreasuryManager's
 *      REWARDS allocation (set as treasuries[TreasuryType.REWARDS]).
 */
interface IQuestRewardsPool {

    // ============================================
    // EVENTS
    // ============================================

    event RewardPaid(
        address indexed recipient,
        uint256 amount,
        string  source,
        address indexed module
    );
    event FundsDeposited(address indexed sender, uint256 amount);

    // ============================================
    // FUND RECEPTION
    // ============================================

    /**
     * @notice Accept Treasury distribution funds (called by TreasuryManager).
     */
    function depositFromTreasury() external payable;

    // ============================================
    // PAYOUT
    // ============================================

    /**
     * @notice Request a reward payout to a user.
     * @dev    Callable only by addresses holding MODULE_ROLE.
     * @param  recipient  Address that receives the reward.
     * @param  amount     Amount in wei.
     * @param  source     Human-readable label: "staking_quest", "collaborator_quest", "minigame_quest".
     */
    function requestPayout(
        address recipient,
        uint256 amount,
        string calldata source
    ) external;

    // ============================================
    // VIEW
    // ============================================

    /**
     * @notice Return pool stats.
     * @return balance     Current ETH balance.
     * @return received    Total ETH received since deployment.
     * @return distributed Total ETH paid out to users.
     */
    function getPoolStats()
        external
        view
        returns (
            uint256 balance,
            uint256 received,
            uint256 distributed
        );
}
