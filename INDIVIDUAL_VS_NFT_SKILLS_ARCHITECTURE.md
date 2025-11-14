# Individual Skills vs NFT Skills Architecture

## Executive Summary

Existen **DOS sistemas de skills completamente independientes y diferentes**:

1. **IndividualSkillsMarketplace** - Skills individuales sin NFT (acceso flexible)
2. **GameifiedMarketplaceSkillsV2** - Skills embebidas en NFTs (acceso restringido)

Cada sistema tiene sus propias reglas, precios, y mecanismos de activación.

---

## System 1: IndividualSkillsMarketplace

### Propósito
- Compra de **skills individuales SIN necesidad de minting NFT**
- Sistema más flexible y accesible
- Enfoque en accesibilidad directa a bonificadores

### Modelo de Acceso

#### COMPRA (purchaseIndividualSkill)
```
✅ FLEXIBLE - SIN requisitos de staking
- Cualquier usuario puede comprar
- NO necesita 250 POL en staking
- Paga el precio del skill + rarity
- Recibe un skillId (no NFT)
```

#### ACTIVACIÓN (activateIndividualSkill)
```
✅ REQUIERE 250 POL en staking
- Solo usuarios con 250+ POL stakeados pueden ACTIVAR
- Una vez activados, el skill da bonificaciones
- Máximo 3 skills activos por tipo
- 30 días de validez, luego expira
```

### Precios Fijos (POL)

| Rarity     | Staking Skills | Active Skills |
|------------|---|---|
| COMMON     | 50 | 65 |
| UNCOMMON   | 80 | 104 |
| RARE       | 100 | 130 |
| EPIC       | 150 | 195 |
| LEGENDARY  | 220 | 286 |

**Markup:** Active skills tienen +30% sobre staking skills

### Storage
```solidity
mapping(skillType => mapping(rarity => uint256)) skillPrices;
```

### Key Functions
```solidity
// COMPRA - Sin staking required
purchaseIndividualSkill(skillType, rarity, level, metadata) 
  → returns skillId

// ACTIVACIÓN - Requiere 250 POL en staking
activateIndividualSkill(skillId)
  → Skills activos dan bonificaciones

// RENOVACIÓN - 50% del precio original
renewIndividualSkill(skillId)
  → Extiende validez 30 días más

// TRANSFER - Enviar skills entre wallets
transferIndividualSkill(skillId, recipient)
  → No puede transferirse si está activo

// ADMIN - Actualizar precios (sin redeployment)
updateSkillPrice(skillType, rarity, newPrice)
updateStakingSkillsPricing(common, uncommon, rare, epic, legendary)
updateActiveSkillsPricing(common, uncommon, rare, epic, legendary)
```

### Flow de Uso
```
1. Usuario sin staking → Compra skill (✓ permitido)
   └─ Se convierte en "propietario inactivo"

2. Usuario deposita 250 POL en staking

3. Usuario activa el skill (✓ ahora es permitido)
   └─ Skill comienza a dar bonificaciones

4. 30 días después → Skill expira

5. Usuario renueva (50% del precio) o compra otro
```

---

## System 2: GameifiedMarketplaceSkillsV2

### Propósito
- Skills **embebidas directamente en NFTs** de marketplace
- Sistema más restrictivo para coleccionables premium
- Enfoque en NFTs con múltiples skills integrados

### Modelo de Acceso

#### CREACIÓN NFT CON SKILLS (registerSkillsForNFT)
```
✅ REQUIERE 250 POL en staking (desde inicio)
- Solo usuarios con 250+ POL pueden registrar skills en NFT
- Máximo 5 skills por NFT
- Se minta/actualiza directamente en NFT
- Primera skill es GRATIS (en XP)
```

#### CARACTERÍSTICAS
```solidity
struct SkillNFT {
    address creator;
    Skill[] skills;           // Array de hasta 5 skills
    uint256 createdAt;
    uint256 basePrice;        // Precio base del NFT
}

struct Skill {
    SkillType skillType;
    Rarity rarity;
    uint256 level;
    uint256 createdAt;
    uint256 expiresAt;        // 30 días
}
```

### Storage
```solidity
mapping(tokenId => SkillNFT) skillNFTs;
mapping(address => uint256[]) userSkillNFTs;
mapping(skillType => uint256) skillTypeCount;
```

### Key Functions
```solidity
// REGISTRO - Crear/actualizar NFT con skills (Requiere 250 POL)
registerSkillsForNFT(
  tokenId,
  skillTypes[],
  rarities[],
  levels[],
  basePrice
)
  → Embebe skills en NFT

// RENOVACIÓN - 50% del precio base
renewSkill(tokenId)
  → Extiende todos los skills 30 días más

// CAMBIO DE SKILL - Cambiar skill entre NFTs (costo 25%)
switchSkill(oldTokenId, newTokenId, skillType)
  → Cambia el skill activo a otro NFT

// DEACTIVACIÓN - Apagar skill manualmente
deactivateSkillManually(tokenId, skillType)
  → Desactiva un skill específico del NFT

// CONSULTAS
getSkillNFT(tokenId) → SkillNFT completo
getSkillNFTSkills(tokenId) → Array de skills
getUserSkillNFTs(user) → Array de tokenIds
```

