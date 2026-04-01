// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface INFTRentalHook {
    function setRenter(uint256 tokenId, address renter, uint256 expiry) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool);
}

interface IRentalTreasury {
    function depositRevenue(string calldata revenueType) external payable;
}

interface IRentalAgentRegistry {
    function registeredNFTContracts(address nftContract) external view returns (bool);
}

/**
 * @title NuxAgentRental
 * @notice Time-based NFT rental system for AI Agent NFTs
 * @dev Enables owners to earn passive income by renting their agents.
 *
 * RENTAL FLOW:
 *   1. Owner calls createRentalOffer() → defines duration range and price per day
 *   2. Renter calls rentAgent(offerId, days) with payment
 *   3. Contract splits revenue and calls setRenter() on the NFT contract (needs RENTAL_ROLE)
 *   4. Renter gains effective-controller access via currentRenter / rentalExpiry mapping
 *   5. On expiry, anyone calls claimExpiredRental() to clean up state
 *
 * REVENUE SPLIT:
 *   - 80% to NFT owner
 *   - 14% to TreasuryManager
 *   - 6% to platform (same TreasuryManager with type "rental_platform_fee")
 *
 * EXTENSIONS:
 *   Renters may extend an active rental before expiry. The additional cost
 *   is calculated pro-rata and follows the same revenue split.
 *
 * SECURITY:
 *   - Rental is aborted if the NFT is transferred (setRenter called with address(0) by base contract)
 *   - Owner cannot rent their own NFT (prevents circular ownership tricks)
 *   - The contract holds no NFTs in escrow — only payment flow is managed here
 */
