# MinerBot Empire - Documentación Técnica

## Descripción General

MinerBot Empire es un juego blockchain innovador que combina mecánicas de minería idle con un ecosistema NFT robusto. Los jugadores pueden adquirir, mejorar y gestionar robots mineros NFT para generar tokens MBT de forma pasiva, mientras participan en un mercado descentralizado dinámico y un sistema de staking avanzado.

## Características Principales

### 🤖 Sistema de NFT Robots
- **Robots únicos**: Cada NFT tiene atributos únicos (rareza, tipo, nivel, poder de minería, batería, comunicación, almacenamiento, durabilidad, eficiencia)
- **Sistema de evolución**: Los robots pueden subir de nivel y mejorar sus capacidades mediante experiencia
- **Durabilidad dinámica**: Sistema de mantenimiento que requiere gestión activa y afecta la eficiencia
- **Breeding avanzado**: Posibilidad de crear nuevos robots combinando existentes con herencia de atributos
- **Metadata on-chain**: Información completa del NFT almacenada directamente en blockchain

### ⛏️ Mecánicas de Minería Idle
- **Minería pasiva**: Los robots generan MBT automáticamente basado en sus atributos
- **Optimización estratégica**: Diferentes configuraciones y tipos de robot afectan la eficiencia
- **Eventos especiales**: Bonificaciones temporales, eventos de lluvia de tokens y desafíos
- **Sistema de energía y reputación**: Gestión de recursos para maximizar ganancias
- **Penalizaciones dinámicas**: Sistema anti-fraude que detecta patrones sospechosos

### 💰 Tokenomics Equilibradas
- **Token MBT**: Moneda principal del ecosistema con suministro total de 1 billón
- **Suministro controlado**: Mecanismos deflacionarios integrados con quema de tokens
- **Distribución justa**: Sistema anti-ballena con límites de transacción del 1% del suministro
- **Utilidad múltiple**: Usado para minting, mejoras, marketplace, staking y mantenimiento
- **Recompensas de juego**: Minteo controlado para recompensas de minería y staking

### 🏦 Sistema de Staking Avanzado
- **Múltiples pools**: 4 pools con diferentes duraciones (30, 90, 180, 365 días) y APY (10%, 15%, 20%, 25%)
- **Staking flexible**: Montos desde 100 MBT hasta 1M MBT por pool
- **Bonificaciones por lealtad**: 2% adicional después de 90 días
- **Anti-fraude integrado**: Detección de patrones sospechosos y límites de acciones diarias
- **Retiro de emergencia**: Disponible con penalización del 5%

### 🛒 Marketplace Descentralizado
- **Compra/venta de NFTs**: Mercado peer-to-peer con precios fijos
- **Sistema de subastas**: Subastas con precio de reserva y extensión automática
- **Ofertas directas**: Negociación flexible entre usuarios
- **Comisiones competitivas**: 2.5% de fee del marketplace
- **Gestión de fondos**: Sistema de retiros pendientes para seguridad

### 🛡️ Medidas Anti-Fraude Avanzadas
- **Detección multi-nivel**: Algoritmos de seguridad en todos los contratos
- **Límites dinámicos**: Prevención de manipulación con límites adaptativos
- **Sistema de reputación**: Tracking completo de comportamiento de usuarios
- **Pausas de emergencia**: Controles de seguridad integrados en todos los contratos
- **Baneos automáticos**: Sistema de suspensión por actividad sospechosa

## 📋 Contratos Inteligentes

### MinerBotGame.sol
**Contrato principal del juego - Lógica central de minería**
- **Gestión de robots**: Registro y tracking de robots NFT activos en minería
- **Sistema de zonas**: 5 zonas de minería con diferentes multiplicadores y dificultades
- **Cálculo de recompensas**: Algoritmo complejo basado en atributos del robot, zona, tiempo y eventos
- **Sistema de energía**: Gestión de energía por robot con regeneración automática
- **Sistema de reputación**: Tracking de comportamiento del jugador con bonificaciones/penalizaciones
- **Eventos especiales**: Rain events, multiplicadores temporales y eventos de bonificación
- **Anti-fraude avanzado**: Detección de patrones sospechosos, límites de acciones y baneos automáticos
- **Mantenimiento de robots**: Sistema de durabilidad que afecta la eficiencia de minería
- **Funciones de administración**: Configuración de parámetros, pausas de emergencia y gestión de eventos

### MinerBotToken.sol
**Token ERC20 principal (MBT) - Economía del juego**
- **Suministro controlado**: 1 billón de tokens con distribución específica por categorías
- **Distribución automática**: Asignación automática según tokenomics predefinidas
- **Mecanismo deflacionario**: Quema de tokens en transacciones específicas para controlar inflación
- **Protección anti-ballena**: Límites del 1% del suministro total por transacción
- **Sistema de autorización**: Whitelist de contratos autorizados para minteo de recompensas
- **Funciones de emergencia**: Pausas de contrato y recuperación de tokens
- **Compatibilidad**: Interfaz estándar ERC20 con extensiones para gaming

