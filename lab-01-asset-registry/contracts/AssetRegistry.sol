// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AssetRegistry
/// @author Sami BELHADJ, Book 3, Lab 1
/// @notice Registers assets from four industries and tracks their ownership
///         and status.
/// @dev Teaching contract for Chapters 2, 3 and 6. Not audited. Ownership of the
///      registry moves in two steps, and the owner can pause registrations,
///      transfers and status changes in an emergency. Fee withdrawal is never
///      paused, so collected fees cannot be trapped.
contract AssetRegistry is Ownable2Step, Pausable, ReentrancyGuard {
    // ------------------------------------------------------------
    // Types
    // ------------------------------------------------------------

    /// @notice Life-cycle status of an asset.
    enum AssetStatus {
        Registered,
        Active,
        InTransit,
        Maintenance,
        Decommissioned
    }

    /// @notice Sector an asset belongs to.
    enum Industry {
        Healthcare,
        Logistics,
        Finance,
        Industrial
    }

    /// @notice Everything the registry stores about one asset.
    /// @dev industry, status and currentOwner share one slot; registeredBy and
    ///      registrationTime share the next one. uint64 timestamps last until
    ///      the year 584 billion.
    struct Asset {
        uint256 id;
        string name;
        string description;
        Industry industry;
        AssetStatus status;
        address currentOwner;
        address registeredBy;
        uint64 registrationTime;
        uint64 lastUpdated;
        string metadataURI;
        bool exists;
    }

    /// @notice One change of ownership.
    struct TransferRecord {
        address from;
        address to;
        uint256 timestamp;
        string reason;
    }

    // ------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------

    /// @notice `caller` is neither the owner nor an authorized registrar.
    error NotAuthorizedRegistrar(address caller);
    /// @notice No asset has id `assetId`.
    error AssetNotFound(uint256 assetId);
    /// @notice `caller` does not own asset `assetId`.
    error NotAssetOwner(uint256 assetId, address caller);
    /// @notice The registration fee must be paid exactly.
    error IncorrectFee(uint256 sent, uint256 required);
    /// @notice An asset needs a name.
    error EmptyName();
    /// @notice A transfer needs a new, non-zero owner.
    error InvalidNewOwner(address newOwner);
    /// @notice A decommissioned asset can no longer change.
    error AssetDecommissioned(uint256 assetId);
    /// @notice The asset already has status `status`.
    error StatusUnchanged(uint256 assetId, AssetStatus status);
    /// @notice A registrar address cannot be zero.
    error ZeroAddress();
    /// @notice The contract holds no fees.
    error NoFeesToWithdraw();
    /// @notice The owner rejected the ether sent by withdrawFees.
    error WithdrawalFailed();

    // ------------------------------------------------------------
    // State
    // ------------------------------------------------------------

    uint256 private _nextAssetId;
    /// @notice Number of assets ever registered.
    uint256 public totalAssets;
    /// @notice Fee in wei that every registration must pay exactly.
    uint256 public registrationFee;

    /// @notice Asset data by id.
    mapping(uint256 => Asset) public assets;
    mapping(uint256 => TransferRecord[]) private _transferHistory;
    mapping(address => uint256[]) private _ownerAssets;
    /// @dev Position of an asset id in its owner's array, for swap-and-pop removal.
    mapping(uint256 => uint256) private _ownerAssetIndex;
    /// @notice Accounts allowed to register assets, besides the owner.
    mapping(address => bool) public authorizedRegistrars;

    // ------------------------------------------------------------
    // Events
    // ------------------------------------------------------------

    /// @notice Asset `assetId` was registered and is owned by `owner`.
    event AssetRegistered(
        uint256 indexed assetId,
        string name,
        Industry industry,
        address indexed owner
    );
    /// @notice Asset `assetId` moved from `from` to `to`.
    event AssetTransferred(
        uint256 indexed assetId,
        address indexed from,
        address indexed to,
        string reason
    );
    /// @notice Asset `assetId` changed status.
    event AssetStatusChanged(
        uint256 indexed assetId,
        AssetStatus oldStatus,
        AssetStatus newStatus
    );
    /// @notice `registrar` may now register assets.
    event RegistrarAuthorized(address indexed registrar);
    /// @notice `registrar` may no longer register assets.
    event RegistrarRevoked(address indexed registrar);
    /// @notice The registration fee changed.
    event RegistrationFeeUpdated(uint256 oldFee, uint256 newFee);
    /// @notice `amount` wei of fees went to `to`.
    event FeesWithdrawn(address indexed to, uint256 amount);

    // ------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------

    /// @dev Restricts a function to the owner and authorized registrars.
    modifier onlyRegistrar() {
        _checkRegistrar();
        _;
    }

    /// @dev Restricts a function to assets that exist.
    modifier assetExists(uint256 assetId) {
        _checkExists(assetId);
        _;
    }

    /// @dev Restricts a function to the current owner of an asset.
    modifier onlyAssetOwner(uint256 assetId) {
        _checkAssetOwner(assetId);
        _;
    }

    // ------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------

    /// @param initialFee Registration fee in wei.
    constructor(uint256 initialFee) Ownable(msg.sender) {
        registrationFee = initialFee;
        authorizedRegistrars[msg.sender] = true;
        emit RegistrarAuthorized(msg.sender);
        emit RegistrationFeeUpdated(0, initialFee);
    }

    // ------------------------------------------------------------
    // Core functions
    // ------------------------------------------------------------

    /// @notice Registers a new asset owned by the caller.
    /// @param name Short name; must not be empty.
    /// @param description Free-text description.
    /// @param industry Sector of the asset.
    /// @param metadataURI Link to off-chain documents, such as a certificate.
    /// @return assetId Id of the new asset.
    function registerAsset(
        string calldata name,
        string calldata description,
        Industry industry,
        string calldata metadataURI
    ) external payable onlyRegistrar whenNotPaused returns (uint256 assetId) {
        if (msg.value != registrationFee)
            revert IncorrectFee(msg.value, registrationFee);
        if (bytes(name).length == 0) revert EmptyName();

        assetId = _nextAssetId++;
        totalAssets++;

        assets[assetId] = Asset({
            id: assetId,
            name: name,
            description: description,
            industry: industry,
            status: AssetStatus.Registered,
            currentOwner: msg.sender,
            registeredBy: msg.sender,
            registrationTime: uint64(block.timestamp),
            lastUpdated: uint64(block.timestamp),
            metadataURI: metadataURI,
            exists: true
        });

        _addToOwner(msg.sender, assetId);

        emit AssetRegistered(assetId, name, industry, msg.sender);
    }

    /// @notice Moves an asset to a new owner and records why.
    /// @param assetId Asset to move.
    /// @param newOwner Receiving account; not zero and not the caller.
    /// @param reason Free-text reason kept in the transfer history.
    function transferAsset(
        uint256 assetId,
        address newOwner,
        string calldata reason
    ) external whenNotPaused assetExists(assetId) onlyAssetOwner(assetId) {
        if (newOwner == address(0) || newOwner == msg.sender)
            revert InvalidNewOwner(newOwner);
        Asset storage a = assets[assetId];
        if (a.status == AssetStatus.Decommissioned)
            revert AssetDecommissioned(assetId);

        a.currentOwner = newOwner;
        a.lastUpdated = uint64(block.timestamp);

        _transferHistory[assetId].push(
            TransferRecord({
                from: msg.sender,
                to: newOwner,
                timestamp: block.timestamp,
                reason: reason
            })
        );

        _removeFromOwner(msg.sender, assetId);
        _addToOwner(newOwner, assetId);

        emit AssetTransferred(assetId, msg.sender, newOwner, reason);
    }

    /// @notice Changes the status of an asset. Decommissioning is final.
    /// @param assetId Asset to update.
    /// @param newStatus New status; must differ from the current one.
    function updateStatus(
        uint256 assetId,
        AssetStatus newStatus
    ) external whenNotPaused assetExists(assetId) onlyAssetOwner(assetId) {
        Asset storage a = assets[assetId];
        AssetStatus oldStatus = a.status;
        if (oldStatus == AssetStatus.Decommissioned)
            revert AssetDecommissioned(assetId);
        if (newStatus == oldStatus) revert StatusUnchanged(assetId, newStatus);

        a.status = newStatus;
        a.lastUpdated = uint64(block.timestamp);

        emit AssetStatusChanged(assetId, oldStatus, newStatus);
    }

    // ------------------------------------------------------------
    // Views
    // ------------------------------------------------------------

    /// @notice Full record of one asset.
    /// @param assetId Asset to read.
    /// @return The stored asset.
    function getAsset(
        uint256 assetId
    ) external view assetExists(assetId) returns (Asset memory) {
        return assets[assetId];
    }

    /// @notice Every transfer of one asset, oldest first.
    /// @dev For long histories, read the AssetTransferred events instead.
    /// @param assetId Asset to read.
    /// @return The transfer records.
    function getTransferHistory(
        uint256 assetId
    ) external view assetExists(assetId) returns (TransferRecord[] memory) {
        return _transferHistory[assetId];
    }

    /// @notice Ids of every asset `account` currently owns, in no fixed order.
    /// @param account Owner to look up.
    /// @return The asset ids.
    function getOwnerAssets(
        address account
    ) external view returns (uint256[] memory) {
        return _ownerAssets[account];
    }

    // ------------------------------------------------------------
    // Admin
    // ------------------------------------------------------------

    /// @notice Lets `registrar` register assets.
    /// @param registrar Account to authorize; not zero.
    function authorizeRegistrar(address registrar) external onlyOwner {
        if (registrar == address(0)) revert ZeroAddress();
        authorizedRegistrars[registrar] = true;
        emit RegistrarAuthorized(registrar);
    }

    /// @notice Stops `registrar` from registering assets.
    /// @param registrar Account to revoke.
    function revokeRegistrar(address registrar) external onlyOwner {
        authorizedRegistrars[registrar] = false;
        emit RegistrarRevoked(registrar);
    }

    /// @notice Sets the fee for future registrations.
    /// @param newFee Fee in wei.
    function updateRegistrationFee(uint256 newFee) external onlyOwner {
        emit RegistrationFeeUpdated(registrationFee, newFee);
        registrationFee = newFee;
    }

    /// @notice Stops registrations, transfers and status changes.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes normal operation.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sends every collected fee to the owner. Works while paused.
    /// @dev Uses call, not transfer: transfer forwards only 2,300 gas, which fails
    ///      when the owner is a smart account or an EOA with an EIP-7702 delegation.
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFeesToWithdraw();
        emit FeesWithdrawn(owner(), balance);
        (bool ok, ) = payable(owner()).call{value: balance}("");
        if (!ok) revert WithdrawalFailed();
    }

    // ------------------------------------------------------------
    // Internal
    // ------------------------------------------------------------

    function _checkRegistrar() private view {
        if (!authorizedRegistrars[msg.sender] && msg.sender != owner()) {
            revert NotAuthorizedRegistrar(msg.sender);
        }
    }

    function _checkExists(uint256 assetId) private view {
        if (!assets[assetId].exists) revert AssetNotFound(assetId);
    }

    function _checkAssetOwner(uint256 assetId) private view {
        if (assets[assetId].currentOwner != msg.sender)
            revert NotAssetOwner(assetId, msg.sender);
    }

    function _addToOwner(address account, uint256 assetId) private {
        _ownerAssetIndex[assetId] = _ownerAssets[account].length;
        _ownerAssets[account].push(assetId);
    }

    function _removeFromOwner(address account, uint256 assetId) private {
        uint256[] storage list = _ownerAssets[account];
        uint256 index = _ownerAssetIndex[assetId];
        uint256 lastId = list[list.length - 1];
        list[index] = lastId;
        _ownerAssetIndex[lastId] = index;
        list.pop();
        delete _ownerAssetIndex[assetId];
    }
}
