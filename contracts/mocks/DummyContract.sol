// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IAirdrop {
    function claim() external;
}

contract DummyContract {
    function attemptClaim(address airdropContract) external {
        IAirdrop(airdropContract).claim();
    }

    receive() external payable {}
}
