// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev Minimal mock implementing INFTRentalHook for NuxAgentRental tests
contract MockNFTRentalHook {
    mapping(uint256 => address) private _owners;
    mapping(uint256 => address) public  renters;
    mapping(uint256 => uint256) public  rentalExpiry;

    function setOwner(uint256 tokenId, address owner_) external {
        _owners[tokenId] = owner_;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }

    function setRenter(uint256 tokenId, address renter_, uint256 expiry_) external {
        renters[tokenId]      = renter_;
        rentalExpiry[tokenId] = expiry_;
    }

    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool) {
        return _owners[tokenId] == spender;
    }
}
