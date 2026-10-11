// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BalanceBook} from "./BalanceBook.sol";
import {ShipmentLogWide, ShipmentLogPacked} from "./ShipmentLogs.sol";

/// @notice Both versions of each gas example must behave the same.
contract GasExamplesTest is Test {
    function testFuzz_DebitsAgree(uint96 deposit, uint96 debit) public {
        BalanceBook a = new BalanceBook();
        BalanceBook b = new BalanceBook();
        vm.deal(address(this), uint256(deposit) * 2);
        a.deposit{value: deposit}();
        b.deposit{value: deposit}();
        if (debit > deposit) {
            vm.expectRevert(BalanceBook.Insufficient.selector);
            a.debitRepeated(debit);
            vm.expectRevert(BalanceBook.Insufficient.selector);
            b.debitCached(debit);
        } else {
            a.debitRepeated(debit);
            b.debitCached(debit);
            assertEq(a.balances(address(this)), b.balances(address(this)));
        }
    }

    function testFuzz_LayoutsStoreTheSameData(uint256 id, uint256 w, bool f) public {
        ShipmentLogWide wide = new ShipmentLogWide();
        ShipmentLogPacked packed = new ShipmentLogPacked();
        wide.record(id, w, f);
        packed.record(id, w, f);
        (uint256 w1, bool f1, , address s1, ) = wide.shipments(id);
        (uint256 w2, , address s2, , bool f2) = packed.shipments(id);
        assertEq(w1, w2);
        assertEq(s1, s2);
        assertEq(f1, f2);
    }
}
