# � Nuxchain Protocol

**A unified DeFi ecosystem combining staking, gaming, NFTs, and sustainable treasury management on Polygon.**

---

## 📚 Documentation Quick Links

Choose your path based on what you need:

| Need | Document | Time |
|------|----------|------|
| **Quick overview** | [EXECUTIVE_SUMMARY.md](./EXECUTIVE_SUMMARY.md) | 15 min |
| **Social/sharing** | [VISUAL_QUICK_GUIDE.md](./VISUAL_QUICK_GUIDE.md) | 10 min |
| **Complete details** | [NUXCHAIN_WHITEPAPER.md](./NUXCHAIN_WHITEPAPER.md) | 45 min |
| **Technical specs** | [TECHNOLOGY_DEEP_DIVE.md](./TECHNOLOGY_DEEP_DIVE.md) | 60 min |
| **Marketing/community** | [MARKETING_COMMUNITY_GUIDE.md](./MARKETING_COMMUNITY_GUIDE.md) | 40 min |
| **Smart contracts** | [doc/SMART_CONTRACTS_REFERENCE.md](./doc/SMART_CONTRACTS_REFERENCE.md) | 30 min |

---

## 🎯 What is Nuxchain?

Nuxchain Protocol combines four core components:

- **💰 Smart Staking**: Generate 40-250% APY with skill-based enhancements
- **🎮 Gameified Marketplace**: Trade NFTs with integrated progression system  
- **🏅 Skill NFTs**: Collectible boosts affecting staking and marketplace performance
- **🏦 Treasury Management**: Circular economy ensuring long-term sustainability

---

## 🌟 Key Stats

| Metric | Value |
|--------|-------|
| Network | Polygon (Chain 137) |
| Base APY | 43.8% |
| Max APY | 250%+ |
| Min Deposit | 10 POL |
| Max Deposit | 10,000 POL |
| Staking Commission | 6% |
| Marketplace Fee | 5% |

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

---

## 👥 For Different Audiences

### 📊 Investors/Partners
Start with: **EXECUTIVE_SUMMARY.md** → **NUXCHAIN_WHITEPAPER.md**

### 👨‍💻 Developers/Auditors
Start with: **TECHNOLOGY_DEEP_DIVE.md** → **doc/SMART_CONTRACTS_REFERENCE.md**

### 📢 Marketing/Community
Start with: **MARKETING_COMMUNITY_GUIDE.md** → **VISUAL_QUICK_GUIDE.md**

### 🎓 Community Members
Start with: **VISUAL_QUICK_GUIDE.md** → **EXECUTIVE_SUMMARY.md**

---

## 🗂️ Project Structure

```
📁 Nuxchain-protocol
├── 📄 README.md (this file)
├── 📄 NUXCHAIN_WHITEPAPER.md (official spec)
├── 📄 EXECUTIVE_SUMMARY.md (quick reference)
├── 📄 VISUAL_QUICK_GUIDE.md (social/sharing)
├── 📄 TECHNOLOGY_DEEP_DIVE.md (technical details)
├── 📄 MARKETING_COMMUNITY_GUIDE.md (go-to-market)
│
├── 📁 contracts/ (smart contracts source)
├── 📁 scripts/ (deployment & maintenance)
├── 📁 test/ (test suite)
├── 📁 artifacts/ (compiled contracts)
│
└── 📁 doc/ (technical documentation)
    ├── 📄 SMART_CONTRACTS_REFERENCE.md
    ├── 📄 SYSTEM_ARCHITECTURE.md
    ├── 📄 CONTRACTS_SUMMARY.md
    └── 📁 contracts/ (individual contract docs)
```

---

## 🚀 Getting Started (5 Minutes)

### 1. Prepare Wallet
```bash
- Download MetaMask
- Add Polygon network (ChainID: 137)
- Get 1-2 POL for gas
```

### 2. Acquire POL
```bash
- Buy on exchange (Uniswap, 1inch)
- Bridge from Ethereum if needed
- Transfer to your wallet
```

### 3. Deposit
```bash
- Go to staking interface
- Connect wallet
- Deposit 10-10,000 POL
- Confirm transaction
```

### 4. Monitor
```bash
- Check dashboard for APY
- See rewards update hourly
- Compound or withdraw anytime
```

---

## 🔗 Smart Contract Addresses (Polygon Mainnet)

| Component | Address |
|-----------|---------|
| **Smart Staking Core** | `0xC67F0a0cB719e4f4358D980a5D966878Fd6f3946` |
| **Staking Rewards (v5.1.0)** | `0xEB02b4cC589B7017e621a8b4A02295793d6cB32E` |
| **Staking Skills (v5.1.0)** | `0x2c8E2A5902dACEd9705e5AB9A3eE2EdAAe0e7F38` |
| **Dynamic APY Calculator** | `0xF07B192F42E0eB84ba08c6DB591d08B1c753aC68` |
| **Gameified Marketplace** | `0xd502fA2F8F565B1b30a24c6c0F83dBf17CB0F8f0` |
| **Marketplace Skills NFT** | `0x355126Fbb7f8294aaB32Be884C49102075c5D6ce` |
| **Individual Skills** | `0xB23257758B385444dF5A78aC2F315bd653470df3` |
| **Treasury Manager (v2)** | `0x8f3554Fca1Bd1b79bBf531706FA2C67fEcC5401F` |
| **Collaborator Badge Rewards** | `0xd0F4c324ad5C34A9502A51e38807e1EdcfACDeAB` |

See [doc/CONTRACTS_SUMMARY.md](./doc/CONTRACTS_SUMMARY.md) for full details.

---

## 📊 Latest Updates (Feb 13, 2026)

✅ **Deployed**:
- TreasuryManager v2 with 10% reserve fund
- DynamicAPYCalculator (sqrt-based TVL scaling)
- EnhancedSmartStakingRewards v5.1.0 (25% APY reduction)
- EnhancedSmartStakingSkills v5.1.0 (25% boost reduction)
- CollaboratorBadgeRewards with tiered commissions

✅ **Configured**:
- Treasury allocations: 30/35/20/15% split
- Reserve fund auto-accumulation enabled
- All 4 treasury wallets connected to contracts

🔄 **Pending**:
- Frontend .env updates (6 variables)
- ABI file copies
- IndividualSkillsMarketplace treasury connection

---

## 🛠️ Development

### Prerequisites
```bash
node >= 16.0
hardhat
@openzeppelin/contracts-upgradeable
```

### Setup
```bash
npm install
npx hardhat compile
```

### Testing
```bash
npx hardhat test
```

### Deployment
See `scripts/` directory for deployment scripts.

---

## 🔒 Security

All smart contracts include:
- ✅ ReentrancyGuard protection
- ✅ AccessControl permissions
- ✅ Pausable emergency mechanism
- ✅ Parameter validation
- ✅ Event logging for transparency

See [TECHNOLOGY_DEEP_DIVE.md](./TECHNOLOGY_DEEP_DIVE.md) for security details.

---

## 📞 Support

**Need help?**
1. Check the relevant documentation above
2. Review [EXECUTIVE_SUMMARY.md](./EXECUTIVE_SUMMARY.md) FAQ section
3. Check smart contract comments in `contracts/` directory
4. Review test files in `test/` directory

---

## 📄 License

MIT

---

**Last Updated**: February 13, 2026  
**Repository**: [github.com/LennyDevX/Nuxchain-protocol](https://github.com/LennyDevX/Nuxchain-protocol)  
**Network**: Polygon (Chain 137)
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
