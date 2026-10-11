// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleStorage} from "./SimpleStorage.sol";
import {SimpleStorageV2} from "../solutions/SimpleStorageV2.sol";

/// @notice Tests for SimpleStorage and the Exercise 3.1 solution.
contract SimpleStorageTest is Test {
    event ValueChanged(address indexed by, uint256 oldValue, uint256 newValue);

    function testFuzz_SetThenGet(uint256 a, uint256 b) public {
        SimpleStorage s = new SimpleStorage();
        s.set(a);
        vm.expectEmit(address(s));
        emit ValueChanged(address(this), a, b);
        s.set(b);
        assertEq(s.get(), b);
    }

    function test_V2IncrementCountsWrites() public {
        SimpleStorageV2 s = new SimpleStorageV2();
        s.set(41);
        s.increment();
        assertEq(s.get(), 42);
        assertEq(s.setCount(), 2);
    }
}
