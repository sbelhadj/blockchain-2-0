// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Airdrop
/// @author Sami BELHADJ, Book 3, Exercise 3.3, contract C
/// @notice DELIBERATELY VULNERABLE: contains the flaws Exercise 3.3 asks you to
///         find. Do not deploy. The fixed version is AirdropFixed.
contract Airdrop {
    /// @notice What each recipient was allocated.
    mapping(address => uint256) public claimable;

    /// @notice Sends `amount` to every recipient.
    /// @param recipients Accounts to pay.
    /// @param amount Wei for each recipient.
    function distribute(address[] calldata recipients, uint256 amount) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            claimable[recipients[i]] = amount;
            payable(recipients[i]).transfer(amount);
        }
    }

    /// @notice Accepts ether to distribute.
    receive() external payable {}
}
