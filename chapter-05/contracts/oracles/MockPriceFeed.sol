// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title IPriceFeed
/// @notice The subset of Chainlink's AggregatorV3Interface used in this chapter.
interface IPriceFeed {
    /// @notice Decimals of the answer.
    /// @return The number of decimals.
    function decimals() external view returns (uint8);

    /// @notice The latest answer and when it was updated.
    /// @return roundId Round of the answer.
    /// @return answer Price, scaled by decimals().
    /// @return startedAt When the round started.
    /// @return updatedAt When the answer was last updated.
    /// @return answeredInRound Round in which the answer was computed.
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt,
                 uint80 answeredInRound);
}

/// @title MockPriceFeed
/// @author Sami BELHADJ, Book 3, Chapter 5
/// @notice A price feed whose answer the owner sets. 8 decimals, like Chainlink
///         USD feeds.
/// @dev Test double for local runs. Never use it as a real oracle.
contract MockPriceFeed is IPriceFeed, Ownable {
    int256 private _answer;
    uint256 private _updatedAt;
    uint80 private _round;

    /// @notice The owner set a new answer.
    event PriceUpdated(uint80 indexed roundId, int256 answer, uint256 updatedAt);

    /// @param answer First answer, with 8 decimals.
    constructor(int256 answer) Ownable(msg.sender) {
        _setPrice(answer);
    }

    /// @notice Sets the answer and marks it as updated now.
    /// @param answer New answer, with 8 decimals.
    function setPrice(int256 answer) external onlyOwner {
        _setPrice(answer);
    }

    /// @inheritdoc IPriceFeed
    function decimals() external pure returns (uint8) {
        return 8;
    }

    /// @inheritdoc IPriceFeed
    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_round, _answer, _updatedAt, _updatedAt, _round);
    }

    function _setPrice(int256 answer) private {
        _answer = answer;
        _updatedAt = block.timestamp;
        uint80 round = ++_round;
        emit PriceUpdated(round, answer, block.timestamp);
    }
}
