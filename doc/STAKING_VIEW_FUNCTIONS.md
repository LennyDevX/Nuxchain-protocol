# Funciones View para Lectura de Depósitos - Staking Contract

## Descripción General

Se han agregado **7 nuevas funciones view** al contrato `EnhancedSmartStakingCore.sol` para permitir al frontend leer detalladamente información sobre los depósitos del usuario, clasificados por tipo de bloqueo (flexible, 30 días, 90 días, 180 días, 365 días).

---

## Nuevos Structs

### `DepositDetails`
Estructura que contiene información detallada sobre un depósito individual:

```solidity
struct DepositDetails {
    uint256 depositIndex;          // Índice del depósito en el array
    uint256 amount;                // Cantidad depositada en wei
    uint256 currentRewards;        // Recompensas actuales acumuladas
    uint256 timestamp;             // Timestamp de creación del depósito
    uint256 lastClaimTime;         // Última vez que se reclamaron recompensas
    uint256 lockupDuration;        // Duración del bloqueo en segundos
    uint256 unlockTime;            // Timestamp cuando se desbloquea
    string lockupType;             // Tipo: "Flexible", "30 Days", "90 Days", etc.
    bool isLocked;                 // True si el depósito sigue bloqueado
    bool isWithdrawable;           // True si puede ser retirado ahora
}
```

### `UserPortfolio`
Estructura que resume todo el portafolio del usuario:

```solidity
struct UserPortfolio {
    uint256 totalDeposited;        // Total depositado (sin recompensas)
    uint256 totalRewards;          // Total de recompensas acumuladas
    uint256 totalPortfolioValue;   // Total = deposited + rewards
    uint256 depositCount;          // Cantidad de depósitos
    uint256 flexibleBalance;       // Balance en depósitos flexibles
    uint256 lockedBalance;         // Balance en depósitos bloqueados actualmente
    uint256 unlockedBalance;       // Balance en depósitos ya desbloqueados
    uint256 lastWithdrawTime;      // Última vez que se retiró
    DepositDetails[] deposits;     // Array con detalles de cada depósito
}
```

---

## Nuevas Funciones View

### 1. `getUserPortfolio(address _user)`
**Descripción:** Retorna un resumen completo del portafolio del usuario con detalles de todos sus depósitos.

**Parámetros:**
- `_user`: Dirección del usuario

**Retorna:** `UserPortfolio memory`
- Información completa incluyendo balance total, recompensas, y array de depósitos con detalles

**Uso en Frontend:**
```javascript
const portfolio = await contract.getUserPortfolio(userAddress);
console.log(portfolio.totalDeposited);      // Total depositado
console.log(portfolio.totalRewards);        // Recompensas acumuladas
console.log(portfolio.flexibleBalance);     // Balance flexible
console.log(portfolio.lockedBalance);       // Balance bloqueado
console.log(portfolio.deposits);            // Array de depósitos con detalles
```

---

### 2. `getUserDepositsByType(address _user)`
**Descripción:** Retorna los depósitos del usuario clasificados por tipo de bloqueo.

**Parámetros:**
- `_user`: Dirección del usuario

**Retorna:** 
- `DepositDetails[] memory flexible`   - Depósitos sin bloqueo
- `DepositDetails[] memory locked30`   - Depósitos de 30 días
- `DepositDetails[] memory locked90`   - Depósitos de 90 días
- `DepositDetails[] memory locked180`  - Depósitos de 180 días
- `DepositDetails[] memory locked365`  - Depósitos de 365 días

**Uso en Frontend:**
```javascript
const { flexible, locked30, locked90, locked180, locked365 } = 
    await contract.getUserDepositsByType(userAddress);

// Mostrar depósitos flexibles
flexible.forEach(d => console.log(`${d.amount} - ${d.lockupType}`));

// Mostrar depósitos con bloqueo
locked30.forEach(d => {
    console.log(`30-day: ${d.amount} - Locked: ${d.isLocked}`);
});
```

---

### 3. `getDepositDetails(address _user, uint256 _depositIndex)`
**Descripción:** Obtiene detalles de un depósito específico por su índice.

**Parámetros:**
- `_user`: Dirección del usuario
- `_depositIndex`: Índice del depósito (0-based)

