// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IXPHub.sol";

interface IAuctionTreasury {
    function receiveRevenue(string calldata revenueType) external payable;
}

/**
 * @title NuxAuctionMarketplace
 * @notice Multi-mode auction marketplace for AI Agent NFTs
 * @dev Supports three auction types:
 *
 *   ENGLISH  — Classic ascending bid auction.
 *              Each new bid must beat the current highest by at least 1%.
 *              The NFT is escrowed. Loser bids are refunded immediately.
 *              Seller can set a reserve price; auction fails if reserve not met.
 *
 *   DUTCH    — Descending price auction.
 *              Price decreases linearly from startPrice to reservePrice over the duration.
 *              First buyer at the current price wins. NFT is escrowed.
 *
 *   SEALED   — Commit-reveal blind auction.
 *              Phase 1 (commit): Bidders submit keccak256(amount, salt) + a deposit ≥ their amount.
 *              Phase 2 (reveal): Bidders reveal amount + salt. Highest verified bid wins.
 *              Phase 3 (settle): After reveal deadline, winner gets NFT; others get refunds.
 *
 * FEES (on successful sale):
 *   - Platform fee (default 600 bps = 6%) → TreasuryManager.receiveRevenue("auction_platform_fee")
 *   - Royalty (ERC-2981, up to 1500 bps) → royalty recipient
 *   - Remainder → seller
 *
 * XP REWARDS:
 *   - Winning a bid: 100 XP to buyer
 *   - Successful sale: 50 XP to seller
 *   - Placing a bid (English): 10 XP to bidder
 */
