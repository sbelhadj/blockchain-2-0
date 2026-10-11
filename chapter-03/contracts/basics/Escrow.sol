// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Escrow
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice A buyer pays, an agent confirms delivery, the seller is paid. If the
///         agent never acts, the buyer can reclaim the payment after a deadline.
/// @dev Used for types, errors, events, modifiers and the state machine pattern.
///      Payouts are pulled with withdraw(), never pushed. Not audited.
contract Escrow is ReentrancyGuard {
    /// @notice The stages of one deal.
    enum State { AwaitingPayment, AwaitingDelivery, Complete, Refunded }

    /// @notice Account that pays, and may reclaim after the deadline.
    address public immutable buyer;
    /// @notice Account that is paid when delivery is confirmed.
    address public immutable seller;
    /// @notice Independent party that confirms delivery or cancels the deal.
    address public immutable agent;
    /// @notice Price in wei.
    uint256 public immutable price;
    /// @notice Seconds the agent has, after payment, to confirm or refund.
    uint256 public immutable deliveryWindow;

    /// @notice Current stage. Packed with `deadline` in one storage slot.
    State public state;
    /// @notice Time after which the buyer may reclaim the payment.
    uint64 public deadline;
    /// @notice Wei each account can withdraw.
    mapping(address => uint256) public owed;

    /// @notice A party address is zero.
    error ZeroAddress();
    /// @notice The price is zero.
    error ZeroPrice();
    /// @notice The agent is also the buyer or the seller.
    error AgentNotIndependent();
    /// @notice The caller may not take this step.
    error OnlyRole(address caller);
    /// @notice The step is not allowed in the current stage.
    error WrongState(State expected, State actual);
    /// @notice The payment does not match the price.
    error WrongAmount(uint256 sent, uint256 expected);
    /// @notice The buyer tried to reclaim before the deadline.
    error DeadlineNotReached(uint256 deadline);
    /// @notice The caller has nothing to withdraw.
    error NothingOwed(address account);
    /// @notice Sending ether to the caller failed.
    error PaymentFailed();

    /// @notice The buyer paid; the agent must act before `deadline`.
    event Paid(address indexed buyer, uint256 amount, uint64 deadline);
    /// @notice Delivery was confirmed; the seller can withdraw `amount`.
    event Released(address indexed seller, uint256 amount);
    /// @notice The deal was cancelled; the buyer can withdraw `amount`.
    event Refunded(address indexed buyer, uint256 amount);
    /// @notice `account` withdrew `amount` wei.
    event Withdrawn(address indexed account, uint256 amount);

    /// @dev Restricts a function to one party of the deal.
    modifier only(address who) {
        if (msg.sender != who) revert OnlyRole(msg.sender);
        _;
    }

    /// @dev Restricts a function to one state of the state machine.
    modifier inState(State expected) {
        if (state != expected) revert WrongState(expected, state);
        _;
    }

    /// @param buyer_ Account that will pay.
    /// @param seller_ Account that will be paid.
    /// @param agent_ Independent party that confirms or cancels.
    /// @param price_ Price in wei, greater than zero.
    /// @param deliveryWindow_ Seconds the agent has after payment.
    constructor(
        address buyer_,
        address seller_,
        address agent_,
        uint256 price_,
        uint256 deliveryWindow_
    ) {
        if (buyer_ == address(0) || seller_ == address(0) || agent_ == address(0)) {
            revert ZeroAddress();
        }
        if (agent_ == buyer_ || agent_ == seller_) revert AgentNotIndependent();
        if (price_ == 0) revert ZeroPrice();
        buyer = buyer_;
        seller = seller_;
        agent = agent_;
        price = price_;
        deliveryWindow = deliveryWindow_;
    }

    /// @notice The buyer pays exactly `price` into the escrow.
    function pay() external payable only(buyer) inState(State.AwaitingPayment) {
        if (msg.value != price) revert WrongAmount(msg.value, price);
        uint64 due = uint64(block.timestamp + deliveryWindow);
        state = State.AwaitingDelivery;
        deadline = due;
        emit Paid(msg.sender, msg.value, due);
    }

    /// @notice The agent confirms delivery; the seller can then withdraw.
    function confirmDelivery()
        external
        only(agent)
        inState(State.AwaitingDelivery)
    {
        state = State.Complete;
        owed[seller] += price;
        emit Released(seller, price);
    }

    /// @notice Cancels the deal: the agent at any time, or the buyer once the
    ///         deadline has passed without a decision.
    function refund() external inState(State.AwaitingDelivery) {
        if (msg.sender == buyer) {
            if (block.timestamp < deadline) revert DeadlineNotReached(deadline);
        } else if (msg.sender != agent) {
            revert OnlyRole(msg.sender);
        }
        state = State.Refunded;
        owed[buyer] += price;
        emit Refunded(buyer, price);
    }

    /// @notice Sends the caller everything the escrow owes them.
    /// @dev Checks, effects, interactions, plus a reentrancy guard.
    function withdraw() external nonReentrant {
        uint256 amount = owed[msg.sender];
        if (amount == 0) revert NothingOwed(msg.sender);
        owed[msg.sender] = 0;
        emit Withdrawn(msg.sender, amount);
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert PaymentFailed();
    }
}
