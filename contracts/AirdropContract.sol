// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Airdrop is ReentrancyGuard, Pausable, IERC721Receiver {
    enum AirdropType { MATIC, ERC20, NFT }

    struct AirdropConfig {
        AirdropType airdropType;
        address tokenAddress;
        uint256 tokenAmount;
        uint256 startDate;
        uint256 endDate;
        bool isConfigured;
        string description;
    }

    error AirdropActive();
    error InvalidDates();
    error StartDateMustBeFuture();
    error NotEligible();
    error AlreadyClaimed(); 
    error TransferFailed();
    error CallerNotOwner();
    error InsufficientContractBalance();
    error AirdropNotFunded();
    error InvalidAmount();
    error TransferLimitExceeded();
    error UnsupportedAirdropType();
    error InvalidTokenAddress();
    error AirdropNotConfigured();
    error AirdropInactive();

    address public owner;
    uint256 public totalParticipants;
    uint256 public maxParticipants;
    uint256 public constant MIN_BALANCE = 1 ether;
    
    AirdropConfig public currentAirdrop;
    mapping(address => bool) public hasClaimed;
    mapping(uint256 => bool) public nftClaimed;
    uint256[] public availableNFTs;

    // Add mapping for whitelisted contracts
    mapping(address => bool) public whitelistedContracts;
    
    event TokensClaimed(address indexed user, uint256 amount);
    event NFTClaimed(address indexed user, uint256 tokenId);
    event AirdropConfigured(AirdropType airdropType, address tokenAddress, uint256 amount, string description);
    event FundsReceived(address indexed from, uint256 amount);
    event EmergencyWithdrawal(address indexed token, uint256 amount);
    // Add event for contract whitelisting
    event ContractWhitelisted(address indexed contractAddress, bool status);
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert CallerNotOwner();
        _;
    }
    
    constructor(uint256 _maxParticipants) {
        owner = msg.sender;
        maxParticipants = _maxParticipants;
    }
    
    function configureAirdrop(
        AirdropType _type,
        address _tokenAddress,
        uint256 _amount,
        uint256 _startDate,
        uint256 _endDate,
        string calldata _description
    ) external onlyOwner {
        if (_startDate >= _endDate) revert InvalidDates();
        if (_startDate <= block.timestamp) revert StartDateMustBeFuture();
        if (_type != AirdropType.MATIC && _tokenAddress == address(0)) revert InvalidTokenAddress();
        
        // Reset claims for new airdrop
        delete currentAirdrop;
        totalParticipants = 0;
        
        currentAirdrop = AirdropConfig({
            airdropType: _type,
            tokenAddress: _tokenAddress,
            tokenAmount: _amount,
            startDate: _startDate,
            endDate: _endDate,
            isConfigured: true,
            description: _description
        });
        
        emit AirdropConfigured(_type, _tokenAddress, _amount, _description);
    }
    
    function claim() external nonReentrant whenNotPaused {
        // Move state checks after nonReentrant modifier (which is already at the top)
        if (!currentAirdrop.isConfigured) revert AirdropNotConfigured();
        if (!isActive()) revert AirdropInactive();
        if (!isEligible(msg.sender)) revert NotEligible();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (totalParticipants >= maxParticipants) revert TransferLimitExceeded();

        // Update state
        hasClaimed[msg.sender] = true;
        totalParticipants++;

        // Handle claim based on type
        if (currentAirdrop.airdropType == AirdropType.MATIC) {
            _claimMatic();
        } else if (currentAirdrop.airdropType == AirdropType.ERC20) {
            _claimERC20();
        } else if (currentAirdrop.airdropType == AirdropType.NFT) {
            _claimNFT();
        } else {
            revert UnsupportedAirdropType();
        }
    }

    function _claimMatic() private {
        if (!hasSufficientFunds()) revert InsufficientContractBalance();
        uint256 amountToSend = currentAirdrop.tokenAmount;
        
        // External call last (CEI pattern)
        (bool success, ) = msg.sender.call{value: amountToSend}("");
        if (!success) revert TransferFailed();
        
        emit TokensClaimed(msg.sender, amountToSend);
    }

    function _claimERC20() private {
        IERC20 token = IERC20(currentAirdrop.tokenAddress);
        if (token.balanceOf(address(this)) < currentAirdrop.tokenAmount) 
            revert InsufficientContractBalance();
        if (!token.transfer(msg.sender, currentAirdrop.tokenAmount)) 
            revert TransferFailed();
        emit TokensClaimed(msg.sender, currentAirdrop.tokenAmount);
    }

    function _claimNFT() private {
        if (availableNFTs.length == 0) revert InsufficientContractBalance();
        uint256 tokenId = availableNFTs[availableNFTs.length - 1];
        availableNFTs.pop();
        
        IERC721 nft = IERC721(currentAirdrop.tokenAddress);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        nftClaimed[tokenId] = true;
        emit NFTClaimed(msg.sender, tokenId);
    }

    function depositNFTs(uint256[] calldata tokenIds) external {
        require(currentAirdrop.airdropType == AirdropType.NFT, "Not NFT airdrop");
        IERC721 nft = IERC721(currentAirdrop.tokenAddress);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nft.safeTransferFrom(msg.sender, address(this), tokenIds[i]);
            availableNFTs.push(tokenIds[i]);
        }
    }

    // Add whitelisting function
    function whitelistContract(address _contract, bool _status) external onlyOwner {
        whitelistedContracts[_contract] = _status;
        emit ContractWhitelisted(_contract, _status);
    }

    // Modify isEligible function to include whitelisted contracts
    function isEligible(address _address) public view returns (bool) {
        if (whitelistedContracts[_address]) return true;
        return tx.origin == msg.sender && !Address.isContract(_address);
    }

    function batchClaim(address[] calldata users) external onlyOwner {
        require(users.length <= 100, "Batch too large");
        for(uint i = 0; i < users.length; i++) {
            if(!hasClaimed[users[i]] && isEligible(users[i])) {
                hasClaimed[users[i]] = true;
                (bool success, ) = users[i].call{value: currentAirdrop.tokenAmount}("");
                if(success) {
                    emit TokensClaimed(users[i], currentAirdrop.tokenAmount);
                }
            }
        }
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function hasSufficientFunds() public view returns (bool) {
        uint256 balance = getContractBalance();
        uint256 requiredBalance = currentAirdrop.tokenAmount; // Solo necesitamos fondos para el siguiente claim
        return balance >= requiredBalance;
    }

    function checkUserEligibility(address user) external view returns (
        bool isEligible_,
        bool hasClaimed_,
        bool hasMinBalance_,
        uint256 userBalance
    ) {
        isEligible_ = isEligible(user);
        hasClaimed_ = hasClaimed[user];
        userBalance = address(user).balance;

        // Adjust MIN_CONTRACT_BALANCE for testing if needed
        hasMinBalance_ = userBalance >= MIN_BALANCE;
    }

    function getAirdropStats() external view returns (
        uint256 remainingTokens,
        uint256 claimedCount,
        uint256 remainingTime,
        bool isAirdropActive,
        bool isFunded
    ) {
        remainingTokens = getContractBalance();
        claimedCount = totalParticipants;
        remainingTime = block.timestamp < currentAirdrop.endDate ? currentAirdrop.endDate - block.timestamp : 0;
        isAirdropActive = isActive();
        isFunded = remainingTokens >= currentAirdrop.tokenAmount;
        return (remainingTokens, claimedCount, remainingTime, isAirdropActive, isFunded);
    }

    function emergencyWithdraw(address token_) external onlyOwner whenPaused {
        if (isActive()) revert AirdropActive();
        uint256 balance;
        bool success;
        
        if (token_ == address(0)) {
            balance = address(this).balance;
            // Use payable(owner) to ensure the owner address is payable
            (success, ) = payable(owner).call{value: balance}("");
        } else {
            IERC20 otherToken = IERC20(token_);
            balance = otherToken.balanceOf(address(this));
            // Use safe transfer for ERC20 tokens
            success = otherToken.transfer(owner, balance);
        }
        
        // Replace custom error with require statement
        require(success, "Transfer failed");
        emit EmergencyWithdrawal(token_, balance);
    }

    function setMaxParticipants(uint256 _maxParticipants) external onlyOwner {
        maxParticipants = _maxParticipants;
    }

    function isActive() public view returns (bool) {
        return block.timestamp >= currentAirdrop.startDate && block.timestamp <= currentAirdrop.endDate;
    }

    // Function to fund the contract
    function fundContract() external payable {
        if (msg.value == 0) revert InvalidAmount();
        emit FundsReceived(msg.sender, msg.value);
    }

    // Fallback function - Called on plain Ether transfer
    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    // Fallback function - Called when no other function matches
    fallback() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function getAirdropInfo() external view returns (
        AirdropType airdropType,
        address tokenAddress,
        uint256 tokenAmount,
        uint256 startDate,
        uint256 endDate,
        string memory description,
        uint256 remainingTokens,
        uint256 claimedCount,
        bool isActive_,
        bool canClaim
    ) {
        airdropType = currentAirdrop.airdropType;
        tokenAddress = currentAirdrop.tokenAddress;
        tokenAmount = currentAirdrop.tokenAmount;
        startDate = currentAirdrop.startDate;
        endDate = currentAirdrop.endDate;
        description = currentAirdrop.description;
        
        if (currentAirdrop.airdropType == AirdropType.MATIC) {
            remainingTokens = address(this).balance;
        } else if (currentAirdrop.airdropType == AirdropType.ERC20) {
            remainingTokens = IERC20(tokenAddress).balanceOf(address(this));
        } else {
            remainingTokens = availableNFTs.length;
        }
        
        claimedCount = totalParticipants;
        isActive_ = isActive();
        canClaim = isActive_ && !hasClaimed[msg.sender] && isEligible(msg.sender);
    }
}