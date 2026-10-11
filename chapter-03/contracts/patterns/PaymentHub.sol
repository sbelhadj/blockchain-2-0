// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PaymentHub
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice Circuit breaker pattern: a pauser can stop new payments in an
///         emergency. Payees withdraw what they received.
/// @dev Pausing blocks money coming in, never money going out, so a pause can
///      not trap funds. The pauser can pause; only the admin can unpause.
///      Teaching code, not audited.
contract PaymentHub is AccessControl, Pausable, ReentrancyGuard {
    /// @notice Role allowed to pause, for example a monitoring service.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @notice Wei each payee can withdraw.
    mapping(address => uint256) public received;

    /// @notice An address argument is zero.
    error ZeroAddress();
    /// @notice The payment was zero.
    error ZeroAmount();
    /// @notice The caller has nothing to withdraw.
    error NothingToWithdraw();
    /// @notice Sending ether to the caller failed.
    error TransferFailed();

    /// @notice `from` paid `amount` wei to `to`.
    event PaymentRecorded(address indexed from, address indexed to, uint256 amount);
    /// @notice `payee` withdrew `amount` wei.
    event Withdrawn(address indexed payee, uint256 amount);

    /// @param admin Account that manages roles and can unpause.
    /// @param pauser Account that can pause.
    constructor(address admin, address pauser) {
        if (admin == address(0) || pauser == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, pauser);
    }

    /// @notice Pays the ether sent to `to`. Blocked while paused.
    /// @param to Payee.
    function pay(address to) external payable whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (msg.value == 0) revert ZeroAmount();
        received[to] += msg.value;
        emit PaymentRecorded(msg.sender, to, msg.value);
    }

    /// @notice Sends the caller everything they received. Works while paused.
    function withdraw() external nonReentrant {
        uint256 amount = received[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        received[msg.sender] = 0;
        emit Withdrawn(msg.sender, amount);
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Stops new payments.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Resumes payments.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
