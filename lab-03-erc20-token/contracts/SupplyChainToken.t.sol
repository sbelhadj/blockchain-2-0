// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SupplyChainToken} from "./SupplyChainToken.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title Property and invariant tests for SupplyChainToken
/// @notice Fuzz tests state single-call properties; the invariant test lets the
///         fuzzer call the token in random order through a handler.
contract SupplyChainTokenTest is Test {
    SupplyChainToken internal sct;
    address internal constant TREASURY = address(0x7EA5);
    address internal constant CARRIER = address(0xCA22);

    function setUp() public {
        sct = new SupplyChainToken(address(this), TREASURY, 1 days);
        sct.setCarrier(CARRIER, true);
    }

    /// Property: no pair of treasury mints can push supply above the cap.
    function testFuzz_SupplyNeverExceedsCap(uint256 a, uint256 b) public {
        a = bound(a, 0, 120_000_000 ether);
        b = bound(b, 0, 120_000_000 ether);
        try sct.mint(address(1), a) {} catch {}
        try sct.mint(address(2), b) {} catch {}
        assertLe(sct.totalSupply(), sct.cap());
    }

    /// Property: an event id pays once, whatever the id and the kind.
    function testFuzz_EventRewardedOnce(bytes32 eventId, uint8 rawKind) public {
        SupplyChainToken.Reward kind = SupplyChainToken.Reward(bound(rawKind, 0, 2));
        sct.reward(CARRIER, kind, eventId);
        vm.expectRevert(
            abi.encodeWithSelector(SupplyChainToken.AlreadyRewarded.selector, eventId)
        );
        sct.reward(CARRIER, kind, eventId);
    }

    /// Property: no reward amount above MAX_REWARD can be configured.
    function testFuzz_RewardAmountBounded(uint256 amount) public {
        amount = bound(amount, sct.MAX_REWARD() + 1, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainToken.RewardTooLarge.selector, amount, sct.MAX_REWARD()
            )
        );
        sct.setRewardAmount(SupplyChainToken.Reward.QualityCheck, amount);
    }

    function test_ZeroAddressesRejected() public {
        vm.expectRevert(SupplyChainToken.ZeroAddress.selector);
        new SupplyChainToken(address(this), address(0), 1 days);
        vm.expectRevert(SupplyChainToken.ZeroAddress.selector);
        sct.setCarrier(address(0), true);
    }

    function test_RewardNeedsVerifiedCarrier() public {
        address stranger = address(0xBAD);
        vm.expectRevert(
            abi.encodeWithSelector(SupplyChainToken.CarrierNotVerified.selector, stranger)
        );
        sct.reward(stranger, SupplyChainToken.Reward.QualityCheck, "evt");

        sct.setCarrier(CARRIER, false);
        vm.expectRevert(
            abi.encodeWithSelector(SupplyChainToken.CarrierNotVerified.selector, CARRIER)
        );
        sct.reward(CARRIER, SupplyChainToken.Reward.QualityCheck, "evt");
    }

    function test_PauseStopsTransfersUntilUnpaused() public {
        sct.pause();
        vm.prank(TREASURY);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        sct.transfer(CARRIER, 1 ether);

        sct.unpause();
        vm.prank(TREASURY);
        assertTrue(sct.transfer(CARRIER, 1 ether));
        assertEq(sct.balanceOf(CARRIER), 1 ether);
    }
}

/// @notice Drives the token with bounded random actions and tracks the holders
///         it has touched, so the invariant can sum their balances.
contract SctHandler is Test {
    SupplyChainToken internal immutable sct;
    address[] public holders;
    uint256 public onTimeRewards;
    uint256 internal nextEvent;

    constructor(SupplyChainToken token, address treasury, address carrier) {
        sct = token;
        holders.push(treasury);
        holders.push(carrier);
    }

    function rewardCarrier(uint8 rawKind) external {
        SupplyChainToken.Reward kind = SupplyChainToken.Reward(rawKind % 3);
        try sct.reward(holders[1], kind, bytes32(++nextEvent)) {
            if (kind == SupplyChainToken.Reward.OnTimeDelivery) onTimeRewards++;
        } catch {}
    }

    function mintTreasury(uint256 amount) external {
        amount = bound(amount, 0, 5_000_000 ether);
        try sct.mint(holders[0], amount) {} catch {}
    }

    function transferFromTreasury(uint256 seed, uint256 amount) external {
        address to = address(uint160(bound(seed, 1, 50)));
        amount = bound(amount, 0, sct.balanceOf(holders[0]));
        vm.prank(holders[0]);
        sct.transfer(to, amount);
        holders.push(to);
    }

    function burnFromCarrier(uint256 amount) external {
        amount = bound(amount, 0, sct.balanceOf(holders[1]));
        vm.prank(holders[1]);
        sct.burn(amount);
    }

    function holderCount() external view returns (uint256) {
        return holders.length;
    }
}

/// @title Invariant suite for SupplyChainToken
contract SupplyChainTokenInvariantTest is Test {
    SupplyChainToken internal sct;
    SctHandler internal handler;

    function setUp() public {
        sct = new SupplyChainToken(address(this), address(0x7EA5), 1 days);
        sct.setCarrier(address(0xCA22), true);
        handler = new SctHandler(sct, address(0x7EA5), address(0xCA22));
        sct.grantRole(sct.REWARDER_ROLE(), address(handler));
        sct.grantRole(sct.MINTER_ROLE(), address(handler));
        targetContract(address(handler));
    }

    /// Supply never exceeds the cap.
    function invariant_SupplyWithinCap() public view {
        assertLe(sct.totalSupply(), sct.MAX_SUPPLY());
    }

    /// Every token is held by an account the handler has touched.
    function invariant_BalancesAddUpToSupply() public view {
        uint256 n = handler.holderCount();
        uint256 sum;
        address[] memory seen = new address[](n);
        uint256 unique;
        for (uint256 i; i < n; i++) {
            address h = handler.holders(i);
            bool dup;
            for (uint256 j; j < unique; j++) if (seen[j] == h) dup = true;
            if (dup) continue;
            seen[unique++] = h;
            sum += sct.balanceOf(h);
        }
        assertEq(sum, sct.totalSupply());
    }

    /// The delivery counter matches the on-time rewards actually paid.
    function invariant_DeliveryCountMatchesRewards() public view {
        assertEq(sct.deliveryCount(address(0xCA22)), handler.onTimeRewards());
    }
}
