// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TestToken
/// @author Sami BELHADJ, Book 3, Chapter 5
/// @notice Test token with a chosen number of decimals and ERC-2612 permit.
/// @dev The owner can mint without limit: fine for tests, never for a real
///      asset. Minting emits the standard Transfer event.
contract TestToken is ERC20, ERC20Permit, Ownable {
    uint8 private immutable _decimals;

    /// @param name Token name, also the EIP-712 domain name.
    /// @param symbol Token symbol.
    /// @param decimals_ Number of decimals, e.g. 18 or 6.
    constructor(string memory name, string memory symbol, uint8 decimals_)
        ERC20(name, symbol)
        ERC20Permit(name)
        Ownable(msg.sender)
    {
        _decimals = decimals_;
    }

    /// @notice Decimals chosen at deployment.
    /// @return The number of decimals.
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Mints `amount` to `to`.
    /// @param to Recipient.
    /// @param amount Amount in the token's smallest unit.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