### MinerBotNFT.sol
**Colección de robots NFT (ERC721) - Activos del juego**
- **Sistema de rareza**: 5 niveles (Common a Legendary) con costos de minting diferenciados
- **Atributos complejos**: 9 atributos por robot (tipo, rareza, nivel, mining power, batería, comunicación, storage, durabilidad, eficiencia, experiencia)
- **Generación procedural**: Algoritmo de generación aleatoria de atributos basado en rareza
- **Sistema de breeding**: Combinación de dos robots para crear descendencia con herencia de atributos
- **Evolución dinámica**: Sistema de experiencia y level-up que mejora atributos
- **Metadata on-chain**: JSON completo almacenado en blockchain con todos los atributos
- **Sistema de durabilidad**: Desgaste que afecta eficiencia y requiere mantenimiento
- **Funciones de administración**: Configuración de costos, autorización de minters y pausas

### MinerBotMarketplace.sol
**Marketplace descentralizado - Comercio de NFTs**
- **Listados flexibles**: Venta a precio fijo con configuración de duración
- **Sistema de subastas**: Subastas con precio de reserva, extensión automática y gestión de pujas
- **Ofertas directas**: Sistema de ofertas peer-to-peer con aceptación manual
- **Gestión de fondos**: Sistema de retiros pendientes para seguridad en transacciones
- **Comisiones competitivas**: 2.5% de fee con destinatario configurable
- **Protección avanzada**: ReentrancyGuard y validaciones exhaustivas
- **Estadísticas**: Tracking de volumen total y fees generados
- **Funciones de administración**: Configuración de fees, pausas y retiros de emergencia

### MinerBotStaking.sol
**Sistema de staking avanzado - Recompensas pasivas**
- **Múltiples pools**: 4 pools predefinidos con duraciones de 30, 90, 180 y 365 días
- **APY diferenciado**: Tasas de 10%, 15%, 20% y 25% respectivamente por pool
- **Staking flexible**: Rangos de stake desde 100 MBT hasta 1M MBT por pool
- **Bonificaciones por lealtad**: 2% adicional después de 90 días de staking
- **Sistema anti-fraude**: Detección de patrones sospechosos, límites de acciones diarias y baneos
- **Retiro de emergencia**: Disponible con penalización del 5% para liquidez inmediata
- **Gestión de recompensas**: Minteo automático de recompensas usando interfaz del token
- **Estadísticas detalladas**: Tracking completo de stakes, pools y actividad de usuarios
- **Funciones de administración**: Configuración de pools, penalizaciones y gestión de usuarios

## 🔧 Instalación y Configuración

### Prerrequisitos
```bash
# Node.js 18+ y npm
node --version  # >= 18.0.0
npm --version   # >= 8.0.0

# Hardhat para desarrollo
npm install --global hardhat

# Git para control de versiones
git --version
```

### Instalación del Proyecto
```bash
# Clonar repositorio
git clone <repository-url>
cd Nuvos-SC

# Instalar dependencias
npm install

# Verificar instalación
npx hardhat --version
```

### Configuración de Variables de Entorno
```bash
# Crear archivo de configuración
cp .env.example .env

# Configurar variables necesarias en .env:
# PRIVATE_KEY=tu_clave_privada_aqui
# SEPOLIA_URL=https://sepolia.infura.io/v3/tu_project_id
# MAINNET_URL=https://mainnet.infura.io/v3/tu_project_id
# ETHERSCAN_API_KEY=tu_api_key_de_etherscan
```

### Configuración de Red
```javascript
// hardhat.config.js - Configuración de redes
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337
    },
    sepolia: {
      url: process.env.SEPOLIA_URL,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 11155111
    },
    mainnet: {
      url: process.env.MAINNET_URL,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 1
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
```

## 🧪 Testing

### Ejecutar Tests
```bash
# Compilar contratos
npx hardhat compile

# Ejecutar todos los tests
npx hardhat test

# Ejecutar tests específicos por contrato
npx hardhat test test/MinerBotToken.test.js
npx hardhat test test/MinerBotNFT.test.js
npx hardhat test test/MinerBotGame.test.js
npx hardhat test test/MinerBotStaking.test.js
npx hardhat test test/MinerBotMarketplace.test.js

# Tests con reporte de gas
npx hardhat test --gas-reporter

# Tests con coverage
npx hardhat coverage

# Tests en red local
npx hardhat node  # Terminal 1
npx hardhat test --network localhost  # Terminal 2
```

### Estructura de Tests
- **Unit Tests**: Pruebas individuales de cada función de contrato
- **Integration Tests**: Pruebas de interacción entre múltiples contratos
- **Security Tests**: Pruebas de reentrancy, overflow, access control
- **Gas Optimization Tests**: Análisis de consumo de gas y optimizaciones
- **Edge Case Tests**: Pruebas de casos límite y manejo de errores

### Cobertura de Tests
- **Cobertura mínima objetivo**: 95%
- **Funciones críticas**: 100% de cobertura
- **Casos de error**: Todos los require/revert cubiertos
- **Eventos**: Verificación de emisión correcta

