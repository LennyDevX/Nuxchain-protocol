// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/IStakingIntegration.sol";

/**
 * @title GameifiedMarketplaceSkills
 * @dev Sistema de Skills NFTs optimizado
 * - Crear NFTs con skills desde IStakingIntegration
 * - Gestionar rarezas y tipos
 * - Validación de skills con expiraciones
 * - Anti-abuse: máximo 3 skills activos, una por tipo por usuario
 */

interface IGameifiedMarketplaceCore {
    function createStandardNFT(
        string calldata _tokenURI,
        string calldata _category,
        uint96 _royaltyPercentage
    ) external returns (uint256);
    
    function updateUserXP(address _user, uint256 _amount) external;
}

contract GameifiedMarketplaceSkills is AccessControl, Pausable {
    using Counters for Counters.Counter;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // ✅ Usar tipos de IStakingIntegration para sincronización correcta
    struct Skill {
        IStakingIntegration.SkillType skillType;
        IStakingIntegration.Rarity rarity;
        uint256 level;
        uint256 createdAt;
        uint256 expiresAt;      // ✅ NUEVO: Expiración de skill (30 días)
    }
    
    struct SkillNFT {
        address creator;
        Skill[] skills;
        uint256 createdAt;
        uint256 basePrice;
    }
    
    Counters.Counter private _skillNFTCounter;
    
    // ✅ NUEVO: Máximo de skills activos simultáneos por usuario
    uint256 private constant MAX_ACTIVE_SKILLS_PER_USER = 3;
    uint256 private constant SKILL_DURATION = 30 days;
    
    // ✅ NUEVO: Track active skills per user per type (usando SkillType de IStakingIntegration)
    mapping(address => mapping(IStakingIntegration.SkillType => uint256)) public userActiveSkillsByType;
    mapping(address => mapping(IStakingIntegration.SkillType => uint256)) public userSkillNFTId;
    
    mapping(uint256 => SkillNFT) public skillNFTs;
    mapping(address => uint256[]) public userSkillNFTs;
    mapping(IStakingIntegration.SkillType => uint256) public skillTypeCount;
    mapping(uint256 => bool) public isFirstSkillFree;
    
    address public coreContractAddress;
    address public stakingContractAddress;
    
    event SkillNFTCreated(
        address indexed creator,
        uint256 indexed tokenId,
        uint256 skillCount,
        uint256 totalXP
    );
    event SkillAdded(uint256 indexed tokenId, IStakingIntegration.SkillType skillType, IStakingIntegration.Rarity rarity);
    event SkillExpired(address indexed user, uint256 indexed tokenId, IStakingIntegration.SkillType skillType);
    event SkillRenewed(address indexed user, uint256 indexed tokenId, uint256 newExpiryTime);
    event SkillTypeAlreadyActive(address indexed user, IStakingIntegration.SkillType skillType);
    event SkillSwitched(
        address indexed user,
        uint256 indexed oldTokenId,
        uint256 indexed newTokenId,
        IStakingIntegration.SkillType skillType,
        uint256 switchFee
    );
    event SkillDeactivatedManually(
        address indexed user,
        uint256 indexed tokenId,
        IStakingIntegration.SkillType skillType
    );

    error InvalidSkillCount();
    error InvalidSkillType();
    error CoreContractNotSet();
    error SkillTypeAlreadyActiveDuplicate(IStakingIntegration.SkillType skillType);
    error MaxActiveSkillsReached();
    error SkillNotExpiredYet(uint256 expiryTime);
    error NotSkillOwner();

    constructor(address _coreAddress) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        coreContractAddress = _coreAddress;
    }

    /**
     * @dev Registrar skills a un NFT existente
     */
    function registerSkillsForNFT(
        uint256 _tokenId,
        IStakingIntegration.SkillType[] calldata _skillTypes,
        IStakingIntegration.Rarity[] calldata _rarities,
        uint256[] calldata _levels,
        uint256 _basePrice
    ) external whenNotPaused returns (uint256) {
        require(coreContractAddress != address(0), "Core not set");
        require(_skillTypes.length > 0 && _skillTypes.length <= 5, "Invalid skill count");
        require(_skillTypes.length == _rarities.length, "Length mismatch");
        require(_skillTypes.length == _levels.length, "Length mismatch");
        
        // ✅ NUEVO: Validar límite de skills activos
        uint256 activeSkillsCount = 0;
        for (uint256 k = 0; k < userSkillNFTs[msg.sender].length; k++) {
            if (block.timestamp < _getSkillExpiryTime(userSkillNFTs[msg.sender][k])) {
                activeSkillsCount++;
            }
        }
        require(activeSkillsCount < MAX_ACTIVE_SKILLS_PER_USER, "Max active skills reached");
        
        // Validar que no hay skill types repetidos
        for (uint256 i = 0; i < _skillTypes.length; i++) {
            for (uint256 j = i + 1; j < _skillTypes.length; j++) {
                require(_skillTypes[i] != _skillTypes[j], "Duplicate skill type");
            }
            require(uint256(_skillTypes[i]) < 21, "Invalid skill type");
            
            // ✅ NUEVO: Validar que no tenga este tipo de skill activo
            if (userActiveSkillsByType[msg.sender][_skillTypes[i]] != 0) {
                emit SkillTypeAlreadyActive(msg.sender, _skillTypes[i]);
                revert SkillTypeAlreadyActiveDuplicate(_skillTypes[i]);
            }
        }
        
        SkillNFT storage nft = skillNFTs[_tokenId];
        nft.creator = msg.sender;
        nft.createdAt = block.timestamp;
        nft.basePrice = _basePrice;
        
        uint256 totalXP = 0;
        uint256 expiryTime = block.timestamp + SKILL_DURATION;
        
        for (uint256 i = 0; i < _skillTypes.length; i++) {
            Skill memory skill = Skill({
                skillType: _skillTypes[i],
                rarity: _rarities[i],
                level: _levels[i],
                createdAt: block.timestamp,
                expiresAt: expiryTime  // ✅ NUEVO: Expiración
            });
            
            nft.skills.push(skill);
            skillTypeCount[_skillTypes[i]]++;
            
            // ✅ NUEVO: Registrar skill activo por tipo
            userActiveSkillsByType[msg.sender][_skillTypes[i]] = _tokenId;
            userSkillNFTId[msg.sender][_skillTypes[i]] = _tokenId;
            
            // Primera skill gratis, resto con costo
            if (i == 0) {
                isFirstSkillFree[_tokenId] = true;
                totalXP += 15;
            } else {
                totalXP += 10 + (uint256(_rarities[i]) * 5);
            }
            
            emit SkillAdded(_tokenId, _skillTypes[i], _rarities[i]);
        }
        
        userSkillNFTs[msg.sender].push(_tokenId);
        
        // Otorgar XP por agregar skills
        IGameifiedMarketplaceCore(coreContractAddress).updateUserXP(msg.sender, totalXP);
        
        // Notificar al staking sobre las skills activadas
        if (stakingContractAddress != address(0)) {
            for (uint256 i = 0; i < _skillTypes.length; i++) {
                uint16 skillValue = uint16(5 + (uint256(_rarities[i]) * 2));
                IStakingIntegration(stakingContractAddress).notifySkillActivation(
                    msg.sender,
                    _tokenId,
                    IStakingIntegration.SkillType(uint256(_skillTypes[i])),
                    skillValue
                );
            }
        }
        
        emit SkillNFTCreated(msg.sender, _tokenId, _skillTypes.length, totalXP);
        return _tokenId;
    }
    
    // ✅ NUEVO: Helper function para obtener tiempo de expiración
    function _getSkillExpiryTime(uint256 _tokenId) private view returns (uint256) {
        SkillNFT storage nft = skillNFTs[_tokenId];
        if (nft.skills.length == 0) return 0;
        return nft.skills[0].expiresAt;
    }
    
    // ✅ NUEVO: Deactivate expired skills
    function deactivateExpiredSkill(uint256 _tokenId) external {
        SkillNFT storage nft = skillNFTs[_tokenId];
        require(nft.creator != address(0), "Skill NFT not found");
        
        uint256 expiryTime = _getSkillExpiryTime(_tokenId);
        require(block.timestamp >= expiryTime, "Skill still active");
        
        // Limpiar tracking para cada skill
        for (uint256 i = 0; i < nft.skills.length; i++) {
            IStakingIntegration.SkillType skillType = nft.skills[i].skillType;
            
            if (userActiveSkillsByType[nft.creator][skillType] == _tokenId) {
                userActiveSkillsByType[nft.creator][skillType] = 0;
                userSkillNFTId[nft.creator][skillType] = 0;
            }
            
            emit SkillExpired(nft.creator, _tokenId, skillType);
        }
    }
    
    // ✅ NUEVO: Renew expired skill
    function renewSkill(uint256 _tokenId) external payable whenNotPaused {
        SkillNFT storage nft = skillNFTs[_tokenId];
        require(nft.creator == msg.sender, "Not owner");
        
        uint256 expiryTime = _getSkillExpiryTime(_tokenId);
        require(block.timestamp >= expiryTime, "Skill still active");
        
        // Verificar pago
        uint256 renewalPrice = nft.basePrice / 2;
        require(msg.value >= renewalPrice, "Insufficient payment");
        
        // Renovar expiración
        uint256 newExpiryTime = block.timestamp + SKILL_DURATION;
        for (uint256 i = 0; i < nft.skills.length; i++) {
            nft.skills[i].expiresAt = newExpiryTime;
        }
        
        // Re-activar en staking
        if (stakingContractAddress != address(0)) {
            for (uint256 i = 0; i < nft.skills.length; i++) {
                uint16 skillValue = uint16(5 + (uint256(nft.skills[i].rarity) * 2));
                IStakingIntegration(stakingContractAddress).notifySkillActivation(
                    msg.sender,
                    _tokenId,
                    IStakingIntegration.SkillType(uint256(nft.skills[i].skillType)),
                    skillValue
                );
            }
        }
        
        emit SkillRenewed(msg.sender, _tokenId, newExpiryTime);
    }
    
    // ✅ NUEVO: Check if skill is expired
    function isSkillExpired(uint256 _tokenId) external view returns (bool) {
        uint256 expiryTime = _getSkillExpiryTime(_tokenId);
        return block.timestamp >= expiryTime;
    }
    
    // ✅ NUEVO: Get skill expiry time
    function getSkillExpiryTime(uint256 _tokenId) external view returns (uint256) {
        return _getSkillExpiryTime(_tokenId);
    }
    
    // ✅ NUEVO: Get active skills for user
    function getActiveSkillsForUser(address _user) external view returns (uint256[] memory) {
        uint256[] memory allSkills = userSkillNFTs[_user];
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < allSkills.length; i++) {
            if (block.timestamp < _getSkillExpiryTime(allSkills[i])) {
                activeCount++;
            }
        }
        
        uint256[] memory activeSkills = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allSkills.length; i++) {
            if (block.timestamp < _getSkillExpiryTime(allSkills[i])) {
                activeSkills[index] = allSkills[i];
                index++;
            }
        }
        
        return activeSkills;
    }

    /**
     * @dev Obtener skills de un NFT
     */
    function getSkillNFTSkills(uint256 _tokenId) external view returns (Skill[] memory) {
        return skillNFTs[_tokenId].skills;
    }

    /**
     * @dev Obtener información de Skill NFT
     */
    function getSkillNFT(uint256 _tokenId) external view returns (SkillNFT memory) {
        return skillNFTs[_tokenId];
    }

    /**
     * @dev Obtener skill NFTs del usuario
     */
    function getUserSkillNFTs(address _user) external view returns (uint256[] memory) {
        return userSkillNFTs[_user];
    }

    /**
     * @dev Obtener conteo de skill types
     */
    function getSkillTypeCount(IStakingIntegration.SkillType _skillType) external view returns (uint256) {
        return skillTypeCount[_skillType];
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
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ✨ NUEVO: SISTEMA DE CAMBIO DE SKILLS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Cambiar skill activo instantáneamente pagando una tarifa
     * @param _oldTokenId NFT con skill activo a deactivar
     * @param _newTokenId NFT con skill a activar
     * @param _skillType Tipo de skill a cambiar
     * 
     * Costo: 25% del precio original del skill
     * Instanciación: Inmediata
     * Sincronización: Staking notificado del cambio
     */
    function switchSkill(
        uint256 _oldTokenId,
        uint256 _newTokenId,
        IStakingIntegration.SkillType _skillType
    ) external payable whenNotPaused {
        // 1. Validar propietario de ambos NFTs
        SkillNFT storage oldNFT = skillNFTs[_oldTokenId];
        SkillNFT storage newNFT = skillNFTs[_newTokenId];
        
        require(oldNFT.creator == msg.sender, "Not owner of old NFT");
        require(newNFT.creator == msg.sender, "Not owner of new NFT");
        
        // 2. Validar que ambos tienen el skill type
        bool oldHasSkill = false;
        bool newHasSkill = false;
        IStakingIntegration.Rarity oldRarity;
        IStakingIntegration.Rarity newRarity;
        
        for (uint256 i = 0; i < oldNFT.skills.length; i++) {
            if (oldNFT.skills[i].skillType == _skillType) {
                oldHasSkill = true;
                oldRarity = oldNFT.skills[i].rarity;
                break;
            }
        }
        
        for (uint256 i = 0; i < newNFT.skills.length; i++) {
            if (newNFT.skills[i].skillType == _skillType) {
                newHasSkill = true;
                newRarity = newNFT.skills[i].rarity;
                break;
            }
        }
        
        require(oldHasSkill, "Old NFT doesn't have this skill");
        require(newHasSkill, "New NFT doesn't have this skill");
        
        // 3. Validar que el viejo está activo
        require(
            userActiveSkillsByType[msg.sender][_skillType] == _oldTokenId,
            "Skill not active in old NFT"
        );
        
        // 4. Validar que el nuevo no está expirado
        require(
            block.timestamp < _getSkillExpiryTime(_newTokenId),
            "New skill has expired"
        );
        
        // 5. Verificar pago (25% del precio original)
        uint256 switchPrice = oldNFT.basePrice / 4;
        require(msg.value >= switchPrice, "Insufficient payment for switch");
        
        // 6. DEACTIVAR skill anterior en Staking
        if (stakingContractAddress != address(0)) {
            IStakingIntegration(stakingContractAddress).notifySkillDeactivation(
                msg.sender,
                _oldTokenId
            );
        }
        
        // 7. ACTIVAR nuevo skill en Staking
        if (stakingContractAddress != address(0)) {
            uint16 skillValue = uint16(5 + (uint256(newRarity) * 2));
            IStakingIntegration(stakingContractAddress).notifySkillActivation(
                msg.sender,
                _newTokenId,
                _skillType,
                skillValue
            );
        }
        
        // 8. Actualizar mappings
        userActiveSkillsByType[msg.sender][_skillType] = _newTokenId;
        userSkillNFTId[msg.sender][_skillType] = _newTokenId;
        
        // 9. Transferir fee al core (treasury)
        if (msg.value > 0) {
            payable(coreContractAddress).transfer(msg.value);
        }
        
        // 10. Emit evento
        emit SkillSwitched(
            msg.sender,
            _oldTokenId,
            _newTokenId,
            _skillType,
            switchPrice
        );
    }
    
    /**
     * @dev Deactivar skill manualmente (sin esperar expiración)
     * @param _tokenId NFT con skill a deactivar
     * @param _skillType Tipo de skill a deactivar
     * 
     * Uso: Liberar slot para activar otro skill
     * Costo: Gratis (pero revoca multiplicador del staking)
     */
    function deactivateSkillManually(
        uint256 _tokenId,
        IStakingIntegration.SkillType _skillType
    ) external whenNotPaused {
        SkillNFT storage nft = skillNFTs[_tokenId];
        require(nft.creator == msg.sender, "Not owner");
        
        // Validar que está activo
        require(
            userActiveSkillsByType[msg.sender][_skillType] == _tokenId,
            "Skill not active"
        );
        
        // Encontrar y validar el skill
        bool found = false;
        for (uint256 i = 0; i < nft.skills.length; i++) {
            if (nft.skills[i].skillType == _skillType) {
                found = true;
                break;
            }
        }
        require(found, "Skill not found in NFT");
        
        // Notificar Staking de deactivación
        if (stakingContractAddress != address(0)) {
            IStakingIntegration(stakingContractAddress).notifySkillDeactivation(
                msg.sender,
                _tokenId
            );
        }
        
        // Actualizar mappings
        userActiveSkillsByType[msg.sender][_skillType] = 0;
        userSkillNFTId[msg.sender][_skillType] = 0;
        
        // Emit evento
        emit SkillDeactivatedManually(msg.sender, _tokenId, _skillType);
    }
    
    /**
     * @dev Obtener información de skill switching para un usuario
     * @param _user Dirección del usuario
     * @param _skillType Tipo de skill a consultar
     * @return activeTokenId Token ID del skill activo (0 si inactivo)
     * @return expiresAt Timestamp de expiración
     * @return canSwitch Puede cambiar a otro (hay candidatos)?
     */
    function getSkillSwitchInfo(
        address _user,
        IStakingIntegration.SkillType _skillType
    ) external view returns (
        uint256 activeTokenId,
        uint256 expiresAt,
        bool canSwitch
    ) {
        activeTokenId = userActiveSkillsByType[_user][_skillType];
        
        if (activeTokenId == 0) {
            return (0, 0, true); // No hay activo, puede activar
        }
        
        expiresAt = _getSkillExpiryTime(activeTokenId);
        
        // Chequear si hay otros NFTs con este skill type disponibles
        uint256[] memory allSkills = userSkillNFTs[_user];
        for (uint256 i = 0; i < allSkills.length; i++) {
            if (allSkills[i] != activeTokenId) {
                SkillNFT storage nft = skillNFTs[allSkills[i]];
                for (uint256 j = 0; j < nft.skills.length; j++) {
                    if (nft.skills[j].skillType == _skillType) {
                        if (block.timestamp < _getSkillExpiryTime(allSkills[i])) {
                            canSwitch = true;
                            break;
                        }
                    }
                }
                if (canSwitch) break;
            }
        }
    }
    
    /**
     * @dev Obtener todos los skills del tipo especificado que posee el usuario
     * @param _user Dirección del usuario
     * @param _skillType Tipo de skill a buscar
     * @return tokenIds Array de NFT IDs que contienen este skill type
     * @return statuses Array con estados: 0=activo, 1=inactivo, 2=expirado
     */
    function getUserSkillsByType(
        address _user,
        IStakingIntegration.SkillType _skillType
    ) external view returns (
        uint256[] memory tokenIds,
        uint8[] memory statuses
    ) {
        uint256[] memory allSkills = userSkillNFTs[_user];
        uint256 count = 0;
        
        // Contar cuántos tienen este skill type
        for (uint256 i = 0; i < allSkills.length; i++) {
            SkillNFT storage nft = skillNFTs[allSkills[i]];
            for (uint256 j = 0; j < nft.skills.length; j++) {
                if (nft.skills[j].skillType == _skillType) {
                    count++;
                    break;
                }
            }
        }
        
        // Construir arrays
        tokenIds = new uint256[](count);
        statuses = new uint8[](count);
        uint256 index = 0;
        uint256 activeToken = userActiveSkillsByType[_user][_skillType];
        
        for (uint256 i = 0; i < allSkills.length; i++) {
            SkillNFT storage nft = skillNFTs[allSkills[i]];
            bool found = false;
            
            for (uint256 j = 0; j < nft.skills.length; j++) {
                if (nft.skills[j].skillType == _skillType) {
                    found = true;
                    break;
                }
            }
            
            if (found) {
                tokenIds[index] = allSkills[i];
                
                if (allSkills[i] == activeToken) {
                    statuses[index] = 0; // Activo
                } else if (block.timestamp >= _getSkillExpiryTime(allSkills[i])) {
                    statuses[index] = 2; // Expirado
                } else {
                    statuses[index] = 1; // Inactivo disponible
                }
                
                index++;
            }
        }
    }
}
