// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/ISmartStakingRewards.sol";
import "../interfaces/ISmartStakingPower.sol";
import "../interfaces/ISmartStakingGamification.sol";
import "../interfaces/ITreasuryManager.sol";
import "./SmartStakingTypes.sol";

error ModuleNotSet();
error NoRewardsAvailable();
error InsufficientBalance();
error NoDepositsFound();
error InvalidLockupDuration();
error FundsAreLocked();
error DailyWithdrawalLimitExceeded(uint256 availableToWithdraw);
error CommissionTransferFailed(address treasury, uint256 amount);
error InvalidAddress();
error AutoCompoundNotEnabled();
error DepositIndexOutOfBounds(uint256 index, uint256 length);
error MigrationNotAllowed();

event CommissionPaid(address indexed receiver, uint256 amount, uint256 timestamp);
event EarlyExitFeePaid(address indexed user, uint256 feeAmount);
event AutocompoundFeePaid(address indexed user, uint256 feeAmount);

interface ISmartStakingRewardsExtendedLib {
    function clearStakingSince(address user) external;
}

library SmartStakingCoreLib {
    using Address for address payable;

    uint16 private constant COMMISSION_PERCENTAGE = 600;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant DAILY_WITHDRAWAL_LIMIT = 2000 ether;
    uint256 private constant WITHDRAWAL_LIMIT_PERIOD = 1 days;
    uint256 private constant EARLY_EXIT_FEE_BPS = 50;
    uint256 private constant EARLY_EXIT_WINDOW = 7 days;
    uint256 private constant AUTOCOMPOUND_FEE_BPS = 25;

    function calculateRewards(
        mapping(address => User) storage users,
        address rewardsModuleAddress,
        address powerModuleAddress,
        mapping(address => uint256) storage referralBoostEndTime,
        uint256 referralBoostBps,
        address userAddress
    ) public view returns (uint256 totalRewards) {
        if (rewardsModuleAddress == address(0)) revert ModuleNotSet();

        User storage user = users[userAddress];
        if (user.deposits.length == 0) return 0;

        uint16 stakingBoostTotal = 0;
        if (powerModuleAddress != address(0)) {
            (stakingBoostTotal,,) = ISmartStakingPower(powerModuleAddress).getUserBoosts(userAddress);
        }

        if (referralBoostBps > 0 && referralBoostEndTime[userAddress] > block.timestamp) {
            uint256 combined = uint256(stakingBoostTotal) + referralBoostBps;
            stakingBoostTotal = combined > type(uint16).max ? type(uint16).max : uint16(combined);
        }

        ISmartStakingRewards rewardsModule = ISmartStakingRewards(rewardsModuleAddress);
        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            uint8 lockupIndex = _getLockupIndex(userDeposit.lockupDuration);

            totalRewards += rewardsModule.calculateStakingRewards(
                uint256(userDeposit.amount),
                uint256(userDeposit.timestamp),
                uint256(userDeposit.lastClaimTime),
                lockupIndex,
                stakingBoostTotal
            );
        }
    }

    function withdrawRewards(
        mapping(address => User) storage users,
        mapping(address => uint256) storage dailyWithdrawalAmount,
        mapping(address => uint256) storage lastWithdrawalDay,
        mapping(address => uint256) storage totalRewardsClaimed,
        mapping(address => uint256) storage reinvestmentPercentage,
        address rewardsModuleAddress,
        address powerModuleAddress,
        mapping(address => uint256) storage referralBoostEndTime,
        uint256 referralBoostBps,
        address treasury,
        address treasuryManagerAddress,
        uint256 totalPoolBalance,
        address userAddress
    ) public returns (uint256 netAmount, uint256 compoundPortion, uint256 newTotalPoolBalance) {
        User storage user = users[userAddress];

        if (block.timestamp / WITHDRAWAL_LIMIT_PERIOD > lastWithdrawalDay[userAddress]) {
            dailyWithdrawalAmount[userAddress] = 0;
            lastWithdrawalDay[userAddress] = block.timestamp / WITHDRAWAL_LIMIT_PERIOD;
        }

        uint256 totalRewards = calculateRewards(
            users,
            rewardsModuleAddress,
            powerModuleAddress,
            referralBoostEndTime,
            referralBoostBps,
            userAddress
        );
        if (totalRewards == 0) revert NoRewardsAvailable();

        uint256 userReinvestPct = reinvestmentPercentage[userAddress];
        if (userReinvestPct > 0) {
            compoundPortion = (totalRewards * userReinvestPct) / BASIS_POINTS;
            totalRewards -= compoundPortion;
        }

        if (totalRewards == 0) revert NoRewardsAvailable();

        if (dailyWithdrawalAmount[userAddress] + totalRewards > DAILY_WITHDRAWAL_LIMIT) {
            revert DailyWithdrawalLimitExceeded(DAILY_WITHDRAWAL_LIMIT - dailyWithdrawalAmount[userAddress]);
        }

        dailyWithdrawalAmount[userAddress] += totalRewards;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            if (userDeposit.lockupDuration > 0 && block.timestamp < userDeposit.timestamp + userDeposit.lockupDuration) {
                revert FundsAreLocked();
            }
        }

        uint256 commission = (totalRewards * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        netAmount = totalRewards - commission;

        if (address(this).balance < netAmount + commission) {
            revert InsufficientBalance();
        }

        uint64 currentTime = uint64(block.timestamp);
        for (uint256 i = 0; i < user.deposits.length; i++) {
            user.deposits[i].lastClaimTime = currentTime;
        }
        user.lastWithdrawTime = currentTime;

        newTotalPoolBalance = totalPoolBalance;
        if (compoundPortion > 0) {
            user.totalDeposited += uint128(compoundPortion);
            newTotalPoolBalance += compoundPortion;
            user.deposits.push(Deposit({
                amount: uint128(compoundPortion),
                timestamp: currentTime,
                lastClaimTime: currentTime,
                lockupDuration: 0
            }));
            _syncTVLToRewards(rewardsModuleAddress, newTotalPoolBalance);
        }

        totalRewardsClaimed[userAddress] += netAmount;

        _transferCommission(treasury, treasuryManagerAddress, commission);
        payable(userAddress).sendValue(netAmount);
    }

    function withdrawAll(
        mapping(address => User) storage users,
        address rewardsModuleAddress,
        address powerModuleAddress,
        mapping(address => uint256) storage referralBoostEndTime,
        uint256 referralBoostBps,
        address treasury,
        address treasuryManagerAddress,
        uint256 totalPoolBalance,
        uint256 uniqueUsersCount,
        address userAddress
    ) public returns (uint256 netAmount, uint256 newTotalPoolBalance, uint256 newUniqueUsersCount) {
        User storage user = users[userAddress];
        if (user.totalDeposited == 0) revert NoDepositsFound();

        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage userDeposit = user.deposits[i];
            if (userDeposit.lockupDuration > 0 && block.timestamp < userDeposit.timestamp + userDeposit.lockupDuration) {
                revert FundsAreLocked();
            }
        }

        uint256 earlyExitFee = 0;
        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage dep = user.deposits[i];
            if (dep.lockupDuration == 0 && block.timestamp < uint256(dep.timestamp) + EARLY_EXIT_WINDOW) {
                earlyExitFee += (uint256(dep.amount) * EARLY_EXIT_FEE_BPS) / BASIS_POINTS;
            }
        }

        uint256 rewards = calculateRewards(
            users,
            rewardsModuleAddress,
            powerModuleAddress,
            referralBoostEndTime,
            referralBoostBps,
            userAddress
        );
        uint256 totalAmount = user.totalDeposited + rewards;
        uint256 rewardCommission = (rewards * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        uint256 totalFees = rewardCommission + earlyExitFee;
        netAmount = totalAmount - totalFees;

        if (address(this).balance < netAmount + totalFees) {
            revert InsufficientBalance();
        }

        user.totalDeposited = 0;
        user.lastWithdrawTime = uint64(block.timestamp);
        delete user.deposits;

        newTotalPoolBalance = totalPoolBalance - (totalAmount - rewards);
        newUniqueUsersCount = uniqueUsersCount;
        if (newUniqueUsersCount > 0) {
            unchecked { --newUniqueUsersCount; }
        }
        if (rewardsModuleAddress != address(0)) {
            try ISmartStakingRewardsExtendedLib(rewardsModuleAddress).clearStakingSince(userAddress) {} catch {}
        }

        _syncTVLToRewards(rewardsModuleAddress, newTotalPoolBalance);

        if (earlyExitFee > 0) {
            emit EarlyExitFeePaid(userAddress, earlyExitFee);
        }

        _transferCommission(treasury, treasuryManagerAddress, totalFees);
        payable(userAddress).sendValue(netAmount);
    }

    function compoundRewards(
        mapping(address => User) storage users,
        address rewardsModuleAddress,
        address powerModuleAddress,
        mapping(address => uint256) storage referralBoostEndTime,
        uint256 referralBoostBps,
        address treasury,
        address treasuryManagerAddress,
        uint256 totalPoolBalance,
        address userAddress
    ) public returns (uint256 compoundAmount, uint256 newTotalPoolBalance) {
        User storage userStruct = users[userAddress];
        uint256 rewards = calculateRewards(
            users,
            rewardsModuleAddress,
            powerModuleAddress,
            referralBoostEndTime,
            referralBoostBps,
            userAddress
        );

        if (rewards == 0) revert NoRewardsAvailable();

        uint256 acFee = (rewards * AUTOCOMPOUND_FEE_BPS) / BASIS_POINTS;
        compoundAmount = rewards - acFee;

        if (acFee > 0) {
            _transferCommission(treasury, treasuryManagerAddress, acFee);
            emit AutocompoundFeePaid(userAddress, acFee);
        }

        userStruct.totalDeposited += uint128(compoundAmount);
        newTotalPoolBalance = totalPoolBalance + compoundAmount;
        _syncTVLToRewards(rewardsModuleAddress, newTotalPoolBalance);

        uint64 currentTime = uint64(block.timestamp);
        userStruct.deposits.push(Deposit({
            amount: uint128(compoundAmount),
            timestamp: currentTime,
            lastClaimTime: currentTime,
            lockupDuration: 0
        }));

        for (uint256 i = 0; i < userStruct.deposits.length; i++) {
            userStruct.deposits[i].lastClaimTime = currentTime;
        }
    }

    function performAutoCompound(
        mapping(address => User) storage users,
        address rewardsModuleAddress,
        address powerModuleAddress,
        address gamificationModuleAddress,
        mapping(address => uint256) storage referralBoostEndTime,
        uint256 referralBoostBps,
        uint256 totalPoolBalance,
        address userAddress
    ) public returns (uint256 rewards, uint256 newTotalPoolBalance) {
        if (gamificationModuleAddress == address(0)) revert ModuleNotSet();

        (bool shouldCompound,) = ISmartStakingGamification(gamificationModuleAddress).checkAutoCompound(userAddress);
        if (!shouldCompound) revert AutoCompoundNotEnabled();

        rewards = calculateRewards(
            users,
            rewardsModuleAddress,
            powerModuleAddress,
            referralBoostEndTime,
            referralBoostBps,
            userAddress
        );
        if (rewards == 0) revert NoRewardsAvailable();

        User storage userStruct = users[userAddress];
        userStruct.totalDeposited += uint128(rewards);
        newTotalPoolBalance = totalPoolBalance + rewards;

        uint64 currentTime = uint64(block.timestamp);
        userStruct.deposits.push(Deposit({
            amount: uint128(rewards),
            timestamp: currentTime,
            lastClaimTime: currentTime,
            lockupDuration: 0
        }));

        for (uint256 i = 0; i < userStruct.deposits.length; i++) {
            userStruct.deposits[i].lastClaimTime = currentTime;
        }

        ISmartStakingGamification(gamificationModuleAddress).performAutoCompound(userAddress);
        _syncTVLToRewards(rewardsModuleAddress, newTotalPoolBalance);
    }

    function executeWithdrawals(
        mapping(address => User) storage users,
        mapping(address => uint256) storage dailyWithdrawalAmount,
        mapping(address => uint256) storage lastWithdrawalDay,
        mapping(address => uint256) storage totalRewardsClaimed,
        address rewardsModuleAddress,
        address powerModuleAddress,
        address treasury,
        address treasuryManagerAddress,
        uint256 totalPoolBalance,
        uint256 uniqueUsersCount,
        uint256[] memory indices,
        address userAddress
    ) public returns (
        uint256 principal,
        uint256 netRewards,
        uint256 payout,
        uint256 newTotalPoolBalance,
        uint256 newUniqueUsersCount
    ) {
        User storage user = users[userAddress];

        if (block.timestamp / WITHDRAWAL_LIMIT_PERIOD > lastWithdrawalDay[userAddress]) {
            dailyWithdrawalAmount[userAddress] = 0;
            lastWithdrawalDay[userAddress] = block.timestamp / WITHDRAWAL_LIMIT_PERIOD;
        }

        uint16 boost = 0;
        if (powerModuleAddress != address(0)) {
            (boost,,) = ISmartStakingPower(powerModuleAddress).getUserBoosts(userAddress);
        }

        uint256 totalEarlyFee;
        uint256 totalRewards_;
        uint64 now_ = uint64(block.timestamp);

        for (uint256 i; i < indices.length; i++) {
            uint256 idx = indices[i];
            if (idx >= user.deposits.length) revert DepositIndexOutOfBounds(idx, user.deposits.length);
            Deposit storage dep = user.deposits[idx];
            if (dep.lockupDuration > 0 && now_ < dep.timestamp + dep.lockupDuration) revert FundsAreLocked();

            principal += dep.amount;

            if (rewardsModuleAddress != address(0)) {
                totalRewards_ += ISmartStakingRewards(rewardsModuleAddress).calculateStakingRewards(
                    dep.amount,
                    dep.timestamp,
                    dep.lastClaimTime,
                    _getLockupIndex(dep.lockupDuration),
                    boost
                );
            }
            if (dep.lockupDuration == 0 && now_ < dep.timestamp + EARLY_EXIT_WINDOW) {
                totalEarlyFee += (uint256(dep.amount) * EARLY_EXIT_FEE_BPS) / BASIS_POINTS;
            }
        }

        if (dailyWithdrawalAmount[userAddress] + principal > DAILY_WITHDRAWAL_LIMIT) {
            revert DailyWithdrawalLimitExceeded(DAILY_WITHDRAWAL_LIMIT - dailyWithdrawalAmount[userAddress]);
        }
        dailyWithdrawalAmount[userAddress] += principal;

        uint256 rewardComm = (totalRewards_ * COMMISSION_PERCENTAGE) / BASIS_POINTS;
        netRewards = totalRewards_ - rewardComm;
        uint256 totalFees = rewardComm + totalEarlyFee;
        payout = principal + netRewards - totalEarlyFee;

        if (address(this).balance < payout + totalFees) revert InsufficientBalance();

        for (uint256 i; i < indices.length; i++) {
            uint256 idx = indices[i];
            uint256 last_ = user.deposits.length - 1;
            if (idx != last_) user.deposits[idx] = user.deposits[last_];
            user.deposits.pop();
        }

        user.totalDeposited -= uint128(principal);
        user.lastWithdrawTime = now_;
        newTotalPoolBalance = totalPoolBalance - principal;
        newUniqueUsersCount = uniqueUsersCount;

        if (user.deposits.length == 0) {
            if (newUniqueUsersCount > 0) {
                unchecked { --newUniqueUsersCount; }
            }
            if (rewardsModuleAddress != address(0)) {
                try ISmartStakingRewardsExtendedLib(rewardsModuleAddress).clearStakingSince(userAddress) {} catch {}
            }
        }

        _syncTVLToRewards(rewardsModuleAddress, newTotalPoolBalance);
        if (totalFees > 0) _transferCommission(treasury, treasuryManagerAddress, totalFees);
        if (totalEarlyFee > 0) emit EarlyExitFeePaid(userAddress, totalEarlyFee);
        totalRewardsClaimed[userAddress] += netRewards;
        payable(userAddress).sendValue(payout);
    }

    function migrateLockup(
        mapping(address => User) storage users,
        uint256 depositIndex,
        uint64 newLockupDays,
        address userAddress
    ) public returns (uint64 newDuration) {
        if (newLockupDays != 30 && newLockupDays != 90 && newLockupDays != 180 && newLockupDays != 365) {
            revert InvalidLockupDuration();
        }

        User storage user = users[userAddress];
        if (depositIndex >= user.deposits.length) {
            revert DepositIndexOutOfBounds(depositIndex, user.deposits.length);
        }

        Deposit storage dep = user.deposits[depositIndex];
        if (dep.lockupDuration != 0) revert MigrationNotAllowed();

        newDuration = newLockupDays * 1 days;
        dep.lockupDuration = newDuration;
        dep.timestamp = uint64(block.timestamp);
        dep.lastClaimTime = uint64(block.timestamp);
    }

    function emergencyWithdrawStake(
        mapping(address => User) storage users,
        address rewardsModuleAddress,
        uint256 totalPoolBalance,
        uint256 uniqueUsersCount,
        address userAddress
    ) public returns (uint256 stakeAmount, uint256 newTotalPoolBalance, uint256 newUniqueUsersCount) {
        User storage user = users[userAddress];
        stakeAmount = user.totalDeposited;
        if (stakeAmount == 0) revert NoDepositsFound();

        if (address(this).balance < stakeAmount) {
            revert InsufficientBalance();
        }

        user.totalDeposited = 0;
        user.lastWithdrawTime = uint64(block.timestamp);
        delete user.deposits;

        newTotalPoolBalance = totalPoolBalance - stakeAmount;
        newUniqueUsersCount = uniqueUsersCount;
        if (newUniqueUsersCount > 0) {
            unchecked { --newUniqueUsersCount; }
        }

        _syncTVLToRewards(rewardsModuleAddress, newTotalPoolBalance);
        payable(userAddress).sendValue(stakeAmount);
    }

    function _transferCommission(address treasury, address treasuryManagerAddress, uint256 commission) private {
        if (treasuryManagerAddress != address(0)) {
            try ITreasuryManager(treasuryManagerAddress).receiveRevenue{value: commission}("staking_commission") {
                emit CommissionPaid(treasuryManagerAddress, commission, block.timestamp);
                return;
            } catch {
            }
        }

        if (treasury == address(0)) revert InvalidAddress();

        (bool sent, ) = payable(treasury).call{value: commission}("");
        if (!sent) {
            revert CommissionTransferFailed(treasury, commission);
        }
        emit CommissionPaid(treasury, commission, block.timestamp);
    }

    function _syncTVLToRewards(address rewardsModuleAddress, uint256 totalPoolBalance) private {
        if (rewardsModuleAddress != address(0)) {
            try ISmartStakingRewards(rewardsModuleAddress).updateCurrentTVL(totalPoolBalance) {
            } catch {
            }
        }
    }

    function _getLockupIndex(uint64 lockupDuration) private pure returns (uint8) {
        if (lockupDuration == 0) return 0;
        if (lockupDuration == 30 days) return 1;
        if (lockupDuration == 90 days) return 2;
        if (lockupDuration == 180 days) return 3;
        if (lockupDuration == 365 days) return 4;
        return 0;
    }
}