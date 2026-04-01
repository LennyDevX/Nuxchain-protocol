// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IXPHub
 * @notice Canonical XP & leveling interface for the Nuxchain Protocol.
 *
 * ARCHITECTURE
 * ─────────────────────────────────────────────────────────────────────
 *  LevelingSystem is the singleton hub implementation (contracts/Leveling/).
 *  All protocol contracts that award XP call awardXP() here instead of
 *  maintaining their own XP mappings.
 *
 * ROLES (implemented in LevelingSystem)
 *  MARKETPLACE_ROLE — legacy callers (MarketplaceCore, QuestCore,
 *                     NFT contracts, MiniGame).  Uses updateUserXP.
 *  REPORTER_ROLE    — new callers (Gamification, Auction,
 *                     NuxPower, Referral).  Uses awardXP() with source enum.
 *
 * XP SOURCE INDEXES (15 total)
 *  0  MARKETPLACE_BUY   1  MARKETPLACE_SELL  2  NFT_CREATE
 *  3  AGENT_MINT        4  AGENT_UPGRADE     5  AGENT_TASK
 *  6  STAKING           7  COMPOUND          8  QUEST
 *  9  ACHIEVEMENT       10 AUCTION_BID       11 AUCTION_WIN
 *  12 NUXPOWER          13 REFERRAL          14 SOCIAL
 */
interface IXPHub {

    // ─────────────────────────────────────────────────────────────────────
    // XP SOURCE ENUM  (uint8, 0–14)
    // ─────────────────────────────────────────────────────────────────────

    enum XPSource {
        MARKETPLACE_BUY,    // 0  NFT purchased on the Marketplace
        MARKETPLACE_SELL,   // 1  NFT sold on the Marketplace
        NFT_CREATE,         // 2  NFT created (single or batch)
        AGENT_MINT,         // 3  AI Agent NFT minted
        AGENT_UPGRADE,      // 4  NuxPower upgrade applied to an agent
        AGENT_TASK,         // 5  Agent task completed (MiniGame)
        STAKING,            // 6  POL staked in SmartStaking
        COMPOUND,           // 7  Rewards compounded in SmartStaking
        QUEST,              // 8  Quest completed (any contract)
        ACHIEVEMENT,        // 9  Achievement unlocked
        AUCTION_BID,        // 10 Bid placed in auction
        AUCTION_WIN,        // 11 Auction won
        NUXPOWER,           // 12 NuxPower purchased
        REFERRAL,           // 13 Referral conversion
        SOCIAL              // 14 Social action (like / comment)
    }

    // ─────────────────────────────────────────────────────────────────────
    // SHARED STRUCTS
    // ─────────────────────────────────────────────────────────────────────

    struct UserProfile {
        uint256 totalXP;
        uint8   level;
        uint256 nftsCreated;
        uint256 nftsOwned;
        uint32  nftsSold;
        uint32  nftsBought;
    }

    // ─────────────────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @notice Emitted on every awardXP() call.
     * @dev    `source` is indexed for cheap per-source frontend log filtering.
     *         Frontend query example:
     *           getLogs({ event: "XPAwarded", topics: [null, userAddress, null] })
     *           → group results by `source` to build the full XP breakdown.
     */
    event XPAwarded(
        address indexed user,
        uint256         amount,
        uint8   indexed source,
        uint256         newTotal,
        uint256         timestamp
    );

    // ─────────────────────────────────────────────────────────────────────
    // PRIMARY WRITE — REPORTER_ROLE
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @notice Award XP with source tracking (primary API for new callers).
     * @dev    Caller must hold REPORTER_ROLE on the LevelingSystem.
    *         Does NOT trigger level-up POL rewards to avoid double payment
    *         when the caller (e.g. Gamification) handles rewards itself.
     * @param  user      Recipient address.
     * @param  amount    XP to award.
     * @param  source    Origin of the XP (XPSource enum).
     * @return leveledUp True if the user reached a new level.
     * @return newLevel  The new level (0 if no level-up occurred).
     */
    function awardXP(address user, uint256 amount, XPSource source)
        external
        returns (bool leveledUp, uint8 newLevel);

    // ─────────────────────────────────────────────────────────────────────
    // BACKWARD-COMPATIBLE WRITE — MARKETPLACE_ROLE
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @notice Legacy XP update used by Marketplace & NFT contracts.
     *         Includes automatic level-up POL reward distribution.
     */
    function updateUserXP(address user, uint256 xpAmount, string calldata reason) external;

    /**
     * @notice Admin-only absolute XP synchronization.
     * @dev    Intended for migrations, corrections, and admin tooling.
     */
    function adminSetUserXP(address user, uint256 totalXP) external;

    /**
     * @notice Simple XP addition used by MiniGame and legacy callers.
     */
    function addXP(address user, uint256 amount) external;

    // ─────────────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Get a user's total XP and current level.
    function getUserXP(address user) external view returns (uint256 totalXP, uint8 level);

    /// @notice Full profile including NFT stats.
    function getUserProfile(address user) external view returns (UserProfile memory);

    /**
     * @notice Per-source XP breakdown for frontend dashboard widgets.
     * @return xpBySource Fixed-size array of 15 values, indexed by XPSource.
     */
    function getUserXPBreakdown(address user) external view returns (uint256[15] memory xpBySource);

    /// @notice Calculate level from cumulative XP (uses the protocol progression formula).
    function getLevelFromXP(uint256 xp) external pure returns (uint8 level);

    /// @notice XP required to clear a specific level (not cumulative).
    function getXPRequiredForLevel(uint8 level) external pure returns (uint256 xpRequired);

    /// @notice Cumulative XP required to reach a specific level.
    function getCumulativeXPForLevel(uint8 level) external pure returns (uint256 cumulativeXP);

    /// @notice Native token reward paid when a user reaches a specific level.
    function getRewardForLevel(uint8 level) external pure returns (uint256 rewardAmount);
}
