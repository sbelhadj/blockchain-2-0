// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PatientConsent
 * @notice Manages patient consent for healthcare data sharing.
 * @dev Patients grant/revoke time-limited access to their records.
 *      The actual medical data stays off-chain. This contract only
 *      manages permissions and creates an immutable audit trail.
 */
/// Earlier draft, kept only to reproduce its consent-id-zero bug in a test. Do not deploy.
contract PatientConsentDraft is AccessControl, ReentrancyGuard {

    bytes32 public constant PROVIDER_ROLE = keccak256("PROVIDER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct ConsentRecord {
        uint256 id;
        address patient;
        address provider;
        string dataCategory;
        uint256 grantedAt;
        uint256 expiresAt;
        bool isActive;
        string purpose;
    }

    struct AccessLog {
        address accessor;
        uint256 timestamp;
        string action;
        string dataCategory;
    }

    uint256 private _nextConsentId;

    mapping(address => uint256[]) private _patientConsents;
    mapping(uint256 => ConsentRecord) public consents;
    mapping(address => AccessLog[]) private _accessLogs;
    mapping(address => mapping(address => mapping(string => uint256))) private _activeConsent;

    /// @notice A patient granted consent.
    event ConsentGranted(
        uint256 indexed consentId,
        address indexed patient,
        address indexed provider,
        string dataCategory,
        uint256 expiresAt
    );

    /// @notice A patient revoked consent.
    event ConsentRevoked(
        uint256 indexed consentId,
        address indexed patient,
        address indexed provider
    );

    /// @notice A provider logged an access.
    event DataAccessed(
        address indexed patient,
        address indexed accessor,
        string action,
        string dataCategory,
        uint256 timestamp
    );

    /// @notice Makes the deployer the admin.
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /// @notice Grants consent to a provider.
    /// @dev Flaw kept on purpose: ids start at 0, the same value an empty mapping returns,
    ///      and the provider is never checked against PROVIDER_ROLE.
    function grantConsent(
        address provider,
        string calldata dataCategory,
        uint256 durationDays,
        string calldata purpose
    ) external returns (uint256) {
        require(provider != address(0), "Invalid provider address");
        require(provider != msg.sender, "Cannot grant consent to yourself");
        require(durationDays > 0 && durationDays <= 365, "Duration: 1-365 days");
        require(bytes(dataCategory).length > 0, "Category cannot be empty");

        uint256 consentId = _nextConsentId++;
        uint256 expiresAt = block.timestamp + (durationDays * 1 days);

        consents[consentId] = ConsentRecord({
            id: consentId,
            patient: msg.sender,
            provider: provider,
            dataCategory: dataCategory,
            grantedAt: block.timestamp,
            expiresAt: expiresAt,
            isActive: true,
            purpose: purpose
        });

        _patientConsents[msg.sender].push(consentId);
        _activeConsent[msg.sender][provider][dataCategory] = consentId;

        emit ConsentGranted(consentId, msg.sender, provider, dataCategory, expiresAt);

        return consentId;
    }

    /// @notice Revokes one of the caller's consents.
    function revokeConsent(uint256 consentId) external {
        ConsentRecord storage consent = consents[consentId];
        require(consent.patient == msg.sender, "Not your consent");
        require(consent.isActive, "Already revoked");

        consent.isActive = false;
        delete _activeConsent[msg.sender][consent.provider][consent.dataCategory];

        emit ConsentRevoked(consentId, msg.sender, consent.provider);
    }

    /// @notice True if a consent is active.
    /// @dev Flaw kept on purpose: a missing entry reads as id 0, which is a real
    ///      consent once anyone has granted one, so unrelated pairs can pass.
    function hasActiveConsent(
        address patient,
        address provider,
        string calldata dataCategory
    ) external view returns (bool) {
        uint256 consentId = _activeConsent[patient][provider][dataCategory];
        ConsentRecord storage consent = consents[consentId];
        return consent.isActive && consent.expiresAt > block.timestamp;
    }

    /// @notice Logs an access in storage and in an event.
    /// @dev Flaw kept on purpose: never checks consent, and stores what an
    ///      event already records.
    function logAccess(
        address patient,
        string calldata action,
        string calldata dataCategory
    ) external onlyRole(PROVIDER_ROLE) {
        _accessLogs[patient].push(AccessLog({
            accessor: msg.sender,
            timestamp: block.timestamp,
            action: action,
            dataCategory: dataCategory
        }));

        emit DataAccessed(patient, msg.sender, action, dataCategory, block.timestamp);
    }

    /// @notice Every consent the caller granted.
    /// @dev Unbounded loop over an ever-growing array.
    function getMyConsents() external view returns (ConsentRecord[] memory) {
        uint256[] storage ids = _patientConsents[msg.sender];
        ConsentRecord[] memory result = new ConsentRecord[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = consents[ids[i]];
        }
        return result;
    }

    /// @notice Every access logged for the caller.
    function getMyAccessLogs() external view returns (AccessLog[] memory) {
        return _accessLogs[msg.sender];
    }

    /// @notice Gives `provider` the provider role.
    function registerProvider(address provider) external onlyRole(ADMIN_ROLE) {
        _grantRole(PROVIDER_ROLE, provider);
    }
}
