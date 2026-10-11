// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleAMM} from "./SimpleAMM.sol";
import {TestToken} from "../tokens/TestToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Unit and fuzz tests for SimpleAMM.
contract SimpleAMMTest is Test {
    TestToken weth;
    TestToken usd;
    SimpleAMM amm;
    address trader = makeAddr("trader");
    uint256 deadline;

    function setUp() public {
        weth = new TestToken("Wrapped Ether", "WETH", 18);
        usd = new TestToken("Test USD", "tUSD", 6);
        amm = new SimpleAMM(weth, usd, address(this));
        deadline = block.timestamp + 1 hours;
        weth.mint(address(this), 1_000 ether);
        usd.mint(address(this), 3_000_000e6);
        weth.approve(address(amm), type(uint256).max);
        usd.approve(address(amm), type(uint256).max);
        amm.addLiquidity(100 ether, 300_000e6, 0, deadline);   // 1 WETH = 3,000
        weth.mint(trader, 100 ether);
        vm.prank(trader);
        weth.approve(address(amm), type(uint256).max);
    }

    function test_ConstructorChecks() public {
        vm.expectRevert(SimpleAMM.InvalidToken.selector);
        new SimpleAMM(weth, weth, address(this));
        vm.expectRevert(SimpleAMM.InvalidToken.selector);
        new SimpleAMM(IERC20(address(0)), usd, address(this));
        vm.expectRevert(SimpleAMM.ZeroAddress.selector);
        new SimpleAMM(weth, usd, address(0));
    }

    function test_FirstDepositLocksMinimumLiquidity() public view {
        assertEq(amm.shares(address(0)), amm.MINIMUM_LIQUIDITY());
        assertEq(amm.totalShares(), amm.shares(address(this)) + amm.MINIMUM_LIQUIDITY());
    }

    function test_TinyFirstDepositIsRejected() public {
        SimpleAMM fresh = new SimpleAMM(weth, usd, address(this));
        weth.approve(address(fresh), type(uint256).max);
        usd.approve(address(fresh), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(SimpleAMM.InsufficientShares.selector, 0, 0));
        fresh.addLiquidity(1_000, 1_000, 0, deadline);
    }

    function test_SwapBothWays() public {
        uint256 quote = amm.getAmountOut(1 ether, 100 ether, 300_000e6);
        vm.prank(trader);
        uint256 out = amm.swap(weth, 1 ether, quote, deadline);
        assertEq(out, quote);
        assertEq(usd.balanceOf(trader), quote);
        vm.startPrank(trader);
        usd.approve(address(amm), type(uint256).max);
        uint256 back = amm.swap(usd, quote, 0, deadline);
        vm.stopPrank();
        assertLt(back, 1 ether);                               // the fee, twice
    }

    function test_SwapRejections() public {
        vm.startPrank(trader);
        vm.expectRevert(SimpleAMM.ZeroAmount.selector);
        amm.swap(weth, 0, 0, deadline);
        vm.expectRevert(SimpleAMM.InvalidToken.selector);
        amm.swap(IERC20(address(0xBEEF)), 1, 0, deadline);
        uint256 quote = amm.getAmountOut(1 ether, 100 ether, 300_000e6);
        vm.expectRevert(
            abi.encodeWithSelector(SimpleAMM.SlippageExceeded.selector, quote, quote + 1)
        );
        amm.swap(weth, 1 ether, quote + 1, deadline);
        vm.warp(deadline + 1);
        vm.expectRevert(abi.encodeWithSelector(SimpleAMM.Expired.selector, deadline));
        amm.swap(weth, 1 ether, 0, deadline);
        vm.stopPrank();
    }

    function test_AddAndRemoveLiquidity() public {
        uint256 minted = amm.addLiquidity(10 ether, 30_000e6, 1, deadline);
        vm.expectRevert(SimpleAMM.ZeroAmount.selector);
        amm.addLiquidity(0, 1, 0, deadline);
        vm.expectRevert();
        amm.addLiquidity(1 ether, 3_000e6, type(uint256).max, deadline);
        uint256 held = amm.shares(address(this));
        vm.expectRevert(
            abi.encodeWithSelector(SimpleAMM.ExceedsShares.selector, held + 1, held)
        );
        amm.removeLiquidity(held + 1, 0, 0, deadline);
        vm.expectRevert(SimpleAMM.ZeroAmount.selector);
        amm.removeLiquidity(0, 0, 0, deadline);
        vm.expectRevert();
        amm.removeLiquidity(minted, type(uint256).max, 0, deadline);
        (uint256 a, uint256 b) = amm.removeLiquidity(minted, 0, 0, deadline);
        assertApproxEqRel(a, 10 ether, 1e12);                 // within 0.0001%
        assertApproxEqRel(b, 30_000e6, 1e12);
    }

    function test_PauseStopsTradingNotWithdrawals() public {
        amm.pause();
        vm.prank(trader);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        amm.swap(weth, 1 ether, 0, deadline);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        amm.addLiquidity(1 ether, 3_000e6, 0, deadline);
        amm.removeLiquidity(1_000, 0, 0, deadline);
        vm.prank(trader);
        vm.expectRevert();
        amm.unpause();
        amm.unpause();
    }

    function testFuzz_SwapNeverLowersK(uint96 amountIn, bool aIn) public {
        uint256 k0 = amm.reserveA() * amm.reserveB();
        uint256 amount = bound(amountIn, 1e6, 50 ether);
        if (aIn) {
            vm.prank(trader);
            try amm.swap(weth, amount, 0, deadline) {} catch {}
        } else {
            usd.mint(trader, amount);
            vm.startPrank(trader);
            usd.approve(address(amm), amount);
            try amm.swap(usd, amount, 0, deadline) {} catch {}
            vm.stopPrank();
        }
        assertGe(amm.reserveA() * amm.reserveB(), k0);
        assertEq(weth.balanceOf(address(amm)), amm.reserveA());
        assertEq(usd.balanceOf(address(amm)), amm.reserveB());
    }
}
