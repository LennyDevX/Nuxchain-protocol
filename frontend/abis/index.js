/**
 * ABIS para Frontend - Nuxchain Protocol
 * Extraído de artifacts compilados
 * Fecha: 11 de Noviembre de 2025
 */

// ============================================
// 1. GameifiedMarketplaceCore ABI
// ============================================
export const GAMEIFIED_MARKETPLACE_CORE_ABI = [
  {
    inputs: [],
    name: "InsufficientPayment",
    type: "error"
  },
  {
    inputs: [],
    name: "NoOffersAvailable",
    type: "error"
  },
  {
    inputs: [],
    name: "NotTokenOwner",
    type: "error"
  },
  {
    inputs: [],
    name: "TokenNotFound",
    type: "error"
  },
  {
    inputs: [],
    name: "TokenNotListed",
    type: "error"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "creator",
        type: "address"
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "string",
        name: "uri",
        type: "string"
      }
    ],
    name: "TokenCreated",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "seller",
        type: "address"
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256"
      }
    ],
    name: "TokenListed",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "seller",
        type: "address"
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256"
      }
    ],
    name: "TokenUnlisted",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "seller",
        type: "address"
      },
      {
        indexed: true,
        internalType: "address",
        name: "buyer",
        type: "address"
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256"
      }
    ],
    name: "TokenSold",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "string",
        name: "reason",
        type: "string"
      }
    ],
    name: "XPGained",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint8",
        name: "newLevel",
        type: "uint8"
      }
    ],
    name: "LevelUp",
    type: "event"
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "initialize",
    inputs: [
      {
        internalType: "address",
        name: "_platformTreasury",
        type: "address"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "createStandardNFT",
    inputs: [
      {
        internalType: "string",
        name: "_tokenURI",
        type: "string"
      },
      {
        internalType: "string",
        name: "_category",
        type: "string"
      },
      {
        internalType: "uint96",
        name: "_royaltyPercentage",
        type: "uint96"
      }
    ],
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256"
      }
    ]
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "listTokenForSale",
    inputs: [
      {
        internalType: "uint256",
        name: "_tokenId",
        type: "uint256"
      },
      {
        internalType: "uint256",
        name: "_price",
        type: "uint256"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "payable",
    type: "function",
    name: "buyToken",
    inputs: [
      {
        internalType: "uint256",
        name: "_tokenId",
        type: "uint256"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "toggleLike",
    inputs: [
      {
        internalType: "uint256",
        name: "_tokenId",
        type: "uint256"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "addComment",
    inputs: [
      {
        internalType: "uint256",
        name: "_tokenId",
        type: "uint256"
      },
      {
        internalType: "string",
        name: "_comment",
        type: "string"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "view",
    type: "function",
    name: "userProfiles",
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address"
      }
    ],
    outputs: [
      {
        internalType: "uint256",
        name: "totalXP",
        type: "uint256"
      },
      {
        internalType: "uint8",
        name: "level",
        type: "uint8"
      },
      {
        internalType: "uint256",
        name: "nftsCreated",
        type: "uint256"
      },
      {
        internalType: "uint256",
        name: "nftsOwned",
        type: "uint256"
      },
      {
        internalType: "uint32",
        name: "nftsSold",
        type: "uint32"
      },
      {
        internalType: "uint32",
        name: "nftsBought",
        type: "uint32"
      }
    ]
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "setSkillsContract",
    inputs: [
      {
        internalType: "address",
        name: "_skillsAddress",
        type: "address"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "setQuestsContract",
    inputs: [
      {
        internalType: "address",
        name: "_questsAddress",
        type: "address"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "setStakingContract",
    inputs: [
      {
        internalType: "address",
        name: "_stakingAddress",
        type: "address"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "view",
    type: "function",
    name: "nftLikeCount",
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256"
      }
    ],
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256"
      }
    ]
  },
  {
    stateMutability: "view",
    type: "function",
    name: "nftComments",
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256"
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256"
      }
    ],
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string"
      }
    ]
  }
];

// ============================================
// 2. GameifiedMarketplaceSkills ABI
// ============================================
export const GAMEIFIED_MARKETPLACE_SKILLS_ABI = [
  {
    inputs: [],
    name: "CoreContractNotSet",
    type: "error"
  },
  {
    inputs: [],
    name: "InvalidSkillCount",
    type: "error"
  },
  {
    inputs: [],
    name: "InvalidSkillType",
    type: "error"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "creator",
        type: "address"
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "skillCount",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "totalXP",
        type: "uint256"
      }
    ],
    name: "SkillNFTCreated",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "enum GameifiedMarketplaceSkills.SkillType",
        name: "skillType",
        type: "uint8"
      },
      {
        indexed: false,
        internalType: "enum GameifiedMarketplaceSkills.Rarity",
        name: "rarity",
        type: "uint8"
      }
    ],
    name: "SkillAdded",
    type: "event"
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "registerSkillsForNFT",
    inputs: [
      {
        internalType: "uint256",
        name: "_tokenId",
        type: "uint256"
      },
      {
        internalType: "enum GameifiedMarketplaceSkills.SkillType[]",
        name: "_skillTypes",
        type: "uint8[]"
      },
      {
        internalType: "enum GameifiedMarketplaceSkills.Rarity[]",
        name: "_rarities",
        type: "uint8[]"
      },
      {
        internalType: "uint256[]",
        name: "_levels",
        type: "uint256[]"
      },
      {
        internalType: "uint256",
        name: "_basePrice",
        type: "uint256"
      }
    ],
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256"
      }
    ]
  },
  {
    stateMutability: "view",
    type: "function",
    name: "getSkillNFTSkills",
    inputs: [
      {
        internalType: "uint256",
        name: "_tokenId",
        type: "uint256"
      }
    ],
    outputs: [
      {
        components: [
          {
            internalType: "enum GameifiedMarketplaceSkills.SkillType",
            name: "skillType",
            type: "uint8"
          },
          {
            internalType: "enum GameifiedMarketplaceSkills.Rarity",
            name: "rarity",
            type: "uint8"
          },
          {
            internalType: "uint256",
            name: "level",
            type: "uint256"
          },
          {
            internalType: "uint256",
            name: "createdAt",
            type: "uint256"
          }
        ],
        internalType: "struct GameifiedMarketplaceSkills.Skill[]",
        name: "",
        type: "tuple[]"
      }
    ]
  },
  {
    stateMutability: "view",
    type: "function",
    name: "getUserSkillNFTs",
    inputs: [
      {
        internalType: "address",
        name: "_user",
        type: "address"
      }
    ],
    outputs: [
      {
        internalType: "uint256[]",
        name: "",
        type: "uint256[]"
      }
    ]
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "setStakingContract",
    inputs: [
      {
        internalType: "address",
        name: "_stakingAddress",
        type: "address"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "view",
    type: "function",
    name: "getSkillTypeCount",
    inputs: [
      {
        internalType: "enum GameifiedMarketplaceSkills.SkillType",
        name: "_skillType",
        type: "uint8"
      }
    ],
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256"
      }
    ]
  }
];

