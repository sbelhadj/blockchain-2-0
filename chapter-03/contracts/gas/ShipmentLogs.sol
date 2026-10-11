// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ShipmentLogWide
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice Field order decides how many 32-byte slots a struct uses. This
///         layout needs four slots.
contract ShipmentLogWide {
    struct Shipment {
        uint256 weight;     // slot 0
        bool fragile;       // slot 1 (alone: the next field does not fit beside it)
        uint256 id;         // slot 2
        address sender;     // slot 3
        uint64 createdAt;   // slot 3 (packed beside sender)
    }

    /// @notice Shipments by id.
    mapping(uint256 => Shipment) public shipments;

    /// @notice A shipment was recorded.
    event ShipmentRecorded(uint256 indexed id, address indexed sender);

    /// @notice Records a shipment.
    /// @param id Shipment id.
    /// @param weight Weight in grams.
    /// @param fragile Whether it needs careful handling.
    function record(uint256 id, uint256 weight, bool fragile) external {
        uint64 nowTs = uint64(block.timestamp);
        shipments[id] = Shipment(weight, fragile, id, msg.sender, nowTs);
        emit ShipmentRecorded(id, msg.sender);
    }
}

/// @title ShipmentLogPacked
/// @author Sami BELHADJ, Book 3, Chapter 3
/// @notice The same fields reordered into three slots.
contract ShipmentLogPacked {
    struct Shipment {
        uint256 weight;     // slot 0
        uint256 id;         // slot 1
        address sender;     // slot 2: 20 bytes
        uint64 createdAt;   // slot 2: 8 bytes
        bool fragile;       // slot 2: 1 byte (29 of 32 bytes used)
    }

    /// @notice Shipments by id.
    mapping(uint256 => Shipment) public shipments;

    /// @notice A shipment was recorded.
    event ShipmentRecorded(uint256 indexed id, address indexed sender);

    /// @notice Records a shipment.
    /// @param id Shipment id.
    /// @param weight Weight in grams.
    /// @param fragile Whether it needs careful handling.
    function record(uint256 id, uint256 weight, bool fragile) external {
        uint64 nowTs = uint64(block.timestamp);
        shipments[id] = Shipment(weight, id, msg.sender, nowTs, fragile);
        emit ShipmentRecorded(id, msg.sender);
    }
}
