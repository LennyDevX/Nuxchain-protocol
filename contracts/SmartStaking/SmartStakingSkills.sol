// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/ISmartStakingSkills.sol";
import "../interfaces/IStakingIntegration.sol";

/**
 * @title SmartStakingSkills
 * @notice Handles NFT skill management for the SmartStaking system
 * @dev Manages skill activation/deactivation, rarity tracking, and boost calculations
 */
contract SmartStakingSkills is Ownable, ISmartStakingSkills {
    using EnumerableSet for EnumerableSet.UintSet;
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    /// @notice Basis points denominator
    uint256 private constant BASIS_POINTS = 10000;
    
    /// @notice Maximum active skills per user (synchronized with system)
    uint8 private constant MAX_ACTIVE_SKILLS = 5;
    
    /// @notice Number of skill types
    uint8 private constant SKILL_TYPE_COUNT = 20;
    
    /// @notice Maximum total staking boost (+37.5% APY cap) - REDUCED 25% FOR SUSTAINABILITY
    uint256 private constant MAX_TOTAL_STAKING_BOOST = 3750; // 37.5% in basis points (was 50%)
    
    /// @notice Maximum total fee discount (56.25% cap) - REDUCED 25% FOR SUSTAINABILITY
    uint256 private constant MAX_TOTAL_FEE_DISCOUNT = 5625; // 56.25% in basis points (was 75%)
    
    /// @notice Maximum lock time reduction (37.5% cap) - REDUCED 25% FOR SUSTAINABILITY
    uint256 private constant MAX_LOCK_TIME_REDUCTION = 3750; // 37.5% in basis points (was 50%)
    
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
        IStakingIntegration.PowerType skillType;
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
    mapping(IStakingIntegration.PowerType => uint16) private _skillBoosts;
    
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
    // EVENTS
    // ============================================
    
    event BoostLimitReached(address indexed user, string boostType, uint256 attemptedValue, uint256 maxAllowed);
    event SkillActivationRejected(address indexed user, uint256 nftId, string reason);
    
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
        
        // Initialize default skill boosts mapped to staking integration enum - REDUCED 25% (v5.1.0)
        _skillBoosts[IStakingIntegration.PowerType.NONE] = 0;
        _skillBoosts[IStakingIntegration.PowerType.STAKE_BOOST_I] = 375;    // +3.75% APY (was +5%)
        _skillBoosts[IStakingIntegration.PowerType.STAKE_BOOST_II] = 750;   // +7.5% APY (was +10%)
        _skillBoosts[IStakingIntegration.PowerType.STAKE_BOOST_III] = 1500; // +15% APY (was +20%)
        _skillBoosts[IStakingIntegration.PowerType.AUTO_COMPOUND] = 0;      // handled separately
        _skillBoosts[IStakingIntegration.PowerType.LOCK_REDUCER] = 188;     // -1.88% lock time (was -2.5%)
        _skillBoosts[IStakingIntegration.PowerType.FEE_REDUCER_I] = 750;    // -7.5% fees (was -10%)
        _skillBoosts[IStakingIntegration.PowerType.FEE_REDUCER_II] = 1875;  // -18.75% fees (was -25%)
        _skillBoosts[IStakingIntegration.PowerType.PRIORITY_LISTING] = 0;
        _skillBoosts[IStakingIntegration.PowerType.BATCH_MINTER] = 0;
        _skillBoosts[IStakingIntegration.PowerType.VERIFIED_CREATOR] = 0;
        _skillBoosts[IStakingIntegration.PowerType.INFLUENCER] = 0;
        _skillBoosts[IStakingIntegration.PowerType.CURATOR] = 0;
        _skillBoosts[IStakingIntegration.PowerType.AMBASSADOR] = 375;   // +3.75% APY (was +5%)
        _skillBoosts[IStakingIntegration.PowerType.VIP_ACCESS] = 0;
        _skillBoosts[IStakingIntegration.PowerType.EARLY_ACCESS] = 0;
        _skillBoosts[IStakingIntegration.PowerType.PRIVATE_AUCTIONS] = 0;
        
        // Badge skill types - Collaborator Badges (+3.75% APY each, was +5%)
        _skillBoosts[IStakingIntegration.PowerType.MODERATOR] = 375;    // +3.75% APY (was +5%)
        _skillBoosts[IStakingIntegration.PowerType.BETA_TESTER] = 375;  // +3.75% APY (was +5%)
        _skillBoosts[IStakingIntegration.PowerType.VIP_PARTNER] = 375;  // +3.75% APY (was +5%)
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
    function updateSkillBoost(IStakingIntegration.PowerType skillType, uint16 newBoost) external onlyOwner {
        require(skillType != IStakingIntegration.PowerType.NONE, "Invalid skill type");
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
        IStakingIntegration.PowerType skillType,
        uint16 effectValue
    ) external override onlyMarketplace {
        require(skillType != IStakingIntegration.PowerType.NONE, "Invalid skill type");
        require(!_userActiveSkillNFTs[user].contains(nftId), "Skill already active");
        
        UserSkillProfile storage profile = _userSkillProfiles[user];
        require(_userActiveSkillNFTs[user].length() < MAX_ACTIVE_SKILLS, "Max skills reached");
        
        uint16 resolvedBoost = effectValue > 0 ? effectValue : _skillBoosts[skillType];
        SkillRarity rarity = _nftRarity[nftId];
        if (rarity == SkillRarity.Common && _nftRarity[nftId] == SkillRarity.Common) {
            _nftRarity[nftId] = SkillRarity.Common;
        }
        
        uint16 rarityMult = _rarityMultipliers[rarity];
        uint16 effectiveValue = uint16((uint256(resolvedBoost) * rarityMult) / 100);
        
        // VALIDATE LIMITS BEFORE ACTIVATION
        if (skillType == IStakingIntegration.PowerType.STAKE_BOOST_I || 
            skillType == IStakingIntegration.PowerType.STAKE_BOOST_II || 
            skillType == IStakingIntegration.PowerType.STAKE_BOOST_III ||
            skillType == IStakingIntegration.PowerType.MODERATOR ||
            skillType == IStakingIntegration.PowerType.BETA_TESTER ||
            skillType == IStakingIntegration.PowerType.VIP_PARTNER ||
            skillType == IStakingIntegration.PowerType.AMBASSADOR) {
            
            uint256 newStakingBoost = profile.stakingBoostTotal + effectiveValue;
            if (newStakingBoost > MAX_TOTAL_STAKING_BOOST) {
                emit BoostLimitReached(user, "staking", newStakingBoost, MAX_TOTAL_STAKING_BOOST);
                emit SkillActivationRejected(user, nftId, "Staking boost limit exceeded");
                return; // Reject activation
            }
        } 
        else if (skillType == IStakingIntegration.PowerType.FEE_REDUCER_I || 
                 skillType == IStakingIntegration.PowerType.FEE_REDUCER_II) {
            
            uint256 newFeeDiscount = profile.feeDiscountTotal + effectiveValue;
            if (newFeeDiscount > MAX_TOTAL_FEE_DISCOUNT) {
                emit BoostLimitReached(user, "fee_discount", newFeeDiscount, MAX_TOTAL_FEE_DISCOUNT);
                emit SkillActivationRejected(user, nftId, "Fee discount limit exceeded");
                return; // Reject activation
            }
        }
        else if (skillType == IStakingIntegration.PowerType.LOCK_REDUCER) {
            uint256 newLockReduction = profile.lockTimeReduction + effectiveValue;
            if (newLockReduction > MAX_LOCK_TIME_REDUCTION) {
                emit BoostLimitReached(user, "lock_reduction", newLockReduction, MAX_LOCK_TIME_REDUCTION);
                emit SkillActivationRejected(user, nftId, "Lock reduction limit exceeded");
                return; // Reject activation
            }
        }
        
        // ACTIVATION APPROVED - Proceed with normal logic
        _userActiveSkillNFTs[user].add(nftId);
        
        SkillInstance storage detail = _userSkillDetails[user][nftId];
        detail.skillType = skillType;
        detail.effectValue = resolvedBoost;
        detail.activatedAt = uint64(block.timestamp);
        detail.cooldownEnds = 0;
        detail.isActive = true;
        
        profile.totalBoost += resolvedBoost;
        profile.activeSkillCount = uint8(_userActiveSkillNFTs[user].length());
        if (profile.rarityMultiplier == 0) {
            profile.rarityMultiplier = 100;
        }
        if (rarityMult > profile.rarityMultiplier) {
            profile.rarityMultiplier = rarityMult;
        }
        
        // Apply boosts to profile
        if (skillType == IStakingIntegration.PowerType.STAKE_BOOST_I || 
            skillType == IStakingIntegration.PowerType.STAKE_BOOST_II || 
            skillType == IStakingIntegration.PowerType.STAKE_BOOST_III ||
            skillType == IStakingIntegration.PowerType.MODERATOR ||
            skillType == IStakingIntegration.PowerType.BETA_TESTER ||
            skillType == IStakingIntegration.PowerType.VIP_PARTNER ||
            skillType == IStakingIntegration.PowerType.AMBASSADOR) {
            profile.stakingBoostTotal += effectiveValue;
        } 
        else if (skillType == IStakingIntegration.PowerType.FEE_REDUCER_I || 
                 skillType == IStakingIntegration.PowerType.FEE_REDUCER_II) {
            profile.feeDiscountTotal += effectiveValue;
        }
        else if (skillType == IStakingIntegration.PowerType.LOCK_REDUCER) {
            profile.lockTimeReduction += effectiveValue;
        }
        else if (skillType == IStakingIntegration.PowerType.AUTO_COMPOUND) {
            profile.hasAutoCompound = true;
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
        IStakingIntegration.PowerType skillType = detail.skillType;
        
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
    function getSkillBoost(IStakingIntegration.PowerType skillType) external view override returns (uint16 boost) {
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
        returns (IStakingIntegration.PowerType[] memory skillTypes, uint16[] memory boosts)
    {
        skillTypes = new IStakingIntegration.PowerType[](SKILL_TYPE_COUNT);
        boosts = new uint16[](SKILL_TYPE_COUNT);
        
        for (uint8 i = 0; i < SKILL_TYPE_COUNT; i++) {
            IStakingIntegration.PowerType skillType = IStakingIntegration.PowerType(i);
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
     * @return totalBoost The STAKING boost percentage (APY boost only)
     * @return rarityMultiplier The rarity multiplier (100-500)
     * @return effectiveBoost The effective boost after rarity
     */
    function getUserBoosts(address user) external view override returns (
        uint16 totalBoost,
        uint16 rarityMultiplier,
        uint16 effectiveBoost
    ) {
        UserSkillProfile storage profile = _userSkillProfiles[user];
        // stakingBoostTotal already stores rarity-multiplied values (applied at activation time)
        totalBoost = profile.stakingBoostTotal;
        rarityMultiplier = profile.rarityMultiplier == 0 ? 100 : profile.rarityMultiplier;
        // effectiveBoost equals totalBoost — rarity was already factored in during notifySkillActivation
        effectiveBoost = totalBoost;
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
        profile.stakingBoostTotal = 0;
        profile.feeDiscountTotal = 0;
        profile.lockTimeReduction = 0;
        profile.hasAutoCompound = false;
        
        profile.activeSkillCount = uint8(_userActiveSkillNFTs[user].length());
        profile.rarityMultiplier = 100; // Base multiplier
        
        // Recalculate from active skills
        uint256 length = _userActiveSkillNFTs[user].length();
        for (uint256 i = 0; i < length; i++) {
            uint256 nftId = _userActiveSkillNFTs[user].at(i);
            SkillInstance storage detail = _userSkillDetails[user][nftId];
            
            // Apply rarity multiplier to the effect value
            uint16 rarityMult = _rarityMultipliers[_nftRarity[nftId]];
            uint16 effectiveValue = uint16((uint256(detail.effectValue) * rarityMult) / 100);
            
            // Update max rarity multiplier seen
            if (rarityMult > profile.rarityMultiplier) {
                profile.rarityMultiplier = rarityMult;
            }

            // Categorize boost
            IStakingIntegration.PowerType sType = detail.skillType;
            
            if (sType == IStakingIntegration.PowerType.STAKE_BOOST_I || 
                sType == IStakingIntegration.PowerType.STAKE_BOOST_II || 
                sType == IStakingIntegration.PowerType.STAKE_BOOST_III ||
                sType == IStakingIntegration.PowerType.MODERATOR ||
                sType == IStakingIntegration.PowerType.BETA_TESTER ||
                sType == IStakingIntegration.PowerType.VIP_PARTNER ||
                sType == IStakingIntegration.PowerType.AMBASSADOR) {
                profile.stakingBoostTotal += effectiveValue;
            } 
            else if (sType == IStakingIntegration.PowerType.FEE_REDUCER_I || 
                     sType == IStakingIntegration.PowerType.FEE_REDUCER_II) {
                profile.feeDiscountTotal += effectiveValue;
            }
            else if (sType == IStakingIntegration.PowerType.LOCK_REDUCER) {
                profile.lockTimeReduction += effectiveValue;
            }
            else if (sType == IStakingIntegration.PowerType.AUTO_COMPOUND) {
                profile.hasAutoCompound = true;
            }
            
            // Keep totalBoost for legacy/generic compatibility
            profile.totalBoost += effectiveValue;
        }
    }
}