### Tests de Seguridad
```bash
# Análisis estático con Slither
pip install slither-analyzer
slither contracts/

# Tests de fuzzing con Echidna
echidna-test contracts/MinerBotGame.sol
```

## 🚀 Deployment

### Red Local (Hardhat)
```bash
# Iniciar nodo local
npx hardhat node

# Deploy en otra terminal
npx hardhat run scripts/deploy.js --network localhost

# Verificar deployment
npx hardhat run scripts/verify-deployment.js --network localhost
```

### Testnet (Sepolia)
```bash
# Deploy en Sepolia
npx hardhat run scripts/deploy.js --network sepolia

# Verificar contratos en Etherscan
npx hardhat verify --network sepolia DEPLOYED_CONTRACT_ADDRESS

# Configurar contratos después del deploy
npx hardhat run scripts/configure-contracts.js --network sepolia
```

### Mainnet
```bash
# Deploy en mainnet (¡VERIFICAR TODO ANTES!)
npx hardhat run scripts/deploy.js --network mainnet

# Verificar contratos
npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS

# Configuración post-deployment
npx hardhat run scripts/configure-contracts.js --network mainnet
```

### Orden de Deployment
1. **MinerBotToken** - Token principal del ecosistema
2. **MinerBotNFT** - Colección de robots NFT
3. **MinerBotGame** - Lógica principal del juego
4. **MinerBotStaking** - Sistema de staking de tokens
5. **MinerBotMarketplace** - Marketplace descentralizado
6. **Configuración** - Autorizar contratos y configurar parámetros iniciales

### Scripts de Deployment
```bash
# Script completo de deployment
npx hardhat run scripts/full-deploy.js --network <network>

# Script de configuración post-deployment
npx hardhat run scripts/post-deploy-config.js --network <network>

# Script de verificación de deployment
npx hardhat run scripts/verify-deployment.js --network <network>
```

##### 🔐 Verificación de Contratos

```bash
# Verificar en Etherscan
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>

# Verificar múltiples contratos
npx hardhat run scripts/verify-all-contracts.js --network sepolia
```

## 🌐 Desarrollo de Frontend

### Configuración Inicial

#### Dependencias Necesarias
```bash
# Instalar librerías para interacción con blockchain
npm install ethers wagmi viem
npm install @rainbow-me/rainbowkit  # Para wallet connection
npm install @tanstack/react-query   # Para manejo de estado
```

#### Configuración de Contratos
```javascript
// contracts/config.js
export const CONTRACTS = {
  MinerBotToken: {
    address: "0x...",
    abi: MinerBotTokenABI
  },
  MinerBotNFT: {
    address: "0x...",
    abi: MinerBotNFTABI
  },
  MinerBotGame: {
    address: "0x...",
    abi: MinerBotGameABI
  },
  MinerBotStaking: {
    address: "0x...",
    abi: MinerBotStakingABI
  },
  MinerBotMarketplace: {
    address: "0x...",
    abi: MinerBotMarketplaceABI
  }
};

export const CHAIN_CONFIG = {
  chainId: 1, // Mainnet
  name: 'Ethereum',
  currency: 'ETH',
  rpcUrl: 'https://mainnet.infura.io/v3/YOUR_PROJECT_ID'
};
```

### Funciones Principales para Frontend

#### 1. Gestión de Tokens MBT
```javascript
// hooks/useMBTToken.js
import { useContractRead, useContractWrite } from 'wagmi';

export function useMBTToken() {
  // Leer balance
  const { data: balance } = useContractRead({
    address: CONTRACTS.MinerBotToken.address,
    abi: CONTRACTS.MinerBotToken.abi,
    functionName: 'balanceOf',
    args: [userAddress]
  });

  // Aprobar tokens
  const { write: approve } = useContractWrite({
    address: CONTRACTS.MinerBotToken.address,
    abi: CONTRACTS.MinerBotToken.abi,
    functionName: 'approve'
  });

  return { balance, approve };
}
```

#### 2. Gestión de NFTs
```javascript
// hooks/useNFTRobots.js
export function useNFTRobots() {
  // Obtener robots del usuario
  const { data: userRobots } = useContractRead({
    address: CONTRACTS.MinerBotNFT.address,
    abi: CONTRACTS.MinerBotNFT.abi,
    functionName: 'tokensOfOwner',
    args: [userAddress]
  });

  // Mintear nuevo robot
  const { write: mintRobot } = useContractWrite({
    address: CONTRACTS.MinerBotNFT.address,
    abi: CONTRACTS.MinerBotNFT.abi,
    functionName: 'mintRobot'
  });

  // Obtener atributos de robot
  const getRobotAttributes = async (tokenId) => {
    const attributes = await readContract({
      address: CONTRACTS.MinerBotNFT.address,
      abi: CONTRACTS.MinerBotNFT.abi,
      functionName: 'getRobotAttributes',
      args: [tokenId]
    });
    return attributes;
  };

  return { userRobots, mintRobot, getRobotAttributes };
}
```

