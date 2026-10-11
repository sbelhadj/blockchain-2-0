// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PaymentHubV1
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice Version 1 of an upgradeable payment hub behind a UUPS proxy.
/// @dev OpenZeppelin 5 keeps its own state in ERC-7201 namespaced slots, so
///      this contract's variables start at slot 0 and later versions append.
///      The reentrancy guard also uses a namespaced slot. Not audited.
contract PaymentHubV1 is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    /// @notice Total wei paid in through this hub.
    uint256 public totalPayments;

    /// @notice The payment was zero.
    error ZeroAmount();
    /// @notice The recipient address is zero.
    error ZeroAddress();
    /// @notice The hub holds no ether.
    error NothingToWithdraw();
    /// @notice Sending ether failed.
    error TransferFailed();

    /// @notice `from` paid `amount` wei.
    event PaymentReceived(address indexed from, uint256 amount);
    /// @notice The owner withdrew `amount` wei to `to`.
    event FundsWithdrawn(address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();   // nobody can initialize the implementation itself
    }

    /// @notice Sets the owner. Called once, through the proxy.
    /// @param initialOwner Account that can withdraw and upgrade.
    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    /// @notice Pays the ether sent into the hub.
    function pay() external payable {
        if (msg.value == 0) revert ZeroAmount();
        totalPayments += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }

    /// @notice Sends the hub's whole balance to `to`.
    /// @param to Recipient.
    function withdraw(address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();
        emit FundsWithdrawn(to, amount);
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @dev Only the owner may upgrade.
    function _authorizeUpgrade(address) internal override onlyOwner {}
}

/// @title PaymentHubV2
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice Version 2 appends a variable. Existing variables keep their slots.
contract PaymentHubV2 is PaymentHubV1 {
    /// @notice Payments made through payAndCount().
    uint256 public paymentCount;

    /// @notice Pays the ether sent and counts the payment.
    function payAndCount() external payable {
        if (msg.value == 0) revert ZeroAmount();
        totalPayments += msg.value;
        paymentCount += 1;
        emit PaymentReceived(msg.sender, msg.value);
    }

    /// @notice The implementation's version.
    /// @return Always "2".
    function version() external pure returns (string memory) {
        return "2";
    }
}
