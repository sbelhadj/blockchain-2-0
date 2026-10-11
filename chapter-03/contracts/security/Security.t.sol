// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SecureVault} from "./SecureVault.sol";
import {RoleMintToken} from "./AccessControlExamples.sol";
import {PushPayout, PullPayout, RejectingRecipient} from "./Payouts.sol";
import {Attacker} from "./Attacker.sol";

/// @notice Tests for the fixed contracts of Section 3.4.
contract SecurityTest is Test {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function test_SecureVaultDepositAndWithdraw() public {
        SecureVault vault = new SecureVault();
        vm.expectRevert(SecureVault.ZeroDeposit.selector);
        vault.deposit();
        vm.deal(alice, 2 ether);
        vm.startPrank(alice);
        vault.deposit{value: 2 ether}();
        vault.withdraw();
        vm.expectRevert(SecureVault.NoBalance.selector);
        vault.withdraw();
        vm.stopPrank();
        assertEq(alice.balance, 2 ether);
    }

    function test_SecureVaultStopsReentrancy() public {
        SecureVault vault = new SecureVault();
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        vault.deposit{value: 5 ether}();
        Attacker attacker = new Attacker(address(vault));
        vm.expectRevert(SecureVault.TransferFailed.selector);
        attacker.attack{value: 1 ether}();
        assertEq(address(vault).balance, 5 ether);
    }

    function test_RoleMintToken() public {
        vm.expectRevert(RoleMintToken.ZeroAddress.selector);
        new RoleMintToken(address(0));
        RoleMintToken token = new RoleMintToken(address(this));
        token.grantRole(token.MINTER_ROLE(), alice);
        vm.prank(alice);
        token.mint(bob, 7);
        assertEq(token.balances(bob), 7);
        vm.prank(bob);
        vm.expectRevert();
        token.mint(bob, 1);
    }

    function test_PushPayoutFailsForEveryoneWhenOneRejects() public {
        PushPayout push = new PushPayout();
        address[] memory list = new address[](2);
        list[0] = alice;
        list[1] = bob;
        push.payAll{value: 2 ether}(list, 1 ether);
        assertEq(alice.balance, 1 ether);

        list[1] = address(new RejectingRecipient());
        vm.expectRevert(bytes("Payout failed"));
        push.payAll{value: 2 ether}(list, 1 ether);
        assertEq(alice.balance, 1 ether);       // alice's second payment was undone too
    }

    function test_PullPayoutFundingAndBatch() public {
        PullPayout pull = new PullPayout();
        address[] memory list = new address[](2);
        list[0] = alice;
        list[1] = bob;
        vm.expectRevert(
            abi.encodeWithSelector(PullPayout.WrongFunding.selector, 1 ether, 2 ether)
        );
        pull.allocate{value: 1 ether}(list, 1 ether);
        address[] memory tooMany = new address[](201);
        vm.expectRevert(abi.encodeWithSelector(PullPayout.BatchTooLarge.selector, 201));
        pull.allocate(tooMany, 0);
    }

    function test_PullPayoutWithdrawals() public {
        PullPayout pull = new PullPayout();
        RejectingRecipient bad = new RejectingRecipient();
        address[] memory list = new address[](3);
        list[0] = alice;
        list[1] = address(bad);
        list[2] = bob;
        pull.allocate{value: 3 ether}(list, 1 ether);
        vm.prank(alice);
        pull.withdraw();
        assertEq(alice.balance, 1 ether);
        vm.prank(alice);
        vm.expectRevert(PullPayout.NothingOwed.selector);
        pull.withdraw();
        vm.prank(address(bad));
        vm.expectRevert(PullPayout.TransferFailed.selector);
        pull.withdraw();
        vm.prank(bob);
        pull.withdraw();
        assertEq(bob.balance, 1 ether);
    }

    function testFuzz_PullPayoutKeepsBooksBalanced(uint8 n, uint64 amount) public {
        n = uint8(bound(n, 1, 20));
        PullPayout pull = new PullPayout();
        address[] memory list = new address[](n);
        for (uint256 i = 0; i < n; i++) list[i] = address(uint160(0x1000 + i));
        uint256 total = uint256(n) * amount;
        vm.deal(address(this), total);
        pull.allocate{value: total}(list, amount);
        uint256 sum;
        for (uint256 i = 0; i < n; i++) sum += pull.owed(list[i]);
        assertEq(sum, address(pull).balance);
    }
}
