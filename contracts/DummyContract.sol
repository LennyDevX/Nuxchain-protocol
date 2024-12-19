// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract DummyContract {
    function dummyFunction() public pure returns (bool) {
        return true;
    }

    // Function to attempt claiming tokens (will fail)
    function claimTokens(address airdropAddress) public {
        (bool success, ) = airdropAddress.call(abi.encodeWithSignature("claimTokens()"));
        require(success, "Call failed");
    }
}