### Flow de Uso
```
1. Usuario tiene 250+ POL en staking (✓ requerido)

2. Usuario llama registerSkillsForNFT
   └─ Especifica 1-5 skills para embeberlos en NFT
   └─ Primera skill = GRATIS en XP (15 XP)
   └─ Resto = 10 + (rarity × 5) XP, máx 50 por skill

3. NFT ahora tiene skills embebidos
   └─ Puede tener MAX_ACTIVE_SKILLS_PER_USER (3) NFTs

4. 30 días después → Skills expiran

5. Usuario renueva (50% del basePrice) o cambia skills
   └─ switchSkill = 25% del basePrice
```

---

## Comparativa Técnica

| Aspecto | Individual Skills | NFT Skills |
|--------|---|---|
| **Requisito Compra** | ✅ NO | ❌ SÍ (250 POL) |
| **Requisito Activación** | ✅ SÍ (250 POL) | ❌ N/A |
| **Cantidad por Tx** | 1 skill | 1-5 skills/NFT |
| **Storage** | skillId (simple) | NFT embebido |
| **Max Activos** | 3 por tipo | 3 NFTs totales |
| **Transferible** | Sí (si inactivo) | Sí (si es NFT) |
| **Precio** | Dinámico por skill | Basado en NFT |
| **XP Reward** | Integrado | 15 (1ero) + resto |
| **Renovación** | 50% skill | 50% NFT base |

---

## Arquitectura de Datos

### IndividualSkillsMarketplace
```solidity
// 1D Mapping: skillId → IndividualSkill
mapping(uint256 => IndividualSkill) individualSkills;

// Nested: user → skillType → [activeIds]
mapping(address => mapping(SkillType => uint256[])) userActiveSkills;

// 2D Pricing: skillType → rarity → price
mapping(SkillType => mapping(Rarity => uint256)) skillPrices;
```

### GameifiedMarketplaceSkillsV2
```solidity
// 1D Mapping: tokenId → SkillNFT
mapping(uint256 => SkillNFT) skillNFTs;

// user → skillType → tokenId (only 1 per type)
mapping(address => mapping(SkillType => uint256)) userActiveSkillsByType;

// Global counter para skill types
mapping(SkillType => uint256) skillTypeCount;
```

---

## Diferencias en Validación de Staking

### IndividualSkillsMarketplace
```solidity
function purchaseIndividualSkill(...) {
    // ✅ NO hay _validateStakingRequirement aquí
    // Cualquiera puede comprar
}

function activateIndividualSkill(...) {
    // ✅ SÍ hay _validateStakingRequirement aquí
    // Solo con 250+ POL pueden activar
    _validateStakingRequirement(msg.sender);
}
```

### GameifiedMarketplaceSkillsV2
```solidity
function registerSkillsForNFT(...) {
    // ✅ SÍ requiere staking desde el inicio
    try IEnhancedSmartStaking(stakingContractAddress)
        .getTotalDeposit(msg.sender) returns (uint256 totalDeposit) {
        if (totalDeposit < MIN_STAKING_REQUIREMENT) {
            revert InsufficientStakingBalance(...);
        }
    }
}
```

---

## Casos de Uso

### Use Case 1: Usuario Casual (sin staking)
```
❌ NO PUEDE usar GameifiedMarketplaceSkillsV2

✅ PUEDE usar IndividualSkillsMarketplace:
   1. Compra skill (50 POL COMMON)
   2. Lo guarda pero NO lo activa
   3. Luego deposita 250 POL en staking
   4. Activa el skill y recibe bonificadores
```

### Use Case 2: Usuario Premium (con 250+ POL staked)
```
✅ PUEDE usar ambos sistemas:

GameifiedMarketplaceSkillsV2:
   1. Registra 3-5 skills en NFT
   2. Obtiene XP inmediato
   3. NFT con skills embebidos

IndividualSkillsMarketplace:
   1. Compra skills adicionales (sin staking req)
   2. Activa algunos inmediatamente
   3. Guarda otros para después
```

### Use Case 3: Flipper/Trader
```
IndividualSkillsMarketplace:
   1. Compra skills baratos
   2. NO los activa
   3. Los transfiere a otras wallets
   4. Gana spread en la venta

GameifiedMarketplaceSkillsV2:
   1. NO es posible "flippear" directamente
   2. Skills están embebidos en NFT
   3. Debe tener staking para registrar
```

---

## Flujo de Integración con Staking

