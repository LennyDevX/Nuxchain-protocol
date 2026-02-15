#!/usr/bin/env node

/**
 * 🚀 QUICK START GUIDE - Using Exported ABIs
 * 
 * Este archivo muestra ejemplos de cómo usar los ABIs exportados en tu frontend
 */

// ════════════════════════════════════════════════════════════════════════════════════════
// 1. OPCIÓN A: Importar archivo JSON completo (Recomendado para Vue/React)
// ════════════════════════════════════════════════════════════════════════════════════════

/*
// En tu archivo frontend (Vue, React, etc.)
import allABIs from '@/abis/all-abis.json';

// Acceder a un contrato específico
const stakingABI = allABIs['EnhancedSmartStaking'].abi;
const stakingAddress = '0xC67F0a0cB719e4f4358D980a5D966878Fd6f3946';

// Usar con ethers.js v6
import { ethers } from 'ethers';

const provider = new ethers.JsonRpcProvider('https://polygon-rpc.com');
const signer = new ethers.Wallet(privateKey, provider);
const contract = new ethers.Contract(stakingAddress, stakingABI, signer);

// Usar con Web3.js
import Web3 from 'web3';

const web3 = new Web3('https://polygon-rpc.com');
const contract = new web3.eth.Contract(stakingABI, stakingAddress);
*/

// ════════════════════════════════════════════════════════════════════════════════════════
// 2. OPCIÓN B: Importar ABIs por categoría (Para mejor organización)
// ════════════════════════════════════════════════════════════════════════════════════════

/*
import abisByCategory from '@/abis/abis-by-category.json';

// Acceder a contratos de staking
const stakingContracts = abisByCategory.SmartStaking;
const rewardsABI = stakingContracts.EnhancedSmartStakingRewards.abi;

// Acceder a contratos del marketplace
const marketplaceContracts = abisByCategory.Marketplace;
const coreABI = marketplaceContracts.GameifiedMarketplaceCoreV1.abi;
*/

// ════════════════════════════════════════════════════════════════════════════════════════
// 3. OPCIÓN C: Usar índice TypeScript (Para proyectos TypeScript/Vite)
// ════════════════════════════════════════════════════════════════════════════════════════

/*
// En archivo .ts o .tsx
import { EnhancedSmartStaking, GameifiedMarketplaceCoreV1 } from '@/abis';

// Los tipos están incluidos automáticamente
const stakingABI: typeof EnhancedSmartStaking = yourConstant;
*/

// ════════════════════════════════════════════════════════════════════════════════════════
// 4. CONFIGURACIÓN CENTRALIZADA DE CONTRATOS (Recomendado)
// ════════════════════════════════════════════════════════════════════════════════════════

/*
// archivo: src/config/contracts.ts

import allABIs from '@/abis/all-abis.json';

export const CONTRACTS = {
  staking: {
    core: {
      address: '0xC67F0a0cB719e4f4358D980a5D966878Fd6f3946',
      abi: allABIs['EnhancedSmartStaking'].abi,
      name: 'EnhancedSmartStaking'
    },
    rewards: {
      address: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
      abi: allABIs['EnhancedSmartStakingRewards'].abi,
      name: 'EnhancedSmartStakingRewards'
    },
    skills: {
      address: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
      abi: allABIs['EnhancedSmartStakingSkills'].abi,
      name: 'EnhancedSmartStakingSkills'
    },
    gamification: {
      address: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
      abi: allABIs['EnhancedSmartStakingGamification'].abi,
      name: 'EnhancedSmartStakingGamification'
    },
    view: {
      address: '0x5E29fCd3B1250F6148D87b65343b876D92d161D6',
      abi: allABIs['EnhancedSmartStakingView'].abi,
      name: 'EnhancedSmartStakingView'
    }
  },
  marketplace: {
    core: {
      address: '0xA0Ee7A142d267C1f36714E4a8F75612e634a8F07',
      abi: allABIs['GameifiedMarketplaceCoreV1'].abi,
      name: 'GameifiedMarketplaceCoreV1'
    },
    quests: {
      address: '0x90193C961A926261B756D1E5bb255e67ff9498A1',
      abi: allABIs['GameifiedMarketplaceQuests'].abi,
      name: 'GameifiedMarketplaceQuests'
    },
    skills: {
      address: '0x1B61991eCD6BcfEE8b63dBb3e8Dfb3d0B6B1e1F7',
      abi: allABIs['GameifiedMarketplaceSkillsNft'].abi,
      name: 'GameifiedMarketplaceSkillsNft'
    },
    skillsMarketplace: {
      address: '0x0b567F90e8B6A4f1482E1618E1453931Fca4f8D4',
      abi: allABIs['IndividualSkillsMarketplace'].abi,
      name: 'IndividualSkillsMarketplace'
    }
  },
  treasury: {
    manager: {
      address: '0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0',
      abi: allABIs['TreasuryManager'].abi,
      name: 'TreasuryManager'
    }
  }
};

// Luego en tu código
import { CONTRACTS } from '@/config/contracts';
import { ethers } from 'ethers';

const stakingContract = new ethers.Contract(
  CONTRACTS.staking.core.address,
  CONTRACTS.staking.core.abi,
  signer
);
*/

