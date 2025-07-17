// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Airdrops.sol";

/**
 * @title AirdropFactory
 * @dev Factory contract to deploy and manage multiple airdrop campaigns
 */
contract AirdropFactory {
    address public owner;
    
    struct AirdropInfo {
        address airdropContract;
        address token;
        string name;
        uint256 deploymentTime;
        bool isActive;
    }
    
    AirdropInfo[] public airdrops;
    mapping(address => uint256[]) public ownerAirdrops;
    
    event AirdropDeployed(
        address indexed airdropContract, 
        address indexed owner, 
        address indexed token,
        string name,
        uint256 index
    );
    
    error Unauthorized();
    error InvalidInput();
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Deploy a new airdrop contract
     */
    function deployAirdrop(
        address _token,
        uint256 _registrationDuration,
        uint256 _claimDelay,
        uint256 _claimDuration,
        string memory _name
    ) external returns (address) {
        if (_token == address(0)) revert InvalidInput();
        if (bytes(_name).length == 0) revert InvalidInput();
        
        Airdrop newAirdrop = new Airdrop(
            _token,
            _registrationDuration,
            _claimDelay,
            _claimDuration
        );
        
        // Transfer ownership to the caller
        newAirdrop.transferOwnership(msg.sender);
        
        address airdropAddress = address(newAirdrop);
        
        // Store airdrop info
        AirdropInfo memory info = AirdropInfo({
            airdropContract: airdropAddress,
            token: _token,
            name: _name,
            deploymentTime: block.timestamp,
            isActive: true
        });
        
        airdrops.push(info);
        uint256 airdropIndex = airdrops.length - 1;
        ownerAirdrops[msg.sender].push(airdropIndex);
        
        emit AirdropDeployed(airdropAddress, msg.sender, _token, _name, airdropIndex);
        
        return airdropAddress;
    }
    
    /**
     * @dev Get all airdrops by owner
     */
    function getAirdropsByOwner(address _owner) external view returns (uint256[] memory) {
        return ownerAirdrops[_owner];
    }
    
    /**
     * @dev Get airdrop info by index
     */
    function getAirdropInfo(uint256 index) external view returns (AirdropInfo memory) {
        require(index < airdrops.length, "Invalid index");
        return airdrops[index];
    }
    
    /**
     * @dev Get total number of airdrops
     */
    function getTotalAirdrops() external view returns (uint256) {
        return airdrops.length;
    }
    
    /**
     * @dev Get multiple airdrop infos at once
     */
    function getAirdropInfoBatch(uint256[] calldata indices) external view returns (AirdropInfo[] memory) {
        AirdropInfo[] memory result = new AirdropInfo[](indices.length);
        for (uint256 i = 0; i < indices.length; i++) {
            require(indices[i] < airdrops.length, "Invalid index");
            result[i] = airdrops[indices[i]];
        }
        return result;
    }
    
    /**
     * @dev Deactivate an airdrop (only owner)
     */
    function deactivateAirdrop(uint256 index) external onlyOwner {
        require(index < airdrops.length, "Invalid index");
        airdrops[index].isActive = false;
    }
}
