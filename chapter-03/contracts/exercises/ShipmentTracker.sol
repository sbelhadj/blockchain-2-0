// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ShipmentTracker
/// @author Sami BELHADJ, Book 3, Exercise 3.4
/// @notice The starting point of Exercise 3.4: correct but deliberately
///         wasteful. Make recordShipment cheaper.
contract ShipmentTracker {
    struct Shipment {
        uint256 id;
        string origin;
        string destination;
        uint256 weight;
        bool isDelivered;
        uint256 createdAt;
        address sender;
        address receiver;
        string status;
        uint256 temperature;
    }

    /// @notice Every shipment, in order.
    Shipment[] public shipments;
    /// @notice The same shipments, by id.
    mapping(uint256 => Shipment) public shipmentById;
    /// @notice Number of shipments recorded.
    uint256 public shipmentCount;

    /// @notice Records a shipment.
    /// @param origin Where it leaves from.
    /// @param destination Where it goes.
    /// @param weight Weight in grams.
    /// @param receiver Account that receives it.
    /// @param status Free-text status.
    /// @param temperature Temperature reading.
    function recordShipment(
        string memory origin,
        string memory destination,
        uint256 weight,
        address receiver,
        string memory status,
        uint256 temperature
    ) public {
        shipmentCount = shipmentCount + 1;
        Shipment memory s = Shipment(
            shipmentCount, origin, destination, weight,
            false, block.timestamp, msg.sender, receiver, status, temperature
        );
        shipments.push(s);
        shipmentById[shipmentCount] = s;
    }
}