contract NuxAuctionMarketplace is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // ============================================
    // ROLES
    // ============================================
    bytes32 public constant ADMIN_ROLE    = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE   = keccak256("PAUSER_ROLE");

    // ============================================
    // ENUMS & STRUCTS
    // ============================================

    enum AuctionType   { ENGLISH, DUTCH, SEALED }
    enum AuctionStatus { PENDING, ACTIVE, FINALIZED, CANCELLED }

    struct Auction {
        AuctionType   auctionType;
        AuctionStatus status;
        address       nftContract;
        uint256       tokenId;
        address       seller;
        // Pricing
        uint256       startPrice;
        uint256       reservePrice;    // 0 = no reserve for ENGLISH/DUTCH
        // Timing
        uint256       startTime;
        uint256       endTime;
        uint256       revealDeadline;  // Only for SEALED
        // Bids
        address       highestBidder;
        uint256       highestBid;
        // Metadata
        bool          royaltyPaid;
    }

    struct SealedBidCommit {
        bytes32 commitment;       // keccak256(abi.encode(amount, salt))
        uint256 deposit;          // ETH deposited; must cover the bid amount
        address bidder;
        bool    revealed;
        uint256 revealedAmount;
    }

    // ============================================
    // STATE
    // ============================================

    IAuctionTreasury public treasuryManager;
    IXPHub           public levelingSystem;

    uint256 public auctionCounter;
    uint256 public platformFeeBps;       // Default 600 (6%)
    uint256 public maxRoyaltyBps;        // Cap ERC-2981 royalties (default 1500 = 15%)
    uint256 public minBidIncrementBps;   // Default 100 = 1% min raise for English auctions
    uint256 public sealedRevealWindow;   // Seconds after endTime for reveal phase (default 24h)
    bool    public paused;

    mapping(uint256 => Auction) public auctions;

    // English: per-auction loser refund queue
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;

    // Sealed: per-auction, per-bidder commit
    mapping(uint256 => mapping(address => SealedBidCommit)) public sealedCommits;
    // Sealed: list of bidders for iteration
    mapping(uint256 => address[]) private _sealedBidders;
    // Sealed: track if bidder already committed (prevent double-commit per auction)
    mapping(uint256 => mapping(address => bool)) public hasSealedCommit;

    // ============================================
    // EVENTS
    // ============================================
    event AuctionCreated(uint256 indexed auctionId, AuctionType indexed auctionType, address nftContract, uint256 tokenId, address seller, uint256 startPrice);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event BidCommitted(uint256 indexed auctionId, address indexed bidder, bytes32 commitment);
    event BidRevealed(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionFinalized(uint256 indexed auctionId, address indexed winner, uint256 finalPrice);
    event AuctionCancelled(uint256 indexed auctionId);
    event RefundIssued(uint256 indexed auctionId, address indexed bidder, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address treasuryManager_,
        address levelingSystem_
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);

        treasuryManager    = IAuctionTreasury(treasuryManager_);
        levelingSystem     = IXPHub(levelingSystem_);

        platformFeeBps     = 600;
        maxRoyaltyBps      = 1500;
        minBidIncrementBps = 100;
        sealedRevealWindow = 24 hours;
    }

    // ============================================
    // CREATE AUCTION
    // ============================================

    /**
     * @notice Create an auction. The NFT is transferred to this contract as escrow.
     * @param nftContract   ERC-721 contract address
     * @param tokenId       Token to auction
     * @param auctionType_  ENGLISH, DUTCH, or SEALED
     * @param startPrice    Starting bid / Dutch starting price
     * @param reservePrice  Minimum acceptable price (0 = no reserve)
     * @param duration      Auction duration in seconds
     */
    function createAuction(
        address     nftContract,
        uint256     tokenId,
        AuctionType auctionType_,
        uint256     startPrice,
        uint256     reservePrice,
        uint256     duration
    ) external returns (uint256 auctionId) {
        require(!paused, "Auction: paused");
        require(duration >= 1 hours && duration <= 30 days, "Auction: invalid duration");
        require(startPrice > 0, "Auction: start price must be > 0");
        require(
            auctionType_ == AuctionType.DUTCH
                ? reservePrice < startPrice
                : reservePrice <= startPrice || reservePrice == 0,
            "Auction: invalid reserve vs start"
        );

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        auctionCounter++;
        auctionId = auctionCounter;

        auctions[auctionId] = Auction({
            auctionType:  auctionType_,
            status:       AuctionStatus.ACTIVE,
            nftContract:  nftContract,
            tokenId:      tokenId,
            seller:       msg.sender,
            startPrice:   startPrice,
            reservePrice: reservePrice,
            startTime:    block.timestamp,
            endTime:      block.timestamp + duration,
            revealDeadline: auctionType_ == AuctionType.SEALED
                ? block.timestamp + duration + sealedRevealWindow
                : 0,
            highestBidder: address(0),
            highestBid:    0,
            royaltyPaid:   false
        });

        emit AuctionCreated(auctionId, auctionType_, nftContract, tokenId, msg.sender, startPrice);
    }

    // ============================================
    // BIDDING — ENGLISH
    // ============================================

    /**
     * @notice Place a bid in an English auction
     */
    function placeBid(uint256 auctionId) external payable nonReentrant {
        require(!paused, "Auction: paused");
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.ACTIVE, "Auction: not active");
        require(a.auctionType == AuctionType.ENGLISH, "Auction: use placeBid for English only");
        require(block.timestamp < a.endTime, "Auction: ended");
        require(msg.sender != a.seller, "Auction: seller cannot bid");

        uint256 minRequired;
        if (a.highestBid == 0) {
            minRequired = a.startPrice;
        } else {
            minRequired = a.highestBid + (a.highestBid * minBidIncrementBps / 10000);
        }
        require(msg.value >= minRequired, "Auction: bid too low");

        // Refund previous highest bidder
        if (a.highestBidder != address(0)) {
            pendingReturns[auctionId][a.highestBidder] += a.highestBid;
        }

        a.highestBidder = msg.sender;
        a.highestBid    = msg.value;

        _awardXP(msg.sender, 10, IXPHub.XPSource.AUCTION_BID);
        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    /**
     * @notice Pull pending refund (for outbid bidders in English auctions)
     */
    function claimRefund(uint256 auctionId) external nonReentrant {
        uint256 amount = pendingReturns[auctionId][msg.sender];
        require(amount > 0, "Auction: no refund pending");
        pendingReturns[auctionId][msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Auction: refund failed");
        emit RefundIssued(auctionId, msg.sender, amount);
    }

    // ============================================
    // BUYING — DUTCH
    // ============================================

    /**
     * @notice Buy at the current Dutch price
     */
    function buyDutch(uint256 auctionId) external payable nonReentrant {
        require(!paused, "Auction: paused");
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.ACTIVE, "Auction: not active");
        require(a.auctionType == AuctionType.DUTCH, "Auction: use buyDutch for Dutch only");
        require(block.timestamp < a.endTime, "Auction: ended");
        require(msg.sender != a.seller, "Auction: seller cannot buy");

        uint256 currentPrice = getDutchPrice(auctionId);
        require(msg.value >= currentPrice, "Auction: payment below current price");

        // Refund excess
        if (msg.value > currentPrice) {
            (bool refOk, ) = payable(msg.sender).call{value: msg.value - currentPrice}("");
            require(refOk, "Auction: refund failed");
        }

        a.highestBidder = msg.sender;
        a.highestBid    = currentPrice;
        a.status        = AuctionStatus.FINALIZED;

        _settleAuction(auctionId);
    }

    /**
     * @notice Calculate current Dutch auction price (linear decay)
     */
    function getDutchPrice(uint256 auctionId) public view returns (uint256) {
        Auction storage a = auctions[auctionId];
        if (block.timestamp >= a.endTime) return a.reservePrice;
        uint256 elapsed  = block.timestamp - a.startTime;
        uint256 duration = a.endTime - a.startTime;
        uint256 priceDrop = ((a.startPrice - a.reservePrice) * elapsed) / duration;
        return a.startPrice - priceDrop;
    }

    // ============================================
    // BIDDING — SEALED BID
    // ============================================

    /**
     * @notice Commit a sealed bid
     * @param auctionId  Target auction
     * @param commitment keccak256(abi.encode(amount, salt)) — keep amount and salt secret until reveal
     * @dev   Send ETH deposit at least equal to your intended bid amount
     */
    function commitSealedBid(uint256 auctionId, bytes32 commitment) external payable nonReentrant {
        require(!paused, "Auction: paused");
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.ACTIVE, "Auction: not active");
        require(a.auctionType == AuctionType.SEALED, "Auction: sealed bids only");
        require(block.timestamp < a.endTime, "Auction: commit phase ended");
        require(msg.sender != a.seller, "Auction: seller cannot bid");
        require(!hasSealedCommit[auctionId][msg.sender], "Auction: already committed");
        require(msg.value >= a.startPrice, "Auction: deposit below start price");

        sealedCommits[auctionId][msg.sender] = SealedBidCommit({
            commitment:     commitment,
            deposit:        msg.value,
            bidder:         msg.sender,
            revealed:       false,
            revealedAmount: 0
        });
        hasSealedCommit[auctionId][msg.sender] = true;
        _sealedBidders[auctionId].push(msg.sender);

        emit BidCommitted(auctionId, msg.sender, commitment);
    }

    /**
     * @notice Reveal your sealed bid during the reveal window
     * @param amount Actual bid amount
     * @param salt   The salt used when creating the commitment
     */
    function revealSealedBid(
        uint256 auctionId,
        uint256 amount,
        bytes32 salt
    ) external nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.auctionType == AuctionType.SEALED, "Auction: not sealed");
        require(block.timestamp >= a.endTime, "Auction: commit phase still open");
        require(block.timestamp < a.revealDeadline, "Auction: reveal window closed");

        SealedBidCommit storage commit = sealedCommits[auctionId][msg.sender];
        require(commit.bidder == msg.sender, "Auction: no commitment found");
        require(!commit.revealed, "Auction: already revealed");
        require(
            keccak256(abi.encode(amount, salt)) == commit.commitment,
            "Auction: invalid reveal"
        );
        require(commit.deposit >= amount, "Auction: deposit too low for revealed amount");

        commit.revealed        = true;
        commit.revealedAmount  = amount;

        // Update highest bid
        if (amount > a.highestBid) {
            a.highestBid    = amount;
            a.highestBidder = msg.sender;
        }

        emit BidRevealed(auctionId, msg.sender, amount);
    }

    /**
     * @notice Finalize sealed auction after reveal window closes
     */
    function finalizeSealedAuction(uint256 auctionId) external nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.ACTIVE, "Auction: not active");
        require(a.auctionType == AuctionType.SEALED, "Auction: not sealed");
        require(block.timestamp >= a.revealDeadline, "Auction: reveal window still open");

        _finalizeSealedBids(auctionId);
    }

    function _finalizeSealedBids(uint256 auctionId) internal {
        Auction storage a = auctions[auctionId];

        bool reserveMet = (a.reservePrice == 0 || a.highestBid >= a.reservePrice);

        if (a.highestBidder == address(0) || !reserveMet) {
            a.status = AuctionStatus.CANCELLED;
            IERC721(a.nftContract).transferFrom(address(this), a.seller, a.tokenId);
            emit AuctionCancelled(auctionId);
        } else {
            a.status = AuctionStatus.FINALIZED;
            // Refund all non-winners
            address[] storage bidders = _sealedBidders[auctionId];
            for (uint256 i; i < bidders.length; i++) {
                address bidder = bidders[i];
                SealedBidCommit storage commit = sealedCommits[auctionId][bidder];
                if (bidder != a.highestBidder) {
                    // Full refund for non-winners
                    if (commit.deposit > 0) {
                        uint256 refund = commit.deposit;
                        commit.deposit = 0;
                        (bool ok, ) = payable(bidder).call{value: refund}("");
                        if (ok) emit RefundIssued(auctionId, bidder, refund);
                    }
                } else {
                    // Winner: refund excess deposit above winning bid
                    if (commit.deposit > a.highestBid) {
                        uint256 excess = commit.deposit - a.highestBid;
                        commit.deposit = a.highestBid;
                        (bool ok, ) = payable(bidder).call{value: excess}("");
                        if (ok) emit RefundIssued(auctionId, bidder, excess);
                    }
                }
            }
            _settleAuction(auctionId);
        }
    }

    // ============================================
    // FINALIZATION — ENGLISH
    // ============================================

    /**
     * @notice Finalize an English auction after end time
     */
    function finalizeEnglishAuction(uint256 auctionId) external nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.ACTIVE, "Auction: not active");
        require(a.auctionType == AuctionType.ENGLISH, "Auction: not English");
        require(block.timestamp >= a.endTime, "Auction: still ongoing");

        // Check reserve
        bool reserveMet = (a.reservePrice == 0 || a.highestBid >= a.reservePrice);

        if (a.highestBidder == address(0) || !reserveMet) {
            a.status = AuctionStatus.CANCELLED;
            IERC721(a.nftContract).transferFrom(address(this), a.seller, a.tokenId);
            if (a.highestBidder != address(0) && a.highestBid > 0) {
                pendingReturns[auctionId][a.highestBidder] += a.highestBid;
            }
            emit AuctionCancelled(auctionId);
        } else {
            a.status = AuctionStatus.FINALIZED;
            _settleAuction(auctionId);
        }
    }

    /**
     * @notice Seller cancels an auction before any bids (English only)
     */
    function cancelAuction(uint256 auctionId) external nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.seller == msg.sender, "Auction: not seller");
        require(a.status == AuctionStatus.ACTIVE, "Auction: not active");
        require(a.highestBidder == address(0), "Auction: has bids");

        a.status = AuctionStatus.CANCELLED;
        IERC721(a.nftContract).transferFrom(address(this), a.seller, a.tokenId);
        emit AuctionCancelled(auctionId);
    }

    // ============================================
    // SETTLEMENT
    // ============================================

    function _settleAuction(uint256 auctionId) internal {
        Auction storage a = auctions[auctionId];

        // Transfer NFT to winner
        IERC721(a.nftContract).transferFrom(address(this), a.highestBidder, a.tokenId);

        uint256 salePrice = a.highestBid;

        // ERC-2981 royalty
        uint256 royaltyAmount;
        address royaltyRecipient;
        try IERC2981(a.nftContract).royaltyInfo(a.tokenId, salePrice) returns (address recipient, uint256 amount) {
            if (recipient != address(0) && recipient != a.seller) {
                // Cap royalty to maxRoyaltyBps
                uint256 maxRoyalty = (salePrice * maxRoyaltyBps) / 10000;
                royaltyAmount    = amount > maxRoyalty ? maxRoyalty : amount;
                royaltyRecipient = recipient;
            }
        } catch {}

        // Platform fee
        uint256 platformFee = (salePrice * platformFeeBps) / 10000;

        // Ensure deductions don't exceed sale price
        if (platformFee + royaltyAmount > salePrice) {
            royaltyAmount = 0;
            platformFee   = (salePrice * platformFeeBps) / 10000;
        }

        uint256 sellerAmount = salePrice - platformFee - royaltyAmount;

        // Pay royalty
        if (royaltyAmount > 0 && royaltyRecipient != address(0)) {
            (bool royOk, ) = payable(royaltyRecipient).call{value: royaltyAmount}("");
            if (!royOk) sellerAmount += royaltyAmount; // fall back to seller if recipient fails
        }

        // Platform fee to treasury
        if (platformFee > 0) {
            try treasuryManager.receiveRevenue{value: platformFee}("auction_platform_fee") {} catch {
                sellerAmount += platformFee; // fallback to seller if treasury call fails
            }
        }

        // Pay seller
        if (sellerAmount > 0) {
            (bool selOk, ) = payable(a.seller).call{value: sellerAmount}("");
            require(selOk, "Auction: seller payment failed");
        }

        // XP rewards
        _awardXP(a.highestBidder, 100, IXPHub.XPSource.AUCTION_WIN);
        _awardXP(a.seller,        50,  IXPHub.XPSource.MARKETPLACE_SELL);

        emit AuctionFinalized(auctionId, a.highestBidder, salePrice);
    }

    function _awardXP(address user, uint256 amount, IXPHub.XPSource source) internal {
        try levelingSystem.awardXP(user, amount, source) {} catch {}
    }

    // ============================================
    // ADMIN
    // ============================================

    function setPlatformFee(uint256 feeBps) external onlyRole(ADMIN_ROLE) {
        require(feeBps <= 1000, "Auction: fee too high"); // max 10%
        platformFeeBps = feeBps;
    }

    function setMaxRoyalty(uint256 maxBps) external onlyRole(ADMIN_ROLE) {
        require(maxBps <= 2500, "Auction: royalty cap too high");
        maxRoyaltyBps = maxBps;
    }

    function setMinBidIncrement(uint256 bps) external onlyRole(ADMIN_ROLE) {
        require(bps >= 50 && bps <= 1000, "Auction: invalid increment");
        minBidIncrementBps = bps;
    }

    function setSealedRevealWindow(uint256 window) external onlyRole(ADMIN_ROLE) {
        require(window >= 1 hours && window <= 7 days, "Auction: invalid window");
        sealedRevealWindow = window;
    }

    function setPaused(bool paused_) external onlyRole(PAUSER_ROLE) {
        paused = paused_;
    }

    function setTreasuryManager(address tm) external onlyRole(ADMIN_ROLE) {
        require(tm != address(0), "Auction: invalid address");
        treasuryManager = IAuctionTreasury(tm);
    }

    function setLevelingSystem(address ls) external onlyRole(ADMIN_ROLE) {
        require(ls != address(0), "Auction: invalid address");
        levelingSystem = IXPHub(ls);
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ============================================
    // VIEW
    // ============================================

    function getAuction(uint256 auctionId) external view returns (Auction memory) {
        return auctions[auctionId];
    }

    function getSealedBidders(uint256 auctionId) external view returns (address[] memory) {
        return _sealedBidders[auctionId];
    }
}
