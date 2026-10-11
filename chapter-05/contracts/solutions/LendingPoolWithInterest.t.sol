// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LendingPoolWithInterest} from "./LendingPoolWithInterest.sol";
import {TestToken} from "../tokens/TestToken.sol";
import {MockPriceFeed} from "../oracles/MockPriceFeed.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Exercise 5.4: a maximum borrow is healthy when made, total debt never
///         exceeds what lenders are owed however much time passes, and the
///         edges of every function.
contract LendingPoolWithInterestTest is Test {
    TestToken weth;
    TestToken usd;
    MockPriceFeed feed;
    LendingPoolWithInterest pool;
    address bob = makeAddr("bob");
    address liquidator = makeAddr("liquidator");

    function setUp() public {
        weth = new TestToken("Wrapped ETH", "WETH", 18);
        usd = new TestToken("Test USD", "tUSD", 6);
        feed = new MockPriceFeed(2_500e8);
        pool = new LendingPoolWithInterest(weth, usd, feed, address(this));
        usd.mint(address(this), 1e15);
        usd.approve(address(pool), type(uint256).max);
        pool.supply(1e15);
        weth.mint(bob, 10 ether);
        usd.mint(bob, 1_000_000e6);
        vm.startPrank(bob);
        weth.approve(address(pool), type(uint256).max);
        usd.approve(address(pool), type(uint256).max);
        vm.stopPrank();
        usd.mint(liquidator, 1_000_000e6);
        vm.prank(liquidator);
        usd.approve(address(pool), type(uint256).max);
    }

    function testFuzz_MaxBorrowHealthyAndDebtCovered(
        uint96 amount,
        uint32 elapsed
    ) public {
        uint256 coll = bound(amount, 1e15, 1_000 ether);
        weth.mint(address(this), coll);
        weth.approve(address(pool), coll);
        pool.depositCollateral(coll);
        uint256 maxBorrow = pool.availableToBorrow(address(this));
        vm.assume(maxBorrow > 0);
        pool.borrow(maxBorrow);
        assertGe(pool.healthFactor(address(this)), 1e18);

        vm.warp(block.timestamp + bound(elapsed, 1, 3 * 365 days));
        pool.accrue();
        uint256 totalDebt =
            (pool.totalScaledDebt() * pool.borrowIndex()) / pool.RAY();
        uint256 owed = (pool.totalScaledSupply() * pool.supplyIndex()) / pool.RAY();
        assertLe(totalDebt, owed + 1); // allow 1 unit of rounding
    }

    function test_ConstructorChecks() public {
        vm.expectRevert(LendingPoolWithInterest.ZeroAddress.selector);
        new LendingPoolWithInterest(weth, usd, feed, address(0));
        vm.expectRevert(LendingPoolWithInterest.UnsupportedDecimals.selector);
        new LendingPoolWithInterest(usd, weth, feed, address(this));
    }

    function test_RateModelAndEmptyPool() public {
        assertEq(pool.borrowRateBps(0), 200);
        assertEq(pool.borrowRateBps(8_000), 1_000);
        assertEq(pool.borrowRateBps(10_000), 6_000);
        LendingPoolWithInterest empty =
            new LendingPoolWithInterest(weth, usd, feed, address(this));
        assertEq(empty.utilizationBps(), 0);
    }

    function test_ZeroAmountsRevert() public {
        bytes4 z = LendingPoolWithInterest.ZeroAmount.selector;
        vm.expectRevert(z);
        pool.supply(0);
        vm.expectRevert(z);
        pool.withdrawSupply(0);
        vm.expectRevert(z);
        pool.depositCollateral(0);
        vm.expectRevert(z);
        pool.borrow(0);
        vm.expectRevert(z);
        pool.repay(0);
        vm.expectRevert(z);
        pool.withdrawCollateral(0);
    }

    function test_BorrowerCycleWithInterest() public {
        vm.startPrank(bob);
        pool.depositCollateral(3 ether);
        vm.expectRevert();
        pool.borrow(5_626e6);
        pool.borrow(5_000e6);
        vm.warp(block.timestamp + 30 days);
        vm.stopPrank();
        feed.setPrice(2_500e8);
        vm.startPrank(bob);
        uint256 debt = pool.debtOf(bob);
        assertGt(debt, 5_000e6);
        pool.repay(type(uint128).max);                         // clamped to the debt
        assertEq(pool.debtOf(bob), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                LendingPoolWithInterest.ExceedsBalance.selector, 4 ether, 3 ether
            )
        );
        pool.withdrawCollateral(4 ether);
        pool.withdrawCollateral(3 ether);
        vm.stopPrank();
    }

    function test_UnhealthyWithdrawalAndLiquidation() public {
        vm.startPrank(bob);
        pool.depositCollateral(1 ether);
        pool.borrow(1_875e6);
        vm.expectRevert();
        pool.withdrawCollateral(0.5 ether);
        vm.stopPrank();
        vm.prank(liquidator);
        vm.expectRevert();
        pool.liquidate(bob, 100e6);                            // healthy
        feed.setPrice(900e8);
        vm.startPrank(liquidator);
        vm.expectRevert();
        pool.liquidate(bob, 0);
        pool.liquidate(bob, 937e6);                            // seizure capped
        vm.stopPrank();
        assertEq(pool.collateralOf(bob), 0);
    }

    function test_LenderWithdrawals() public {
        vm.startPrank(bob);
        pool.depositCollateral(10 ether);
        pool.borrow(18_000e6);
        vm.stopPrank();
        vm.expectRevert();
        pool.withdrawSupply(1e15 + 1);
        vm.expectRevert();
        pool.withdrawSupply(1e15);                             // part is lent out
        pool.withdrawSupply(1e15 - 18_000e6);
        vm.prank(bob);
        vm.expectRevert();
        pool.borrow(1);                                        // no cash left
        vm.warp(block.timestamp + 365 days);
        feed.setPrice(2_500e8);
        vm.prank(bob);
        pool.repay(type(uint128).max);
        uint256 all = pool.suppliedOf(address(this));
        pool.withdrawSupply(all);
        assertGt(usd.balanceOf(address(this)), 1e15);         // principal + interest
    }

    /// @dev A lender can always withdraw exactly what suppliedOf reports, and
    ///      that leaves no scaled balance behind, whatever the rounding.
    function testFuzz_FullWithdrawalClearsBalance(uint64 amount, uint32 dt) public {
        amount = uint64(bound(amount, 1, 1e13));
        address carol = makeAddr("carol");
        usd.mint(carol, amount);
        vm.startPrank(carol);
        usd.approve(address(pool), amount);
        pool.supply(amount);
        vm.stopPrank();
        vm.startPrank(bob);
        pool.depositCollateral(10 ether);
        pool.borrow(10_000e6);
        vm.stopPrank();
        vm.warp(block.timestamp + bound(dt, 1, 365 days));
        feed.setPrice(2_500e8);
        vm.prank(bob);
        pool.repay(type(uint128).max);
        uint256 all = pool.suppliedOf(carol);
        vm.prank(carol);
        pool.withdrawSupply(all);
        assertEq(pool.scaledSupplyOf(carol), 0);
        (uint256 bIndex, uint256 sIndex) = pool.currentIndexes();
        assertGe(bIndex, sIndex);                              // borrowers pay the spread
        assertEq(pool.suppliedOf(carol), 0);
    }

    function test_OracleChecks() public {
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert();
        pool.price();
        feed.setPrice(-1);
        vm.expectRevert(
            abi.encodeWithSelector(LendingPoolWithInterest.BadPrice.selector, -1)
        );
        pool.price();
    }

    function test_PauseStopsNewRiskOnly() public {
        vm.prank(bob);
        pool.depositCollateral(1 ether);
        pool.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pool.supply(1);
        vm.startPrank(bob);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pool.depositCollateral(1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pool.borrow(1);
        pool.withdrawCollateral(1 ether);
        vm.stopPrank();
        pool.unpause();
    }
}
