# Emergency Fund System - Guía de Implementación

**Status**: ⚠️ En diseño - Protocolos necesitan conectarse al sistema de fondos de emergencia  
**Prioridad**: ALTA - Crítico para sustainability  
**Fecha**: Febrero 14, 2026

---

## Resumen Ejecutivo

Nuxchain cuenta con un **Reserve Fund** en TreasuryManager, pero **los protocolos individuales NO pueden solicitar estos fondos automáticamente** en emergencias. Esta guía describe:

1. **Cómo está implementado** el sistema actual
2. **Qué hace falta** para conectar protocolos al fondo de emergencia
3. **Cómo implementar** el fallback automático en cada protocolo

---

## 1. Sistema Actual de Fondos

### Componentes

```
TreasuryManager
├─ Balance Total: 1000 ETH
│  ├─ Normal Balance: 800 ETH (distribuible semanalmente)
│  └─ Reserve Fund: 200 ETH (emergencia)
│
├─ requestRewardFunds(amount)
│  └─ Obtiene fondos del balance normal
│
└─ requestEmergencyFunds(protocol, amount) [NECESITA IMPLEMENTACIÓN]
   └─ Obtiene fondos del Reserve Fund
```

### Protocolos que Necesitan Emergencias

| Protocolo | Estado | Integración |
|-----------|--------|-------------|
| **CollaboratorBadgeRewards** | ✅ Parcial | Intenta requestEmergencyFunds en claimRewards() |
| **EnhancedSmartStakingGamification** | 🟡 Débil | Intenta requestRewardFunds pero sin pausa |
| **EnhancedSmartStakingRewards** | ❌ No | Revierte sin fallback |
| **GameifiedMarketplaceCoreV1** | ❌ No | Sin mecanismo de fondos |

---

## 2. CollaboratorBadgeRewards - Implementación Completa

**Status**: ✅ Implementado  
**Archivo**: `contracts/Marketplace/CollaboratorBadgeRewards.sol`

### Lógica Actual

```solidity
function claimRewards() external nonReentrant {
    uint256 grossAmount = pendingRewards[msg.sender];
    
    // Paso 1: Verificar balance local
    if (address(this).balance < grossAmount) {
        // Paso 2: Intentar fondos de emergencia
        try treasuryManager.requestEmergencyFunds(
            ITreasuryManager.TreasuryType.COLLABORATORS,
            grossAmount - address(this).balance
        ) returns (bool emergencySuccess) {
            // Fondos obtenidos o no, continuamos
        } catch {
            // Si falla, simplemente revierte después
        }
        
        // Paso 3: Verificación final
        if (address(this).balance < grossAmount) revert InsufficientBalance();
    }
    
    // Paso 4: Procesar pago
    // ...
}
```

### Health Check para Monitoreo

```solidity
function getContractHealth() external view returns (
    uint256 solvencyRatio,  // (balance / pending) * 10000
    bool isHealthy,         // balance >= pending
    uint256 deficit         // pending - balance (si no solvente)
)
```

**Ejemplo**:
- Balance: 500 ETH
- Pending: 1000 ETH
- **solvencyRatio**: 5000 (50%)
- **isHealthy**: false
- **deficit**: 500 ETH

---

## 3. EnhancedSmartStakingGamification - Implementación Débil

**Status**: 🟡 Parcial  
**Archivo**: `contracts/SmartStaking/EnhancedSmartStakingGamification.sol`

### Problema Actual

```solidity
function _distributeLevelUpReward(address user, uint16 newLevel) internal {
    uint256 rewardAmount = _calculateLevelUpReward(newLevel);
    
    // ✅ Intenta requestRewardFunds (normal balance)
    // ❌ NO intenta requestEmergencyFunds (reserve)
    // ❌ NO pausa automáticamente si ambos fallan
    // ❌ Solo diferida - usuario nunca recibe
}
```

### Lo que Falta

1. **Fallback a emergencia** después de intentar normal
2. **Pausa automática** si fondos insuficientes persistentemente
3. **Notificación al admin** sobre estado crítico

---

## 4. Integración en TreasuryManager

### Interface Necesaria

```solidity
interface ITreasuryManager {
    enum TreasuryType {
        REWARDS,
        STAKING,
        COLLABORATORS,
        DEVELOPMENT,
        MARKETPLACE
    }
    
    // Solicitar fondos de emergencia
    function requestEmergencyFunds(
        TreasuryType protocol,
        uint256 amount
    ) external returns (bool success);
    
    // Obtener fondos normales
    function requestRewardFunds(uint256 amount) 
        external returns (bool success);
}
```

### Lógica en TreasuryManager

```
requestEmergencyFunds(protocol, amount):
  
  IF reserveFundBalance < amount:
    RETURN false (fondos insuficientes)
  
  IF dailyEmergencyUsage[protocol] + amount > max:
    RETURN false (límite diario excedido)
  
  IF protocolHealth == CRITICAL:
    Transfer amount from reserve
    Update accounting
    Emit APYCompressionAlert
    RETURN true
  
  RETURN false (protocolo no en emergencia)
```

---

## 5. Patrones de Implementación

### Patrón 1: Intentar Normal → Emergencia

```solidity
// En cualquier función que pida fondos:
function claimOrRequestFunds(uint256 amount) internal returns (bool) {
    // 1. Intentar balance local
    if (address(this).balance >= amount) {
        return true;
    }
    
    // 2. Intentar normal (distribución semanal)
    try treasuryManager.requestRewardFunds(amount) returns (bool success) {
        if (success) return true;
    } catch {}
    
    // 3. Intentar emergencia (reserve fund)
    try treasuryManager.requestEmergencyFunds(
        ITreasuryManager.TreasuryType.YOUR_PROTOCOL,
        amount
    ) returns (bool success) {
        return success;
    } catch {
        return false;
    }
}
```