contract NuxAgentRental is
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
    // STATE
    // ============================================

    struct RentalOffer {
        address nftContract;
        uint256 tokenId;
        address owner;
        uint256 pricePerDay;    // In wei
        uint256 minDays;
        uint256 maxDays;
        bool    active;
    }

    struct ActiveRental {
        uint256 offerId;
        address nftContract;
        uint256 tokenId;
        address renter;
        uint256 startTime;
        uint256 endTime;
        uint256 totalPaid;
        bool    active;
    }

    struct RentalOfferView {
        uint256 offerId;
        address nftContract;
        uint256 tokenId;
        address offerOwner;
        address currentOwner;
        uint256 pricePerDay;
        uint256 minDays;
        uint256 maxDays;
        bool    active;
        bool    hasActiveRental;
        uint256 activeRentalId;
    }

    struct ActiveRentalView {
        uint256 rentalId;
        uint256 offerId;
        address nftContract;
        uint256 tokenId;
        address owner;
        address renter;
        uint256 startTime;
        uint256 endTime;
        uint256 totalPaid;
        bool    active;
        uint256 remainingTime;
    }

    struct RentalMarketStats {
        uint256 totalOffers;
        uint256 activeOffers;
        uint256 totalRentals;
        uint256 activeRentals;
    }

    struct OwnerRentalSummary {
        uint256 totalOffers;
        uint256 activeOffers;
        uint256 totalRentalsOut;
        uint256 activeRentalsOut;
    }

    IRentalTreasury public treasuryManager;
    address public agentRegistry;

    uint256 public offerCounter;
    uint256 public rentalCounter;

    mapping(uint256 => RentalOffer)  public rentalOffers;
    mapping(uint256 => ActiveRental) public activeRentals;

    // tokenId + nftContract → active rentalId (0 = none, use hasActiveRental)
    mapping(address => mapping(uint256 => uint256)) private _tokenRentalId;
    mapping(address => mapping(uint256 => bool))    private _hasActiveRental;

    // Revenue split (basis points, sum = 10000)
    uint256 public ownerShareBps;    // default 8000 (80%)
    uint256 public treasuryBps;      // default 1400 (14%)
    uint256 public platformBps;      // default  600 ( 6%)

    bool public paused;
    mapping(address => bool) public supportedNFTContracts;

    // ============================================
    // EVENTS
    // ============================================
    event RentalOfferCreated(uint256 indexed offerId, address indexed nftContract, uint256 indexed tokenId, uint256 pricePerDay);
    event RentalOfferCancelled(uint256 indexed offerId);
    event RentalStarted(uint256 indexed rentalId, uint256 indexed offerId, address indexed renter, uint256 endTime, uint256 paid);
    event RentalExtended(uint256 indexed rentalId, uint256 newEndTime, uint256 extraPaid);
    event RentalEnded(uint256 indexed rentalId);
    event RevenueDistributed(uint256 indexed rentalId, address owner, uint256 ownerAmount, uint256 treasuryAmount);
    event AgentRegistryUpdated(address indexed agentRegistry);
    event SupportedNFTContractUpdated(address indexed nftContract, bool supported);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address treasuryManager_
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);

        treasuryManager = IRentalTreasury(treasuryManager_);
        ownerShareBps   = 8000;
        treasuryBps     = 1400;
        platformBps     = 600;
    }

    // ============================================
    // RENTAL OFFERS
    // ============================================

    /**
     * @notice List your AI Agent NFT for rental
     * @param nftContract Address of the category NFT contract
     * @param tokenId     Token ID to offer
     * @param pricePerDay Rental price per day in wei
     * @param minDays     Minimum rental duration (>= 1)
     * @param maxDays     Maximum rental duration (<= 365)
     */
    function createRentalOffer(
        address nftContract,
        uint256 tokenId,
        uint256 pricePerDay,
        uint256 minDays,
        uint256 maxDays
    ) external returns (uint256 offerId) {
        require(!paused, "Rental: paused");
        require(nftContract != address(0), "Rental: invalid contract");
        require(pricePerDay > 0, "Rental: price must be > 0");
        require(minDays >= 1 && minDays <= maxDays, "Rental: invalid duration range");
        require(maxDays <= 365, "Rental: max 365 days");
        require(_isSupportedNFTContract(nftContract), "Rental: unsupported NFT contract");
        require(
            INFTRentalHook(nftContract).ownerOf(tokenId) == msg.sender,
            "Rental: not token owner"
        );
        require(
            !_hasActiveRental[nftContract][tokenId],
            "Rental: token already rented"
        );

        offerCounter++;
        offerId = offerCounter;

        rentalOffers[offerId] = RentalOffer({
            nftContract:  nftContract,
            tokenId:      tokenId,
            owner:        msg.sender,
            pricePerDay:  pricePerDay,
            minDays:      minDays,
            maxDays:      maxDays,
            active:       true
        });

        emit RentalOfferCreated(offerId, nftContract, tokenId, pricePerDay);
    }

    /**
     * @notice Cancel an existing rental offer (only if token not currently rented)
     */
    function cancelRentalOffer(uint256 offerId) external {
        RentalOffer storage offer = rentalOffers[offerId];
        require(offer.owner == msg.sender, "Rental: not offer owner");
        require(offer.active, "Rental: already inactive");
        require(!_hasActiveRental[offer.nftContract][offer.tokenId], "Rental: has active rental");
        offer.active = false;
        emit RentalOfferCancelled(offerId);
    }

    // ============================================
    // RENTAL LIFECYCLE
    // ============================================

    /**
     * @notice Rent an AI Agent NFT for a specified number of days
     * @param offerId  The rental offer ID
     * @param days_    Rental duration in days (must be within offer's min/max range)
     */
    function rentAgent(
        uint256 offerId,
        uint256 days_
    ) external payable nonReentrant returns (uint256 rentalId) {
        require(!paused, "Rental: paused");
        RentalOffer storage offer = rentalOffers[offerId];
        require(offer.active, "Rental: offer not active");
        require(days_ >= offer.minDays && days_ <= offer.maxDays, "Rental: invalid duration");
        require(offer.owner != msg.sender, "Rental: owner can't rent own token");
        require(!_hasActiveRental[offer.nftContract][offer.tokenId], "Rental: already rented");

        uint256 totalCost = offer.pricePerDay * days_;
        require(msg.value >= totalCost, "Rental: insufficient payment");

        // Refund excess
        if (msg.value > totalCost) {
            (bool refundOk, ) = payable(msg.sender).call{value: msg.value - totalCost}("");
            require(refundOk, "Rental: refund failed");
        }

        uint256 endTime = block.timestamp + (days_ * 1 days);

        rentalCounter++;
        rentalId = rentalCounter;

        activeRentals[rentalId] = ActiveRental({
            offerId:     offerId,
            nftContract: offer.nftContract,
            tokenId:     offer.tokenId,
            renter:      msg.sender,
            startTime:   block.timestamp,
            endTime:     endTime,
            totalPaid:   totalCost,
            active:      true
        });

        _hasActiveRental[offer.nftContract][offer.tokenId] = true;
        _tokenRentalId[offer.nftContract][offer.tokenId]   = rentalId;

        // Grant renter access on the NFT contract
        INFTRentalHook(offer.nftContract).setRenter(offer.tokenId, msg.sender, endTime);

        // Distribute revenue
        _distributeRevenue(rentalId, offer.owner, totalCost);

        emit RentalStarted(rentalId, offerId, msg.sender, endTime, totalCost);
    }

    /**
     * @notice Extend an active rental (renter only)
     * @param rentalId  Rental to extend
     * @param extraDays Additional days to add
     */
    function extendRental(uint256 rentalId, uint256 extraDays) external payable nonReentrant {
        require(!paused, "Rental: paused");
        ActiveRental storage rental = activeRentals[rentalId];
        require(rental.active, "Rental: rental not active");
        require(rental.renter == msg.sender, "Rental: not renter");
        require(block.timestamp < rental.endTime, "Rental: already expired");

        RentalOffer storage offer = rentalOffers[rental.offerId];
        uint256 newEnd = rental.endTime + (extraDays * 1 days);
        uint256 totalDaysFromNow = (newEnd - block.timestamp) / 1 days;
        require(totalDaysFromNow <= offer.maxDays, "Rental: exceeds max duration");

        uint256 extraCost = offer.pricePerDay * extraDays;
        require(msg.value >= extraCost, "Rental: insufficient payment");

        if (msg.value > extraCost) {
            (bool refundOk, ) = payable(msg.sender).call{value: msg.value - extraCost}("");
            require(refundOk, "Rental: refund failed");
        }

        rental.endTime   = newEnd;
        rental.totalPaid += extraCost;

        // Update expiry on the NFT contract
        INFTRentalHook(offer.nftContract).setRenter(offer.tokenId, msg.sender, newEnd);

        _distributeRevenue(rentalId, offer.owner, extraCost);

        emit RentalExtended(rentalId, newEnd, extraCost);
    }

    /**
     * @notice Clean up an expired rental (anyone can call)
     */
    function claimExpiredRental(uint256 rentalId) external {
        ActiveRental storage rental = activeRentals[rentalId];
        require(rental.active, "Rental: not active");
        require(block.timestamp >= rental.endTime, "Rental: not expired yet");

        _endRental(rentalId);
    }

    /**
     * @notice Renter ends rental early (no refund)
     */
    function endRentalEarly(uint256 rentalId) external {
        ActiveRental storage rental = activeRentals[rentalId];
        require(rental.active, "Rental: not active");
        require(rental.renter == msg.sender, "Rental: not renter");

        _endRental(rentalId);
    }

    function _endRental(uint256 rentalId) internal {
        ActiveRental storage rental = activeRentals[rentalId];

        rental.active = false;
        _hasActiveRental[rental.nftContract][rental.tokenId] = false;

        // Clear renter access on NFT contract
        INFTRentalHook(rental.nftContract).setRenter(rental.tokenId, address(0), 0);

        emit RentalEnded(rentalId);
    }

    // ============================================
    // REVENUE DISTRIBUTION
    // ============================================

    function _distributeRevenue(
        uint256 rentalId,
        address owner_,
        uint256 amount
    ) internal {
        uint256 ownerAmount    = (amount * ownerShareBps) / 10000;
        uint256 treasuryAmount = (amount * treasuryBps)   / 10000;
        uint256 platformAmount = amount - ownerAmount - treasuryAmount;

        // Pay owner
        (bool ownerOk, ) = payable(owner_).call{value: ownerAmount}("");
        require(ownerOk, "Rental: owner payment failed");

        // Pay treasury: combines owner-share (14%) + platform fee (6%) in a single call to save gas
        uint256 totalFees = treasuryAmount + platformAmount;
        if (totalFees > 0) {
            try treasuryManager.depositRevenue{value: totalFees}("nuxtap_agent_rental_fee") {} catch {}
        }

        emit RevenueDistributed(rentalId, owner_, ownerAmount, totalFees);
    }

    // ============================================
    // ADMIN
    // ============================================

    function setRevenueShares(uint256 ownerBps_, uint256 treasuryBps_) external onlyRole(ADMIN_ROLE) {
        require(ownerBps_ + treasuryBps_ <= 10000, "Rental: shares exceed 100%");
        ownerShareBps = ownerBps_;
        treasuryBps   = treasuryBps_;
        platformBps   = 10000 - ownerBps_ - treasuryBps_;
    }

    function setPaused(bool paused_) external onlyRole(ADMIN_ROLE) {
        paused = paused_;
    }

    function setAgentRegistry(address registry_) external onlyRole(ADMIN_ROLE) {
        agentRegistry = registry_;
        emit AgentRegistryUpdated(registry_);
    }

    function setSupportedNFTContract(address nftContract, bool supported) external onlyRole(ADMIN_ROLE) {
        require(nftContract != address(0), "Rental: invalid contract");
        supportedNFTContracts[nftContract] = supported;
        emit SupportedNFTContractUpdated(nftContract, supported);
    }

    function setTreasuryManager(address tm_) external onlyRole(ADMIN_ROLE) {
        require(tm_ != address(0), "Rental: invalid address");
        treasuryManager = IRentalTreasury(tm_);
    }

    uint256[50] private __gap;

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    function _isSupportedNFTContract(address nftContract) internal view returns (bool) {
        if (supportedNFTContracts[nftContract]) {
            return true;
        }

        if (agentRegistry == address(0)) {
            return false;
        }

        try IRentalAgentRegistry(agentRegistry).registeredNFTContracts(nftContract) returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    // ============================================
    // VIEW
    // ============================================

    function getActiveRentalForToken(
        address nftContract,
        uint256 tokenId
    ) external view returns (uint256 rentalId, bool hasRental) {
        hasRental = _hasActiveRental[nftContract][tokenId];
        rentalId  = hasRental ? _tokenRentalId[nftContract][tokenId] : 0;
    }

    function getRentalCost(uint256 offerId, uint256 days_) external view returns (uint256) {
        return rentalOffers[offerId].pricePerDay * days_;
    }

    function getRentalOfferDetails(uint256 offerId) external view returns (RentalOfferView memory) {
        return _buildOfferView(offerId);
    }

    function getActiveRentalDetails(uint256 rentalId) external view returns (ActiveRentalView memory) {
        return _buildRentalView(rentalId);
    }

    function getTokenRentalStatus(
        address nftContract,
        uint256 tokenId
    ) external view returns (
        bool hasRental,
        uint256 rentalId,
        address renter,
        uint256 endTime,
        uint256 remainingTime,
        bool hasActiveOffer,
        uint256 offerId,
        uint256 pricePerDay,
        address currentOwner
    ) {
        currentOwner = INFTRentalHook(nftContract).ownerOf(tokenId);

        hasRental = _hasActiveRental[nftContract][tokenId];
        if (hasRental) {
            rentalId = _tokenRentalId[nftContract][tokenId];
            ActiveRental storage rental = activeRentals[rentalId];
            renter = rental.renter;
            endTime = rental.endTime;
            remainingTime = rental.endTime > block.timestamp ? rental.endTime - block.timestamp : 0;
        }

        for (uint256 currentOfferId = offerCounter; currentOfferId > 0; currentOfferId--) {
            RentalOffer storage offer = rentalOffers[currentOfferId];
            if (offer.nftContract == nftContract && offer.tokenId == tokenId && offer.active) {
                hasActiveOffer = true;
                offerId = currentOfferId;
                pricePerDay = offer.pricePerDay;
                break;
            }
        }
    }

    function getRentalOffersPage(
        uint256 offset,
        uint256 limit,
        bool activeOnly
    ) external view returns (RentalOfferView[] memory offers, uint256 total) {
        return _getRentalOffersPage(offset, limit, activeOnly, address(0), false);
    }

    function getOwnerRentalOffers(
        address owner,
        uint256 offset,
        uint256 limit,
        bool activeOnly
    ) external view returns (RentalOfferView[] memory offers, uint256 total) {
        return _getRentalOffersPage(offset, limit, activeOnly, owner, true);
    }

    function getRenterRentals(
        address renter,
        uint256 offset,
        uint256 limit,
        bool activeOnly
    ) external view returns (ActiveRentalView[] memory rentals, uint256 total) {
        return _getRenterRentals(renter, offset, limit, activeOnly);
    }

    function getRentalMarketStats() external view returns (RentalMarketStats memory stats) {
        stats.totalOffers = offerCounter;
        stats.totalRentals = rentalCounter;

        for (uint256 offerId = 1; offerId <= offerCounter; offerId++) {
            if (rentalOffers[offerId].active) {
                stats.activeOffers++;
            }
        }

        for (uint256 rentalId = 1; rentalId <= rentalCounter; rentalId++) {
            if (activeRentals[rentalId].active) {
                stats.activeRentals++;
            }
        }
    }

    function getOwnerRentalSummary(address owner) external view returns (OwnerRentalSummary memory summary) {
        for (uint256 offerId = 1; offerId <= offerCounter; offerId++) {
            RentalOffer storage offer = rentalOffers[offerId];
            if (offer.owner != owner) {
                continue;
            }
            summary.totalOffers++;
            if (offer.active) {
                summary.activeOffers++;
            }
        }

        for (uint256 rentalId = 1; rentalId <= rentalCounter; rentalId++) {
            ActiveRental storage rental = activeRentals[rentalId];
            RentalOffer storage offer = rentalOffers[rental.offerId];
            if (offer.owner != owner) {
                continue;
            }
            summary.totalRentalsOut++;
            if (rental.active) {
                summary.activeRentalsOut++;
            }
        }
    }

    function _getRentalOffersPage(
        uint256 offset,
        uint256 limit,
        bool activeOnly,
        address owner,
        bool filterByOwner
    ) internal view returns (RentalOfferView[] memory offers, uint256 total) {
        if (limit == 0 || offset >= offerCounter) {
            return (new RentalOfferView[](0), 0);
        }

        for (uint256 offerId = 1; offerId <= offerCounter; offerId++) {
            RentalOffer storage offer = rentalOffers[offerId];
            if (_matchesOfferFilter(offer, activeOnly, owner, filterByOwner)) {
                total++;
            }
        }

        if (offset >= total) {
            return (new RentalOfferView[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) end = total;

        offers = new RentalOfferView[](end - offset);
        uint256 seen;
        uint256 index;

        for (uint256 offerId = 1; offerId <= offerCounter && index < offers.length; offerId++) {
            RentalOffer storage offer = rentalOffers[offerId];
            if (!_matchesOfferFilter(offer, activeOnly, owner, filterByOwner)) {
                continue;
            }
            if (seen >= offset) {
                offers[index] = _buildOfferView(offerId);
                index++;
            }
            seen++;
        }
    }

    function _getRenterRentals(
        address renter,
        uint256 offset,
        uint256 limit,
        bool activeOnly
    ) internal view returns (ActiveRentalView[] memory rentals, uint256 total) {
        if (limit == 0 || offset >= rentalCounter) {
            return (new ActiveRentalView[](0), 0);
        }

        for (uint256 rentalId = 1; rentalId <= rentalCounter; rentalId++) {
            ActiveRental storage rental = activeRentals[rentalId];
            if (rental.renter == renter && (!activeOnly || rental.active)) {
                total++;
            }
        }

        if (offset >= total) {
            return (new ActiveRentalView[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) end = total;

        rentals = new ActiveRentalView[](end - offset);
        uint256 seen;
        uint256 index;

        for (uint256 rentalId = 1; rentalId <= rentalCounter && index < rentals.length; rentalId++) {
            ActiveRental storage rental = activeRentals[rentalId];
            if (rental.renter != renter || (activeOnly && !rental.active)) {
                continue;
            }
            if (seen >= offset) {
                rentals[index] = _buildRentalView(rentalId);
                index++;
            }
            seen++;
        }
    }

    function _matchesOfferFilter(
        RentalOffer storage offer,
        bool activeOnly,
        address owner,
        bool filterByOwner
    ) internal view returns (bool) {
        if (activeOnly && !offer.active) return false;
        if (filterByOwner && offer.owner != owner) return false;
        return true;
    }

    function _buildOfferView(uint256 offerId) internal view returns (RentalOfferView memory view_) {
        RentalOffer storage offer = rentalOffers[offerId];
        bool hasRental = _hasActiveRental[offer.nftContract][offer.tokenId];

        view_.offerId = offerId;
        view_.nftContract = offer.nftContract;
        view_.tokenId = offer.tokenId;
        view_.offerOwner = offer.owner;
        view_.currentOwner = offer.nftContract == address(0) ? address(0) : INFTRentalHook(offer.nftContract).ownerOf(offer.tokenId);
        view_.pricePerDay = offer.pricePerDay;
        view_.minDays = offer.minDays;
        view_.maxDays = offer.maxDays;
        view_.active = offer.active;
        view_.hasActiveRental = hasRental;
        view_.activeRentalId = hasRental ? _tokenRentalId[offer.nftContract][offer.tokenId] : 0;
    }

    function _buildRentalView(uint256 rentalId) internal view returns (ActiveRentalView memory view_) {
        ActiveRental storage rental = activeRentals[rentalId];
        RentalOffer storage offer = rentalOffers[rental.offerId];

        view_.rentalId = rentalId;
        view_.offerId = rental.offerId;
        view_.nftContract = rental.nftContract;
        view_.tokenId = rental.tokenId;
        view_.owner = offer.owner;
        view_.renter = rental.renter;
        view_.startTime = rental.startTime;
        view_.endTime = rental.endTime;
        view_.totalPaid = rental.totalPaid;
        view_.active = rental.active;
        view_.remainingTime = rental.endTime > block.timestamp ? rental.endTime - block.timestamp : 0;
    }
}
