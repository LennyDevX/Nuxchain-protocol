// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IXPHub.sol";

/**
 * @title XPSourceMetadata
 * @notice Read-only on-chain metadata for every XPSource.
 *
 * PURPOSE
 * ───────────────────────────────────────────────────────────────────────
 *  Provides human-readable labels, emoji icons, and relative XP multipliers
 *  for each of the 15 XP sources so that frontend dashboards and admin panels
 *  can render XP breakdowns without hard-coding strings in the UI.
 *
 * DEPLOYMENT
 *  This is a stateless helper — deploy once, never upgrade.
 *  Reference from the frontend via:
 *    const meta = await XPSourceMetadata.getSourceMetadata(sourceIndex);
 *
 * MULTIPLIER SEMANTICS
 *  `multiplierBps` is expressed in basis points (10 000 = 1×, i.e. no bonus).
 *  At 10 000 bps a user earns exactly the base XP defined in LevelingSystem.
 *  Values above 10 000 indicate a premium activity:
 *    e.g. 15 000 bps → 1.5× multiplier (used for AGENT_MINT, AUCTION_WIN, etc.)
 *  Values below 10 000 indicate a bonus-reduced activity.
 *  The multiplier stored here is INFORMATIONAL — LevelingSystem hard-codes its
 *  own XP constants.  This contract is purely for frontend display purposes.
 */
