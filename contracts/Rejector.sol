// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract Rejector {
    receive() external payable {
        revert();
    }
}
