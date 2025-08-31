# MinerBot Empire - Blockchain Gaming Ecosystem

## 🎮 Descripción del Proyecto

MinerBot Empire es un juego idle/estratégico basado en blockchain donde los jugadores gestionan robots NFT que extraen recursos automáticamente. El juego combina mecánicas de minería idle, coleccionables NFT, staking de tokens y un marketplace descentralizado.

## 🚀 Características Principales

### 🤖 Sistema de Robots NFT
- **5 niveles de rareza**: Common, Uncommon, Rare, Epic, Legendary
- **Atributos modulares**: Mining Power, Battery, Communication, Storage, Durability
- **Sistema de evolución**: Los robots pueden subir de nivel y mejorar sus atributos
- **Breeding**: Posibilidad de crear nuevos robots combinando dos existentes
- **Mantenimiento**: Sistema de durabilidad que requiere mantenimiento periódico

### ⛏️ Mecánicas de Minería Idle
- **5 zonas de minería**: Desde Crystal Caves hasta Quantum Realm
- **Minería automática**: Los robots minan recursos sin intervención activa
- **Sistema de energía**: Consumo de energía por hora de minería
- **Eventos especiales**: Multiplicadores temporales de recompensas
- **Cálculo de recompensas**: Basado en atributos del robot, zona y duración

### 💰 Tokenomics Balanceadas
- **Token principal**: MinerBot Token (MBT) - ERC20
- **Suministro total**: 1,000,000,000 MBT
- **Distribución equitativa**:
  - 40% Game Rewards
  - 20% Staking Rewards
  - 15% Team (vesting 2 años)
  - 10% Marketing
  - 8% Treasury
  - 5% Airdrops
  - 2% Advisors (vesting 1 año)
- **Mecanismo deflacionario**: Quema de tokens en ciertas transacciones
- **Protección anti-ballena**: Límites en transacciones y wallets

### 🏦 Sistema de Staking
- **4 pools de staking** con diferentes duraciones y APY:
  - 30 días: 10% APY
  - 90 días: 15% APY
  - 180 días: 20% APY
  - 365 días: 25% APY
- **Bonos de lealtad**: Recompensas adicionales por completar períodos completos
- **Penalización por retiro temprano**: 10% de penalización
- **Límites de stake**: Mínimos y máximos por pool

### 🛒 Marketplace Descentralizado
- **Venta directa**: Listados a precio fijo
- **Subastas**: Sistema de pujas con duración configurable
- **Ofertas directas**: Los compradores pueden hacer ofertas a los propietarios
- **Comisión del marketplace**: 2.5% en todas las transacciones
- **Protección contra reentrancy**: Implementación de ReentrancyGuard

### 🛡️ Medidas Anti-Fraude
- **Límites de acciones diarias**: Prevención de spam
- **Detección de actividad sospechosa**: Sistema de puntuación
- **Sistema de baneos**: Capacidad de banear usuarios maliciosos
- **Verificación de frecuencia**: Control de acciones repetitivas

## 📋 Contratos Inteligentes

### 1. MinerBotToken.sol
- Token ERC20 principal del ecosistema
- Funciones de quema deflacionaria
- Vesting para team y advisors
- Autorización para contratos del juego
- Protección anti-ballena

### 2. MinerBotNFT.sol
- Robots NFT con atributos únicos
- Sistema de rareza y evolución
- Breeding y mantenimiento
- Metadata on-chain
- Costos de minteo en MBT y ETH

### 3. MinerBotGame.sol
- Lógica principal del juego
- Mecánicas de minería idle
- Sistema de zonas y energía
- Cálculo de recompensas
- Eventos especiales

### 4. MinerBotStaking.sol
- Pools de staking con diferentes APY
- Sistema de recompensas y penalizaciones
- Medidas anti-fraude integradas
- Funciones de emergencia

### 5. MinerBotMarketplace.sol
- Trading de robots NFT
- Subastas y ofertas directas
- Distribución automática de comisiones
- Protección contra reentrancy

## 🔧 Instalación y Configuración

### Prerrequisitos
- Node.js v16 o superior
- npm o yarn
- Git

### Instalación
```bash
# Clonar el repositorio
git clone <repository-url>
cd minerbot-empire

# Instalar dependencias
npm install

# Configurar variables de entorno
cp .env.example .env
# Editar .env con tus claves privadas y API keys
```

