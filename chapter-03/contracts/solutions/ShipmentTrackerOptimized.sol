// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ShipmentTrackerOptimized
/// @author Sami BELHADJ, Book 3, Exercise 3.4 solution
/// @notice Strings move to an event; one mapping instead of array + mapping;
///         small fields packed into one slot; calldata parameters.
/// @dev Teaching code, not audited.
contract ShipmentTrackerOptimized {
    struct Shipment {
        uint128 weight; // slot 0
        uint64 createdAt; // slot 0
        int32 temperature; // slot 0 (tenths of a degree)
        bool isDelivered; // slot 0
        address sender; // slot 1
        address receiver; // slot 2
    }

    /// @notice Shipments by id, starting at 1.
    mapping(uint256 => Shipment) public shipmentById;
    /// @notice Number of shipments recorded.
    uint256 public shipmentCount;

    /// @notice A shipment was recorded; the strings live only here.
    event ShipmentRecorded(
        uint256 indexed id,
        address indexed sender,
        address indexed receiver,
        string origin,
        string destination,
        string status
    );

    /// @notice Records a shipment.
    /// @param origin Where it leaves from.
    /// @param destination Where it goes.
    /// @param weight Weight in grams.
    /// @param receiver Account that receives it.
    /// @param status Free-text status.
    /// @param temperature Temperature in tenths of a degree.
    function recordShipment(
        string calldata origin,
        string calldata destination,
        uint128 weight,
        address receiver,
        string calldata status,
        int32 temperature
    ) external {
        uint256 id = ++shipmentCount;
        shipmentById[id] = Shipment(
            weight,
            uint64(block.timestamp),
            temperature,
            false,
            msg.sender,
            receiver
        );
        emit ShipmentRecorded(
            id,
            msg.sender,
            receiver,
            origin,
            destination,
            status
        );
    }
}
