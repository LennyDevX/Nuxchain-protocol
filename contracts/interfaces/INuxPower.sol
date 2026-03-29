// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IStakingIntegration.sol";

/**
 * @title INuxPower
 * @dev Interface for NuxPowers Marketplace
 * @notice Allows users to purchase, activate, and manage NuxPowers without NFT minting
 * @custom:security-contact security@nuvo.com
 */
interface INuxPower {
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev NuxPower structure - standalone purchase without NFT
     */
    struct NuxPower {
        IStakingIntegration.PowerType skillType;    // Type of power
        IStakingIntegration.Rarity rarity;          // Rarity level
        uint256 level;                              // Skill level
        address owner;                              // Current owner
        uint256 purchasedAt;                        // Purchase timestamp
        uint256 expiresAt;                          // Expiration timestamp (30 days)
        bool isActive;                              // Whether skill is active
        string metadata;                            // Unique ID for platform validation
        uint256 createdAt;                          // Creation timestamp
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    event nuxPowerPurchased(
        address indexed user,
        uint256 indexed skillId,
        IStakingIntegration.PowerType skillType,
        IStakingIntegration.Rarity rarity,
        uint256 price
    );
    
    event nuxPowerActivated(
        address indexed user,
        uint256 indexed skillId,
        IStakingIntegration.PowerType skillType
    );
    
    event nuxPowerDeactivated(
        address indexed user,
        uint256 indexed skillId,
        IStakingIntegration.PowerType skillType
    );
    
    event nuxPowerTransferred(
        address indexed from,
        address indexed to,
        uint256 indexed skillId,
        IStakingIntegration.PowerType skillType
    );
    
    event nuxPowerExpired(
        address indexed user,
        uint256 indexed skillId,
        IStakingIntegration.PowerType skillType
    );
    
    event nuxPowerRenewed(
        address indexed user,
        uint256 indexed skillId,
        uint256 newExpiryTime
    );
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MAIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Purchase NuxPower without NFT minting
     * @param _skillType Type of skill to purchase
     * @param _rarity Rarity level of skill
     * @param _level Skill level
     * @param _metadata Unique identifier for skill validation
     * @return skillId ID of newly purchased skill
     */
    function purchaseNuxPower(
        IStakingIntegration.PowerType _skillType,
        IStakingIntegration.Rarity _rarity,
        uint256 _level,
        string calldata _metadata
    ) external payable returns (uint256 skillId);
    
    /**
     * @dev Activate NuxPower
     * @param _skillId ID of skill to activate
     */
    function activateNuxPower(uint256 _skillId) external;
    
    /**
     * @dev Deactivate NuxPower
     * @param _skillId ID of skill to deactivate
     */
    function deactivateNuxPower(uint256 _skillId) external;
    
    /**
     * @dev Transfer NuxPower to another wallet
     * @param _skillId ID of skill to transfer
     * @param _recipient Address of skill recipient
     */
    function transferNuxPower(uint256 _skillId, address _recipient) external;
    
    /**
     * @dev Renew expired NuxPower
     * @param _skillId ID of skill to renew
     */
    function renewNuxPower(uint256 _skillId) external payable;
    
    /**
     * @dev Claim and cleanup expired skill
     * @param _skillId ID of skill to claim
     */
    function claimExpiredNuxPower(uint256 _skillId) external;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Get NuxPower details
     * @param _skillId ID of skill
     * @return skill NuxPower struct
     */
    function getNuxPower(uint256 _skillId) external view returns (NuxPower memory skill);
    
    /**
     * @dev Get all NuxPowers owned by user
     * @param _user Address of user
     * @return skillIds Array of skill IDs
     */
    function getUsernuxPowers(address _user) external view returns (uint256[] memory skillIds);
    
    /**
     * @dev Get active NuxPowers by type for user
     * @param _user Address of user
     * @param _skillType Type of skill
     * @return skillIds Array of active skill IDs
     */
    function getUserActivenuxPowers(address _user, IStakingIntegration.PowerType _skillType) external view returns (uint256[] memory skillIds);
    
    /**
     * @dev Calculate price for NuxPower
     * @param _rarity Rarity level
     * @return price Price in wei
     */
    function getnuxPowerPrice(IStakingIntegration.Rarity _rarity) external view returns (uint256 price);
    
    /**
     * @dev Get detailed NuxPowers for user (including status)
     * @param _user Address of user
     * @return skills Array of NuxPower structs
     * @return isActive Array of booleans indicating if skill is active
     */
    function getUsernuxPowersDetailed(address _user) external view returns (NuxPower[] memory skills, bool[] memory isActive);
}