// ============================================
// 3. GameifiedMarketplaceQuests ABI
// ============================================
export const GAMEIFIED_MARKETPLACE_QUESTS_ABI = [
  {
    inputs: [],
    name: "AlreadyCompleted",
    type: "error"
  },
  {
    inputs: [],
    name: "QuestNotActive",
    type: "error"
  },
  {
    inputs: [],
    name: "QuestNotFound",
    type: "error"
  },
  {
    inputs: [],
    name: "RequirementNotMet",
    type: "error"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "questId",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "enum GameifiedMarketplaceQuests.QuestType",
        name: "questType",
        type: "uint8"
      },
      {
        indexed: false,
        internalType: "string",
        name: "title",
        type: "string"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "requirement",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "xpReward",
        type: "uint256"
      }
    ],
    name: "QuestCreated",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "questId",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "xpReward",
        type: "uint256"
      }
    ],
    name: "QuestCompleted",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "questId",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "progress",
        type: "uint256"
      }
    ],
    name: "QuestProgressUpdated",
    type: "event"
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "createQuest",
    inputs: [
      {
        internalType: "enum GameifiedMarketplaceQuests.QuestType",
        name: "_questType",
        type: "uint8"
      },
      {
        internalType: "string",
        name: "_title",
        type: "string"
      },
      {
        internalType: "string",
        name: "_description",
        type: "string"
      },
      {
        internalType: "uint256",
        name: "_requirement",
        type: "uint256"
      },
      {
        internalType: "uint256",
        name: "_xpReward",
        type: "uint256"
      }
    ],
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256"
      }
    ]
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "completeQuest",
    inputs: [
      {
        internalType: "uint256",
        name: "_questId",
        type: "uint256"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "view",
    type: "function",
    name: "getUserCompletedQuests",
    inputs: [
      {
        internalType: "address",
        name: "_user",
        type: "address"
      }
    ],
    outputs: [
      {
        internalType: "uint256[]",
        name: "",
        type: "uint256[]"
      }
    ]
  },
  {
    stateMutability: "view",
    type: "function",
    name: "getQuest",
    inputs: [
      {
        internalType: "uint256",
        name: "_questId",
        type: "uint256"
      }
    ],
    outputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "questId",
            type: "uint256"
          },
          {
            internalType: "enum GameifiedMarketplaceQuests.QuestType",
            name: "questType",
            type: "uint8"
          },
          {
            internalType: "string",
            name: "title",
            type: "string"
          },
          {
            internalType: "string",
            name: "description",
            type: "string"
          },
          {
            internalType: "uint256",
            name: "requirement",
            type: "uint256"
          },
          {
            internalType: "uint256",
            name: "xpReward",
            type: "uint256"
          },
          {
            internalType: "bool",
            name: "active",
            type: "bool"
          },
          {
            internalType: "uint256",
            name: "createdAt",
            type: "uint256"
          }
        ],
        internalType: "struct GameifiedMarketplaceQuests.Quest",
        name: "",
        type: "tuple"
      }
    ]
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "setStakingContract",
    inputs: [
      {
        internalType: "address",
        name: "_stakingAddress",
        type: "address"
      }
    ],
    outputs: []
  }
];

