// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IStakingIntegration.sol";

/**
 * @title TestGameifiedMarketplace
 * @dev Versión simplificada de GameifiedMarketplace para testing
 */
contract TestGameifiedMarketplace is ERC721, AccessControl, Pausable {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    Counters.Counter private _tokenIdCounter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // Basic structures
    struct UserProfile {
        uint256 totalXP;
        uint8 level;
        uint256 nftsCreated;
        uint256 nftsOwned;
    }
    
    struct SkillNFT {
        uint256 tokenId;
        IStakingIntegration.SkillType skillType;
        uint16 effectValue;
        IStakingIntegration.Rarity rarity;
        bool isSkillActive;
        uint8 stars;
    }
    
    // State
    mapping(address => UserProfile) public userProfiles;
    mapping(uint256 => SkillNFT) public tokenSkills;
    mapping(address => EnumerableSet.UintSet) private _userActiveSkills;
    address public stakingContractAddress;
    address public platformTreasury;
    
    // Events
    event SkillNFTCreated(uint256 indexed tokenId, address indexed creator, IStakingIntegration.SkillType skillType);
    event SkillActivated(address indexed user, uint256 indexed tokenId);
    event SkillDeactivated(address indexed user, uint256 indexed tokenId);
    event XPGained(address indexed user, uint256 amount, string reason);
    event LevelUp(address indexed user, uint8 newLevel);

    constructor() ERC721("TestGameifiedNFT", "TGNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        platformTreasury = msg.sender;
    }

    function createNFT(string calldata, string calldata, uint256) external whenNotPaused {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(msg.sender, tokenId);
        
        userProfiles[msg.sender].nftsCreated++;
        userProfiles[msg.sender].totalXP += 10;
    }

    function createSkillNFT(
        string calldata,
        string calldata,
        uint256,
        IStakingIntegration.SkillType skillType,
        uint16 effectValue,
        IStakingIntegration.Rarity rarity
    ) external whenNotPaused returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(msg.sender, tokenId);
        
        tokenSkills[tokenId] = SkillNFT({
            tokenId: tokenId,
            skillType: skillType,
            effectValue: effectValue,
            rarity: rarity,
            isSkillActive: false,
            stars: _rarityToStars(rarity)
        });
        
        userProfiles[msg.sender].nftsCreated++;
        userProfiles[msg.sender].totalXP += 10;
        
        emit SkillNFTCreated(tokenId, msg.sender, skillType);
        
        return tokenId;
    }

    function activateSkill(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!tokenSkills[tokenId].isSkillActive, "Skill already active");
        
        tokenSkills[tokenId].isSkillActive = true;
        _userActiveSkills[msg.sender].add(tokenId);
        
        emit SkillActivated(msg.sender, tokenId);
    }

    function deactivateSkill(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(tokenSkills[tokenId].isSkillActive, "Skill not active");
        
        tokenSkills[tokenId].isSkillActive = false;
        _userActiveSkills[msg.sender].remove(tokenId);
        
        emit SkillDeactivated(msg.sender, tokenId);
    }

    function getUserActiveSkills(address user) external view returns (SkillNFT[] memory) {
        uint256[] memory skillIds = _userActiveSkills[user].values();
        SkillNFT[] memory skills = new SkillNFT[](skillIds.length);
        
        for (uint256 i = 0; i < skillIds.length; i++) {
            skills[i] = tokenSkills[skillIds[i]];
        }
        
        return skills;
    }

    function getSkillDetails(uint256 tokenId) external view returns (SkillNFT memory) {
        return tokenSkills[tokenId];
    }

    function getUserProfile(address user) external view returns (UserProfile memory) {
        UserProfile memory profile = userProfiles[user];
        // Calculate level: 1 level per 100 XP
        profile.level = uint8(profile.totalXP / 100);
        return profile;
    }

    function likeNFT(uint256) external whenNotPaused {
        userProfiles[msg.sender].totalXP += 1;
        emit XPGained(msg.sender, 1, "like");
    }

    function commentNFT(uint256, string calldata) external whenNotPaused {
        userProfiles[msg.sender].totalXP += 2;
        emit XPGained(msg.sender, 2, "comment");
    }

    function registerReferral(address referrer) external {
        userProfiles[referrer].totalXP += 50;
        emit XPGained(referrer, 50, "referral");
    }

    function getCreatorLeaderboard() external pure returns (address[] memory) {
        return new address[](0);
    }

    function getCollectorLeaderboard() external pure returns (address[] memory) {
        return new address[](0);
    }

    function createNFTBatch(string[] calldata uris, string calldata, uint256) external whenNotPaused {
        for (uint256 i = 0; i < uris.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            
            _safeMint(msg.sender, tokenId);
            
            userProfiles[msg.sender].nftsCreated++;
            userProfiles[msg.sender].totalXP += 10;
        }
    }

    function setStakingContract(address stakingAddress) external onlyRole(ADMIN_ROLE) {
        stakingContractAddress = stakingAddress;
    }

    function setCommunityTreasury(address treasuryAddress) external onlyRole(ADMIN_ROLE) {
        // No-op for test
    }

    function setRoyaltyStakingPool(address poolAddress) external onlyRole(ADMIN_ROLE) {
        // No-op for test
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function buyTokenEnhanced(uint256 tokenId) external payable {
        // No-op for test
    }

    function _rarityToStars(IStakingIntegration.Rarity rarity) internal pure returns (uint8) {
        if (rarity == IStakingIntegration.Rarity.COMMON) return 1;
        if (rarity == IStakingIntegration.Rarity.UNCOMMON) return 2;
        if (rarity == IStakingIntegration.Rarity.RARE) return 3;
        if (rarity == IStakingIntegration.Rarity.EPIC) return 4;
        return 5; // LEGENDARY
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
