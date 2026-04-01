// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

struct Deposit {
    uint128 amount;
    uint64 timestamp;
    uint64 lastClaimTime;
    uint64 lockupDuration;
}

struct User {
    Deposit[] deposits;
    uint128 totalDeposited;
    uint64 lastWithdrawTime;
}