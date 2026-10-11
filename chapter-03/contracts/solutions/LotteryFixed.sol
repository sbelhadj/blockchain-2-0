// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title LotteryFixed
/// @author Sami BELHADJ, Book 3, Exercise 3.3, contract A fixed
/// @notice One round: buy tickets until the deadline, close, draw from a future
///         block hash, and the winner claims the prize.
/// @dev Production code should use a verifiable randomness service (for example
///      Chainlink VRF): a block proposer can still withhold a block to change
///      the result. This version removes the flaws that need no external
///      service. Not audited.
contract LotteryFixed is ReentrancyGuard {
    /// @notice Ticket price.
    uint256 public constant TICKET = 0.1 ether;
    /// @notice Most players in one round, so storage and loops stay bounded.
    uint256 public constant MAX_PLAYERS = 100;
    /// @notice Blocks between closing and the block whose hash decides.
    uint256 public constant DRAW_DELAY = 5;
    /// @notice Time after which no more tickets are sold.
    uint256 public immutable closesAt;
    /// @notice Block whose hash picks the winner, fixed when the round closes.
    uint256 public drawBlock;
    /// @notice Ticket holders.
    address[] public players;
    /// @notice The winner, once drawn.
    address public winner;
    /// @notice Prize each account can claim.
    mapping(address => uint256) public prizes;

    /// @notice The ether sent is not the ticket price.
    error WrongTicket();
    /// @notice The round has MAX_PLAYERS players.
    error Full();
    /// @notice The deadline has not passed.
    error StillOpen();
    /// @notice The round is closed.
    error AlreadyClosed();
    /// @notice The draw block has not been produced.
    error TooEarly();
    /// @notice Nobody bought a ticket.
    error NoPlayers();
    /// @notice The winner is already drawn.
    error AlreadyDrawn();
    /// @notice The draw block is older than 256 blocks.
    error DrawExpired();
    /// @notice The caller has no prize.
    error NothingToClaim();
    /// @notice Sending ether failed.
    error TransferFailed();

    /// @notice `player` bought a ticket.
    event Entered(address indexed player);
    /// @notice The round closed; block `drawBlock` decides.
    event Closed(uint256 drawBlock);
    /// @notice `winner` won `prize` wei.
    event Drawn(address indexed winner, uint256 prize);
    /// @notice `winner` claimed `amount` wei.
    event PrizeClaimed(address indexed winner, uint256 amount);

    /// @param durationSeconds How long tickets are sold.
    constructor(uint256 durationSeconds) {
        closesAt = block.timestamp + durationSeconds;
    }

    /// @notice Buys one ticket.
    function enter() external payable {
        if (block.timestamp >= closesAt) revert AlreadyClosed();
        if (msg.value != TICKET) revert WrongTicket();
        if (players.length >= MAX_PLAYERS) revert Full();
        players.push(msg.sender);
        emit Entered(msg.sender);
    }

    /// @notice Closes the round after the deadline; anyone may call it. The
    ///         draw uses a block not yet produced.
    function close() external {
        if (block.timestamp < closesAt) revert StillOpen();
        if (drawBlock != 0) revert AlreadyClosed();
        if (players.length == 0) revert NoPlayers();
        uint256 target = block.number + DRAW_DELAY;
        drawBlock = target;
        emit Closed(target);
    }

    /// @notice Draws the winner from the hash of the draw block.
    function draw() external {
        if (drawBlock == 0 || block.number <= drawBlock) revert TooEarly();
        if (winner != address(0)) revert AlreadyDrawn();
        bytes32 seed = blockhash(drawBlock);
        if (seed == bytes32(0)) revert DrawExpired(); // older than 256 blocks
        address w = players[uint256(seed) % players.length];
        uint256 prize = address(this).balance;
        winner = w;
        prizes[w] = prize;
        emit Drawn(w, prize);
    }

    /// @notice Sends the caller their prize.
    function claim() external nonReentrant {
        uint256 amount = prizes[msg.sender];
        if (amount == 0) revert NothingToClaim();
        prizes[msg.sender] = 0;
        emit PrizeClaimed(msg.sender, amount);
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
