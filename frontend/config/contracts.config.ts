/**
 * Contract Configuration — Nuxchain Protocol Frontend
 * Polygon Mainnet (ChainID 137)
 * Deployment block: 83546246 | Date: 2026-02-27
 * Version: v6.2.0
 */

// ============================================
// Contract Addresses Interface (19 contracts)
// ============================================
export interface ContractAddresses {
  // --- Smart Staking ---
  StakingCore:           string;  // EnhancedSmartStakingCoreV2
  StakingRewards:        string;  // EnhancedSmartStakingRewards
  StakingSkills:         string;  // EnhancedSmartStakingSkills
  StakingGamification:   string;  // EnhancedSmartStakingGamification
  StakingViewCore:       string;  // EnhancedSmartStakingViewCore
  StakingViewStats:      string;  // EnhancedSmartStakingViewStats
  StakingViewSkills:     string;  // EnhancedSmartStakingViewSkills
  DynamicAPYCalculator:  string;  // DynamicAPYCalculator
  // --- Marketplace ---
  MarketplaceProxy:      string;  // GameifiedMarketplaceProxy (UUPS)
  MarketplaceLeveling:   string;  // LevelingSystem
  MarketplaceReferral:   string;  // ReferralSystem
  MarketplaceSkillsNFT:  string;  // GameifiedMarketplaceSkillsNft
  IndividualSkills:      string;  // IndividualSkillsMarketplace
  MarketplaceQuests:     string;  // GameifiedMarketplaceQuests
  CollaboratorBadges:    string;  // CollaboratorBadgeRewards
  MarketplaceView:       string;  // MarketplaceView
  MarketplaceStatistics: string;  // MarketplaceStatistics
  MarketplaceSocial:     string;  // MarketplaceSocial
  // --- Treasury ---
  TreasuryManager:       string;  // TreasuryManager
}

// ============================================
// Deployed Addresses — Polygon Mainnet v6.2.0
// ============================================
export const CONTRACT_ADDRESSES: ContractAddresses = {
  // Smart Staking
  StakingCore:           '0x642E60a50d8b61Cf44A671F20ac03301bE55104B',
  StakingRewards:        '0x91B08eC5d101Bfcd86ac96E70b434cd31E233fA3',
  StakingSkills:         '0x95aB1642AA371F583ed3959F04bEe55675708Ad5',
  StakingGamification:   '0xcCaca85B84dFF2e8195570F5a71FE146F7C1E758',
  StakingViewCore:       '0x5c756A9a3034312E540AB47C674A37ABB7c302Fd',
  StakingViewStats:      '0x38266Acc1d334013b611Bb088eF0D82AC564B78D',
  StakingViewSkills:     '0x92Eb2717CF4973fAA397f5F915277477E15f3b76',
  DynamicAPYCalculator:  '0xef5380c18cb7D4f66618329E492FaaD4a84F47C3',
  // Marketplace
  MarketplaceProxy:      '0x65BD8E08c02c1121cE44210C249E0760f18eB64f',
  MarketplaceLeveling:   '0xd077F3D85a7cfE93518567cCc9045F748c10E0ce',
  MarketplaceReferral:   '0x27c629be5AA56593D4B6dF723BF28EA0aFF6B7F2',
  MarketplaceSkillsNFT:  '0x6c0D178E75eA924f8AC0Af8B6F740C48f54D2084',
  IndividualSkills:      '0x21dC162354576fd359535D584B3c72C3cc251939',
  MarketplaceQuests:     '0x92770D64E621cB82e32FD459a5259D51e94aDdCE',
  CollaboratorBadges:    '0x31864c4594127631456758854a6f2d0b404EcAf4',
  MarketplaceView:       '0x3c1e8e6192e128b903F5E308f7d82A6ebdc6175e',
  MarketplaceStatistics: '0xeA37D26a4d2cA03dA4e9FADdd59cA14e6aBe8070',
  MarketplaceSocial:     '0xd2162715503B016F073C5fF48818FAdE6A33d8ef',
  // Treasury
  TreasuryManager:       '0x0cfad488352beA84621a4CA4D7764041Da34C079'
};

// ============================================
// Wallet addresses
// ============================================
export const WALLET_ADDRESSES = {
  deployer: '0x604a3cD727E72216375dbbFB76b3fc9C75C4D767',
  treasury: '0x9a7fac014e2056835878d1866651d673b0ba9407'
};

