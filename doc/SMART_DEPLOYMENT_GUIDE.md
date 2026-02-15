# 🚀 Smart Deployment System V2

Sistema inteligente de deployment para los contratos de Nuxchain Protocol que detecta cambios, sugiere estrategias y preserva direcciones mediante upgrades.

## 📋 Índice

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Modos de Deployment](#modos-de-deployment)
- [Uso](#uso)
- [Arquitectura](#arquitectura)
- [FAQ](#faq)

## ✨ Características

### Detección Automática
- **Análisis de Git**: Detecta contratos modificados desde el último deployment usando git log
- **Fallback Filesystem**: Si git no está disponible, usa timestamps de archivos
- **Categorización**: Agrupa contratos por staking, marketplace, treasury, etc.
- **Dependencias**: Analiza imports y dependencias entre contratos

### Estrategias Inteligentes
- **UPGRADE**: Preserva dirección mediante `upgradeProxy()` (para contratos Core/Proxy)
- **REDEPLOY**: Crea nueva dirección (para módulos que pueden cambiar)
- **Mixed**: Combina ambas estrategias según el contrato

### Gestión de Direcciones
- **Carga Automática**: Lee direcciones existentes desde `deployments/complete-deployment.json` y `.env`
- **Backups**: Crea copias de seguridad timestamped antes de cada deployment
- **Actualización**: Actualiza automáticamente `.env` y archivos de deployment
- **Validación**: Verifica que los contratos existen on-chain

### Interfaz Interactiva
- **Menú CLI**: Sistema de menús con `inquirer.js`
- **Selección por Checkbox**: Elige contratos visualmente
- **Confirmación de Acciones**: Revisión antes de ejecutar
- **Progreso en Tiempo Real**: Visualiza deployment en vivo

### Opciones Avanzadas
- **Dry Run**: Simula deployment sin ejecutar
- **Verificación**: Verifica contratos en Polygonscan automáticamente
- **Gas Optimization**: (Opcional) Sugiere optimizaciones de gas
- **Reporte Detallado**: Genera reporte completo con resultados

## 📦 Requisitos

### Dependencias
```json
{
  "inquirer": "^8.2.5",           // CLI interactivo
  "hardhat": "^2.26.5",            // Framework de desarrollo
  "ethers": "^6.15.0",             // Librería de Ethereum
  "@openzeppelin/hardhat-upgrades": "^3.9.1"  // Sistema de upgrades
}
```

### Configuración de Red
Hardhat configurado con Polygon mainnet o testnet en `hardhat.config.cjs`:

```javascript
networks: {
  polygon: {
    url: process.env.POLYGON_RPC_URL,
    accounts: [process.env.PRIVATE_KEY]
  }
}
```

## 🛠️ Instalación

### 1. Instalar Dependencias
```bash
npm install inquirer@8.2.5
```

### 2. Verificar Estructura
Asegúrate de tener la siguiente estructura:
```
scripts/
  ├── DeploySmartV2.cjs          # Script principal
  └── utils/
      ├── ContractAnalyzer.cjs   # Detección de cambios
      ├── AddressManager.cjs      # Gestión de direcciones
      ├── InteractiveMenu.cjs     # Menús CLI
      └── DeploymentStrategy.cjs  # Ejecución de deployments
```

### 3. Verificar Archivos de Deployment
Debe existir `deployments/complete-deployment.json` con la estructura:
```json
{
  "deployment": {
    "timestamp": "2024-01-15T10:30:00.000Z",
    "network": "polygon"
  },
  "staking": {
    "core": { "address": "0x..." },
    "rewards": "0x...",
    ...
  },
  "marketplace": {
    "proxy": "0x...",
    ...
  }
}
```

## 🎯 Modos de Deployment

### 1. Smart Deploy (Recomendado)
**Detecta automáticamente contratos modificados y sugiere acciones**

```bash
npx hardhat run scripts/DeploySmartV2.cjs --network polygon
```

- Analiza git log desde último deployment
- Muestra reporte de cambios
- Sugiere UPGRADE o REDEPLOY para cada contrato
- Pre-selecciona contratos modificados
- Permite ajustar selección manualmente

**Cuándo usar**: Deployments regulares después de hacer cambios al código

**Estrategia sugerida**:
- Core contracts → UPGRADE (preserva dirección)
- Módulos → REDEPLOY (nueva dirección)

### 2. Upgrade Only
**Actualiza contratos existentes preservando TODAS las direcciones**

- Carga direcciones existentes
- Solo permite seleccionar contratos que ya tienen dirección
- Ejecuta `upgradeProxy()` para todos
- No crea nuevas direcciones

**Cuándo usar**: Bug fixes o mejoras que NO requieren cambiar addresses

**Ventaja**: Frontend no necesita actualizarse

### 3. Deploy New (Fresh)
**Deployment completo con nuevas direcciones**

- Despliega todos los contratos desde cero
- Crea nuevas direcciones para todo
- Útil para nuevas redes o resetear sistema

**Cuándo usar**: 
- Deployment en nueva red (testnet, mainnet)
- Recreación completa del sistema
- Testing en entorno limpio

**⚠️ ADVERTENCIA**: Requiere actualizar frontend con todas las nuevas direcciones

### 4. Custom Selection
**Control manual completo**

- Selecciona contratos manualmente
- Define UPGRADE o DEPLOY para cada uno
- Máxima flexibilidad

**Cuándo usar**: Scenarios complejos con requirements específicos

## 📖 Uso

### Ejemplo Básico

```bash
# 1. Asegúrate de estar en la carpeta del proyecto
cd Nuxchain-protocol

# 2. Ejecuta el script en Polygon
npx hardhat run scripts/DeploySmartV2.cjs --network polygon
```

### Flujo Interactivo

```
╔════════════════════════════════════════════════════════════════╗
║  🚀 NUXCHAIN SMART DEPLOYMENT SYSTEM V2                        ║
╚════════════════════════════════════════════════════════════════╝

📡 Network: polygon
👤 Deployer: 0x1234...
💰 Balance: 125.5 MATIC

📋 Select deployment mode:
  › 🎯 Smart Deploy (Only modified contracts)
    🔄 Upgrade Only (Preserve all addresses)
    🆕 Deploy New (Fresh deployment)
    ✅ Custom Selection (Manual choice)
    ❌ Cancel
```

Después de seleccionar el modo:

```
🎯 SMART MODE: Detecting modified contracts...

╔════════════════════════════════════════════════════════════════╗
║  📊 CONTRACT MODIFICATION REPORT                              ║
╚════════════════════════════════════════════════════════════════╝

STAKING:
• EnhancedSmartStakingRewards
• EnhancedSmartStakingSkills

MARKETPLACE:
• GameifiedMarketplaceSkillsNft

Total: 3 contract(s) modified since 2024-02-10

💡 SUGGESTED STRATEGY:
   Action: mixed

   ⚠️  Warnings:
      EnhancedSmartStakingRewards is a Core module - consider UPGRADE
      
   📋 Recommendations:
      Use UPGRADE for staking to preserve addresses
      REDEPLOY marketplace modules if needed

✅ Select contracts to deploy:
  ━━ STAKING ━━
  ☑ 🟢 EnhancedSmartStakingRewards        (contracts/SmartStaking/...)
  ☑ 🟢 EnhancedSmartStakingSkills         (contracts/SmartStaking/...)
  
  ━━ MARKETPLACE ━━
  ☑ 🟢 GameifiedMarketplaceSkillsNft      (contracts/Marketplace/...)
```

Configuración de opciones:

```
⚙️  Select additional options:
  ☑ 📸 Create backup before deployment
  ☑ 🔍 Verify contracts on Polygonscan
  ☐ 🌡️  Show gas optimization suggestions
  ☐ 🧪 Dry run (simulate without deploying)
  ☑ 💾 Update .env file automatically
```

Confirmación:

```
╔════════════════════════════════════════════════════════════════╗
║  📋 DEPLOYMENT PLAN SUMMARY                                   ║
╚════════════════════════════════════════════════════════════════╝

Mode: SMART
Total contracts: 3

🔄 UPGRADE (Preserve addresses):
   • EnhancedSmartStakingRewards (staking)
   • EnhancedSmartStakingSkills (staking)

🆕 NEW DEPLOYMENT (New addresses):
   • GameifiedMarketplaceSkillsNft (marketplace)

⚠️  WARNINGS:
   Staking contracts will preserve existing addresses
   Marketplace will have new address

🚀 Proceed with deployment? (y/N)
```

Ejecución:

```
💾 Creating backup of current addresses...
💾 Backup created: backup-polygon-2024-02-15T14-30-00.json

╔════════════════════════════════════════════════════════════════╗
║  ⚡ EXECUTING DEPLOYMENT STRATEGY                            ║
╚════════════════════════════════════════════════════════════════╝

🔄 Upgrading EnhancedSmartStakingRewards at 0xEB02b4cC...
   Deploying new implementation...
   ✅ Upgraded successfully
   📍 Proxy: 0xEB02b4cC589B7017e621a8b4A02295793d6cB32E
   📍 Implementation: 0x9876...

🔄 Upgrading EnhancedSmartStakingSkills at 0x2c8E2A59...
   Deploying new implementation...
   ✅ Upgraded successfully
   📍 Proxy: 0x2c8E2A5902dACEd9705e5AB9A3eE2EdAAe0e7F38
   📍 Implementation: 0x5432...

🚀 Deploying GameifiedMarketplaceSkillsNft...
   Deploying as uups proxy...
   ✅ Deployed successfully
   📍 Proxy: 0x987f...
   📍 Implementation: 0x1234...

💾 Updating addresses...
💾 Deployment file updated: complete-deployment.json
💾 .env file updated with 1 addresses

🔍 Verifying contracts on Polygonscan...
   Verifying EnhancedSmartStakingRewards...
   ✅ Verified EnhancedSmartStakingRewards
   ...

╔════════════════════════════════════════════════════════════════╗
║  ✅ DEPLOYMENT COMPLETED                                      ║
╚════════════════════════════════════════════════════════════════╝

✅ SUCCESSFULLY UPGRADED:
   EnhancedSmartStakingRewards        → 0xEB02b4cC589B7017e621a8b4A02295793d6cB32E
   EnhancedSmartStakingSkills         → 0x2c8E2A5902dACEd9705e5AB9A3eE2EdAAe0e7F38

🆕 SUCCESSFULLY DEPLOYED:
   GameifiedMarketplaceSkillsNft      → 0x987f...

💾 Backup saved: backup-polygon-2024-02-15T14-30-00.json

🎉 Deployment session completed at 2/15/2024, 2:30:00 PM
```

## 🏗️ Arquitectura

### Módulos del Sistema

#### 1. ContractAnalyzer
**Responsabilidad**: Detectar cambios y analizar contratos

Métodos principales:
```javascript
detectModifiedContracts(sinceDate)
  // Detecta contratos modificados desde una fecha
  // Usa git log o filesystem timestamps

getContractDependencies(contractPath)
  // Analiza imports y dependencias

suggestDeploymentStrategy(modifiedContracts)
  // Sugiere UPGRADE o REDEPLOY para cada contrato
  // Basado en: tipo (Core/Proxy/Module), categoría, cambios

categorizeContract(filePath)
  // Clasifica: staking, marketplace, treasury, other
```

**Lógica de Sugerencias**:
- Si `name.includes('Core')` → UPGRADE (preservar dirección)
- Si `name.includes('Proxy')` → UPGRADE (UUPS proxy)
- Si módulo independiente → REDEPLOY (seguro cambiar)

#### 2. AddressManager
**Responsabilidad**: Gestionar direcciones de contratos deployados

Métodos principales:
```javascript
loadExistingAddresses()
  // Carga desde complete-deployment.json y .env
  // Merge y retorna: {staking: {}, marketplace: {}, ...}

backupAddresses(addresses)
  // Crea backup-{network}-{timestamp}.json
  // Guarda en deployments/

updateAddresses(newAddresses, options)
  // Actualiza .env y complete-deployment.json
  // Merge con existentes

validateExistingContract(address)
  // Verifica on-chain con eth_getCode
  // Detecta si es proxy
```

**Mapeo de Keys**:
- `.env`: `VITE_ENHANCED_SMARTSTAKING_ADDRESS`
- Deployment: `staking.core`
- Código: `EnhancedSmartStakingCore`

#### 3. InteractiveMenu
**Responsabilidad**: Interfaz CLI para usuario

Métodos principales:
```javascript
showMainMenu()
  // Menú principal con 5 opciones
  // Retorna: 'smart', 'upgrade', 'fresh', 'custom', 'cancel'

showContractSelection(contracts, preselected)
  // Checkboxes agrupados por categoría
  // Retorna: array de contratos seleccionados

confirmDeployment(contracts, strategy, gasEstimate)
  // Muestra resumen y pide confirmación
  // Retorna: boolean

showFinalResult(result)
  // Reporte final con deployed/upgraded/failed
```

**Features UI**:
- Separadores por categoría (━━ STAKING ━━)
- Icons de estado (🟢 seleccionado, ⚪ no seleccionado)
- Paginación (15 items por página)
- Validación (al menos 1 contrato)

#### 4. DeploymentStrategy
**Responsabilidad**: Ejecutar deployments y upgrades

Métodos principales:
```javascript
executeUpgrade(contractName, proxyAddress, options)
  // Ejecuta upgrades.upgradeProxy()
  // Valida que proxy existe
  // Obtiene nueva implementation address

executeDeploy(contractName, constructorArgs, options)
  // Deploy como proxy o regular
  // Maneja UUPS, Transparent, beacon

executeStrategy(contracts, strategy, existingAddresses)
  // Orquesta deployment completo
  // Itera contratos, aplica acción correcta
  // Retorna resultados completos

verifyDeployment(address)
  // Verifica bytecode on-chain
  // Detecta si es proxy
  // Valida implementation si es proxy
```

**Deploy Configs** (getDeployConfig):
```javascript
{
  'EnhancedSmartStakingCore': {
    args: [],
    options: { isProxy: true, kind: 'uups', initializer: 'initialize' }
  },
  'EnhancedSmartStakingRewards': {
    args: [],
    options: { isProxy: false }  // Módulo, no es proxy
  }
}
```

### Flujo de Datos

```
1. Usuario ejecuta DeploySmartV2.cjs
         ↓
2. Initialize() → carga red, signer, balance
         ↓
3. showMainMenu() → usuario elige modo
         ↓
4. Modo Smart:
   - ContractAnalyzer.detectModifiedContracts()
   - suggestDeploymentStrategy()
   - showContractSelection()
         ↓
5. showOptions() → backup, verify, dry-run, etc.
         ↓
6. confirmDeployment() → muestra plan completo
         ↓
7. Si confirmado:
   - AddressManager.backupAddresses()
   - DeploymentStrategy.executeStrategy()
   - AddressManager.updateAddresses()
   - verifyContracts() en Polygonscan
         ↓
8. showFinalResult() → reporte de resultados
```

## ❓ FAQ

### ¿Qué pasa si no hay archivos de deployment previos?

El sistema trata todos los contratos como "nuevos" y sugiere DEPLOY para todos. Puedes usar el modo "Fresh" directamente.

### ¿Cómo sabe qué contratos fueron modificados?

1. **Método primario (Git)**: Ejecuta `git log --since=[lastDeploymentDate] --name-only -- contracts/`
2. **Fallback (Filesystem)**: Compara `stat.mtimeMs` de archivos con timestamp del último deployment
3. **Sin deployment previo**: Considera todos modificados

### ¿Puedo cambiar la acción sugerida?

Sí, en modo "Custom" puedes elegir UPGRADE o DEPLOY para cada contrato individualmente.

### ¿Qué es un "Dry Run"?

Simula el deployment sin ejecutar transacciones. Muestra qué se deployaría pero no consume gas ni modifica la blockchain.

### ¿Los backups se crean automáticamente?

Sí, si la opción "Create backup" está habilitada (por defecto). Se guardan en `deployments/backup-{network}-{timestamp}.json`.

### ¿Cómo recuperar una dirección de un backup?

Los backups son archivos JSON legibles:
```json
{
  "network": "polygon",
  "timestamp": "2024-02-15T14:30:00.000Z",
  "addresses": {
    "staking": {
      "core": "0x...",
      ...
    }
  }
}
```

Puedes copiar las direcciones a `.env` o `complete-deployment.json` manualmente.

### ¿Qué pasa si falla un deployment a mitad del proceso?

El sistema continúa con los demás contratos y reporta los fallidos al final. Los contratos exitosos SE deployaron, los fallidos NO. Revisa el reporte final.

### ¿Los módulos de staking son proxies?

NO. Solo `EnhancedSmartStakingCore` es un proxy UUPS. Los módulos (Rewards, Skills, Gamification, View) son contratos regulares que el Core referencia por dirección.

### ¿Puedo detener el deployment una vez iniciado?

Durante la confirmación puedes cancelar. Una vez que inicia el deployment **NO** se puede detener (las transacciones ya están en blockchain).

### ¿Cómo actualizar solo un contrato?

Modo "Custom" → Selecciona solo ese contrato → Elige UPGRADE o DEPLOY.

### ¿La verificación en Polygonscan es obligatoria?

No, es opcional. Puedes deshabilitarla en las opciones o verificar manualmente después.

## 🔧 Troubleshooting

### Error: "inquirer is not installed"
```bash
npm install inquirer@8.2.5
```

### Error: "No deployment file found"
Primera vez usando el sistema. Usa modo "Fresh" para crear deployment inicial.

### Error: "No contract found at proxy address"
La dirección en tu archivo de deployment no existe on-chain. Verifica:
- ¿Estás en la red correcta?
- ¿El contrato fue deployado realmente?
- ¿La dirección en .env es correcta?

### Error: "Insufficient funds"
El deployer no tiene suficiente MATIC. Transfiere más a la dirección del deployer.

### Git no detecta cambios
Si git no está disponible, el sistema usa timestamps de archivos. Asegúrate de que los archivos `.sol` tengan timestamp reciente.

## 📝 Notas Importantes

1. **Staking Addresses**: Siempre usa UPGRADE para preservar direcciones y evitar actualizar frontend
2. **Marketplace**: Puede tener nuevas direcciones sin problema (frontend se actualiza fácil)
3. **Backups**: Siempre crea backup antes de deployar en mainnet
4. **Dry Run**: Usa dry-run primero para verificar el plan
5. **Gas**: Ten suficiente MATIC para deployments completos (~0.5-2 MATIC)
6. **Network**: Verifica que estás en la red correcta ANTES de confirmar

## 🎯 Mejores Prácticas

### Antes de Deployar
- [ ] Compilar contratos: `npx hardhat compile`
- [ ] Ejecutar tests: `npx hardhat test`
- [ ] Verificar .env tiene variables correctas
- [ ] Verificar balance del deployer
- [ ] Hacer commit de cambios a git

### Durante Deployment
- [ ] Usar modo "Smart" en primera instancia
- [ ] Revisar sugerencias del sistema
- [ ] Habilitar backup
- [ ] Habilitar verificación en Polygonscan
- [ ] Usar dry-run primero si no estás seguro

### Después de Deployar
- [ ] Verificar que todos los contratos se deployaron correctamente
- [ ] Revisar `.env` tiene direcciones actualizadas
- [ ] Actualizar frontend si hubo nuevas direcciones
- [ ] Guardar backup en lugar seguro
- [ ] Hacer commit de deployment artifacts
- [ ] Testing post-deployment

---

**Creado por**: Nuxchain Team  
**Versión**: 2.0  
**Última actualización**: Febrero 2024
