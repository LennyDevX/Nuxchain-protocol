// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MinerBotToken.sol";
import "./MinerBotNFT.sol";

/**
 * @title MinerBotGame
 * @dev Contrato principal del juego MinerBot Empire
 * 
 * Características:
 * - Minería idle automática
 * - Sistema de zonas con diferentes recursos
 * - Recompensas basadas en atributos del robot
 * - Mecánicas anti-fraude
 * - Sistema de energía y mantenimiento
 * - Eventos especiales y meteoritos
 */
contract MinerBotGame is ReentrancyGuard, Pausable, Ownable {

    // Referencias a contratos
    MinerBotToken public minerBotToken;
    MinerBotNFT public minerBotNFT;

    // Enums
    enum ResourceType { Iron, Gold, Crystal, Energy, Data }
    enum ZoneType { Basic, Advanced, Elite, Legendary }

    // Estructuras
    struct MiningZone {
        string name;
        ZoneType zoneType;
        ResourceType primaryResource;
        ResourceType secondaryResource;
        uint256 baseReward;          // Recompensa base por hora
        uint8 difficultyLevel;       // Nivel de dificultad (1-100)
        uint16 energyCost;           // Costo de energía por hora (max 65535)
        uint16 maxMiners;            // Máximo de robots simultáneos (max 65535)
        uint16 currentMiners;        // Robots actualmente minando (max 65535)
        bool isActive;               // Si la zona está activa
        uint256 discoveryTime;       // Cuándo fue descubierta
    }

    struct MiningSession {
        uint256 robotId;
        uint256 zoneId;
        uint256 startTime;
        uint256 lastClaim;
        uint256 energySpent;
        bool isActive;
        uint256 totalRewards;
    }

    struct PlayerStats {
        uint256 totalMined;
        uint256 totalRewards;
        uint16 robotsOwned;          // Máximo robots por jugador (max 65535)
        uint8 zonesDiscovered;       // Máximo zonas (max 255)
        uint256 lastActivity;
        uint32 reputation;           // Reputación del jugador (max 4B)
        bool isBanned;               // Si está baneado por fraude
    }

    struct SpecialEvent {
        string name;
        uint256 startTime;
        uint256 endTime;
        uint16 bonusMultiplier;      // Multiplicador de recompensas (100 = 1x, max 65535)
        ResourceType bonusResource;
        bool isActive;
    }

    // Mappings
    mapping(uint256 => MiningZone) public miningZones;
    mapping(uint256 => mapping(uint256 => MiningSession)) public miningSessions; // robotId => zoneId => session
    mapping(address => PlayerStats) public playerStats;
    mapping(uint256 => SpecialEvent) public specialEvents;
    mapping(address => uint256) public playerEnergy;
    mapping(address => uint256) public lastEnergyUpdate;
    mapping(uint256 => uint256) public robotLastMaintenance;
    mapping(address => mapping(uint256 => uint256)) public playerResources; // player => resourceType => amount

    // Configuración del juego
    uint16 public constant MAX_ENERGY = 1000;
    uint8 public constant ENERGY_REGEN_RATE = 1; // 1 energía por minuto
    uint256 public constant MAINTENANCE_INTERVAL = 24 hours;
    uint8 public constant FRAUD_DETECTION_THRESHOLD = 10; // Máximo claims por hora
    uint256 public constant REPUTATION_DECAY_TIME = 7 days;
    
    uint16 public zoneCounter;           // Máximo 65535 zonas
    uint16 public eventCounter;          // Máximo 65535 eventos
    uint256 public totalRewardsDistributed;
    uint256 public gameStartTime;

    // Anti-fraude
    mapping(address => uint256[]) public recentClaims;
    mapping(address => uint256) public suspiciousActivity;
    
    // Events
    event MiningStarted(address indexed player, uint256 indexed robotId, uint256 indexed zoneId);
    event MiningClaimed(address indexed player, uint256 indexed robotId, uint256 reward, ResourceType resource);
    event MiningStopped(address indexed player, uint256 indexed robotId, uint256 indexed zoneId);
    event ZoneDiscovered(uint256 indexed zoneId, string name, ZoneType zoneType);
    event SpecialEventStarted(uint256 indexed eventId, string name, uint256 bonusMultiplier);
    event PlayerBanned(address indexed player, string reason);
    event ReputationChanged(address indexed player, uint256 newReputation);
    event EnergyRestored(address indexed player, uint256 amount);

    modifier validRobot(uint256 robotId) {
        require(minerBotNFT.ownerOf(robotId) == msg.sender, "MBG: Not robot owner");
        _;
    }

    modifier notBanned() {
        require(!playerStats[msg.sender].isBanned, "MBG: Player is banned");
        _;
    }

    modifier antiSpam() {
        _updateRecentClaims(msg.sender);
        require(recentClaims[msg.sender].length <= FRAUD_DETECTION_THRESHOLD, "MBG: Too many claims");
        _;
    }

    constructor(address _minerBotToken, address _minerBotNFT) {
        require(_minerBotToken != address(0), "MBG: Invalid token address");
        require(_minerBotNFT != address(0), "MBG: Invalid NFT address");
        
        minerBotToken = MinerBotToken(_minerBotToken);
        minerBotNFT = MinerBotNFT(_minerBotNFT);
        gameStartTime = block.timestamp;
        
        // Crear zonas iniciales
        _createInitialZones();
    }

    /**
     * @dev Crea las zonas iniciales del juego
     */
    function _createInitialZones() internal {
        // Zona básica - Iron Mine
        _createZone(
            "Iron Mine",
            ZoneType.Basic,
            ResourceType.Iron,
            ResourceType.Energy,
            100, // 100 tokens por hora base
            10,  // Dificultad 10
            5,   // 5 energía por hora
            1000 // Máximo 1000 robots
        );
        
        // Zona avanzada - Gold Quarry
        _createZone(
            "Gold Quarry",
            ZoneType.Advanced,
            ResourceType.Gold,
            ResourceType.Iron,
            250, // 250 tokens por hora base
            25,  // Dificultad 25
            15,  // 15 energía por hora
            500  // Máximo 500 robots
        );
        
        // Zona élite - Crystal Caverns
        _createZone(
            "Crystal Caverns",
            ZoneType.Elite,
            ResourceType.Crystal,
            ResourceType.Gold,
            500, // 500 tokens por hora base
            50,  // Dificultad 50
            30,  // 30 energía por hora
            200  // Máximo 200 robots
        );
        
        // Zona legendaria - Data Core
        _createZone(
            "Data Core",
            ZoneType.Legendary,
            ResourceType.Data,
            ResourceType.Crystal,
            1000, // 1000 tokens por hora base
            80,   // Dificultad 80
            50,   // 50 energía por hora
            50    // Máximo 50 robots
        );
    }

    /**
     * @dev Crea una nueva zona de minería
     */
    function _createZone(
        string memory name,
        ZoneType zoneType,
        ResourceType primaryResource,
        ResourceType secondaryResource,
        uint256 baseReward,
        uint8 difficultyLevel,
        uint16 energyCost,
        uint16 maxMiners
    ) internal {
        miningZones[zoneCounter] = MiningZone({
            name: name,
            zoneType: zoneType,
            primaryResource: primaryResource,
            secondaryResource: secondaryResource,
            baseReward: baseReward,
            difficultyLevel: difficultyLevel,
            energyCost: energyCost,
            maxMiners: maxMiners,
            currentMiners: 0,
            isActive: true,
            discoveryTime: block.timestamp
        });
        
        emit ZoneDiscovered(zoneCounter, name, zoneType);
        zoneCounter++;
    }

    /**
     * @dev Inicia minería en una zona específica
     */
    function startMining(uint256 robotId, uint256 zoneId) 
        external 
        nonReentrant 
        whenNotPaused 
        validRobot(robotId) 
        notBanned 
    {
        require(zoneId < zoneCounter, "MBG: Invalid zone");
        require(miningZones[zoneId].isActive, "MBG: Zone not active");
        require(!miningSessions[robotId][zoneId].isActive, "MBG: Already mining in this zone");
        require(
            miningZones[zoneId].currentMiners < miningZones[zoneId].maxMiners,
            "MBG: Zone at capacity"
        );
        
        // Verificar que el robot no esté minando en otra zona
        require(!_isRobotMining(robotId), "MBG: Robot already mining elsewhere");
        
        // Verificar energía del jugador
        _updatePlayerEnergy(msg.sender);
        require(playerEnergy[msg.sender] >= miningZones[zoneId].energyCost, "MBG: Insufficient energy");
        
        // Verificar atributos del robot vs dificultad de la zona
        require(_canRobotMineInZone(robotId, zoneId), "MBG: Robot not suitable for this zone");
        
        // Verificar mantenimiento del robot
        require(
            block.timestamp - robotLastMaintenance[robotId] < MAINTENANCE_INTERVAL,
            "MBG: Robot needs maintenance"
        );
        
        // Iniciar sesión de minería
        miningSessions[robotId][zoneId] = MiningSession({
            robotId: robotId,
            zoneId: zoneId,
            startTime: block.timestamp,
            lastClaim: block.timestamp,
            energySpent: 0,
            isActive: true,
            totalRewards: 0
        });
        
        miningZones[zoneId].currentMiners++;
        playerStats[msg.sender].lastActivity = block.timestamp;
        
        emit MiningStarted(msg.sender, robotId, zoneId);
    }

    /**
     * @dev Reclama recompensas de minería
     */
    function claimMiningRewards(uint256 robotId, uint256 zoneId) 
        external 
        nonReentrant 
        whenNotPaused 
        validRobot(robotId) 
        notBanned 
        antiSpam 
    {
        MiningSession storage session = miningSessions[robotId][zoneId];
        require(session.isActive, "MBG: No active mining session");
        
        uint256 timeElapsed = block.timestamp - session.lastClaim;
        require(timeElapsed >= 1 hours, "MBG: Must wait at least 1 hour");
        
        // Calcular recompensas
        (uint256 primaryReward, uint256 secondaryReward) = _calculateRewards(robotId, zoneId, timeElapsed);
        
        // Verificar que el robot aún tenga energía
        uint256 energyNeeded = miningZones[zoneId].energyCost * timeElapsed / 1 hours;
        _updatePlayerEnergy(msg.sender);
        
        if (playerEnergy[msg.sender] < energyNeeded) {
            // Detener minería por falta de energía
            _stopMining(robotId, zoneId);
            return;
        }
        
        // Consumir energía
        playerEnergy[msg.sender] = playerEnergy[msg.sender] - energyNeeded;
        session.energySpent = session.energySpent + energyNeeded;
        
        // Distribuir recompensas
        if (primaryReward > 0) {
            minerBotToken.mintGameRewards(msg.sender, primaryReward);
            playerResources[msg.sender][uint256(miningZones[zoneId].primaryResource)] = 
                playerResources[msg.sender][uint256(miningZones[zoneId].primaryResource)] + primaryReward;
        }
        
        if (secondaryReward > 0) {
            playerResources[msg.sender][uint256(miningZones[zoneId].secondaryResource)] = 
                playerResources[msg.sender][uint256(miningZones[zoneId].secondaryResource)] + secondaryReward;
        }
        
        // Actualizar estadísticas
        session.lastClaim = block.timestamp;
        session.totalRewards = session.totalRewards + primaryReward + secondaryReward;
        playerStats[msg.sender].totalRewards = playerStats[msg.sender].totalRewards + primaryReward + secondaryReward;
        playerStats[msg.sender].lastActivity = block.timestamp;
        totalRewardsDistributed = totalRewardsDistributed + primaryReward + secondaryReward;
        
        // Añadir experiencia al robot
        uint256 experience = timeElapsed / 1 hours * 10; // 10 exp por hora
        minerBotNFT.addExperience(robotId, experience);
        
        // Actualizar reputación
        _updateReputation(msg.sender, true);
        
        emit MiningClaimed(msg.sender, robotId, primaryReward + secondaryReward, miningZones[zoneId].primaryResource);
    }

    /**
     * @dev Detiene la minería de un robot
     */
    function stopMining(uint256 robotId, uint256 zoneId) 
        external 
        nonReentrant 
        validRobot(robotId) 
    {
        _stopMining(robotId, zoneId);
    }

    /**
     * @dev Función interna para detener minería
     */
    function _stopMining(uint256 robotId, uint256 zoneId) internal {
        MiningSession storage session = miningSessions[robotId][zoneId];
        require(session.isActive, "MBG: No active mining session");
        
        session.isActive = false;
        miningZones[zoneId].currentMiners--;
        
        emit MiningStopped(msg.sender, robotId, zoneId);
    }

    /**
     * @dev Calcula recompensas basadas en atributos del robot y zona
     */
    function _calculateRewards(uint256 robotId, uint256 zoneId, uint256 timeElapsed) 
        internal 
        view 
        returns (uint256 primaryReward, uint256 secondaryReward) 
    {
        MinerBotNFT.RobotAttributes memory robot = minerBotNFT.getRobotInfo(robotId);
        MiningZone memory zone = miningZones[zoneId];
        
        // Recompensa base por hora
        uint256 baseRewardPerHour = zone.baseReward;
        
        // Multiplicador basado en atributos del robot
        uint256 efficiencyMultiplier = (robot.efficiency + robot.miningPower) / 2;
        uint256 rarityBonus = _getRarityBonus(robot.rarity);
        uint256 levelBonus = robot.level * 2; // 2% por nivel
        uint256 evolutionBonus = robot.isEvolved ? 50 : 0; // 50% si está evolucionado
        
        // Multiplicador total (base 100)
        uint256 totalMultiplier = uint256(100)
            + (efficiencyMultiplier / 10) // Eficiencia/10 como porcentaje
            + rarityBonus
            + levelBonus
            + evolutionBonus;
        
        // Aplicar multiplicador de evento especial si está activo
        uint256 eventMultiplier = _getActiveEventMultiplier();
        totalMultiplier = totalMultiplier * eventMultiplier / 100;
        
        // Calcular recompensa primaria
        primaryReward = baseRewardPerHour
            * timeElapsed
            / 1 hours
            * totalMultiplier
            / 100;
        
        // Recompensa secundaria (20% de la primaria)
        secondaryReward = primaryReward / 5;
        
        // Aplicar degradación por mantenimiento
        uint256 maintenanceDecay = _getMaintenanceDecay(robotId);
        primaryReward = primaryReward * maintenanceDecay / 100;
        secondaryReward = secondaryReward * maintenanceDecay / 100;
    }

    /**
     * @dev Obtiene bonificación por rareza
     */
    function _getRarityBonus(MinerBotNFT.Rarity rarity) internal pure returns (uint256) {
        if (rarity == MinerBotNFT.Rarity.Common) return 0;
        if (rarity == MinerBotNFT.Rarity.Uncommon) return 10;
        if (rarity == MinerBotNFT.Rarity.Rare) return 25;
        if (rarity == MinerBotNFT.Rarity.Epic) return 50;
        if (rarity == MinerBotNFT.Rarity.Legendary) return 100;
        return 0;
    }

    /**
     * @dev Verifica si un robot puede minar en una zona específica
     */
    function _canRobotMineInZone(uint256 robotId, uint256 zoneId) internal view returns (bool) {
        MinerBotNFT.RobotAttributes memory robot = minerBotNFT.getRobotInfo(robotId);
        MiningZone memory zone = miningZones[zoneId];
        
        // Verificar que la eficiencia del robot sea suficiente para la dificultad
        uint256 requiredEfficiency = zone.difficultyLevel * 5; // 5 puntos de eficiencia por nivel de dificultad
        return robot.efficiency >= requiredEfficiency;
    }

    /**
     * @dev Verifica si un robot está minando en alguna zona
     */
    function _isRobotMining(uint256 robotId) internal view returns (bool) {
        for (uint256 i = 0; i < zoneCounter; i++) {
            if (miningSessions[robotId][i].isActive) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Actualiza la energía del jugador
     */
    function _updatePlayerEnergy(address player) internal {
        // Inicializar lastEnergyUpdate si es la primera vez
        if (lastEnergyUpdate[player] == 0) {
            lastEnergyUpdate[player] = block.timestamp;
            // No hay energía regenerada en la primera inicialización
            return;
        }
        
        uint256 timePassed = block.timestamp - lastEnergyUpdate[player];
        uint256 energyToAdd = timePassed / 60 * ENERGY_REGEN_RATE; // 1 energía por minuto
        
        playerEnergy[player] = playerEnergy[player] + energyToAdd;
        if (playerEnergy[player] > MAX_ENERGY) {
            playerEnergy[player] = MAX_ENERGY;
        }
        
        lastEnergyUpdate[player] = block.timestamp;
    }

    /**
     * @dev Obtiene multiplicador de evento activo
     */
    function _getActiveEventMultiplier() internal view returns (uint256) {
        for (uint256 i = 0; i < eventCounter; i++) {
            SpecialEvent memory evt = specialEvents[i];
            if (evt.isActive && block.timestamp >= evt.startTime && block.timestamp <= evt.endTime) {
                return evt.bonusMultiplier;
            }
        }
        return 100; // Sin bonificación
    }

    /**
     * @dev Calcula degradación por falta de mantenimiento
     */
    function _getMaintenanceDecay(uint256 robotId) internal view returns (uint256) {
        uint256 timeSinceMaintenance = block.timestamp - robotLastMaintenance[robotId];
        
        if (timeSinceMaintenance <= MAINTENANCE_INTERVAL) {
            return 100; // Sin degradación
        }
        
        // Degradación del 10% por día después del intervalo
        uint256 daysOverdue = (timeSinceMaintenance - MAINTENANCE_INTERVAL) / 1 days;
        uint256 decay = daysOverdue * 10;
        
        return decay >= 90 ? 10 : uint256(100) - decay; // Mínimo 10% de eficiencia
    }

    /**
     * @dev Actualiza claims recientes para detección de fraude
     */
    function _updateRecentClaims(address player) internal {
        uint256 currentHour = block.timestamp / 1 hours;
        
        // Limpiar claims de horas anteriores
        uint256[] storage claims = recentClaims[player];
        uint256 validClaims = 0;
        
        for (uint256 i = 0; i < claims.length; i++) {
            if (claims[i] >= currentHour) {
                claims[validClaims] = claims[i];
                validClaims++;
            }
        }
        
        // Ajustar el array
        while (claims.length > validClaims) {
            claims.pop();
        }
        
        // Añadir claim actual
        claims.push(currentHour);
    }

    /**
     * @dev Actualiza reputación del jugador
     */
    function _updateReputation(address player, bool positive) internal {
        if (positive) {
            playerStats[player].reputation = playerStats[player].reputation + 1;
        } else {
            if (playerStats[player].reputation > 0) {
                playerStats[player].reputation = playerStats[player].reputation - 1;
            }
            
            suspiciousActivity[player]++;
            
            // Banear si hay demasiada actividad sospechosa
            if (suspiciousActivity[player] >= 10) {
                playerStats[player].isBanned = true;
                emit PlayerBanned(player, "Suspicious activity detected");
            }
        }
        
        emit ReputationChanged(player, playerStats[player].reputation);
    }

    /**
     * @dev Realiza mantenimiento de un robot
     */
    function performRobotMaintenance(uint256 robotId) external validRobot(robotId) {
        robotLastMaintenance[robotId] = block.timestamp;
        
        // Costo de mantenimiento se maneja en el contrato NFT
        minerBotNFT.performMaintenanceByGame(robotId, msg.sender);
    }

    /**
     * @dev Compra energía adicional
     */
    function buyEnergy(uint16 amount) external nonReentrant {
        require(amount > 0 && amount <= 500, "MBG: Invalid energy amount");
        
        uint256 cost = uint256(amount) * 10 * 10**18; // 10 MBT por energía
        require(minerBotToken.transferFrom(msg.sender, address(this), cost), "MBG: Payment failed");
        
        _updatePlayerEnergy(msg.sender);
        playerEnergy[msg.sender] = playerEnergy[msg.sender] + amount;
        
        if (playerEnergy[msg.sender] > MAX_ENERGY) {
            playerEnergy[msg.sender] = MAX_ENERGY;
        }
        
        emit EnergyRestored(msg.sender, amount);
    }

    /**
     * @dev Crea un evento especial (solo owner)
     */
    function createSpecialEvent(
        string memory name,
        uint256 duration,
        uint16 bonusMultiplier,
        ResourceType bonusResource
    ) external onlyOwner {
        specialEvents[eventCounter] = SpecialEvent({
            name: name,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            bonusMultiplier: bonusMultiplier,
            bonusResource: bonusResource,
            isActive: true
        });
        
        emit SpecialEventStarted(eventCounter, name, bonusMultiplier);
        eventCounter++;
    }

    /**
     * @dev Desbanea un jugador (solo owner)
     */
    function unbanPlayer(address player) external onlyOwner {
        playerStats[player].isBanned = false;
        suspiciousActivity[player] = 0;
    }

    /**
     * @dev Obtiene información de minería de un robot
     */
    function getMiningInfo(uint256 robotId, uint256 zoneId) external view returns (MiningSession memory) {
        return miningSessions[robotId][zoneId];
    }

    /**
     * @dev Obtiene estadísticas del jugador
     */
    function getPlayerStats(address player) external view returns (PlayerStats memory) {
        return playerStats[player];
    }

    /**
     * @dev Obtiene información de una zona
     */
    function getZoneInfo(uint256 zoneId) external view returns (MiningZone memory) {
        require(zoneId < zoneCounter, "MBG: Invalid zone");
        return miningZones[zoneId];
    }

    /**
     * @dev Obtiene energía actual del jugador
     */
    function getPlayerEnergy(address player) external view returns (uint256) {
        // Si es la primera vez, no hay energía
        if (lastEnergyUpdate[player] == 0) {
            return 0;
        }
        
        uint256 timePassed = block.timestamp - lastEnergyUpdate[player];
        uint256 energyToAdd = timePassed / 60 * ENERGY_REGEN_RATE;
        uint256 currentEnergy = playerEnergy[player] + energyToAdd;
        
        return currentEnergy > MAX_ENERGY ? MAX_ENERGY : currentEnergy;
    }

    /**
     * @dev Pausa/despausa el juego
     */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Función de emergencia para retirar tokens
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = minerBotToken.balanceOf(address(this));
        minerBotToken.transfer(owner(), balance);
    }
}