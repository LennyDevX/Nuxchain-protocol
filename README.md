# � Nuxchain Protocol

**A unified DeFi ecosystem combining staking, gaming, NFTs, and sustainable treasury management on Polygon.**

---

## 🎯 Choose Your Path

| Who You Are | Start Here | Time |
|---|---|---|
| **User / Community** | [guides/INTRODUCTION.md](./guides/INTRODUCTION.md) | 15 min |
| **Marketing / Social** | [guides/MARKETING.md](./guides/MARKETING.md) | 20 min |
| **Designer / Visual** | [guides/QUICK_REFERENCE.md](./guides/QUICK_REFERENCE.md) | 10 min |
| **Developer** | [doc/ARCHITECTURE.md](./doc/ARCHITECTURE.md) | 30 min |
| **DevOps** | [doc/DEPLOYMENT.md](./doc/DEPLOYMENT.md) | 20 min |
| **API Reference** | [doc/SMART_CONTRACTS_REFERENCE.md](./doc/SMART_CONTRACTS_REFERENCE.md) | 45 min |

---

## � What is Nuxchain?

Four integrated components:

- **💰 Smart Staking**: 43.8% - 250% APY with skill boosts
- **🎮 Gameified Marketplace**: Trade NFTs + earn XP
- **🏅 Skill NFTs**: 7 collectible skills with 5 rarity tiers
- **🏦 Treasury**: Automated distribution for sustainability

---

## 📊 Key Metrics

| Metric | Value |
|---|---|
| Network | Polygon (Chain 137) |
| Base APY | 43.8% |
| Max APY | 250%+ |
| Min Deposit | 10 POL |
| Max Deposit | 10,000 POL |
| Commission | 6% (staking), 5% (trades) |

---

## 📚 Documentation Structure

```
guides/                              ← For End Users
├── INTRODUCTION.md                  (Getting started)
├── QUICK_REFERENCE.md               (Visual guide)
├── TECHNOLOGY.md                    (Deep dive)
└── MARKETING.md                     (Community messaging)

doc/                                 ← For Developers
├── README.md                        (Tech doc navigation)
├── ARCHITECTURE.md                  (Complete design)
├── SMART_CONTRACTS_REFERENCE.md     (API reference)
├── DEPLOYMENT.md                    (Setup & devops)
├── IMPLEMENTATION_GUIDES/
│   ├── DynamicAPYCalculator.md
│   └── EmergencyFundSystem.md
└── FEATURES/
    └── CollaboratorBadgeRewards.md

reports/                             ← Implementation Reports
├── DynamicAPY_Implementation.md
└── Marketplace_Features.md

contracts/                           ← Smart Contract Source Code
```

---

## 🚀 Quick Start (5 minutes)

### Setup Wallet
1. Get MetaMask or similar
2. Add Polygon (ChainID: 137)
3. Fund with 1-2 POL for gas
4. Buy 10+ POL

### Deposit & Earn
1. Visit Nuxchain interface
2. Connect wallet
3. Deposit 10-10,000 POL
4. Select lock-up (optional)
5. Watch it compound 24/7

### Maximize Returns
1. Create NFTs on marketplace (+10 XP per NFT)
2. Buy skill NFTs (+5-20% APY boost)
3. Collect rarity tiers (up to 1.8x multiplier)
4. Level up to unlock features

**Full guide**: [guides/INTRODUCTION.md](./guides/INTRODUCTION.md)

---

## 🛠️ For Developers

### Requirements
```bash
node >= 16.0.0
npm >= 8.0.0
```

### Setup Repository
```bash
git clone https://github.com/LennyDevX/Nuxchain-protocol.git
cd Nuxchain-protocol
npm install
npm test
```

### Deploy Contracts
```bash
# Configure environment
cp .env.example .env
# Edit .env with your private key and RPC URL

# Deploy to Polygon
npx hardhat run scripts/DeploySmartV2.cjs --network polygon
```

**Detailed guide**: [doc/DEPLOYMENT.md](./doc/DEPLOYMENT.md)

---

## 📖 Documentation by Use Case

### I'm a User
Start with [guides/INTRODUCTION.md](./guides/INTRODUCTION.md) (15 min)
- What is Nuxchain
- How to get started
- How rewards work
- Security features

### I'm Creating Marketing Content
Start with [guides/MARKETING.md](./guides/MARKETING.md) (20 min)
- Brand messaging
- Social media templates
- Target audiences
- Crisis management

### I'm a Developer
Start with [doc/ARCHITECTURE.md](./doc/ARCHITECTURE.md) (30 min)
- System design
- Smart contract stack
- Data flows
- Integration patterns

Then check [doc/SMART_CONTRACTS_REFERENCE.md](./doc/SMART_CONTRACTS_REFERENCE.md) (45 min)
- Function signatures
- Event definitions
- State variables

### I'm Deploying
Start with [doc/DEPLOYMENT.md](./doc/DEPLOYMENT.md) (20 min)
- Requirements
- Configuration
- Deployment modes
- Troubleshooting

### I Want to Understand Everything
Read in order:
1. [guides/INTRODUCTION.md](./guides/INTRODUCTION.md) - Overview
2. [doc/ARCHITECTURE.md](./doc/ARCHITECTURE.md) - Technical design
3. [doc/SMART_CONTRACTS_REFERENCE.md](./doc/SMART_CONTRACTS_REFERENCE.md) - API
4. [contracts/](./contracts/) - Source code

---

## 🔗 Key Resources

- **[Full Guides](./guides/)** - For end users & content creators
- **[Technical Docs](./doc/)** - For developers & auditors
- **[Smart Contracts](./contracts/)** - Source code
- **[Tests](./test/)** - Test suite

---

## ✅ Status

- ✅ Smart Staking deployed
- ✅ Gameified Marketplace live
- ✅ Skill NFT system active
- ✅ Treasury management operational
- ✅ All contracts verified on PolygonScan
- ✅ Documentation complete

---

## 📝 License

Licensed under MIT License

---

**Last Updated**: February 14, 2026  
**Version**: 5.0+ (Modular)  
**Network**: Polygon (Production) ✅  
**Status**: Fully Operational

For questions or contributions, see [guides/MARKETING.md](./guides/MARKETING.md#-contact--resources)
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