```
┌─────────────────────────────────────────┐
│  EnhancedSmartStaking (250+ POL check)  │
└─────────────────────────┬───────────────┘
                          │
        ┌─────────────────┴──────────────────┐
        │                                     │
        ▼                                     ▼
┌──────────────────────┐        ┌──────────────────────┐
│ IndividualSkills     │        │ GameifiedMarketplace │
│ - Sin req en compra  │        │ - Req en registro    │
│ - Req en activación  │        │ - Max 3 NFTs activos │
│ - Max 3 por tipo     │        │ - Skills embebidos   │
└──────────────────────┘        └──────────────────────┘
        │                                     │
        └─────────────────┬──────────────────┘
                          │
        ┌─────────────────▼──────────────────┐
        │   notifySkillActivation(user)      │
        │   notifySkillDeactivation(user)    │
        └───────────────────────────────────┘
```

---

## Actualización de Precios

### IndividualSkillsMarketplace (Flexible)
```javascript
// Cambiar precio de 1 skill
await marketplace.updateSkillPrice(
  SkillType.STAKE_BOOST_I,
  Rarity.LEGENDARY,
  ethers.parseEther("250")  // Nuevo precio
);

// Cambiar todos los staking skills
await marketplace.updateStakingSkillsPricing(
  ethers.parseEther("60"),   // COMMON
  ethers.parseEther("96"),   // UNCOMMON
  ethers.parseEther("120"),  // RARE
  ethers.parseEther("180"),  // EPIC
  ethers.parseEther("264")   // LEGENDARY
);
```

### GameifiedMarketplaceSkillsV2 (Fijo en NFT)
```
No hay función de cambio de precios.
El precio está en: basePrice del NFT
La renovación siempre es: 50% de basePrice
El cambio siempre es: 25% de basePrice
```

---

## Seguridad y Reentrancia

### IndividualSkillsMarketplace
```solidity
nonReentrant
→ purchaseIndividualSkill
→ renewIndividualSkill
```

### GameifiedMarketplaceSkillsV2
```solidity
nonReentrant
→ registerSkillsForNFT
→ renewSkill
→ switchSkill
```

Ambos usan **CEI Pattern** (Checks → Effects → Interactions).

---

## Recomendaciones de Uso Frontend

### Mostrar IndividualSkillsMarketplace CUANDO:
- ✅ Usuario sin staking (solo mostrar compra)
- ✅ Usuario con staking (mostrar compra + activación)
- ✅ Usuario quiere skills "sueltos"
- ✅ Usuario quiere coleccionar múltiples de un tipo

### Mostrar GameifiedMarketplaceSkillsV2 CUANDO:
- ✅ Usuario tiene 250+ POL en staking
- ✅ Usuario quiere NFT con múltiples skills
- ✅ Usuario quiere "embebereds" permanentes
- ✅ Usuario quiere flujo de XP inmediato

### Deshabilitar GameifiedMarketplaceSkillsV2 CUANDO:
- ❌ Usuario tiene < 250 POL en staking
- ❌ Usuario ya tiene 3 NFT skills activos
- ❌ Usuario no tiene 250 POL en el momento de registro

---

## Eventos para Monitoreo

### IndividualSkillsMarketplace
```solidity
event IndividualSkillPurchased(user, skillId, skillType, rarity, price)
event IndividualSkillActivated(user, skillId, skillType)
event IndividualSkillDeactivated(user, skillId, skillType)
event IndividualSkillRenewed(user, skillId, expiresAt)
event IndividualSkillTransferred(from, to, skillId, skillType)
event SkillPricingUpdated(skillType, price, rarity)
```

### GameifiedMarketplaceSkillsV2
```solidity
event SkillNFTCreated(creator, tokenId, skillCount, totalXP)
event SkillAdded(tokenId, skillType, rarity)
event SkillRenewed(user, tokenId, newExpiryTime)
event SkillSwitched(user, oldTokenId, newTokenId, skillType, fee)
event SkillDeactivatedManually(user, tokenId, skillType)
```

---

## Summary Table

| Característica | IndividualSkills | GameifiedMarketplaceV2 |
|---|---|---|
| **Acceso sin staking** | ✅ Compra libre | ❌ Requiere 250 POL |
| **Acceso con staking** | ✅ Activación+bonos | ✅ Registro+embebido |
| **Skills por TX** | 1 | 1-5 |
| **Transferible** | Sí | Sí (como NFT) |
| **Precios actualizables** | ✅ Sí (admin) | ❌ Fijo |
| **Renovación** | 50% skill | 50% NFT |
| **XP Reward** | Integrado | 15+10+rarity×5 |
| **Max Activos** | 3/tipo | 3 NFTs |
| **Independencia** | ✅ Completa | ✅ Completa |
| **Interoperabilidad** | NO interactúan | NO interactúan |

---

**Conclusión:**  
Ambos sistemas son **totalmente independientes** con propósitos y mecanismos diferentes. IndividualSkills es flexible y accesible; GameifiedMarketplaceSkillsV2 es premium y requiere staking desde el inicio.
