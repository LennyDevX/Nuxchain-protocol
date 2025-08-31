// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

// Interface for MinerBotToken minting
interface IMinerBotToken {
    function mintGameRewards(address to, uint256 amount) external;
}

/**
 * @title MinerBotStaking
 * @dev Sistema de staking para tokens MBT con recompensas y penalizaciones anti-fraude
 * @author MinerBot Empire Team
 */
contract MinerBotStaking is ReentrancyGuard, Ownable, Pausable {

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    IERC20 public immutable minerBotToken; // Alias for compatibility
    
    // Configuración de staking
    uint256 public constant MINIMUM_STAKE_AMOUNT = 100 * 10**18; // 100 MBT mínimo
    uint256 public constant MAXIMUM_STAKE_AMOUNT = 1000000 * 10**18; // 1M MBT máximo
    uint32 public constant MINIMUM_STAKE_DURATION = 7 days;
    uint8 public constant EARLY_WITHDRAWAL_PENALTY = 25; // 25% penalización
    uint16 public constant REWARD_RATE_BASE = 1000; // 10% APY base
    uint32 public constant LOYALTY_BONUS_THRESHOLD = 90 days;
    uint16 public constant LOYALTY_BONUS_RATE = 200; // 2% adicional
    
    // Pools de staking con diferentes duraciones
    struct StakingPool {
        uint32 duration; // Duración en segundos
        uint16 rewardRate; // Tasa de recompensa (base 10000)
        uint256 totalStaked;
        uint256 maxCapacity;
        bool active;
        // Campos adicionales para compatibilidad con tests
        uint16 apy; // APY en base 10000
        uint256 minStake;
        uint256 maxStake;
        bool isActive;
    }
    
    // Estructura para estadísticas de pool
    struct PoolStats {
        uint256 totalStaked;
        uint256 totalStakers;
    }
    
    // Estructura para información de stake individual
    struct Stake {
        address user;
        uint256 poolId;
        uint256 amount;
        uint256 startTime;
        bool isActive;
    }
    
    // Estructura para actividad del usuario
    struct UserActivity {
        uint256 actionsToday;
        uint256 lastActionDay;
        uint256 suspiciousScore;
    }
    
    // Información de stake del usuario
    struct UserStake {
        uint256 amount;
        uint256 startTime;
        uint256 lastClaimTime;
        uint256 poolId;
        uint256 accumulatedRewards;
        bool isActive;
    }
    
    // Anti-fraude y seguridad
    struct UserSecurity {
        uint256 totalStaked;
        uint256 totalWithdrawn;
        uint256 lastActionTime;
        uint8 suspiciousActivityCount;
        bool isBanned;
    }
    
    // Mapeos
    mapping(uint256 => StakingPool) public stakingPools;
    mapping(address => mapping(uint256 => UserStake)) public userStakes;
    mapping(address => UserSecurity) public userSecurity;
    mapping(address => uint256[]) public userStakeIds;
    mapping(address => bool) public authorizedContracts;
    // Mapeos adicionales para compatibilidad
    mapping(uint256 => PoolStats) public poolStats;
    mapping(uint256 => Stake) public stakes;
    mapping(address => UserActivity) public userActivity;
    mapping(address => bool) public bannedUsers;
    
    // Variables de estado
    uint256 public nextPoolId;
    uint256 public nextStakeId = 1; // Empezar desde 1
    uint256 public totalRewardsDistributed;
    uint8 public emergencyWithdrawalFee = 50; // 5%
    // Variables adicionales para compatibilidad
    uint16 public earlyWithdrawalPenalty = 1000; // 10% en base 10000
    uint8 public maxActionsPerDay = 10;
    uint8 public suspiciousThreshold = 20;
    
    // Eventos
    event Staked(uint256 indexed stakeId, address indexed user, uint256 indexed poolId, uint256 amount);
    event Unstaked(address indexed user, uint256 indexed stakeId, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 indexed stakeId, uint256 amount);
    event EmergencyWithdrawal(uint256 indexed stakeId, address indexed user, uint256 amount);
    event PoolCreated(uint256 indexed poolId, uint256 duration, uint256 rewardRate);
    event UserBanned(address indexed user, string reason);
    event SuspiciousActivity(address indexed user, string activity);
    
    constructor(
        address _stakingToken
    ) Ownable() {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_stakingToken); // Same token for staking and rewards
        minerBotToken = IERC20(_stakingToken); // Alias for compatibility
        
        // Crear pools iniciales según las pruebas
        _createPool(30 days, 1000, 10000000 * 10**18, 100 * 10**18, 10000 * 10**18); // 10% APY, 30 días
        _createPool(90 days, 1500, 5000000 * 10**18, 500 * 10**18, 50000 * 10**18); // 15% APY, 90 días
        _createPool(180 days, 2000, 2000000 * 10**18, 1000 * 10**18, 100000 * 10**18); // 20% APY, 180 días
        _createPool(365 days, 2500, 1000000 * 10**18, 1000 * 10**18, 100000 * 10**18); // 25% APY, 1 año
    }
    
    /**
     * @dev Hacer stake de tokens en un pool específico
     */
    function stake(uint256 _poolId, uint256 _amount) external nonReentrant whenNotPaused {
        require(_poolId < nextPoolId, "Invalid pool ID");
        require(stakingPools[_poolId].active, "Pool not active");
        require(stakingPools[_poolId].isActive, "Pool not active");
        require(!userSecurity[msg.sender].isBanned, "User is banned");
        require(!bannedUsers[msg.sender], "User is banned");
        
        require(_amount > 0, "Amount must be greater than 0");
        
        StakingPool storage pool = stakingPools[_poolId];
         require(_amount >= pool.minStake, "Amount below minimum");
         require(_amount <= pool.maxStake, "Amount above maximum");
        require(pool.totalStaked + _amount <= pool.maxCapacity, "Pool capacity exceeded");
        
        // Verificaciones anti-fraude
        _checkAntifraud(msg.sender, _amount);
        
        // Transferir tokens
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        // Crear stake
        uint256 stakeId = nextStakeId++;
        userStakes[msg.sender][stakeId] = UserStake({
            amount: _amount,
            startTime: block.timestamp,
            lastClaimTime: block.timestamp,
            poolId: _poolId,
            accumulatedRewards: 0,
            isActive: true
        });
        
        // Actualizar estructura stakes para compatibilidad
        stakes[stakeId] = Stake({
            user: msg.sender,
            poolId: _poolId,
            amount: _amount,
            startTime: block.timestamp,
            isActive: true
        });
        
        userStakeIds[msg.sender].push(stakeId);
        pool.totalStaked = pool.totalStaked + _amount;
        
        // Actualizar estadísticas del pool
        poolStats[_poolId].totalStaked = poolStats[_poolId].totalStaked + _amount;
        poolStats[_poolId].totalStakers = poolStats[_poolId].totalStakers + 1;
        
        // Actualizar actividad del usuario
        _updateUserActivity(msg.sender);
        
        // Actualizar seguridad del usuario
        userSecurity[msg.sender].totalStaked = userSecurity[msg.sender].totalStaked + _amount;
        userSecurity[msg.sender].lastActionTime = block.timestamp;
        
        emit Staked(stakeId, msg.sender, _poolId, _amount);
    }
    
    /**
     * @dev Reclamar recompensas de un stake
     */
    function claimRewards(uint256 _stakeId) external nonReentrant whenNotPaused {
        require(!userSecurity[msg.sender].isBanned, "User is banned");
        
        UserStake storage userStake = userStakes[msg.sender][_stakeId];
        require(userStake.isActive, "Stake not active");
        
        uint256 rewards = calculateRewards(msg.sender, _stakeId);
        require(rewards > 0, "No rewards available");
        
        // Actualizar estado
        userStake.lastClaimTime = block.timestamp;
        userStake.accumulatedRewards = userStake.accumulatedRewards + rewards;
        totalRewardsDistributed = totalRewardsDistributed + rewards;
        
        // Mint rewards using MinerBotToken interface
        IMinerBotToken(address(stakingToken)).mintGameRewards(msg.sender, rewards);
        
        emit RewardsClaimed(msg.sender, _stakeId, rewards);
    }
    
    /**
     * @dev Retirar stake después del período de bloqueo
     */
    function unstake(uint256 _stakeId) external nonReentrant whenNotPaused {
        require(!userSecurity[msg.sender].isBanned, "User is banned");
        
        UserStake storage userStake = userStakes[msg.sender][_stakeId];
        require(userStake.isActive, "Stake not active");
        
        StakingPool storage pool = stakingPools[userStake.poolId];
        require(block.timestamp >= userStake.startTime + pool.duration, "Stake still locked");
        
        // Reclamar recompensas pendientes
        uint256 pendingRewards = calculateRewards(msg.sender, _stakeId);
        if (pendingRewards > 0) {
            userStake.accumulatedRewards = userStake.accumulatedRewards + pendingRewards;
            totalRewardsDistributed = totalRewardsDistributed + pendingRewards;
            // Mint rewards using MinerBotToken interface
            IMinerBotToken(address(stakingToken)).mintGameRewards(msg.sender, pendingRewards);
        }
        
        // Retirar stake principal
        uint256 stakeAmount = userStake.amount;
        userStake.isActive = false;
        pool.totalStaked = pool.totalStaked - stakeAmount;
        
        // Actualizar seguridad del usuario
        userSecurity[msg.sender].totalWithdrawn = userSecurity[msg.sender].totalWithdrawn + stakeAmount;
        userSecurity[msg.sender].lastActionTime = block.timestamp;
        
        require(stakingToken.transfer(msg.sender, stakeAmount), "Stake transfer failed");
        
        emit Unstaked(msg.sender, _stakeId, stakeAmount);
        if (pendingRewards > 0) {
            emit RewardsClaimed(msg.sender, _stakeId, pendingRewards);
        }
    }
    
    /**
     * @dev Retiro de emergencia con penalización
     */
    function emergencyWithdraw(uint256 _stakeId) external nonReentrant {
        Stake storage userStake = stakes[_stakeId];
        require(userStake.user == msg.sender, "Not stake owner");
        require(userStake.isActive, "Stake not active");
        
        StakingPool storage pool = stakingPools[userStake.poolId];
        uint256 stakeAmount = userStake.amount;
        uint256 penalty = stakeAmount * emergencyWithdrawalFee / 1000;
        uint256 withdrawAmount = stakeAmount - penalty;
        
        // Marcar actividad sospechosa
        userSecurity[msg.sender].suspiciousActivityCount++;
        if (userSecurity[msg.sender].suspiciousActivityCount >= 3) {
            emit SuspiciousActivity(msg.sender, "Multiple emergency withdrawals");
        }
        
        userStake.isActive = false;
        pool.totalStaked = pool.totalStaked - stakeAmount;
        
        require(stakingToken.transfer(msg.sender, withdrawAmount), "Transfer failed");
        
        emit EmergencyWithdrawal(_stakeId, msg.sender, withdrawAmount);
    }
    
    /**
     * @dev Calcular recompensas pendientes
     */
    function calculateRewards(address _user, uint256 _stakeId) public view returns (uint256) {
        UserStake storage userStake = userStakes[_user][_stakeId];
        if (!userStake.isActive) return 0;
        
        StakingPool storage pool = stakingPools[userStake.poolId];
        uint256 timeStaked = block.timestamp - userStake.startTime;
        
        // Calcular recompensa base
        uint256 baseReward = userStake.amount
            * pool.rewardRate
            * timeStaked
            / 365 days
            / 10000;
        
        // Bonus por lealtad
        if (block.timestamp - userStake.startTime >= LOYALTY_BONUS_THRESHOLD) {
            uint256 loyaltyBonus = baseReward * LOYALTY_BONUS_RATE / 10000;
            baseReward = baseReward + loyaltyBonus;
        }
        
        return baseReward;
    }
    

    
    /**
     * @dev Verificaciones anti-fraude
     */
    function _checkAntifraud(address _user, uint256 _amount) internal {
        UserSecurity storage security = userSecurity[_user];
        
        // Verificar límites de tiempo entre acciones
        if (security.lastActionTime > 0) {
            require(block.timestamp - security.lastActionTime >= 1 seconds, "Action too frequent");
        }
        
        // Verificar patrones sospechosos
        if (_amount > 100000 * 10**18 && security.totalStaked == 0) {
            security.suspiciousActivityCount++;
            emit SuspiciousActivity(_user, "Large first stake");
        }
    }
    
    /**
     * @dev Actualizar actividad del usuario
     */
    function _updateUserActivity(address _user) internal {
        UserActivity storage activity = userActivity[_user];
        uint256 currentDay = block.timestamp / 1 days;
        
        if (activity.lastActionDay != currentDay) {
            activity.actionsToday = 1;
            activity.lastActionDay = currentDay;
        } else {
            activity.actionsToday++;
            require(activity.actionsToday <= maxActionsPerDay, "Too many actions today");
            
            // Incrementar score sospechoso si hace muchas acciones
            if (activity.actionsToday >= maxActionsPerDay) {
                activity.suspiciousScore++;
            }
        }
    }
    

    
    /**
     * @dev Reclamar recompensa y cerrar stake (para compatibilidad con tests)
     */
    function claimReward(uint256 _stakeId) external nonReentrant whenNotPaused {
        require(!userSecurity[msg.sender].isBanned, "User is banned");
        require(!bannedUsers[msg.sender], "User is banned");
        require(stakes[_stakeId].user == msg.sender, "Not stake owner");
        
        UserStake storage userStake = userStakes[msg.sender][_stakeId];
        require(userStake.isActive, "Stake not active");
        
        StakingPool storage pool = stakingPools[userStake.poolId];
        
        // Verificar si es retiro temprano
        bool isEarlyWithdrawal = block.timestamp < userStake.startTime + pool.duration;
        
        uint256 stakeAmount = userStake.amount;
        uint256 finalAmount = stakeAmount;
        
        if (isEarlyWithdrawal) {
            // Aplicar penalización por retiro temprano
            uint256 penalty = stakeAmount * earlyWithdrawalPenalty / 10000;
            finalAmount = stakeAmount - penalty;
            emit EarlyWithdrawal(msg.sender, _stakeId, penalty);
        } else {
            // Calcular y agregar recompensas
            uint256 rewards = calculateRewards(msg.sender, _stakeId);
            if (rewards > 0) {
                // Mint rewards using MinerBotToken interface
                IMinerBotToken(address(stakingToken)).mintGameRewards(msg.sender, rewards);
                finalAmount = stakeAmount; // Only return staked amount, rewards are minted separately
                userStake.accumulatedRewards = userStake.accumulatedRewards + rewards;
                totalRewardsDistributed = totalRewardsDistributed + rewards;
                emit RewardsClaimed(msg.sender, _stakeId, rewards);
            }
        }
        
        // Marcar stake como inactivo
        userStake.isActive = false;
        stakes[_stakeId].isActive = false;
        pool.totalStaked = pool.totalStaked - stakeAmount;
        
        // Actualizar estadísticas del pool
        poolStats[userStake.poolId].totalStaked = poolStats[userStake.poolId].totalStaked - stakeAmount;
        if (poolStats[userStake.poolId].totalStakers > 0) {
            poolStats[userStake.poolId].totalStakers--;
        }
        
        // Actualizar seguridad del usuario
        userSecurity[msg.sender].totalWithdrawn = userSecurity[msg.sender].totalWithdrawn + stakeAmount;
        userSecurity[msg.sender].lastActionTime = block.timestamp;
        
        require(stakingToken.transfer(msg.sender, finalAmount), "Transfer failed");
        
        emit RewardClaimed(msg.sender, _stakeId, finalAmount);
    }
    
    // Eventos adicionales para compatibilidad
    event RewardClaimed(address indexed user, uint256 indexed stakeId, uint256 amount);
    event EarlyWithdrawal(address indexed user, uint256 indexed stakeId, uint256 penalty);
    
    /**
     * @dev Crear nuevo pool de staking (solo owner)
     */
    function createPool(
        uint32 _duration,
        uint16 _rewardRate,
        uint256 _maxCapacity
    ) external onlyOwner {
        _createPool(_duration, _rewardRate, _maxCapacity, MINIMUM_STAKE_AMOUNT, MAXIMUM_STAKE_AMOUNT);
    }
    
    function _createPool(
        uint32 _duration,
        uint16 _rewardRate,
        uint256 _maxCapacity,
        uint256 _minStake,
        uint256 _maxStake
    ) internal {
        require(_duration >= MINIMUM_STAKE_DURATION, "Duration too short");
        require(_rewardRate > 0 && _rewardRate <= 5000, "Invalid reward rate"); // Max 50% APY
        
        stakingPools[nextPoolId] = StakingPool({
            duration: _duration,
            rewardRate: _rewardRate,
            totalStaked: 0,
            maxCapacity: _maxCapacity,
            active: true,
            apy: _rewardRate,
            minStake: _minStake,
            maxStake: _maxStake,
            isActive: true
        });
        
        emit PoolCreated(nextPoolId, _duration, _rewardRate);
        nextPoolId++;
    }
    
    /**
     * @dev Banear usuario (solo owner)
     */
    function banUser(address _user, string calldata _reason) external onlyOwner {
        userSecurity[_user].isBanned = true;
        bannedUsers[_user] = true;
        emit UserBanned(_user, _reason);
    }
    
    /**
     * @dev Desbanear usuario (solo owner)
     */
    function unbanUser(address _user) external onlyOwner {
        userSecurity[_user].isBanned = false;
        bannedUsers[_user] = false;
    }
    
    /**
     * @dev Actualizar APY de un pool
     */
    function updatePoolAPY(uint256 _poolId, uint16 _newAPY) external onlyOwner {
        require(_poolId < nextPoolId, "Invalid pool ID");
        stakingPools[_poolId].apy = _newAPY;
        stakingPools[_poolId].rewardRate = _newAPY;
    }
    
    /**
     * @dev Actualizar límites de un pool
     */
    function updatePoolLimits(uint256 _poolId, uint256 _minStake, uint256 _maxStake) external onlyOwner {
        require(_poolId < nextPoolId, "Invalid pool ID");
        stakingPools[_poolId].minStake = _minStake;
        stakingPools[_poolId].maxStake = _maxStake;
    }
    
    /**
     * @dev Establecer máximo de acciones por día
     */
    function setMaxActionsPerDay(uint8 _maxActions) external onlyOwner {
        maxActionsPerDay = _maxActions;
    }
    
    /**
     * @dev Establecer umbral sospechoso
     */
    function setSuspiciousThreshold(uint8 _threshold) external onlyOwner {
        suspiciousThreshold = _threshold;
    }
    
    /**
     * @dev Establecer penalización por retiro temprano
     */
    function setEarlyWithdrawalPenalty(uint16 _penalty) external onlyOwner {
        require(_penalty <= 5000, "Penalty too high"); // Max 50%
        earlyWithdrawalPenalty = _penalty;
    }
    
    /**
     * @dev Obtener información de stakes del usuario
     */
    function getUserStakes(address _user) external view returns (uint256[] memory) {
        return userStakeIds[_user];
    }
    
    /**
     * @dev Obtener información detallada de un stake
     */
    function getStakeInfo(address _user, uint256 _stakeId) external view returns (
        uint256 amount,
        uint256 startTime,
        uint256 lastClaimTime,
        uint256 poolId,
        uint256 accumulatedRewards,
        bool isActive,
        uint256 pendingRewards
    ) {
        UserStake storage userStake = userStakes[_user][_stakeId];
        return (
            userStake.amount,
            userStake.startTime,
            userStake.lastClaimTime,
            userStake.poolId,
            userStake.accumulatedRewards,
            userStake.isActive,
            calculateRewards(_user, _stakeId)
        );
    }
    
    /**
     * @dev Funciones de administración
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function setEmergencyWithdrawalFee(uint8 _fee) external onlyOwner {
        require(_fee <= 100, "Fee too high"); // Max 10%
        emergencyWithdrawalFee = _fee;
    }
    
    function togglePoolStatus(uint256 _poolId) external onlyOwner {
        require(_poolId < nextPoolId, "Invalid pool ID");
        stakingPools[_poolId].active = !stakingPools[_poolId].active;
        stakingPools[_poolId].isActive = !stakingPools[_poolId].isActive;
    }
    
    /**
     * @dev Retirar tokens de emergencia (solo owner)
     */
    function emergencyTokenWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }
}