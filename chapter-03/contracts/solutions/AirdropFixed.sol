// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AirdropFixed
/// @author Sami BELHADJ, Book 3, Exercise 3.3, contract C fixed
/// @notice Owner-only allocation that adds to what each recipient is owed, and
///         recipients claim their own share.
/// @dev Teaching code, not audited.
contract AirdropFixed is Ownable, ReentrancyGuard {
    /// @notice Most recipients one allocate() call may list.
    uint256 public constant MAX_BATCH = 200;
    /// @notice Wei each recipient can claim.
    mapping(address => uint256) public claimable;
    /// @notice Wei allocated and not yet claimed.
    uint256 public totalAllocated;

    /// @notice The batch is longer than MAX_BATCH.
    error BatchTooLarge(uint256 size);
    /// @notice The contract's balance cannot cover the allocation.
    error InsufficientFunds(uint256 needed, uint256 available);
    /// @notice The caller has nothing to claim.
    error NothingToClaim();
    /// @notice Sending ether failed.
    error TransferFailed();

    /// @notice `recipient` can claim `amount` more wei.
    event Allocated(address indexed recipient, uint256 amount);
    /// @notice `recipient` claimed `amount` wei.
    event Claimed(address indexed recipient, uint256 amount);
    /// @notice `from` funded the airdrop with `amount` wei.
    event Funded(address indexed from, uint256 amount);

    /// @param initialOwner Account that allocates.
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Credits `amount` to each recipient, if the balance covers it.
    /// @param recipients Accounts to credit.
    /// @param amount Wei for each recipient.
    function allocate(
        address[] calldata recipients,
        uint256 amount
    ) external onlyOwner {
        uint256 n = recipients.length;
        if (n > MAX_BATCH) revert BatchTooLarge(n);
        uint256 needed = totalAllocated + n * amount;
        if (needed > address(this).balance) {
            revert InsufficientFunds(needed, address(this).balance);
        }
        totalAllocated = needed;
        for (uint256 i = 0; i < n; ++i) {
            claimable[recipients[i]] += amount;
            emit Allocated(recipients[i], amount);
        }
    }

    /// @notice Sends the caller their allocation.
    function claim() external nonReentrant {
        uint256 amount = claimable[msg.sender];
        if (amount == 0) revert NothingToClaim();
        claimable[msg.sender] = 0;
        totalAllocated -= amount;
        emit Claimed(msg.sender, amount);
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Accepts ether to distribute.
    receive() external payable {
        emit Funded(msg.sender, msg.value);
    }
}
