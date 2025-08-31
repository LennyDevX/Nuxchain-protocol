// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Interfaz para el contrato de lógica de staking
interface StakingLogicInterface {
    function migrateData(address user, uint balance) external;
}

contract UpdateContract {
    address public owner;
    address public newStakingLogicContract;
    mapping(address => uint) internal stakingBalances;
    address[] public users;
    bytes public contractData; // almacenamos datos de la llamada del contrato

    constructor(address _newStakingLogicContract) {
        owner = msg.sender;
        newStakingLogicContract = _newStakingLogicContract;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    function migrateFundsAndData(address _newStakingLogicContract) external onlyOwner {
        require(_newStakingLogicContract != address(0), "New staking logic contract address is required");
        require(newStakingLogicContract != _newStakingLogicContract, "New logic contract addresses should be different");

        for (uint i = 0; i < users.length; i++) {
            address user = users[i];
            uint stakingBalance = stakingBalances[user];

            // Transferir fondos al nuevo contrato de lógica de staking
            (bool stakingSent, ) = _newStakingLogicContract.call{value: stakingBalance}("");
            require(stakingSent, "Failed to send Ether to staking logic contract");

            // Actualizar los datos en el nuevo contrato de lógica
            StakingLogicInterface(_newStakingLogicContract).migrateData(user, stakingBalance);

            // Anular los saldos en el contrato proxy
            stakingBalances[user] = 0;
        }

        // Actualizar la dirección del contrato de lógica en el contrato proxy
        newStakingLogicContract = _newStakingLogicContract;
    }

    function setNewStakingLogicContract(address _newStakingLogicContract) external onlyOwner {
        newStakingLogicContract = _newStakingLogicContract;
    }

    function migrateToNewStakingLogic() external payable onlyOwner {
        require(newStakingLogicContract != address(0), "New staking logic contract address not set");
        for (uint i = 0; i < users.length; i++) {
            address user = users[i];
            uint balance = stakingBalances[user];
            if (balance > 0) {
                (bool sent, ) = newStakingLogicContract.call{value: balance}("");
                require(sent, "Failed to send Ether to new staking logic contract");
                StakingLogicInterface(newStakingLogicContract).migrateData(user, balance);
                stakingBalances[user] = 0;
                contractData = msg.data;
            }
        }
        owner = newStakingLogicContract;
        newStakingLogicContract = address(0);
    }

    function getRecentContractData() external view returns (bytes memory) {
        return contractData;
    }
}