// ============================================
// SkillType Enum — Staking Skills (v6.2.0)
// Matches IStakingIntegration.SkillType
// ============================================
export enum SkillType {
  STAKING_BOOST_I  = 0,
  STAKING_BOOST_II = 1,
  FEE_REDUCER_I    = 2,
  FEE_REDUCER_II   = 3,
  LOCK_REDUCER     = 4,
  AUTO_COMPOUND    = 5
}

// ============================================
// Rarity Enum
// Matches IStakingIntegration.Rarity
// ============================================
export enum Rarity {
  COMMON    = 0,
  UNCOMMON  = 1,
  RARE      = 2,
  EPIC      = 3,
  LEGENDARY = 4
}

// ============================================
// Marketplace QuestType Enum
// ============================================
export enum QuestType {
  PURCHASE = 0,
  CREATE   = 1,
  SOCIAL   = 2,
  LEVEL_UP = 3,
  TRADING  = 4
}

// ============================================
// TypeScript Interfaces — Smart Staking
// ============================================

/** Single deposit details (EnhancedSmartStakingCoreV2) */
export interface DepositDetails {
  amount: bigint;
  depositTime: number;
  lastClaimTime: number;
  lockupPeriodIndex: number;  // 0=30d, 1=60d, 2=90d, 3=180d
  referrer: string;
  reinvestmentPercentage: number; // bps
}

/** Full user position (getCompleteUserInfo) */
export interface UserStakingInfo {
  deposits: DepositDetails[];
  totalDeposited: bigint;
  totalRewards: bigint;
  pendingRewards: bigint;
  isCircuitBreakerActive: boolean;
  depositCount: number;
}

/** Staking rates / APY info */
export interface StakingRatesInfo {
  baseAPYs: bigint[];           // [30d, 60d, 90d, 180d] in basis points
  dynamicAPYs: bigint[];
  earlyExitFees: bigint[];      // bps per lockup
  lockupDurations: bigint[];    // seconds
}

/** Pool health (ViewStats) */
export interface PoolHealthStatus {
  status: number;           // 0=HEALTHY, 1=WARNING, 2=CRITICAL, 3=CIRCUIT_BREAKER
  contractBalance: bigint;
  totalPendingRewards: bigint;
  deficit: bigint;
  canPayRewards: boolean;
  healthPercentage: bigint;
}

/** User rewards projection (ViewStats) */
export interface UserRewardsProjection {
  estimatedDailyRewards: bigint;
  estimatedMonthlyRewards: bigint;
  projectedAPY: bigint;
  timeToNextClaim: bigint;
}

/** Lockup analysis (ViewCore) */
export interface LockupAnalysis {
  depositIndex: number;
  lockupName: string;
  daysRemaining: bigint;
  currentRewards: bigint;
  penaltyIfExitNow: bigint;
  maturityTimestamp: bigint;
}

/** DynamicAPY simulator result */
export interface DynamicAPYSimulation {
  baseAPY: bigint;
  dynamicAPY: bigint;
  multiplier: bigint;
  compressionBps: bigint;
}

// ============================================
// TypeScript Interfaces — Skills
// ============================================

/** User skill profile (ViewSkills / Skills module) */
export interface UserSkillProfile {
  activeSkillNFTIds: bigint[];
  totalBoost: number;           // bps
  stakingBoostTotal: number;    // bps
  feeDiscountTotal: number;     // bps
  lockTimeReduction: number;    // bps
  hasAutoCompound: boolean;
  rarityMultiplier: number;
  level: number;
  activeSkillCount: number;
}

/** Individual skill (IndividualSkillsMarketplace) */
export interface IndividualSkill {
  skillType: SkillType;
  rarity: Rarity;
  level: bigint;
  owner: string;
  purchasedAt: bigint;
  expiresAt: bigint;
  isActive: boolean;
  metadata: string;
  createdAt: bigint;
}

/** NFT Skill info (Skills module) */
export interface SkillNFTInfo {
  nftId: bigint;
  skillType: SkillType;
  rarity: Rarity;
  boost: number;
  rarityMultiplier: number;
  isActive: boolean;
  activatedAt: bigint;
  cooldownEnds: bigint;
}

// ============================================
// TypeScript Interfaces — Marketplace
// ============================================

export interface UserProfile {
  totalXP: bigint;
  level: number;
  maxActiveSkills: number;
  skillsLevel: number;
  nftsCreated: bigint;
  nftsSold: bigint;
  nftsBought: bigint;
  lastActivityTimestamp: bigint;
}

export interface NFTMetadata {
  creator: string;
  uri: string;
  category: string;
  createdAt: bigint;
  royaltyPercentage: number;
}

export interface ReferralInfo {
  referrer: string;
  totalReferrals: bigint;
  rewardsEarned: bigint;
}

