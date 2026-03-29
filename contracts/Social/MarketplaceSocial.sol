// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IMarketplaceSocial.sol";
import "../interfaces/IMarketplaceCore.sol";

interface ISocialQuestCore {
    enum QuestType { PURCHASE, CREATE, SOCIAL, LEVEL_UP, TRADING, STAKE, COMPOUND, AGENT_TASK }
    function notifyAction(address user, QuestType questType, uint256 value) external;
}

contract MarketplaceSocial is AccessControl, IMarketplaceSocial {
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    IMarketplaceCore public marketplaceCore;
    ISocialQuestCore public questCore;
    
    mapping(uint256 => mapping(address => bool)) private _nftLikes;
    mapping(uint256 => uint256) private _nftLikeCount;
    mapping(uint256 => Comment[]) private _nftComments;
    
    uint256 private constant MAX_COMMENTS_PER_NFT = 1000;
    
    error InvalidCommentLength();
    error TooManyComments();
    error NotExists();
    
    constructor(address admin, address marketplaceCoreAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MARKETPLACE_ROLE, marketplaceCoreAddress);
        marketplaceCore = IMarketplaceCore(marketplaceCoreAddress);
    }
    
    function toggleLike(uint256 tokenId, address user) external onlyRole(MARKETPLACE_ROLE) {
        bool currentLikeStatus = _nftLikes[tokenId][user];
        _nftLikes[tokenId][user] = !currentLikeStatus;

        if (!currentLikeStatus) {
            _nftLikeCount[tokenId]++;
            if (address(questCore) != address(0)) {
                try questCore.notifyAction(user, ISocialQuestCore.QuestType.SOCIAL, 1) {} catch {}
            }
        } else {
            if (_nftLikeCount[tokenId] > 0) {
                _nftLikeCount[tokenId]--;
            }
        }

        emit LikeToggled(user, tokenId, !currentLikeStatus);
    }
    
    function addComment(uint256 tokenId, address user, string calldata comment) external onlyRole(MARKETPLACE_ROLE) {
        bytes memory commentBytes = bytes(comment);
        if (commentBytes.length == 0 || commentBytes.length > 500) revert InvalidCommentLength();
        if (_nftComments[tokenId].length >= MAX_COMMENTS_PER_NFT) revert TooManyComments();

        _nftComments[tokenId].push(Comment({
            author: user,
            text: comment,
            timestamp: block.timestamp
        }));

        if (address(questCore) != address(0)) {
            try questCore.notifyAction(user, ISocialQuestCore.QuestType.SOCIAL, 1) {} catch {}
        }

        emit CommentAdded(user, tokenId, comment);
    }
    
    function hasUserLiked(uint256 tokenId, address user) external view returns (bool) {
        return _nftLikes[tokenId][user];
    }
    
    function getLikeCount(uint256 tokenId) external view returns (uint256) {
        return _nftLikeCount[tokenId];
    }
    
    function getComments(uint256 tokenId) external view returns (Comment[] memory) {
        return _nftComments[tokenId];
    }
    
    function getCommentsPaginated(uint256 tokenId, uint256 offset, uint256 limit) external view returns (Comment[] memory) {
        Comment[] storage all = _nftComments[tokenId];
        if (offset >= all.length) return new Comment[](0);
        uint256 end = offset + limit > all.length ? all.length : offset + limit;
        uint256 pageSize = end - offset;
        Comment[] memory result = new Comment[](pageSize);
        for (uint256 i = 0; i < pageSize; i++) {
            result[i] = all[offset + i];
        }
        return result;
    }
    
    function getCommentCount(uint256 tokenId) external view returns (uint256) {
        return _nftComments[tokenId].length;
    }
    
    function setMarketplaceCore(address newCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MARKETPLACE_ROLE, newCore);
        marketplaceCore = IMarketplaceCore(newCore);
    }

    function setQuestCore(address questCore_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        questCore = ISocialQuestCore(questCore_);
    }
}
