// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Lottery
/// @author Sami BELHADJ, Book 3, Exercise 3.3, contract A
/// @notice DELIBERATELY VULNERABLE: contains the flaws Exercise 3.3 asks you to
///         find. Do not deploy. The fixed version is LotteryFixed.
contract Lottery {
    /// @notice Everyone who bought a ticket.
    address[] public players;

    /// @notice Buys one ticket for 0.1 ether.
    function enter() external payable {
        require(msg.value == 0.1 ether, "Ticket is 0.1 ETH");
        players.push(msg.sender);
    }

    /// @notice Picks a winner and pays out the whole balance.
    function pickWinner() external {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp)));
        uint256 index = seed % players.length;
        payable(players[index]).transfer(address(this).balance);
        delete players;
    }
}
