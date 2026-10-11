// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SecureVault
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice VulnerableVault fixed with checks-effects-interactions and a
///         reentrancy guard.
/// @dev Teaching code, not audited.
contract SecureVault is ReentrancyGuard {
    /// @notice Ether deposited by each account.
    mapping(address => uint256) public balances;

    /// @notice The deposit was zero.
    error ZeroDeposit();
    /// @notice The caller has no balance.
    error NoBalance();
    /// @notice Sending ether to the caller failed.
    error TransferFailed();

    /// @notice `account` deposited `amount` wei.
    event Deposited(address indexed account, uint256 amount);
    /// @notice `account` withdrew `amount` wei.
    event Withdrawn(address indexed account, uint256 amount);

    /// @notice Deposits the ether sent with the call.
    function deposit() external payable {
        if (msg.value == 0) revert ZeroDeposit();
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Withdraws the caller's whole balance.
    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NoBalance();             // check
        balances[msg.sender] = 0;                        // effect
        emit Withdrawn(msg.sender, amount);
        (bool ok,) = msg.sender.call{value: amount}(""); // interaction
        if (!ok) revert TransferFailed();
    }
}
