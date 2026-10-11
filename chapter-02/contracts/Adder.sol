// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Adder
/// @notice Used in Listing 2.1 to look at the bytecode the compiler produces.
/// @dev Kept as small as possible so the dispatcher is easy to read.
contract Adder {
    /// @notice Adds two numbers; reverts on overflow.
    /// @param a First number.
    /// @param b Second number.
    /// @return The sum.
    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }
}
