// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SimpleStorageV2
/// @author Sami BELHADJ, Book 3, Exercise 3.1 solution
/// @notice SimpleStorage with increment() and a count of writes.
/// @dev Teaching code, not audited.
contract SimpleStorageV2 {
    uint256 private storedValue;
    /// @notice Number of writes, through set() or increment().
    uint256 public setCount;

    /// @notice Emitted on every write, with the value before and after.
    /// @param by Account that made the change.
    /// @param oldValue Value before the change.
    /// @param newValue Value after the change.
    event ValueChanged(address indexed by, uint256 oldValue, uint256 newValue);

    /// @notice Replaces the stored value.
    /// @dev Public, not external, because increment() calls it.
    /// @param newValue The value to store.
    function set(uint256 newValue) public {
        uint256 old = storedValue;
        storedValue = newValue;
        setCount += 1;
        emit ValueChanged(msg.sender, old, newValue);
    }

    /// @notice Adds one to the stored value.
    function increment() external {
        set(storedValue + 1);
    }

    /// @notice Returns the stored value.
    /// @return The current value.
    function get() external view returns (uint256) {
        return storedValue;
    }
}
