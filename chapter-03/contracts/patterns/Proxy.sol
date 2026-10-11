// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title HubProxy
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice The proxy users talk to. It stores the implementation address in the
///         slot defined by ERC-1967 and forwards every call with delegatecall.
/// @dev A named wrapper so Hardhat 3 compiles an artifact for the
///      OpenZeppelin proxy.
contract HubProxy is ERC1967Proxy {
    /// @param implementation First implementation (PaymentHubV1).
    /// @param initData Encoded initialize() call, run through the proxy.
    constructor(address implementation, bytes memory initData)
        ERC1967Proxy(implementation, initData)
    {}
}
