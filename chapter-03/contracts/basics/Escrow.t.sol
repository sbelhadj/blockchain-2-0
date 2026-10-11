// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Escrow} from "./Escrow.sol";

/// @notice Unit and fuzz tests for Escrow. This contract plays the buyer.
contract EscrowTest is Test {
    Escrow escrow;
    address seller = makeAddr("seller");
    address agent = makeAddr("agent");
    uint256 constant PRICE = 1 ether;
    uint256 constant WINDOW = 7 days;

    receive() external payable {}

    function setUp() public {
        escrow = new Escrow(address(this), seller, agent, PRICE, WINDOW);
        vm.deal(address(this), 10 ether);
    }

    function test_ConstructorRejectsBadParties() public {
        vm.expectRevert(Escrow.ZeroAddress.selector);
        new Escrow(address(0), seller, agent, PRICE, WINDOW);
        vm.expectRevert(Escrow.ZeroAddress.selector);
        new Escrow(address(this), address(0), agent, PRICE, WINDOW);
        vm.expectRevert(Escrow.ZeroAddress.selector);
        new Escrow(address(this), seller, address(0), PRICE, WINDOW);
        vm.expectRevert(Escrow.AgentNotIndependent.selector);
        new Escrow(address(this), seller, address(this), PRICE, WINDOW);
        vm.expectRevert(Escrow.AgentNotIndependent.selector);
        new Escrow(address(this), seller, seller, PRICE, WINDOW);
        vm.expectRevert(Escrow.ZeroPrice.selector);
        new Escrow(address(this), seller, agent, 0, WINDOW);
    }

    function test_HappyPathSellerWithdraws() public {
        escrow.pay{value: PRICE}();
        assertEq(escrow.deadline(), block.timestamp + WINDOW);
        vm.prank(agent);
        escrow.confirmDelivery();
        assertEq(uint8(escrow.state()), uint8(Escrow.State.Complete));
        assertEq(escrow.owed(seller), PRICE);
        vm.prank(seller);
        escrow.withdraw();
        assertEq(seller.balance, PRICE);
        assertEq(address(escrow).balance, 0);
    }

    function test_AgentRefundsAnyTime() public {
        escrow.pay{value: PRICE}();
        vm.prank(agent);
        escrow.refund();
        assertEq(escrow.owed(address(this)), PRICE);
        uint256 before = address(this).balance;
        escrow.withdraw();
        assertEq(address(this).balance, before + PRICE);
    }

    function test_BuyerReclaimsOnlyAfterDeadline() public {
        escrow.pay{value: PRICE}();
        uint256 due = escrow.deadline();
        vm.expectRevert(abi.encodeWithSelector(Escrow.DeadlineNotReached.selector, due));
        escrow.refund();
        vm.warp(due);
        escrow.refund();
        assertEq(uint8(escrow.state()), uint8(Escrow.State.Refunded));
    }

    function test_OnlyBuyerPays() public {
        vm.deal(seller, PRICE);
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Escrow.OnlyRole.selector, seller));
        escrow.pay{value: PRICE}();
    }

    function test_StrangerCannotRefund() public {
        escrow.pay{value: PRICE}();
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Escrow.OnlyRole.selector, seller));
        escrow.refund();
    }

    function test_WrongStateIsRejected() public {
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(
                Escrow.WrongState.selector,
                Escrow.State.AwaitingDelivery,
                Escrow.State.AwaitingPayment
            )
        );
        escrow.confirmDelivery();
    }

    function test_NothingOwedAndFailedPayment() public {
        vm.expectRevert(
            abi.encodeWithSelector(Escrow.NothingOwed.selector, address(this))
        );
        escrow.withdraw();
        Rejecter rejecter = new Rejecter();
        Escrow e = new Escrow(address(this), address(rejecter), agent, PRICE, WINDOW);
        e.pay{value: PRICE}();
        vm.prank(agent);
        e.confirmDelivery();          // a rejecting seller cannot block the deal
        vm.prank(address(rejecter));
        vm.expectRevert(Escrow.PaymentFailed.selector);
        e.withdraw();
    }

    function testFuzz_PayRejectsAnyOtherAmount(uint256 amount) public {
        vm.assume(amount != PRICE && amount < 1_000 ether);
        vm.deal(address(this), amount);
        vm.expectRevert(
            abi.encodeWithSelector(Escrow.WrongAmount.selector, amount, PRICE)
        );
        escrow.pay{value: amount}();
    }

    function testFuzz_OnlyAgentConfirms(address caller) public {
        vm.assume(caller != agent);
        escrow.pay{value: PRICE}();
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Escrow.OnlyRole.selector, caller));
        escrow.confirmDelivery();
    }
}

/// @notice A seller that refuses ether.
contract Rejecter {
    receive() external payable {
        revert();
    }
}

/// @notice Drives one escrow through random calls from its three parties.
contract EscrowHandler is Test {
    Escrow public escrow;
    address public seller = address(0x5E11E2);
    address public agent = address(0xA6E27);

    constructor() {
        escrow = new Escrow(address(this), seller, agent, 1 ether, 1 days);
        vm.deal(address(this), 1 ether);
    }

    receive() external payable {}

    function pay() external {
        try escrow.pay{value: 1 ether}() {} catch {}
    }

    function confirm() external {
        vm.prank(agent);
        try escrow.confirmDelivery() {} catch {}
    }

    function refund(bool asAgent, uint32 wait) external {
        vm.warp(block.timestamp + wait);
        if (asAgent) vm.prank(agent);
        try escrow.refund() {} catch {}
    }

    function withdraw(bool asSeller) external {
        if (asSeller) vm.prank(seller);
        try escrow.withdraw() {} catch {}
    }
}

/// @notice Invariant: the escrow always holds exactly what it owes.
contract EscrowInvariantTest is Test {
    EscrowHandler handler;

    function setUp() public {
        handler = new EscrowHandler();
        targetContract(address(handler));
    }

    function invariant_BalanceMatchesObligations() public view {
        Escrow e = handler.escrow();
        uint256 held = e.state() == Escrow.State.AwaitingDelivery ? e.price() : 0;
        uint256 owed = e.owed(address(handler)) + e.owed(handler.seller());
        assertEq(address(e).balance, held + owed);
    }
}
