# 🚀 QUICK START - COMANDOS RÁPIDOS

## 📋 Antes de Empezar

```bash
# Verificar que tienes todo configurado
npx hardhat accounts --network polygon    # Ver tu cuenta
npx hardhat balance --network polygon     # Ver balance de POL

# Asegurar que tienes al menos 5-10 POL para gas
```

---

## 🎯 OPCIÓN 1: TODO AUTOMÁTICO (Recomendado)

```bash
# Ejecutar orquestador (hará todo en orden)
npx hardhat run scripts/updates/staking/deploy_all_updates.cjs --network polygon

# Verificar que todo esté bien
npx hardhat run scripts/updates/staking/verify_setup.cjs --network polygon
```

⏱️ **Tiempo:** 10-15 minutos
📊 **Contratos desplegados:** 4 (Treasury + 3 módulos)

---

## 🔧 OPCIÓN 2: PASO A PASO

### Paso 1️⃣ - Desplegar Treasury Manager

```bash
npx hardhat run scripts/updates/staking/deploy_treasury_manager.cjs --network polygon
```

Salida esperada:
```
✅ TreasuryManager desplegado en: 0x...
💾 polygon-addresses.json actualizado
```

### Paso 2️⃣ - Actualizar Gamification

```bash
npx hardhat run scripts/updates/staking/update_gamification_module.cjs --network polygon
```

Salida esperada:
```
✅ Nuevo Gamification desplegado en: 0x...
✅ Treasury Manager vinculado
✅ Autorizado como requester
```

### Paso 3️⃣ - Actualizar Rewards

```bash
npx hardhat run scripts/updates/staking/update_rewards_module.cjs --network polygon
```

Salida esperada:
```
✅ Nuevo Rewards desplegado en: 0x...
✅ 2% commission implementado
✅ Treasury Manager vinculado
```

### Paso 4️⃣ - Actualizar Skills

```bash
npx hardhat run scripts/updates/staking/update_skills_module.cjs --network polygon
```

Salida esperada:
```
✅ Nuevo Skills desplegado en: 0x...
✅ Boost limits configurados
✅ Pre-activation validation activa
```

---

## ✅ VERIFICAR TODO

```bash
# Ejecutar suite de verificaciones
npx hardhat run scripts/updates/staking/verify_setup.cjs --network polygon
```

Esperado: ✅ Checks OK: 8/8 (100%)

---

## 🔍 VER DIRECCIONES DESPLEGADAS

```bash
# Ver todas las direcciones en JSON
cat deployments/polygon-addresses.json

# Ver solo Treasury
cat deployments/polygon-addresses.json | grep -A 10 '"treasury"'

# Ver solo Staking Modules
cat deployments/polygon-addresses.json | grep -A 10 '"staking"'
```

---

## 🌍 VERIFICAR EN POLYGONSCAN

Una vez desplegados, verificar en: https://polygonscan.com/

```bash
# Verificar TreasuryManager
npx hardhat verify --network polygon 0x{TreasuryAddress}

# Verificar Gamification
npx hardhat verify --network polygon 0x{GamificationAddress}

# Verificar Rewards
npx hardhat verify --network polygon 0x{RewardsAddress}

# Verificar Skills
npx hardhat verify --network polygon 0x{SkillsAddress}
```

---

## 💰 FONDEAR TREASURY (Opcional)

Si quieres iniciar con fondos en el Treasury:

```bash
# Usar Hardhat
npx hardhat run -c "
const { ethers } = require('hardhat');
const [signer] = await ethers.getSigners();
const tx = await signer.sendTransaction({
  to: '0x{TreasuryAddress}',
  value: ethers.parseEther('100') // 100 POL
});
await tx.wait();
console.log('✅ 100 POL enviados al Treasury');
" --network polygon
```

---

## 🧪 TESTS RÁPIDOS

```bash
# Correr todos los tests
npx hardhat test

# Tests específicos
npx hardhat test test/treasury.test.js
npx hardhat test test/gamification.test.js
npx hardhat test test/rewards.test.js
npx hardhat test test/skills.test.js
```

