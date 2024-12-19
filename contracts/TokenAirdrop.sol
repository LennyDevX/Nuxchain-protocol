// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenAirdrop is ReentrancyGuard, Pausable {
    IERC20 public immutable token;
    address public owner;
    uint256 public tokenAmount;
    uint256 public startDate;
    uint256 public endDate;
    uint256 public totalParticipants;
    uint256 public maxParticipants;
    uint256 public constant MAX_BATCH_SIZE = 100;
    uint256 public constant MIN_TOKEN_BALANCE = 1e18; // 1 token minimum
    
    mapping(address => bool) public hasClaimed;
    
    event TokensClaimed(address indexed user, uint256 amount);
    event AirdropConfigured(uint256 startDate, uint256 endDate, uint256 amount);
    event AirdropFunded(uint256 amount);
    event EmergencyWithdrawal(uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor(
        address _token,
        uint256 _maxParticipants
    ) {
        token = IERC20(_token);
        owner = msg.sender;
        maxParticipants = _maxParticipants;
    }
    
    function configureAirdrop(
        uint256 _startDate,
        uint256 _endDate,
        uint256 _tokenAmount
    ) external onlyOwner {
        require(_startDate > block.timestamp, "Start must be future");
        require(_endDate > _startDate, "End after start");
        require(_tokenAmount > 0, "Amount > 0");
        
        startDate = _startDate;
        endDate = _endDate;
        tokenAmount = _tokenAmount;
        
        emit AirdropConfigured(_startDate, _endDate, _tokenAmount);
    }
    
    function claimTokens() external nonReentrant whenNotPaused {
        require(block.timestamp >= startDate, "Not started");
        require(block.timestamp <= endDate, "Ended");
        require(!hasClaimed[msg.sender], "Already claimed");
        require(isEligible(msg.sender), "Not eligible");
        require(totalParticipants < maxParticipants, "Max reached");
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient funds");
        
        hasClaimed[msg.sender] = true;
        totalParticipants++;
        
        require(token.transfer(msg.sender, tokenAmount), "Transfer failed");
        emit TokensClaimed(msg.sender, tokenAmount);
    }

    function batchClaim(address[] calldata users) external onlyOwner {
        require(users.length <= MAX_BATCH_SIZE, "Batch too large");
        uint256 totalAmount = tokenAmount * users.length;
        require(token.balanceOf(address(this)) >= totalAmount, "Insufficient funds");
        
        for(uint256 i = 0; i < users.length; i++) {
            if(!hasClaimed[users[i]] && isEligible(users[i])) {
                hasClaimed[users[i]] = true;
                totalParticipants++;
                require(token.transfer(users[i], tokenAmount), "Transfer failed");
                emit TokensClaimed(users[i], tokenAmount);
            }
        }
    }
    
    function isEligible(address _user) public view returns (bool) {
        return token.balanceOf(_user) >= MIN_TOKEN_BALANCE;
    }
    
    function getAirdropInfo() external view returns (
        uint256 remainingTokens,
        uint256 claimed,
        bool active,
        bool canClaim
    ) {
        remainingTokens = token.balanceOf(address(this));
        claimed = totalParticipants;
        active = block.timestamp >= startDate && block.timestamp <= endDate;
        canClaim = active && 
                  !hasClaimed[msg.sender] && 
                  isEligible(msg.sender) &&
                  totalParticipants < maxParticipants;
    }
    
    function fundAirdrop(uint256 amount) external {
        require(amount > 0, "Amount > 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit AirdropFunded(amount);
    }
    
    function withdrawTokens() external onlyOwner {
        require(block.timestamp > endDate, "Not ended");
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(owner, balance), "Transfer failed");
        emit EmergencyWithdrawal(balance);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
}
