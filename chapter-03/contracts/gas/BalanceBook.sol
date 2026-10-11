// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BalanceBook
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice Same behaviour, two ways of touching storage, for gas measurements.
/// @dev Teaching code, not audited. Balances are bookkeeping only.
contract BalanceBook {
    /// @notice Balance of each account.
    mapping(address => uint256) public balances;

    /// @notice The account cannot cover the debit.
    error Insufficient();

    /// @notice `account` deposited `amount` wei.
    event Deposited(address indexed account, uint256 amount);
    /// @notice A debit left `remaining` on `account`.
    event Withdrawal(address indexed account, uint256 remaining);

    /// @notice Credits the ether sent to the caller.
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Debits `amount`, reading balances[msg.sender] three times.
    /// @param amount Amount to debit.
    function debitRepeated(uint256 amount) external {
        if (balances[msg.sender] < amount) revert Insufficient();
        balances[msg.sender] -= amount;
        emit Withdrawal(msg.sender, balances[msg.sender]);
    }

    /// @notice Debits `amount`, reading the balance once into a local variable.
    /// @param amount Amount to debit.
    function debitCached(uint256 amount) external {
        uint256 balance = balances[msg.sender];
        if (balance < amount) revert Insufficient();
        uint256 remaining = balance - amount;
        balances[msg.sender] = remaining;
        emit Withdrawal(msg.sender, remaining);
    }
}
