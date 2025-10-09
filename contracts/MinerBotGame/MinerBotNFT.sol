// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MinerBotNFT
 * @dev NFTs de robots mineros con atributos, rareza y sistema de evolución
 * 
 * Características:
 * - 5 niveles de rareza: Common, Uncommon, Rare, Epic, Legendary
 * - Atributos modulares: Mining Power, Battery, Communication, Storage, Durability
 * - Sistema de evolución y upgrades
 * - Breeding entre robots
 * - Metadata on-chain para transparencia
 */
contract MinerBotNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    
    // Referencia al token del juego
    IERC20 public minerBotToken;
    
    // Enums
    enum Rarity { Common, Uncommon, Rare, Epic, Legendary }
    enum RobotType { Excavator, Processor, Scanner, Communicator, Hybrid }
    
    // Estructura de atributos del robot
    struct RobotAttributes {
        uint16 miningPower;      // Poder de minería (1-1000)
        uint16 battery;          // Duración de batería (1-1000)
        uint16 communication;    // Capacidad de comunicación (1-1000)
        uint16 storageCapacity;  // Capacidad de almacenamiento (1-1000)
        uint16 durability;       // Durabilidad (1-1000)
        uint16 efficiency;       // Eficiencia general (calculada)
        Rarity rarity;           // Nivel de rareza
        RobotType robotType;     // Tipo de robot
        uint8 generation;        // Generación (para breeding, max 255)
        uint32 experience;       // Experiencia acumulada (max 4B)
        uint8 level;             // Nivel del robot (1-100)
        bool isEvolved;          // Si ha evolucionado
        uint256 birthTime;       // Timestamp de creación
        uint256 lastMaintenance; // Último mantenimiento
    }
    
    // Estructura de costos de minting
    struct MintCost {
        uint256 tokenCost;       // Costo en MBT tokens
        uint256 ethCost;         // Costo en ETH (para gas y desarrollo)
    }
    
    // Mappings
    mapping(uint256 => RobotAttributes) public robotAttributes;
    mapping(Rarity => MintCost) public mintCosts;
    mapping(Rarity => uint256) public raritySupply;
    mapping(Rarity => uint256) public maxRaritySupply;
    mapping(address => bool) public authorizedMinters;
    mapping(uint256 => uint256) public robotParent1;
    mapping(uint256 => uint256) public robotParent2;
    mapping(uint256 => uint256[]) public robotChildren;
    
    // Configuración del juego
    address public gameContract;
    uint256 public breedingCooldown = 7 days;
    uint256 public maintenanceCost = 100 * 10**18; // 100 MBT
    uint256 public evolutionCost = 1000 * 10**18;  // 1000 MBT
    
    // Límites de supply por rareza
    uint32 public constant MAX_COMMON = 50000;
    uint32 public constant MAX_UNCOMMON = 20000;
    uint16 public constant MAX_RARE = 8000;
    uint16 public constant MAX_EPIC = 2000;
    uint16 public constant MAX_LEGENDARY = 500;
    
    // Events
    event RobotMinted(uint256 indexed tokenId, address indexed owner, Rarity rarity, RobotType robotType);
    event RobotEvolved(uint256 indexed tokenId, uint256 newLevel);
    event RobotBred(uint256 indexed parent1, uint256 indexed parent2, uint256 indexed childId);
    event ExperienceGained(uint256 indexed tokenId, uint256 experience);
    event MaintenancePerformed(uint256 indexed tokenId, uint256 cost);
    event AttributesUpgraded(uint256 indexed tokenId, string attribute, uint256 newValue);
    
    modifier onlyGameContract() {
        require(msg.sender == gameContract, "MBN: Only game contract");
        _;
    }
    
    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "MBN: Not authorized minter");
        _;
    }
    
    constructor(address _minerBotToken) ERC721("MinerBot NFT", "MBOT") Ownable() {
        require(_minerBotToken != address(0), "MBN: Invalid token address");
        minerBotToken = IERC20(_minerBotToken);
        
        // Configurar límites de supply
        maxRaritySupply[Rarity.Common] = MAX_COMMON;
        maxRaritySupply[Rarity.Uncommon] = MAX_UNCOMMON;
        maxRaritySupply[Rarity.Rare] = MAX_RARE;
        maxRaritySupply[Rarity.Epic] = MAX_EPIC;
        maxRaritySupply[Rarity.Legendary] = MAX_LEGENDARY;
        
        // Configurar costos de minting
        mintCosts[Rarity.Common] = MintCost(100 * 10**18, 0.001 ether);
        mintCosts[Rarity.Uncommon] = MintCost(500 * 10**18, 0.005 ether);
        mintCosts[Rarity.Rare] = MintCost(2000 * 10**18, 0.02 ether);
        mintCosts[Rarity.Epic] = MintCost(10000 * 10**18, 0.1 ether);
        mintCosts[Rarity.Legendary] = MintCost(50000 * 10**18, 0.5 ether);
    }
    
    /**
     * @dev Mintea un nuevo robot con rareza específica
     */
    function mintRobot(address to, Rarity rarity, RobotType robotType) external payable nonReentrant whenNotPaused {
        require(to != address(0), "MBN: Invalid recipient");
        require(uint256(rarity) < 5, "MBN: Invalid rarity");
        require(raritySupply[rarity] < maxRaritySupply[rarity], "MBN: Rarity supply exhausted");
        
        MintCost memory cost = mintCosts[rarity];
        require(msg.value >= cost.ethCost, "MBN: Insufficient ETH");
        
        // Transferir tokens MBT
        if (cost.tokenCost > 0) {
            require(
                minerBotToken.transferFrom(msg.sender, address(this), cost.tokenCost),
                "MBN: Token transfer failed"
            );
        }
        
        uint256 tokenId = _tokenIdCounter;
        ++_tokenIdCounter;
        
        // Generar atributos basados en rareza y tipo
        RobotAttributes memory attributes = _generateAttributes(rarity, robotType);
        robotAttributes[tokenId] = attributes;
        
        raritySupply[rarity] = raritySupply[rarity] + 1;
        
        _safeMint(to, tokenId);
        
        emit RobotMinted(tokenId, to, rarity, robotType);
    }
    
    /**
     * @dev Mint especial para el contrato del juego
     */
    function mintGameReward(address to, Rarity rarity, RobotType robotType) external onlyGameContract {
        require(to != address(0), "MBN: Invalid recipient");
        require(raritySupply[rarity] < maxRaritySupply[rarity], "MBN: Rarity supply exhausted");
        
        uint256 tokenId = _tokenIdCounter;
        ++_tokenIdCounter;
        
        RobotAttributes memory attributes = _generateAttributes(rarity, robotType);
        robotAttributes[tokenId] = attributes;
        
        raritySupply[rarity] = raritySupply[rarity] + 1;
        
        _safeMint(to, tokenId);
        
        emit RobotMinted(tokenId, to, rarity, robotType);
    }
    
    /**
     * @dev Genera atributos aleatorios basados en rareza y tipo
     */
    function _generateAttributes(Rarity rarity, RobotType robotType) internal view returns (RobotAttributes memory) {
        uint256 baseMultiplier = _getRarityMultiplier(rarity);
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, _tokenIdCounter)));
        
        // Generar atributos base
        uint16 miningPower = _generateAttribute(randomSeed, 1, baseMultiplier);
        uint16 battery = _generateAttribute(randomSeed >> 8, 2, baseMultiplier);
        uint16 communication = _generateAttribute(randomSeed >> 16, 3, baseMultiplier);
        uint16 storageCapacity = _generateAttribute(randomSeed >> 24, 4, baseMultiplier);
        uint16 durability = _generateAttribute(randomSeed >> 32, 5, baseMultiplier);
        
        // Aplicar bonificaciones por tipo de robot
        (miningPower, battery, communication, storageCapacity, durability) = _applyTypeBonus(
            robotType, miningPower, battery, communication, storageCapacity, durability
        );
        
        uint16 efficiency = _calculateEfficiency(miningPower, battery, communication, storageCapacity, durability);
        
        return RobotAttributes({
            miningPower: miningPower,
            battery: battery,
            communication: communication,
            storageCapacity: storageCapacity,
            durability: durability,
            efficiency: efficiency,
            rarity: rarity,
            robotType: robotType,
            generation: 1,
            experience: 0,
            level: 1,
            isEvolved: false,
            birthTime: block.timestamp,
            lastMaintenance: block.timestamp
        });
    }
    
    /**
     * @dev Obtiene multiplicador basado en rareza
     */
    function _getRarityMultiplier(Rarity rarity) internal pure returns (uint256) {
        if (rarity == Rarity.Common) return 100;
        if (rarity == Rarity.Uncommon) return 200;
        if (rarity == Rarity.Rare) return 400;
        if (rarity == Rarity.Epic) return 700;
        if (rarity == Rarity.Legendary) return 1000;
        return 100;
    }
    
    /**
     * @dev Genera un atributo individual
     */
    function _generateAttribute(uint256 seed, uint256 salt, uint256 multiplier) internal pure returns (uint16) {
        uint256 random = uint256(keccak256(abi.encodePacked(seed, salt))) % 100;
        uint256 base = 50 + random; // 50-149
        return uint16((base * multiplier) / 100); // Aplicar multiplicador de rareza
    }
    
    /**
     * @dev Aplica bonificaciones por tipo de robot
     */
    function _applyTypeBonus(
        RobotType robotType,
        uint16 mining,
        uint16 battery,
        uint16 comm,
        uint16 storageCapacity,
        uint16 durability
    ) internal pure returns (uint16, uint16, uint16, uint16, uint16) {
        uint256 newMining = mining;
        uint256 newBattery = battery;
        uint256 newComm = comm;
        uint256 newStorage = storageCapacity;
        uint256 newDurability = durability;
        
        if (robotType == RobotType.Excavator) {
            newMining = (newMining * 150) / 100; // +50% mining
            newDurability = (newDurability * 120) / 100; // +20% durability
        } else if (robotType == RobotType.Processor) {
            newStorage = (newStorage * 150) / 100; // +50% storage
            newBattery = (newBattery * 120) / 100; // +20% battery
        } else if (robotType == RobotType.Scanner) {
            newComm = (newComm * 150) / 100; // +50% communication
            newMining = (newMining * 110) / 100; // +10% mining
        } else if (robotType == RobotType.Communicator) {
            newComm = (newComm * 200) / 100; // +100% communication
        } else if (robotType == RobotType.Hybrid) {
            // Bonificación balanceada del 10% en todos
            newMining = (newMining * 110) / 100;
            newBattery = (newBattery * 110) / 100;
            newComm = (newComm * 110) / 100;
            newStorage = (newStorage * 110) / 100;
            newDurability = (newDurability * 110) / 100;
        }
        
        // Ensure values don't exceed uint16 max
        newMining = newMining > 65535 ? 65535 : newMining;
        newBattery = newBattery > 65535 ? 65535 : newBattery;
        newComm = newComm > 65535 ? 65535 : newComm;
        newStorage = newStorage > 65535 ? 65535 : newStorage;
        newDurability = newDurability > 65535 ? 65535 : newDurability;
        
        return (uint16(newMining), uint16(newBattery), uint16(newComm), uint16(newStorage), uint16(newDurability));
    }
    
    /**
     * @dev Calcula eficiencia general
     */
    function _calculateEfficiency(
        uint16 mining,
        uint16 battery,
        uint16 comm,
        uint16 storageCapacity,
        uint16 durability
    ) internal pure returns (uint16) {
        return uint16((uint256(mining) + uint256(battery) + uint256(comm) + uint256(storageCapacity) + uint256(durability)) / 5);
    }
    
    /**
     * @dev Breeding entre dos robots
     */
    function breedRobots(uint256 parent1Id, uint256 parent2Id) external nonReentrant whenNotPaused {
        require(ownerOf(parent1Id) == msg.sender, "MBN: Not owner of parent1");
        require(ownerOf(parent2Id) == msg.sender, "MBN: Not owner of parent2");
        require(parent1Id != parent2Id, "MBN: Cannot breed with itself");
        
        RobotAttributes storage parent1 = robotAttributes[parent1Id];
        RobotAttributes storage parent2 = robotAttributes[parent2Id];
        
        require(
            block.timestamp >= parent1.lastMaintenance + breedingCooldown,
            "MBN: Parent1 breeding cooldown"
        );
        require(
            block.timestamp >= parent2.lastMaintenance + breedingCooldown,
            "MBN: Parent2 breeding cooldown"
        );
        
        // Costo de breeding
        uint256 breedingCost = 500 * 10**18; // 500 MBT
        require(
            minerBotToken.transferFrom(msg.sender, address(this), breedingCost),
            "MBN: Breeding cost transfer failed"
        );
        
        uint256 childId = _tokenIdCounter;
        ++_tokenIdCounter;
        
        // Generar atributos del hijo
        RobotAttributes memory childAttributes = _breedAttributes(parent1, parent2);
        robotAttributes[childId] = childAttributes;
        
        // Registrar parentesco
        robotParent1[childId] = parent1Id;
        robotParent2[childId] = parent2Id;
        robotChildren[parent1Id].push(childId);
        robotChildren[parent2Id].push(childId);
        
        // Actualizar cooldowns
        parent1.lastMaintenance = block.timestamp;
        parent2.lastMaintenance = block.timestamp;
        
        _safeMint(msg.sender, childId);
        
        emit RobotBred(parent1Id, parent2Id, childId);
    }
    
    /**
     * @dev Genera atributos para breeding
     */
    function _breedAttributes(
        RobotAttributes memory parent1,
        RobotAttributes memory parent2
    ) internal view returns (RobotAttributes memory) {
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, _tokenIdCounter)));
        
        // Heredar atributos (promedio + variación)
        uint16 miningPower = _inheritAttribute(parent1.miningPower, parent2.miningPower, randomSeed, 1);
        uint16 battery = _inheritAttribute(parent1.battery, parent2.battery, randomSeed, 2);
        uint16 communication = _inheritAttribute(parent1.communication, parent2.communication, randomSeed, 3);
        uint16 storageCapacity = _inheritAttribute(parent1.storageCapacity, parent2.storageCapacity, randomSeed, 4);
        uint16 durability = _inheritAttribute(parent1.durability, parent2.durability, randomSeed, 5);
        
        // Determinar rareza (posibilidad de upgrade)
        Rarity childRarity = _determineChildRarity(parent1.rarity, parent2.rarity, randomSeed);
        
        // Determinar tipo (aleatorio entre los padres o híbrido)
        RobotType childType = _determineChildType(parent1.robotType, parent2.robotType, randomSeed);
        
        uint8 generation = (parent1.generation > parent2.generation ? parent1.generation : parent2.generation) + 1;
        uint16 efficiency = _calculateEfficiency(miningPower, battery, communication, storageCapacity, durability);
        
        return RobotAttributes({
            miningPower: miningPower,
            battery: battery,
            communication: communication,
            storageCapacity: storageCapacity,
            durability: durability,
            efficiency: efficiency,
            rarity: childRarity,
            robotType: childType,
            generation: generation,
            experience: 0,
            level: 1,
            isEvolved: false,
            birthTime: block.timestamp,
            lastMaintenance: block.timestamp
        });
    }
    
    /**
     * @dev Hereda un atributo específico
     */
    function _inheritAttribute(
        uint16 parent1Value,
        uint16 parent2Value,
        uint256 seed,
        uint256 salt
    ) internal pure returns (uint16) {
        uint256 average = (uint256(parent1Value) + uint256(parent2Value)) / 2;
        uint256 variation = uint256(keccak256(abi.encodePacked(seed, salt))) % 21; // 0-20%
        uint256 modifierValue = variation > 10 ? average * (variation - 10) / 100 : average * (10 - variation) / 100;
        
        if (variation > 10) {
            return uint16(average + modifierValue);
        } else {
            return uint16(average > modifierValue ? average - modifierValue : 1);
        }
    }
    
    /**
     * @dev Determina rareza del hijo
     */
    function _determineChildRarity(Rarity parent1Rarity, Rarity parent2Rarity, uint256 seed) internal pure returns (Rarity) {
        uint256 random = seed % 100;
        uint256 avgRarity = (uint256(parent1Rarity) + uint256(parent2Rarity)) / 2;
        
        // 70% probabilidad de rareza promedio, 20% de upgrade, 10% de downgrade
        if (random < 70) {
            return Rarity(avgRarity);
        } else if (random < 90 && avgRarity < 4) {
            return Rarity(avgRarity + 1); // Upgrade
        } else if (avgRarity > 0) {
            return Rarity(avgRarity - 1); // Downgrade
        }
        
        return Rarity(avgRarity);
    }
    
    /**
     * @dev Determina tipo del hijo
     */
    function _determineChildType(RobotType parent1Type, RobotType parent2Type, uint256 seed) internal pure returns (RobotType) {
        uint256 random = seed % 100;
        
        if (random < 40) {
            return parent1Type;
        } else if (random < 80) {
            return parent2Type;
        } else {
            return RobotType.Hybrid; // 20% chance de híbrido
        }
    }
    
    /**
     * @dev Añade experiencia a un robot (solo contrato del juego)
     */
    function addExperience(uint256 tokenId, uint256 experience) external onlyGameContract {
        require(_exists(tokenId), "MBN: Robot does not exist");
        
        RobotAttributes storage robot = robotAttributes[tokenId];
        robot.experience = uint32(robot.experience + experience);
        
        // Verificar level up
        uint8 newLevel = _calculateLevel(robot.experience);
        if (newLevel > robot.level) {
            robot.level = newLevel;
            _levelUpBonus(tokenId, uint256(newLevel));
        }
        
        emit ExperienceGained(tokenId, experience);
    }
    
    /**
     * @dev Calcula nivel basado en experiencia
     */
    function _calculateLevel(uint256 experience) internal pure returns (uint8) {
        if (experience < 1000) return 1;
        uint256 level = (experience / 1000) + 1;
        return uint8(level > 100 ? 100 : level);
    }
    
    /**
     * @dev Aplica bonificaciones por level up
     */
    function _levelUpBonus(uint256 tokenId, uint256 newLevel) internal {
        RobotAttributes storage robot = robotAttributes[tokenId];
        
        // Bonificación del 1% por nivel en todos los atributos
        uint256 bonus = newLevel;
        robot.miningPower = uint16(robot.miningPower * (100 + bonus) / 100);
        robot.battery = uint16(robot.battery * (100 + bonus) / 100);
        robot.communication = uint16(robot.communication * (100 + bonus) / 100);
        robot.storageCapacity = uint16(robot.storageCapacity * (100 + bonus) / 100);
        robot.durability = uint16(robot.durability * (100 + bonus) / 100);
        robot.efficiency = _calculateEfficiency(
            robot.miningPower,
            robot.battery,
            robot.communication,
            robot.storageCapacity,
            robot.durability
        );
    }
    
    /**
     * @dev Evoluciona un robot (mejora permanente)
     */
    function evolveRobot(uint256 tokenId) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "MBN: Not owner");
        
        RobotAttributes storage robot = robotAttributes[tokenId];
        require(!robot.isEvolved, "MBN: Already evolved");
        require(robot.level >= 50, "MBN: Minimum level 50 required");
        
        // Costo de evolución
        require(
            minerBotToken.transferFrom(msg.sender, address(this), evolutionCost),
            "MBN: Evolution cost transfer failed"
        );
        
        robot.isEvolved = true;
        
        // Bonificación de evolución (50% en todos los atributos)
        robot.miningPower = uint16(robot.miningPower * 150 / 100);
        robot.battery = uint16(robot.battery * 150 / 100);
        robot.communication = uint16(robot.communication * 150 / 100);
        robot.storageCapacity = uint16(robot.storageCapacity * 150 / 100);
        robot.durability = uint16(robot.durability * 150 / 100);
        robot.efficiency = _calculateEfficiency(
            robot.miningPower,
            robot.battery,
            robot.communication,
            robot.storageCapacity,
            robot.durability
        );
        
        emit RobotEvolved(tokenId, robot.level);
    }
    
    /**
     * @dev Realiza mantenimiento del robot
     */
    function performMaintenance(uint256 tokenId) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "MBN: Not owner");
        
        // Costo de mantenimiento
        require(
            minerBotToken.transferFrom(msg.sender, address(this), maintenanceCost),
            "MBN: Maintenance cost transfer failed"
        );
        
        RobotAttributes storage robot = robotAttributes[tokenId];
        robot.lastMaintenance = block.timestamp;
        
        // Restaurar durabilidad
        robot.durability = uint16(robot.durability * 110 / 100); // +10% durability
        if (robot.durability > 1000) robot.durability = 1000; // Cap a 1000
        
        emit MaintenancePerformed(tokenId, maintenanceCost);
    }
    
    /**
     * @dev Realiza mantenimiento del robot por parte del contrato de juego
     */
    function performMaintenanceByGame(uint256 tokenId, address robotOwner) external onlyGameContract nonReentrant {
        require(ownerOf(tokenId) == robotOwner, "MBN: Not owner");
        
        // Costo de mantenimiento
        require(
            minerBotToken.transferFrom(robotOwner, address(this), maintenanceCost),
            "MBN: Maintenance cost transfer failed"
        );
        
        RobotAttributes storage robot = robotAttributes[tokenId];
        robot.lastMaintenance = block.timestamp;
        
        // Restaurar durabilidad
        robot.durability = uint16(robot.durability * 110 / 100); // +10% durability
        if (robot.durability > 1000) robot.durability = 1000; // Cap a 1000
        
        emit MaintenancePerformed(tokenId, maintenanceCost);
    }
    
    /**
     * @dev Obtiene información completa de un robot
     */
    function getRobotInfo(uint256 tokenId) external view returns (RobotAttributes memory) {
        require(_exists(tokenId), "MBN: Robot does not exist");
        return robotAttributes[tokenId];
    }
    
    /**
     * @dev Obtiene robots de un propietario
     */
    function getRobotsByOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory robots = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            robots[i] = tokenOfOwnerByIndex(owner, i);
        }
        
        return robots;
    }
    
    /**
     * @dev Obtener el próximo token ID
     */
    function nextTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Obtener costo en MBT tokens para una rareza específica
     */
    function mintCostMBT(Rarity rarity) external view returns (uint256) {
        return mintCosts[rarity].tokenCost;
    }

    /**
     * @dev Obtener costo en ETH para una rareza específica
     */
    function mintCostETH(Rarity rarity) external view returns (uint256) {
        return mintCosts[rarity].ethCost;
    }

    /**
     * @dev Configuración del contrato del juego
     */
    function setGameContract(address _gameContract) external onlyOwner {
        gameContract = _gameContract;
    }
    
    /**
     * @dev Autorizar minters
     */
    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        authorizedMinters[minter] = authorized;
    }
    
    /**
     * @dev Actualizar costos de minting
     */
    function updateMintCost(Rarity rarity, uint256 tokenCost, uint256 ethCost) external onlyOwner {
        mintCosts[rarity] = MintCost(tokenCost, ethCost);
    }
    
    /**
     * @dev Pausar/despausar contrato
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Retirar fondos
     */
    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    function withdrawTokens(uint256 amount) external onlyOwner {
        minerBotToken.transfer(owner(), amount);
    }
    
    // Overrides requeridos
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        require(_exists(tokenId), "MBN: URI query for nonexistent token");
        
        RobotAttributes memory robot = robotAttributes[tokenId];
        
        // Generar metadata JSON
        string memory json = string(abi.encodePacked(
            '{',
            '"name": "MinerBot #', _toString(tokenId), '",',
            '"description": "A powerful mining robot from the MinerBot Empire",',
            '"attributes": [',
            '{"trait_type": "Type", "value": "', _getRobotTypeName(robot.robotType), '"},',
            '{"trait_type": "Rarity", "value": "', _getRarityName(robot.rarity), '"},',
            '{"trait_type": "Level", "value": ', _toString(robot.level), '},',
            '{"trait_type": "Mining Power", "value": ', _toString(robot.miningPower), '},',
            '{"trait_type": "Battery", "value": ', _toString(robot.battery), '},',
            '{"trait_type": "Communication", "value": ', _toString(robot.communication), '},',
            '{"trait_type": "Storage Capacity", "value": ', _toString(robot.storageCapacity), '},',
            '{"trait_type": "Durability", "value": ', _toString(robot.durability), '},',
            '{"trait_type": "Efficiency", "value": ', _toString(robot.efficiency), '},',
            '{"trait_type": "Experience", "value": ', _toString(robot.experience), '}',
            ']',
            '}'
        ));
        
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _base64Encode(bytes(json))
        ));
    }
    
    function _getRobotTypeName(RobotType robotType) internal pure returns (string memory) {
        if (robotType == RobotType.Excavator) return "Excavator";
        if (robotType == RobotType.Processor) return "Processor";
        if (robotType == RobotType.Scanner) return "Scanner";
        if (robotType == RobotType.Communicator) return "Communicator";
        if (robotType == RobotType.Hybrid) return "Hybrid";
        return "Unknown";
    }
    
    function _getRarityName(Rarity rarity) internal pure returns (string memory) {
        if (rarity == Rarity.Common) return "Common";
        if (rarity == Rarity.Uncommon) return "Uncommon";
        if (rarity == Rarity.Rare) return "Rare";
        if (rarity == Rarity.Epic) return "Epic";
        if (rarity == Rarity.Legendary) return "Legendary";
        return "Unknown";
    }
    
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    
    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";
        
        string memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        bytes memory result = new bytes(4 * ((data.length + 2) / 3));
        
        uint256 i = 0;
        uint256 j = 0;
        
        for (; i + 3 <= data.length; i += 3) {
            uint256 a = uint256(uint8(data[i]));
            uint256 b = uint256(uint8(data[i + 1]));
            uint256 c = uint256(uint8(data[i + 2]));
            
            uint256 bitmap = (a << 16) | (b << 8) | c;
            
            result[j++] = bytes(table)[(bitmap >> 18) & 63];
            result[j++] = bytes(table)[(bitmap >> 12) & 63];
            result[j++] = bytes(table)[(bitmap >> 6) & 63];
            result[j++] = bytes(table)[bitmap & 63];
        }
        
        if (data.length % 3 == 1) {
            uint256 a = uint256(uint8(data[i]));
            uint256 bitmap = a << 16;
            
            result[j++] = bytes(table)[(bitmap >> 18) & 63];
            result[j++] = bytes(table)[(bitmap >> 12) & 63];
            result[j++] = "=";
            result[j++] = "=";
        } else if (data.length % 3 == 2) {
            uint256 a = uint256(uint8(data[i]));
            uint256 b = uint256(uint8(data[i + 1]));
            uint256 bitmap = (a << 16) | (b << 8);
            
            result[j++] = bytes(table)[(bitmap >> 18) & 63];
            result[j++] = bytes(table)[(bitmap >> 12) & 63];
            result[j++] = bytes(table)[(bitmap >> 6) & 63];
            result[j++] = "=";
        }
        
        return string(result);
    }
    
    /**
     * @dev Calcula la experiencia requerida para un nivel específico
     */
    function getExperienceRequired(uint256 level) external pure returns (uint256) {
        if (level <= 1) return 0;
        if (level == 2) return 1000;
        if (level == 3) return 2500;
        return (level - 1) * (level - 1) * 500;
    }
    
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}