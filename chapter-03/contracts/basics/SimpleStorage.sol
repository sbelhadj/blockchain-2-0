// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SimpleStorage
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice Stores one number and announces every change.
/// @dev The first contract of Chapter 3. Teaching code, not audited.
contract SimpleStorage {
    uint256 private storedValue;

    /// @notice Emitted on every write, with the value before and after.
    /// @param by Account that made the change.
    /// @param oldValue Value before the change.
    /// @param newValue Value after the change.
    event ValueChanged(address indexed by, uint256 oldValue, uint256 newValue);

    /// @notice Replaces the stored value.
    /// @param newValue The value to store.
    function set(uint256 newValue) external {
        uint256 old = storedValue;
        storedValue = newValue;
        emit ValueChanged(msg.sender, old, newValue);
    }

    /// @notice Returns the stored value.
    /// @return The current value.
    function get() external view returns (uint256) {
        return storedValue;
    }
}
