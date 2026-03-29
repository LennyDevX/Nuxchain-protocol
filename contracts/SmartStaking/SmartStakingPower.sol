// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/ISmartStakingPower.sol";
import "../interfaces/IStakingIntegration.sol";

/**
 * @title SmartStakingPower
 * @notice Handles NFT power management for the SmartStaking system
 * @dev Manages power activation/deactivation, rarity tracking, and boost calculations
 */
contract SmartStakingPower is Ownable, ISmartStakingPower {
    using EnumerableSet for EnumerableSet.UintSet;
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    /// @notice Basis points denominator
    uint256 private constant BASIS_POINTS = 10000;
    
    /// @notice Maximum active powers per user (synchronized with system)
    uint8 private constant MAX_ACTIVE_POWERS = 5;
    
    /// @notice Number of power types
    uint8 private constant POWER_TYPE_COUNT = 20;
    
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
    
    /// @notice Maps user address to their active NFT power IDs
    mapping(address => EnumerableSet.UintSet) private _userActivePowerNFTs;
    
    /// @notice Maps user address to their power profile
    mapping(address => UserPowerProfile) private _userPowerProfiles;

    struct PowerInstance {
        IStakingIntegration.PowerType powerType;
        uint16 effectValue;
        uint64 activatedAt;
        uint64 cooldownEnds;
        bool isActive;
    }
    
    /// @notice Tracks per-user power metadata
    mapping(address => mapping(uint256 => PowerInstance)) private _userPowerDetails;
    
    /// @notice Maps NFT ID to its rarity
    mapping(uint256 => PowerRarity) private _nftRarity;
    
    /// @notice Maps power type to its boost percentage (in basis points)
    mapping(IStakingIntegration.PowerType => uint16) private _powerBoosts;
    
    /// @notice Maps rarity to multiplier (100 = 1x, 500 = 5x)
    mapping(PowerRarity => uint16) private _rarityMultipliers;
    
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
    event PowerActivationRejected(address indexed user, uint256 nftId, string reason);
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        // Initialize rarity multipliers
        _rarityMultipliers[PowerRarity.Common] = 100;      // 1x
        _rarityMultipliers[PowerRarity.Uncommon] = 150;    // 1.5x
        _rarityMultipliers[PowerRarity.Rare] = 200;        // 2x
        _rarityMultipliers[PowerRarity.Epic] = 300;        // 3x
        _rarityMultipliers[PowerRarity.Legendary] = 500;   // 5x
        
        // Initialize default power boosts mapped to staking integration enum - REDUCED 25% (v5.1.0)
        _powerBoosts[IStakingIntegration.PowerType.NONE] = 0;
        _powerBoosts[IStakingIntegration.PowerType.STAKE_BOOST_I] = 375;    // +3.75% APY (was +5%)
        _powerBoosts[IStakingIntegration.PowerType.STAKE_BOOST_II] = 750;   // +7.5% APY (was +10%)
        _powerBoosts[IStakingIntegration.PowerType.STAKE_BOOST_III] = 1500; // +15% APY (was +20%)
        _powerBoosts[IStakingIntegration.PowerType.AUTO_COMPOUND] = 0;      // handled separately
        _powerBoosts[IStakingIntegration.PowerType.LOCK_REDUCER] = 188;     // -1.88% lock time (was -2.5%)
        _powerBoosts[IStakingIntegration.PowerType.FEE_REDUCER_I] = 750;    // -7.5% fees (was -10%)
        _powerBoosts[IStakingIntegration.PowerType.FEE_REDUCER_II] = 1875;  // -18.75% fees (was -25%)
        _powerBoosts[IStakingIntegration.PowerType.PRIORITY_LISTING] = 0;
        _powerBoosts[IStakingIntegration.PowerType.BATCH_MINTER] = 0;
        _powerBoosts[IStakingIntegration.PowerType.VERIFIED_CREATOR] = 0;
        _powerBoosts[IStakingIntegration.PowerType.INFLUENCER] = 0;
        _powerBoosts[IStakingIntegration.PowerType.CURATOR] = 0;
        _powerBoosts[IStakingIntegration.PowerType.AMBASSADOR] = 375;   // +3.75% APY (was +5%)
        _powerBoosts[IStakingIntegration.PowerType.VIP_ACCESS] = 0;
        _powerBoosts[IStakingIntegration.PowerType.EARLY_ACCESS] = 0;
        _powerBoosts[IStakingIntegration.PowerType.PRIVATE_AUCTIONS] = 0;
        
        // Badge power types - Collaborator Badges (+3.75% APY each, was +5%)
        _powerBoosts[IStakingIntegration.PowerType.MODERATOR] = 375;    // +3.75% APY (was +5%)
        _powerBoosts[IStakingIntegration.PowerType.BETA_TESTER] = 375;  // +3.75% APY (was +5%)
        _powerBoosts[IStakingIntegration.PowerType.VIP_PARTNER] = 375;  // +3.75% APY (was +5%)
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
     * @notice Update power boost percentage
     * @param powerType The power type
     * @param newBoost The new boost percentage in basis points
     */
    function updatePowerBoost(IStakingIntegration.PowerType powerType, uint16 newBoost) external onlyOwner {
        require(powerType != IStakingIntegration.PowerType.NONE, "Invalid power type");
        require(newBoost <= 2500, "Boost too high"); // Max 25%
        _powerBoosts[powerType] = newBoost;
    }
    
    // ============================================
    // MARKETPLACE FUNCTIONS
    // ============================================
    
    /**
     * @notice Notify that a power NFT has been activated for a user
     * @param user The user address
     * @param nftId The NFT ID
     * @param powerType The power type
     * @param effectValue The effect value in basis points (overrides defaults when > 0)
     */
    function notifyPowerActivation(
        address user,
        uint256 nftId,
        IStakingIntegration.PowerType powerType,
        uint16 effectValue
    ) external override onlyMarketplace {
        require(powerType != IStakingIntegration.PowerType.NONE, "Invalid power type");
        require(!_userActivePowerNFTs[user].contains(nftId), "Power already active");
        
        UserPowerProfile storage profile = _userPowerProfiles[user];
        require(_userActivePowerNFTs[user].length() < MAX_ACTIVE_POWERS, "Max powers reached");
        
        uint16 resolvedBoost = effectValue > 0 ? effectValue : _powerBoosts[powerType];
        PowerRarity rarity = _nftRarity[nftId];
        if (rarity == PowerRarity.Common && _nftRarity[nftId] == PowerRarity.Common) {
            _nftRarity[nftId] = PowerRarity.Common;
        }
        
        uint16 rarityMult = _rarityMultipliers[rarity];
        uint16 effectiveValue = uint16((uint256(resolvedBoost) * rarityMult) / 100);
        
        // VALIDATE LIMITS BEFORE ACTIVATION
        if (powerType == IStakingIntegration.PowerType.STAKE_BOOST_I || 
            powerType == IStakingIntegration.PowerType.STAKE_BOOST_II || 
            powerType == IStakingIntegration.PowerType.STAKE_BOOST_III ||
            powerType == IStakingIntegration.PowerType.MODERATOR ||
            powerType == IStakingIntegration.PowerType.BETA_TESTER ||
            powerType == IStakingIntegration.PowerType.VIP_PARTNER ||
            powerType == IStakingIntegration.PowerType.AMBASSADOR) {
            
            uint256 newStakingBoost = profile.stakingBoostTotal + effectiveValue;
            if (newStakingBoost > MAX_TOTAL_STAKING_BOOST) {
                emit BoostLimitReached(user, "staking", newStakingBoost, MAX_TOTAL_STAKING_BOOST);
                emit PowerActivationRejected(user, nftId, "Staking boost limit exceeded");
                return; // Reject activation
            }
        } 
        else if (powerType == IStakingIntegration.PowerType.FEE_REDUCER_I || 
                 powerType == IStakingIntegration.PowerType.FEE_REDUCER_II) {
            
            uint256 newFeeDiscount = profile.feeDiscountTotal + effectiveValue;
            if (newFeeDiscount > MAX_TOTAL_FEE_DISCOUNT) {
                emit BoostLimitReached(user, "fee_discount", newFeeDiscount, MAX_TOTAL_FEE_DISCOUNT);
                emit PowerActivationRejected(user, nftId, "Fee discount limit exceeded");
                return; // Reject activation
            }
        }
        else if (powerType == IStakingIntegration.PowerType.LOCK_REDUCER) {
            uint256 newLockReduction = profile.lockTimeReduction + effectiveValue;
            if (newLockReduction > MAX_LOCK_TIME_REDUCTION) {
                emit BoostLimitReached(user, "lock_reduction", newLockReduction, MAX_LOCK_TIME_REDUCTION);
                emit PowerActivationRejected(user, nftId, "Lock reduction limit exceeded");
                return; // Reject activation
            }
        }
        
        // ACTIVATION APPROVED - Proceed with normal logic
        _userActivePowerNFTs[user].add(nftId);
        
        PowerInstance storage detail = _userPowerDetails[user][nftId];
        detail.powerType = powerType;
        detail.effectValue = resolvedBoost;
        detail.activatedAt = uint64(block.timestamp);
        detail.cooldownEnds = 0;
        detail.isActive = true;
        
        profile.totalBoost += resolvedBoost;
        profile.activeSkillCount = uint8(_userActivePowerNFTs[user].length());
        if (profile.rarityMultiplier == 0) {
            profile.rarityMultiplier = 100;
        }
        if (rarityMult > profile.rarityMultiplier) {
            profile.rarityMultiplier = rarityMult;
        }
        
        // Apply boosts to profile
        if (powerType == IStakingIntegration.PowerType.STAKE_BOOST_I || 
            powerType == IStakingIntegration.PowerType.STAKE_BOOST_II || 
            powerType == IStakingIntegration.PowerType.STAKE_BOOST_III ||
            powerType == IStakingIntegration.PowerType.MODERATOR ||
            powerType == IStakingIntegration.PowerType.BETA_TESTER ||
            powerType == IStakingIntegration.PowerType.VIP_PARTNER ||
            powerType == IStakingIntegration.PowerType.AMBASSADOR) {
            profile.stakingBoostTotal += effectiveValue;
        } 
        else if (powerType == IStakingIntegration.PowerType.FEE_REDUCER_I || 
                 powerType == IStakingIntegration.PowerType.FEE_REDUCER_II) {
            profile.feeDiscountTotal += effectiveValue;
        }
        else if (powerType == IStakingIntegration.PowerType.LOCK_REDUCER) {
            profile.lockTimeReduction += effectiveValue;
        }
        else if (powerType == IStakingIntegration.PowerType.AUTO_COMPOUND) {
            profile.hasAutoCompound = true;
        }
        
        emit PowerActivated(user, nftId, powerType, resolvedBoost, profile.totalBoost);
    }
    
    /**
     * @notice Notify that a power NFT has been deactivated for a user
     * @param user The user address
     * @param nftId The NFT ID
     */
    function notifyPowerDeactivation(address user, uint256 nftId) external override onlyMarketplace {
        require(_userActivePowerNFTs[user].contains(nftId), "Power not active");
        
        PowerInstance storage detail = _userPowerDetails[user][nftId];
        IStakingIntegration.PowerType powerType = detail.powerType;
        
        _userActivePowerNFTs[user].remove(nftId);
        detail.isActive = false;
        detail.cooldownEnds = uint64(block.timestamp);
        
        _recalculatePowerProfile(user);
        
        UserPowerProfile storage profile = _userPowerProfiles[user];
        emit PowerDeactivated(user, nftId, powerType, profile.totalBoost);
    }
    
    /**
     * @notice Set the rarity for a specific NFT
     * @param nftId The NFT ID
     * @param rarity The rarity level
     */
    function setPowerRarity(uint256 nftId, PowerRarity rarity) external override onlyMarketplace {
        require(rarity <= PowerRarity.Legendary, "Invalid rarity");
        _nftRarity[nftId] = rarity;
        
        uint16 multiplier = _rarityMultipliers[rarity];
        emit PowerRarityUpdated(nftId, rarity, multiplier);
    }
    
    /**
     * @notice Batch set rarities for multiple NFTs
     * @param nftIds Array of NFT IDs
     * @param rarities Array of rarity levels
     */
    function batchSetPowerRarity(uint256[] calldata nftIds, PowerRarity[] calldata rarities) external override onlyMarketplace {
        require(nftIds.length == rarities.length, "Length mismatch");
        
        for (uint256 i = 0; i < nftIds.length; i++) {
            require(rarities[i] <= PowerRarity.Legendary, "Invalid rarity");
            _nftRarity[nftIds[i]] = rarities[i];
            
            uint16 multiplier = _rarityMultipliers[rarities[i]];
            emit PowerRarityUpdated(nftIds[i], rarities[i], multiplier);
        }
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @notice Get the power profile for a user
     * @param user The user address
     * @return profile The user's power profile
     */
    function getUserPowerProfile(address user) external view override returns (UserPowerProfile memory profile) {
        profile = _userPowerProfiles[user];
        
        // Add active power NFT IDs
        uint256 length = _userActivePowerNFTs[user].length();
        profile.activeSkillNFTIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            profile.activeSkillNFTIds[i] = _userActivePowerNFTs[user].at(i);
        }
    }
    
    /**
     * @notice Get active powers with full details for a user
     * @param user The user address
     * @return powers Array of power information
     */
    function getActivePowersWithDetails(address user) external view override returns (PowerInfo[] memory powers) {
        uint256 length = _userActivePowerNFTs[user].length();
        powers = new PowerInfo[](length);
        
        for (uint256 i = 0; i < length; i++) {
            uint256 nftId = _userActivePowerNFTs[user].at(i);
            PowerRarity rarity = _nftRarity[nftId];
            PowerInstance storage detail = _userPowerDetails[user][nftId];
            powers[i] = PowerInfo({
                nftId: nftId,
                powerType: detail.powerType,
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
    function getPowerRarity(uint256 nftId) external view override returns (PowerRarity rarity, uint16 multiplier) {
        rarity = _nftRarity[nftId];
        multiplier = _rarityMultipliers[rarity];
    }
    
    /**
     * @notice Get the boost percentage for a power type
     * @param powerType The power type
     * @return boost The boost percentage in basis points
     */
    function getPowerBoost(IStakingIntegration.PowerType powerType) external view override returns (uint16 boost) {
        return _powerBoosts[powerType];
    }
    
    /**
     * @notice Get all power type configurations
     * @return powerTypes Array of power type IDs
     * @return boosts Array of boost percentages
     */
    function getAllPowerBoosts()
        external
        view
        override
        returns (IStakingIntegration.PowerType[] memory powerTypes, uint16[] memory boosts)
    {
        powerTypes = new IStakingIntegration.PowerType[](POWER_TYPE_COUNT);
        boosts = new uint16[](POWER_TYPE_COUNT);
        
        for (uint8 i = 0; i < POWER_TYPE_COUNT; i++) {
            IStakingIntegration.PowerType powerType = IStakingIntegration.PowerType(i);
            powerTypes[i] = powerType;
            boosts[i] = _powerBoosts[powerType];
        }
    }
    
    /**
     * @notice Check if a user has a specific power active
     * @param user The user address
     * @param nftId The NFT ID
     * @return isActive True if the power is active
     */
    function isPowerActive(address user, uint256 nftId) external view override returns (bool isActive) {
        return _userActivePowerNFTs[user].contains(nftId);
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
        UserPowerProfile storage profile = _userPowerProfiles[user];
        // stakingBoostTotal already stores rarity-multiplied values (applied at activation time)
        totalBoost = profile.stakingBoostTotal;
        rarityMultiplier = profile.rarityMultiplier == 0 ? 100 : profile.rarityMultiplier;
        // effectiveBoost equals totalBoost — rarity was already factored in during notifyPowerActivation
        effectiveBoost = totalBoost;
    }
    
    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================
    
    /**
     * @notice Recalculate power profile from scratch
     * @param user The user address
     */
    function _recalculatePowerProfile(address user) internal {
        UserPowerProfile storage profile = _userPowerProfiles[user];
        
        // Reset profile
        profile.totalBoost = 0;
        profile.stakingBoostTotal = 0;
        profile.feeDiscountTotal = 0;
        profile.lockTimeReduction = 0;
        profile.hasAutoCompound = false;
        
        profile.activeSkillCount = uint8(_userActivePowerNFTs[user].length());
        profile.rarityMultiplier = 100; // Base multiplier
        
        // Recalculate from active powers
        uint256 length = _userActivePowerNFTs[user].length();
        for (uint256 i = 0; i < length; i++) {
            uint256 nftId = _userActivePowerNFTs[user].at(i);
            PowerInstance storage detail = _userPowerDetails[user][nftId];
            
            // Apply rarity multiplier to the effect value
            uint16 rarityMult = _rarityMultipliers[_nftRarity[nftId]];
            uint16 effectiveValue = uint16((uint256(detail.effectValue) * rarityMult) / 100);
            
            // Update max rarity multiplier seen
            if (rarityMult > profile.rarityMultiplier) {
                profile.rarityMultiplier = rarityMult;
            }

            // Categorize boost
            IStakingIntegration.PowerType pType = detail.powerType;
            
            if (pType == IStakingIntegration.PowerType.STAKE_BOOST_I || 
                pType == IStakingIntegration.PowerType.STAKE_BOOST_II || 
                pType == IStakingIntegration.PowerType.STAKE_BOOST_III ||
                pType == IStakingIntegration.PowerType.MODERATOR ||
                pType == IStakingIntegration.PowerType.BETA_TESTER ||
                pType == IStakingIntegration.PowerType.VIP_PARTNER ||
                pType == IStakingIntegration.PowerType.AMBASSADOR) {
                profile.stakingBoostTotal += effectiveValue;
            } 
            else if (pType == IStakingIntegration.PowerType.FEE_REDUCER_I || 
                     pType == IStakingIntegration.PowerType.FEE_REDUCER_II) {
                profile.feeDiscountTotal += effectiveValue;
            }
            else if (pType == IStakingIntegration.PowerType.LOCK_REDUCER) {
                profile.lockTimeReduction += effectiveValue;
            }
            else if (pType == IStakingIntegration.PowerType.AUTO_COMPOUND) {
                profile.hasAutoCompound = true;
            }
            
            // Keep totalBoost for legacy/generic compatibility
            profile.totalBoost += effectiveValue;
        }
    }
}
