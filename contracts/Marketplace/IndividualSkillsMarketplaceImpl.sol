// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IndividualSkillsMarketplace.sol";

/**
 * @title IndividualSkillsMarketplaceImpl
 * @dev Concrete implementation of IndividualSkillsMarketplace abstract contract
 * This contract extends the abstract base contract and is deployable
 */
contract IndividualSkillsMarketplaceImpl is IndividualSkillsMarketplace {
    /**
     * @dev Constructor
     * @param _treasuryAddress Treasury address for receiving payments
     */
    constructor(address _treasuryAddress) IndividualSkillsMarketplace(_treasuryAddress) {}
}
