// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev Minimal mock for ITreasuryManager used in NFT unit tests
contract MockTreasury {
    event RevenueReceived(string revenueType, uint256 amount);

    receive() external payable {}

    function receiveRevenue(string calldata revenueType) external payable {
        emit RevenueReceived(revenueType, msg.value);
    }

    function depositRevenue(string calldata revenueType) external payable {
        emit RevenueReceived(revenueType, msg.value);
    }
}