---

## 🔐 AUTORIZAR FUENTES (Manual)

En Polygonscan, llamar a TreasuryManager.setAuthorizedSource():

```javascript
// Para Core Staking
{
  source: 0x{CoreStakingAddress},
  authorized: true
}

// Para Marketplace
{
  source: 0x{MarketplaceAddress},
  authorized: true
}
```

---

## 🆘 TROUBLESHOOTING RÁPIDO

**Error: "No se encontró polygon-addresses.json"**
```bash
mkdir -p deployments
echo '{"network":"polygon","chainId":"137","staking":{},"marketplace":{},"treasury":{}}' > deployments/polygon-addresses.json
```

**Error: "Insufficient balance"**
```bash
# Ver balance actual
npx hardhat account --network polygon

# Necesitas ~5-10 POL para gas
```

**Error: "Transaction reverted"**
```bash
# Ver logs de la transacción en Polygonscan
# Probablemente: 
# - Dirección incorrecta en polygon-addresses.json
# - Gas estimado insuficiente
# - Dependencias no desplegadas en orden
```

---

## 📊 MONITOREAR EN TIEMPO REAL

```bash
# Ver eventos RevenueReceived
npx hardhat run -c "
const { ethers } = require('hardhat');
const treasury = await ethers.getContractAt('TreasuryManager', '0x{Address}');
treasury.on('RevenueReceived', (source, amount, type) => {
  console.log(\`💰 Ingresos: \${ethers.formatEther(amount)} POL (\${type})\`);
});
" --network polygon
```

---

## 🎯 CHECKLIST FINAL

```
Pre-Despliegue:
☐ Balance > 10 POL
☐ polygon-addresses.json existe
☐ Network configurado (polygon en hardhat.config.js)

Post-Despliegue:
☐ TreasuryManager desplegado
☐ Gamification actualizado
☐ Rewards actualizado
☐ Skills actualizado
☐ verify_setup.cjs pasado (8/8 checks)
☐ Contratos verificados en Polygonscan
☐ Treasury fondeado con 100+ POL (opcional)
☐ Fuentes autorizadas en Treasury
☐ Tests ejecutados exitosamente
```

---

## 💡 TIPS ÚTILES

**Para evitar errores comunes:**

1. Siempre ejecutar en ORDEN:
   - Treasury PRIMERO
   - Luego Gamification, Rewards, Skills

2. Esperar confirmación de cada transacción:
   - El script esperará automáticamente
   - Si se cuelga, esperar 2-3 minutos antes de reintentar

3. Guardar direcciones después de cada despliegue:
   - polygon-addresses.json se actualiza automáticamente
   - Hacer backup de este archivo

4. Verificar en Polygonscan:
   - Confirmar que el código existe en la dirección
   - Revisar que no hay errores en constructor

5. Monitorear eventos:
   - Los primeros 24h son críticos
   - Verificar que RevenueReceived y RevenueDistributed se ejecutan

---

## 📞 REFERENCIAS RÁPIDAS

**Archivos importantes:**
- Scripts: `scripts/updates/staking/`
- Contratos: `contracts/Treasury/` y `contracts/SmartStaking/`
- Configuración: `deployments/polygon-addresses.json`
- Guía completa: `scripts/updates/DEPLOYMENT_GUIDE_V2.md`

**Funciones clave:**
- `TreasuryManager.receiveRevenue()`
- `EnhancedSmartStakingGamification._distributeLevelUpReward()`
- `EnhancedSmartStakingRewards.claimQuestReward()`
- `EnhancedSmartStakingSkills.notifySkillActivation()`

---

## 🎉 ¡LISTO!

Una vez completados todos los pasos:
- ✅ Economía circular funcionando
- ✅ Rewards automáticamente financiados
- ✅ Badges auto-awarded
- ✅ Anti-exploit protecciones activas
- ✅ Listo para usuarios

**Tiempo total estimado:** 15-30 minutos (incluyendo esperas de transacción)
