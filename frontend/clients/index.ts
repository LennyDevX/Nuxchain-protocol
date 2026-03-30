import { Contract, type ContractRunner } from "ethers";

import {
  SmartStakingCore,
  SmartStakingViewCore,
  SmartStakingViewStats,
  SmartStakingViewSkills,
  MarketplaceCore,
  MarketplaceView,
  MarketplaceStatistics,
  TreasuryManager
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
  treasuryManager: Contract;
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
  return {
    marketplaceCore: new Contract(addresses.MarketplaceProxy, MarketplaceCore, runner),
    marketplaceView: new Contract(addresses.MarketplaceView, MarketplaceView, runner),
    marketplaceStatistics: new Contract(addresses.MarketplaceStatistics, MarketplaceStatistics, runner)
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