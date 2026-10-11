// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Capped} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Pausable} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

/// @title SupplyChainToken (SCT)
/// @author Sami Belhadj, Blockchain 2.0 (Book 3), Lab 3
/// @notice Rewards verified logistics carriers for on-time deliveries, passed
///         quality checks and sustainability compliance. The supply is capped at
///         100 million SCT, holders can burn, an emergency pause stops every
///         transfer, and ERC-2612 permit allows gasless approvals.
/// @dev Teaching code, not audited. Authority is split into four roles so that
///      no single operational key controls everything:
///      - REWARDER_ROLE issues rewards for recorded logistics events,
///      - CARRIER_MANAGER_ROLE verifies and unverifies carriers,
///      - PAUSER_ROLE stops and restarts transfers,
///      - MINTER_ROLE mints treasury supply, always bounded by the cap.
///      The default admin grants and revokes those roles. Handing the admin role
///      to a new account takes two steps separated by a delay
///      (AccessControlDefaultAdminRules), so a mistyped address or a stolen key
///      cannot take over the token in one transaction.
contract SupplyChainToken is
    ERC20,
    ERC20Burnable,
    ERC20Capped,
    ERC20Pausable,
    ERC20Permit,
    AccessControlDefaultAdminRules
{
    /// @notice The three kinds of logistics event that earn a reward.
    enum Reward {
        OnTimeDelivery,
        QualityCheck,
        Sustainability
    }

    /// @notice Role allowed to issue rewards.
    bytes32 public constant REWARDER_ROLE = keccak256("REWARDER_ROLE");
    /// @notice Role allowed to verify and unverify carriers.
    bytes32 public constant CARRIER_MANAGER_ROLE = keccak256("CARRIER_MANAGER_ROLE");
    /// @notice Role allowed to pause and unpause transfers.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @notice Role allowed to mint treasury supply.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Hard cap on total supply: 100 million SCT with 18 decimals.
    uint256 public constant MAX_SUPPLY = 100_000_000 ether;
    /// @notice Supply minted to the treasury at deployment: 10 million SCT.
    uint256 public constant INITIAL_SUPPLY = 10_000_000 ether;
    /// @notice Upper bound for any single reward amount, so a mistaken update
    ///         cannot turn one reward into a large mint.
    uint256 public constant MAX_REWARD = 10_000 ether;

    /// @notice Whether a carrier may receive rewards.
    mapping(address carrier => bool verified) public isVerifiedCarrier;
    /// @notice Number of on-time deliveries rewarded per carrier.
    mapping(address carrier => uint256 count) public deliveryCount;
    /// @notice Whether a logistics event has already been rewarded.
    /// @dev The event id is chosen off-chain, for example the hash of a
    ///      shipment number and the kind of check. Recording it makes rewards
    ///      idempotent: retrying a transaction cannot pay the same event twice.
    mapping(bytes32 eventId => bool done) public rewarded;
    /// @notice Current reward amount for each kind of event.
    mapping(Reward kind => uint256 amount) public rewardAmount;

    /// @notice The address is the zero address where an account is required.
    error ZeroAddress();
    /// @notice The carrier is not verified.
    /// @param carrier The account that was to be rewarded.
    error CarrierNotVerified(address carrier);
    /// @notice The logistics event has already been rewarded.
    /// @param eventId The identifier of the event.
    error AlreadyRewarded(bytes32 eventId);
    /// @notice A reward amount above MAX_REWARD was requested.
    /// @param amount The requested amount.
    /// @param max The maximum allowed.
    error RewardTooLarge(uint256 amount, uint256 max);

    /// @notice Emitted when a carrier is verified or unverified.
    /// @param carrier The carrier.
    /// @param verified The new status.
    /// @param by The account that made the change.
    event CarrierStatusChanged(
        address indexed carrier, bool verified, address indexed by
    );
    /// @notice Emitted when a reward is minted.
    /// @param carrier The rewarded carrier.
    /// @param kind The kind of event.
    /// @param eventId The identifier of the rewarded event.
    /// @param amount The amount minted.
    event RewardIssued(
        address indexed carrier,
        Reward indexed kind,
        bytes32 indexed eventId,
        uint256 amount
    );
    /// @notice Emitted when a reward amount changes.
    /// @param kind The kind of event.
    /// @param oldAmount The previous amount.
    /// @param newAmount The new amount.
    event RewardAmountUpdated(
        Reward indexed kind, uint256 oldAmount, uint256 newAmount
    );
    /// @notice Emitted when treasury supply is minted outside the reward flow.
    /// @param to The recipient.
    /// @param amount The amount minted.
    /// @param by The minter.
    event TreasuryMinted(address indexed to, uint256 amount, address indexed by);

    /// @notice Deploys the token, mints the initial supply and sets up roles.
    /// @dev The admin also receives the four operational roles so the lab can be
    ///      run with one account. Move them to separate keys before real use.
    /// @param admin The default admin and initial holder of every role.
    /// @param treasury The account that receives INITIAL_SUPPLY.
    /// @param adminDelay Seconds a new admin must wait before accepting the role.
    constructor(address admin, address treasury, uint48 adminDelay)
        ERC20("SupplyChainToken", "SCT")
        ERC20Capped(MAX_SUPPLY)
        ERC20Permit("SupplyChainToken")
        AccessControlDefaultAdminRules(adminDelay, admin)
    {
        if (treasury == address(0)) revert ZeroAddress();
        _grantRole(REWARDER_ROLE, admin);
        _grantRole(CARRIER_MANAGER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);

        _setRewardAmount(Reward.OnTimeDelivery, 100 ether);
        _setRewardAmount(Reward.QualityCheck, 50 ether);
        _setRewardAmount(Reward.Sustainability, 200 ether);

        _mint(treasury, INITIAL_SUPPLY);
    }

    /// @notice Verifies or unverifies a carrier.
    /// @param carrier The carrier account.
    /// @param verified True to allow rewards, false to stop them.
    function setCarrier(address carrier, bool verified)
        external
        onlyRole(CARRIER_MANAGER_ROLE)
    {
        if (carrier == address(0)) revert ZeroAddress();
        isVerifiedCarrier[carrier] = verified;
        emit CarrierStatusChanged(carrier, verified, msg.sender);
    }

    /// @notice Mints the reward for one logistics event to a verified carrier.
    /// @dev The cap is enforced by ERC20Capped and the pause by ERC20Pausable,
    ///      both inside _update. Each eventId can be rewarded once.
    /// @param carrier The carrier to reward.
    /// @param kind The kind of event.
    /// @param eventId A unique identifier for the event, chosen off-chain.
    function reward(address carrier, Reward kind, bytes32 eventId)
        external
        onlyRole(REWARDER_ROLE)
    {
        if (!isVerifiedCarrier[carrier]) revert CarrierNotVerified(carrier);
        if (rewarded[eventId]) revert AlreadyRewarded(eventId);
        rewarded[eventId] = true;
        if (kind == Reward.OnTimeDelivery) deliveryCount[carrier] += 1;
        uint256 amount = rewardAmount[kind];
        emit RewardIssued(carrier, kind, eventId, amount);
        _mint(carrier, amount);
    }

    /// @notice Changes the amount paid for one kind of event.
    /// @param kind The kind of event.
    /// @param amount The new amount, at most MAX_REWARD.
    function setRewardAmount(Reward kind, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setRewardAmount(kind, amount);
    }

    /// @notice Mints treasury supply, bounded by the cap.
    /// @dev This is the token's main governance risk: whoever holds MINTER_ROLE
    ///      decides new supply up to the cap. Give it to a multisig or revoke it
    ///      after the initial distribution.
    /// @param to The recipient.
    /// @param amount The amount to mint.
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        emit TreasuryMinted(to, amount, msg.sender);
        _mint(to, amount);
    }

    /// @notice Stops all transfers, mints and burns.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Resumes transfers, mints and burns.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @dev Validates and stores a reward amount, emitting the change.
    function _setRewardAmount(Reward kind, uint256 amount) private {
        if (amount > MAX_REWARD) revert RewardTooLarge(amount, MAX_REWARD);
        emit RewardAmountUpdated(kind, rewardAmount[kind], amount);
        rewardAmount[kind] = amount;
    }

    /// @dev ERC20Capped and ERC20Pausable both extend _update, so every parent
    ///      that defines it must be listed. Solidity runs them in linearized
    ///      order, so both the cap check and the pause check apply.
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Capped, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
