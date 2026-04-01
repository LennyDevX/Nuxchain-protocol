// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./NuxPowerMarketplace.sol";

/**
 * @title NuxPowerMarketplaceImpl
 * @dev Concrete implementation of NuxPowerMarketplace abstract contract
 * This contract extends the abstract base contract and is deployable
 */
contract NuxPowerMarketplaceImpl is NuxPowerMarketplace {
    /**
     * @dev Constructor
     * @param _treasuryAddress Treasury address for receiving payments
     */
    constructor(address _treasuryAddress) NuxPowerMarketplace(_treasuryAddress) {}
}
