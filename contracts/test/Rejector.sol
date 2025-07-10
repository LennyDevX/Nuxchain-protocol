// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title Rejector Contract
/// @notice A simple contract that rejects all incoming Ether transfers.
/// @dev Used for testing fallback mechanisms in other contracts.
contract Rejector {
    // Reject any Ether sent to this contract.
    receive() external payable {
        revert("Transfer rejected");
    }
}
