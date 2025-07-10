// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Asegúrate de haber instalado OpenZeppelin Contracts: npm install @openzeppelin/contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestToken
 * @dev A simple ERC20 token for testing purposes.
 */
contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}
