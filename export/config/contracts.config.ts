/**
 * Contract Configuration — Nuxchain Protocol Frontend
 * Polygon Mainnet (ChainID 137)
 * Deployment block: 83626688 | Date: 2026-03-01
 * Version: v6.3.0
 */

// ============================================
// Contract Addresses Interface (19 contracts)
// ============================================
export interface ContractAddresses {
  // --- Smart Staking ---
  StakingCore:           string;  // SmartStakingCore
  StakingRewards:        string;  // SmartStakingRewards
  StakingSkills:         string;  // SmartStakingPower
  StakingGamification:   string;  // Gamification
  StakingViewCore:       string;  // SmartStakingViewCore
  StakingViewStats:      string;  // SmartStakingViewStats
  StakingViewSkills:     string;  // SmartStakingViewSkills
  DynamicAPYCalculator:  string;  // DynamicAPYCalculator
  // --- Marketplace ---
  MarketplaceProxy:      string;  // GameifiedMarketplaceProxy (UUPS)
  MarketplaceLeveling:   string;  // LevelingSystem
  MarketplaceReferral:   string;  // ReferralSystem
  MarketplaceSkillsNFT:  string;  // GameifiedMarketplaceSkillsNft
  IndividualSkills:      string;  // IndividualSkillsMarketplace
  QuestCore:             string;  // QuestCore
  CollaboratorBadges:    string;  // CollaboratorBadgeRewards
  MarketplaceView:       string;  // MarketplaceView
  MarketplaceStatistics: string;  // MarketplaceStatistics
  MarketplaceSocial:     string;  // MarketplaceSocial
  NuxAgentView?:         string;  // NuxAgentView
  // --- Treasury ---
  TreasuryManager:       string;  // TreasuryManager

  // --- NuxTap ---
  NuxTapGame?:           string;  // NuxTapGame
  NuxTapAgentMarketplace?: string;  // NuxTapAgentMarketplace
  NuxTapStore?:          string;  // NuxTapItemStore
  NuxTapTreasury?:       string;  // NuxTapTreasury

  // Power aliases kept in frontend for the renamed product language.
  StakingPowers?:        string;
  StakingViewPowers?:    string;
  MarketplacePowerNFT?:  string;
  IndividualPowers?:     string;
}

// ============================================
// Deployed Addresses — Polygon Mainnet v6.3.0
// ============================================
export const CONTRACT_ADDRESSES: ContractAddresses = {
  // Smart Staking
  StakingCore:           '0x2cda88046543be25a3EC4eA2d86dBe975Fda0028',
  StakingRewards:        '0xEa481FB987d95F8a58730bBd89a91ef733f8C128',
  StakingSkills:         '0x4cF5F1eDfACC19E2FABC1Ec2955A0de4b222025d',
  StakingGamification:   '0x58b38720BE35eDD36e3D252ea41e8B0a9629EA1F',
  StakingViewCore:       '0xDd21d682f3625eF90c446C8DE622A51e4084DA56',
  StakingViewStats:      '0x994BC04688577066CD4c6E55B459788dfe408007',
  StakingViewSkills:     '0xc5a07f94b5Ecaaf8E65d9F3adb7AB590550a9bE9',
  DynamicAPYCalculator:  '0xb3900912495c02191C96631141e5A169669E2ced',
  // Marketplace
  MarketplaceProxy:      '0xc8Af452F3842805Bc79bfFBBbDB9b130f222d9BC',
  MarketplaceLeveling:   '0xC1f6f5b27F58bbB7a61C177D1D8782B117e28A91',
  MarketplaceReferral:   '0xBCEFd299776237e6D7cf0d08E030582cE3214C90',
  MarketplaceSkillsNFT:  '0xe09e85E7AEd3A35fa77DCaC44D110664C42A4DCd',
  IndividualSkills:      '0x2248e909EC9E122D1D7206E86D2061681EfCC49B',
  QuestCore:             '0x090774e87CFF7478910fbF8f035fA85414a8625a',
  CollaboratorBadges:    '0xc9B1bf1ae921280f2f048fd3d893AF6D18E99C51',
  MarketplaceView:       '0x579d34872d25a56235D61138dBdE1c81a6f20f4d',
  MarketplaceStatistics: '0x7C4c72d3D1b9a54178254c79Ca4F788111A9c99D',
  MarketplaceSocial:     '0x4FE695192c20E2D9b4bDB0A18F168e198F7e9557',
  // Treasury
  TreasuryManager:       '0x312a3c5072c9DE2aB5cbDd799b3a65fb053DF043',

  // Power aliases
  StakingPowers:         '0x4cF5F1eDfACC19E2FABC1Ec2955A0de4b222025d',
  StakingViewPowers:     '0xc5a07f94b5Ecaaf8E65d9F3adb7AB590550a9bE9',
  MarketplacePowerNFT:   '0xe09e85E7AEd3A35fa77DCaC44D110664C42A4DCd',
  IndividualPowers:      '0x2248e909EC9E122D1D7206E86D2061681EfCC49B'
};

