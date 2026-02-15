# CollaboratorBadgeRewards v2 - Guía Rápida

**Status**: ✅ IMPLEMENTADO  
**Tipo**: Proxy UUPS Upgradeable  
**Archivo**: `contracts/Marketplace/CollaboratorBadgeRewards.sol`

---

## Resumen

Badge holders (colaboradores) ganan recompensas a través de:
1. **Quests**: Completar tareas específicas
2. **Pool pasivo**: Parte de todas las comisiones del protocolo (25%)

Reciben honorarios por acciones en el ecosistema (comisiones NFT, marketplace fees, etc).

---

## Arquitectura

```
TreasuryManager (25% de ingresos)
    ↓
CollaboratorBadgeRewards (pool de recompensas)
    ├─ Quest rewards (admin configurable)
    ├─ Commission pool (NFT sales)
    ├─ Tiered claim fees (descuento por volumen)
    └─ Health monitoring (solvency tracking)
```

---

## Características Principales

### 1. Quests (Recompensas por Tarea)

```solidity
struct CollaboratorQuest {
    string description;
    uint256 rewardAmount;      // POL por completar
    uint256 startTime;
    uint256 endTime;
    bool active;
    uint256 completionCount;   // Total completamientos
    uint256 maxCompletions;    // 0 = unlimited
}
```

**Funciones Admin**:
```solidity
createQuest(description, rewardAmount, startTime, endTime, maxCompletions)
    → retorna questId

completeQuestForUser(user, questId)
    → marca como completada para usuario

batchCompleteQuest(users[], questId)
    → completa para múltiples usuarios

deactivateQuest(questId)
    → desactiva un quest

updateQuestReward(questId, newAmount)
    → ajusta recompensa
```

### 2. Claim con Tiered Fees

```solidity
function claimRewards() external {
    // Calcula fee basado en volumen acumulativo del user
    uint256 fee = _calculateCommissionTier(msg.sender);
    
    // Fee escalonado:
    // 0-10 ETH: 2%
    // 10-50 ETH: 1.5%
    // 50+ ETH: 1%
    
    uint256 netAmount = grossAmount - fee;
    // Fee → Treasury via receiveRevenue()
}
```

**Health Monitoring**:
```solidity
function getContractHealth() external view returns (
    uint256 solvencyRatio,  // (balance / pending) * 10000
    bool isHealthy,         // balance >= pending
    uint256 deficit         // pending - balance if not healthy
)
```

### 3. Emergency Fallback

```solidity
if (address(this).balance < neededAmount) {
    // Intentar emergency funds de Treasury
    try treasuryManager.requestEmergencyFunds(
        ITreasuryManager.TreasuryType.COLLABORATORS,
        neededAmount - address(this).balance
    ) {
        // Fondos obtenidos o no, reintentamos
    }
    
    if (address(this).balance < neededAmount) revert InsufficientBalance();
}
```

---

## Parámetros Configurables

| Parámetro | Default | Rango | Usar |
|-----------|---------|-------|------|
| maxRewardLimit | 500 ETH | 0-∞ | Máximo por quest |
| maxBalanceLimit | 10,000 ETH | 0-∞ | Techo de balance |
| maxPendingRewardsPerUser | 1,000 ETH | 0-∞ | Máximo acumulado/user |
| claimFeePercent | 200 bps (2%) | 0-1000 | Fee base en claim |
| Commission Tiers | Ver tabla | Variable | Fees escalonados |

**Ajustes admin**:
```solidity
setLimits(maxReward, maxBalance)
setClaimFeePercent(newFeePercent)
setMaxPendingRewardsPerUser(newLimit)
setCommissionTier(threshold, feeRate)
```

---

## Estadísticas & Monitoreo