#### 3. Sistema de Minería
```javascript
// hooks/useMining.js
export function useMining() {
  // Iniciar minería
  const { write: startMining } = useContractWrite({
    address: CONTRACTS.MinerBotGame.address,
    abi: CONTRACTS.MinerBotGame.abi,
    functionName: 'startMining'
  });

  // Reclamar recompensas
  const { write: claimRewards } = useContractWrite({
    address: CONTRACTS.MinerBotGame.address,
    abi: CONTRACTS.MinerBotGame.abi,
    functionName: 'claimRewards'
  });

  // Calcular recompensas pendientes
  const { data: pendingRewards } = useContractRead({
    address: CONTRACTS.MinerBotGame.address,
    abi: CONTRACTS.MinerBotGame.abi,
    functionName: 'calculateRewards',
    args: [userAddress, robotId]
  });

  return { startMining, claimRewards, pendingRewards };
}
```

#### 4. Sistema de Staking
```javascript
// hooks/useStaking.js
export function useStaking() {
  // Hacer stake
  const { write: stake } = useContractWrite({
    address: CONTRACTS.MinerBotStaking.address,
    abi: CONTRACTS.MinerBotStaking.abi,
    functionName: 'stake'
  });

  // Obtener información de pools
  const { data: pools } = useContractRead({
    address: CONTRACTS.MinerBotStaking.address,
    abi: CONTRACTS.MinerBotStaking.abi,
    functionName: 'stakingPools',
    args: [poolId]
  });

  // Obtener stakes del usuario
  const { data: userStakes } = useContractRead({
    address: CONTRACTS.MinerBotStaking.address,
    abi: CONTRACTS.MinerBotStaking.abi,
    functionName: 'getUserStakes',
    args: [userAddress]
  });

  return { stake, pools, userStakes };
}
```

#### 5. Marketplace
```javascript
// hooks/useMarketplace.js
export function useMarketplace() {
  // Listar NFT
  const { write: listItem } = useContractWrite({
    address: CONTRACTS.MinerBotMarketplace.address,
    abi: CONTRACTS.MinerBotMarketplace.abi,
    functionName: 'listItem'
  });

  // Comprar NFT
  const { write: buyItem } = useContractWrite({
    address: CONTRACTS.MinerBotMarketplace.address,
    abi: CONTRACTS.MinerBotMarketplace.abi,
    functionName: 'buyItem'
  });

  // Obtener listings activos
  const { data: activeListings } = useContractRead({
    address: CONTRACTS.MinerBotMarketplace.address,
    abi: CONTRACTS.MinerBotMarketplace.abi,
    functionName: 'getActiveListings',
    args: [0, 50] // offset, limit
  });

  return { listItem, buyItem, activeListings };
}
```

### Componentes de UI Recomendados

#### Dashboard Principal
```javascript
// components/Dashboard.jsx
export function Dashboard() {
  const { balance } = useMBTToken();
  const { userRobots } = useNFTRobots();
  const { pendingRewards } = useMining();

  return (
    <div className="dashboard">
      <div className="stats">
        <div>Balance MBT: {balance}</div>
        <div>Robots: {userRobots?.length}</div>
        <div>Recompensas Pendientes: {pendingRewards}</div>
      </div>
      <RobotGrid robots={userRobots} />
      <MiningPanel />
      <StakingPanel />
    </div>
  );
}
```

#### Panel de Minería
```javascript
// components/MiningPanel.jsx
export function MiningPanel() {
  const { startMining, claimRewards } = useMining();
  const [selectedRobot, setSelectedRobot] = useState(null);
  const [selectedZone, setSelectedZone] = useState(0);

  return (
    <div className="mining-panel">
      <h3>Centro de Minería</h3>
      <RobotSelector onSelect={setSelectedRobot} />
      <ZoneSelector onSelect={setSelectedZone} />
      <button onClick={() => startMining(selectedRobot, selectedZone)}>
        Iniciar Minería
      </button>
      <button onClick={() => claimRewards(selectedRobot)}>
        Reclamar Recompensas
      </button>
    </div>
  );
}
```

### Manejo de Eventos

```javascript
// hooks/useContractEvents.js
import { useContractEvent } from 'wagmi';

export function useContractEvents() {
  // Escuchar eventos de minería
  useContractEvent({
    address: CONTRACTS.MinerBotGame.address,
    abi: CONTRACTS.MinerBotGame.abi,
    eventName: 'MiningStarted',
    listener: (logs) => {
      console.log('Minería iniciada:', logs);
      // Actualizar UI
    }
  });

  // Escuchar eventos de marketplace
  useContractEvent({
    address: CONTRACTS.MinerBotMarketplace.address,
    abi: CONTRACTS.MinerBotMarketplace.abi,
    eventName: 'ItemSold',
    listener: (logs) => {
      console.log('Item vendido:', logs);
      // Actualizar listings
    }
  });
}
```

### Utilidades y Helpers

