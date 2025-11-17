// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IStakingIntegration.sol";

/**
 * @title IEnhancedSmartStakingSkills
 * @notice Interface for NFT skill management in the EnhancedSmartStaking system
 * @dev This module handles skill activation/deactivation, rarity tracking, and boost calculations
 */
interface IEnhancedSmartStakingSkills {
    
    // ============================================
    // ENUMS
    // ============================================
    
    enum SkillRarity {
        Common,      // 100% multiplier
        Uncommon,    // 150% multiplier
        Rare,        // 200% multiplier
        Epic,        // 300% multiplier
        Legendary    // 500% multiplier
    }
    
    // ============================================
    // STRUCTS
    // ============================================
    
    struct UserSkillProfile {
        uint256[] activeSkillNFTIds;
        uint16 totalBoost;
        uint16 rarityMultiplier;
        uint16 level;
        uint8 activeSkillCount;
    }
    
    struct SkillInfo {
        uint256 nftId;
        IStakingIntegration.SkillType skillType;
        SkillRarity rarity;
        uint16 boost;
        uint16 rarityMultiplier;
        bool isActive;
        uint64 activatedAt;
        uint64 cooldownEnds;
    }
    
    // ============================================
    // EVENTS
    // ============================================
    
    event SkillActivated(
        address indexed user,
        uint256 indexed nftId,
        IStakingIntegration.SkillType skillType,
        uint16 effectValue,
        uint16 totalBoost
    );
    event SkillDeactivated(
        address indexed user,
        uint256 indexed nftId,
        IStakingIntegration.SkillType skillType,
        uint16 totalBoost
    );
    event SkillRarityUpdated(uint256 indexed nftId, SkillRarity rarity, uint16 rarityMultiplier);
    
    // ============================================
    // STATE-CHANGING FUNCTIONS
    // ============================================
    
    /**
     * @notice Notify that a skill NFT has been activated for a user
     * @param user The user address
     * @param nftId The NFT ID
    * @param skillType The skill type defined in IStakingIntegration
    * @param effectValue The effect value in basis points (overrides defaults when > 0)
     */
    function notifySkillActivation(
        address user,
        uint256 nftId,
        IStakingIntegration.SkillType skillType,
        uint16 effectValue
    ) external;
    
    /**
     * @notice Notify that a skill NFT has been deactivated for a user
     * @param user The user address
     * @param nftId The NFT ID
     */
    function notifySkillDeactivation(address user, uint256 nftId) external;
    
    /**
     * @notice Set the rarity for a specific NFT
     * @param nftId The NFT ID
     * @param rarity The rarity level
     */
    function setSkillRarity(uint256 nftId, SkillRarity rarity) external;
    
    /**
     * @notice Batch set rarities for multiple NFTs
     * @param nftIds Array of NFT IDs
     * @param rarities Array of rarity levels
     */
    function batchSetSkillRarity(uint256[] calldata nftIds, SkillRarity[] calldata rarities) external;

    /**
     * @notice Update the default boost for a specific skill type
     * @param skillType The skill type defined in IStakingIntegration
     * @param newBoost The new effect value in basis points
     */
    function updateSkillBoost(IStakingIntegration.SkillType skillType, uint16 newBoost) external;
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @notice Get the skill profile for a user
     * @param user The user address
     * @return profile The user's skill profile
     */
    function getUserSkillProfile(address user) external view returns (UserSkillProfile memory profile);
    
    /**
     * @notice Get active skills with full details for a user
     * @param user The user address
     * @return skills Array of skill information
     */
    function getActiveSkillsWithDetails(address user) external view returns (SkillInfo[] memory skills);
    
    /**
     * @notice Get the rarity information for an NFT
     * @param nftId The NFT ID
     * @return rarity The rarity level
     * @return multiplier The rarity multiplier (100-500)
     */
    function getSkillRarity(uint256 nftId) external view returns (SkillRarity rarity, uint16 multiplier);
    
    /**
     * @notice Get the boost percentage for a skill type
    * @param skillType The skill type defined in IStakingIntegration
     * @return boost The boost percentage
     */
    function getSkillBoost(IStakingIntegration.SkillType skillType) external view returns (uint16 boost);
    
    /**
     * @notice Get all skill type configurations
     * @return skillTypes Array of skill type IDs
     * @return boosts Array of boost percentages
     */
    function getAllSkillBoosts()
        external
        view
        returns (IStakingIntegration.SkillType[] memory skillTypes, uint16[] memory boosts);
    
    /**
     * @notice Check if a user has a specific skill active
     * @param user The user address
     * @param nftId The NFT ID
     * @return isActive True if the skill is active
     */
    function isSkillActive(address user, uint256 nftId) external view returns (bool isActive);
    
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
