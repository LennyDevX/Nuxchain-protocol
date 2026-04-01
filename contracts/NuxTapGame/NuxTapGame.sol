// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface INuxTapTreasuryGame {
    function availableLiquidity() external view returns (uint256);
    function reserveLiquidity(uint256 amount) external;
    function payReward(address recipient, uint256 grossAmount, uint256 feeAmount, string calldata reason) external;
}

interface INuxTapGameStore {
    function consumeItem(address account, uint256 itemId, uint256 amount) external;
    function getItemConfig(uint256 itemId)
        external
        view
        returns (uint8 kind, uint256 price, uint256 value, uint256 duration, uint256 stock, bool active, bool soulbound, address nftContract);
}

interface INuxTapAgentRegistry {
    function registeredNFTContracts(address nftContract) external view returns (bool);

    function getAgentOperationalProfile(address nftContract, uint256 tokenId)
        external
        view
        returns (
            address agentWallet,
            uint256 totalTasksRun,
            uint256 totalRevenueEarned,
            uint256 spendingLimitDaily,
            uint256 spentToday,
            uint256 spentDayReset,
            bool x402Enabled,
            string memory mcpEndpoint,
            string memory a2aEndpoint,
            uint256 currentReputationScore,
            uint256 clientCount,
            uint256 validationCount
        );
}

interface INuxTapOwnerNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface INuxTapControllableNFT is INuxTapOwnerNFT {
    function effectiveController(uint256 tokenId) external view returns (address);
}

