import { Contract, type ContractRunner } from "ethers";

import {
  EnhancedSmartStakingCoreV2,
  EnhancedSmartStakingViewCore,
  EnhancedSmartStakingViewStats,
  EnhancedSmartStakingViewSkills,
  GameifiedMarketplaceCoreV1,
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
    stakingCore: new Contract(addresses.StakingCore, EnhancedSmartStakingCoreV2, runner),
    stakingViewCore: new Contract(addresses.StakingViewCore, EnhancedSmartStakingViewCore, runner),
    stakingViewStats: new Contract(addresses.StakingViewStats, EnhancedSmartStakingViewStats, runner),
    stakingViewSkills: new Contract(addresses.StakingViewSkills, EnhancedSmartStakingViewSkills, runner)
  };
}

export function createMarketplaceClients(
  runner: ContractRunner,
  addresses: GeneratedContractAddresses = CONTRACT_ADDRESSES
) {
  return {
    marketplaceCore: new Contract(addresses.MarketplaceProxy, GameifiedMarketplaceCoreV1, runner),
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