// ============================================
// 4. EnhancedSmartStaking ABI (Funciones principales)
// ============================================
export const ENHANCED_SMART_STAKING_ABI = [
  {
    stateMutability: "payable",
    type: "function",
    name: "deposit",
    inputs: [],
    outputs: []
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "withdraw",
    inputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "notifySkillActivation",
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        internalType: "uint256",
        name: "nftId",
        type: "uint256"
      },
      {
        internalType: "enum IStakingIntegration.SkillType",
        name: "skillType",
        type: "uint8"
      },
      {
        internalType: "uint16",
        name: "effectValue",
        type: "uint16"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "nonpayable",
    type: "function",
    name: "notifyQuestCompletion",
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        internalType: "uint256",
        name: "questId",
        type: "uint256"
      },
      {
        internalType: "uint256",
        name: "rewardAmount",
        type: "uint256"
      }
    ],
    outputs: []
  },
  {
    stateMutability: "view",
    type: "function",
    name: "getUserStakingInfo",
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address"
      }
    ],
    outputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "totalStaked",
            type: "uint256"
          },
          {
            internalType: "uint256",
            name: "totalRewards",
            type: "uint256"
          },
          {
            internalType: "uint256",
            name: "lastRewardTime",
            type: "uint256"
          },
          {
            internalType: "bool",
            name: "locked",
            type: "bool"
          }
        ],
        internalType: "struct IStakingIntegration.StakingInfo",
        name: "",
        type: "tuple"
      }
    ]
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256"
      }
    ],
    name: "Deposited",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256"
      }
    ],
    name: "Withdrawn",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "reward",
        type: "uint256"
      }
    ],
    name: "RewardClaimed",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "nftId",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "uint8",
        name: "skillType",
        type: "uint8"
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "effectValue",
        type: "uint16"
      }
    ],
    name: "SkillActivationNotified",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "questId",
        type: "uint256"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "rewardAmount",
        type: "uint256"
      }
    ],
    name: "QuestCompletionNotified",
    type: "event"
  }
];

// ============================================
// Exports - Usar en tu Frontend
// ============================================
export const CONTRACT_ABIS = {
  GameifiedMarketplaceCore: GAMEIFIED_MARKETPLACE_CORE_ABI,
  GameifiedMarketplaceSkills: GAMEIFIED_MARKETPLACE_SKILLS_ABI,
  GameifiedMarketplaceQuests: GAMEIFIED_MARKETPLACE_QUESTS_ABI,
  EnhancedSmartStaking: ENHANCED_SMART_STAKING_ABI,
};

export default CONTRACT_ABIS;
