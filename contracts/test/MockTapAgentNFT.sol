// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockTapAgentNFT is ERC721 {
    uint256 private _nextTokenId;

    constructor() ERC721("Mock Tap Agent", "MTA") {}

    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextTokenId;
        _nextTokenId += 1;
        _mint(to, tokenId);
    }
}