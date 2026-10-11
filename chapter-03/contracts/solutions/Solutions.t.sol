// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TokenSaleFixed} from "./TokenSaleFixed.sol";
import {LotteryFixed} from "./LotteryFixed.sol";
import {AirdropFixed} from "./AirdropFixed.sol";
import {ShipmentTrackerOptimized} from "./ShipmentTrackerOptimized.sol";
import {ShipmentTracker} from "../exercises/ShipmentTracker.sol";

/// @notice Tests for the Exercise 3.3 and 3.4 solutions.
contract SolutionsTest is Test {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    receive() external payable {}

    // ---- TokenSaleFixed --------------------------------------------------

    function test_TokenSaleEdges() public {
        TokenSaleFixed sale = new TokenSaleFixed(address(this));
        vm.expectRevert(TokenSaleFixed.NothingToWithdraw.selector);
        sale.withdraw();
        vm.deal(alice, 10 ether);
        vm.startPrank(alice);
        vm.expectRevert(TokenSaleFixed.ZeroAmount.selector);
        sale.buy(0, 1 ether);
        vm.expectRevert(
            abi.encodeWithSelector(TokenSaleFixed.WrongPayment.selector, 1, 2 ether)
        );
        sale.buy{value: 1}(2, 1 ether);
        sale.buy{value: 2 ether}(2, 1 ether);
        vm.stopPrank();
        assertEq(sale.tokenBalances(alice), 2);
        uint256 before = address(this).balance;
        sale.withdraw();
        assertEq(address(this).balance, before + 2 ether);
    }

    function test_TokenSalePriceCap() public {
        TokenSaleFixed sale = new TokenSaleFixed(address(this));
        sale.setPrice(2 ether);
        vm.deal(alice, 2 ether);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenSaleFixed.PriceAboveLimit.selector, 2 ether, 1 ether
            )
        );
        sale.buy{value: 2 ether}(1, 1 ether);
    }

    function test_TokenSaleOwnerThatRefusesEther() public {
        Refuser refuser = new Refuser();
        TokenSaleFixed sale = new TokenSaleFixed(address(refuser));
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        sale.buy{value: 1 ether}(1, 1 ether);
        vm.prank(address(refuser));
        vm.expectRevert(TokenSaleFixed.TransferFailed.selector);
        sale.withdraw();
    }

    // ---- LotteryFixed ----------------------------------------------------

    function _round() internal returns (LotteryFixed lottery) {
        lottery = new LotteryFixed(1 hours);
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        vm.prank(alice);
        lottery.enter{value: 0.1 ether}();
        vm.prank(bob);
        lottery.enter{value: 0.1 ether}();
    }

    function test_LotteryFullRound() public {
        LotteryFixed lottery = _round();
        vm.expectRevert(LotteryFixed.StillOpen.selector);
        lottery.close();
        vm.expectRevert(LotteryFixed.TooEarly.selector);
        lottery.draw();
        vm.warp(block.timestamp + 1 hours);
        vm.expectRevert(LotteryFixed.AlreadyClosed.selector);
        lottery.enter{value: 0.1 ether}();
        lottery.close();
        vm.expectRevert(LotteryFixed.AlreadyClosed.selector);
        lottery.close();
        vm.expectRevert(LotteryFixed.TooEarly.selector);
        lottery.draw();
        vm.roll(block.number + 6);
        lottery.draw();
        vm.expectRevert(LotteryFixed.AlreadyDrawn.selector);
        lottery.draw();
        address w = lottery.winner();
        vm.prank(w);
        lottery.claim();
        assertEq(w.balance, 1.1 ether);
        vm.prank(w);
        vm.expectRevert(LotteryFixed.NothingToClaim.selector);
        lottery.claim();
    }

    function test_LotteryTicketRulesAndLimits() public {
        LotteryFixed lottery = new LotteryFixed(1 hours);
        vm.expectRevert(LotteryFixed.WrongTicket.selector);
        lottery.enter{value: 1}();
        for (uint160 i = 1; i <= 100; i++) {
            address p = address(i + 0x1000);
            vm.deal(p, 0.1 ether);
            vm.prank(p);
            lottery.enter{value: 0.1 ether}();
        }
        vm.expectRevert(LotteryFixed.Full.selector);
        lottery.enter{value: 0.1 ether}();
        LotteryFixed empty = new LotteryFixed(0);
        vm.expectRevert(LotteryFixed.NoPlayers.selector);
        empty.close();
    }

    function test_LotteryDrawExpiresAndRefusingWinner() public {
        LotteryFixed lottery = _round();
        vm.warp(block.timestamp + 1 hours);
        lottery.close();
        vm.roll(block.number + 300);                // the draw block is too old
        vm.expectRevert(LotteryFixed.DrawExpired.selector);
        lottery.draw();

        Refuser refuser = new Refuser();
        LotteryFixed solo = new LotteryFixed(1 hours);
        vm.deal(address(refuser), 1 ether);
        vm.prank(address(refuser));
        solo.enter{value: 0.1 ether}();
        vm.warp(block.timestamp + 1 hours);
        solo.close();
        vm.roll(block.number + 6);
        solo.draw();
        vm.prank(address(refuser));
        vm.expectRevert(LotteryFixed.TransferFailed.selector);
        solo.claim();
    }

    // ---- AirdropFixed ----------------------------------------------------

    function test_AirdropEdges() public {
        AirdropFixed drop = new AirdropFixed(address(this));
        (bool ok, ) = address(drop).call{value: 2 ether}("");
        assertTrue(ok);
        address[] memory tooMany = new address[](201);
        vm.expectRevert(abi.encodeWithSelector(AirdropFixed.BatchTooLarge.selector, 201));
        drop.allocate(tooMany, 0);
        address[] memory list = new address[](1);
        list[0] = alice;
        drop.allocate(list, 1 ether);
        vm.prank(alice);
        drop.claim();
        assertEq(drop.totalAllocated(), 0);
        vm.prank(alice);
        vm.expectRevert(AirdropFixed.NothingToClaim.selector);
        drop.claim();
        Refuser refuser = new Refuser();
        list[0] = address(refuser);
        drop.allocate(list, 1 ether);
        vm.prank(address(refuser));
        vm.expectRevert(AirdropFixed.TransferFailed.selector);
        drop.claim();
    }

    function testFuzz_AirdropNeverPromisesMoreThanItHolds(
        uint96 funding,
        uint96 amount,
        uint8 n
    ) public {
        AirdropFixed drop = new AirdropFixed(address(this));
        vm.deal(address(this), funding);
        (bool ok, ) = address(drop).call{value: funding}("");
        assertTrue(ok);
        address[] memory list = new address[](bound(n, 1, 10));
        for (uint256 i = 0; i < list.length; i++) list[i] = address(uint160(i + 1));
        try drop.allocate(list, amount) {} catch {}
        assertLe(drop.totalAllocated(), address(drop).balance);
    }

    // ---- ShipmentTrackerOptimized -----------------------------------------

    function test_ShipmentRecorded() public {
        ShipmentTrackerOptimized t = new ShipmentTrackerOptimized();
        t.recordShipment("Rades", "Sfax", 1200, bob, "IN_TRANSIT", 45);
        (uint128 w, , int32 temp, bool delivered, address s, address r) =
            t.shipmentById(1);
        assertEq(w, 1200);
        assertEq(temp, 45);
        assertFalse(delivered);
        assertEq(s, address(this));
        assertEq(r, bob);
        assertEq(t.shipmentCount(), 1);
        ShipmentTracker before = new ShipmentTracker();      // the starting point
        before.recordShipment("Rades", "Sfax", 1200, bob, "IN_TRANSIT", 45);
        assertEq(before.shipmentCount(), t.shipmentCount());
    }
}

/// @notice An account that refuses ether.
contract Refuser {
    receive() external payable {
        revert();
    }
}
