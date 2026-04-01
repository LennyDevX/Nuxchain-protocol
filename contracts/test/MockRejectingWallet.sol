// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IMarketplaceRefundClaims {
    function makeOffer(uint256 tokenId, uint8 expiresInDays) external payable;
    function claimPendingRefund() external;
}

interface ILevelingDeferredRewards {
    function claimDeferredReward() external;
}

contract MockRejectingWallet {
    address public immutable owner;
    bool public rejectPayments = true;

    modifier onlyOwner() {
        require(msg.sender == owner, "MockRejectingWallet: not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {
        require(!rejectPayments, "MockRejectingWallet: rejecting payment");
    }

    function setRejectPayments(bool reject) external onlyOwner {
        rejectPayments = reject;
    }

    function makeMarketplaceOffer(address marketplace, uint256 tokenId, uint8 expiresInDays) external payable onlyOwner {
        IMarketplaceRefundClaims(marketplace).makeOffer{value: msg.value}(tokenId, expiresInDays);
    }

    function claimMarketplaceRefund(address marketplace) external onlyOwner {
        IMarketplaceRefundClaims(marketplace).claimPendingRefund();
    }

    function claimLevelingReward(address leveling) external onlyOwner {
        ILevelingDeferredRewards(leveling).claimDeferredReward();
    }

    function withdraw(address payable recipient) external onlyOwner {
        (bool success, ) = recipient.call{value: address(this).balance}("");
        require(success, "MockRejectingWallet: withdraw failed");
    }
}