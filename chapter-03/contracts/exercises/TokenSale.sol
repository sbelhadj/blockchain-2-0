// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title TokenSale
/// @author Sami BELHADJ, Book 3, Exercise 3.3, contract B
/// @notice DELIBERATELY VULNERABLE: contains the flaws Exercise 3.3 asks you to
///         find. Do not deploy. The fixed version is TokenSaleFixed.
contract TokenSale {
    /// @notice Tokens bought by each account.
    mapping(address => uint256) public tokenBalances;
    /// @notice Price of one token in wei.
    uint256 public tokenPrice = 1 ether;

    /// @notice Buys `amount` tokens at the current price.
    /// @param amount Number of tokens.
    function buy(uint256 amount) external payable {
        require(msg.value == amount * tokenPrice, "Wrong payment");
        tokenBalances[msg.sender] += amount;
    }

    /// @notice Sets the price of one token.
    /// @param newPrice New price in wei.
    function setPrice(uint256 newPrice) external {
        tokenPrice = newPrice;
    }
}
