// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title VulnerableVault
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice DELIBERATELY VULNERABLE: sends ether before updating the balance,
///         so a contract can re-enter withdraw(). Do not deploy.
/// @dev Kept unsafe for Section 3.4.1; SecureVault is the fixed version.
contract VulnerableVault {
    /// @notice Ether deposited by each account.
    mapping(address => uint256) public balances;

    /// @notice Deposits the ether sent with the call.
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// @notice Withdraws the caller's balance. The order of the last three
    ///         statements is the bug.
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");
        (bool ok,) = msg.sender.call{value: amount}("");   // interaction first
        require(ok, "Transfer failed");
        balances[msg.sender] = 0;                          // effect last: the bug
    }
}
