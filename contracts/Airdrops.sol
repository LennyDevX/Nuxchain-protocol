// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IERC20
 * @dev Minimal interface for ERC20 tokens.
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title Ownable
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 */
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @title Airdrop
 * @dev A simple contract for handling token airdrops.
 * Users register during a specific period and can claim their tokens after.
 */
contract Airdrop is Ownable {
    IERC20 public immutable token;
    uint256 public immutable registrationEndTime;
    uint256 public immutable claimStartTime;
    uint256 public immutable airdropAmount;
    uint256 public registeredUserCount;

    mapping(address => bool) public isRegistered;
    mapping(address => bool) public hasClaimed;

    event UserRegistered(address indexed user);
    event TokensClaimed(address indexed user, uint256 amount);
    event TokensWithdrawn(address indexed owner, uint256 amount);

    /**
     * @dev Sets up the airdrop contract.
     * @param _token The address of the ERC20 token to be distributed.
     * @param _registrationDuration The duration of the registration period in seconds.
     * @param _claimDelay The delay in seconds after registration ends before claiming can start.
     * @param _amountPerUser The amount of tokens each user will receive.
     */
    constructor(
        address _token,
        uint256 _registrationDuration,
        uint256 _claimDelay,
        uint256 _amountPerUser
    ) {
        require(_token != address(0), "Airdrop: Token address cannot be zero");
        require(_amountPerUser > 0, "Airdrop: Airdrop amount must be greater than zero");

        token = IERC20(_token);
        registrationEndTime = block.timestamp + _registrationDuration;
        claimStartTime = registrationEndTime + _claimDelay;
        airdropAmount = _amountPerUser;
    }

    /**
     * @dev Allows a user to register for the airdrop.
     * Registration is only possible before the registration end time.
     */
    function register() external {
        require(block.timestamp < registrationEndTime, "Airdrop: Registration period has ended");
        require(!isRegistered[msg.sender], "Airdrop: User already registered");

        isRegistered[msg.sender] = true;
        registeredUserCount++;
        emit UserRegistered(msg.sender);
    }

    /**
     * @dev Allows a registered user to claim their tokens.
     * Claiming is only possible after the claim start time.
     */
    function claim() external {
        require(block.timestamp >= claimStartTime, "Airdrop: Claim period has not started yet");
        require(isRegistered[msg.sender], "Airdrop: User is not registered");
        require(!hasClaimed[msg.sender], "Airdrop: Tokens already claimed");

        hasClaimed[msg.sender] = true;

        // It's good practice to check contract balance, though the user's claim will fail anyway if insufficient.
        require(token.balanceOf(address(this)) >= airdropAmount, "Airdrop: Insufficient token balance in contract");
        bool sent = token.transfer(msg.sender, airdropAmount);
        require(sent, "Airdrop: Token transfer failed");

        emit TokensClaimed(msg.sender, airdropAmount);
    }

    /**
     * @dev Allows the owner to withdraw remaining tokens from the contract.
     * This is useful to recover tokens that were not claimed.
     * It's recommended to call this after a reasonable time has passed since the claim period started.
     */
    function withdrawRemainingTokens() external onlyOwner {
        uint256 remainingBalance = token.balanceOf(address(this));
        if (remainingBalance > 0) {
            bool sent = token.transfer(owner(), remainingBalance);
            require(sent, "Airdrop: Withdrawal transfer failed");
            emit TokensWithdrawn(owner(), remainingBalance);
        }
    }
}
// }
//         // This function is a placeholder for a more complex deposit logic if needed.
//         // For this simple airdrop, the admin can just transfer tokens to the contract address.
//         // The most important thing is that the contract has the tokens.
//         // Let's simplify and assume the owner just transfers tokens.
//         // A function to check balance and emit an event is still useful.
//         // This is a conceptual deposit. The actual token transfer must happen outside.
//         // A better implementation would be to pull tokens.
//         // Let's add a require to ensure tokens were actually sent.
//         // This function is not standard, usually owner just sends tokens.
//         // Let's remove it to keep it simple and secure, as per the user's manual funding flow.
//         // The `withdrawRemainingTokens` is sufficient for owner operations.
//     }


//     /**
//      * @dev Allows the owner to withdraw remaining tokens from the contract.
//      * This is useful to recover tokens that were not claimed.
//      * It's recommended to call this after a reasonable time has passed since the claim period started.
//      */
//     function withdrawRemainingTokens() external onlyOwner {
//         uint256 remainingBalance = token.balanceOf(address(this));
//         if (remainingBalance > 0) {
//             bool sent = token.transfer(owner(), remainingBalance);
//             require(sent, "Airdrop: Withdrawal transfer failed");
//             emit TokensWithdrawn(owner(), remainingBalance);
//         }
//     }
// }