// ============================================
// Wallet addresses
// ============================================
export const WALLET_ADDRESSES = {
  deployer: '0x581A41c663223bAE563134C67151CdC2C274f06A',
  treasury: '0xe67cbb6c94353903ddbb15fd376e0967bdef13b1'
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
// QuestCore Enums
// ============================================
export enum QuestType {
  PURCHASE   = 0,
  CREATE     = 1,
  SOCIAL     = 2,
  LEVEL_UP   = 3,
  TRADING    = 4,
  STAKE      = 5,
  COMPOUND   = 6,
  AGENT_TASK = 7
}

export enum QuestCategory {
  MARKETPLACE = 0,
  STAKING     = 1,
  NFT_AGENT   = 2,
  GENERAL     = 3
}

// ============================================
// TypeScript Interfaces — Smart Staking
// ============================================

/** Single deposit details (SmartStakingCore) */
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

export type UserPowerProfile = UserSkillProfile;

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

export type IndividualPower = IndividualSkill;

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

export type PowerNFTInfo = SkillNFTInfo;

export type PowerType = SkillType;

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
// TypeScript Interfaces — NuxTap
// ============================================

export interface NuxTapPlayerProfile {
  totalScore: bigint;
  lifetimeTaps: bigint;
  totalSessions: bigint;
  unclaimedRewards: bigint;
  claimedRewards: bigint;
  currentLevel: bigint;
  currentStreak: bigint;
  bestStreak: bigint;
  autoTapRate: bigint;
  boosterMultiplierBps: bigint;
  boosterExpiresAt: bigint;
  lastSettlementAt: bigint;
  lastActiveDay: bigint;
  dailyTapCount: bigint;
  linkedNftContract: string;
  linkedTokenId: bigint;
}

export interface NuxTapLevelConfig {
  scoreRequired: bigint;
  dailyTapCap: bigint;
  rewardMultiplierBps: bigint;
}

export interface NuxTapLinkedAgent {
  nftContract: string;
  tokenId: bigint;
}

export interface NuxTapTreasuryStats {
  balance: bigint;
  rewardBalance: bigint;
  available: bigint;
  reserved: bigint;
  distributed: bigint;
  feesRetained: bigint;
  revenueReceived: bigint;
}

export enum NuxTapItemKind {
  NONE = 0,
  AUTO_TAP = 1,
  BOOSTER = 2,
  WITHDRAW_PASS = 3,
  AGENT_NFT = 4
}

export interface NuxTapItemConfig {
  kind: NuxTapItemKind;
  price: bigint;
  value: bigint;
  duration: bigint;
  stock: bigint;
  active: boolean;
  soulbound: boolean;
  nftContract: string;
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
  [QuestType.PURCHASE]:   'Purchase NFTs',
  [QuestType.CREATE]:     'Create NFTs',
  [QuestType.SOCIAL]:     'Social Engagement',
  [QuestType.LEVEL_UP]:   'Level Up',
  [QuestType.TRADING]:    'Trading Activity',
  [QuestType.STAKE]:      'Stake POL',
  [QuestType.COMPOUND]:   'Compound Rewards',
  [QuestType.AGENT_TASK]: 'Agent Tasks'
};

export const QUEST_CATEGORY_NAMES: Record<QuestCategory, string> = {
  [QuestCategory.MARKETPLACE]: 'Marketplace',
  [QuestCategory.STAKING]:     'Staking',
  [QuestCategory.NFT_AGENT]:   'NFT Agent',
  [QuestCategory.GENERAL]:     'General'
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