```javascript
// utils/formatters.js
export const formatMBT = (amount) => {
  return (Number(amount) / 10**18).toFixed(2);
};

export const formatRarity = (rarity) => {
  const rarities = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary'];
  return rarities[rarity] || 'Unknown';
};

export const calculateAPY = (poolId) => {
  const apys = [10, 15, 20, 25]; // Por pool
  return apys[poolId] || 0;
};
```

## 🚧 Áreas de Desarrollo Pendientes

### Funcionalidades Críticas para Implementar

#### 1. Sistema de Autenticación y Wallet
- **Conexión de Wallet**: Integración con MetaMask, WalletConnect, Coinbase Wallet
- **Gestión de Sesión**: Persistencia de conexión y manejo de desconexiones
- **Verificación de Red**: Validación de que el usuario esté en la red correcta
- **Manejo de Errores**: Gestión de errores de conexión y transacciones fallidas

#### 2. Dashboard de Usuario
- **Panel de Control Principal**: Vista general de activos, recompensas y estadísticas
- **Gestión de Robots**: Visualización de robots NFT con sus atributos y estados
- **Historial de Transacciones**: Registro de todas las actividades del usuario
- **Notificaciones**: Sistema de alertas para eventos importantes

#### 3. Sistema de Minería
- **Interfaz de Minería**: Panel para iniciar/detener minería y seleccionar zonas
- **Monitoreo en Tiempo Real**: Visualización de progreso y recompensas acumuladas
- **Gestión de Energía**: Indicadores de energía y tiempo de regeneración
- **Calculadora de Recompensas**: Estimación de ganancias por configuración

#### 4. Marketplace
- **Catálogo de NFTs**: Listado con filtros por rareza, precio, atributos
- **Sistema de Búsqueda**: Búsqueda avanzada y ordenamiento
- **Gestión de Listings**: Crear, editar y cancelar listados propios
- **Sistema de Ofertas**: Hacer y gestionar ofertas en NFTs
- **Historial de Ventas**: Tracking de precios y tendencias del mercado

#### 5. Sistema de Staking
- **Panel de Staking**: Visualización de pools disponibles y APY
- **Gestión de Stakes**: Crear, monitorear y retirar stakes
- **Calculadora de Recompensas**: Estimación de ganancias por pool y tiempo
- **Historial de Staking**: Registro de stakes pasados y recompensas obtenidas

### Componentes de UI Necesarios

#### Componentes Base
- **WalletConnector**: Botón de conexión de wallet con estado
- **NetworkSwitcher**: Selector de red blockchain
- **TransactionModal**: Modal para confirmar transacciones
- **LoadingSpinner**: Indicador de carga para operaciones blockchain
- **ErrorBoundary**: Manejo de errores de la aplicación

#### Componentes Específicos del Juego
- **RobotCard**: Tarjeta individual de robot con atributos
- **RobotGrid**: Grilla de robots con paginación
- **MiningZoneSelector**: Selector de zonas de minería
- **StakingPoolCard**: Tarjeta de pool de staking
- **MarketplaceItem**: Item del marketplace con opciones de compra
- **PriceChart**: Gráfico de precios históricos

### Integraciones Técnicas Requeridas

#### 1. Manejo de Estado Global
```javascript
// store/gameStore.js
export const useGameStore = create((set, get) => ({
  // Estado de usuario
  user: {
    address: null,
    balance: 0,
    robots: [],
    stakes: [],
    miningStatus: {}
  },
  
  // Estado del juego
  game: {
    zones: [],
    events: [],
    pools: []
  },
  
  // Acciones
  setUser: (user) => set({ user }),
  updateBalance: (balance) => set(state => ({ 
    user: { ...state.user, balance } 
  })),
  addRobot: (robot) => set(state => ({
    user: { ...state.user, robots: [...state.user.robots, robot] }
  }))
}));
```

#### 2. Gestión de Transacciones
```javascript
// hooks/useTransactions.js
export function useTransactions() {
  const [pending, setPending] = useState([]);
  const [completed, setCompleted] = useState([]);
  
  const addTransaction = (tx) => {
    setPending(prev => [...prev, tx]);
  };
  
  const completeTransaction = (txHash) => {
    setPending(prev => prev.filter(tx => tx.hash !== txHash));
    setCompleted(prev => [...prev, { hash: txHash, timestamp: Date.now() }]);
  };
  
  return { pending, completed, addTransaction, completeTransaction };
}
```

#### 3. Cache y Optimización
```javascript
// hooks/useContractCache.js
export function useContractCache() {
  const queryClient = useQueryClient();
  
  const invalidateRobots = () => {
    queryClient.invalidateQueries(['robots']);
  };
  
  const invalidateBalance = () => {
    queryClient.invalidateQueries(['balance']);
  };
  
  return { invalidateRobots, invalidateBalance };
}
```

### Consideraciones de UX/UI

#### 1. Responsive Design
- **Mobile First**: Diseño optimizado para dispositivos móviles
- **Progressive Enhancement**: Funcionalidades adicionales en desktop
- **Touch Interactions**: Gestos táctiles para navegación

