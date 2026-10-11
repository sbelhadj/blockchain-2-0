// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Secret
/// @notice Used in Listing 2.4: "private" limits which contracts can read a
///         variable, not who can read the chain.
/// @dev Never store a real secret like this. The storage layout is the lesson,
///      so the three variables stay in slots 0, 1 and 2.
contract Secret {
    /// @notice Deployer of the contract.
    address public owner;                         // slot 0
    uint256 private accessCode;                   // slot 1
    mapping(address => uint256) private balances; // slot 2 (base slot)

    /// @param code Value stored in the "private" slot 1.
    constructor(uint256 code) {
        owner = msg.sender;
        accessCode = code;
        balances[msg.sender] = 1000;
    }
}
