# 📜 Scripts de Deploy - Nuxchain Protocol

Este directorio contiene todos los scripts de despliegue para los contratos del protocolo Nuxchain.

## 🚀 Scripts Principales de Deploy

### ✅ Scripts Funcionales (Actualizados con Verificación Automática)

| Script | Contrato(s) | Red Sugerida | Descripción |
|--------|-------------|--------------|-------------|
| `DeployAirdropFactory.cjs` | AirdropFactory | Polygon | Despliega el factory para crear múltiples airdrops |
| `DeployAirdrop.cjs` | Airdrop | Polygon | Despliega un contrato Airdrop individual |
| `DeploySmartStaking.cjs` | SmartStaking | Polygon | Despliega el sistema de staking inteligente |
| `DeployMinerBot.cjs` | MinerBot (5 contratos) | Polygon/ETH | Despliega el ecosistema completo MinerBot Empire |
| `DeployTokenizationApp.cjs` | Marketplace | Polygon/ETH | Despliega el marketplace de NFTs |

### ⚠️ Scripts Obsoletos (Requieren Actualización)

| Script | Estado | Acción Requerida |
|--------|--------|------------------|
| `DeployGame.cjs` | ❌ Obsoleto | Contratos referenciados no existen en el proyecto |
| `DeployToken.cjs` | ❌ Obsoleto | Contrato NUVOToken no existe en el proyecto |

---

## 📖 Cómo Usar los Scripts

### Requisitos Previos

1. **Configurar `.env` con tus claves:**
```env
PRIVATE_KEY=tu_private_key_aqui
POLYGONSCAN_API_KEY=tu_api_key_polygonscan
ETHERSCAN_API_KEY=tu_api_key_etherscan
```

2. **Instalar dependencias:**
```bash
npm install
```

3. **Verificar configuración de red en `hardhat.config.cjs`:**
```javascript
networks: {
  polygon: {
    url: "https://polygon-rpc.com",
    accounts: [process.env.PRIVATE_KEY]
  }
}
```

### Ejecutar un Deploy

#### Sintaxis Básica
```powershell
npx hardhat run scripts/<NombreScript>.cjs --network <nombre-red>
```

#### Ejemplos

**Deploy AirdropFactory en Polygon:**
```powershell
npx hardhat run scripts/DeployAirdropFactory.cjs --network polygon
```

**Deploy SmartStaking en Polygon:**
```powershell
npx hardhat run scripts/DeploySmartStaking.cjs --network polygon
```

**Deploy MinerBot Empire (todos los contratos):**
```powershell
npx hardhat run scripts/DeployMinerBot.cjs --network polygon
```

**Deploy en localhost para testing:**
```powershell
# Terminal 1: Iniciar nodo local
npx hardhat node

# Terminal 2: Desplegar
npx hardhat run scripts/DeployAirdropFactory.cjs --network localhost
```

---

## ✨ Características de los Scripts Actualizados

### 🔄 Verificación Automática con Reintentos

Todos los scripts de deploy funcionales incluyen verificación automática en el explorador de bloques:

- ✅ **Hasta 3 intentos automáticos** por defecto
- ✅ **Detección de "already verified"** - No falla si el contrato ya está verificado
- ✅ **Retraso configurable** entre intentos (7 segundos por defecto)
- ✅ **Manejo inteligente de errores** - Distingue entre errores recuperables y no recuperables
- ✅ **Mensajes informativos** - Feedback claro en cada paso

### 📁 Gestión de Archivos

- ✅ **Guarda direcciones** en `deployments/<network>.json`
- ✅ **No crea carpeta frontend** si no existe (evita errores ENOENT)
- ✅ **Actualiza .env.local** solo si la carpeta frontend existe
- ✅ **Logging detallado** de todas las operaciones

### ⛽ Optimización de Gas

Scripts como `DeploySmartStaking.cjs` y `DeployAirdropFactory.cjs` incluyen:

- 📊 Estimación de gas antes del deploy
- 💰 Cálculo de costo estimado
- ⚡ Buffer de gas configurable (20% por defecto)
- 📈 Display de gas usado y costo real post-deploy

---

## 🛠️ Verificación Manual

Si la verificación automática falla, puedes verificar manualmente:

### Contrato sin argumentos constructor
```powershell
npx hardhat verify --network polygon \
  --contract contracts/Airdrop/AirdropFactory.sol:AirdropFactory \
  0xDIRECCION_CONTRATO
```

### Contrato con argumentos constructor
```powershell
npx hardhat verify --network polygon \
  --contract contracts/SmartStaking/SmartStaking.sol:SmartStaking \
  0xDIRECCION_CONTRATO \
  0xTREASURY_ADDRESS
```

### Contrato con múltiples argumentos
```powershell
npx hardhat verify --network polygon \
  --contract contracts/Airdrop/Airdrops.sol:Airdrop \
  0xDIRECCION_CONTRATO \
  0xTOKEN_ADDRESS \
  604800 \
  86400 \
  2592000
```

---

## 📋 Estructura de Archivos Generados

### deployments/
```
deployments/
├── polygon.json          # Direcciones en Polygon mainnet
├── mumbai.json          # Direcciones en testnet Mumbai
├── sepolia.json         # Direcciones en testnet Sepolia
└── localhost.json       # Direcciones en red local
```

**Formato de archivo:**
```json
{
  "AirdropFactory": "0x123...",
  "SmartStaking": "0x456...",
  "MinerBotToken": "0x789..."
}
```

