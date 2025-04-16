// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title NUVOS Token
 * @dev Implementation of the NUVOS ERC20 token with a maximum supply of 21 million tokens.
 * 1 million tokens are minted to the deployer at deployment.
 * The contract owner can mint additional tokens up to the maximum supply.
 * The contract will burn tokens to reduce supply to 10M tokens (burning 11M tokens).
 */
contract NUVOToken is ERC20Capped, Ownable, ReentrancyGuard {
    // Events
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    
    // Constants
    uint256 private constant MAX_SUPPLY = 21_000_000 * 10**18; // 21 million tokens with 18 decimals
    uint256 private constant INITIAL_SUPPLY = 1_000_000 * 10**18; // 1 million tokens with 18 decimals
    uint256 private constant FINAL_SUPPLY = 10_000_000 * 10**18; // 10 million final supply after burning
    
    // Total burned tokens
    uint256 public totalBurnedTokens = 0;
    uint256 public constant BURN_TARGET = 11_000_000 * 10**18; // 11 million tokens to burn

    /**
     * @dev Constructor that gives the msg.sender the initial tokens.
     */
    constructor(address initialOwner) 
        ERC20("NUVOS", "NUVOS") 
        ERC20Capped(MAX_SUPPLY)
        Ownable() // Remove the initialOwner parameter
    {
        // Transfer ownership to initialOwner if it's not the message sender
        if (initialOwner != msg.sender) {
            _transferOwnership(initialOwner);
        }
        
        _mint(initialOwner, INITIAL_SUPPLY);
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     * Can only be called by the contract owner.
     * Cannot exceed the max supply of 21 million tokens.
     * 
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner nonReentrant {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Returns the number of tokens that can still be minted.
     */
    function remainingMintableSupply() public view returns (uint256) {
        return cap() - totalSupply();
    }

    /**
     * @dev Returns the number of tokens that should still be burned to reach the final supply.
     */
    function remainingToBurn() public view returns (uint256) {
        if (totalBurnedTokens >= BURN_TARGET) {
            return 0;
        }
        return BURN_TARGET - totalBurnedTokens;
    }

    /**
     * @dev Returns the burn progress as a percentage (0-100)
     */
    function burnProgress() public view returns (uint256) {
        return totalBurnedTokens * 100 / BURN_TARGET;
    }

    /**
     * @dev Burns a specific amount of tokens from the message sender.
     * @param amount The amount of token to be burned
     */
    function burn(uint256 amount) external {
        // Check that the sender has enough tokens to burn
        require(balanceOf(_msgSender()) >= amount, "ERC20: burn amount exceeds balance");
        
        _burn(_msgSender(), amount);
        totalBurnedTokens += amount;
        emit TokensBurned(_msgSender(), amount);
    }

    /**
     * @dev Burns a specific amount of tokens from the specified account.
     * The caller must have allowance for the account's tokens.
     * @param account The account whose tokens will be burned
     * @param amount The amount of token to be burned
     */
    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: insufficient allowance");
        
        // Check that the account has enough tokens to burn
        require(balanceOf(account) >= amount, "ERC20: burn amount exceeds balance");
        
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
        totalBurnedTokens += amount;
        emit TokensBurned(account, amount);
    }

    /**
     * @dev Returns the target final supply after burning
     */
    function targetSupply() public pure returns (uint256) {
        return FINAL_SUPPLY;
    }

    /**
     * @dev Returns the current burn target
     */
    function getBurnTarget() public pure returns (uint256) {
        return BURN_TARGET;
    }

    /**
     * @dev Returns detailed statistics about token supply and burning
     */
    function getTokenStats() external view returns (
        uint256 maxSupply,
        uint256 currentSupply,
        uint256 targetFinalSupply,
        uint256 totalBurned,
        uint256 burnTarget,
        uint256 currentBurnProgress,
        uint256 currentRemainingToBurn
    ) {
        uint256 progress = 0;
        if (totalBurnedTokens > 0) {
            progress = totalBurnedTokens * 100 / BURN_TARGET;
        }
        
        uint256 remaining = 0;
        if (totalBurnedTokens < BURN_TARGET) {
            remaining = BURN_TARGET - totalBurnedTokens;
        }
        
        return (
            MAX_SUPPLY,
            totalSupply(),
            FINAL_SUPPLY,
            totalBurnedTokens,
            BURN_TARGET,
            progress,
            remaining
        );
    }
}