contract NuxTapGame is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint8 private constant ITEM_KIND_AUTO_TAP = 1;
    uint8 private constant ITEM_KIND_BOOSTER = 2;
    uint8 private constant ITEM_KIND_WITHDRAW_PASS = 3;

    struct LevelConfig {
        uint256 scoreRequired;
        uint256 dailyTapCap;
        uint256 rewardMultiplierBps;
    }

    struct PlayerProfile {
        uint256 totalScore;
        uint256 lifetimeTaps;
        uint256 totalSessions;
        uint256 unclaimedRewards;
        uint256 claimedRewards;
        uint256 currentLevel;
        uint256 currentStreak;
        uint256 bestStreak;
        uint256 autoTapRate;
        uint256 boosterMultiplierBps;
        uint256 boosterExpiresAt;
        uint256 lastSettlementAt;
        uint256 lastActiveDay;
        uint256 dailyTapCount;
        address linkedNftContract;
        uint256 linkedTokenId;
    }

    address public treasury;
    address public itemStore;
    address public agentRegistry;
    uint256 public rewardPerTapWei;
    uint256 public baseDailyTapCap;
    uint256 public maxManualTapsPerSession;
    uint256 public passiveTickSeconds;
    uint256 public claimFeeBps;
    uint256 public streakBonusBps;
    uint256 public linkedAgentBaseBonusBps;
    uint256 public linkedAgentMaxReputationBonusBps;
    uint256 public linkedAgentMaxTaskBonusBps;
    uint256 public maxLinkedAgentBonusBps;

    mapping(address => PlayerProfile) private _profiles;
    mapping(address => bool) public supportedNFTContracts;
    LevelConfig[] private _levelConfigs;

    event ExternalContractsUpdated(address indexed treasury, address indexed itemStore, address indexed agentRegistry);
    event SupportedNFTContractUpdated(address indexed nftContract, bool supported);
    event GameConfigUpdated(
        uint256 rewardPerTapWei,
        uint256 baseDailyTapCap,
        uint256 maxManualTapsPerSession,
        uint256 passiveTickSeconds,
        uint256 claimFeeBps,
        uint256 streakBonusBps
    );
    event LinkedAgentConfigUpdated(
        uint256 linkedAgentBaseBonusBps,
        uint256 linkedAgentMaxReputationBonusBps,
        uint256 linkedAgentMaxTaskBonusBps,
        uint256 maxLinkedAgentBonusBps
    );
    event LevelConfigsReplaced(uint256 totalLevels);
    event AgentLinked(address indexed player, address indexed nftContract, uint256 indexed tokenId);
    event AgentUnlinked(address indexed player, address indexed nftContract, uint256 indexed tokenId);
    event BoosterActivated(address indexed player, uint256 indexed itemId, uint256 multiplierBps, uint256 expiresAt);
    event AutoTapUpgraded(address indexed player, uint256 indexed itemId, uint256 addedRate, uint256 newRate);
    event SessionSettled(
        address indexed player,
        uint256 manualTaps,
        uint256 passiveTaps,
        uint256 creditedTaps,
        uint256 scoreEarned,
        uint256 rewardEarned,
        uint256 newLevel,
        uint256 streak
    );
    event RewardsClaimed(address indexed player, uint256 grossAmount, uint256 feeAmount, bool feeWaived);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin_, address treasury_, address itemStore_, address agentRegistry_) external initializer {
        require(admin_ != address(0), "NuxTapGame: invalid admin");
        require(treasury_ != address(0), "NuxTapGame: invalid treasury");
        require(itemStore_ != address(0), "NuxTapGame: invalid store");

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        treasury = treasury_;
        itemStore = itemStore_;
        agentRegistry = agentRegistry_;

        rewardPerTapWei = 0.00001 ether;
        baseDailyTapCap = 5_000;
        maxManualTapsPerSession = 1_000;
        passiveTickSeconds = 300;
        claimFeeBps = 500;
        streakBonusBps = 150;
        linkedAgentBaseBonusBps = 300;
        linkedAgentMaxReputationBonusBps = 800;
        linkedAgentMaxTaskBonusBps = 400;
        maxLinkedAgentBonusBps = 1_500;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, admin_);

        _levelConfigs.push(LevelConfig({scoreRequired: 0, dailyTapCap: 5_000, rewardMultiplierBps: 10_000}));
        _levelConfigs.push(LevelConfig({scoreRequired: 1_000, dailyTapCap: 7_500, rewardMultiplierBps: 10_500}));
        _levelConfigs.push(LevelConfig({scoreRequired: 5_000, dailyTapCap: 10_000, rewardMultiplierBps: 11_500}));
        _levelConfigs.push(LevelConfig({scoreRequired: 15_000, dailyTapCap: 15_000, rewardMultiplierBps: 12_500}));
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setExternalContracts(address treasury_, address itemStore_, address agentRegistry_) external onlyRole(ADMIN_ROLE) {
        require(treasury_ != address(0), "NuxTapGame: invalid treasury");
        require(itemStore_ != address(0), "NuxTapGame: invalid store");

        treasury = treasury_;
        itemStore = itemStore_;
        agentRegistry = agentRegistry_;

        emit ExternalContractsUpdated(treasury_, itemStore_, agentRegistry_);
    }

    function setSupportedNFTContract(address nftContract, bool supported) external onlyRole(ADMIN_ROLE) {
        require(nftContract != address(0), "NuxTapGame: invalid NFT contract");
        supportedNFTContracts[nftContract] = supported;
        emit SupportedNFTContractUpdated(nftContract, supported);
    }

    function setGameConfig(
        uint256 rewardPerTapWei_,
        uint256 baseDailyTapCap_,
        uint256 maxManualTapsPerSession_,
        uint256 passiveTickSeconds_,
        uint256 claimFeeBps_,
        uint256 streakBonusBps_
    ) external onlyRole(ADMIN_ROLE) {
        require(claimFeeBps_ <= 2_500, "NuxTapGame: claim fee too high");
        require(passiveTickSeconds_ > 0, "NuxTapGame: invalid passive tick");

        rewardPerTapWei = rewardPerTapWei_;
        baseDailyTapCap = baseDailyTapCap_;
        maxManualTapsPerSession = maxManualTapsPerSession_;
        passiveTickSeconds = passiveTickSeconds_;
        claimFeeBps = claimFeeBps_;
        streakBonusBps = streakBonusBps_;

        emit GameConfigUpdated(
            rewardPerTapWei_,
            baseDailyTapCap_,
            maxManualTapsPerSession_,
            passiveTickSeconds_,
            claimFeeBps_,
            streakBonusBps_
        );
    }

    function setLinkedAgentConfig(
        uint256 linkedAgentBaseBonusBps_,
        uint256 linkedAgentMaxReputationBonusBps_,
        uint256 linkedAgentMaxTaskBonusBps_,
        uint256 maxLinkedAgentBonusBps_
    ) external onlyRole(ADMIN_ROLE) {
        require(maxLinkedAgentBonusBps_ <= 3_000, "NuxTapGame: linked agent cap too high");
        require(
            linkedAgentBaseBonusBps_ + linkedAgentMaxReputationBonusBps_ + linkedAgentMaxTaskBonusBps_ >=
                maxLinkedAgentBonusBps_,
            "NuxTapGame: invalid linked agent config"
        );

        linkedAgentBaseBonusBps = linkedAgentBaseBonusBps_;
        linkedAgentMaxReputationBonusBps = linkedAgentMaxReputationBonusBps_;
        linkedAgentMaxTaskBonusBps = linkedAgentMaxTaskBonusBps_;
        maxLinkedAgentBonusBps = maxLinkedAgentBonusBps_;

        emit LinkedAgentConfigUpdated(
            linkedAgentBaseBonusBps_,
            linkedAgentMaxReputationBonusBps_,
            linkedAgentMaxTaskBonusBps_,
            maxLinkedAgentBonusBps_
        );
    }

    function replaceLevelConfigs(LevelConfig[] calldata newConfigs) external onlyRole(ADMIN_ROLE) {
        require(newConfigs.length > 0, "NuxTapGame: missing configs");
        require(newConfigs[0].scoreRequired == 0, "NuxTapGame: first level must start at zero");

        delete _levelConfigs;
        for (uint256 i = 0; i < newConfigs.length; i++) {
            if (i > 0) {
                require(
                    newConfigs[i].scoreRequired > newConfigs[i - 1].scoreRequired,
                    "NuxTapGame: unordered levels"
                );
            }
            require(newConfigs[i].rewardMultiplierBps >= 10_000, "NuxTapGame: invalid multiplier");
            _levelConfigs.push(newConfigs[i]);
        }

        emit LevelConfigsReplaced(newConfigs.length);
    }

    function getLevelConfigs() external view returns (LevelConfig[] memory) {
        return _levelConfigs;
    }

    function linkAgent(address nftContract, uint256 tokenId) external whenNotPaused {
        require(supportedNFTContracts[nftContract], "NuxTapGame: unsupported NFT contract");
        require(_currentAgentController(nftContract, tokenId) == msg.sender, "NuxTapGame: not agent controller");

        if (agentRegistry != address(0)) {
            require(INuxTapAgentRegistry(agentRegistry).registeredNFTContracts(nftContract), "NuxTapGame: NFT not registered");
        }

        _profiles[msg.sender].linkedNftContract = nftContract;
        _profiles[msg.sender].linkedTokenId = tokenId;

        emit AgentLinked(msg.sender, nftContract, tokenId);
    }

    function unlinkAgent() external {
        PlayerProfile storage profile = _profiles[msg.sender];
        address previousContract = profile.linkedNftContract;
        uint256 previousTokenId = profile.linkedTokenId;

        profile.linkedNftContract = address(0);
        profile.linkedTokenId = 0;

        emit AgentUnlinked(msg.sender, previousContract, previousTokenId);
    }

    function applyAutoTapItem(uint256 itemId) external whenNotPaused nonReentrant {
        (, , uint256 value, , , bool active, , ) = INuxTapGameStore(itemStore).getItemConfig(itemId);
        require(active, "NuxTapGame: inactive item");
        require(_itemKind(itemId) == ITEM_KIND_AUTO_TAP, "NuxTapGame: invalid auto-tap item");

        INuxTapGameStore(itemStore).consumeItem(msg.sender, itemId, 1);
        _profiles[msg.sender].autoTapRate += value;

        emit AutoTapUpgraded(msg.sender, itemId, value, _profiles[msg.sender].autoTapRate);
    }

    function activateBooster(uint256 itemId) external whenNotPaused nonReentrant {
        (, , uint256 value, uint256 duration, , bool active, , ) = INuxTapGameStore(itemStore).getItemConfig(itemId);
        require(active, "NuxTapGame: inactive item");
        require(_itemKind(itemId) == ITEM_KIND_BOOSTER, "NuxTapGame: invalid booster item");
        require(duration > 0, "NuxTapGame: booster duration required");

        INuxTapGameStore(itemStore).consumeItem(msg.sender, itemId, 1);

        PlayerProfile storage profile = _profiles[msg.sender];
        profile.boosterMultiplierBps = value;
        profile.boosterExpiresAt = block.timestamp + duration;

        emit BoosterActivated(msg.sender, itemId, value, profile.boosterExpiresAt);
    }

    function settleTapSession(uint256 manualTaps) external whenNotPaused nonReentrant {
        require(manualTaps <= maxManualTapsPerSession, "NuxTapGame: manual tap limit exceeded");

        PlayerProfile storage profile = _profiles[msg.sender];
        uint256 passiveTaps = _consumePassiveTaps(profile);
        uint256 rawTaps = manualTaps + passiveTaps;
        require(rawTaps > 0, "NuxTapGame: no taps to settle");

        uint256 streak = _rollDay(profile);
        uint256 tapCap = _dailyTapCap(profile.currentLevel);
        uint256 remainingDaily = profile.dailyTapCount >= tapCap ? 0 : tapCap - profile.dailyTapCount;
        require(remainingDaily > 0, "NuxTapGame: daily cap reached");

        uint256 creditedTaps = rawTaps > remainingDaily ? remainingDaily : rawTaps;
        uint256 rewardMultiplierBps = _rewardMultiplier(profile.currentLevel, streak, profile);
        uint256 scoreEarned = (creditedTaps * rewardMultiplierBps) / 10_000;
        if (scoreEarned == 0) {
            scoreEarned = creditedTaps;
        }

        uint256 rewardEarned = (creditedTaps * rewardPerTapWei * rewardMultiplierBps) / 10_000;
        uint256 availableLiquidity = INuxTapTreasuryGame(treasury).availableLiquidity();
        if (rewardEarned > availableLiquidity) {
            rewardEarned = availableLiquidity;
        }

        if (rewardEarned > 0) {
            INuxTapTreasuryGame(treasury).reserveLiquidity(rewardEarned);
            profile.unclaimedRewards += rewardEarned;
        }

        profile.lifetimeTaps += creditedTaps;
        profile.totalSessions += 1;
        profile.totalScore += scoreEarned;
        profile.dailyTapCount += creditedTaps;
        profile.currentLevel = _resolveLevel(profile.totalScore);
        profile.lastSettlementAt = block.timestamp;

        emit SessionSettled(
            msg.sender,
            manualTaps,
            passiveTaps,
            creditedTaps,
            scoreEarned,
            rewardEarned,
            profile.currentLevel,
            profile.currentStreak
        );
    }

    function claimRewards(uint256 amount, uint256 withdrawPassItemId) external whenNotPaused nonReentrant {
        PlayerProfile storage profile = _profiles[msg.sender];
        require(amount > 0, "NuxTapGame: invalid amount");
        require(amount <= profile.unclaimedRewards, "NuxTapGame: insufficient rewards");

        uint256 feeAmount = (amount * claimFeeBps) / 10_000;
        bool feeWaived = false;

        if (withdrawPassItemId != 0) {
            require(_itemKind(withdrawPassItemId) == ITEM_KIND_WITHDRAW_PASS, "NuxTapGame: invalid withdraw pass");
            INuxTapGameStore(itemStore).consumeItem(msg.sender, withdrawPassItemId, 1);
            feeAmount = 0;
            feeWaived = true;
        }

        profile.unclaimedRewards -= amount;
        profile.claimedRewards += amount;

        INuxTapTreasuryGame(treasury).payReward(msg.sender, amount, feeAmount, "nuxtap_claim");

        emit RewardsClaimed(msg.sender, amount, feeAmount, feeWaived);
    }

    function getPlayerProfile(address account) external view returns (PlayerProfile memory) {
        return _profiles[account];
    }

    function previewPendingPassiveTaps(address account) external view returns (uint256) {
        PlayerProfile memory profile = _profiles[account];
        if (profile.autoTapRate == 0 || profile.lastSettlementAt == 0) {
            return 0;
        }

        uint256 elapsed = block.timestamp - profile.lastSettlementAt;
        return (elapsed / passiveTickSeconds) * profile.autoTapRate;
    }

    function previewLinkedAgentBonusBps(address account) external view returns (uint256) {
        return _linkedAgentBonusBps(account, _profiles[account]);
    }

    function _consumePassiveTaps(PlayerProfile storage profile) internal view returns (uint256) {
        if (profile.autoTapRate == 0 || profile.lastSettlementAt == 0) {
            return 0;
        }

        uint256 elapsed = block.timestamp - profile.lastSettlementAt;
        return (elapsed / passiveTickSeconds) * profile.autoTapRate;
    }

    function _rollDay(PlayerProfile storage profile) internal returns (uint256) {
        uint256 currentDay = block.timestamp / 1 days;

        if (profile.lastActiveDay == currentDay) {
            if (profile.currentStreak == 0) {
                profile.currentStreak = 1;
                profile.bestStreak = 1;
            }
            return profile.currentStreak;
        }

        if (profile.lastActiveDay == 0) {
            profile.currentStreak = 1;
        } else if (currentDay == profile.lastActiveDay + 1) {
            profile.currentStreak += 1;
        } else {
            profile.currentStreak = 1;
        }

        if (profile.currentStreak > profile.bestStreak) {
            profile.bestStreak = profile.currentStreak;
        }

        profile.lastActiveDay = currentDay;
        profile.dailyTapCount = 0;
        return profile.currentStreak;
    }

    function _dailyTapCap(uint256 level) internal view returns (uint256) {
        uint256 configuredCap = _levelConfigs[level].dailyTapCap;
        return configuredCap == 0 ? baseDailyTapCap : configuredCap;
    }

    function _rewardMultiplier(uint256 level, uint256 streak, PlayerProfile storage profile) internal view returns (uint256) {
        uint256 multiplier = _levelConfigs[level].rewardMultiplierBps;

        if (streak > 1) {
            multiplier += (streak - 1) * streakBonusBps;
        }

        if (profile.boosterExpiresAt >= block.timestamp && profile.boosterMultiplierBps > 0) {
            multiplier += profile.boosterMultiplierBps;
        }

        multiplier += _linkedAgentBonusBps(msg.sender, profile);

        return multiplier;
    }

    function _linkedAgentBonusBps(address player, PlayerProfile storage profile) internal view returns (uint256) {
        if (profile.linkedNftContract == address(0)) {
            return 0;
        }

        if (_currentAgentController(profile.linkedNftContract, profile.linkedTokenId) != player) {
            return 0;
        }

        uint256 bonus = linkedAgentBaseBonusBps;
        if (agentRegistry == address(0)) {
            return bonus > maxLinkedAgentBonusBps ? maxLinkedAgentBonusBps : bonus;
        }

        try INuxTapAgentRegistry(agentRegistry).getAgentOperationalProfile(profile.linkedNftContract, profile.linkedTokenId) returns (
            address,
            uint256 totalTasksRun,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            string memory,
            string memory,
            uint256 currentReputationScore,
            uint256,
            uint256
        ) {
            uint256 normalizedTasks = totalTasksRun > 100 ? 100 : totalTasksRun;
            uint256 normalizedReputation = currentReputationScore > 100 ? 100 : currentReputationScore;

            bonus += (normalizedTasks * linkedAgentMaxTaskBonusBps) / 100;
            bonus += (normalizedReputation * linkedAgentMaxReputationBonusBps) / 100;
        } catch {
            return bonus > maxLinkedAgentBonusBps ? maxLinkedAgentBonusBps : bonus;
        }

        return bonus > maxLinkedAgentBonusBps ? maxLinkedAgentBonusBps : bonus;
    }

    function _currentAgentController(address nftContract, uint256 tokenId) internal view returns (address controller) {
        try INuxTapControllableNFT(nftContract).effectiveController(tokenId) returns (address effectiveController_) {
            return effectiveController_;
        } catch {
            return INuxTapOwnerNFT(nftContract).ownerOf(tokenId);
        }
    }

    function _resolveLevel(uint256 score) internal view returns (uint256 level) {
        for (uint256 i = _levelConfigs.length; i > 0; i--) {
            if (score >= _levelConfigs[i - 1].scoreRequired) {
                return i - 1;
            }
        }
        return 0;
    }

    function _itemKind(uint256 itemId) internal view returns (uint8 kind) {
        (kind, , , , , , , ) = INuxTapGameStore(itemStore).getItemConfig(itemId);
    }

    uint256[50] private __gap;

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}