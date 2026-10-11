// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Escrow} from "../basics/Escrow.sol";
import {EscrowFactory} from "./EscrowFactory.sol";
import {PaymentHub} from "./PaymentHub.sol";
import {PaymentHubV1, PaymentHubV2} from "./PaymentHubUpgradeable.sol";
import {HubProxy} from "./Proxy.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Tests for the factory, circuit breaker and UUPS proxy patterns.
contract PatternsTest is Test {
    address admin = makeAddr("admin");
    address pauser = makeAddr("pauser");
    address seller = makeAddr("seller");
    address agent = makeAddr("agent");
    address payee = makeAddr("payee");

    function test_FactoryMakesCallerTheBuyer() public {
        EscrowFactory factory = new EscrowFactory();
        Escrow e = factory.createEscrow(seller, agent, 1 ether, 1 days);
        factory.createEscrow(seller, agent, 2 ether, 1 days);
        assertEq(factory.count(), 2);
        assertEq(address(factory.escrows(0)), address(e));
        assertEq(e.buyer(), address(this));
    }

    function test_HubPauseBlocksPaymentsNotWithdrawals() public {
        vm.expectRevert(PaymentHub.ZeroAddress.selector);
        new PaymentHub(address(0), pauser);
        PaymentHub hub = new PaymentHub(admin, pauser);
        hub.pay{value: 1 ether}(payee);
        vm.prank(pauser);
        hub.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        hub.pay{value: 1 ether}(payee);
        vm.prank(payee);
        hub.withdraw();                          // still possible while paused
        assertEq(payee.balance, 1 ether);
        vm.prank(pauser);
        vm.expectRevert();                       // the pauser cannot unpause
        hub.unpause();
        vm.prank(admin);
        hub.unpause();
    }

    function test_HubRejectsBadPaymentsAndEmptyWithdrawals() public {
        PaymentHub hub = new PaymentHub(admin, pauser);
        vm.expectRevert(PaymentHub.ZeroAddress.selector);
        hub.pay{value: 1}(address(0));
        vm.expectRevert(PaymentHub.ZeroAmount.selector);
        hub.pay(payee);
        vm.expectRevert(PaymentHub.NothingToWithdraw.selector);
        hub.withdraw();
        Refuser refuser = new Refuser();
        hub.pay{value: 1}(address(refuser));
        vm.prank(address(refuser));
        vm.expectRevert(PaymentHub.TransferFailed.selector);
        hub.withdraw();
    }

    function _proxy() internal returns (PaymentHubV1 hub) {
        PaymentHubV1 impl = new PaymentHubV1();
        bytes memory init = abi.encodeCall(PaymentHubV1.initialize, (admin));
        hub = PaymentHubV1(address(new HubProxy(address(impl), init)));
    }

    function test_UpgradeKeepsState() public {
        PaymentHubV1 hub = _proxy();
        hub.pay{value: 100}();
        vm.expectRevert(PaymentHubV1.ZeroAmount.selector);
        hub.pay();
        PaymentHubV2 v2 = new PaymentHubV2();
        vm.prank(admin);
        hub.upgradeToAndCall(address(v2), "");
        PaymentHubV2 hub2 = PaymentHubV2(address(hub));
        assertEq(hub2.totalPayments(), 100);
        hub2.payAndCount{value: 50}();
        assertEq(hub2.totalPayments(), 150);
        assertEq(hub2.paymentCount(), 1);
        assertEq(hub2.version(), "2");
        vm.expectRevert(PaymentHubV1.ZeroAmount.selector);
        hub2.payAndCount();
    }

    function test_OnlyOwnerUpgradesAndWithdraws() public {
        PaymentHubV1 hub = _proxy();
        PaymentHubV2 v2 = new PaymentHubV2();
        vm.expectRevert();
        hub.upgradeToAndCall(address(v2), "");
        vm.startPrank(admin);
        vm.expectRevert(PaymentHubV1.NothingToWithdraw.selector);
        hub.withdraw(payable(admin));
        vm.stopPrank();
        hub.pay{value: 3}();
        vm.startPrank(admin);
        vm.expectRevert(PaymentHubV1.ZeroAddress.selector);
        hub.withdraw(payable(address(0)));
        Refuser refuser = new Refuser();
        vm.expectRevert(PaymentHubV1.TransferFailed.selector);
        hub.withdraw(payable(address(refuser)));
        hub.withdraw(payable(payee));
        vm.stopPrank();
        assertEq(payee.balance, 3);
    }

    function test_ImplementationCannotBeInitialized() public {
        PaymentHubV1 impl = new PaymentHubV1();
        vm.expectRevert();
        impl.initialize(address(this));
    }
}

/// @notice An account that refuses ether.
contract Refuser {
    receive() external payable {
        revert();
    }
}