### frontend/.env.local (si existe carpeta frontend)
```env
# Ejemplo para AirdropFactory
NEXT_PUBLIC_AIRDROP_FACTORY_ADDRESS=0x123...
NEXT_PUBLIC_FACTORY_CHAIN_ID=137
NEXT_PUBLIC_FACTORY_NETWORK=polygon

# Ejemplo para MinerBot
NEXT_PUBLIC_MINERBOT_TOKEN_ADDRESS=0x123...
NEXT_PUBLIC_MINERBOT_NFT_ADDRESS=0x456...
NEXT_PUBLIC_MINERBOT_GAME_ADDRESS=0x789...
```

---

## 🔧 Utilidades y Helpers

### verifyHelper.cjs

Módulo centralizado para verificación de contratos con reintentos.

**Uso básico:**
```javascript
const { verifyContract } = require("./utils/verifyHelper.cjs");

// Verificar un contrato
await verifyContract(
  "0x123...",                                    // address
  "contracts/Token.sol:Token",                   // fully qualified name
  []                                             // constructor args
);

// Verificar con más intentos
await verifyContract(
  "0x123...",
  "contracts/Token.sol:Token",
  [],
  5,      // maxAttempts
  10000   // delayMs
);
```

**Verificar múltiples contratos:**
```javascript
const { verifyMultipleContracts } = require("./utils/verifyHelper.cjs");

const results = await verifyMultipleContracts([
  {
    address: tokenAddress,
    name: "Token",
    fullyQualifiedName: "contracts/Token.sol:Token",
    constructorArgs: []
  },
  {
    address: nftAddress,
    name: "NFT",
    fullyQualifiedName: "contracts/NFT.sol:NFT",
    constructorArgs: [tokenAddress]
  }
]);

// results: { Token: true, NFT: true }
```

### gasHelper.cjs

Helper para cálculos y estimaciones de gas (ya existente).

---

## 🐛 Troubleshooting

### Error: "Contract not present in your project"

**Causa:** El nombre fully-qualified del contrato no coincide con la estructura del proyecto.

**Solución:** Verificar que la ruta incluya las subcarpetas correctas:
```javascript
// ❌ Incorrecto
"contracts/Token.sol:Token"

// ✅ Correcto
"contracts/MinerBotGame/Token.sol:Token"
```

### Error: "Invalid API Key"

**Causa:** No hay API key configurada para el explorador de bloques.

**Solución:** Añadir en `.env`:
```env
POLYGONSCAN_API_KEY=tu_api_key_aqui
```

Y en `hardhat.config.cjs`:
```javascript
etherscan: {
  apiKey: {
    polygon: process.env.POLYGONSCAN_API_KEY
  }
}
```

### Error: ENOENT (frontend/.env.local)

**Causa:** Script antiguo intentaba crear la carpeta frontend.

**Solución:** Los scripts actualizados ya NO crean la carpeta. Si ves este error, actualiza el script según el patrón de los scripts corregidos.

### Error: "Already Verified"

**No es un error:** Los scripts actualizados detectan esto y lo tratan como éxito. Si ves este mensaje, el contrato está correctamente verificado.

### Verificación falla después de 3 intentos

**Posibles causas:**
1. Red lenta o inestable
2. Explorador de bloques saturado
3. Contrato muy grande
4. Rate limit del API

**Soluciones:**
1. Esperar unos minutos y verificar manualmente
2. Aumentar `maxAttempts` en el código
3. Aumentar `delayMs` entre intentos
4. Usar script de verificación manual: `Verify.cjs` o `VerifyContractPolygonscan.cjs`

---

## 📊 Resumen de Mejoras Aplicadas

### Antes ❌
- Sin reintentos en verificación
- Creaba carpeta `frontend/` sin verificar existencia
- Errores mal manejados
- Sin logging detallado
- "Already verified" tratado como error

### Después ✅
- Hasta 3 reintentos automáticos
- Verifica existencia antes de escribir archivos
- Manejo robusto de errores
- Logging informativo en cada paso
- "Already verified" tratado como éxito
- Helper centralizado reutilizable

---

## 🔗 Enlaces Útiles

- [Hardhat Documentation](https://hardhat.org/hardhat-runner/docs/getting-started)
- [Hardhat Verify Plugin](https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-verify)
- [Polygonscan API](https://polygonscan.com/apis)
- [Etherscan API](https://docs.etherscan.io/)

---

## 📝 Notas Adicionales

### Scripts NO de Deploy (Utilitarios)

Los siguientes scripts NO despliegan contratos, son para gestión:

- `AirdropFunds.cjs` - Fondear airdrops
- `ConfigureAirdrop.cjs` - Configurar airdrops
- `CreateAirdrop.cjs` - Crear airdrop desde factory
- `FundSmartStaking.cjs` - Fondear staking
- `ManageAirdrops.cjs` - Gestionar airdrops
- `UnpauseSmartStaking.cjs` - Despausar contratos
- `WithdrawFromSmartStaking.cjs` - Retirar fondos
- `CheckPoolBalance.cjs` - Verificar balances
- `CancelPendingTx.cjs` - Cancelar transacciones
- `UpdateEnv.cjs` - Actualizar variables de entorno
- `Verify.cjs` / `VerifyContractPolygonscan.cjs` - Verificación manual

### Convenciones de Nombres

Todos los scripts siguen la convención `PascalCase` con prefijos descriptivos:
- `Deploy*` - Scripts que despliegan contratos
- `Configure*` - Scripts que configuran contratos existentes
- `Fund*` - Scripts que fondean contratos
- `Manage*` - Scripts de gestión general
- `Verify*` - Scripts de verificación manual

---

**Última actualización:** 10 de octubre de 2025  
**Autor:** LennyDevX  
**Versión:** 2.0 - Con verificación automática y manejo robusto de errores
