// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../Quest/QuestCore.sol";

contract QuestCoreV2Mock is QuestCore {
    function version() external pure returns (uint256) {
        return 2;
    }
}