// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title MinerBotToken
 * @dev Token principal del ecosistema MinerBot Empire
 * 
 * Tokenomics:
 * - Supply total: 1,000,000,000 MBT
 * - Distribución:
 *   * 40% - Recompensas de juego (400M)
 *   * 25% - Staking y liquidez (250M)
 *   * 15% - Equipo y desarrollo (150M) - Vesting 24 meses
 *   * 10% - Marketing y partnerships (100M)
 *   * 5% - Reserva del tesoro (50M)
 *   * 3% - Airdrops y eventos (30M)
 *   * 2% - Advisors (20M) - Vesting 12 meses
 * 
 * Características:
 * - Mecanismo de quema deflacionario
 * - Staking con recompensas
 * - Anti-whale protection
 * - Pausable para emergencias
 */
contract MinerBotToken is ERC20, ERC20Burnable, Pausable, Ownable, ReentrancyGuard {

    // Constantes de tokenomics
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1B tokens
    uint256 public constant GAME_REWARDS_ALLOCATION = 400_000_000 * 10**18; // 40%
    uint256 public constant STAKING_ALLOCATION = 250_000_000 * 10**18; // 25%
    uint256 public constant TEAM_ALLOCATION = 150_000_000 * 10**18; // 15%
    uint256 public constant MARKETING_ALLOCATION = 100_000_000 * 10**18; // 10%
    uint256 public constant TREASURY_ALLOCATION = 50_000_000 * 10**18; // 5%
    uint256 public constant AIRDROP_ALLOCATION = 30_000_000 * 10**18; // 3%
    uint256 public constant ADVISOR_ALLOCATION = 20_000_000 * 10**18; // 2%

    // Direcciones de distribución
    address public gameRewardsWallet;
    address public stakingContract;
    address public teamWallet;
    address public marketingWallet;
    address public treasuryWallet;
    address public airdropWallet;
    address public advisorWallet;

    // Vesting
    uint256 public teamVestingStart;
    uint256 public advisorVestingStart;
    uint32 public constant TEAM_VESTING_DURATION = 24 * 30 days; // 24 meses
    uint32 public constant ADVISOR_VESTING_DURATION = 12 * 30 days; // 12 meses
    
    uint256 public teamTokensReleased;
    uint256 public advisorTokensReleased;

    // Anti-whale protection
    uint256 public maxTransactionAmount = 5_000_000 * 10**18; // 0.5% del supply
    uint256 public maxWalletAmount = 10_000_000 * 10**18; // 1% del supply
    mapping(address => bool) public isExcludedFromLimits;

    // Burn tracking
    uint256 public totalBurned;
    
    // Game contract authorization
    mapping(address => bool) public authorizedGameContracts;

    // Events
    event TokensVested(address indexed beneficiary, uint256 amount, string vestingType);
    event GameContractAuthorized(address indexed gameContract, bool authorized);
    event LimitsUpdated(uint256 maxTransaction, uint256 maxWallet);
    event TokensBurned(uint256 amount, address indexed burner);

    modifier onlyAuthorizedGame() {
        require(authorizedGameContracts[msg.sender], "MBT: Not authorized game contract");
        _;
    }

    constructor(
        address _gameRewardsWallet,
        address _teamWallet,
        address _marketingWallet,
        address _treasuryWallet,
        address _airdropWallet,
        address _advisorWallet
    ) ERC20("MinerBot Token", "MBT") Ownable() {
        require(_gameRewardsWallet != address(0), "MBT: Invalid game rewards wallet");
        require(_teamWallet != address(0), "MBT: Invalid team wallet");
        require(_marketingWallet != address(0), "MBT: Invalid marketing wallet");
        require(_treasuryWallet != address(0), "MBT: Invalid treasury wallet");
        require(_airdropWallet != address(0), "MBT: Invalid airdrop wallet");
        require(_advisorWallet != address(0), "MBT: Invalid advisor wallet");

        gameRewardsWallet = _gameRewardsWallet;
        teamWallet = _teamWallet;
        marketingWallet = _marketingWallet;
        treasuryWallet = _treasuryWallet;
        airdropWallet = _airdropWallet;
        advisorWallet = _advisorWallet;

        teamVestingStart = block.timestamp;
        advisorVestingStart = block.timestamp;

        // Excluir direcciones del sistema de límites
        isExcludedFromLimits[owner()] = true;
        isExcludedFromLimits[address(this)] = true;
        isExcludedFromLimits[_gameRewardsWallet] = true;
        isExcludedFromLimits[_teamWallet] = true;
        isExcludedFromLimits[_marketingWallet] = true;
        isExcludedFromLimits[_treasuryWallet] = true;
        isExcludedFromLimits[_airdropWallet] = true;
        isExcludedFromLimits[_advisorWallet] = true;

        // Distribución inicial
        _mint(_gameRewardsWallet, GAME_REWARDS_ALLOCATION);
        _mint(_marketingWallet, MARKETING_ALLOCATION);
        _mint(_treasuryWallet, TREASURY_ALLOCATION);
        _mint(_airdropWallet, AIRDROP_ALLOCATION);
        
        // Los tokens de staking se mintean cuando se establece el contrato
        // Los tokens de team y advisor se liberan gradualmente
    }

    /**
     * @dev Establece el contrato de staking y transfiere tokens
     */
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "MBT: Invalid staking contract");
        require(stakingContract == address(0), "MBT: Staking contract already set");
        
        stakingContract = _stakingContract;
        isExcludedFromLimits[_stakingContract] = true;
        _mint(_stakingContract, STAKING_ALLOCATION);
    }

    /**
     * @dev Libera tokens del team según el vesting schedule
     */
    function releaseTeamTokens() external nonReentrant {
        uint256 releasableAmount = getReleasableTeamTokens();
        require(releasableAmount > 0, "MBT: No tokens to release");

        teamTokensReleased += releasableAmount;
        _mint(teamWallet, releasableAmount);

        emit TokensVested(teamWallet, releasableAmount, "team");
    }

    /**
     * @dev Libera tokens de advisors según el vesting schedule
     */
    function releaseAdvisorTokens() external nonReentrant {
        uint256 releasableAmount = getReleasableAdvisorTokens();
        require(releasableAmount > 0, "MBT: No tokens to release");

        advisorTokensReleased += releasableAmount;
        _mint(advisorWallet, releasableAmount);

        emit TokensVested(advisorWallet, releasableAmount, "advisor");
    }

    /**
     * @dev Calcula tokens del team liberables
     */
    function getReleasableTeamTokens() public view returns (uint256) {
        if (block.timestamp < teamVestingStart) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - teamVestingStart;
        uint256 vestedAmount;

        if (elapsedTime >= TEAM_VESTING_DURATION) {
            vestedAmount = TEAM_ALLOCATION;
        } else {
            vestedAmount = (TEAM_ALLOCATION * elapsedTime) / TEAM_VESTING_DURATION;
        }

        return vestedAmount - teamTokensReleased;
    }

    /**
     * @dev Calcula tokens de advisors liberables
     */
    function getReleasableAdvisorTokens() public view returns (uint256) {
        if (block.timestamp < advisorVestingStart) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - advisorVestingStart;
        uint256 vestedAmount;

        if (elapsedTime >= ADVISOR_VESTING_DURATION) {
            vestedAmount = ADVISOR_ALLOCATION;
        } else {
            vestedAmount = (ADVISOR_ALLOCATION * elapsedTime) / ADVISOR_VESTING_DURATION;
        }

        return vestedAmount - advisorTokensReleased;
    }

    /**
     * @dev Autoriza contratos de juego para mint de recompensas
     */
    function authorizeGameContract(address gameContract, bool authorized) external onlyOwner {
        require(gameContract != address(0), "MBT: Invalid game contract");
        authorizedGameContracts[gameContract] = authorized;
        isExcludedFromLimits[gameContract] = authorized;
        
        emit GameContractAuthorized(gameContract, authorized);
    }

    /**
     * @dev Mint de tokens para recompensas de juego (solo contratos autorizados)
     */
    function mintGameRewards(address to, uint256 amount) external onlyAuthorizedGame {
        require(to != address(0), "MBT: Invalid recipient");
        require(amount > 0, "MBT: Invalid amount");
        
        _mint(to, amount);
    }

    /**
     * @dev Quema tokens con tracking
     */
    function burn(uint256 amount) public override {
        super.burn(amount);
        totalBurned += amount;
        emit TokensBurned(amount, msg.sender);
    }

    /**
     * @dev Quema tokens de otra dirección con tracking
     */
    function burnFrom(address account, uint256 amount) public override {
        super.burnFrom(account, amount);
        totalBurned += amount;
        emit TokensBurned(amount, account);
    }

    /**
     * @dev Actualiza límites anti-whale
     */
    function updateLimits(uint256 _maxTransactionAmount, uint256 _maxWalletAmount) external onlyOwner {
        require(_maxTransactionAmount >= totalSupply() / 1000, "MBT: Max transaction too low"); // Min 0.1%
        require(_maxWalletAmount >= totalSupply() / 500, "MBT: Max wallet too low"); // Min 0.2%
        
        maxTransactionAmount = _maxTransactionAmount;
        maxWalletAmount = _maxWalletAmount;
        
        emit LimitsUpdated(_maxTransactionAmount, _maxWalletAmount);
    }

    /**
     * @dev Excluye/incluye direcciones de los límites
     */
    function setExcludedFromLimits(address account, bool excluded) external onlyOwner {
        isExcludedFromLimits[account] = excluded;
    }

    /**
     * @dev Pausa el contrato (solo owner)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Despausa el contrato (solo owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Override de transfer con límites anti-whale
     */
    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "MBT: Transfer from zero address");
        require(to != address(0), "MBT: Transfer to zero address");
        require(!paused(), "MBT: Token transfers paused");

        // Aplicar límites anti-whale
        if (!isExcludedFromLimits[from] && !isExcludedFromLimits[to]) {
            require(amount <= maxTransactionAmount, "MBT: Transfer amount exceeds limit");
            
            if (to != address(0)) {
                require(
                    balanceOf(to) + amount <= maxWalletAmount,
                    "MBT: Wallet amount exceeds limit"
                );
            }
        }

        super._transfer(from, to, amount);
    }

    /**
     * @dev Función de emergencia para recuperar tokens ERC20 enviados por error
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(this), "MBT: Cannot recover own tokens");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }

    /**
     * @dev Función de emergencia para recuperar ETH enviado por error
     */
    function recoverETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Información del supply circulante (excluyendo tokens no liberados)
     */
    function circulatingSupply() external view returns (uint256) {
        uint256 unreleasedTeam = TEAM_ALLOCATION - teamTokensReleased;
        uint256 unreleasedAdvisor = ADVISOR_ALLOCATION - advisorTokensReleased;
        return totalSupply() - unreleasedTeam - unreleasedAdvisor;
    }

    /**
     * @dev Información de burn rate
     */
    function burnRate() external view returns (uint256) {
        if (totalSupply() == 0) return 0;
        return (totalBurned * 10000) / TOTAL_SUPPLY; // En basis points
    }
}