// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title GameifiedMarketplaceProxy
 * @dev UUPS Transparent Proxy para GameifiedMarketplaceV1
 * 
 * IMPORTANTES:
 * - Este proxy NO debe ser modificado después del deploy
 * - Todos los upgrades se hacen a través de `upgradeTo()` en el implementation
 * - El implementation debe heredar de UUPSUpgradeable
 * 
 * DEPLOY INSTRUCTIONS:
 * 1. Deploy GameifiedMarketplaceV1 (implementation)
 * 2. Deploy GameifiedMarketplaceProxy con address del implementation
 * 3. Llamar a initialize() en el proxy ABI pero con GameifiedMarketplaceV1 interface
 * 4. Para upgradear: Llamar a upgradeTo(newImplementationAddress) desde owner
 */
contract GameifiedMarketplaceProxy is ERC1967Proxy {
    /**
     * @dev Inicializa el proxy con el implementation contract
     * @param implementation Address del contrato GameifiedMarketplaceV1
     * @param initializationData Encoded data para llamar initialize()
     * 
     * NOTA: initializationData debe ser el resultado de:
     * abi.encodeWithSignature(
     *   "initialize(address,address,address,address,address,address)",
     *   polTokenAddress,
     *   stakingContractAddress,
     *   communityTreasuryAddress,
     *   royaltyStakingPoolAddress,
     *   stakingTreasuryAddress,
     *   platformTreasuryAddress
     * )
     */
    constructor(address implementation, bytes memory initializationData)
        ERC1967Proxy(implementation, initializationData)
    {}
}
