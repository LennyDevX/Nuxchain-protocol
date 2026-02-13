# 🚀 NUXCHAIN PROTOCOL - DEPLOYMENT SCRIPT DOCUMENTATION

## Descripción General

El script `DeployAllContracts.cjs` es el orquestador central para desplegar toda la arquitectura del Nuxchain Protocol en Polygon. Realiza un despliegue modular y sincronizado de **5 módulos de Smart Staking** y **4 módulos de Gameified Marketplace** con un patrón UUPS Proxy.

**Versión:** 6.0.0  
**Red Soportada:** Polygon / Mumbai  
**Patrón Arquitectónico:** UUPS Proxy + Modular

---

## 📋 TABLA DE CONTENIDOS

1. [Requisitos Previos](#requisitos-previos)
2. [Estructura del Despliegue](#estructura-del-despliegue)
3. [Fases de Despliegue](#fases-de-despliegue)
4. [Variables de Entorno](#variables-de-entorno)
5. [Ejecución del Script](#ejecución-del-script)
6. [Validaciones Implementadas](#validaciones-implementadas)
7. [Recuperación ante Errores](#recuperación-ante-errores)
8. [Archivos Generados](#archivos-generados)
9. [Verificación en Polygonscan](#verificación-en-polygonscan)
10. [Troubleshooting](#troubleshooting)

---

## Requisitos Previos

### Herramientas Requeridas
- **Node.js** v16+ con npm/yarn
- **Hardhat** configurado correctamente
- **Ethers.js** v6+
- **dotenv** para gestión de variables de entorno
- Cuenta en **Polygonscan** con API key (para verificación automática)

### Red Blockchain
- **Polygon Mainnet** o **Mumbai Testnet**
- Saldo mínimo en POL para gas:
  - Testnet: ~5-10 POL
  - Mainnet: ~50-100 POL

### Configuración Local
```bash
# Instalar dependencias
npm install

# Crear archivo .env
cp .env.example .env

# Completar variables de entorno
PRIVATE_KEY=<tu_clave_privada>
TREASURY_ADDRESS=<dirección_treasury>
POLYGONSCAN_API_KEY=<tu_api_key>
```

---

## Estructura del Despliegue

### FASE 1: Enhanced Smart Staking (5 Módulos)

| Módulo | Dirección | Descripción |
|--------|-----------|-------------|
| **EnhancedSmartStakingRewards** | Dirección 1 | Cálculo de APY y compounding |
| **EnhancedSmartStakingSkills** | Dirección 2 | Activación y efectos de skills |
| **EnhancedSmartStakingGamification** | Dirección 3 | XP, niveles y gamificación |
| **EnhancedSmartStakingCore** | Dirección 4 | Orquestador principal (depósitos/retiros) |
| **EnhancedSmartStakingView** | Dirección 5 | Consultas read-only |

### FASE 2: Gameified Marketplace (UUPS Proxy + 4 Sub-módulos)

| Componente | Dirección | Descripción |
|------------|-----------|-------------|
| **GameifiedMarketplaceProxy** | Dirección Proxy | UUPS Proxy (usar para interacciones) |
| **GameifiedMarketplaceCoreV1** | Dirección Impl | Lógica upgradeable |
| **GameifiedMarketplaceSkillsV2** | Dirección 6 | NFTs con skills integradas |
| **IndividualSkillsMarketplace** | Dirección 7 | Compra directa de skills |
| **GameifiedMarketplaceQuests** | Dirección 8 | Sistema de quests |

---

## Fases de Despliegue

### FASE 1: Despliegue de Enhanced Smart Staking

#### 1.1 - Deploy Rewards Module
```
📦 Despliega: EnhancedSmartStakingRewards
⏳ Espera confirmaciones en blockchain
✅ Guarda dirección en deploymentData.staking.rewards
```

#### 1.2 - Deploy Skills Module
```
📦 Despliega: EnhancedSmartStakingSkills
⏳ Espera confirmaciones en blockchain
✅ Guarda dirección en deploymentData.staking.skills
```

#### 1.3 - Deploy Gamification Module
```
📦 Despliega: EnhancedSmartStakingGamification
⏳ Espera confirmaciones en blockchain
✅ Guarda dirección en deploymentData.staking.gamification
```

#### 1.4 - Deploy Core Staking
```
📦 Despliega: EnhancedSmartStakingCore
   Constructor: TREASURY_ADDRESS
⏳ Espera confirmaciones en blockchain
✅ Guarda dirección en deploymentData.staking.core
```

#### 1.5 - Deploy View Module
```
📦 Despliega: EnhancedSmartStakingView
   Constructor: coreAddress (de 1.4)
⏳ Espera confirmaciones en blockchain
✅ Guarda dirección en deploymentData.staking.view
```

#### 1.6 - Configurar Referencias Core → Módulos
```
🔗 Core.setRewardsModule(rewardsAddress)
🔗 Core.setSkillsModule(skillsAddress)
🔗 Core.setGamificationModule(gamificationAddress)
```

#### 1.7 - Configurar Referencias Módulos → Core
```
🔗 SkillsModule.setCoreStakingContract(coreAddress)
🔗 GamificationModule.setCoreStakingContract(coreAddress)
```

---

### FASE 2: Despliegue de Gameified Marketplace

#### 2.1 - Deploy Implementation (UUPS Logic)
```
📦 Despliega: GameifiedMarketplaceCoreV1
✅ Guarda como implementation
```

#### 2.2 - Preparar Datos de Inicialización
```
📝 Encoda: initialize(TREASURY_ADDRESS)
⏳ Espera 10 segundos para indexación en chain
```

#### 2.3 - Deploy UUPS Proxy
```
📦 Despliega: GameifiedMarketplaceProxy
   Constructor: (implementation, initData)
✅ DIRECCIÓN PERMANENTE - Usar para todas las interacciones
```

#### 2.4 - Deploy Skills NFT Module
```
📦 Despliega: GameifiedMarketplaceSkillsV2
   Constructor: proxyAddress
✅ Configura treasury automáticamente
```

#### 2.5 - Deploy Individual Skills Marketplace
```
📦 Despliega: IndividualSkillsMarketplace
   Constructor: TREASURY_ADDRESS
```

#### 2.6 - Deploy Quests Module
```
📦 Despliega: GameifiedMarketplaceQuests
   Constructor: proxyAddress
```

---

### FASE 3: Sincronización Bidireccional

#### 3.1 - Configurar Marketplace → Módulos
```
🔗 Proxy.setSkillsContract(skillsNFTAddress)
🔗 Proxy.setQuestsContract(questsAddress)
🔗 Proxy.setStakingContract(coreAddress)
```

#### 3.2 - Configurar Staking → Marketplace
```
🔗 Core.setMarketplaceAddress(proxyAddress)
🔗 SkillsModule.setMarketplaceContract(proxyAddress)
🔗 GamificationModule.setMarketplaceContract(proxyAddress)
```

#### 3.3 - Configurar Canales de Notificación
```
🔗 SkillsNFT.setStakingContract(coreAddress)
🔗 IndividualSkills.setStakingContract(coreAddress)
🔗 Quests.setStakingContract(coreAddress)
```

#### 3.4 - Asignar UPGRADER_ROLE
```
🔐 Proxy.grantRole(UPGRADER_ROLE, deployer.address)
```

---

### FASE 4: Validación de Sincronización

El script verifica automáticamente que:

✅ **Marketplace → Módulos**
- `Proxy.skillsContractAddress === skillsNFTAddress`
- `Proxy.questsContractAddress === questsAddress`
- `Proxy.stakingContractAddress === coreAddress`

✅ **Staking → Marketplace**
- `Core.marketplaceContract === proxyAddress`
- `SkillsModule.marketplaceContract === proxyAddress`
- `GamificationModule.marketplaceContract === proxyAddress`

✅ **Canales de Notificación**
- `SkillsNFT.stakingContractAddress === coreAddress`
- `IndividualSkills.stakingContractAddress === coreAddress`
- `Quests.stakingContractAddress === coreAddress`

---

### FASE 5: Verificación en Polygonscan (Automática)

- ⏳ Espera 45 segundos para confirmaciones
- 🔍 Verifica 10 contratos automáticamente
- ✅ Publica source code en Polygonscan
- ℹ️ Maneja contratos ya verificados sin errores

---

### FASE 6: Guardado de Información de Despliegue

Genera 3 archivos en `deployments/`:

1. **complete-deployment.json** - Información completa con metadatos
2. **{network}-deployment.json** - Archivo específico por red (polygon-deployment.json)
3. **{network}-addresses.json** - Solo direcciones para referencia rápida

---

## Variables de Entorno

### Obligatorias

```env
# Clave privada del deployer (no compartir)
PRIVATE_KEY=0x...

# Dirección que recibirá comisiones del protocolo
TREASURY_ADDRESS=0x...

# API key para verificación en Polygonscan
POLYGONSCAN_API_KEY=...
```

### Opcionales

```env
# RPC personalizado (si no se usa hardhat.config)
POLYGON_RPC_URL=https://polygon-rpc.com

# Network específica (si se configura en hardhat)
HARDHAT_NETWORK=polygon
```

---

## Ejecución del Script

### Ejecutar en Polygon Mainnet

```bash
# Terminal
npx hardhat run scripts/DeployAllContracts.cjs --network polygon
```

### Ejecutar en Mumbai Testnet

```bash
npx hardhat run scripts/DeployAllContracts.cjs --network mumbai
```

### Con Variables de Entorno Personalizadas

```bash
TREASURY_ADDRESS=0x123... npx hardhat run scripts/DeployAllContracts.cjs --network polygon
```

### Salida Esperada

```
╔════════════════════════════════════════════════════════════════════════════════╗
║  🚀 NUXCHAIN PROTOCOL - COMPLETE DEPLOYMENT v6.0                             ║
║                                                                                ║
║  ✅ EnhancedSmartStaking (5 modules - Modular + Reusable View contract)       ║
║  ✅ GameifiedMarketplace (UUPS Proxy + 4 sub-modules)                        ║
║  ✅ Complete Bidirectional Synchronization                                    ║
║  ✅ Interface Validation & Automatic Polygonscan Verification                 ║
║                                                                                ║
║  Network: POLYGON                         Chain ID: 137                       ║
╚════════════════════════════════════════════════════════════════════════════════╝

🏦 Treasury Address (from .env): 0x...
📍 Deployer: 0x...
💰 Balance: 45.234 POL
🌐 Network: polygon
⛓️  Chain ID: 137

✅ Compilation completed

⛽ Getting current gas price...
   Using: 45.32 Gwei (no buffer - better for Polygon)

[FASES 1-6...]

✅ COMPLETE DEPLOYMENT SUCCESSFUL!

📋 ENHANCED SMART STAKING (5 MODULAR CONTRACTS):
   Core (Main):       0x...
   Rewards Module:    0x...
   Skills Module:     0x...
   Gamification:      0x...
   View Module:       0x...

📋 GAMEIFIED MARKETPLACE (UUPS PROXY + 4 SUB-MODULES):
   Proxy (PRIMARY):   0x...
   Implementation:    0x...
   Skills NFT:        0x...
   Individual Skills: 0x...
   Quests:            0x...
```

---

## Validaciones Implementadas

### 1. Validación de Configuración
- ✅ Existencia de `TREASURY_ADDRESS` en .env
- ✅ Balance del deployer ≥ 0 POL
- ✅ RPC disponible y funcional
- ✅ Datos de gas válidos

### 2. Validación de Bytecode
```javascript
await waitForContractCode(address, {
    retries: 20,     // 20 intentos
    delay: 3000,     // Cada 3 segundos
    name: "Contract" // Identificador
})
```
- Verifica que el bytecode esté en la chain
- Reintenta hasta 20 veces
- Espera 3 segundos entre intentos

### 3. Validación de Transacciones
- Espera confirmaciones de bloque
- Valida estado de transacción (status === 1)
- Maneja timeouts (5 minutos máximo por despliegue)

### 4. Validación de Sincronización
- Verifica bidireccionalidad completa
- Compara direcciones en minúsculas (case-insensitive)
- Detalla qué referencias están configuradas

---

## Recuperación ante Errores

### Error: TREASURY_ADDRESS no encontrado

```
❌ TREASURY_ADDRESS not found in .env
```

**Solución:**
```bash
# Agregar a .env
TREASURY_ADDRESS=0xTuDireccionDelTesoreria
```

### Error: Gas Fee Data Inválido

```
❌ Invalid gas fee data from RPC
maxFeePerGas or maxPriorityFeePerGas is null
```

**Soluciones:**
1. Cambiar RPC en hardhat.config
2. Esperar y reintentar (problemas temporales)
3. Establecer gas manual en hardhat.config:
```javascript
networks: {
    polygon: {
        url: process.env.POLYGON_RPC_URL,
        accounts: [process.env.PRIVATE_KEY],
        gasPrice: ethers.parseUnits("50", "gwei")
    }
}
```

### Error: Timeout en Despliegue

```
❌ Deployment timeout after 5 minutes
```

**Soluciones:**
1. Aumentar timeout en script (línea ~108):
```javascript
setTimeout(() => reject(new Error('Timeout')), 600000) // 10 minutos
```
2. Verificar balance de gas
3. Intentar con gas price más bajo
4. Reintentar desde FASE donde falló

### Error: Contrato ya Desplegado

```
❌ Error deploying Core: Contract already exists
```

**Recuperación:**
1. Cambiar `PRIVATE_KEY` a otra cuenta
2. O usar direcciones existentes en una nueva FASE

### Error: Verificación en Polygonscan Falla

```
⚠️  EnhancedSmartStakingCore verification failed
```

**Causas Comunes:**
- Bytecode no indexado (esperar 60+ segundos)
- Constructor arguments incorrectos
- Compilador mismatch (solc version)

**Solución Manual:**
```bash
# Usar comando de hardhat
npx hardhat verify --network polygon 0x... <constructor-args>
```

---

## Archivos Generados

### 1. deployments/complete-deployment.json

Contiene información completa:

```json
{
  "deployment": {
    "network": "polygon",
    "chainId": "137",
    "deployer": "0x...",
    "treasury": "0x...",
    "timestamp": "2025-11-17T15:30:00Z",
    "blockNumber": 58241234
  },
  "staking": {
    "core": {
      "address": "0x...",
      "name": "EnhancedSmartStakingCore",
      "contract": "EnhancedSmartStaking",
      "description": "Core staking contract - Orchestrator"
    },
    ...
  },
  "marketplace": {
    "proxy": {
      "address": "0x...",
      "name": "GameifiedMarketplaceProxy",
      "isPrimary": true,
      ...
    },
    ...
  },
  "synchronization": {
    "bidirectional": {
      "staking_marketplace": { "status": "✅ SYNCHRONIZED" },
      ...
    }
  }
}
```

### 2. deployments/polygon-deployment.json

Copia de `complete-deployment.json` con nombre de red específica.

### 3. deployments/polygon-addresses.json

Referencia rápida solo de direcciones:

```json
{
  "network": "polygon",
  "chainId": "137",
  "timestamp": "2025-11-17T15:30:00Z",
  "staking": {
    "core": "0x...",
    "rewards": "0x...",
    "skills": "0x...",
    "gamification": "0x...",
    "view": "0x..."
  },
  "marketplace": {
    "proxy": "0x...",
    "implementation": "0x...",
    "skillsNFT": "0x...",
    "individualSkills": "0x...",
    "quests": "0x..."
  }
}
```

---

## Verificación en Polygonscan

### Verificación Automática

El script verifica automáticamente en Polygonscan si:
- Red es Polygon o Mumbai
- `POLYGONSCAN_API_KEY` está configurado

### Contratos Verificados

| # | Contrato | Función |
|---|----------|---------|
| 1 | EnhancedSmartStakingRewards | Rewards & APY |
| 2 | EnhancedSmartStakingSkills | Skill Activation |
| 3 | EnhancedSmartStakingGamification | XP & Levels |
| 4 | EnhancedSmartStakingView | Read-only Queries |
| 5 | EnhancedSmartStaking (Core) | Core Staking |
| 6 | GameifiedMarketplaceCoreV1 | Implementation (UUPS) |
| 7 | GameifiedMarketplaceProxy | UUPS Proxy |
| 8 | GameifiedMarketplaceSkillsV2 | NFT Skills |
| 9 | IndividualSkillsMarketplace | Direct Skills |
| 10 | GameifiedMarketplaceQuests | Quests System |

### Verificación Manual

```bash
npx hardhat verify --network polygon <ADDRESS> <ARGS>

# Ejemplo:
npx hardhat verify --network polygon 0x... 0xTreasuryAddress
```

---

## Troubleshooting

### Problema: Script se queda "esperando"

**Síntomas:** 
- ⏳ Waiting for confirmations (2-5 minutes) - nunca termina
- Última línea de output congelada

**Soluciones:**
1. Presionar Ctrl+C para cancelar
2. Verificar en Polygonscan si la TX se completó
3. Si se completó, ejecutar desde la siguiente FASE
4. Si no se completó, intentar de nuevo (reintentos automáticos después de 5 min)

### Problema: Error "Cannot redeclare variable"

**Síntomas:**
```
Cannot redeclare block-scoped variable 'SkillsFactory'
```

**Solución:**
Ya está solucionado en v6.0. Si persiste:
```bash
# Limpiar cache
rm -rf cache/ artifacts/

# Recompilar
npx hardhat compile

# Reintentar deploy
npx hardhat run scripts/DeployAllContracts.cjs --network polygon
```

### Problema: "Insufficient balance for gas"

**Síntomas:**
```
Error: insufficient funds for gas
```

**Soluciones:**
1. Enviar más POL a la cuenta del deployer
2. Usar account diferente con más fondos
3. Reducir gas en hardhat.config (no recomendado)

### Problema: RPC no responde

**Síntomas:**
```
Error: network does not support ENS
Network timeout
```

**Soluciones:**
1. Cambiar RPC en hardhat.config
2. Verificar conexión a internet
3. Usar RPC público diferente:
   - `https://polygon-rpc.com`
   - `https://rpc-mainnet.matic.network`
   - `https://matic-mainnet.chainstacklabs.com`

### Problema: Verificación en Polygonscan falla

**Síntomas:**
```
⚠️  Already Verified
```

**Causa:** Contrato ya fue verificado anteriormente

**Solución:** Ignorar, el script continúa automáticamente

---

## Mejores Prácticas

### Antes del Despliegue

1. ✅ **Backup de .env** - Guardar copia segura de variables
2. ✅ **Test en Mumbai** - Validar primero en testnet
3. ✅ **Compilación** - Asegurar que compila sin warnings
4. ✅ **Balance suficiente** - Verificar POL disponible
5. ✅ **RPC funcional** - Probar conexión antes

### Durante el Despliegue

1. ✅ **No interrumpir** - Dejar ejecutar hasta finalizar
2. ✅ **Monitorear logs** - Revisar cada FASE
3. ✅ **Guardar output** - Hacer screenshot o export
4. ✅ **Verificar en Polygonscan** - Confirmar direcciones

### Después del Despliegue

1. ✅ **Guardar archivos JSON** - Backup de deployments/
2. ✅ **Validar sincronización** - Verificar referencias cruzadas
3. ✅ **Verificar en Polygonscan** - Confirmar verificación
4. ✅ **Documentar direcciones** - Guardar en ubicación segura
5. ✅ **Testar flujos** - Hacer transacciones de prueba

---

## Casos de Uso

### Despliegue Completo (Primera Vez)

```bash
npx hardhat run scripts/DeployAllContracts.cjs --network polygon
```

Genera:
- 10 contratos desplegados
- Sincronización completa
- Verificación en Polygonscan
- 3 archivos JSON con información

### Redeployment (Si algo falló)

1. Usar cuenta diferente con POL fresco
2. Ejecutar script completo nuevamente
3. Nuevas direcciones se generarán

### Usar Direcciones Existentes (Desarrollo)

```bash
# Editar script para usar direcciones existentes
# O crear script secondary que configure referencias
```

---

## Soporte

Para errores o preguntas:

1. **Revisar sección Troubleshooting** arriba
2. **Consultar logs del script** - Guardar output completo
3. **Verificar transacciones** en Polygonscan
4. **Contactar al equipo** con:
   - Output completo del error
   - Network y chainId
   - Archivo complete-deployment.json (si se generó)

---

## Resumen de Características

✅ **Modular** - 9 módulos independientes  
✅ **Sincronización Bidireccional** - Referencias cruzadas  
✅ **UUPS Proxy** - Upgradeable marketplace  
✅ **Validaciones Automáticas** - Verifica cada paso  
✅ **Verificación en Polygonscan** - Source code público  
✅ **Manejo de Errores** - Recuperación y rollback  
✅ **Documentación JSON** - Archivos de referencia  
✅ **Gas Optimizado** - Sin buffers innecesarios  
✅ **Timeout Protection** - Máximo 5 minutos por despliegue  
✅ **Idempotente** - Se puede reejecutar

---

**Última Actualización:** 17 de Noviembre, 2025  
**Versión del Script:** 6.0.0  
**Mantenedor:** Nuxchain Protocol Team
