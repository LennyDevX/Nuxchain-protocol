/**
 * Contract Configuration para Frontend
 * Direcciones y ABIs - Polygon Mainnet
 * Fecha: 11 de Noviembre de 2025
 */

// ============================================
// Tipos TypeScript
// ============================================
export interface ContractAddresses {
  GameifiedMarketplaceProxy: string;
  GameifiedMarketplaceSkills: string;
  GameifiedMarketplaceQuests: string;
  EnhancedSmartStaking: string;
}

export interface UserProfile {
  totalXP: number;
  level: number;
  nftsCreated: number;
  nftsOwned: number;
  nftsSold: number;
  nftsBought: number;
}

export interface Skill {
  skillType: SkillType;
  rarity: Rarity;
  level: number;
  createdAt: number;
}

export interface Quest {
  questId: number;
  questType: QuestType;
  title: string;
  description: string;
  requirement: number;
  xpReward: number;
  active: boolean;
  createdAt: number;
}

export interface StakingInfo {
  totalStaked: string;
  totalRewards: string;
  lastRewardTime: number;
  locked: boolean;
}

export enum SkillType {
  CODING = 0,
  DESIGN = 1,
  MARKETING = 2,
  TRADING = 3,
  COMMUNITY = 4,
  WRITING = 5
}

export enum Rarity {
  COMMON = 0,
  UNCOMMON = 1,
  RARE = 2,
  EPIC = 3,
  LEGENDARY = 4
}

export enum QuestType {
  PURCHASE = 0,      // Comprar N NFTs
  CREATE = 1,        // Crear N NFTs
  SOCIAL = 2,        // Like/Comment N veces
  LEVEL_UP = 3,      // Alcanzar nivel N
  TRADING = 4        // Vender N NFTs
}

// ============================================
// Configuración de Contratos
// ============================================
export const CONTRACT_ADDRESSES: ContractAddresses = {
  // 📌 DIRECCIÓN PERMANENTE - USA ESTA EN TU FRONTEND
  GameifiedMarketplaceProxy: '0xfffaCf763A24F265dea7fea23bF0C7d4E131053c',
  
  // Módulos satelite
  GameifiedMarketplaceSkills: '0x418906d96D40D7f557F86b1Eec27902F5930cFb6',
  GameifiedMarketplaceQuests: '0x2c199bc46E7D5041f1CED8329946662acC482605',
  
  // Staking
  EnhancedSmartStaking: '0xd332eAF6f64B1ED524B71a53AFf8eF24Bf750422'
};

// ============================================
// Configuración de Red
// ============================================
export const CHAIN_CONFIG = {
  chainId: 137,
  chainName: 'Polygon',
  nativeCurrency: {
    name: 'MATIC',
    symbol: 'MATIC',
    decimals: 18
  },
  rpcUrls: [
    'https://polygon-mainnet.g.alchemy.com/v2/Oyk0XqXD7K2HQO4bkbDm1w8iZQ6fHulV'
  ],
  blockExplorerUrls: ['https://polygonscan.com']
};

// ============================================
// Funciones Utilitarias
// ============================================
export const getBlockExplorerUrl = (txHash: string): string => {
  return `https://polygonscan.com/tx/${txHash}`;
};

export const getAddressExplorerUrl = (address: string): string => {
  return `https://polygonscan.com/address/${address}`;
};

export const getContractExplorerUrl = (contractAddress: string): string => {
  return `https://polygonscan.com/address/${contractAddress}#code`;
};

// ============================================
// Mapeos de Enums
// ============================================
export const SKILL_TYPE_NAMES = {
  [SkillType.CODING]: 'Coding',
  [SkillType.DESIGN]: 'Design',
  [SkillType.MARKETING]: 'Marketing',
  [SkillType.TRADING]: 'Trading',
  [SkillType.COMMUNITY]: 'Community',
  [SkillType.WRITING]: 'Writing'
};

export const RARITY_NAMES = {
  [Rarity.COMMON]: 'Common',
  [Rarity.UNCOMMON]: 'Uncommon',
  [Rarity.RARE]: 'Rare',
  [Rarity.EPIC]: 'Epic',
  [Rarity.LEGENDARY]: 'Legendary'
};

export const RARITY_COLORS = {
  [Rarity.COMMON]: '#A0AEC0',      // Gris
  [Rarity.UNCOMMON]: '#48BB78',    // Verde
  [Rarity.RARE]: '#4299E1',        // Azul
  [Rarity.EPIC]: '#9F7AEA',        // Púrpura
  [Rarity.LEGENDARY]: '#ED8936'    // Naranja
};

export const QUEST_TYPE_NAMES = {
  [QuestType.PURCHASE]: 'Purchase NFTs',
  [QuestType.CREATE]: 'Create NFTs',
  [QuestType.SOCIAL]: 'Social Engagement',
  [QuestType.LEVEL_UP]: 'Level Up',
  [QuestType.TRADING]: 'Trading Activity'
};

// ============================================
// Constantes de Contratos
// ============================================
export const CONTRACT_CONSTANTS = {
  PLATFORM_FEE_PERCENTAGE: 5,
  MIN_DEPOSIT_STAKING: 10,           // 10 MATIC
  MAX_DEPOSIT_STAKING: 10000,        // 10000 MATIC
  MAX_SKILLS_PER_NFT: 5,
  XP_PER_SKILL: {
    first: 15,
    others: 10
  }
};

// ============================================
// Interfaces de Transacciones
// ============================================
export interface TransactionOptions {
  gasLimit?: string;
  gasPrice?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
}

export interface TransactionReceipt {
  transactionHash: string;
  blockNumber: number;
  blockHash: string;
  from: string;
  to: string;
  gasUsed: string;
  status: number;
}
