// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IStakingIntegration.sol";

/**
 * @title IIndividualSkills
 * @dev Interface for Individual Skills Marketplace
 * @notice Allows users to purchase, activate, and manage individual skills without NFT minting
 * @custom:security-contact security@nuvo.com
 */
interface IIndividualSkills {
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Individual Skill structure - standalone purchase without NFT
     */
    struct IndividualSkill {
        IStakingIntegration.SkillType skillType;    // Type of skill
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
    
    event IndividualSkillPurchased(
        address indexed user,
        uint256 indexed skillId,
        IStakingIntegration.SkillType skillType,
        IStakingIntegration.Rarity rarity,
        uint256 price
    );
    
    event IndividualSkillActivated(
        address indexed user,
        uint256 indexed skillId,
        IStakingIntegration.SkillType skillType
    );
    
    event IndividualSkillDeactivated(
        address indexed user,
        uint256 indexed skillId,
        IStakingIntegration.SkillType skillType
    );
    
    event IndividualSkillTransferred(
        address indexed from,
        address indexed to,
        uint256 indexed skillId,
        IStakingIntegration.SkillType skillType
    );
    
    event IndividualSkillExpired(
        address indexed user,
        uint256 indexed skillId,
        IStakingIntegration.SkillType skillType
    );
    
    event IndividualSkillRenewed(
        address indexed user,
        uint256 indexed skillId,
        uint256 newExpiryTime
    );
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // MAIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Purchase individual skill without NFT minting
     * @param _skillType Type of skill to purchase
     * @param _rarity Rarity level of skill
     * @param _level Skill level
     * @param _metadata Unique identifier for skill validation
     * @return skillId ID of newly purchased skill
     */
    function purchaseIndividualSkill(
        IStakingIntegration.SkillType _skillType,
        IStakingIntegration.Rarity _rarity,
        uint256 _level,
        string calldata _metadata
    ) external payable returns (uint256 skillId);
    
    /**
     * @dev Activate individual skill
     * @param _skillId ID of skill to activate
     */
    function activateIndividualSkill(uint256 _skillId) external;
    
    /**
     * @dev Deactivate individual skill
     * @param _skillId ID of skill to deactivate
     */
    function deactivateIndividualSkill(uint256 _skillId) external;
    
    /**
     * @dev Transfer individual skill to another wallet
     * @param _skillId ID of skill to transfer
     * @param _recipient Address of skill recipient
     */
    function transferIndividualSkill(uint256 _skillId, address _recipient) external;
    
    /**
     * @dev Renew expired individual skill
     * @param _skillId ID of skill to renew
     */
    function renewIndividualSkill(uint256 _skillId) external payable;
    
    /**
     * @dev Claim and cleanup expired skill
     * @param _skillId ID of skill to claim
     */
    function claimExpiredIndividualSkill(uint256 _skillId) external;
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Get individual skill details
     * @param _skillId ID of skill
     * @return skill IndividualSkill struct
     */
    function getIndividualSkill(uint256 _skillId) external view returns (IndividualSkill memory skill);
    
    /**
     * @dev Get all individual skills owned by user
     * @param _user Address of user
     * @return skillIds Array of skill IDs
     */
    function getUserIndividualSkills(address _user) external view returns (uint256[] memory skillIds);
    
    /**
     * @dev Get active individual skills by type for user
     * @param _user Address of user
     * @param _skillType Type of skill
     * @return skillIds Array of active skill IDs
     */
    function getUserActiveIndividualSkills(address _user, IStakingIntegration.SkillType _skillType) external view returns (uint256[] memory skillIds);
    
    /**
     * @dev Calculate price for individual skill
     * @param _rarity Rarity level
     * @return price Price in wei
     */
    function getIndividualSkillPrice(IStakingIntegration.Rarity _rarity) external pure returns (uint256 price);
    
    /**
     * @dev Get detailed individual skills for user (including status)
     * @param _user Address of user
     * @return skills Array of IndividualSkill structs
     * @return isActive Array of booleans indicating if skill is active
     */
    function getUserIndividualSkillsDetailed(address _user) external view returns (IndividualSkill[] memory skills, bool[] memory isActive);
}
