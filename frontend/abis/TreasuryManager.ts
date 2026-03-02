/**
 * TreasuryManager — Full ABI
 * Contract: 0x0cfad488352beA84621a4CA4D7764041Da34C079 (Polygon Mainnet)
 * Version: v6.2.0
 *
 * Includes all read + write functions for treasury health dashboard.
 */
export const TreasuryManagerABI = [
  // ── State variables (public getters) ─────────────────────────────────────
  { inputs: [], name: "owner",                     outputs: [{ internalType: "address",  name: "", type: "address"  }], stateMutability: "view", type: "function" },
  { inputs: [], name: "totalRevenueReceived",      outputs: [{ internalType: "uint256",  name: "", type: "uint256"  }], stateMutability: "view", type: "function" },
  { inputs: [], name: "totalDistributed",          outputs: [{ internalType: "uint256",  name: "", type: "uint256"  }], stateMutability: "view", type: "function" },
  { inputs: [], name: "reserveFundBalance",        outputs: [{ internalType: "uint256",  name: "", type: "uint256"  }], stateMutability: "view", type: "function" },
  { inputs: [], name: "totalReserveAccumulated",   outputs: [{ internalType: "uint256",  name: "", type: "uint256"  }], stateMutability: "view", type: "function" },
  { inputs: [], name: "totalReserveWithdrawn",     outputs: [{ internalType: "uint256",  name: "", type: "uint256"  }], stateMutability: "view", type: "function" },
  { inputs: [], name: "reserveAllocationPercentage", outputs: [{ internalType: "uint256", name: "", type: "uint256" }], stateMutability: "view", type: "function" },
  { inputs: [], name: "reserveAccumulationEnabled", outputs: [{ internalType: "bool",    name: "", type: "bool"     }], stateMutability: "view", type: "function" },
  { inputs: [], name: "firstDepositTime",          outputs: [{ internalType: "uint256",  name: "", type: "uint256"  }], stateMutability: "view", type: "function" },
  { inputs: [], name: "lastDistributionTime",      outputs: [{ internalType: "uint256",  name: "", type: "uint256"  }], stateMutability: "view", type: "function" },
  { inputs: [], name: "nextDistributionTime",      outputs: [{ internalType: "uint256",  name: "", type: "uint256"  }], stateMutability: "view", type: "function" },
  { inputs: [], name: "autoDistributionEnabled",   outputs: [{ internalType: "bool",     name: "", type: "bool"     }], stateMutability: "view", type: "function" },
  { inputs: [], name: "emergencyModeEnabled",      outputs: [{ internalType: "bool",     name: "", type: "bool"     }], stateMutability: "view", type: "function" },
  { inputs: [], name: "lastEmergencyTimestamp",    outputs: [{ internalType: "uint256",  name: "", type: "uint256"  }], stateMutability: "view", type: "function" },
  { inputs: [], name: "totalEmergencyFundsDistributed", outputs: [{ internalType: "uint256", name: "", type: "uint256" }], stateMutability: "view", type: "function" },
  {
    inputs: [{ internalType: "address", name: "", type: "address" }],
    name: "authorizedSources",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [{ internalType: "address", name: "", type: "address" }],
    name: "authorizedRequester",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [{ internalType: "uint8", name: "", type: "uint8" }],
    name: "treasuries",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [{ internalType: "uint8", name: "", type: "uint8" }],
    name: "allocations",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [{ internalType: "uint8", name: "", type: "uint8" }],
    name: "protocolStatus",
    outputs: [{ internalType: "uint8", name: "", type: "uint8" }],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [{ internalType: "uint8", name: "", type: "uint8" }],
    name: "protocolDeficit",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view", type: "function"
  },

  // ── View functions ────────────────────────────────────────────────────────
  {
    inputs: [],
    name: "getBalance",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [],
    name: "getAvailableBalance",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [],
    name: "getStats",
    outputs: [
      { internalType: "uint256", name: "totalReceived",    type: "uint256" },
      { internalType: "uint256", name: "totalDist",        type: "uint256" },
      { internalType: "uint256", name: "currentBalance",   type: "uint256" },
      { internalType: "uint256", name: "availableBalance", type: "uint256" },
      { internalType: "uint256", name: "lastDistribution", type: "uint256" },
      { internalType: "bool",    name: "autoDistEnabled",  type: "bool"    },
    ],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [],
    name: "getReserveStats",
    outputs: [
      { internalType: "uint256", name: "currentBalance",       type: "uint256" },
      { internalType: "uint256", name: "totalAccumulated",     type: "uint256" },
      { internalType: "uint256", name: "totalWithdrawn",       type: "uint256" },
      { internalType: "uint256", name: "allocationPercentage", type: "uint256" },
      { internalType: "bool",    name: "isEnabled",            type: "bool"    },
    ],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [],
    name: "getDistributionTimeline",
    outputs: [
      { internalType: "uint256", name: "firstDeposit",    type: "uint256" },
      { internalType: "uint256", name: "lastDistribution",type: "uint256" },
      { internalType: "uint256", name: "nextDistribution",type: "uint256" },
      { internalType: "uint256", name: "timeUntilNext",   type: "uint256" },
      { internalType: "bool",    name: "isReady",         type: "bool"    },
    ],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [],
    name: "isDistributionReady",
    outputs: [
      { internalType: "bool",    name: "ready",        type: "bool"    },
      { internalType: "uint256", name: "timeUntilNext", type: "uint256" },
    ],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [],
    name: "getAllAllocations",
    outputs: [
      { internalType: "uint256", name: "rewardsAlloc",      type: "uint256" },
      { internalType: "uint256", name: "stakingAlloc",      type: "uint256" },
      { internalType: "uint256", name: "collaboratorsAlloc",type: "uint256" },
      { internalType: "uint256", name: "developmentAlloc",  type: "uint256" },
      { internalType: "uint256", name: "marketplaceAlloc",  type: "uint256" },
    ],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [{ internalType: "uint8", name: "treasuryType", type: "uint8" }],
    name: "getTreasuryConfig",
    outputs: [
      { internalType: "address", name: "treasuryAddress", type: "address" },
      { internalType: "uint256", name: "allocation",      type: "uint256" },
    ],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [],
    name: "getEmergencyInfo",
    outputs: [
      { internalType: "bool",    name: "isActive",               type: "bool"    },
      { internalType: "uint256", name: "timestamp",              type: "uint256" },
      { internalType: "uint256", name: "emergencyFundsDistributed", type: "uint256" },
      { internalType: "uint256", name: "reserveAvailable",       type: "uint256" },
    ],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [{ internalType: "uint8", name: "protocol", type: "uint8" }],
    name: "getProtocolStatus",
    outputs: [
      { internalType: "uint8",   name: "status",           type: "uint8"   },
      { internalType: "uint256", name: "deficit",          type: "uint256" },
      { internalType: "bool",    name: "canAccessEmergency", type: "bool"  },
    ],
    stateMutability: "view", type: "function"
  },
  {
    inputs: [{ internalType: "uint256", name: "monthlyBurnRate", type: "uint256" }],
    name: "getReserveRunwayMonths",
    outputs: [{ internalType: "uint256", name: "months", type: "uint256" }],
    stateMutability: "view", type: "function"
  },

  // ── Write functions (owner) ───────────────────────────────────────────────
  {
    inputs: [],
    name: "triggerDistribution",
    outputs: [],
    stateMutability: "nonpayable", type: "function"
  },
  {
    inputs: [],
    name: "depositToReserve",
    outputs: [],
    stateMutability: "payable", type: "function"
  },
  {
    inputs: [{ internalType: "address", name: "source", type: "address" }, { internalType: "bool", name: "authorized", type: "bool" }],
    name: "setAuthorizedSource",
    outputs: [],
    stateMutability: "nonpayable", type: "function"
  },
  {
    inputs: [{ internalType: "address", name: "requester", type: "address" }, { internalType: "bool", name: "authorized", type: "bool" }],
    name: "setAuthorizedRequester",
    outputs: [],
    stateMutability: "nonpayable", type: "function"
  },
  {
    inputs: [{ internalType: "bool", name: "enabled", type: "bool" }],
    name: "setAutoDistribution",
    outputs: [],
    stateMutability: "nonpayable", type: "function"
  },
  {
    inputs: [{ internalType: "string", name: "reason", type: "string" }],
    name: "declareEmergency",
    outputs: [],
    stateMutability: "nonpayable", type: "function"
  },
  {
    inputs: [],
    name: "endEmergency",
    outputs: [],
    stateMutability: "nonpayable", type: "function"
  },
  {
    inputs: [
      { internalType: "address", name: "to",     type: "address" },
      { internalType: "uint256", name: "amount", type: "uint256" },
      { internalType: "string",  name: "reason", type: "string"  },
    ],
    name: "withdrawFromReserve",
    outputs: [],
    stateMutability: "nonpayable", type: "function"
  },

  // ── Events ────────────────────────────────────────────────────────────────
  { anonymous: false, inputs: [{ indexed: true, internalType: "address", name: "source", type: "address" }, { indexed: false, internalType: "uint256", name: "amount", type: "uint256" }, { indexed: false, internalType: "string", name: "revenueType", type: "string" }], name: "RevenueReceived", type: "event" },
  { anonymous: false, inputs: [{ indexed: true, internalType: "uint8",   name: "treasuryType",    type: "uint8"   }, { indexed: true, internalType: "address", name: "treasuryAddress", type: "address" }, { indexed: false, internalType: "uint256", name: "amount", type: "uint256" }], name: "RevenueDistributed", type: "event" },
  { anonymous: false, inputs: [{ indexed: false, internalType: "uint256", name: "amount",          type: "uint256" }, { indexed: false, internalType: "uint256", name: "newBalance",        type: "uint256" }], name: "ReserveFundDeposit", type: "event" },
  { anonymous: false, inputs: [{ indexed: true,  internalType: "address", name: "to",              type: "address" }, { indexed: false, internalType: "uint256", name: "amount",             type: "uint256" }, { indexed: false, internalType: "uint256", name: "remainingBalance", type: "uint256" }, { indexed: false, internalType: "string", name: "reason", type: "string" }], name: "ReserveFundWithdrawal", type: "event" },
  { anonymous: false, inputs: [{ indexed: false, internalType: "uint256", name: "firstDepositTime", type: "uint256" }, { indexed: false, internalType: "uint256", name: "nextDistributionTime", type: "uint256" }], name: "DistributionCycleInitialized", type: "event" },
  { anonymous: false, inputs: [{ indexed: false, internalType: "uint256", name: "amount",           type: "uint256" }, { indexed: false, internalType: "uint256", name: "nextDistributionTime",  type: "uint256" }], name: "DistributionTriggered", type: "event" },
  { anonymous: false, inputs: [{ indexed: false, internalType: "uint256", name: "timestamp",        type: "uint256" }, { indexed: false, internalType: "string",  name: "reason",               type: "string"  }], name: "EmergencyModeActivated", type: "event" },
  { anonymous: false, inputs: [{ indexed: false, internalType: "uint256", name: "timestamp",        type: "uint256" }], name: "EmergencyModeDeactivated", type: "event" },

  // ── receive ───────────────────────────────────────────────────────────────
  { stateMutability: "payable", type: "receive" },
] as const;

