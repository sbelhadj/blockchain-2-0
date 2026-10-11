// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title PatientConsent
/// @author Sami BELHADJ, Book 3, Chapter 4 and Lab 2
/// @notice Patients grant and revoke time-limited consent for registered providers.
/// @dev Nothing medical is stored. A category is a bytes32 code from a published
///      list, a purpose is the hash of a document kept off-chain, and the history
///      lives in events. The admin role changes hands only in two steps with a
///      one-day delay. Pausing stops new consents and access records; revocation
///      is never paused, so a patient can always withdraw consent.
contract PatientConsent is AccessControlDefaultAdminRules, Pausable {
    /// @notice Role held by registered healthcare providers.
    bytes32 public constant PROVIDER_ROLE = keccak256("PROVIDER_ROLE");
    /// @notice Longest consent a patient can grant, in days.
    uint32 public constant MAX_DAYS = 365;
    /// @notice Delay between starting and accepting an admin transfer.
    uint48 public constant ADMIN_DELAY = 1 days;

    /// @notice One consent. Ids start at 1, so 0 means "none".
    struct Consent {
        address patient;     // slot 0 (20 bytes)
        uint64 expiresAt;    // slot 0 (8 bytes)
        bool active;         // slot 0 (1 byte)
        address provider;    // slot 1
        bytes32 category;    // slot 2
        bytes32 purposeHash; // slot 3
    }

    /// @notice Number of consents ever granted; also the id of the latest one.
    uint256 public consentCount;
    /// @notice Consent data by id.
    mapping(uint256 => Consent) public consents;
    /// @notice patient => provider => category => current consent id.
    mapping(address => mapping(address => mapping(bytes32 => uint256)))
        public activeConsentId;

    /// @notice `account` does not hold the provider role.
    error NotProvider(address account);
    /// @notice A consent lasts from 1 to MAX_DAYS days.
    error InvalidDuration(uint32 durationDays);
    /// @notice A provider cannot consent to itself.
    error SelfConsent();
    /// @notice Only the patient who granted consent `consentId` can revoke it.
    error NotYourConsent(uint256 consentId);
    /// @notice Consent `consentId` was already revoked or replaced.
    error AlreadyInactive(uint256 consentId);
    /// @notice No current consent covers this patient, provider and category.
    error NoActiveConsent(address patient, address provider, bytes32 category);

    /// @notice A patient granted consent `consentId`.
    event ConsentGranted(
        uint256 indexed consentId,
        address indexed patient,
        address indexed provider,
        bytes32 category,
        uint64 expiresAt,
        bytes32 purposeHash
    );
    /// @notice Consent `consentId` was revoked or replaced.
    event ConsentRevoked(
        uint256 indexed consentId, address indexed patient, address indexed provider
    );
    /// @notice A provider recorded an access to a patient's data.
    event DataAccessed(
        address indexed patient, address indexed provider, bytes32 indexed category,
        bytes32 action
    );

    /// @param admin Account that registers providers and can pause.
    constructor(address admin) AccessControlDefaultAdminRules(ADMIN_DELAY, admin) {}

    /// @notice Grants consent. Replaces any earlier consent for the same provider
    ///         and category, and records the replacement as a revocation.
    /// @param provider Registered provider receiving consent.
    /// @param category Published category code, such as keccak256("LAB_RESULTS").
    /// @param durationDays Validity in days, 1 to MAX_DAYS.
    /// @param purposeHash Hash of the off-chain document stating the purpose.
    /// @return id Id of the new consent.
    function grantConsent(
        address provider,
        bytes32 category,
        uint32 durationDays,
        bytes32 purposeHash
    ) external whenNotPaused returns (uint256 id) {
        if (!hasRole(PROVIDER_ROLE, provider)) revert NotProvider(provider);
        if (provider == msg.sender) revert SelfConsent();
        if (durationDays == 0 || durationDays > MAX_DAYS) {
            revert InvalidDuration(durationDays);
        }

        uint256 previous = activeConsentId[msg.sender][provider][category];
        if (previous != 0 && consents[previous].active) {
            consents[previous].active = false;
            emit ConsentRevoked(previous, msg.sender, provider);
        }

        id = ++consentCount;
        uint64 expiresAt = uint64(block.timestamp + uint256(durationDays) * 1 days);
        consents[id] =
            Consent(msg.sender, expiresAt, true, provider, category, purposeHash);
        activeConsentId[msg.sender][provider][category] = id;

        emit ConsentGranted(
            id, msg.sender, provider, category, expiresAt, purposeHash
        );
    }

    /// @notice Revokes a consent. Works even while the contract is paused.
    /// @param id Consent to revoke; the caller must be its patient.
    function revokeConsent(uint256 id) external {
        Consent storage c = consents[id];
        if (c.patient != msg.sender) revert NotYourConsent(id);
        if (!c.active) revert AlreadyInactive(id);
        c.active = false;
        delete activeConsentId[msg.sender][c.provider][c.category];
        emit ConsentRevoked(id, msg.sender, c.provider);
    }

    /// @notice True if `patient` currently consents to `provider` reading
    ///         `category`, and `provider` is still registered.
    /// @param patient Patient account.
    /// @param provider Provider account.
    /// @param category Category code.
    /// @return Whether access is allowed now.
    function hasActiveConsent(address patient, address provider, bytes32 category)
        public
        view
        returns (bool)
    {
        uint256 id = activeConsentId[patient][provider][category];
        if (id == 0 || !hasRole(PROVIDER_ROLE, provider)) return false;
        Consent storage c = consents[id];
        return c.active && c.expiresAt > block.timestamp;
    }

    /// @notice A provider records an access to a patient's data. Reverts
    ///         without consent.
    /// @param patient Patient whose data was accessed.
    /// @param category Category code of the data.
    /// @param action What was done, such as keccak256("READ").
    function recordAccess(address patient, bytes32 category, bytes32 action)
        external
        whenNotPaused
        onlyRole(PROVIDER_ROLE)
    {
        if (!hasActiveConsent(patient, msg.sender, category)) {
            revert NoActiveConsent(patient, msg.sender, category);
        }
        emit DataAccessed(patient, msg.sender, category, action);
    }

    /// @notice Stops new consents and access records. Revocation still works.
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Resumes normal operation.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
