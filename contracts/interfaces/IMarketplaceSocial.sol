// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IMarketplaceSocial {
    struct Comment {
        address author;
        string text;
        uint256 timestamp;
    }

    event LikeToggled(address indexed user, uint256 indexed tokenId, bool liked);
    event CommentAdded(address indexed user, uint256 indexed tokenId, string comment);
    
    function toggleLike(uint256 tokenId, address user) external;
    function addComment(uint256 tokenId, address user, string calldata comment) external;
    
    function hasUserLiked(uint256 tokenId, address user) external view returns (bool);
    function getLikeCount(uint256 tokenId) external view returns (uint256);
    function getComments(uint256 tokenId) external view returns (Comment[] memory);
    function getCommentsPaginated(uint256 tokenId, uint256 offset, uint256 limit) external view returns (Comment[] memory);
    function getCommentCount(uint256 tokenId) external view returns (uint256);
}