```solidity
function getStats() external view returns (
    uint256 balance,              // Balance actual
    uint256 pendingDebt,          // totalPendingRewards
    uint256 commission,           // Comisiones recibidas
    uint256 treasury,             // De TreasuryManager
    uint256 paid,                 // Total pagado
    uint256 holders,              // Badge holders activos
    uint256 questCount            // Total quests creados
)

function getBadgeHolderRewardsSummary(user) external view returns (
    uint256 pending,              // Recompensas pendientes
    uint256 poolBalance,          // Balance del contrato
    uint256 totalCommission,      // Historial comisiones
    uint256 totalTreasury         // Recibido de Treasury
)

function getContractHealth() external view returns (
    uint256 solvencyRatio,        // balance/pending * 10000
    bool isHealthy,
    uint256 deficit
)
```

---

## Estados Críticos

| Trigger | Acción |
|---------|--------|
| balance < pending | ⚠️ Insolvente - intenta emergencia |
| solvencyRatio < 20% | 🔴 CRÍTICO - admin notificado |
| balance > maxBalance | ❌ Rechaza depósitos nuevos |
| pending > threshold | ⚠️ Health check fallido |

---

## Eventos Importantes

```solidity
event QuestCreated(questId, description, reward, start, end)
event QuestCompleted(user, questId, reward)
event RewardsClaimed(user, grossAmount, netAmount, fee)
event CriticalFundingNeeded(reason)
event ContractPaused(reason)
event EmergencyFundsRequested(amount, success)
```

---

## Típical Workflows

### Admin crea nuevo quest

```javascript
const startTime = Math.floor(Date.now() / 1000) + 86400;  // Mañana
const endTime = startTime + (7 * 86400);                  // 7 días durancia

const tx = await badgeRewards.createQuest(
    "Refer 5 new users",
    ethers.utils.parseEther("10"),  // 10 POL reward
    startTime,
    endTime,
    50  // Max 50 completamientos
);

console.log("Quest created:", (await tx.wait()).events[0].args.questId);
```

### Admin marca quests completados

```javascript
// Individual
await badgeRewards.completeQuestForUser(userAddress, questId);

// Batch (hasta 100)
await badgeRewards.batchCompleteQuest(userAddresses, questId);
```

### User reclama recompensas

```javascript
const pending = await badgeRewards.pendingRewards(userAddress);
console.log("Pending:", ethers.utils.formatEther(pending));

const fee = await badgeRewards.getClaimFeeForUser(userAddress);
console.log("Your fee:", (fee / 100).toFixed(2), "%");

// Claim
const tx = await badgeRewards.connect(userSigner).claimRewards();
console.log("Claimed:", (await tx.wait()).events[0].args.netAmount);
```

### Verificar salud del contrato

```javascript
const health = await badgeRewards.getContractHealth();
console.log({
    solvencyRatio: (health.solvencyRatio / 100).toFixed(2) + "%",
    isHealthy: health.isHealthy,
    deficit: ethers.utils.formatEther(health.deficit) + " ETH"
});
```

---

## Testing Checklist

- [ ] Crear quest y verificar evento
- [ ] Completar quest y verificar pending rewards
- [ ] Batch complete múltiples usuarios
- [ ] Claimrewards con diferentes tiers de fee
- [ ] Verificar health turn green→yellow→red
- [ ] Test fallback a emergencia
- [ ] Test pausa automática si emergencia falla
- [ ] Test actualizaciones de parámetros

---

## Integración con Otros Módulos

```
CollaboratorBadgeRewards
    ↓ requiere
TreasuryManager (receiveRevenue, requestEmergencyFunds)
    ↓
IBadgeManager (getTotalBadgeHolders)

GameifiedMarketplaceCoreV1 (envia comisiones)
    ↓ llama
CollaboratorBadgeRewards (recibe en receive())
```

---

## References

- **Full Code**: [CollaboratorBadgeRewards.sol](../../contracts/Marketplace/CollaboratorBadgeRewards.sol)
- **Interface**: [ITreasuryManager.sol](../../contracts/interfaces/ITreasuryManager.sol)
- **Emergency System**: [EmergencyFundSystem.md](../IMPLEMENTATION_GUIDES/EmergencyFundSystem.md)
- **Treasury Docs**: [SMART_CONTRACTS_REFERENCE.md](../SMART_CONTRACTS_REFERENCE.md#treasurymanager)

---

**Última actualización**: Febrero 14, 2026  
**Versión**: v2.0 (Proxy Upgradeable)
