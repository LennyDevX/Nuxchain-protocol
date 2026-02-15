// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IMarketplaceSocial.sol";
import "../interfaces/IGameifiedMarketplaceCore.sol";

contract MarketplaceSocial is AccessControl, IMarketplaceSocial {
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");
    
    IGameifiedMarketplaceCore public marketplaceCore;
    
    mapping(uint256 => mapping(address => bool)) private _nftLikes;
    mapping(uint256 => uint256) private _nftLikeCount;
    mapping(uint256 => string[]) private _nftComments;
    
    uint256 private constant MAX_COMMENTS_PER_NFT = 1000;
    
    error InvalidCommentLength();
    error TooManyComments();
    error NotExists();
    
    constructor(address admin, address marketplaceCoreAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MARKETPLACE_ROLE, marketplaceCoreAddress);
        marketplaceCore = IGameifiedMarketplaceCore(marketplaceCoreAddress);
    }
    
    function toggleLike(uint256 tokenId, address user) external onlyRole(MARKETPLACE_ROLE) {
        bool currentLikeStatus = _nftLikes[tokenId][user];
        _nftLikes[tokenId][user] = !currentLikeStatus;
        
        if (!currentLikeStatus) {
            _nftLikeCount[tokenId]++;
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
        
        _nftComments[tokenId].push(comment);
        emit CommentAdded(user, tokenId, comment);
    }
    
    function hasUserLiked(uint256 tokenId, address user) external view returns (bool) {
        return _nftLikes[tokenId][user];
    }
    
    function getLikeCount(uint256 tokenId) external view returns (uint256) {
        return _nftLikeCount[tokenId];
    }
    
    function getComments(uint256 tokenId) external view returns (string[] memory) {
        return _nftComments[tokenId];
    }
    
    function setMarketplaceCore(address newCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MARKETPLACE_ROLE, newCore);
        marketplaceCore = IGameifiedMarketplaceCore(newCore);
    }
}