#### 2. Performance
- **Lazy Loading**: Carga diferida de componentes pesados
- **Virtual Scrolling**: Para listas grandes de NFTs
- **Image Optimization**: Compresión y lazy loading de imágenes
- **Bundle Splitting**: División del código para carga rápida

#### 3. Accesibilidad
- **ARIA Labels**: Etiquetas para lectores de pantalla
- **Keyboard Navigation**: Navegación completa por teclado
- **Color Contrast**: Contraste adecuado para visibilidad
- **Screen Reader Support**: Compatibilidad con tecnologías asistivas

### Herramientas de Desarrollo Recomendadas

#### Testing
```bash
# Testing de componentes
npm install @testing-library/react @testing-library/jest-dom

# Testing de contratos
npm install @nomicfoundation/hardhat-chai-matchers

# Testing E2E
npm install playwright
```

#### Desarrollo
```bash
# Linting y formateo
npm install eslint prettier

# Análisis de bundle
npm install webpack-bundle-analyzer

# Documentación
npm install storybook
```

## 🔒 Seguridad

### Mejores Prácticas Implementadas
- **ReentrancyGuard**: Protección contra ataques de reentrancy en todos los contratos
- **Access Control**: Sistema de roles con Ownable y autorizaciones granulares
- **Pausable**: Capacidad de pausar contratos en emergencias con funciones de administración
- **Rate Limiting**: Límites en acciones por usuario y detección de actividad sospechosa
- **Input Validation**: Validación exhaustiva de parámetros y rangos de valores
- **Safe Math**: Uso de Solidity 0.8.28 con protección automática contra overflow/underflow
- **Anti-Fraud Systems**: Sistemas integrados de detección de patrones sospechosos
- **Emergency Functions**: Funciones de retiro de emergencia y recuperación de fondos

### Características de Seguridad por Contrato

#### MinerBotToken.sol
- Límites anti-ballena del 1% del suministro total
- Sistema de autorización para contratos de minteo
- Funciones de pausa y recuperación de emergencia

#### MinerBotNFT.sol
- Validación de rareza y atributos en minteo
- Protección contra transferencias no autorizadas
- Sistema de durabilidad para prevenir abuso

#### MinerBotGame.sol
- Detección de actividad sospechosa multi-nivel
- Límites de acciones diarias por usuario
- Sistema de reputación con penalizaciones

#### MinerBotStaking.sol
- Validación de pools y montos de stake
- Detección de patrones de retiro sospechosos
- Sistema de baneos por actividad fraudulenta

#### MinerBotMarketplace.sol
- Validación de ownership antes de listados
- Protección contra manipulación de precios
- Sistema de fondos pendientes para seguridad

### Auditorías y Testing
- ✅ **Testing exhaustivo**: 95%+ de cobertura de código
- ✅ **Análisis estático**: Integración con Slither y herramientas de análisis
- ✅ **Testing de seguridad**: Pruebas específicas de vulnerabilidades conocidas
- 🔄 **Auditoría externa**: Recomendada antes de mainnet
- 🔄 **Bug bounty program**: Para incentivizar la búsqueda de vulnerabilidades

### Monitoreo y Respuesta
- **Eventos de seguridad**: Logging completo de actividades críticas
- **Alertas automáticas**: Notificaciones para transacciones sospechosas
- **Dashboard de métricas**: Monitoreo en tiempo real de la salud del sistema
- **Procedimientos de respuesta**: Protocolos definidos para incidentes de seguridad

## 📊 Tokenomics Detalladas

### Información del Token MBT
- **Nombre**: MinerBot Token
- **Símbolo**: MBT
- **Decimales**: 18
- **Suministro Total**: 1,000,000,000 MBT (1 billón)
- **Tipo**: Token deflacionario con mecanismos de quema

### Distribución Inicial
| Categoría | Porcentaje | Tokens | Vesting |
|-----------|------------|--------|---------|
| Game Rewards | 40% | 400M MBT | Liberación gradual |
| Staking Rewards | 20% | 200M MBT | Liberación gradual |
| Team | 15% | 150M MBT | 2 años linear |
| Marketing | 10% | 100M MBT | Inmediato |
| Treasury | 8% | 80M MBT | Inmediato |
| Airdrops | 5% | 50M MBT | Inmediato |
| Advisors | 2% | 20M MBT | 1 año linear |

### Mecanismos de Quema
- **Burn en Marketplace**: 2.5% de cada transacción de venta
- **Burn en Breeding**: 10% del costo total de reproducción
- **Burn en Evolución**: 5% del costo de evolución de NFTs
- **Burn en Reparaciones**: 1% del costo de mantenimiento
- **Burn en Penalizaciones**: Tokens quemados por actividades fraudulentas

### Sistema de Recompensas de Minería
- **Recompensa Base**: 10 MBT por sesión de minería
- **Multiplicadores por Rareza**:
  - Común: 1.0x (10 MBT)
  - Poco Común: 1.2x (12 MBT)
  - Raro: 1.5x (15 MBT)
  - Épico: 2.0x (20 MBT)
  - Legendario: 3.0x (30 MBT)