**Retorna:** `DepositDetails memory`
- Estructura con todos los detalles del depósito solicitado

**Uso en Frontend:**
```javascript
const depositDetails = await contract.getDepositDetails(userAddress, 0);
console.log(depositDetails.amount);        // Cantidad
console.log(depositDetails.lockupType);    // "30 Days", "Flexible", etc.
console.log(depositDetails.isWithdrawable); // ¿Puede retirarse?
console.log(depositDetails.currentRewards);  // Recompensas actuales
```

---

### 4. `getContractBalance()`
**Descripción:** Retorna información del balance del contrato.

**Retorna:**
- `uint256 contractBalance`    - Balance actual del contrato (en wei)
- `uint256 totalPoolBalance`   - Total depositado en el pool
- `uint256 availableForRewards` - Disponible para pagar recompensas

**Uso en Frontend:**
```javascript
const { contractBalance, totalPoolBalance, availableForRewards } = 
    await contract.getContractBalance();

console.log(`Contract Balance: ${contractBalance}`);
console.log(`Pool Balance: ${totalPoolBalance}`);
console.log(`Available for Rewards: ${availableForRewards}`);
```

---

### 5. `getDepositSummaryByType(address _user)`
**Descripción:** Retorna un resumen de los montos totales por tipo de bloqueo.

**Parámetros:**
- `_user`: Dirección del usuario

**Retorna:** `uint256[] memory summaries`
- Array con 5 valores: `[flexible, 30d, 90d, 180d, 365d]`
- Cada valor es el total en wei para ese tipo de bloqueo

**Uso en Frontend:**
```javascript
const summaries = await contract.getDepositSummaryByType(userAddress);
console.log(`Flexible: ${summaries[0]}`);    // Flexible total
console.log(`30 Days: ${summaries[1]}`);     // 30 días total
console.log(`90 Days: ${summaries[2]}`);     // 90 días total
console.log(`180 Days: ${summaries[3]}`);    // 180 días total
console.log(`365 Days: ${summaries[4]}`);    // 365 días total
```

---

### 6. `getLockedDepositInfo(address _user)`
**Descripción:** Verifica si el usuario tiene depósitos bloqueados y cuánto total.

**Parámetros:**
- `_user`: Dirección del usuario

**Retorna:**
- `bool hasLocked`    - True si hay depósitos bloqueados
- `uint256 lockedAmount` - Total en depósitos bloqueados (en wei)

**Uso en Frontend:**
```javascript
const { hasLocked, lockedAmount } = await contract.getLockedDepositInfo(userAddress);

if (hasLocked) {
    console.log(`Usuario tiene ${lockedAmount} bloqueado`);
} else {
    console.log(`Usuario no tiene depósitos bloqueados`);
}
```

---

### 7. `getWithdrawableDeposits(address _user)`
**Descripción:** Retorna qué depósitos pueden ser retirados ahora.

**Parámetros:**
- `_user`: Dirección del usuario

**Retorna:**
- `uint256[] memory withdrawableIndices` - Índices de depósitos que pueden retirarse
- `uint256 withdrawableAmount` - Total que puede retirarse (en wei)

**Uso en Frontend:**
```javascript
const { withdrawableIndices, withdrawableAmount } = 
    await contract.getWithdrawableDeposits(userAddress);

console.log(`Puedes retirar: ${withdrawableAmount} (en ${withdrawableIndices.length} depósitos)`);

withdrawableIndices.forEach(idx => {
    console.log(`Depósito ${idx} está disponible`);
});
```

---

### 8. `getNextUnlockTime(address _user)`
**Descripción:** Obtiene cuándo se desbloqueará el próximo depósito.

**Parámetros:**
- `_user`: Dirección del usuario

**Retorna:**
- `uint256 secondsUntilUnlock` - Segundos hasta el próximo desbloqueo
- `uint256 nextUnlockTime` - Timestamp del próximo desbloqueo

**Uso en Frontend:**
```javascript
const { secondsUntilUnlock, nextUnlockTime } = 
    await contract.getNextUnlockTime(userAddress);

if (secondsUntilUnlock > 0) {
    const days = Math.floor(secondsUntilUnlock / 86400);
    console.log(`Próximo desbloqueo en ${days} días`);
    console.log(`Timestamp: ${new Date(nextUnlockTime * 1000)}`);
}
```