### Patrón 2: Health Monitoring

```solidity
function _checkHealthAndReport() internal {
    (uint256 ratio, bool healthy, uint256 deficit) = getContractHealth();
    
    if (!healthy && deficit > getThreshold()) {
        // Reportar estado crítico
        try treasuryManager.reportCriticalStatus(
            "Insufficient funds for reward claims"
        ) {
            // Logged
        } catch {}
    }
}
```

### Patrón 3: Pausa Automática

```solidity
bool private isPaused;

function _tryClaimOrPause() internal {
    if (!_tryGetFunds()) {
        // No hay fondos, pausar
        isPaused = true;
        emit CriticalFundsNeeded("Emergency funding required");
    }
}
```

---

## 6. Diagramas de Flujo

### Flujo Normal (Todo Bien ✅)

```
User quiere $100
    ↓
Contract: ¿Tenemos $100?
    ↓ YES
Pay usuario
    ↓
Event: RewardsClaimed
```

### Flujo de Emergencia (Crisis Controlada ⚠️)

```
User quiere $100
    ↓
Contract: ¿Tenemos $100?
    ↓ NO
Intent: RequestNormalFunds ($100)
    ↓ FALLA
Intent: RequestEmergencyFunds ($100)
    ↓ ÉXITO (Reserve tiene fondos)
Transfer from Reserve
    ↓
Pay usuario
    ↓
Event: CriticalFundingProvided
Notify Admin: APY compression detected
```

### Flujo de Colapso (No Recuperable ❌)

```
User quiere $100
    ↓
Contract: ¿Tenemos $100?
    ↓ NO
Intent: RequestNormalFunds ($100)
    ↓FAILSIntent: RequestEmergencyFunds ($100)
    ↓ FAILS (Reserve vacío)
Transfer FALLA
    ↓
Pause contract automáticamente
    ↓
Emit CriticalError
Notify Admin URGENTE
    ↓
User recibe revert: Fondos insuficientes
```

---

## 7. Tasas & Límites

### Límites de Emergencia (Propuestos)

```solidity
// Por protocolo, por día
MAX_EMERGENCY_REQUEST_PER_DAY = 50% de reserva disponible

// Por semana
MAX_EMERGENCY_PER_WEEK = 80% de reserva

// Rate limiting
MIN_TIME_BETWEEN_REQUESTS = 1 hour
```

### Escala de Severidad

| Solvency Ratio | Estado | Acción |
|---------------|--------|--------|
| > 80% | HEALTHY ✅ | Operación normal |
| 50-80% | CAUTION 🟡 | Monitoreo manual |
| 20-50% | WARNING 🟠 | Alert admin |
| < 20% | CRITICAL 🔴 | Emergency activation |
| = 0% | INSOLVENT ❌ | Pausa automática |

---

## 8. Checklist de Implementación

Para cada protocolo:

- [ ] Implementar `getContractHealth()` que retorne solvencyRatio, isHealthy, deficit
- [ ] Agregar `requestEmergencyFunds()` como fallback en claimRewards/withdrawal
- [ ] Implementar health checking automático
- [ ] Agregar lógica de pausa si emergencia falla
- [ ] Emitir eventos apropiados (CriticalStatus, EmergencyFundingNeeded)
- [ ] Conectar a `treasuryManager.reportCriticalStatus()`
- [ ] Testing con escenarios de insolvencia
- [ ] Documentar thresholds y límites específicos del protocolo

---

## 9. Eventos & Monitoreo

### Eventos Recomendados

```solidity
// En protocolos individuales
event EmergencyFundsRequested(uint256 amount, bool success);
event CriticalStatusReported(string reason);
event ContractPaused(string reason);
event SolvencyCheckFailed(uint256 deficit);

// En TreasuryManager
event EmergencyFundsDistributed(address protocol, uint256 amount);
event ReserveAtThreshold(uint256 remaining);
event ProtocolInCritical(address protocol);
```

### Metricas para Monitoreo

```javascript
// Revisar diariamente
treasuryManager.getEmergencyInfo()
// → isActive, emergencyFundsDistributed, reserveAvailable

// Por protocolo
collaboratorBadges.getContractHealth()
// → solvencyRatio, isHealthy, deficit

// Detectar tendencias
graphql: {
  emegencyFundsDistributed(last: 30days)
  protocolsInCritical(active: true)
  reserveFundBalance(historical: true)
}
```

---

## 10. Troubleshooting

### Problema: "Insufficient Balance" incluso con reserve

**Causa**: Reserve está vacío o límites diarios excedidos  
**Solución**: Revisar `reserveFundBalance` y `dailyEmergencyUsage[protocol]`

### Problema: Fondos de emergencia no llegan

**Causa**: Protocol no está autorizado como requester  
**Solución**: 
```solidity
await treasuryManager.setAuthorizedRequester(protocolAddress, true);
```

### Problema: Pausa automática se activa incorrectamente

**Causa**: Threshold muy bajo o cálculo de health incorrecto  
**Solución**: Revisar `getContractHealth()` y ajustar thresholds

---

## Referencias

- [Documentación de TreasuryManager](../SMART_CONTRACTS_REFERENCE.md#treasurymanager)
- [CollaboratorBadgeRewards](../FEATURES/CollaboratorBadgeRewards.md)
- [Sistema de APY Dinámico](./DynamicAPYCalculator.md) - puede afectar solvencia

---

**Versión**: 1.0  
**Última actualización**: Febrero 14, 2026  
**Estatus**: En diseño/Parcialmente implementado
