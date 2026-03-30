import { Contract } from "ethers";

import {
  SmartStakingCore,
  SmartStakingViewCore,
  SmartStakingViewStats,
  SmartStakingViewSkills,
  MarketplaceCore,
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
    stakingCore: new Contract(addresses.StakingCore, SmartStakingCore, runner),
    stakingViewCore: new Contract(addresses.StakingViewCore, SmartStakingViewCore, runner),
    stakingViewStats: new Contract(addresses.StakingViewStats, SmartStakingViewStats, runner),
    stakingViewSkills: new Contract(addresses.StakingViewSkills, SmartStakingViewSkills, runner)
  };
}

export function createMarketplaceClients(runner, addresses = CONTRACT_ADDRESSES) {
  return {
    marketplaceCore: new Contract(addresses.MarketplaceProxy, MarketplaceCore, runner),
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