import { Contract } from "ethers";

import {
  SmartStakingCore,
  SmartStakingViewCore,
  SmartStakingViewStats,
  SmartStakingViewSkills,
  MarketplaceCore,
  MarketplaceView,
  MarketplaceStatistics,
  NuxAgentView,
  TreasuryManager,
  NuxTapGame,
  NuxTapAgentMarketplace,
  NuxTapItemStore,
  NuxTapTreasury
} from "../abis/runtime.js";
import { CONTRACT_ADDRESSES } from "../config/index.js";

function requireAddress(value, label) {
  if (!value) {
    throw new Error(`Missing ${label} address in contract config`);
  }

  return value;
}

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
  const nuxAgentView = addresses.NuxAgentView
    ? new Contract(addresses.NuxAgentView, NuxAgentView, runner)
    : undefined;

  return {
    marketplaceCore: new Contract(addresses.MarketplaceProxy, MarketplaceCore, runner),
    marketplaceView: new Contract(addresses.MarketplaceView, MarketplaceView, runner),
    marketplaceStatistics: new Contract(addresses.MarketplaceStatistics, MarketplaceStatistics, runner),
    nuxAgentView
  };
}

export function createNuxAgentViewClient(runner, addresses = CONTRACT_ADDRESSES) {
  const nuxAgentViewAddress = requireAddress(addresses.NuxAgentView, "NuxAgentView");
  return new Contract(nuxAgentViewAddress, NuxAgentView, runner);
}

export function createNuxTapClients(runner, addresses = CONTRACT_ADDRESSES) {
  const nuxTapGameAddress = requireAddress(addresses.NuxTapGame, "NuxTapGame");
  const nuxTapAgentMarketplaceAddress = requireAddress(addresses.NuxTapAgentMarketplace, "NuxTapAgentMarketplace");
  const nuxTapStoreAddress = requireAddress(addresses.NuxTapStore, "NuxTapStore");
  const nuxTapTreasuryAddress = requireAddress(addresses.NuxTapTreasury, "NuxTapTreasury");

  return {
    nuxTapGame: new Contract(nuxTapGameAddress, NuxTapGame, runner),
    nuxTapAgentMarketplace: new Contract(nuxTapAgentMarketplaceAddress, NuxTapAgentMarketplace, runner),
    nuxTapStore: new Contract(nuxTapStoreAddress, NuxTapItemStore, runner),
    nuxTapTreasury: new Contract(nuxTapTreasuryAddress, NuxTapTreasury, runner)
  };
}

export function createNuxchainClients(runner, addresses = CONTRACT_ADDRESSES) {
  return {
    ...createStakingClients(runner, addresses),
    ...createMarketplaceClients(runner, addresses),
    treasuryManager: createTreasuryClient(runner, addresses)
  };
}