- **Bonos por Reputación**: Hasta +50% adicional
- **Eventos Especiales**: Multiplicadores temporales de hasta 5x

### Sistema de Staking Avanzado
- **Pools Disponibles**:
  - **Pool 30 días**: 10% APY, monto mínimo 100 MBT
  - **Pool 90 días**: 15% APY, monto mínimo 500 MBT
  - **Pool 180 días**: 20% APY, monto mínimo 1,000 MBT
  - **Pool 365 días**: 25% APY, monto mínimo 5,000 MBT

- **Bonos de Lealtad**: +2% adicional después de 90 días de staking
- **Penalizaciones por Retiro Temprano**: 5% de penalización en retiros de emergencia

### Características Anti-Ballena
- **Límite por Transacción**: 1% del suministro total (10,000,000 MBT)
- **Detección de Patrones**: Sistema automático de detección de actividad sospechosa
- **Cooldown entre Transacciones**: Límites dinámicos para prevenir manipulación

### Utilidad del Token
- **Minería**: Pago de costos operativos y mantenimiento de robots
- **Staking**: Generación de ingresos pasivos con múltiples pools
- **Marketplace**: Compra/venta de NFTs robots
- **Breeding**: Creación de nuevos robots NFT
- **Evolución**: Mejora de atributos y nivel de robots
- **Governance**: Participación en decisiones del protocolo (futuro)

### Incentivos a Largo Plazo
- Recompensas crecientes por lealtad en staking
- Bonificaciones por mantener robots activos
- Descuentos en marketplace para holders de largo plazo
- Governance tokens para decisiones del ecosistema

## 🗺️ Roadmap

### ✅ Fase 1: Fundación (Completada)
- ✅ **Contratos Inteligentes**: Desarrollo completo de todos los contratos base
- ✅ **Sistema de NFTs**: Implementación completa con atributos, rareza y durabilidad
- ✅ **Mecánicas de Minería**: Sistema de minería con recompensas y eventos especiales
- ✅ **Sistema de Staking**: Pools múltiples con APY variable y bonos de lealtad
- ✅ **Marketplace**: Funcionalidad completa de compra/venta y subastas
- ✅ **Testing Framework**: Suite de pruebas exhaustiva con >95% de cobertura
- ✅ **Documentación**: Documentación técnica completa y actualizada

### 🔄 Fase 2: Desarrollo Frontend (En Progreso)
- 🔄 **Configuración Base**: Setup de React, TypeScript, y herramientas de desarrollo
- 🔄 **Integración Web3**: Implementación de wagmi, viem y RainbowKit
- 🔄 **Componentes UI**: Desarrollo de componentes base y específicos del juego
- ⏳ **Dashboard de Usuario**: Panel principal con estadísticas y gestión de robots
- ⏳ **Sistema de Minería**: Interfaz para iniciar/detener minería y ver recompensas
- ⏳ **Marketplace UI**: Interfaz completa para comprar/vender NFTs
- ⏳ **Staking Interface**: Panel para gestionar stakes y reclamar recompensas

### 📋 Fase 3: Testing y Optimización (Próxima)
- ⏳ **Testing de Integración**: Pruebas completas frontend-backend
- ⏳ **Optimización de Performance**: Mejoras de velocidad y experiencia de usuario
- ⏳ **Testing de Usuario**: Beta testing con usuarios reales
- ⏳ **Auditoría de Seguridad**: Auditoría externa de contratos inteligentes
- ⏳ **Optimización de Gas**: Reducción de costos de transacciones
- ⏳ **Mobile Responsiveness**: Adaptación completa para dispositivos móviles

### 🚀 Fase 4: Lanzamiento (Q2 2024)
- ⏳ **Deployment Testnet**: Lanzamiento en Sepolia para testing público
- ⏳ **Community Building**: Construcción de comunidad y marketing inicial
- ⏳ **Bug Bounty Program**: Programa de recompensas por encontrar vulnerabilidades
- ⏳ **Mainnet Deployment**: Lanzamiento oficial en Ethereum mainnet
- ⏳ **Liquidity Provision**: Provisión de liquidez inicial para el token MBT
- ⏳ **Marketing Campaign**: Campaña de marketing y partnerships estratégicos

### 🌟 Fase 5: Expansión (Q3-Q4 2024)
- ⏳ **Governance System**: Implementación de sistema de governance con MBT
- ⏳ **Advanced Features**: Características avanzadas como torneos y eventos
- ⏳ **Cross-Chain Expansion**: Expansión a otras blockchains (Polygon, BSC)
- ⏳ **Mobile App**: Aplicación móvil nativa para iOS y Android
- ⏳ **API Pública**: API para desarrolladores terceros
- ⏳ **Ecosystem Partnerships**: Integraciones con otros proyectos DeFi/GameFi