---

## Ejemplo de Uso Completo en Frontend

```javascript
// 1. Obtener portafolio completo
const portfolio = await contract.getUserPortfolio(userAddress);

console.log("=== PORTAFOLIO DEL USUARIO ===");
console.log(`Total Depositado: ${portfolio.totalDeposited} wei`);
console.log(`Total Recompensas: ${portfolio.totalRewards} wei`);
console.log(`Valor Total: ${portfolio.totalPortfolioValue} wei`);

console.log("\n=== BALANCE POR TIPO ===");
console.log(`Flexible: ${portfolio.flexibleBalance} wei`);
console.log(`Bloqueado: ${portfolio.lockedBalance} wei`);
console.log(`Desbloqueado: ${portfolio.unlockedBalance} wei`);

console.log("\n=== DEPÓSITOS INDIVIDUALES ===");
portfolio.deposits.forEach((deposit, idx) => {
    console.log(`\nDepósito #${idx}:`);
    console.log(`  Cantidad: ${deposit.amount} wei`);
    console.log(`  Tipo: ${deposit.lockupType}`);
    console.log(`  Recompensas: ${deposit.currentRewards} wei`);
    console.log(`  ¿Bloqueado?: ${deposit.isLocked}`);
    console.log(`  ¿Retirable?: ${deposit.isWithdrawable}`);
    console.log(`  Desbloquea en: ${new Date(deposit.unlockTime * 1000)}`);
});

// 2. Información de retiro
const { withdrawableIndices, withdrawableAmount } = 
    await contract.getWithdrawableDeposits(userAddress);

console.log(`\n=== INFORMACIÓN DE RETIRO ===`);
console.log(`Total retirable: ${withdrawableAmount} wei`);
console.log(`Depósitos retirables: ${withdrawableIndices.join(', ')}`);

// 3. Próximo desbloqueo
const { secondsUntilUnlock, nextUnlockTime } = 
    await contract.getNextUnlockTime(userAddress);

if (secondsUntilUnlock > 0) {
    const days = Math.floor(secondsUntilUnlock / 86400);
    console.log(`\nPróximo desbloqueo en ${days} días`);
}
```

---

## Notas para el Frontend

1. **Gas Efficiency**: Todas estas funciones son `view`, por lo que **no gastan gas**.

2. **Cálculo de Recompensas**: Las recompensas se calculan dinámicamente basadas en:
   - El tiempo transcurrido desde el último reclamo
   - El período de bloqueo del depósito (0, 30, 90, 180, 365 días)
   - Los boosts de skills activos del usuario

3. **Formateo de Wei**: Recuerda convertir los valores de wei a unidades legibles (1 POL = 10^18 wei):
   ```javascript
   const amount = ethers.formatEther(deposit.amount); // En POL
   ```

4. **Tipos de Bloqueo**:
   - `"Flexible"` - Sin bloqueo, puede retirarse inmediatamente
   - `"30 Days"` - Bloqueado 30 días
   - `"90 Days"` - Bloqueado 90 días
   - `"180 Days"` - Bloqueado 180 días
   - `"365 Days"` - Bloqueado 365 días

5. **Actualización de Datos**: Estas funciones leen datos en tiempo real, así que puedes llamarlas frecuentemente sin problemas.

---

## Resumen de Cambios

| Función | Propósito |
|---------|-----------|
| `getUserPortfolio()` | Portafolio completo del usuario |
| `getUserDepositsByType()` | Depósitos clasificados por tipo de bloqueo |
| `getDepositDetails()` | Detalles de un depósito específico |
| `getContractBalance()` | Balance e información del contrato |
| `getDepositSummaryByType()` | Totales por tipo de bloqueo (array) |
| `getLockedDepositInfo()` | Información sobre depósitos bloqueados |
| `getWithdrawableDeposits()` | Depósitos que pueden retirarse |
| `getNextUnlockTime()` | Cuándo se desbloquea el próximo depósito |

Todas estas funciones **no modifican estado** y están listas para ser usadas en el frontend para mostrar información detallada sobre los depósitos del usuario.
