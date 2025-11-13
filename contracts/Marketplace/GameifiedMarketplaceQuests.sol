// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
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

contract GameifiedMarketplaceQuests is AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    uint8 private constant MAX_LEVEL = 50;                              // Maximum level cap for LEVEL_UP quests
    uint256 private constant MAX_XP_REWARD = 50000;                     // Max XP per quest (based on level 50)
    uint256 private constant MAX_SOCIAL_ACTIONS_PER_QUEST = 1000;       // Max required social actions per quest
    
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
    mapping(address => uint256) public userSocialActions;           // Track social actions (likes/comments) per user
    
    address public coreContractAddress;
    address public stakingContractAddress;
    
    event QuestCreated(uint256 indexed questId, QuestType questType, string title, uint256 requirement, uint256 xpReward);
    event QuestCompleted(address indexed user, uint256 indexed questId, uint256 xpReward);
    event QuestProgressUpdated(address indexed user, uint256 indexed questId, uint256 progress);
    event QuestDeactivated(uint256 indexed questId);
    event SocialActionRecorded(address indexed user, uint256 newTotal);
    event CoreContractUpdated(address indexed oldCore, address indexed newCore);
    event StakingContractUpdated(address indexed oldStaking, address indexed newStaking);

    error QuestNotFound();
    error QuestNotActive();
    error RequirementNotMet();
    error AlreadyCompleted();
    error InvalidAddress();
    error InvalidRequirement();
    error InvalidXPReward();
    error InvalidMetadata();

    constructor(address _coreAddress) {
        if (_coreAddress == address(0)) revert InvalidAddress();
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        coreContractAddress = _coreAddress;
    }

    /**
     * @dev Crear nueva quest
     * @notice Validaciones:
     * - Title y description no vacíos
     * - Requirement > 0
     * - XP reward entre 1 y MAX_XP_REWARD (50000)
     * - Social actions máximo 1000 por quest
     */
    function createQuest(
        QuestType _questType,
        string calldata _title,
        string calldata _description,
        uint256 _requirement,
        uint256 _xpReward
    ) external onlyRole(ADMIN_ROLE) returns (uint256) {
        if (bytes(_title).length == 0 || bytes(_description).length == 0) revert InvalidMetadata();
        if (_requirement == 0) revert InvalidRequirement();
        if (_xpReward == 0 || _xpReward > MAX_XP_REWARD) revert InvalidXPReward();
        
        // Social quests: max 1000 actions
        if (_questType == QuestType.SOCIAL && _requirement > MAX_SOCIAL_ACTIONS_PER_QUEST) {
            revert InvalidRequirement();
        }
        
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
        if (!quests[_questId].active) revert QuestNotActive();
        quests[_questId].active = false;
        emit QuestDeactivated(_questId);
    }

    /**
     * @dev Completar quest
     */
    function completeQuest(uint256 _questId) external whenNotPaused nonReentrant {
        Quest memory quest = quests[_questId];
        if (!quest.active) revert QuestNotActive();
        if (userQuestProgress[msg.sender][_questId].completed) revert AlreadyCompleted();
        
        uint256 progress = _calculateQuestProgress(msg.sender, quest);
        if (progress < quest.requirement) revert RequirementNotMet();
        
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
        if (!quest.active) revert QuestNotActive();
        
        uint256 progress = _calculateQuestProgress(_user, quest);
        
        userQuestProgress[_user][_questId].currentProgress = progress;
        emit QuestProgressUpdated(_user, _questId, progress);
    }

    /**
     * @dev Calcular progreso según tipo de quest
     * @notice Soporta:
     * - PURCHASE: NFTs comprados
     * - CREATE: NFTs creados
     * - TRADING: NFTs vendidos
     * - LEVEL_UP: Nivel alcanzado (limitado a MAX_LEVEL=50)
     * - SOCIAL: Acciones sociales (likes/comments) del usuario
     */
    function _calculateQuestProgress(address _user, Quest memory _quest) internal view returns (uint256) {
        // SOCIAL quests usan tracking directo
        if (_quest.questType == QuestType.SOCIAL) {
            return userSocialActions[_user];
        }
        
        // Para otros tipos, consultar core contract
        if (coreContractAddress == address(0)) return 0;
        
        IGameifiedMarketplaceCore core = IGameifiedMarketplaceCore(coreContractAddress);
        IGameifiedMarketplaceCore.UserProfile memory profile = core.userProfiles(_user);
        
        if (_quest.questType == QuestType.PURCHASE) {
            return profile.nftsBought;
        } else if (_quest.questType == QuestType.CREATE) {
            return profile.nftsCreated;
        } else if (_quest.questType == QuestType.TRADING) {
            return profile.nftsSold;
        } else if (_quest.questType == QuestType.LEVEL_UP) {
            // Cap level to MAX_LEVEL (50)
            return profile.level > MAX_LEVEL ? MAX_LEVEL : profile.level;
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
        if (!quests[_questId].active) revert QuestNotFound();
        return quests[_questId];
    }

    /**
     * @dev Record social action (like/comment) for user
     * @param _user Address of user
     * @notice Called from core marketplace when user likes/comments on NFTs
     */
    function recordSocialAction(address _user) external onlyRole(ADMIN_ROLE) {
        unchecked {
            userSocialActions[_user]++;
        }
        emit SocialActionRecorded(_user, userSocialActions[_user]);
    }

    /**
     * @dev Get user's total social actions
     * @param _user Address of user
     */
    function getUserSocialActions(address _user) external view returns (uint256) {
        return userSocialActions[_user];
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════

    /**
     * @dev Set core contract address
     * @param _coreAddress Address of core contract
     */
    function setCoreContract(address _coreAddress) external onlyRole(ADMIN_ROLE) {
        if (_coreAddress == address(0)) revert InvalidAddress();
        address oldCore = coreContractAddress;
        coreContractAddress = _coreAddress;
        emit CoreContractUpdated(oldCore, _coreAddress);
    }

    /**
     * @dev Set staking contract address
     * @param _stakingAddress Address of staking contract
     */
    function setStakingContract(address _stakingAddress) external onlyRole(ADMIN_ROLE) {
        if (_stakingAddress == address(0)) revert InvalidAddress();
        address oldStaking = stakingContractAddress;
        stakingContractAddress = _stakingAddress;
        emit StakingContractUpdated(oldStaking, _stakingAddress);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