### 🔮 Fase 6: Futuro (2025+)
- ⏳ **DAO Implementation**: Transición completa a organización autónoma descentralizada
- ⏳ **Metaverse Integration**: Integración con plataformas de metaverso
- ⏳ **AI-Powered Features**: Características impulsadas por inteligencia artificial
- ⏳ **Layer 2 Solutions**: Migración a soluciones de Layer 2 para reducir costos
- ⏳ **Global Expansion**: Expansión a mercados globales con localización
- ⏳ **Enterprise Solutions**: Soluciones para empresas y organizaciones

## 🤝 Contribución

### Cómo Contribuir
1. **Fork del repositorio** en GitHub
2. **Crear branch** para feature (`git checkout -b feature/NuevaFuncionalidad`)
3. **Implementar cambios** siguiendo los estándares de código
4. **Ejecutar tests** y asegurar que pasen todas las pruebas
5. **Commit de cambios** (`git commit -m 'Add: Nueva funcionalidad'`)
6. **Push al branch** (`git push origin feature/NuevaFuncionalidad`)
7. **Abrir Pull Request** con descripción detallada

### Estándares de Código

#### Contratos Inteligentes
- **Solidity Style Guide**: Seguir las convenciones oficiales de Solidity
- **Documentación**: Usar NatSpec para todas las funciones públicas y externas
- **Testing**: Incluir tests unitarios para nuevas funcionalidades
- **Cobertura**: Mantener cobertura de tests >95%
- **Gas Optimization**: Optimizar para reducir costos de gas
- **Security**: Seguir mejores prácticas de seguridad

#### Frontend
- **TypeScript**: Usar tipado estricto
- **ESLint/Prettier**: Seguir configuración del proyecto
- **Componentes**: Crear componentes reutilizables y bien documentados
- **Testing**: Incluir tests para componentes críticos
- **Performance**: Optimizar para carga rápida y UX fluida

### Áreas de Contribución
- 🔧 **Desarrollo de Contratos**: Mejoras y nuevas funcionalidades
- 🎨 **Frontend/UI**: Componentes, diseño y experiencia de usuario
- 🧪 **Testing**: Ampliación de cobertura de tests
- 📚 **Documentación**: Mejoras en documentación técnica y de usuario
- 🔒 **Seguridad**: Auditorías y mejoras de seguridad
- 🌐 **Localización**: Traducción a otros idiomas

### Reportar Issues
- **GitHub Issues**: Usar templates apropiados
- **Información requerida**:
  - Pasos para reproducir el problema
  - Comportamiento esperado vs actual
  - Versión del software y entorno
  - Logs y capturas de pantalla relevantes
- **Etiquetas**: Usar etiquetas apropiadas (bug, enhancement, question)

### Proceso de Review
1. **Revisión automática**: CI/CD ejecuta tests y análisis de código
2. **Revisión por pares**: Al menos un maintainer revisa el código
3. **Testing**: Verificación en entorno de desarrollo
4. **Aprobación**: Merge después de aprobación y tests exitosos

## 📄 Licencia

Este proyecto está bajo la **Licencia MIT** - ver el archivo [LICENSE](LICENSE) para detalles completos.

### Resumen de la Licencia
- ✅ **Uso comercial** permitido
- ✅ **Modificación** permitida
- ✅ **Distribución** permitida
- ✅ **Uso privado** permitido
- ❗ **Sin garantía** - el software se proporciona "tal como está"
- ❗ **Responsabilidad limitada** - los autores no son responsables por daños

## 📞 Contacto y Comunidad

### Canales Oficiales
- 🌐 **Website**: [minerbot.game](https://minerbot.game)
- 📧 **Email Desarrollo**: dev@minerbot.game
- 🛠️ **Soporte Técnico**: support@minerbot.game
- 📱 **Twitter**: [@MinerBotGame](https://twitter.com/MinerBotGame)
- 💬 **Discord**: [MinerBot Community](https://discord.gg/minerbot)
- 📢 **Telegram**: [MinerBot Official](https://t.me/minerbotgame)

### Recursos Adicionales
- 📖 **Documentación**: [docs.minerbot.game](https://docs.minerbot.game)
- 🔍 **Block Explorer**: Enlaces a contratos verificados
- 📊 **Analytics**: Dashboard de métricas del protocolo
- 🎮 **Guías de Juego**: Tutoriales y estrategias

### Comunidad
- 👥 **Discord**: Chat en tiempo real y soporte de la comunidad
- 🐦 **Twitter**: Actualizaciones y anuncios oficiales
- 📱 **Telegram**: Noticias y discusiones
- 📺 **YouTube**: Tutoriales y demos del juego
- 📝 **Medium**: Artículos técnicos y actualizaciones del desarrollo

## 🙏 Agradecimientos

- OpenZeppelin por las librerías de seguridad
- Hardhat por el framework de desarrollo
- Comunidad Ethereum por las mejores prácticas
- Contribuidores del proyecto

---

**MinerBot Empire** - Revolucionando la minería descentralizada con NFTs y DeFi. 🤖⛏️💎

*Construido con ❤️ por la comunidad blockchain*

**⚠️ Disclaimer**: Este es un proyecto de demostración. Realizar auditorías de seguridad profesionales antes de usar en producción.