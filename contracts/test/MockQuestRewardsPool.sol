// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockQuestRewardsPool {
    mapping(address => uint256) public paidTo;
    uint256 public totalPaid;
    bool public shouldRevert;

    receive() external payable {}

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function requestPayout(address recipient, uint256 amount, string calldata) external {
        require(!shouldRevert, "MockQuestRewardsPool: forced revert");
        require(address(this).balance >= amount, "MockQuestRewardsPool: insufficient balance");

        paidTo[recipient] += amount;
        totalPaid += amount;

        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "MockQuestRewardsPool: transfer failed");
    }
}