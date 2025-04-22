// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Contrato MockNUVOToken sin restricciones de owner para facilitar tests
contract MockNUVOToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    // Mint sin restricción para facilitar pruebas
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // Quemar tokens desde el address que llame a la función
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}