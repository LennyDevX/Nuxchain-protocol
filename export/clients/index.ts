import { Contract, type ContractRunner } from "ethers";

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
} from "../abis";
import {
  CONTRACT_ADDRESSES,
  type GeneratedContractAddresses
} from "../config";

export interface NuxchainCoreClients {
  stakingCore: Contract;
  stakingViewCore: Contract;
  stakingViewStats: Contract;
  stakingViewSkills: Contract;
  marketplaceCore: Contract;
  marketplaceView: Contract;
  marketplaceStatistics: Contract;
  nuxAgentView?: Contract;
  treasuryManager: Contract;
}

export interface NuxTapClients {
  nuxTapGame: Contract;
  nuxTapAgentMarketplace: Contract;
  nuxTapStore: Contract;
  nuxTapTreasury: Contract;
}

function requireAddress(value: string | undefined, label: string): string {
  if (!value) {
    throw new Error(`Missing ${label} address in contract config`);
  }

  return value;
}

export function createTreasuryClient(
  runner: ContractRunner,
  addresses: GeneratedContractAddresses = CONTRACT_ADDRESSES
): Contract {
  return new Contract(addresses.TreasuryManager, TreasuryManager, runner);
}

export function createStakingClients(
  runner: ContractRunner,
  addresses: GeneratedContractAddresses = CONTRACT_ADDRESSES
) {
  return {
    stakingCore: new Contract(addresses.StakingCore, SmartStakingCore, runner),
    stakingViewCore: new Contract(addresses.StakingViewCore, SmartStakingViewCore, runner),
    stakingViewStats: new Contract(addresses.StakingViewStats, SmartStakingViewStats, runner),
    stakingViewSkills: new Contract(addresses.StakingViewSkills, SmartStakingViewSkills, runner)
  };
}

export function createMarketplaceClients(
  runner: ContractRunner,
  addresses: GeneratedContractAddresses = CONTRACT_ADDRESSES
) {
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

export function createNuxAgentViewClient(
  runner: ContractRunner,
  addresses: GeneratedContractAddresses = CONTRACT_ADDRESSES
): Contract {
  const nuxAgentViewAddress = requireAddress(addresses.NuxAgentView, "NuxAgentView");
  return new Contract(nuxAgentViewAddress, NuxAgentView, runner);
}

export function createNuxTapClients(
  runner: ContractRunner,
  addresses: GeneratedContractAddresses = CONTRACT_ADDRESSES
): NuxTapClients {
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

export function createNuxchainClients(
  runner: ContractRunner,
  addresses: GeneratedContractAddresses = CONTRACT_ADDRESSES
): NuxchainCoreClients {
  const staking = createStakingClients(runner, addresses);
  const marketplace = createMarketplaceClients(runner, addresses);

  return {
    ...staking,
    ...marketplace,
    treasuryManager: createTreasuryClient(runner, addresses)
  };
}