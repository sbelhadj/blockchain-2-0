// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title OpenMintToken
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice DELIBERATELY VULNERABLE: anyone can mint. Do not deploy.
contract OpenMintToken {
    /// @notice Balance of each account.
    mapping(address => uint256) public balances;

    /// @notice Mints `amount` to `to`. The missing access check is the bug.
    /// @param to Recipient.
    /// @param amount Amount to mint.
    function mint(address to, uint256 amount) external {
        balances[to] += amount;
    }
}

/// @title RoleMintToken
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice OpenMintToken fixed: only accounts holding MINTER_ROLE can mint.
/// @dev Teaching code, not audited.
contract RoleMintToken is AccessControl {
    /// @notice Role allowed to mint.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice Balance of each account.
    mapping(address => uint256) public balances;

    /// @notice The admin address is zero.
    error ZeroAddress();

    /// @notice `amount` was minted to `to`.
    event Minted(address indexed to, uint256 amount);

    /// @param admin Account that can grant and revoke MINTER_ROLE.
    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Mints `amount` to `to`.
    /// @param to Recipient.
    /// @param amount Amount to mint.
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        balances[to] += amount;
        emit Minted(to, amount);
    }
}
