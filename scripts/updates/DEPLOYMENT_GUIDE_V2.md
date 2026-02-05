# 🚀 GUÍA DE ACTUALIZACIÓN - NUXCHAIN PROTOCOL V2

## 📋 Resumen de Cambios

Esta actualización implementa un sistema de economía circular completo para Nuxchain Protocol:

### ✨ Características Nuevas

1. **TreasuryManager** - Centralización de ingresos
   - Recibe comisiones de todos los módulos
   - Auto-distribuye a 4 pools especializados
   - Fallback seguro para rewards

2. **Gamification V2** - Automatización completa
   - Auto-compound corregido
   - 8 tipos de badges (auto-award)
   - Rewards deferred event para tracking

3. **Rewards V2** - Financiamiento sostenible
   - 2% commission en quest rewards
   - Treasury integration
   - Fallback si fondos insuficientes

4. **Skills V2** - Anti-exploit
   - Boost limits: +50% APY cap
   - Pre-activation validation
   - Rejection events transparentes

---

## 📋 Prerequisitos

- Node.js v18+
- Hardhat configurado
- `polygon-addresses.json` en `deployments/`
- Suficiente balance de POL (~5-10 POL para gas)
- Cuenta de deployment autorizada

---

## 🔧 Opciones de Despliegue

### OPCIÓN 1: Desplegar Todo Automáticamente (Recomendado)

```bash
npx hardhat run scripts/updates/staking/deploy_all_updates.cjs --network polygon
```

Esto ejecutará secuencialmente:
1. TreasuryManager
2. Gamification V2
3. Rewards V2
4. Skills V2

⏱️ Tiempo estimado: 10-15 minutos

---

### OPCIÓN 2: Desplegar Módulo por Módulo

#### Paso 1: Desplegar TreasuryManager (PRIMERO)

```bash
npx hardhat run scripts/updates/staking/deploy_treasury_manager.cjs --network polygon
```

**Salida esperada:**
```
✅ TreasuryManager desplegado en: 0x...
💾 polygon-addresses.json actualizado con treasury.manager
```

**Verificar en Polygonscan:**
```bash
npx hardhat verify --network polygon 0x... # dirección del treasury
```

---

#### Paso 2: Actualizar Gamification Module

```bash
npx hardhat run scripts/updates/staking/update_gamification_module.cjs --network polygon
```

**Cambios aplicados:**
- ✅ Vinculado con TreasuryManager
- ✅ Auto-compound ahora calcula rewards correctamente
- ✅ 8 badges auto-award implementados
- ✅ Autorizado como requester en Treasury

**Requisitos previos:**
- ✅ TreasuryManager desplegado

---

#### Paso 3: Actualizar Rewards Module

```bash
npx hardhat run scripts/updates/staking/update_rewards_module.cjs --network polygon
```

**Cambios aplicados:**
- ✅ 2% commission en quests
- ✅ Auto-routing a Treasury
- ✅ Fallback si fondos insuficientes

**Requisitos previos:**
- ✅ TreasuryManager desplegado
- ✅ Gamification V2 desplegado

---

#### Paso 4: Actualizar Skills Module

```bash
npx hardhat run scripts/updates/staking/update_skills_module.cjs --network polygon
```

**Cambios aplicados:**
- ✅ Boost limits implementados (5000 = +50%)
- ✅ Pre-activation validation
- ✅ Rejection events para debugging

**Requisitos previos:**
- ✅ TreasuryManager desplegado

---

## 📊 Verificación Post-Despliegue

### 1. Confirmar Direcciones

```bash
cat deployments/polygon-addresses.json | grep -E "treasury|gamification|rewards|skills"
```

Salida esperada:
```json
{
  "treasury": {
    "manager": "0x...",
    "rewards": "0x...",
    "staking": "0x...",
    "marketplace": "0x...",
    "development": "0x..."
  },
  "staking": {
    "gamification": "0x...",
    "rewards": "0x...",
    "skills": "0x..."
  }
}
```

### 2. Verificar Configuración en Polygonscan

**TreasuryManager:**
```
1. Ve a Polygonscan → Tu TreasuryManager address
2. Click en "Read Contract"
3. Verifica getAllAllocations():
   - rewards: 4000 (40%)
   - staking: 3000 (30%)
   - marketplace: 2000 (20%)
   - development: 1000 (10%)
```

### 3. Verificar Vinculación en Gamification

```
1. Ve a Polygonscan → Gamification address
2. Click en "Read Contract"
3. Llama a treasuryManager() → Debe retornar TreasuryManager address
```

---

## ⚙️ Configuración Manual Requerida

### DESPUÉS de desplegar TODOS los módulos:

#### 1. Autorizar Fuentes en Treasury

En Polygonscan, llamar a `setAuthorizedSource()`:

```
Contract: TreasuryManager
Function: setAuthorizedSource
source: 0x{EnhancedSmartStakingCore}
authorized: true
```

