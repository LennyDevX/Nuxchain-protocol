// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/IStakingIntegration.sol";

/**
 * @title GameifiedMarketplaceQuests
 * @dev Sistema de quests optimizado e independiente
 * - Crear y gestionar quests
 * - Completar quests con validación
 * - Tracking de progreso
 * - Notificar al staking sobre quests completadas
 */

interface IGameifiedMarketplaceCore {
    struct UserProfile {
        uint256 totalXP;
        uint8 level;
        uint256 nftsCreated;
        uint256 nftsOwned;
        uint32 nftsSold;
        uint32 nftsBought;
    }
    
    function userProfiles(address) external view returns (UserProfile memory);
    function updateUserXP(address _user, uint256 _amount) external;
}

contract GameifiedMarketplaceQuests is AccessControl, Pausable {
    using Counters for Counters.Counter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    enum QuestType {
        PURCHASE,      // Comprar N NFTs
        CREATE,        // Crear N NFTs
        SOCIAL,        // Like/Comment N veces
        LEVEL_UP,      // Alcanzar nivel N
        TRADING        // Vender N NFTs
    }
    
    struct Quest {
        uint256 questId;
        QuestType questType;
        string title;
        string description;
        uint256 requirement;
        uint256 xpReward;
        bool active;
        uint256 createdAt;
    }
    
    struct UserQuestProgress {
        uint256 questId;
        uint256 currentProgress;
        bool completed;
        uint256 completedAt;
    }
    
    Counters.Counter private _questIdCounter;
    
    mapping(uint256 => Quest) public quests;
    mapping(address => mapping(uint256 => UserQuestProgress)) public userQuestProgress;
    mapping(address => uint256[]) public userCompletedQuests;
    
    address public coreContractAddress;
    address public stakingContractAddress;
    
    event QuestCreated(uint256 indexed questId, QuestType questType, string title, uint256 requirement, uint256 xpReward);
    event QuestCompleted(address indexed user, uint256 indexed questId, uint256 xpReward);
    event QuestProgressUpdated(address indexed user, uint256 indexed questId, uint256 progress);
    event QuestDeactivated(uint256 indexed questId);

    error QuestNotFound();
    error QuestNotActive();
    error RequirementNotMet();
    error AlreadyCompleted();

    constructor(address _coreAddress) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        coreContractAddress = _coreAddress;
    }

    /**
     * @dev Crear nueva quest
     */
    function createQuest(
        QuestType _questType,
        string calldata _title,
        string calldata _description,
        uint256 _requirement,
        uint256 _xpReward
    ) external onlyRole(ADMIN_ROLE) returns (uint256) {
        require(_requirement > 0, "Invalid requirement");
        require(_xpReward > 0, "Invalid reward");
        
        uint256 questId = _questIdCounter.current();
        _questIdCounter.increment();
        
        quests[questId] = Quest({
            questId: questId,
            questType: _questType,
            title: _title,
            description: _description,
            requirement: _requirement,
            xpReward: _xpReward,
            active: true,
            createdAt: block.timestamp
        });
        
        emit QuestCreated(questId, _questType, _title, _requirement, _xpReward);
        return questId;
    }

    /**
     * @dev Deactivate quest
     */
    function deactivateQuest(uint256 _questId) external onlyRole(ADMIN_ROLE) {
        require(quests[_questId].active, "Already inactive");
        quests[_questId].active = false;
        emit QuestDeactivated(_questId);
    }

    /**
     * @dev Completar quest
     */
    function completeQuest(uint256 _questId) external whenNotPaused {
        Quest memory quest = quests[_questId];
        require(quest.active, "Quest not active");
        require(!userQuestProgress[msg.sender][_questId].completed, "Already completed");
        
        uint256 progress = _calculateQuestProgress(msg.sender, quest);
        require(progress >= quest.requirement, "Requirement not met");
        
        userQuestProgress[msg.sender][_questId] = UserQuestProgress({
            questId: _questId,
            currentProgress: progress,
            completed: true,
            completedAt: block.timestamp
        });
        
        userCompletedQuests[msg.sender].push(_questId);
        
        IGameifiedMarketplaceCore(coreContractAddress).updateUserXP(msg.sender, quest.xpReward);
        
        // Notificar al staking sobre la quest completada
        if (stakingContractAddress != address(0)) {
            IStakingIntegration(stakingContractAddress).notifyQuestCompletion(
                msg.sender,
                _questId,
                quest.xpReward
            );
        }
        
        emit QuestCompleted(msg.sender, _questId, quest.xpReward);
    }

    /**
     * @dev Actualizar progreso manualmente
     */
    function updateQuestProgress(address _user, uint256 _questId) external onlyRole(ADMIN_ROLE) {
        Quest memory quest = quests[_questId];
        require(quest.active, "Quest not active");
        
        uint256 progress = _calculateQuestProgress(_user, quest);
        
        userQuestProgress[_user][_questId].currentProgress = progress;
        emit QuestProgressUpdated(_user, _questId, progress);
    }

    /**
     * @dev Calcular progreso según tipo de quest
     */
    function _calculateQuestProgress(address _user, Quest memory _quest) internal view returns (uint256) {
        IGameifiedMarketplaceCore core = IGameifiedMarketplaceCore(coreContractAddress);
        IGameifiedMarketplaceCore.UserProfile memory profile = core.userProfiles(_user);
        
        if (_quest.questType == QuestType.PURCHASE) {
            return profile.nftsBought;
        } else if (_quest.questType == QuestType.CREATE) {
            return profile.nftsCreated;
        } else if (_quest.questType == QuestType.TRADING) {
            return profile.nftsSold;
        } else if (_quest.questType == QuestType.LEVEL_UP) {
            return profile.level;
        }
        
        return 0;
    }

    /**
     * @dev Obtener progreso del usuario
     */
    function getUserQuestProgress(address _user, uint256 _questId) 
        external view returns (UserQuestProgress memory)
    {
        return userQuestProgress[_user][_questId];
    }

    /**
     * @dev Obtener todas las quests completadas
     */
    function getUserCompletedQuests(address _user) external view returns (uint256[] memory) {
        return userCompletedQuests[_user];
    }

    /**
     * @dev Obtener información de una quest
     */
    function getQuest(uint256 _questId) external view returns (Quest memory) {
        require(quests[_questId].active, "Quest not found");
        return quests[_questId];
    }

    /**
     * @dev Pause/Unpause
     */
    function setStakingContract(address _stakingAddress) external onlyRole(ADMIN_ROLE) {
        require(_stakingAddress != address(0), "Invalid address");
        stakingContractAddress = _stakingAddress;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