### Configuración de Red
Edita `hardhat.config.js` para configurar las redes:
- Hardhat (desarrollo local)
- Localhost
- Goerli (testnet)
- Polygon Mumbai (testnet)
- Polygon Mainnet

## 🧪 Testing

### Ejecutar Tests
```bash
# Ejecutar todos los tests
npm test

# Ejecutar tests específicos
npx hardhat test test/MinerBotToken.test.js
npx hardhat test test/MinerBotNFT.test.js
npx hardhat test test/MinerBotGame.test.js
npx hardhat test test/MinerBotStaking.test.js
npx hardhat test test/MinerBotMarketplace.test.js

# Ejecutar tests con reporte de gas
npx hardhat test --gas-reporter
```

### Cobertura de Tests
Los tests cubren:
- ✅ Deployment y configuración inicial
- ✅ Funcionalidades principales de cada contrato
- ✅ Casos edge y manejo de errores
- ✅ Medidas de seguridad y anti-fraude
- ✅ Optimización de gas
- ✅ Integración entre contratos

## 🚀 Deployment

### Red Local
```bash
# Iniciar nodo local
npx hardhat node

# Desplegar en otra terminal
npx hardhat run scripts/deploy.js --network localhost
```

### Testnet
```bash
# Desplegar en Goerli
npx hardhat run scripts/deploy.js --network goerli

# Desplegar en Polygon Mumbai
npx hardhat run scripts/deploy.js --network mumbai
```

### Verificación de Contratos
```bash
# Verificar en Etherscan
npx hardhat verify --network goerli <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>

# Verificar en PolygonScan
npx hardhat verify --network polygon <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## 🔒 Seguridad

### Mejores Prácticas Implementadas
- **Checks-Effects-Interactions**: Patrón seguido en todas las funciones
- **ReentrancyGuard**: Protección contra ataques de reentrancy
- **SafeMath**: Uso implícito en Solidity 0.8.19
- **Access Control**: Roles y permisos bien definidos
- **Pausable**: Capacidad de pausar contratos en emergencias
- **Input Validation**: Validación exhaustiva de parámetros
- **Gas Optimization**: Optimizaciones para reducir costos

### Auditoría
- Tests exhaustivos con >95% de cobertura
- Revisión manual de código
- Análisis estático con herramientas de seguridad
- Pruebas de stress en testnet

## 📊 Tokenomics Detalladas

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
- 1% de tokens quemados en breeding fallido
- 0.5% de tokens quemados en mantenimiento de robots
- Quema adicional en eventos especiales

### Incentivos a Largo Plazo
- Recompensas crecientes por lealtad en staking
- Bonificaciones por mantener robots activos
- Descuentos en marketplace para holders de largo plazo
- Governance tokens para decisiones del ecosistema

## 🎯 Roadmap

### Versión 1.0 (Actual)
- ✅ Contratos principales implementados
- ✅ Sistema de minería idle básico
- ✅ NFT robots con atributos
- ✅ Staking y marketplace
- ✅ Tests exhaustivos

### Versión 1.1 (Próxima)
- 🔄 Sistema de upgrades de robots
- 🔄 Governance y DAO
- 🔄 Eventos especiales automáticos
- 🔄 Integración con oráculos

### Versión 2.0 (Futuro)
- 📋 Modo expedición
- 📋 Sistema climático
- 📋 PvP "Claim Wars"
- 📋 Redes de robots
- 📋 Mercado de datos

## 🤝 Contribución

### Cómo Contribuir
1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

### Estándares de Código
- Seguir convenciones de Solidity
- Documentar todas las funciones públicas
- Incluir tests para nuevas funcionalidades
- Optimizar para gas cuando sea posible

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 📞 Contacto

- **Proyecto**: MinerBot Empire
- **Documentación**: [Docs](docs/)
- **Issues**: [GitHub Issues](issues/)
- **Discusiones**: [GitHub Discussions](discussions/)

## 🙏 Agradecimientos

- OpenZeppelin por las librerías de seguridad
- Hardhat por el framework de desarrollo
- Comunidad Ethereum por las mejores prácticas
- Contribuidores del proyecto

---

**⚠️ Disclaimer**: Este es un proyecto de demostración. Realizar auditorías de seguridad profesionales antes de usar en producción.