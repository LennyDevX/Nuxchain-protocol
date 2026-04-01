// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title MockCore
 * @dev Mock contract for GameifiedMarketplaceCore in tests
 */
contract MockCore {
    mapping(address => uint256) public userXP;
    
    /// @dev Update user XP (records it for verification)
    function updateUserXP(address user, uint256 amount) external {
        userXP[user] += amount;
    }
    
    /// @dev Get user XP
    function getUserXP(address user) external view returns (uint256) {
        return userXP[user];
    }
    
    /// @dev Create standard NFT (mock - returns dummy ID)
    function createStandardNFT(
        string calldata _tokenURI,
        string calldata _category,
        uint96 /* _royaltyPercentage */
    ) external view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_tokenURI, _category, block.timestamp))) % 10000;
    }
}
