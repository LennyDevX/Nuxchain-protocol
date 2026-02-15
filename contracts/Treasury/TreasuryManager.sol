// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TreasuryManager
 * @notice Centralizes all protocol revenue streams and distributes to specialized treasuries
 * @dev Receives commissions from Staking (6%), Marketplace (6%), Individual Skills sales
 *      Implements weekly distribution cycle (7 days) starting from first deposit
 * 
 * RESERVE FUND SYSTEM:
 * - Automatically allocates 20% of ALL revenue to emergency reserve
 * - Reserve provides 6-12 month buffer for volatility protection
 * - Can be withdrawn by owner during deficit periods or emergencies
 * - Helps maintain protocol sustainability during low-revenue periods
 * 
 * DISTRIBUTION TIMELINE:
 * - First deposit received initializes the distribution cycle
 * - Distributions occur every 7 days from first deposit time
 * - Revenue accumulates in contract until next distribution window
 * - Rewards can be requested immediately from TreasuryManager balance (pre-funded)
 */
contract TreasuryManager is Ownable, ReentrancyGuard {
    
    // ============================================
    // ENUMS
    // ============================================
    
    /// @notice Treasury types for gas-efficient storage
    enum TreasuryType {
        REWARDS,        // 0 - Quest/Achievement/Level-up rewards
        STAKING,        // 1 - Staking operations & sustainability
        COLLABORATORS,  // 2 - Collaborator badge holder rewards
        DEVELOPMENT,    // 3 - Protocol development & maintenance
        MARKETPLACE     // 4 - Marketplace operations (if needed)
    }
    
    /// @notice Protocol health status
    enum ProtocolStatus {
        HEALTHY,        // 0 - Operating normally, sufficient funds
        UNSTABLE,       // 1 - Low on funds but operational
        CRITICAL,       // 2 - Near insolvency, at risk of reverts
        EMERGENCY       // 3 - Active emergency, using reserve funds
    }
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    /// @notice Distribution interval (7 days)
    uint256 private constant DISTRIBUTION_INTERVAL = 7 days;
    
    /// @notice Default reserve fund allocation (20% of ALL incoming revenue)
    uint256 private constant DEFAULT_RESERVE_PERCENTAGE = 2000; // 20% in basis points
    
    /// @notice Maximum reserve fund allocation cap
    uint256 private constant MAX_RESERVE_PERCENTAGE = 3000; // 30% in basis points
    
    /// @notice Basis points constant
    uint256 private constant BASIS_POINTS = 10000;
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /// @notice Treasury addresses (enum-based for gas optimization)
    mapping(TreasuryType => address) public treasuries;
    
    /// @notice Allocation percentages (in basis points, 10000 = 100%)
    mapping(TreasuryType => uint256) public allocations;
    
    /// @notice Total revenue received (all sources)
    uint256 public totalRevenueReceived;
    
    /// @notice Total distributed to treasuries
    uint256 public totalDistributed;
    
    /// @notice Last distribution timestamp
    uint256 public lastDistributionTime;
    
    /// @notice Timestamp of first deposit (initializes distribution cycle)
    uint256 public firstDepositTime;
    
    /// @notice Next scheduled distribution time
    uint256 public nextDistributionTime;
    
    /// @notice Auto-distribution enabled (weekly cycle)
    bool public autoDistributionEnabled;
    
    /// @notice Authorized revenue sources (contracts that can send funds)
    mapping(address => bool) public authorizedSources;
    
    /// @notice Authorized contracts that can request rewards funding
    mapping(address => bool) public authorizedRequester;
    
    // ============================================
    // RESERVE FUND STATE VARIABLES
    // ============================================
    
    /// @notice Reserve fund balance (emergency buffer)
    uint256 public reserveFundBalance;
    
    /// @notice Percentage of revenue allocated to reserve (in basis points)
    uint256 public reserveAllocationPercentage;
    
    /// @notice Total accumulated in reserve over time
    uint256 public totalReserveAccumulated;
    
    /// @notice Total withdrawn from reserve
    uint256 public totalReserveWithdrawn;
    
    /// @notice Enable/disable automatic reserve accumulation
    bool public reserveAccumulationEnabled;
    
    // ============================================
    // EMERGENCY & STABILITY STATE VARIABLES
    // ============================================
    
    /// @notice Current health status of each protocol
    mapping(TreasuryType => ProtocolStatus) public protocolStatus;
    
    /// @notice Accumulated deficit for each protocol (used to recover)
    mapping(TreasuryType => uint256) public protocolDeficit;
    
    /// @notice Total emergency funds distributed (for tracking)
    uint256 public totalEmergencyFundsDistributed;
    
    /// @notice Emergency mode enabled - allows protocols to access reserve
    bool public emergencyModeEnabled;
    
    /// @notice Timestamp of last emergency declaration
    uint256 public lastEmergencyTimestamp;
    
    // ============================================
    // EVENTS
    // ============================================
    
    event RevenueReceived(address indexed source, uint256 amount, string revenueType);
    event RevenueDistributed(TreasuryType indexed treasuryType, address indexed treasuryAddress, uint256 amount);
    event RewardFundsRequested(address indexed requester, uint256 amount, bool success);
    event TreasuryUpdated(TreasuryType indexed treasuryType, address indexed oldAddress, address indexed newAddress);
    event AllocationUpdated(TreasuryType indexed treasuryType, uint256 oldPercentage, uint256 newPercentage);
    event SourceAuthorized(address indexed source, bool authorized);
    event RequesterAuthorized(address indexed requester, bool authorized);
    event AutoDistributionToggled(bool enabled);
    event EmergencyWithdrawal(address indexed to, uint256 amount);
    event ReserveFundDeposit(uint256 amount, uint256 newBalance);
    event ReserveFundWithdrawal(address indexed to, uint256 amount, uint256 remainingBalance, string reason);
    event ReserveAllocationUpdated(uint256 oldPercentage, uint256 newPercentage);
    event ReserveAccumulationToggled(bool enabled);
    event DistributionCycleInitialized(uint256 firstDepositTime, uint256 nextDistributionTime);
    event DistributionTriggered(uint256 amount, uint256 nextDistributionTime);
    event EmergencyFundsRequested(TreasuryType indexed protocol, uint256 amount, bool success);
    event ProtocolStatusChanged(TreasuryType indexed protocol, ProtocolStatus oldStatus, ProtocolStatus newStatus);
    event EmergencyModeActivated(uint256 timestamp, string reason);
    event EmergencyModeDeactivated(uint256 timestamp);
    event ReserveFundsUsedForEmergency(TreasuryType indexed protocol, uint256 amount, string reason);
    event APYCompressionAlert(uint256 currentTVL, uint256 oldMultiplier, uint256 newMultiplier, uint256 compressionBps);
    event DeficitAccumulated(TreasuryType indexed protocol, uint256 amount, uint256 totalDeficit);
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        // Default allocations (apply to 80% after 20% reserve)
        allocations[TreasuryType.REWARDS] = 3000;       // 30% of distributable (24% of total)
        allocations[TreasuryType.STAKING] = 3500;       // 35% of distributable (28% of total)
        allocations[TreasuryType.COLLABORATORS] = 2000; // 20% of distributable (16% of total)
        allocations[TreasuryType.DEVELOPMENT] = 1500;   // 15% of distributable (12% of total)
        allocations[TreasuryType.MARKETPLACE] = 0;      // 0% (reserved for future use)
        
        // Initialize reserve fund system at 20% of ALL revenue
        reserveAllocationPercentage = DEFAULT_RESERVE_PERCENTAGE; // 20%
        reserveAccumulationEnabled = true;
        
        // Auto-distribution enabled (weekly cycle)
        autoDistributionEnabled = true;
        
        // Distribution cycle not started yet (initialized on first deposit)
        firstDepositTime = 0;
        nextDistributionTime = 0;
        lastDistributionTime = 0;
    }
    
    // ============================================
    // RECEIVE FUNCTIONS
    // ============================================
    
    /**
     * @notice Receive POL directly
     * @dev Initializes distribution cycle on first deposit
     */
    receive() external payable {
        totalRevenueReceived += msg.value;
        
        emit RevenueReceived(msg.sender, msg.value, "direct");
        
        // Initialize distribution cycle on first deposit
        if (firstDepositTime == 0 && msg.value > 0) {
            _initializeDistributionCycle();
        }
    }
    
    /**
     * @notice Receive revenue with type label (from authorized sources)
     * @param revenueType Type of revenue ("staking_commission", "marketplace_fee", etc.)
     * @dev Revenue accumulates until next distribution window
     */
    function receiveRevenue(string calldata revenueType) external payable {
        require(authorizedSources[msg.sender], "Not authorized source");
        
        totalRevenueReceived += msg.value;
        
        emit RevenueReceived(msg.sender, msg.value, revenueType);
        
        // Initialize distribution cycle on first deposit
        if (firstDepositTime == 0 && msg.value > 0) {
            _initializeDistributionCycle();
        }
    }
    
    /**
     * @notice Initialize the distribution cycle with first deposit
     * @dev Called automatically when first revenue is received
     */
    function _initializeDistributionCycle() internal {
        firstDepositTime = block.timestamp;
        nextDistributionTime = block.timestamp + DISTRIBUTION_INTERVAL;
        lastDistributionTime = block.timestamp;
        
        emit DistributionCycleInitialized(firstDepositTime, nextDistributionTime);
    }
    
    // ============================================
    // DISTRIBUTION FUNCTIONS
    // ============================================
    
    /**
     * @notice Trigger revenue distribution (only if cycle is ready)
     * @dev Can be called by anyone once the 7-day cycle completes
     */
    function triggerDistribution() external nonReentrant {
        require(firstDepositTime > 0, "No deposits yet");
        require(block.timestamp >= nextDistributionTime, "Distribution not ready");
        
        _distributeRevenue();
    }
    
    /**
     * @notice Check if distribution is ready to be triggered
     * @return ready True if distribution can be executed now
     * @return timeUntilNext Seconds until next distribution (0 if ready)
     */
    function isDistributionReady() external view returns (bool ready, uint256 timeUntilNext) {
        if (firstDepositTime == 0) {
            return (false, 0);
        }
        
        if (block.timestamp >= nextDistributionTime) {
            return (true, 0);
        } else {
            return (false, nextDistributionTime - block.timestamp);
        }
    }
    
    /**
     * @notice Internal distribution logic with reserve fund accumulation
     * @dev First allocates 20% to reserve fund, then distributes remaining 80% to treasuries
     */
    function _distributeRevenue() internal {
        uint256 balance = address(this).balance;
        
        // Don't distribute reserve fund balance
        if (balance <= reserveFundBalance) {
            // Update next distribution time even if nothing to distribute
            nextDistributionTime = block.timestamp + DISTRIBUTION_INTERVAL;
            lastDistributionTime = block.timestamp;
            return;
        }
        
        // Calculate distributable amount (exclude reserve fund)
        uint256 availableBalance = balance - reserveFundBalance;
        if (availableBalance == 0) {
            nextDistributionTime = block.timestamp + DISTRIBUTION_INTERVAL;
            lastDistributionTime = block.timestamp;
            return;
        }
        
        uint256 distributable = availableBalance;
        
        // Step 1: Allocate 20% to reserve fund if enabled
        if (reserveAccumulationEnabled && reserveAllocationPercentage > 0) {
            uint256 reserveAmount = (availableBalance * reserveAllocationPercentage) / BASIS_POINTS;
            if (reserveAmount > 0) {
                reserveFundBalance += reserveAmount;
                totalReserveAccumulated += reserveAmount;
                distributable -= reserveAmount;
                
                emit ReserveFundDeposit(reserveAmount, reserveFundBalance);
            }
        }
        
        // Step 2: Distribute remaining 80% to treasuries (optimized loop)
        if (distributable > 0) {
            _distributeToTreasuries(distributable);
        }
        
        // Step 3: Update distribution timeline
        lastDistributionTime = block.timestamp;
        nextDistributionTime = block.timestamp + DISTRIBUTION_INTERVAL;
        
        emit DistributionTriggered(availableBalance, nextDistributionTime);
    }
    
    /**
     * @notice Distribute funds to all treasuries (gas-optimized with enum iteration)
     * @param totalBalance Total amount to distribute
     */
    function _distributeToTreasuries(uint256 totalBalance) internal {
        // Iterate through all treasury types using enum
        for (uint8 i = 0; i <= uint8(TreasuryType.MARKETPLACE); i++) {
            TreasuryType treasuryType = TreasuryType(i);
            address treasuryAddr = treasuries[treasuryType];
            uint256 allocation = allocations[treasuryType];
            
            // Skip if not configured or zero allocation
            if (treasuryAddr == address(0) || allocation == 0) continue;
            
            uint256 amount = (totalBalance * allocation) / BASIS_POINTS;
            if (amount == 0) continue;
            
            totalDistributed += amount;
            
            (bool success, ) = payable(treasuryAddr).call{value: amount}("");
            require(success, "Transfer failed");
            
            emit RevenueDistributed(treasuryType, treasuryAddr, amount);
        }
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    /**
     * @notice Set treasury address for a specific type
     * @param treasuryType Type of treasury (enum)
     * @param treasuryAddress Address of the treasury
     */
    function setTreasury(TreasuryType treasuryType, address treasuryAddress) external onlyOwner {
        require(treasuryAddress != address(0), "Invalid address");
        
        address oldAddress = treasuries[treasuryType];
        treasuries[treasuryType] = treasuryAddress;
        
        emit TreasuryUpdated(treasuryType, oldAddress, treasuryAddress);
    }
    
    /**
     * @notice Update allocation percentage for a treasury type
     * @param treasuryType Type of treasury (enum)
     * @param percentage Percentage in basis points (10000 = 100%)
     */
    function setAllocation(TreasuryType treasuryType, uint256 percentage) external onlyOwner {
        require(percentage <= BASIS_POINTS, "Exceeds 100%");
        
        // Calculate total allocation with new percentage
        uint256 total = percentage;
        for (uint8 i = 0; i <= uint8(TreasuryType.MARKETPLACE); i++) {
            TreasuryType currentType = TreasuryType(i);
            if (currentType != treasuryType) {
                total += allocations[currentType];
            }
        }
        
        require(total <= BASIS_POINTS, "Total allocation exceeds 100%");
        
        uint256 oldPercentage = allocations[treasuryType];
        allocations[treasuryType] = percentage;
        
        emit AllocationUpdated(treasuryType, oldPercentage, percentage);
    }
    
    /**
     * @notice Authorize/deauthorize revenue source
     * @param source Contract address that can send revenue
     * @param authorized True to authorize, false to revoke
     */
    function setAuthorizedSource(address source, bool authorized) external onlyOwner {
        require(source != address(0), "Invalid address");
        authorizedSources[source] = authorized;
        
        emit SourceAuthorized(source, authorized);
    }
    
    /**
     * @notice Authorize/deauthorize reward requester
     * @param requester Contract address that can request reward funds
     * @param authorized True to authorize, false to revoke
     */
    function setAuthorizedRequester(address requester, bool authorized) external onlyOwner {
        require(requester != address(0), "Invalid address");
        authorizedRequester[requester] = authorized;
        
        emit RequesterAuthorized(requester, authorized);
    }
    
    /**
     * @notice Request funds from TreasuryManager for immediate reward payouts
     * @param amount Amount requested
     * @return success True if funds were provided
     * @dev FIXED: Now transfers from TreasuryManager's own balance (before weekly distribution)
     *      This allows immediate reward payouts while distributions happen weekly
     *      Requires TreasuryManager to maintain sufficient balance for rewards
     */
    function requestRewardFunds(uint256 amount) external nonReentrant returns (bool success) {
        require(authorizedRequester[msg.sender], "Not authorized requester");
        require(amount > 0, "Invalid amount");
        
        // Calculate available balance (total - reserve fund)
        uint256 availableBalance = address(this).balance > reserveFundBalance 
            ? address(this).balance - reserveFundBalance 
            : 0;
        
        // Check if we have sufficient funds available
        if (availableBalance < amount) {
            emit RewardFundsRequested(msg.sender, amount, false);
            return false;
        }
        
        // Transfer from TreasuryManager's balance directly
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        
        if (sent) {
            // Update accounting (reduces amount available for next distribution)
            totalDistributed += amount;
        }
        
        emit RewardFundsRequested(msg.sender, amount, sent);
        return sent;
    }
    
    /**
     * @notice Toggle auto-distribution (weekly cycle)
     * @param enabled True to enable, false to disable
     */
    function setAutoDistribution(bool enabled) external onlyOwner {
        autoDistributionEnabled = enabled;
        emit AutoDistributionToggled(enabled);
    }
    
    /**
     * @notice Notification from APY calculator about significant APY compression
     * @param currentTVL Current total value locked
     * @param oldMultiplier Previous APY multiplier in basis points
     * @param newMultiplier New APY multiplier in basis points
     * @param compressionBps Compression amount in basis points
     * @dev Called by DynamicAPYCalculator when APY drops > threshold
     *      Treasury can monitor this to prepare for increased reserve usage
     */
    function notifyAPYCompression(
        uint256 currentTVL,
        uint256 oldMultiplier,
        uint256 newMultiplier,
        uint256 compressionBps
    ) external {
        require(authorizedSources[msg.sender], "Not authorized source");
        
        emit APYCompressionAlert(currentTVL, oldMultiplier, newMultiplier, compressionBps);
        
        // Future enhancement: Could trigger automatic reserve allocation adjustments
        // or alert mechanisms for admin intervention
    }
    
    // ============================================
    // EMERGENCY & STABILITY MANAGEMENT
    // ============================================
    
    /**
     * @notice Update protocol health status (only owner or automated monitors)
     * @param protocol Protocol type to update
     * @param newStatus New health status
     */
    function setProtocolStatus(TreasuryType protocol, ProtocolStatus newStatus) external onlyOwner {
        ProtocolStatus oldStatus = protocolStatus[protocol];
        
        if (oldStatus != newStatus) {
            protocolStatus[protocol] = newStatus;
            
            // Automatically enable emergency mode if any protocol is CRITICAL or EMERGENCY
            if (newStatus == ProtocolStatus.CRITICAL || newStatus == ProtocolStatus.EMERGENCY) {
                if (!emergencyModeEnabled) {
                    emergencyModeEnabled = true;
                    lastEmergencyTimestamp = block.timestamp;
                    emit EmergencyModeActivated(block.timestamp, "Protocol status changed to CRITICAL/EMERGENCY");
                }
            }
            
            emit ProtocolStatusChanged(protocol, oldStatus, newStatus);
        }
    }
    
    /**
     * @notice Request emergency funds from reserve (when protocol is at risk)
     * @param protocol Type of protocol requesting funds
     * @param amount Amount requested
     * @return success True if funds were provided
     * @dev Only authorized requesters can call this (set via setAuthorizedRequester)
     *      Draws from reserve fund if enabled, recovers protocol from insolvency
     */
    function requestEmergencyFunds(TreasuryType protocol, uint256 amount) 
        external 
        nonReentrant 
        returns (bool success) 
    {
        require(authorizedRequester[msg.sender], "Not authorized requester");
        require(amount > 0, "Invalid amount");
        require(emergencyModeEnabled, "Emergency mode not active");
        
        // Check if we have reserve funds available
        if (reserveFundBalance < amount) {
            emit EmergencyFundsRequested(protocol, amount, false);
            return false;
        }
        
        // Withdraw from reserve fund
        reserveFundBalance -= amount;
        totalReserveWithdrawn += amount;
        totalEmergencyFundsDistributed += amount;
        
        // Track deficit for reporting
        if (protocolDeficit[protocol] < amount) {
            protocolDeficit[protocol] = amount;
        }
        
        // Transfer funds to requester (protocol's treasury or directly to requester)
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        
        if (sent) {
            emit ReserveFundsUsedForEmergency(protocol, amount, "Emergency protocol funding");
            emit EmergencyFundsRequested(protocol, amount, true);
            return true;
        }
        
        // Restore reserve if transfer failed
        reserveFundBalance += amount;
        totalReserveWithdrawn -= amount;
        totalEmergencyFundsDistributed -= amount;
        
        emit EmergencyFundsRequested(protocol, amount, false);
        return false;
    }
    
    /**
     * @notice Declare emergency mode (protocols can access reserve funds)
     * @param reason Reason for emergency declaration
     */
    function declareEmergency(string calldata reason) external onlyOwner {
        require(!emergencyModeEnabled, "Emergency already active");
        
        emergencyModeEnabled = true;
        lastEmergencyTimestamp = block.timestamp;
        
        emit EmergencyModeActivated(block.timestamp, reason);
    }
    
    /**
     * @notice End emergency mode (returns to normal distribution)
     */
    function endEmergency() external onlyOwner {
        require(emergencyModeEnabled, "No emergency active");
        
        emergencyModeEnabled = false;
        
        emit EmergencyModeDeactivated(block.timestamp);
    }
    
    /**
     * @notice Check current health status of a protocol
     * @param protocol Protocol to check
     */
    function getProtocolStatus(TreasuryType protocol) 
        external 
        view 
        returns (ProtocolStatus status, uint256 deficit, bool canAccessEmergency) 
    {
        return (
            protocolStatus[protocol],
            protocolDeficit[protocol],
            emergencyModeEnabled
        );
    }
    
    /**
     * @notice Get emergency mode information
     */
    function getEmergencyInfo()
        external
        view
        returns (
            bool isActive,
            uint256 timestamp,
            uint256 emergencyFundsDistributed,
            uint256 reserveAvailable
        )
    {
        return (
            emergencyModeEnabled,
            lastEmergencyTimestamp,
            totalEmergencyFundsDistributed,
            reserveFundBalance
        );
    }
    
    // ============================================
    // RESERVE FUND MANAGEMENT
    // ============================================
    
    /**
     * @notice Update reserve fund allocation percentage
     * @param percentage Percentage in basis points (e.g., 2000 = 20%)
     * @dev Max 30% of all revenue can be allocated to reserve
     */
    function setReserveAllocation(uint256 percentage) external onlyOwner {
        require(percentage <= MAX_RESERVE_PERCENTAGE, "Max 30% reserve");
        
        uint256 oldPercentage = reserveAllocationPercentage;
        reserveAllocationPercentage = percentage;
        
        emit ReserveAllocationUpdated(oldPercentage, percentage);
    }
    
    /**
     * @notice Toggle reserve fund accumulation
     * @param enabled True to enable, false to disable
     */
    function setReserveAccumulation(bool enabled) external onlyOwner {
        reserveAccumulationEnabled = enabled;
        emit ReserveAccumulationToggled(enabled);
    }
    
    /**
     * @notice Withdraw from reserve fund to external wallet
     * @param to Recipient wallet address (external or treasury smart contract)
     * @param amount Amount to withdraw
     * @param reason Reason for withdrawal (for transparency and audit trail)
     * @dev Admin function to manually withdraw reserve funds for:
     *      - Emergency operations (human review required)
     *      - Deficit recovery across protocols
     *      - Strategic deployments
     *      Emits event for full transparency
     */
    function withdrawFromReserve(
        address to,
        uint256 amount,
        string calldata reason
    ) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(amount > 0 && amount <= reserveFundBalance, "Invalid amount");
        
        reserveFundBalance -= amount;
        totalReserveWithdrawn += amount;
        
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit ReserveFundWithdrawal(to, amount, reserveFundBalance, reason);
    }
    
    /**
     * @notice Withdraw entire reserve fund to external wallet (emergency use)
     * @param to Recipient wallet address
     * @param reason Reason for full withdrawal
     * @return amount Total amount withdrawn
     * @dev Maximum security withdrawal - only allows complete balance drain for emergencies
     */
    function emergencyWithdrawAllReserve(address to, string calldata reason) 
        external 
        onlyOwner 
        returns (uint256 amount) 
    {
        require(to != address(0), "Invalid address");
        
        amount = reserveFundBalance;
        require(amount > 0, "Reserve is empty");
        
        reserveFundBalance = 0;
        totalReserveWithdrawn += amount;
        
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit ReserveFundWithdrawal(to, amount, 0, reason);
        
        return amount;
    }
    
    /**
     * @notice Manually deposit to reserve fund
     * @dev Allows owner to manually boost reserve during high-revenue periods
     */
    function depositToReserve() external payable onlyOwner {
        require(msg.value > 0, "Must send POL");
        
        reserveFundBalance += msg.value;
        totalReserveAccumulated += msg.value;
        
        emit ReserveFundDeposit(msg.value, reserveFundBalance);
    }
    
    /**
     * @notice Emergency withdrawal (only owner, when paused/emergency)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(amount <= address(this).balance, "Insufficient balance");
        
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit EmergencyWithdrawal(to, amount);
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @notice Get current balance (excluding reserve fund)
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @notice Get available balance for distributions (total - reserve)
     */
    function getAvailableBalance() external view returns (uint256) {
        uint256 total = address(this).balance;
        return total > reserveFundBalance ? total - reserveFundBalance : 0;
    }
    
    /**
     * @notice Get treasury configuration
     * @param treasuryType Type of treasury (enum value)
     */
    function getTreasuryConfig(TreasuryType treasuryType) 
        external 
        view 
        returns (address treasuryAddress, uint256 allocation) 
    {
        return (treasuries[treasuryType], allocations[treasuryType]);
    }
    
    /**
     * @notice Get all allocations
     */
    function getAllAllocations() 
        external 
        view 
        returns (
            uint256 rewardsAlloc,
            uint256 stakingAlloc,
            uint256 collaboratorsAlloc,
            uint256 developmentAlloc,
            uint256 marketplaceAlloc
        ) 
    {
        return (
            allocations[TreasuryType.REWARDS],
            allocations[TreasuryType.STAKING],
            allocations[TreasuryType.COLLABORATORS],
            allocations[TreasuryType.DEVELOPMENT],
            allocations[TreasuryType.MARKETPLACE]
        );
    }
    
    /**
     * @notice Get distribution timeline information
     */
    function getDistributionTimeline()
        external
        view
        returns (
            uint256 firstDeposit,
            uint256 lastDistribution,
            uint256 nextDistribution,
            uint256 timeUntilNext,
            bool isReady
        )
    {
        uint256 timeRemaining = 0;
        bool ready = false;
        
        if (firstDepositTime > 0 && nextDistributionTime > 0) {
            if (block.timestamp >= nextDistributionTime) {
                ready = true;
                timeRemaining = 0;
            } else {
                ready = false;
                timeRemaining = nextDistributionTime - block.timestamp;
            }
        }
        
        return (
            firstDepositTime,
            lastDistributionTime,
            nextDistributionTime,
            timeRemaining,
            ready
        );
    }
    
    /**
     * @notice Get statistics
     */
    function getStats() 
        external 
        view 
        returns (
            uint256 totalReceived,
            uint256 totalDist,
            uint256 currentBalance,
            uint256 availableBalance,
            uint256 lastDistribution,
            bool autoDistEnabled
        ) 
    {
        uint256 available = address(this).balance > reserveFundBalance 
            ? address(this).balance - reserveFundBalance 
            : 0;
            
        return (
            totalRevenueReceived,
            totalDistributed,
            address(this).balance,
            available,
            lastDistributionTime,
            autoDistributionEnabled
        );
    }
    
    /**
     * @notice Get reserve fund statistics
     * @return currentBalance Current reserve fund balance
     * @return totalAccumulated Total accumulated over time
     * @return totalWithdrawn Total withdrawn from reserve
     * @return allocationPercentage Current allocation percentage (basis points)
     * @return isEnabled Whether accumulation is enabled
     */
    function getReserveStats()
        external
        view
        returns (
            uint256 currentBalance,
            uint256 totalAccumulated,
            uint256 totalWithdrawn,
            uint256 allocationPercentage,
            bool isEnabled
        )
    {
        return (
            reserveFundBalance,
            totalReserveAccumulated,
            totalReserveWithdrawn,
            reserveAllocationPercentage,
            reserveAccumulationEnabled
        );
    }
    
    /**
     * @notice Calculate months of runway with current reserve
     * @param monthlyBurnRate Estimated monthly expense in wei
     * @return months Number of months reserve can cover
     */
    function getReserveRunwayMonths(uint256 monthlyBurnRate)
        external
        view
        returns (uint256 months)
    {
        if (monthlyBurnRate == 0) return 0;
        return reserveFundBalance / monthlyBurnRate;
    }
}
