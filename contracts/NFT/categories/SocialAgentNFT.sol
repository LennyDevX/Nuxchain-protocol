// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../NuxAgentNFTBase.sol";

/**
 * @title SocialAgentNFT
 * @notice AI Agent NFTs specialized for Social Media & Community Management
 * @dev Category: SOCIAL
 *
 * CAPABILITIES (executed off-chain via Gemini SDK, recorded on-chain):
 *   - Community engagement monitoring and automated responses
 *   - Content generation for posts, threads, newsletters
 *   - Sentiment analysis of community feedback
 *   - Influencer collaboration management
 *   - Cross-platform social metrics tracking (Twitter/X, Lens, Farcaster)
 *   - Moderating NFT comments via MarketplaceSocial integration
 *
 * SKILLS (boosted via existing GameifiedNuxPowerNft):
 *   - INFLUENCER: 2x like multiplier in marketplace social actions
 *   - AMBASSADOR: 2x referral bonus via ReferralSystem
 *   - MODERATOR: Can flag/remove marketplace comments
 *   - VERIFIED_CREATOR: Verified badge on marketplace listings
 *
 * GEMINI INTEGRATION:
 *   Off-chain backend uses google/genai SDK (Gemini):
 *   - Model: gemini-2.0-flash (fast, good for real-time social)
 *   - Tools: web grounding (for trend awareness), code execution (analytics)
 *   - Temperature: 0.7 (creative but coherent for content)
 *   - System prompt: Social media specialist with NuxChain community context
 *
 * MINI-GAME TASKS:
 *   - TASK_VIRAL_CONTENT: Generate content that earns 100+ likes (simulated)
 *   - TASK_COMMUNITY_REPORT: Analyze and summarize community sentiment
 *   - TASK_ENGAGE_USERS: Respond to 10 community questions
 *   - TASK_GROW_FOLLOWERS: Track follower growth metrics
 */
contract SocialAgentNFT is NuxAgentNFTBase {

    // ============================================
    // SOCIAL-SPECIFIC STORAGE
    // ============================================

    struct SocialProfile {
        string[] platforms;           // ["twitter", "lens", "farcaster", "discord"]
        uint256  engagementScore;     // Accumulated engagement XP from tasks
        uint256  contentPieces;       // Total content pieces generated
        uint256  communitySize;       // Tracked community size (updated off-chain)
        bool     verifiedCreator;     // Platform-verified status
        uint256  collaborations;      // Number of influencer collaborations
    }

    mapping(uint256 => SocialProfile) public socialProfiles;

    // ============================================
    // EVENTS
    // ============================================
    event SocialTaskCompleted(uint256 indexed tokenId, string taskType, uint256 xpEarned);
    event ContentGenerated(uint256 indexed tokenId, string platform, uint256 totalPieces);
    event EngagementScoreUpdated(uint256 indexed tokenId, uint256 newScore);
    event VerifiedCreatorSet(uint256 indexed tokenId, bool status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address treasuryManager_,
        address levelingSystem_,
        address erc6551Impl_,
        uint256 mintingFee_
    ) public initializer {
        __NuxAgentNFTBase_init(
            "NuxChain Social Agent",
            "NXSOC",
            admin_,
            treasuryManager_,
            levelingSystem_,
            erc6551Impl_,
            mintingFee_,
            500 // 5% royalty on secondary sales
        );
    }

    // ============================================
    // FACTORY ENTRY POINT
    // ============================================

    /**
     * @notice Called by NuxAgentFactory to mint a Social agent
     * @dev Only FACTORY_ROLE can call this — set via NuxAgentFactory
     */
    function mintFromFactory(
        address recipient,
        AgentConfig memory config,
        string memory tokenURI_
    ) external payable onlyRole(FACTORY_ROLE) returns (uint256 tokenId) {
        require(config.category == AgentCategory.SOCIAL, "SocialNFT: wrong category");
        _collectMintingFee();
        tokenId = _mintAgent(recipient, config, tokenURI_);

        // Initialize social profile
        socialProfiles[tokenId] = SocialProfile({
            platforms:       new string[](0),
            engagementScore: 0,
            contentPieces:   0,
            communitySize:   0,
            verifiedCreator: false,
            collaborations:  0
        });
    }

    /**
     * @notice Direct mint for admin (testing / manual deployment)
     */
    function mint(
        address recipient,
        AgentConfig memory config,
        string memory tokenURI_
    ) external payable onlyRole(ADMIN_ROLE) nonReentrant returns (uint256 tokenId) {
        require(config.category == AgentCategory.SOCIAL, "SocialNFT: wrong category");
        _collectMintingFee();
        tokenId = _mintAgent(recipient, config, tokenURI_);
        socialProfiles[tokenId] = SocialProfile({
            platforms:       new string[](0),
            engagementScore: 0,
            contentPieces:   0,
            communitySize:   0,
            verifiedCreator: false,
            collaborations:  0
        });
    }

    // ============================================
    // SOCIAL TASK RECORDING (called by NuxAgentMiniGame or off-chain backend)
    // ============================================

    /**
     * @notice Record a completed social task — awards XP and updates profile
     * @dev Called by NuxAgentMiniGame (REGISTRY_ROLE) after validation
     */
    function recordSocialTask(
        uint256 tokenId,
        string calldata taskType,
        uint256 xpEarned,
        uint256 engagementDelta
    ) external onlyRole(REGISTRY_ROLE) {
        require(_exists(tokenId), "SocialNFT: token does not exist");

        SocialProfile storage prof = socialProfiles[tokenId];
        prof.engagementScore += engagementDelta;

        // Award XP to NFT owner
        address owner = ownerOf(tokenId);
        _awardXP(owner, xpEarned);

        emit SocialTaskCompleted(tokenId, taskType, xpEarned);
        emit EngagementScoreUpdated(tokenId, prof.engagementScore);
    }

    function recordContentGenerated(
        uint256 tokenId,
        string calldata platform
    ) external onlyRole(REGISTRY_ROLE) {
        require(_exists(tokenId), "SocialNFT: token does not exist");
        socialProfiles[tokenId].contentPieces++;
        emit ContentGenerated(tokenId, platform, socialProfiles[tokenId].contentPieces);
    }

    function addPlatform(uint256 tokenId, string calldata platform) external {
        require(_exists(tokenId), "SocialNFT: token does not exist");
        require(ownerOf(tokenId) == msg.sender || hasRole(ADMIN_ROLE, msg.sender), "SocialNFT: not authorized");
        socialProfiles[tokenId].platforms.push(platform);
    }

    function setVerifiedCreator(uint256 tokenId, bool status) external onlyRole(ADMIN_ROLE) {
        require(_exists(tokenId), "SocialNFT: token does not exist");
        socialProfiles[tokenId].verifiedCreator = status;
        emit VerifiedCreatorSet(tokenId, status);
    }

    function updateCommunitySize(uint256 tokenId, uint256 newSize) external onlyRole(REGISTRY_ROLE) {
        require(_exists(tokenId), "SocialNFT: token does not exist");
        socialProfiles[tokenId].communitySize = newSize;
    }

    // ============================================
    // VIEW
    // ============================================

    function getSocialProfile(uint256 tokenId) external view returns (SocialProfile memory) {
        require(_exists(tokenId), "SocialNFT: token does not exist");
        return socialProfiles[tokenId];
    }

    uint256[50] private __gap;
}