contract XPSourceMetadata {

    uint8 public constant TOTAL_SOURCES = 15;

    struct SourceMeta {
        string label;       // Human-readable name (e.g. "Buy NFT")
        string icon;        // Emoji icon for UI cards
        string category;    // Grouping: "Marketplace", "Staking", "Agent NFT", etc.
        string description; // Short description shown in tooltips
        uint16 multiplierBps; // Relative weight vs. base (10 000 = 1×)
        uint256 baseXP;     // Typical base XP amount for this action
    }

    // ─────────────────────────────────────────────────────────────────────
    // STORAGE (indexed by uint8(XPSource))
    // ─────────────────────────────────────────────────────────────────────

    mapping(uint8 => SourceMeta) private _meta;

    // ─────────────────────────────────────────────────────────────────────
    // CONSTRUCTOR — populate all metadata
    // ─────────────────────────────────────────────────────────────────────

    constructor() {
        // 0 — MARKETPLACE_BUY
        _meta[0] = SourceMeta({
            label:          "Buy NFT",
            icon:           "\xF0\x9F\x9B\x92",   // 🛒
            category:       "Marketplace",
            description:    "Earned when you purchase an NFT on the Nuxchain Marketplace.",
            multiplierBps:  10000,
            baseXP:         15
        });

        // 1 — MARKETPLACE_SELL
        _meta[1] = SourceMeta({
            label:          "Sell NFT",
            icon:           "\xF0\x9F\x92\xB0",   // 💰
            category:       "Marketplace",
            description:    "Earned when one of your NFTs is sold on the Marketplace.",
            multiplierBps:  10000,
            baseXP:         20
        });

        // 2 — NFT_CREATE
        _meta[2] = SourceMeta({
            label:          "Create NFT",
            icon:           "\xF0\x9F\x8E\xA8",   // 🎨
            category:       "Marketplace",
            description:    "Earned when you mint a new NFT. Batch minting scales with count.",
            multiplierBps:  10000,
            baseXP:         10
        });

        // 3 — AGENT_MINT
        _meta[3] = SourceMeta({
            label:          "Mint AI Agent",
            icon:           "\xF0\x9F\xA4\x96",   // 🤖
            category:       "Agent NFT",
            description:    "Earned when you mint a new AI Agent NFT.",
            multiplierBps:  15000,
            baseXP:         50
        });

        // 4 — AGENT_UPGRADE
        _meta[4] = SourceMeta({
            label:          "Upgrade Agent",
            icon:           "\xE2\x9A\xA1",        // ⚡
            category:       "Agent NFT",
            description:    "Earned when you equip a NuxPower upgrade to your Agent NFT.",
            multiplierBps:  10000,
            baseXP:         20
        });

        // 5 — AGENT_TASK
        _meta[5] = SourceMeta({
            label:          "Complete Task",
            icon:           "\xE2\x9C\x85",        // ✅
            category:       "Agent NFT",
            description:    "Earned when your AI Agent completes an approved task (MiniGame).",
            multiplierBps:  10000,
            baseXP:         10
        });

        // 6 — STAKING
        _meta[6] = SourceMeta({
            label:          "Stake POL",
            icon:           "\xF0\x9F\x94\x92",   // 🔒
            category:       "Smart Staking",
            description:    "Earned when you stake POL. Rate: 1 XP per 2 POL staked.",
            multiplierBps:  5000,
            baseXP:         1     // per 2 POL
        });

        // 7 — COMPOUND
        _meta[7] = SourceMeta({
            label:          "Compound Rewards",
            icon:           "\xF0\x9F\x94\x84",   // 🔄
            category:       "Smart Staking",
            description:    "Earned each time your staking rewards are compounded.",
            multiplierBps:  10000,
            baseXP:         3
        });

        // 8 — QUEST
        _meta[8] = SourceMeta({
            label:          "Complete Quest",
            icon:           "\xF0\x9F\x8F\x86",   // 🏆
            category:       "Quests",
            description:    "Earned for completing quests across any Nuxchain module.",
            multiplierBps:  10000,
            baseXP:         25    // variable (10–50 000 depending on quest)
        });

        // 9 — ACHIEVEMENT
        _meta[9] = SourceMeta({
            label:          "Achievement",
            icon:           "\xF0\x9F\x8C\x9F",   // 🌟
            category:       "Quests",
            description:    "Earned when you unlock a special achievement.",
            multiplierBps:  20000,
            baseXP:         100
        });

        // 10 — AUCTION_BID
        _meta[10] = SourceMeta({
            label:          "Place Bid",
            icon:           "\xF0\x9F\x94\xA8",   // 🔨
            category:       "Auction",
            description:    "Earned each time you place a bid in an English auction.",
            multiplierBps:  10000,
            baseXP:         10
        });

        // 11 — AUCTION_WIN
        _meta[11] = SourceMeta({
            label:          "Win Auction",
            icon:           "\xF0\x9F\x8F\x85",   // 🏅
            category:       "Auction",
            description:    "Earned when you win an auction and receive the NFT.",
            multiplierBps:  20000,
            baseXP:         100
        });

        // 12 — NUXPOWER
        _meta[12] = SourceMeta({
            label:          "Buy NuxPower",
            icon:           "\xE2\x9A\x9B\xEF\xB8\x8F",  // ⚛️
            category:       "Agent NFT",
            description:    "Earned when you purchase a NuxPower upgrade from the store.",
            multiplierBps:  10000,
            baseXP:         30
        });

        // 13 — REFERRAL
        _meta[13] = SourceMeta({
            label:          "Referral",
            icon:           "\xF0\x9F\x91\xA5",   // 👥
            category:       "Social",
            description:    "Earned when a user you referred makes their first purchase.",
            multiplierBps:  15000,
            baseXP:         50
        });

        // 14 — SOCIAL
        _meta[14] = SourceMeta({
            label:          "Social Action",
            icon:           "\xF0\x9F\x92\xAC",   // 💬
            category:       "Social",
            description:    "Earned for likes and comments on the Marketplace social feed.",
            multiplierBps:  5000,
            baseXP:         5
        });
    }

    // ─────────────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Metadata for a single XP source.
    function getSourceMetadata(uint8 source) external view returns (SourceMeta memory) {
        require(source < TOTAL_SOURCES, "XPSourceMetadata: invalid source");
        return _meta[source];
    }

    /// @notice Metadata for all 15 XP sources in one call (frontend convenience).
    function getAllSourceMetadata() external view returns (SourceMeta[15] memory all) {
        for (uint8 i = 0; i < TOTAL_SOURCES; i++) {
            all[i] = _meta[i];
        }
    }

    /// @notice Returns the label for a source (e.g. for event log parsing).
    function getSourceLabel(uint8 source) external view returns (string memory) {
        require(source < TOTAL_SOURCES, "XPSourceMetadata: invalid source");
        return _meta[source].label;
    }

    /// @notice Returns the category for a source (e.g. "Marketplace", "Staking").
    function getSourceCategory(uint8 source) external view returns (string memory) {
        require(source < TOTAL_SOURCES, "XPSourceMetadata: invalid source");
        return _meta[source].category;
    }

    /**
     * @notice Returns the multiplierBps for a source.
     *         10 000 bps = 1× (no bonus).
     */
    function getSourceMultiplier(uint8 source) external view returns (uint16) {
        require(source < TOTAL_SOURCES, "XPSourceMetadata: invalid source");
        return _meta[source].multiplierBps;
    }

    /// @notice Returns all category names available (useful for building filter dropdowns).
    function getAllCategories() external pure returns (string[5] memory) {
        return [
            "Marketplace",
            "Agent NFT",
            "Smart Staking",
            "Quests",
            "Auction"
        ];
    }
}
