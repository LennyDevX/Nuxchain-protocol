import { Contract } from "ethers";

import {
  EnhancedSmartStakingCoreV2,
  EnhancedSmartStakingViewCore,
  EnhancedSmartStakingViewStats,
  EnhancedSmartStakingViewSkills,
  GameifiedMarketplaceCoreV1,
  MarketplaceView,
  MarketplaceStatistics,
  TreasuryManager
} from "../abis/runtime.js";
import { CONTRACT_ADDRESSES } from "../config/index.js";

export function createTreasuryClient(runner, addresses = CONTRACT_ADDRESSES) {
  return new Contract(addresses.TreasuryManager, TreasuryManager, runner);
}

export function createStakingClients(runner, addresses = CONTRACT_ADDRESSES) {
  return {
    stakingCore: new Contract(addresses.StakingCore, EnhancedSmartStakingCoreV2, runner),
    stakingViewCore: new Contract(addresses.StakingViewCore, EnhancedSmartStakingViewCore, runner),
    stakingViewStats: new Contract(addresses.StakingViewStats, EnhancedSmartStakingViewStats, runner),
    stakingViewSkills: new Contract(addresses.StakingViewSkills, EnhancedSmartStakingViewSkills, runner)
  };
}

export function createMarketplaceClients(runner, addresses = CONTRACT_ADDRESSES) {
  return {
    marketplaceCore: new Contract(addresses.MarketplaceProxy, GameifiedMarketplaceCoreV1, runner),
    marketplaceView: new Contract(addresses.MarketplaceView, MarketplaceView, runner),
    marketplaceStatistics: new Contract(addresses.MarketplaceStatistics, MarketplaceStatistics, runner)
  };
}

export function createNuxchainClients(runner, addresses = CONTRACT_ADDRESSES) {
  return {
    ...createStakingClients(runner, addresses),
    ...createMarketplaceClients(runner, addresses),
    treasuryManager: createTreasuryClient(runner, addresses)
  };
}