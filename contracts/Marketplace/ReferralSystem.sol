// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ReferralSystem
 * @dev Standalone contract for managing referral codes, registrations, and statistics
 * - Users generate permanent referral codes
 * - One-time registration with referral codes
 * - Track referral earnings and relationships
 * - Called by GameifiedMarketplaceCoreV1 and other contracts
 */
contract ReferralSystem is AccessControl, Initializable, UUPSUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    // XP Constants
    uint256 public constant REFERRER_BASE_XP = 5;
    uint256 public constant BUYER_REFERRAL_BONUS_XP = 10;

    // Mappings for referral system
    mapping(bytes32 => address) public referralCodeOwner;  // code → user address
    mapping(address => bytes32) public referralCode;       // user address → code
    mapping(address => address) public referrer;           // user → referrer address
    mapping(address => address[]) public referrals;        // referrer → list of referrals
    mapping(address => bool) public hasReferrer;           // user → has referrer (one-time)
    mapping(address => uint256) public referralXPEarned;   // user → total XP from referrals
    mapping(address => uint256) public referralCount;      // referrer → count of successful referrals

    // Events
    event ReferralCodeGenerated(address indexed user, bytes32 indexed code);
    event ReferralRegistered(address indexed user, address indexed referrer);
    event ReferralBonusEarned(address indexed referrer, uint256 xpAmount, string reason);
    event ReferralBonusGiven(address indexed buyer, uint256 xpAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address platformAdmin) public initializer {
        require(platformAdmin != address(0), "Invalid platform admin");
        _grantRole(DEFAULT_ADMIN_ROLE, platformAdmin);
        _grantRole(ADMIN_ROLE, platformAdmin);
        _grantRole(UPGRADER_ROLE, platformAdmin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @dev Generate a unique referral code for a user
     * Code format: keccak256(address + timestamp + blockhash)
     * Code never expires and can be shared unlimited times
     */
    function generateReferralCode(address user) external returns (bytes32) {
        require(user != address(0), "Invalid user address");

        // Generate unique code
        bytes32 code = keccak256(abi.encodePacked(user, block.timestamp, blockhash(block.number - 1)));
        
        // Store mapping
        referralCodeOwner[code] = user;
        referralCode[user] = code;

        emit ReferralCodeGenerated(user, code);
        return code;
    }

    /**
     * @dev Register a user with a referral code
     * - User receives registration bonus
     * - Referrer relationship established (one-time only)
     * - Referrer receives +5 XP bonus
     */
    function registerWithReferralCode(address user, bytes32 code) 
        external 
        onlyRole(MARKETPLACE_ROLE) 
        returns (bool) 
    {
        require(user != address(0), "Invalid user");
        require(code != bytes32(0), "Invalid code");
        require(!hasReferrer[user], "User already has referrer");
        require(isValidReferralCode(code), "Invalid referral code");
        require(referralCodeOwner[code] != user, "Cannot register with own code");

        // Get referrer
        address referrerAddress = referralCodeOwner[code];

        // Establish referral relationship
        referrer[user] = referrerAddress;
        hasReferrer[user] = true;
        referrals[referrerAddress].push(user);
        referralCount[referrerAddress]++;

        emit ReferralRegistered(user, referrerAddress);
        return true;
    }

    /**
     * @dev Get user's referral code
     */
    function getReferralCode(address user) external view returns (bytes32) {
        return referralCode[user];
    }

    /**
     * @dev Check if referral code is valid
     */
    function isValidReferralCode(bytes32 code) public view returns (bool) {
        return referralCodeOwner[code] != address(0);
    }

    /**
     * @dev Get comprehensive referral statistics for a user
     */
    function getUserReferralStats(address user) 
        external 
        view 
        returns (
            uint256 totalCount,
            uint256 totalXPEarned,
            address[] memory referralList
        ) 
    {
        return (
            referralCount[user],
            referralXPEarned[user],
            referrals[user]
        );
    }

    /**
     * @dev Called by marketplace to record referral XP earnings
     */
    function recordReferralXP(address referrerAddress, uint256 xpAmount, string memory reason) 
        external 
        onlyRole(MARKETPLACE_ROLE) 
    {
        require(referrerAddress != address(0), "Invalid referrer");
        referralXPEarned[referrerAddress] += xpAmount;
        emit ReferralBonusEarned(referrerAddress, xpAmount, reason);
    }

    /**
     * @dev Called by marketplace to record buyer referral bonus
     */
    function recordBuyerReferralBonus(address buyer, uint256 xpAmount) 
        external 
        onlyRole(MARKETPLACE_ROLE) 
    {
        require(buyer != address(0), "Invalid buyer");
        emit ReferralBonusGiven(buyer, xpAmount);
    }

    /**
     * @dev Get user's referrer
     */
    function getUserReferrer(address user) external view returns (address) {
        return referrer[user];
    }

    /**
     * @dev Check if user has referrer
     */
    function userHasReferrer(address user) external view returns (bool) {
        return hasReferrer[user];
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // DASHBOARD VIEW FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @dev Get referral system statistics
     */
    function getReferralSystemStats() external pure returns (
        uint256 totalReferrals,
        uint256 totalUsers,
        uint256 totalXPEarned,
        uint256 averageReferralsPerUser,
        uint256 conversionRate
    ) {
        // Simplified - full implementation needs tracking
        totalReferrals = 0;
        totalUsers = 0;
        totalXPEarned = 0;
        averageReferralsPerUser = 0;
        conversionRate = 0;
    }

    /**
     * @dev Get top referrers leaderboard
     */
    function getTopReferrers(uint256 _limit) external pure returns (
        address[] memory referrers,
        uint256[] memory referralCounts,
        uint256[] memory xpEarned
    ) {
        referrers = new address[](_limit);
        referralCounts = new uint256[](_limit);
        xpEarned = new uint256[](_limit);
    }

    /**
     * @dev Get user's referral network depth (tree structure)
     */
    function getUserReferralNetwork(address _user) external view returns (
        uint256 directReferrals,
        uint256 totalXPFromReferrals,
        address[] memory referralAddresses,
        bool[] memory activeStatus
    ) {
        directReferrals = referralCount[_user];
        totalXPFromReferrals = referralXPEarned[_user];
        referralAddresses = referrals[_user];
        
        activeStatus = new bool[](referralAddresses.length);
        for (uint256 i = 0; i < referralAddresses.length; i++) {
            activeStatus[i] = true;
        }
    }

    /**
     * @dev Get referral activity statistics
     */
    function getReferralActivity() external pure returns (
        uint256 last24hReferrals,
        uint256 last7dReferrals,
        uint256 last30dReferrals,
        uint256 trendPercentage
    ) {
        // Simplified - needs timestamp tracking
        last24hReferrals = 0;
        last7dReferrals = 0;
        last30dReferrals = 0;
        trendPercentage = 0;
    }

    /**
     * @dev Get referral conversion metrics
     */
    function getReferralConversionMetrics() external pure returns (
        uint256 codesGenerated,
        uint256 codesUsed,
        uint256 conversionRate,
        uint256 averageTimeToConvert
    ) {
        // Simplified - needs tracking
        codesGenerated = 0;
        codesUsed = 0;
        conversionRate = 0;
        averageTimeToConvert = 0;
    }
}