// ============================================
// TypeScript Interfaces — Treasury
// ============================================

/** Protocol status (TreasuryManager) */
export enum ProtocolStatus {
  HEALTHY        = 0,
  WARNING        = 1,
  CRITICAL       = 2,
  CIRCUIT_BREAKER = 3
}

// ============================================
// TypeScript Interfaces — Transactions
// ============================================
export interface TransactionOptions {
  gasLimit?: string;
  gasPrice?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
  value?: bigint;
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

// ============================================
// Network Config — Polygon Mainnet
// ============================================
export const POLYGON_MAINNET = {
  chainId: '0x89',
  chainName: 'Polygon Mainnet',
  nativeCurrency: {
    name: 'POL',
    symbol: 'POL',
    decimals: 18
  },
  rpcUrls: [
    'https://polygon-rpc.com',
    'https://polygon-mainnet.g.alchemy.com/v2/Oyk0XqXD7K2HQO4bkbDm1w8iZQ6fHulV'
  ],
  blockExplorerUrls: ['https://polygonscan.com']
};

// ============================================
// Utility Functions
// ============================================
export const getBlockExplorerUrl = (txHash: string): string =>
  `https://polygonscan.com/tx/${txHash}`;

export const getAddressExplorerUrl = (address: string): string =>
  `https://polygonscan.com/address/${address}`;

export const getContractExplorerUrl = (contractAddress: string): string =>
  `https://polygonscan.com/address/${contractAddress}#code`;

// ============================================
// Enum Display Maps
// ============================================
export const SKILL_TYPE_NAMES: Record<SkillType, string> = {
  [SkillType.STAKING_BOOST_I]:  'Staking Boost I',
  [SkillType.STAKING_BOOST_II]: 'Staking Boost II',
  [SkillType.FEE_REDUCER_I]:    'Fee Reducer I',
  [SkillType.FEE_REDUCER_II]:   'Fee Reducer II',
  [SkillType.LOCK_REDUCER]:     'Lock Reducer',
  [SkillType.AUTO_COMPOUND]:    'Auto Compound'
};

export const RARITY_NAMES: Record<Rarity, string> = {
  [Rarity.COMMON]:    'Common',
  [Rarity.UNCOMMON]:  'Uncommon',
  [Rarity.RARE]:      'Rare',
  [Rarity.EPIC]:      'Epic',
  [Rarity.LEGENDARY]: 'Legendary'
};

export const RARITY_COLORS: Record<Rarity, string> = {
  [Rarity.COMMON]:    '#A0AEC0',
  [Rarity.UNCOMMON]:  '#48BB78',
  [Rarity.RARE]:      '#4299E1',
  [Rarity.EPIC]:      '#9F7AEA',
  [Rarity.LEGENDARY]: '#ED8936'
};

export const QUEST_TYPE_NAMES: Record<QuestType, string> = {
  [QuestType.PURCHASE]: 'Purchase NFTs',
  [QuestType.CREATE]:   'Create NFTs',
  [QuestType.SOCIAL]:   'Social Engagement',
  [QuestType.LEVEL_UP]: 'Level Up',
  [QuestType.TRADING]:  'Trading Activity'
};

export const PROTOCOL_STATUS_NAMES: Record<ProtocolStatus, string> = {
  [ProtocolStatus.HEALTHY]:         'Healthy',
  [ProtocolStatus.WARNING]:         'Warning',
  [ProtocolStatus.CRITICAL]:        'Critical',
  [ProtocolStatus.CIRCUIT_BREAKER]: 'Circuit Breaker'
};

// ============================================
// Lockup Period Constants
// ============================================
export const LOCKUP_PERIODS = [
  { index: 0, label: '30 días',  days: 30,  seconds: 2592000 },
  { index: 1, label: '60 días',  days: 60,  seconds: 5184000 },
  { index: 2, label: '90 días',  days: 90,  seconds: 7776000 },
  { index: 3, label: '180 días', days: 180, seconds: 15552000 }
];

// ============================================
// Contract Constants (v6.2.0)
// ============================================
export const CONTRACT_CONSTANTS = {
  PLATFORM_FEE_BPS: 500,             // 5% en basis points
  REINVESTMENT_MIN_BPS: 0,
  REINVESTMENT_MAX_BPS: 10000,
  MAX_ACTIVE_SKILLS_DEFAULT: 3,
  CIRCUIT_BREAKER_THRESHOLD_BPS: 5000,
  EARLY_EXIT_FEE_BASE_BPS: 1000,     // 10% base (varía por lockup)
  DEPLOYMENT_BLOCK: 83546246,
  CHAIN_ID: 137
};