```
Contract: TreasuryManager
Function: setAuthorizedSource
source: 0x{GameifiedMarketplaceCore}
authorized: true
```

#### 2. Fondear el Treasury (Opcional pero Recomendado)

Enviar 100-200 POL directamente al Treasury Manager para iniciar con fondos:

```bash
# Desde tu CLI o frontend
await web3.eth.sendTransaction({
  from: yourAccount,
  to: treasuryManagerAddress,
  value: web3.utils.toWei('100', 'ether') // 100 POL
})
```

#### 3. Monitorear Eventos

Monitorear los primeros 24h:
- `RevenueReceived` - Ingresos llegando
- `RevenueDistributed` - Distribuciones automáticas
- `BadgeEarned` - Usuarios recibiendo badges

---

## 🧪 Testing Recomendado

Después de despliegue, ejecutar tests:

```bash
npx hardhat test test/treasury_integration.test.js
npx hardhat test test/gamification_badges.test.js
npx hardhat test test/rewards_commission.test.js
npx hardhat test test/skills_limits.test.js
```

### Tests Críticos a Validar

1. **Treasury Auto-Distribution**
   ```javascript
   // Enviar 1 POL al treasury
   // Verificar que se distribuya automáticamente a 4 pools
   ```

2. **Quest Commission**
   ```javascript
   // Completar quest de 100 POL
   // Usuario recibe: 98 POL
   // Treasury recibe: 2 POL
   ```

3. **Badge Auto-Award**
   ```javascript
   // Alcanzar nivel 10
   // Automáticamente award "Level 10 Achieved"
   ```

4. **Boost Limit Enforcement**
   ```javascript
   // Intentar activar boost que excede 5000
   // Debe rechazar con SkillActivationRejected event
   ```

---

## ⚠️ Troubleshooting

### Error: "No se encontró polygon-addresses.json"

**Solución:** Crear manualmente:
```bash
mkdir -p deployments
cat > deployments/polygon-addresses.json << 'EOF'
{
  "network": "polygon",
  "chainId": "137",
  "timestamp": "2026-02-04T00:00:00.000Z",
  "staking": {},
  "marketplace": {},
  "treasury": {}
}
EOF
```

### Error: "Insufficient balance"

**Solución:** 
- Verificar balance: `npx hardhat --network polygon account`
- Obtener más POL desde exchange
- Asegurar correcto network en hardhat.config.js

### Error: "Invalid contract address"

**Solución:**
- Verificar que polygon-addresses.json tiene direcciones válidas
- Direcciones debe ser formato: `0x{40 caracteres hex}`
- Ejecutar despliegues en orden (Treasury primero)

### Error: "Transaction reverted"

**Solución:**
- Verificar logs en Polygonscan
- Posible causa: Insuficiente gas estimado
- Aumentar gasLimit en hardhat.config.js

---

## 📈 Métrica Esperadas Post-Despliegue

### 24h Después:

**Treasury Stats:**
- ✅ totalRevenueReceived > 0 POL
- ✅ totalDistributed > 0 POL
- ✅ currentBalance = totalRevenueReceived - totalDistributed

**Gamification:**
- ✅ Usuarios con level-ups tienen rewards
- ✅ Algunos usuarios con badges
- ✅ Auto-compound ejecutándose

**Rewards:**
- ✅ Quest claims completados
- ✅ 2% commission routing al Treasury
- ✅ No failed claims

**Skills:**
- ✅ Activaciones de skills completadas
- ✅ Ninguna rejeción por límites (si usuarios respetan)

---

## 📞 Contacto & Soporte

Si encuentras problemas durante el despliegue:

1. Revisar logs en Polygonscan
2. Verificar gas estimation en hardhat
3. Confirmar todas las dependencias en polygon-addresses.json
4. Ejecutar en testnets primero (Mumbai)

---

## 🎯 Roadmap Post-V2

- [ ] Multisig para treasuries
- [ ] Vesting contracts para development fund
- [ ] DAO governance para cambios de allocations
- [ ] Frontend dashboard para treasury stats
- [ ] Advanced analytics para anti-exploit

---

## ✅ Checklist Final

Antes de considerar completado:

- [ ] TreasuryManager desplegado
- [ ] Gamification V2 desplegado y vinculado
- [ ] Rewards V2 desplegado y vinculado
- [ ] Skills V2 desplegado y vinculado
- [ ] Todos verificados en Polygonscan
- [ ] Fuentes autorizadas en Treasury
- [ ] Tests pasados
- [ ] Fondos iniciales en Treasury
- [ ] Eventos monitoreados 24h
- [ ] Frontend actualizado con nuevas funciones

---

**Versión:** 2.0.0  
**Fecha:** 2026-02-04  
**Red:** Polygon Mainnet  
**Estado:** ✅ Listo para producción
