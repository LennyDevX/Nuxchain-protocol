// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev Minimal mock NFT implementing ownerOf() for NuxAgentMiniGame tests
contract MockGameNFT {
    mapping(uint256 => address) private _owners;

    function setOwner(uint256 tokenId, address owner_) external {
        _owners[tokenId] = owner_;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        require(_owners[tokenId] != address(0), "MockGameNFT: nonexistent token");
        return _owners[tokenId];
    }
}
