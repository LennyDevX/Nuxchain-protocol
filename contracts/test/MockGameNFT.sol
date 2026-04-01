// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev Minimal mock NFT implementing ownerOf() for NuxAgentMiniGame tests
contract MockGameNFT {
    mapping(uint256 => address) private _owners;
    mapping(uint256 => address) private _controllers;

    function setOwner(uint256 tokenId, address owner_) external {
        _owners[tokenId] = owner_;
    }

    function setController(uint256 tokenId, address controller_) external {
        _controllers[tokenId] = controller_;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        require(_owners[tokenId] != address(0), "MockGameNFT: nonexistent token");
        return _owners[tokenId];
    }

    function effectiveController(uint256 tokenId) external view returns (address) {
        address controller = _controllers[tokenId];
        if (controller != address(0)) {
            return controller;
        }
        require(_owners[tokenId] != address(0), "MockGameNFT: nonexistent token");
        return _owners[tokenId];
    }
}
