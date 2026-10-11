// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TokenSaleFixed
/// @author Sami BELHADJ, Book 3, Exercise 3.3, contract B fixed
/// @notice Only the owner sets the price, buyers cap the price they accept, and
///         the owner can withdraw the proceeds.
/// @dev Teaching code, not audited.
contract TokenSaleFixed is Ownable, ReentrancyGuard {
    /// @notice Tokens bought by each account.
    mapping(address => uint256) public tokenBalances;
    /// @notice Price of one token in wei.
    uint256 public tokenPrice = 1 ether;

    /// @notice The amount to buy is zero.
    error ZeroAmount();
    /// @notice The ether sent does not match the cost.
    error WrongPayment(uint256 sent, uint256 required);
    /// @notice The current price is above the buyer's limit.
    error PriceAboveLimit(uint256 price, uint256 maxPrice);
    /// @notice There are no proceeds to withdraw.
    error NothingToWithdraw();
    /// @notice Sending ether failed.
    error TransferFailed();

    /// @notice `buyer` bought `amount` tokens for `cost` wei.
    event TokensBought(address indexed buyer, uint256 amount, uint256 cost);
    /// @notice The price changed.
    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    /// @notice The owner withdrew `amount` wei.
    event ProceedsWithdrawn(address indexed to, uint256 amount);

    /// @param initialOwner Account that sets the price and withdraws.
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Buys `amount` tokens if the price is at most `maxPrice`.
    /// @param amount Number of tokens.
    /// @param maxPrice Highest price per token the buyer accepts.
    function buy(uint256 amount, uint256 maxPrice) external payable {
        if (amount == 0) revert ZeroAmount();
        if (tokenPrice > maxPrice) revert PriceAboveLimit(tokenPrice, maxPrice);
        uint256 cost = amount * tokenPrice;
        if (msg.value != cost) revert WrongPayment(msg.value, cost);
        tokenBalances[msg.sender] += amount;
        emit TokensBought(msg.sender, amount, cost);
    }

    /// @notice Sets the price of one token.
    /// @param newPrice New price in wei.
    function setPrice(uint256 newPrice) external onlyOwner {
        emit PriceChanged(tokenPrice, newPrice);
        tokenPrice = newPrice;
    }

    /// @notice Sends all proceeds to the owner.
    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();
        emit ProceedsWithdrawn(owner(), amount);
        (bool ok, ) = payable(owner()).call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
