// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BatchExecutor
/// @notice Delegation target for the EIP-7702 demonstration in Exercise 2.4. An
///         EOA that delegates to this code can run several calls in one
///         transaction.
/// @dev Teaching code, not audited. Only the account itself may call execute, so
///      a callee cannot re-enter it: msg.sender would be the callee. The code
///      keeps no storage, because a delegated EOA's storage outlives any one
///      delegation and could clash with the next delegate's layout.
contract BatchExecutor {
    /// @notice One call in a batch.
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    /// @notice Largest batch accepted, so one signature cannot queue unbounded work.
    uint256 public constant MAX_CALLS = 16;

    /// @notice execute was called by someone other than the account itself.
    error OnlySelf();
    /// @notice A batch is empty or longer than MAX_CALLS.
    error BadBatchSize(uint256 size);
    /// @notice Call `index` of the batch reverted; the whole batch is undone.
    error CallFailed(uint256 index);

    /// @notice Call `index` of a batch succeeded.
    event CallExecuted(uint256 indexed index, address indexed to, uint256 value);

    /// @notice Lets the delegated account keep receiving plain ETH transfers.
    receive() external payable {}

    /// @notice Runs every call in order; if one fails, all are reverted.
    /// @param calls The calls to make, at most MAX_CALLS.
    function execute(Call[] calldata calls) external payable {
        if (msg.sender != address(this)) revert OnlySelf();
        uint256 n = calls.length;
        if (n == 0 || n > MAX_CALLS) revert BadBatchSize(n);
        for (uint256 i; i < n; ++i) {
            Call calldata c = calls[i];
            emit CallExecuted(i, c.to, c.value);  // undone too if the call fails
            (bool ok,) = c.to.call{value: c.value}(c.data);
            if (!ok) revert CallFailed(i);
        }
    }
}
