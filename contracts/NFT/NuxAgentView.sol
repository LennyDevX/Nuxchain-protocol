// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/INuxAgentNFT.sol";

interface INuxAgentViewSource is INuxAgentNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function effectiveController(uint256 tokenId) external view returns (address);
    function totalSupply() external view returns (uint256);
    function currentRenter(uint256 tokenId) external view returns (address);
    function rentalExpiry(uint256 tokenId) external view returns (uint256);
}

contract NuxAgentView {
    function getAgentView(address nftContract, uint256 tokenId)
        external
        view
        returns (INuxAgentNFT.AgentView memory view_)
    {
        require(nftContract != address(0), "View: invalid contract");

        INuxAgentViewSource nft = INuxAgentViewSource(nftContract);
        address renter = nft.currentRenter(tokenId);
        uint256 expiry = nft.rentalExpiry(tokenId);
        bool isCurrentlyRented = renter != address(0) && block.timestamp < expiry;

        view_.tokenId = tokenId;
        view_.owner = nft.ownerOf(tokenId);
        view_.effectiveController = nft.effectiveController(tokenId);
        view_.tokenBoundAccount = nft.getTokenBoundAccount(tokenId);
        view_.renter = renter;
        view_.rentalExpiry = expiry;
        view_.remainingRentalTime = isCurrentlyRented ? expiry - block.timestamp : 0;
        view_.isCurrentlyRented = isCurrentlyRented;
        view_.tokenMetadataURI = nft.tokenURI(tokenId);
        view_.agentRegistrationURI = nft.getAgentURI(tokenId);
        view_.config = nft.getAgentConfig(tokenId);
    }

    function getOwnerAgentIds(address nftContract, address owner, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory tokenIds, uint256 total)
    {
        require(nftContract != address(0), "View: invalid contract");
        require(owner != address(0), "View: invalid owner");

        INuxAgentViewSource nft = INuxAgentViewSource(nftContract);
        uint256 mintedCount = nft.totalSupply();

        for (uint256 tokenId = 1; tokenId <= mintedCount; tokenId++) {
            try nft.ownerOf(tokenId) returns (address tokenOwner) {
                if (tokenOwner == owner) {
                    total++;
                }
            } catch {}
        }

        if (limit == 0 || offset >= total) {
            return (new uint256[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) end = total;

        tokenIds = new uint256[](end - offset);
        uint256 seen;
        uint256 index;

        for (uint256 tokenId = 1; tokenId <= mintedCount && index < tokenIds.length; tokenId++) {
            try nft.ownerOf(tokenId) returns (address tokenOwner) {
                if (tokenOwner != owner) {
                    continue;
                }
                if (seen >= offset) {
                    tokenIds[index] = tokenId;
                    index++;
                }
                seen++;
            } catch {}
        }
    }

    function getCollectionStats(address nftContract)
        external
        view
        returns (INuxAgentNFT.CollectionStats memory stats)
    {
        require(nftContract != address(0), "View: invalid contract");

        INuxAgentViewSource nft = INuxAgentViewSource(nftContract);
        uint256 mintedCount = nft.totalSupply();

        for (uint256 tokenId = 1; tokenId <= mintedCount; tokenId++) {
            try nft.getAgentConfig(tokenId) returns (INuxAgentNFT.AgentConfig memory config) {
                stats.totalAgents++;
                stats.categoryCounts[uint256(config.category)]++;

                if (config.state == INuxAgentNFT.AgentState.ACTIVE || config.state == INuxAgentNFT.AgentState.LEARNING) {
                    stats.activeAgents++;
                }

                address renter = nft.currentRenter(tokenId);
                uint256 expiry = nft.rentalExpiry(tokenId);
                if (renter != address(0) && block.timestamp < expiry) {
                    stats.rentedAgents++;
                }
            } catch {}
        }
    }
}