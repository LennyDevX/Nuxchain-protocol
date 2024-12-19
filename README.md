# 🌟 Nuvo Staking Protocol v0.4

A secure and efficient staking protocol built on Polygon Network featuring automated reward calculations and time-based incentives.

## 🚀 Latest Updates (v0.4)

- Enhanced Smart Staking Contract with improved security measures
- New Airdrop Contract implementation with comprehensive testing
- Added Mock Contracts for thorough testing scenarios
- Updated to Ethers.js v6.x.x
- Integrated Alchemy RPC provider
- Enhanced test coverage and scripts

## ✨ Core Features

- 📈 Dynamic ROI System
  - 0.02% base hourly ROI
  - 125% maximum return cap
  - Time-based bonus structure up to 5%

- 🛡️ Security Features
  - ReentrancyGuard protection
  - Pausable emergency circuit
  - Owner-only administrative functions
  - Treasury management system

- 💎 Staking Mechanics
  - Flexible deposits (5-10,000 MATIC)
  - Time-weighted bonus rewards
  - Maximum 300 active deposits per user
  - 6% Treasury commission system

- 🔄 Emergency Systems
  - Pause/Unpause functionality
  - Emergency withdrawal mechanisms
  - Migration capabilities

## 🛠️ Technical Stack

- **Smart Contracts**: Solidity ^0.8.24
- **Framework**: Hardhat
- **Testing**: Mocha & Chai
- **Libraries**: OpenZeppelin Contracts
- **Provider**: Alchemy RPC
- **Client**: Ethers.js v6.x.x

## 📦 Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/nuvo-staking-protocol.git