// ════════════════════════════════════════════════════════════════════════════════════════
// 5. HELPER FUNCTION PARA CREAR CONTRATOS
// ════════════════════════════════════════════════════════════════════════════════════════

/*
// Utility function
import allABIs from '@/abis/all-abis.json';
import { ethers } from 'ethers';

export function getContract(
  contractName: string, 
  address: string, 
  signerOrProvider: ethers.Signer | ethers.Provider
) {
  const abiData = allABIs[contractName];
  
  if (!abiData) {
    throw new Error(`ABI not found for contract: ${contractName}`);
  }

  return new ethers.Contract(address, abiData.abi, signerOrProvider);
}

// Uso:
const core = getContract('EnhancedSmartStaking', stakingAddress, signer);
const rewards = getContract('EnhancedSmartStakingRewards', rewardsAddress, provider);
*/

// ════════════════════════════════════════════════════════════════════════════════════════
// 6. ARCHIVO ENV PARA DIRECCIONES (Recomendado)
// ════════════════════════════════════════════════════════════════════════════════════════

/*
# .env.local o .env.polygon

# Staking
VITE_STAKING_CORE_ADDRESS=0xC67F0a0cB719e4f4358D980a5D966878Fd6f3946
VITE_STAKING_REWARDS_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
VITE_STAKING_SKILLS_ADDRESS=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
VITE_STAKING_GAMIFICATION_ADDRESS=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0

# Marketplace
VITE_MARKETPLACE_CORE_ADDRESS=0xA0Ee7A142d267C1f36714E4a8F75612e634a8F07
VITE_MARKETPLACE_QUESTS_ADDRESS=0x90193C961A926261B756D1E5bb255e67ff9498A1
VITE_MARKETPLACE_SKILLS_ADDRESS=0x1B61991eCD6BcfEE8b63dBb3e8Dfb3d0B6B1e1F7

# Treasury
VITE_TREASURY_MANAGER_ADDRESS=0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0

# Luego en el código:
const stakingAddress = import.meta.env.VITE_STAKING_CORE_ADDRESS;
*/

// ════════════════════════════════════════════════════════════════════════════════════════
// 7. REGENERAR ABIs (Cuando compilas nuevos contratos)
// ════════════════════════════════════════════════════════════════════════════════════════

/*
# Primero compila los contratos
npx hardhat compile

# Luego genera los ABIs
node scripts/ExportABIs.cjs
*/

console.log(`
╔════════════════════════════════════════════════════════════════╗
║  📋 ABI EXPORT CONFIGURATION EXAMPLES                         ║
╚════════════════════════════════════════════════════════════════╝

✅ 40 ABIs han sido exportados exitosamente

📁 Archivos generados:
   • frontend/abis/all-abis.json          - Todos los ABIs en un solo archivo
   • frontend/abis/abis-by-category.json  - ABIs organizados por tipo
   • frontend/abis/index.ts               - Importaciones TypeScript

🚀 Próximos pasos:
   1. Copia uno de los ejemplos de arriba
   2. Ajusta las direcciones según tu red (Hardhat vs Polygon)
   3. Importa los ABIs en tu componente
   4. Crea los contratos con ethers.js o Web3.js

💡 Tips:
   • Usa .env.local para guardar direcciones
   • Crea un archivo config/contracts.ts centralizado
   • Regenera ABIs después de compilar cambios: node scripts/ExportABIs.cjs
   • Los ABIs incluyen interfaces completas para Type Safety
`);
