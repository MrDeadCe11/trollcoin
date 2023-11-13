// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface Errors {
    error InvalidAttackAmount(uint256 amount);
    error InvalidAmount();
    error InvalidBalance();
    error CannotAttackThisAddress(address defender);
    error InvalidCaller();
    error InvalidId();
    error InvalidDefender();
    error UnderAttack(address trolled);
    error InvalidTimestamp();
    error InvalidWithdrawal();
}