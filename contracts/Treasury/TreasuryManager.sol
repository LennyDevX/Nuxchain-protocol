// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ITreasuryManager.sol";

/**
 * @title TreasuryManager
 * @notice Centralizes all protocol revenue streams and distributes to specialized treasuries
 * @dev Receives commissions from Staking (6%), Marketplace (5%), Individual Skills sales, and distributes automatically
 * 
 * RESERVE FUND SYSTEM:
 * - Automatically allocates a percentage of revenue to emergency reserve
 * - Reserve provides 6-12 month buffer for volatility protection
 * - Can be withdrawn by owner during deficit periods or emergencies
 * - Helps maintain protocol sustainability during low-revenue periods
 */
contract TreasuryManager is Ownable, ReentrancyGuard, ITreasuryManager {
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    /// @notice Minimum interval between manual distributions (1 hour)
    uint256 private constant MIN_DISTRIBUTION_INTERVAL = 1 hours;
    
    /// @notice Minimum balance to trigger auto-distribution (1 POL)
    uint256 private constant MIN_AUTO_DISTRIBUTION = 1 ether;
    
    /// @notice Default reserve fund allocation (10% of incoming revenue)
    uint256 private constant DEFAULT_RESERVE_PERCENTAGE = 1000; // 10% in basis points
    
    /// @notice Basis points constant
    uint256 private constant BASIS_POINTS = 10000;
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /// @notice Treasury addresses for different purposes
    mapping(string => address) public treasuries;
    
    /// @notice Allocation percentages (in basis points, 10000 = 100%)
    mapping(string => uint256) public allocations;
    
    /// @notice Total revenue received
    uint256 public totalRevenueReceived;
    
    /// @notice Total distributed to treasuries
    uint256 public totalDistributed;
    
    /// @notice Last distribution timestamp
    uint256 public lastDistributionTime;
    
    /// @notice Auto-distribution enabled
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
    // EVENTS
    // ============================================
    
    event RevenueReceived(address indexed source, uint256 amount, string revenueType);
    event RevenueDistributed(string indexed treasuryType, address indexed treasuryAddress, uint256 amount);
    event RewardFundsRequested(address indexed requester, uint256 amount, bool success);
    event TreasuryUpdated(string indexed treasuryType, address indexed oldAddress, address indexed newAddress);
    event AllocationUpdated(string indexed treasuryType, uint256 oldPercentage, uint256 newPercentage);
    event SourceAuthorized(address indexed source, bool authorized);
    event RequesterAuthorized(address indexed requester, bool authorized);
    event AutoDistributionToggled(bool enabled);
    event EmergencyWithdrawal(address indexed to, uint256 amount);
    event ReserveFundDeposit(uint256 amount, uint256 newBalance);
    event ReserveFundWithdrawal(address indexed to, uint256 amount, uint256 remainingBalance, string reason);
    event ReserveAllocationUpdated(uint256 oldPercentage, uint256 newPercentage);
    event ReserveAccumulationToggled(bool enabled);
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        // Default allocations (can be changed by owner)
        allocations["rewards"] = 3000;      // 30% - Quest/Achievement/Level-up rewards
        allocations["staking"] = 3500;      // 35% - Staking operations & sustainability
        allocations["collaborators"] = 2000;// 20% - Collaborator badge holder rewards (passive income)
        allocations["development"] = 1500;  // 15% - Protocol development & maintenance
        
        // Initialize reserve fund system
        reserveAllocationPercentage = DEFAULT_RESERVE_PERCENTAGE; // 10%
        reserveAccumulationEnabled = true;
        
        autoDistributionEnabled = true;
        lastDistributionTime = block.timestamp;
    }
    
    // ============================================
    // RECEIVE FUNCTIONS
    // ============================================
    
    /**
     * @notice Receive POL and auto-distribute if enabled
     */
    receive() external payable {
        totalRevenueReceived += msg.value;
        
        emit RevenueReceived(msg.sender, msg.value, "direct");
        
        // Auto-distribute if enabled and threshold met
        if (autoDistributionEnabled && address(this).balance >= MIN_AUTO_DISTRIBUTION) {
            _distributeRevenue();
        }
    }
    
    /**
     * @notice Receive revenue with type label (from authorized sources)
     * @param revenueType Type of revenue ("staking_commission", "marketplace_fee", "skill_fee", etc.)
     */
    function receiveRevenue(string calldata revenueType) external payable {
        require(authorizedSources[msg.sender], "Not authorized source");
        
        totalRevenueReceived += msg.value;
        
        emit RevenueReceived(msg.sender, msg.value, revenueType);
        
        // Auto-distribute if enabled and threshold met
        if (autoDistributionEnabled && address(this).balance >= MIN_AUTO_DISTRIBUTION) {
            _distributeRevenue();
        }
    }
    
    // ============================================
    // DISTRIBUTION FUNCTIONS
    // ============================================
    
    /**
     * @notice Manually trigger revenue distribution
     */
    function distributeRevenue() external nonReentrant {
        require(
            block.timestamp >= lastDistributionTime + MIN_DISTRIBUTION_INTERVAL,
            "Distribution too frequent"
        );
        
        _distributeRevenue();
    }
    
    /**
     * @notice Internal distribution logic with reserve fund accumulation
     * @dev First allocates to reserve fund, then distributes remaining to treasuries
     */
    function _distributeRevenue() internal {
        uint256 balance = address(this).balance;
        if (balance == 0) return;
        
        uint256 distribuTable = balance;
        
        // Step 1: Allocate to reserve fund if enabled
        if (reserveAccumulationEnabled && reserveAllocationPercentage > 0) {
            uint256 reserveAmount = (balance * reserveAllocationPercentage) / BASIS_POINTS;
            if (reserveAmount > 0) {
                reserveFundBalance += reserveAmount;
                totalReserveAccumulated += reserveAmount;
                distribuTable -= reserveAmount;
                
                emit ReserveFundDeposit(reserveAmount, reserveFundBalance);
            }
        }
        
        // Step 2: Distribute remaining balance to treasuries
        _distributeTo("rewards", distribuTable);
        _distributeTo("staking", distribuTable);
        _distributeTo("marketplace", distribuTable);
        _distributeTo("development", distribuTable);
        _distributeTo("collaborators", distribuTable);
        
        lastDistributionTime = block.timestamp;
    }
    
    /**
     * @notice Distribute to specific treasury
     */
    function _distributeTo(string memory treasuryType, uint256 totalBalance) internal {
        address treasuryAddr = treasuries[treasuryType];
        uint256 allocation = allocations[treasuryType];
        
        if (treasuryAddr == address(0) || allocation == 0) return;
        
        uint256 amount = (totalBalance * allocation) / 10000;
        if (amount == 0) return;
        
        totalDistributed += amount;
        
        (bool success, ) = payable(treasuryAddr).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit RevenueDistributed(treasuryType, treasuryAddr, amount);
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    /**
     * @notice Set treasury address for a specific type
     * @param treasuryType Type of treasury ("rewards", "staking", "marketplace", "development")
     * @param treasuryAddress Address of the treasury
     */
    function setTreasury(string calldata treasuryType, address treasuryAddress) external onlyOwner {
        require(treasuryAddress != address(0), "Invalid address");
        
        address oldAddress = treasuries[treasuryType];
        treasuries[treasuryType] = treasuryAddress;
        
        emit TreasuryUpdated(treasuryType, oldAddress, treasuryAddress);
    }
    
    /**
     * @notice Update allocation percentage for a treasury type
     * @param treasuryType Type of treasury
     * @param percentage Percentage in basis points (10000 = 100%)
     */
    function setAllocation(string calldata treasuryType, uint256 percentage) external onlyOwner {
        require(percentage <= 10000, "Exceeds 100%");
        
        // Verify total doesn't exceed 100%
        uint256 total = percentage;
        string[5] memory types = ["rewards", "staking", "marketplace", "development", "collaborators"];
        
        for (uint256 i = 0; i < types.length; i++) {
            if (keccak256(bytes(types[i])) != keccak256(bytes(treasuryType))) {
                total += allocations[types[i]];
            }
        }
        
        require(total <= 10000, "Total allocation exceeds 100%");
        
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
     * @notice Request funds from rewards pool (only authorized contracts)
     * @param amount Amount requested
     * @return success True if funds were provided
     */
    function requestRewardFunds(uint256 amount) external returns (bool success) {
        require(authorizedRequester[msg.sender], "Not authorized requester");
        require(amount > 0, "Invalid amount");
        
        address rewardsTreasury = treasuries["rewards"];
        
        // Check if rewards treasury has sufficient balance
        if (rewardsTreasury == address(0)) {
            emit RewardFundsRequested(msg.sender, amount, false);
            return false;
        }
        
        // Try to transfer from rewards treasury to requester
        if (rewardsTreasury.balance >= amount) {
            // Note: This requires rewards treasury to be a contract that can transfer
            // Or we hold rewards in this contract and transfer directly
            (bool sent, ) = payable(msg.sender).call{value: amount}("");
            
            emit RewardFundsRequested(msg.sender, amount, sent);
            return sent;
        }
        
        emit RewardFundsRequested(msg.sender, amount, false);
        return false;
    }
    
    /**
     * @notice Toggle auto-distribution
     * @param enabled True to enable, false to disable
     */
    function setAutoDistribution(bool enabled) external onlyOwner {
        autoDistributionEnabled = enabled;
        emit AutoDistributionToggled(enabled);
    }
    
    // ============================================
    // RESERVE FUND MANAGEMENT
    // ============================================
    
    /**
     * @notice Update reserve fund allocation percentage
     * @param percentage Percentage in basis points (e.g., 1000 = 10%)
     */
    function setReserveAllocation(uint256 percentage) external onlyOwner {
        require(percentage <= 3000, "Max 30% reserve"); // Cap at 30%
        
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
     * @notice Withdraw from reserve fund (emergency/deficit situations)
     * @param to Recipient address
     * @param amount Amount to withdraw
     * @param reason Reason for withdrawal (for transparency)
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
     * @notice Get current balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @notice Get treasury configuration
     */
    function getTreasuryConfig(string calldata treasuryType) 
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
            uint256 marketplaceAlloc,
            uint256 developmentAlloc,
            uint256 collaboratorsAlloc
        ) 
    {
        return (
            allocations["rewards"],
            allocations["staking"],
            allocations["marketplace"],
            allocations["development"],
            allocations["collaborators"]
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
            uint256 lastDistribution,
            bool autoDistEnabled
        ) 
    {
        return (
            totalRevenueReceived,
            totalDistributed,
            address(this).balance,
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
