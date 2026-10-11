// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PushPayout
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice DELIBERATELY VULNERABLE: pushes payments in a loop, so one failing
///         recipient blocks everyone. Do not deploy.
contract PushPayout {
    /// @notice Sends `amount` to every recipient in turn.
    /// @param recipients Accounts to pay.
    /// @param amount Wei for each recipient.
    function payAll(address[] calldata recipients, uint256 amount)
        external
        payable
    {
        for (uint256 i = 0; i < recipients.length; i++) {
            (bool ok,) = recipients[i].call{value: amount}("");
            require(ok, "Payout failed");
        }
    }
}

/// @title PullPayout
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice PushPayout fixed: record what each recipient is owed, and let each
///         one withdraw separately.
/// @dev Teaching code, not audited.
contract PullPayout is ReentrancyGuard {
    /// @notice Most recipients one allocate() call may list.
    uint256 public constant MAX_BATCH = 200;
    /// @notice Wei each recipient can withdraw.
    mapping(address => uint256) public owed;

    /// @notice The batch is longer than MAX_BATCH.
    error BatchTooLarge(uint256 size);
    /// @notice The ether sent does not match recipients x amount.
    error WrongFunding(uint256 sent, uint256 required);
    /// @notice The caller has nothing to withdraw.
    error NothingOwed();
    /// @notice Sending ether to the caller failed.
    error TransferFailed();

    /// @notice `recipient` can now withdraw `amount` more wei.
    event Allocated(address indexed recipient, uint256 amount);
    /// @notice `recipient` withdrew `amount` wei.
    event Withdrawn(address indexed recipient, uint256 amount);

    /// @notice Credits `amount` to each recipient. The caller must send exactly
    ///         recipients.length x amount.
    /// @param recipients Accounts to credit.
    /// @param amount Wei for each recipient.
    function allocate(address[] calldata recipients, uint256 amount)
        external
        payable
    {
        uint256 n = recipients.length;
        if (n > MAX_BATCH) revert BatchTooLarge(n);
        uint256 required = n * amount;
        if (msg.value != required) revert WrongFunding(msg.value, required);
        for (uint256 i = 0; i < n; ++i) {
            owed[recipients[i]] += amount;
            emit Allocated(recipients[i], amount);
        }
    }

    /// @notice Sends the caller everything they are owed.
    function withdraw() external nonReentrant {
        uint256 amount = owed[msg.sender];
        if (amount == 0) revert NothingOwed();
        owed[msg.sender] = 0;
        emit Withdrawn(msg.sender, amount);
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}

/// @title RejectingRecipient
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice A recipient that refuses ether, used by tests to show the denial of
///         service in PushPayout.
contract RejectingRecipient {
    /// @notice Every incoming payment is refused.
    error Rejected();

    /// @notice Refuses every plain ether transfer.
    receive() external payable {
        revert Rejected();
    }
}
