// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IEnhancedSmartStakingSkills.sol";
import "../interfaces/IStakingIntegration.sol";

/**
 * @title EnhancedSmartStakingSkills
 * @notice Handles NFT skill management for the EnhancedSmartStaking system
 * @dev Manages skill activation/deactivation, rarity tracking, and boost calculations
 */
contract EnhancedSmartStakingSkills is Ownable, IEnhancedSmartStakingSkills {
    using EnumerableSet for EnumerableSet.UintSet;
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    /// @notice Basis points denominator
    uint256 private constant BASIS_POINTS = 10000;
    
    /// @notice Maximum active skills per user
    uint8 private constant MAX_ACTIVE_SKILLS = 10;
    
    /// @notice Number of skill types
    uint8 private constant SKILL_TYPE_COUNT = 17;
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /// @notice Address of the marketplace contract (authorized caller)
    address public marketplaceContract;
    
    /// @notice Address of the core staking contract
    address public coreStakingContract;
    
    /// @notice Maps user address to their active NFT skill IDs
    mapping(address => EnumerableSet.UintSet) private _userActiveSkillNFTs;
    
    /// @notice Maps user address to their skill profile
    mapping(address => UserSkillProfile) private _userSkillProfiles;

    struct SkillInstance {
        IStakingIntegration.SkillType skillType;
        uint16 effectValue;
        uint64 activatedAt;
        uint64 cooldownEnds;
        bool isActive;
    }
    
    /// @notice Tracks per-user skill metadata
    mapping(address => mapping(uint256 => SkillInstance)) private _userSkillDetails;
    
    /// @notice Maps NFT ID to its rarity
    mapping(uint256 => SkillRarity) private _nftRarity;
    
    /// @notice Maps skill type to its boost percentage (in basis points)
    mapping(IStakingIntegration.SkillType => uint16) private _skillBoosts;
    
    /// @notice Maps rarity to multiplier (100 = 1x, 500 = 5x)
    mapping(SkillRarity => uint16) private _rarityMultipliers;
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    modifier onlyMarketplace() {
        require(msg.sender == marketplaceContract, "Only marketplace");
        _;
    }
    
    modifier onlyCore() {
        require(msg.sender == coreStakingContract, "Only core");
        _;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        // Initialize rarity multipliers
        _rarityMultipliers[SkillRarity.Common] = 100;      // 1x
        _rarityMultipliers[SkillRarity.Uncommon] = 150;    // 1.5x
        _rarityMultipliers[SkillRarity.Rare] = 200;        // 2x
        _rarityMultipliers[SkillRarity.Epic] = 300;        // 3x
        _rarityMultipliers[SkillRarity.Legendary] = 500;   // 5x
        
        // Initialize default skill boosts mapped to staking integration enum
        _skillBoosts[IStakingIntegration.SkillType.NONE] = 0;
        _skillBoosts[IStakingIntegration.SkillType.STAKE_BOOST_I] = 500;    // +5% APY
        _skillBoosts[IStakingIntegration.SkillType.STAKE_BOOST_II] = 1000;  // +10% APY
        _skillBoosts[IStakingIntegration.SkillType.STAKE_BOOST_III] = 2000; // +20% APY
        _skillBoosts[IStakingIntegration.SkillType.AUTO_COMPOUND] = 0;      // handled separately
        _skillBoosts[IStakingIntegration.SkillType.LOCK_REDUCER] = 250;     // -2.5% lock time equivalent
        _skillBoosts[IStakingIntegration.SkillType.FEE_REDUCER_I] = 1000;   // -10% fees
        _skillBoosts[IStakingIntegration.SkillType.FEE_REDUCER_II] = 2500;  // -25% fees
        _skillBoosts[IStakingIntegration.SkillType.PRIORITY_LISTING] = 0;
        _skillBoosts[IStakingIntegration.SkillType.BATCH_MINTER] = 0;
        _skillBoosts[IStakingIntegration.SkillType.VERIFIED_CREATOR] = 0;
        _skillBoosts[IStakingIntegration.SkillType.INFLUENCER] = 0;
        _skillBoosts[IStakingIntegration.SkillType.CURATOR] = 0;
        _skillBoosts[IStakingIntegration.SkillType.AMBASSADOR] = 0;
        _skillBoosts[IStakingIntegration.SkillType.VIP_ACCESS] = 0;
        _skillBoosts[IStakingIntegration.SkillType.EARLY_ACCESS] = 0;
        _skillBoosts[IStakingIntegration.SkillType.PRIVATE_AUCTIONS] = 0;
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    /**
     * @notice Set the marketplace contract address
     * @param _marketplace The marketplace contract address
     */
    function setMarketplaceContract(address _marketplace) external onlyOwner {
        require(_marketplace != address(0), "Invalid address");
        marketplaceContract = _marketplace;
    }
    
    /**
     * @notice Set the core staking contract address
     * @param _coreStaking The core staking contract address
     */
    function setCoreStakingContract(address _coreStaking) external onlyOwner {
        require(_coreStaking != address(0), "Invalid address");
        coreStakingContract = _coreStaking;
    }
    
    /**
     * @notice Update skill boost percentage
     * @param skillType The skill type (0-16)
     * @param newBoost The new boost percentage in basis points
     */
    function updateSkillBoost(IStakingIntegration.SkillType skillType, uint16 newBoost) external onlyOwner {
        require(skillType != IStakingIntegration.SkillType.NONE, "Invalid skill type");
        require(newBoost <= 2500, "Boost too high"); // Max 25%
        _skillBoosts[skillType] = newBoost;
    }
    
    // ============================================
    // MARKETPLACE FUNCTIONS
    // ============================================
    
    /**
     * @notice Notify that a skill NFT has been activated for a user
     * @param user The user address
     * @param nftId The NFT ID
     * @param skillType The skill type (0-16)
     */
    function notifySkillActivation(
        address user,
        uint256 nftId,
        IStakingIntegration.SkillType skillType,
        uint16 effectValue
    ) external override onlyMarketplace {
        require(skillType != IStakingIntegration.SkillType.NONE, "Invalid skill type");
        require(!_userActiveSkillNFTs[user].contains(nftId), "Skill already active");
        
        UserSkillProfile storage profile = _userSkillProfiles[user];
        require(_userActiveSkillNFTs[user].length() < MAX_ACTIVE_SKILLS, "Max skills reached");
        
        _userActiveSkillNFTs[user].add(nftId);
        
        if (_nftRarity[nftId] == SkillRarity.Common) {
            _nftRarity[nftId] = SkillRarity.Common;
        }
        
        uint16 resolvedBoost = effectValue > 0 ? effectValue : _skillBoosts[skillType];
        SkillInstance storage detail = _userSkillDetails[user][nftId];
        detail.skillType = skillType;
        detail.effectValue = resolvedBoost;
        detail.activatedAt = uint64(block.timestamp);
        detail.cooldownEnds = 0;
        detail.isActive = true;
        
        SkillRarity rarity = _nftRarity[nftId];
        uint16 rarityMult = _rarityMultipliers[rarity];
        
        profile.totalBoost += resolvedBoost;
        profile.activeSkillCount = uint8(_userActiveSkillNFTs[user].length());
        if (profile.rarityMultiplier == 0) {
            profile.rarityMultiplier = 100;
        }
        if (rarityMult > profile.rarityMultiplier) {
            profile.rarityMultiplier = rarityMult;
        }
        
        emit SkillActivated(user, nftId, skillType, resolvedBoost, profile.totalBoost);
    }
    
    /**
     * @notice Notify that a skill NFT has been deactivated for a user
     * @param user The user address
     * @param nftId The NFT ID
     */
    function notifySkillDeactivation(address user, uint256 nftId) external override onlyMarketplace {
        require(_userActiveSkillNFTs[user].contains(nftId), "Skill not active");
        
        SkillInstance storage detail = _userSkillDetails[user][nftId];
        IStakingIntegration.SkillType skillType = detail.skillType;
        
        _userActiveSkillNFTs[user].remove(nftId);
        detail.isActive = false;
        detail.cooldownEnds = uint64(block.timestamp);
        
        _recalculateSkillProfile(user);
        
        UserSkillProfile storage profile = _userSkillProfiles[user];
        emit SkillDeactivated(user, nftId, skillType, profile.totalBoost);
    }
    
    /**
     * @notice Set the rarity for a specific NFT
     * @param nftId The NFT ID
     * @param rarity The rarity level
     */
    function setSkillRarity(uint256 nftId, SkillRarity rarity) external override onlyMarketplace {
        require(rarity <= SkillRarity.Legendary, "Invalid rarity");
        _nftRarity[nftId] = rarity;
        
        uint16 multiplier = _rarityMultipliers[rarity];
        emit SkillRarityUpdated(nftId, rarity, multiplier);
    }
    
    /**
     * @notice Batch set rarities for multiple NFTs
     * @param nftIds Array of NFT IDs
     * @param rarities Array of rarity levels
     */
    function batchSetSkillRarity(uint256[] calldata nftIds, SkillRarity[] calldata rarities) external override onlyMarketplace {
        require(nftIds.length == rarities.length, "Length mismatch");
        
        for (uint256 i = 0; i < nftIds.length; i++) {
            require(rarities[i] <= SkillRarity.Legendary, "Invalid rarity");
            _nftRarity[nftIds[i]] = rarities[i];
            
            uint16 multiplier = _rarityMultipliers[rarities[i]];
            emit SkillRarityUpdated(nftIds[i], rarities[i], multiplier);
        }
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @notice Get the skill profile for a user
     * @param user The user address
     * @return profile The user's skill profile
     */
    function getUserSkillProfile(address user) external view override returns (UserSkillProfile memory profile) {
        profile = _userSkillProfiles[user];
        
        // Add active skill NFT IDs
        uint256 length = _userActiveSkillNFTs[user].length();
        profile.activeSkillNFTIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            profile.activeSkillNFTIds[i] = _userActiveSkillNFTs[user].at(i);
        }
    }
    
    /**
     * @notice Get active skills with full details for a user
     * @param user The user address
     * @return skills Array of skill information
     */
    function getActiveSkillsWithDetails(address user) external view override returns (SkillInfo[] memory skills) {
        uint256 length = _userActiveSkillNFTs[user].length();
        skills = new SkillInfo[](length);
        
        for (uint256 i = 0; i < length; i++) {
            uint256 nftId = _userActiveSkillNFTs[user].at(i);
            SkillRarity rarity = _nftRarity[nftId];
            SkillInstance storage detail = _userSkillDetails[user][nftId];
            skills[i] = SkillInfo({
                nftId: nftId,
                skillType: detail.skillType,
                rarity: rarity,
                boost: detail.effectValue,
                rarityMultiplier: _rarityMultipliers[rarity],
                isActive: detail.isActive,
                activatedAt: detail.activatedAt,
                cooldownEnds: detail.cooldownEnds
            });
        }
    }
    
    /**
     * @notice Get the rarity information for an NFT
     * @param nftId The NFT ID
     * @return rarity The rarity level
     * @return multiplier The rarity multiplier
     */
    function getSkillRarity(uint256 nftId) external view override returns (SkillRarity rarity, uint16 multiplier) {
        rarity = _nftRarity[nftId];
        multiplier = _rarityMultipliers[rarity];
    }
    
    /**
     * @notice Get the boost percentage for a skill type
     * @param skillType The skill type (0-16)
     * @return boost The boost percentage in basis points
     */
    function getSkillBoost(IStakingIntegration.SkillType skillType) external view override returns (uint16 boost) {
        return _skillBoosts[skillType];
    }
    
    /**
     * @notice Get all skill type configurations
     * @return skillTypes Array of skill type IDs
     * @return boosts Array of boost percentages
     */
    function getAllSkillBoosts()
        external
        view
        override
        returns (IStakingIntegration.SkillType[] memory skillTypes, uint16[] memory boosts)
    {
        skillTypes = new IStakingIntegration.SkillType[](SKILL_TYPE_COUNT);
        boosts = new uint16[](SKILL_TYPE_COUNT);
        
        for (uint8 i = 0; i < SKILL_TYPE_COUNT; i++) {
            IStakingIntegration.SkillType skillType = IStakingIntegration.SkillType(i);
            skillTypes[i] = skillType;
            boosts[i] = _skillBoosts[skillType];
        }
    }
    
    /**
     * @notice Check if a user has a specific skill active
     * @param user The user address
     * @param nftId The NFT ID
     * @return isActive True if the skill is active
     */
    function isSkillActive(address user, uint256 nftId) external view override returns (bool isActive) {
        return _userActiveSkillNFTs[user].contains(nftId);
    }
    
    /**
     * @notice Get the total boost for a user including rarity multipliers
     * @param user The user address
     * @return totalBoost The base total boost percentage
     * @return rarityMultiplier The rarity multiplier (100-500)
     * @return effectiveBoost The effective boost after rarity
     */
    function getUserBoosts(address user) external view override returns (
        uint16 totalBoost,
        uint16 rarityMultiplier,
        uint16 effectiveBoost
    ) {
        UserSkillProfile storage profile = _userSkillProfiles[user];
        totalBoost = profile.totalBoost;
        rarityMultiplier = profile.rarityMultiplier == 0 ? 100 : profile.rarityMultiplier;
        effectiveBoost = uint16((uint256(totalBoost) * rarityMultiplier) / 100);
    }
    
    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================
    
    /**
     * @notice Recalculate skill profile from scratch
     * @param user The user address
     */
    function _recalculateSkillProfile(address user) internal {
        UserSkillProfile storage profile = _userSkillProfiles[user];
        
        // Reset profile
        profile.totalBoost = 0;
        profile.activeSkillCount = uint8(_userActiveSkillNFTs[user].length());
        profile.rarityMultiplier = 100; // Base multiplier
        
        // Recalculate from active skills
        uint256 length = _userActiveSkillNFTs[user].length();
        for (uint256 i = 0; i < length; i++) {
            uint256 nftId = _userActiveSkillNFTs[user].at(i);
            SkillInstance storage detail = _userSkillDetails[user][nftId];
            profile.totalBoost += detail.effectValue;
            
            uint16 rarityMult = _rarityMultipliers[_nftRarity[nftId]];
            if (rarityMult > profile.rarityMultiplier) {
                profile.rarityMultiplier = rarityMult;
            }
        }
    }
}
