// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/ITreasuryManager.sol";
import "../interfaces/IMarketplaceStatistics.sol";
import { NFTMetadata, Offer, UserProfile, SaleSettlement } from "./MarketplaceCoreTypes.sol";

error TreasuryFailed();
error SellerFailed();
error RefundFailed();

library MarketplaceCoreLib {
    using EnumerableSet for EnumerableSet.UintSet;

    uint8 private constant MAX_LEVEL = 250;
    uint8 private constant LEVELS_PER_BRACKET = 25;
    uint8 private constant BRACKET_COUNT = 10;
    uint256 private constant XP_PER_BRACKET_STEP = 50;
    uint256 private constant MAX_XP = 68_750;

    function buildSaleSettlement(
        address seller,
        address buyer,
        uint256 grossAmount,
        NFTMetadata memory meta,
        uint256 platformFeePercentage
    ) public pure returns (SaleSettlement memory settlement) {
        settlement.seller = seller;
        settlement.buyer = buyer;
        settlement.grossAmount = grossAmount;
        settlement.platformFee = (grossAmount * platformFeePercentage) / 100;

        if (meta.creator != seller && meta.royaltyPercentage > 0) {
            settlement.royaltyAmount = (grossAmount * meta.royaltyPercentage) / 10000;
            if (settlement.platformFee + settlement.royaltyAmount > grossAmount) {
                settlement.royaltyAmount = grossAmount - settlement.platformFee;
            }
        }

        settlement.sellerAmount = grossAmount - settlement.platformFee - settlement.royaltyAmount;
    }

    function finalizeSale(
        mapping(address => UserProfile) storage userProfiles,
        mapping(address => uint256) storage pendingRefunds,
        mapping(uint256 => bool) storage isListed,
        mapping(uint256 => uint256) storage listedPrice,
        mapping(uint256 => Offer[]) storage nftOffers,
        EnumerableSet.UintSet storage listedTokenIds,
        address statisticsModuleAddress,
        address treasuryManagerAddress,
        address platformTreasury,
        uint256 tokenId,
        uint256 skipOfferIndex,
        SaleSettlement memory settlement,
        NFTMetadata memory meta
    ) public {
        _recordSale(userProfiles, statisticsModuleAddress, tokenId, settlement, meta);
        _clearListingAndRefundOffers(pendingRefunds, isListed, listedPrice, nftOffers, listedTokenIds, tokenId, skipOfferIndex);
        _payoutSale(treasuryManagerAddress, platformTreasury, settlement, meta);
    }

    function _recordSale(
        mapping(address => UserProfile) storage userProfiles,
        address statisticsModuleAddress,
        uint256 tokenId,
        SaleSettlement memory settlement,
        NFTMetadata memory meta
    ) private {
        userProfiles[settlement.seller].nftsSold++;
        userProfiles[settlement.buyer].nftsBought++;
        _addXP(userProfiles, settlement.seller, 20);
        _addXP(userProfiles, settlement.buyer, 15);

        if (statisticsModuleAddress != address(0)) {
            IMarketplaceStatistics statisticsModule = IMarketplaceStatistics(statisticsModuleAddress);
            statisticsModule.recordSale(
                settlement.seller,
                settlement.buyer,
                tokenId,
                settlement.grossAmount,
                meta.category
            );
            if (settlement.royaltyAmount > 0) {
                statisticsModule.recordRoyaltyPayment(meta.creator, tokenId, settlement.royaltyAmount);
            }
        }
    }

    function _clearListingAndRefundOffers(
        mapping(address => uint256) storage pendingRefunds,
        mapping(uint256 => bool) storage isListed,
        mapping(uint256 => uint256) storage listedPrice,
        mapping(uint256 => Offer[]) storage nftOffers,
        EnumerableSet.UintSet storage listedTokenIds,
        uint256 tokenId,
        uint256 skipOfferIndex
    ) private {
        isListed[tokenId] = false;
        listedPrice[tokenId] = 0;
        listedTokenIds.remove(tokenId);

        Offer[] storage offers = nftOffers[tokenId];
        uint256 offerCount = offers.length;
        for (uint256 i = 0; i < offerCount; i++) {
            if (i == skipOfferIndex) continue;

            Offer memory offer = offers[i];
            if (offer.amount > 0) {
                (bool refunded,) = payable(offer.offeror).call{value: offer.amount}("");
                if (!refunded) {
                    pendingRefunds[offer.offeror] += offer.amount;
                }
            }
        }

        delete nftOffers[tokenId];
    }

    function _payoutSale(
        address treasuryManagerAddress,
        address platformTreasury,
        SaleSettlement memory settlement,
        NFTMetadata memory meta
    ) private {
        _distributeFee(treasuryManagerAddress, platformTreasury, settlement.platformFee);

        if (settlement.royaltyAmount > 0) {
            (bool royaltyPaid,) = payable(meta.creator).call{value: settlement.royaltyAmount}("");
            if (!royaltyPaid) revert RefundFailed();
        }

        (bool sellerPaid,) = payable(settlement.seller).call{value: settlement.sellerAmount}("");
        if (!sellerPaid) revert SellerFailed();
    }

    function _distributeFee(
        address treasuryManagerAddress,
        address platformTreasury,
        uint256 platformFee
    ) private {
        if (treasuryManagerAddress != address(0)) {
            try ITreasuryManager(treasuryManagerAddress).receiveRevenue{value: platformFee}("marketplace_fee") {
            } catch {
                (bool treasuryPaid,) = payable(platformTreasury).call{value: platformFee}("");
                if (!treasuryPaid) revert TreasuryFailed();
            }
        } else {
            (bool treasuryPaid,) = payable(platformTreasury).call{value: platformFee}("");
            if (!treasuryPaid) revert TreasuryFailed();
        }
    }

    function _addXP(
        mapping(address => UserProfile) storage userProfiles,
        address user,
        uint256 amount
    ) private {
        UserProfile storage profile = userProfiles[user];
        uint256 newTotal = profile.totalXP + amount;
        if (newTotal > MAX_XP) newTotal = MAX_XP;
        profile.totalXP = newTotal;
        uint8 newLevel = _levelFromXP(newTotal);
        if (newLevel > profile.level) {
            profile.level = newLevel;
        }
    }

    function _levelFromXP(uint256 xp) private pure returns (uint8) {
        if (xp < XP_PER_BRACKET_STEP) return 0;

        uint256 remainingXP = xp > MAX_XP ? MAX_XP : xp;
        for (uint256 bracket = 1; bracket <= BRACKET_COUNT; bracket++) {
            uint256 xpPerLevel = bracket * XP_PER_BRACKET_STEP;
            uint256 bracketXP = xpPerLevel * LEVELS_PER_BRACKET;
            if (remainingXP <= bracketXP) {
                return uint8(((bracket - 1) * LEVELS_PER_BRACKET) + (remainingXP / xpPerLevel));
            }
            remainingXP -= bracketXP;
        }

        return MAX_LEVEL;
    }
}