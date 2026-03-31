export const SkillType = Object.freeze({
  STAKING_BOOST_I: 0,
  STAKING_BOOST_II: 1,
  FEE_REDUCER_I: 2,
  FEE_REDUCER_II: 3,
  LOCK_REDUCER: 4,
  AUTO_COMPOUND: 5
});

export const Rarity = Object.freeze({
  COMMON: 0,
  UNCOMMON: 1,
  RARE: 2,
  EPIC: 3,
  LEGENDARY: 4
});

export const QuestType = Object.freeze({
  PURCHASE: 0,
  CREATE: 1,
  SOCIAL: 2,
  LEVEL_UP: 3,
  TRADING: 4,
  STAKE: 5,
  COMPOUND: 6,
  AGENT_TASK: 7
});

export const QuestCategory = Object.freeze({
  MARKETPLACE: 0,
  STAKING: 1,
  NFT_AGENT: 2,
  GENERAL: 3
});

export const NuxTapItemKind = Object.freeze({
  NONE: 0,
  AUTO_TAP: 1,
  BOOSTER: 2,
  WITHDRAW_PASS: 3,
  AGENT_NFT: 4
});

export const ProtocolStatus = Object.freeze({
  HEALTHY: 0,
  WARNING: 1,
  CRITICAL: 2,
  CIRCUIT_BREAKER: 3
});

export const POLYGON_MAINNET = Object.freeze({
  chainId: "0x89",
  chainName: "Polygon Mainnet",
  nativeCurrency: {
    name: "POL",
    symbol: "POL",
    decimals: 18
  },
  rpcUrls: [
    "https://polygon-rpc.com",
    "https://polygon-mainnet.g.alchemy.com/v2/Oyk0XqXD7K2HQO4bkbDm1w8iZQ6fHulV"
  ],
  blockExplorerUrls: ["https://polygonscan.com"]
});

export const getBlockExplorerUrl = (txHash) =>
  `https://polygonscan.com/tx/${txHash}`;

export const getAddressExplorerUrl = (address) =>
  `https://polygonscan.com/address/${address}`;

export const getContractExplorerUrl = (contractAddress) =>
  `https://polygonscan.com/address/${contractAddress}#code`;

export const SKILL_TYPE_NAMES = Object.freeze({
  [SkillType.STAKING_BOOST_I]: "Staking Boost I",
  [SkillType.STAKING_BOOST_II]: "Staking Boost II",
  [SkillType.FEE_REDUCER_I]: "Fee Reducer I",
  [SkillType.FEE_REDUCER_II]: "Fee Reducer II",
  [SkillType.LOCK_REDUCER]: "Lock Reducer",
  [SkillType.AUTO_COMPOUND]: "Auto Compound"
});

export const RARITY_NAMES = Object.freeze({
  [Rarity.COMMON]: "Common",
  [Rarity.UNCOMMON]: "Uncommon",
  [Rarity.RARE]: "Rare",
  [Rarity.EPIC]: "Epic",
  [Rarity.LEGENDARY]: "Legendary"
});

export const RARITY_COLORS = Object.freeze({
  [Rarity.COMMON]: "#A0AEC0",
  [Rarity.UNCOMMON]: "#48BB78",
  [Rarity.RARE]: "#4299E1",
  [Rarity.EPIC]: "#9F7AEA",
  [Rarity.LEGENDARY]: "#ED8936"
});

export const QUEST_TYPE_NAMES = Object.freeze({
  [QuestType.PURCHASE]: "Purchase NFTs",
  [QuestType.CREATE]: "Create NFTs",
  [QuestType.SOCIAL]: "Social Engagement",
  [QuestType.LEVEL_UP]: "Level Up",
  [QuestType.TRADING]: "Trading Activity",
  [QuestType.STAKE]: "Stake POL",
  [QuestType.COMPOUND]: "Compound Rewards",
  [QuestType.AGENT_TASK]: "Agent Tasks"
});

export const QUEST_CATEGORY_NAMES = Object.freeze({
  [QuestCategory.MARKETPLACE]: "Marketplace",
  [QuestCategory.STAKING]: "Staking",
  [QuestCategory.NFT_AGENT]: "NFT Agent",
  [QuestCategory.GENERAL]: "General"
});

export const PROTOCOL_STATUS_NAMES = Object.freeze({
  [ProtocolStatus.HEALTHY]: "Healthy",
  [ProtocolStatus.WARNING]: "Warning",
  [ProtocolStatus.CRITICAL]: "Critical",
  [ProtocolStatus.CIRCUIT_BREAKER]: "Circuit Breaker"
});

export const LOCKUP_PERIODS = Object.freeze([
  Object.freeze({ index: 0, label: "30 días", days: 30, seconds: 2592000 }),
  Object.freeze({ index: 1, label: "60 días", days: 60, seconds: 5184000 }),
  Object.freeze({ index: 2, label: "90 días", days: 90, seconds: 7776000 }),
  Object.freeze({ index: 3, label: "180 días", days: 180, seconds: 15552000 })
]);

export const CONTRACT_CONSTANTS = Object.freeze({
  PLATFORM_FEE_BPS: 500,
  REINVESTMENT_MIN_BPS: 0,
  REINVESTMENT_MAX_BPS: 10000,
  MAX_ACTIVE_SKILLS_DEFAULT: 3,
  CIRCUIT_BREAKER_THRESHOLD_BPS: 5000,
  EARLY_EXIT_FEE_BASE_BPS: 1000,
  DEPLOYMENT_BLOCK: 83546246,
  CHAIN_ID: 137
});