// ─── Treasury type enum (matches contract) ────────────────────────────────
export enum TreasuryType {
  REWARDS       = 0,
  STAKING       = 1,
  COLLABORATORS = 2,
  DEVELOPMENT   = 3,
  MARKETPLACE   = 4,
}

export const TREASURY_TYPE_LABELS: Record<TreasuryType, string> = {
  [TreasuryType.REWARDS]:       "Rewards",
  [TreasuryType.STAKING]:       "Staking",
  [TreasuryType.COLLABORATORS]: "Collaborators",
  [TreasuryType.DEVELOPMENT]:   "Development",
  [TreasuryType.MARKETPLACE]:   "Marketplace",
};

// ─── Protocol status enum ────────────────────────────────────────────────
export enum ProtocolStatus {
  HEALTHY   = 0,
  UNSTABLE  = 1,
  CRITICAL  = 2,
  EMERGENCY = 3,
}

export const PROTOCOL_STATUS_LABELS: Record<ProtocolStatus, string> = {
  [ProtocolStatus.HEALTHY]:   "Healthy",
  [ProtocolStatus.UNSTABLE]:  "Unstable",
  [ProtocolStatus.CRITICAL]:  "Critical",
  [ProtocolStatus.EMERGENCY]: "Emergency",
};

export const TREASURY_MANAGER_ADDRESS = "0x312a3c5072c9DE2aB5cbDd799b3a65fb053DF043";
