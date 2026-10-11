// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Escrow} from "../basics/Escrow.sol";

/// @title EscrowFactory
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice Factory pattern: deploys one Escrow per deal, with the caller as
///         buyer, and numbers the deals.
/// @dev A mapping instead of an array, and events for history. Not audited.
contract EscrowFactory {
    /// @notice Number of escrows created so far.
    uint256 public count;
    /// @notice Escrow for each deal number, starting at 0.
    mapping(uint256 => Escrow) public escrows;

    /// @notice A new deal was created.
    event EscrowCreated(
        uint256 indexed dealId,
        address indexed escrow,
        address indexed buyer,
        address seller
    );

    /// @notice Deploys an escrow in which the caller is the buyer.
    /// @param seller Account that will be paid.
    /// @param agent Independent party that confirms or cancels.
    /// @param price Price in wei.
    /// @param deliveryWindow Seconds the agent has after payment.
    /// @return escrow The new escrow contract.
    function createEscrow(
        address seller,
        address agent,
        uint256 price,
        uint256 deliveryWindow
    ) external returns (Escrow escrow) {
        escrow = new Escrow(msg.sender, seller, agent, price, deliveryWindow);
        uint256 dealId = count++;
        escrows[dealId] = escrow;
        emit EscrowCreated(dealId, address(escrow), msg.sender, seller);
    }
}
