// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IStakingIntegration.sol";

/**
 * @title ISmartStakingPower
 * @notice Interface for NFT power management in the SmartStaking system
 * @dev This module handles power activation/deactivation, rarity tracking, and boost calculations
 */
interface ISmartStakingPower {
    
    // ============================================
    // ENUMS
    // ============================================
    
    enum PowerRarity {
        Common,      // 100% multiplier
        Uncommon,    // 150% multiplier
        Rare,        // 200% multiplier
        Epic,        // 300% multiplier
        Legendary    // 500% multiplier
    }
    
    // ============================================
    // STRUCTS
    // ============================================
    
    struct UserPowerProfile {
        uint256[] activeSkillNFTIds;
        uint16 totalBoost;          // Deprecated/Legacy generic boost
        uint16 stakingBoostTotal;   // Specific APY boost
        uint16 feeDiscountTotal;    // Specific Fee discount
        uint16 lockTimeReduction;   // Specific Lock time reduction
        bool hasAutoCompound;       // Auto compound status
        uint16 rarityMultiplier;
        uint16 level;
        uint8 activeSkillCount;
    }
    
    struct PowerInfo {
        uint256 nftId;
        IStakingIntegration.PowerType powerType;
        PowerRarity rarity;
        uint16 boost;
        uint16 rarityMultiplier;
        bool isActive;
        uint64 activatedAt;
        uint64 cooldownEnds;
    }
    
    // ============================================
    // EVENTS
    // ============================================
    
    event PowerActivated(
        address indexed user,
        uint256 indexed nftId,
        IStakingIntegration.PowerType powerType,
        uint16 effectValue,
        uint16 totalBoost
    );
    event PowerDeactivated(
        address indexed user,
        uint256 indexed nftId,
        IStakingIntegration.PowerType powerType,
        uint16 totalBoost
    );
    event PowerRarityUpdated(uint256 indexed nftId, PowerRarity rarity, uint16 rarityMultiplier);
    
    // ============================================
    // STATE-CHANGING FUNCTIONS
    // ============================================
    
    /**
     * @notice Notify that a power NFT has been activated for a user
     * @param user The user address
     * @param nftId The NFT ID
     * @param powerType The power type defined in IStakingIntegration
     * @param effectValue The effect value in basis points (overrides defaults when > 0)
     */
    function notifyPowerActivation(
        address user,
        uint256 nftId,
        IStakingIntegration.PowerType powerType,
        uint16 effectValue
    ) external;
    
    /**
     * @notice Notify that a power NFT has been deactivated for a user
     * @param user The user address
     * @param nftId The NFT ID
     */
    function notifyPowerDeactivation(address user, uint256 nftId) external;
    
    /**
     * @notice Set the rarity for a specific NFT
     * @param nftId The NFT ID
     * @param rarity The rarity level
     */
    function setPowerRarity(uint256 nftId, PowerRarity rarity) external;
    
    /**
     * @notice Batch set rarities for multiple NFTs
     * @param nftIds Array of NFT IDs
     * @param rarities Array of rarity levels
     */
    function batchSetPowerRarity(uint256[] calldata nftIds, PowerRarity[] calldata rarities) external;

    /**
     * @notice Update the default boost for a specific power type
     * @param powerType The power type defined in IStakingIntegration
     * @param newBoost The new effect value in basis points
     */
    function updatePowerBoost(IStakingIntegration.PowerType powerType, uint16 newBoost) external;
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @notice Get the power profile for a user
     * @param user The user address
     * @return profile The user's power profile
     */
    function getUserPowerProfile(address user) external view returns (UserPowerProfile memory profile);
    
    /**
     * @notice Get active powers with full details for a user
     * @param user The user address
     * @return powers Array of power information
     */
    function getActivePowersWithDetails(address user) external view returns (PowerInfo[] memory powers);
    
    /**
     * @notice Get the rarity information for an NFT
     * @param nftId The NFT ID
     * @return rarity The rarity level
     * @return multiplier The rarity multiplier (100-500)
     */
    function getPowerRarity(uint256 nftId) external view returns (PowerRarity rarity, uint16 multiplier);
    
    /**
     * @notice Get the boost percentage for a power type
     * @param powerType The power type defined in IStakingIntegration
     * @return boost The boost percentage
     */
    function getPowerBoost(IStakingIntegration.PowerType powerType) external view returns (uint16 boost);
    
    /**
     * @notice Get all power type configurations
     * @return powerTypes Array of power type IDs
     * @return boosts Array of boost percentages
     */
    function getAllPowerBoosts()
        external
        view
        returns (IStakingIntegration.PowerType[] memory powerTypes, uint16[] memory boosts);
    
    /**
     * @notice Check if a user has a specific power active
     * @param user The user address
     * @param nftId The NFT ID
     * @return isActive True if the power is active
     */
    function isPowerActive(address user, uint256 nftId) external view returns (bool isActive);
    
    /**
     * @notice Get the total boost for a user including rarity multipliers
     * @param user The user address
     * @return totalBoost The base total boost percentage
     * @return rarityMultiplier The rarity multiplier (100-500)
     * @return effectiveBoost The effective boost after rarity (totalBoost * rarityMultiplier / 100)
     */
    function getUserBoosts(address user) external view returns (
        uint16 totalBoost,
        uint16 rarityMultiplier,
        uint16 effectiveBoost
    );
}
