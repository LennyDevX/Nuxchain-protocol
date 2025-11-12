// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/IStakingIntegration.sol";

/**
 * @title MinimalTestMarketplace
 * @dev Versión EXTREMADAMENTE simplificada para testing - máximo 24KB
 */
contract MinimalTestMarketplace is ERC721, AccessControl, Pausable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _questIdCounter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    struct UserProfile {
        uint256 totalXP;
        uint32 nftsSold;
        uint32 nftsBought;
        uint32 nftsCreated;
    }
    
    struct SkillNFT {
        IStakingIntegration.SkillType skillType;
        uint8 stars;
        bool isSkillActive;
    }
    
    struct Quest {
        uint256 xpReward;
        uint256 targetValue;
        uint256 questType;
        bool isActive;
        bool isOneTime;
    }
    
    struct QuestProgress {
        bool isCompleted;
        uint256 currentProgress;
    }
    
    mapping(address => UserProfile) public userProfiles;
    mapping(uint256 => SkillNFT) public tokenSkills;
    mapping(address => bool) public userReceivedFreeSkill;
    mapping(uint256 => bool) public isListed;
    mapping(uint256 => uint256) public listedPrice;
    mapping(uint256 => Quest) public quests;
    mapping(address => mapping(uint256 => QuestProgress)) public userQuestProgress;
    
    event QuestCreated(uint256 indexed questId, string name, uint256 questType);
    event QuestCompleted(address indexed user, uint256 indexed questId, uint256 xpReward);
    event SkillNFTCreated(uint256 indexed tokenId, address indexed creator, IStakingIntegration.SkillType skillType);

    constructor() ERC721("MinimalTest", "MT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function createStandardNFT(string calldata, string calldata, uint256) 
        external whenNotPaused returns (uint256) 
    {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        if (userProfiles[msg.sender].totalXP == 0 && msg.sender != address(0)) {
            userProfiles[msg.sender] = UserProfile({totalXP: 10, nftsSold: 0, nftsBought: 0, nftsCreated: 1});
        } else {
            userProfiles[msg.sender].totalXP += 10;
            userProfiles[msg.sender].nftsCreated++;
        }
        return tokenId;
    }

    function createSkillNFT(
        string calldata, string calldata, uint256,
        IStakingIntegration.SkillType[] calldata skillTypes,
        uint16[] calldata,
        IStakingIntegration.Rarity[] calldata rarities
    ) external whenNotPaused returns (uint256) {
        require(skillTypes.length > 0, "Need skills");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        
        IStakingIntegration.SkillType firstSkill = skillTypes[0];
        if (!userReceivedFreeSkill[msg.sender]) {
            firstSkill = IStakingIntegration.SkillType.STAKE_BOOST_I;
            userReceivedFreeSkill[msg.sender] = true;
        }
        
        tokenSkills[tokenId] = SkillNFT({
            skillType: firstSkill,
            stars: _rarityToStars(rarities[0]),
            isSkillActive: false
        });
        
        if (userProfiles[msg.sender].totalXP == 0 && msg.sender != address(0)) {
            userProfiles[msg.sender] = UserProfile({
                totalXP: 10,
                nftsSold: 0,
                nftsBought: 0,
                nftsCreated: 1
            });
        } else {
            userProfiles[msg.sender].totalXP += 10;
            userProfiles[msg.sender].nftsCreated++;
        }
        
        emit SkillNFTCreated(tokenId, msg.sender, firstSkill);
        return tokenId;
    }

    function listTokenForSale(uint256 tokenId, uint256 price, string calldata) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        isListed[tokenId] = true;
        listedPrice[tokenId] = price;
    }

    function buyToken(uint256 tokenId) external payable {
        require(isListed[tokenId], "Not listed");
        address seller = ownerOf(tokenId);
        _transfer(seller, msg.sender, tokenId);
        
        userProfiles[seller].nftsSold++;
        userProfiles[msg.sender].nftsBought++;
        userProfiles[seller].totalXP += 20;
        userProfiles[msg.sender].totalXP += 15;
        isListed[tokenId] = false;
    }

    function unlistToken(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        isListed[tokenId] = false;
    }

    function updatePrice(uint256 tokenId, uint256 newPrice) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        listedPrice[tokenId] = newPrice;
    }

    function makeOffer(uint256, uint8) external payable {}
    function acceptOffer(uint256, uint256) external {}
    function cancelOffer(uint256, uint256) external {}

    function toggleLike(uint256 tokenId) external {
        require(ownerOf(tokenId) != address(0), "Not exists");
        userProfiles[msg.sender].totalXP += 1;
    }

    function addComment(uint256 tokenId, string calldata) external {
        require(ownerOf(tokenId) != address(0), "Not exists");
        userProfiles[msg.sender].totalXP += 2;
    }

    function createQuest(
        string calldata, string calldata, uint256 _type,
        uint256 _targetValue, uint256 _xpReward, uint256,
        uint256, uint256, string calldata,
        uint64, uint64, uint8
    ) external onlyRole(ADMIN_ROLE) returns (uint256 questId) {
        questId = _questIdCounter.current();
        _questIdCounter.increment();
        quests[questId] = Quest({
            xpReward: _xpReward,
            targetValue: _targetValue,
            questType: _type,
            isActive: true,
            isOneTime: true
        });
        emit QuestCreated(questId, "", _type);
        return questId;
    }

    function completeQuest(uint256 _questId) external whenNotPaused {
        require(quests[_questId].isActive, "Not active");
        require(!userQuestProgress[msg.sender][_questId].isCompleted, "Already completed");
        
        Quest storage quest = quests[_questId];
        UserProfile memory profile = userProfiles[msg.sender];
        
        // Validar requirements según el tipo de quest
        bool requirementsMet = false;
        if (quest.questType == 1) {  // CREATE_NFT
            requirementsMet = profile.nftsCreated >= quest.targetValue;
        } else if (quest.questType == 2) {  // BUY_NFT
            requirementsMet = profile.nftsBought >= quest.targetValue;
        } else if (quest.questType == 3) {  // SELL_NFT
            requirementsMet = profile.nftsSold >= quest.targetValue;
        } else {
            requirementsMet = true;
        }
        
        require(requirementsMet, "Requirements not met");
        
        userQuestProgress[msg.sender][_questId].isCompleted = true;
        userQuestProgress[msg.sender][_questId].currentProgress = quest.targetValue;
        
        // Inicializar si es necesario
        if (userProfiles[msg.sender].totalXP == 0 && msg.sender != address(0)) {
            userProfiles[msg.sender] = UserProfile({
                totalXP: quest.xpReward,
                nftsSold: profile.nftsSold,
                nftsBought: profile.nftsBought,
                nftsCreated: profile.nftsCreated
            });
        } else {
            userProfiles[msg.sender].totalXP += quest.xpReward;
        }
        
        emit QuestCompleted(msg.sender, _questId, quest.xpReward);
    }

    function getUserProfile(address user) external view returns (UserProfile memory) {
        return userProfiles[user];
    }

    function getUserQuestProgress(address user, uint256 questId) 
        external view returns (uint256 progress, uint256 target, bool completed)
    {
        UserProfile memory profile = userProfiles[user];
        Quest memory quest = quests[questId];
        
        // Calcular el progreso dinámicamente basándose en el tipo de quest
        if (quest.questType == 1) {  // CREATE_NFT
            progress = profile.nftsCreated;
        } else if (quest.questType == 2) {  // BUY_NFT
            progress = profile.nftsBought;
        } else if (quest.questType == 3) {  // SELL_NFT
            progress = profile.nftsSold;
        } else {
            progress = userQuestProgress[user][questId].currentProgress;
        }
        
        target = quest.targetValue;
        completed = userQuestProgress[user][questId].isCompleted;
    }

    function hasUserReceivedFreeSkill(address user) external view returns (bool) {
        return userReceivedFreeSkill[user];
    }

    function getQuestDetails(uint256 questId) external view returns (Quest memory) {
        return quests[questId];
    }

    function pause() external onlyRole(ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(ADMIN_ROLE) { _unpause(); }

    function activateSkill(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        tokenSkills[tokenId].isSkillActive = true;
    }

    function deactivateSkill(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        tokenSkills[tokenId].isSkillActive = false;
    }

    function getUserActiveSkills(address) external pure returns (SkillNFT[] memory) {
        SkillNFT[] memory empty = new SkillNFT[](0);
        return empty;
    }

    function getMaxActiveSkillsForUser(address) external pure returns (uint8) { return 5; }
    function getUserSkillsLevel(address) external pure returns (uint8) { return 0; }
    function canUserCreateSkillNFT(address) external pure returns (bool) { return true; }
    function getUserStakingBalance(address) external pure returns (uint256) { return 0; }
    function setStakingContractAddress(address) external onlyRole(ADMIN_ROLE) {}
    function setPolTokenAddress(address) external onlyRole(ADMIN_ROLE) {}
    function setStakingTreasuryAddress(address) external onlyRole(ADMIN_ROLE) {}
    function setPlatformTreasury(address) external onlyRole(ADMIN_ROLE) {}
    function getUserCompleteInfo(address user) external view returns (UserProfile memory, uint256, uint8, uint8) {
        return (userProfiles[user], 0, 0, 5);
    }
    function getSkillFeeForRarity(IStakingIntegration.Rarity) external pure returns (uint256) { return 0; }
    function getNFTMetadata(uint256) external pure returns (address, string memory, uint256) { return (address(0), "", 0); }
    function getNFTComments(uint256) external pure returns (string[] memory) { return new string[](0); }
    function getNFTOffers(uint256) external pure returns (address[] memory) { return new address[](0); }
    function buyTokenEnhanced(uint256) external payable {}
    function notifyRewardsClaimed(address, uint256) external pure returns (uint256) { return 0; }
    function activateQuest(uint256) external onlyRole(ADMIN_ROLE) {}
    function deactivateQuest(uint256) external onlyRole(ADMIN_ROLE) {}
    function updateQuestRewards(uint256, uint256, uint256) external onlyRole(ADMIN_ROLE) {}
    function getUserStreakInfo(address) external pure returns (uint32, uint32, uint256) { return (0, 0, 0); }
    function canCompleteQuest(address, uint256) external pure returns (bool, string memory) { return (true, ""); }

    function _rarityToStars(IStakingIntegration.Rarity rarity) internal pure returns (uint8) {
        if (rarity == IStakingIntegration.Rarity.COMMON) return 1;
        if (rarity == IStakingIntegration.Rarity.UNCOMMON) return 2;
        if (rarity == IStakingIntegration.Rarity.RARE) return 3;
        if (rarity == IStakingIntegration.Rarity.EPIC) return 4;
        return 5;
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, AccessControl) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
