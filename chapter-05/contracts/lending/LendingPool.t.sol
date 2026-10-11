// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LendingPool} from "./LendingPool.sol";
import {TestToken} from "../tokens/TestToken.sol";
import {MockPriceFeed, IPriceFeed} from "../oracles/MockPriceFeed.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Unit tests and the Section 5.3 property: borrowing everything the
///         pool allows never leaves a position liquidatable.
contract LendingPoolTest is Test {
    TestToken weth;
    TestToken usd;
    MockPriceFeed feed;
    LendingPool pool;
    address bob = makeAddr("bob");
    address liquidator = makeAddr("liquidator");

    function setUp() public {
        weth = new TestToken("Wrapped Ether", "WETH", 18);
        usd = new TestToken("Test USD", "tUSD", 6);
        feed = new MockPriceFeed(2_500e8);
        pool = new LendingPool(weth, usd, feed, address(this));
        usd.mint(address(this), 1e15);              // 1 billion tUSD of liquidity
        usd.approve(address(pool), type(uint256).max);
        pool.supply(1e15);
        weth.mint(bob, 10 ether);
        vm.prank(bob);
        weth.approve(address(pool), type(uint256).max);
        usd.mint(liquidator, 1e12);
        vm.prank(liquidator);
        usd.approve(address(pool), type(uint256).max);
    }

    function testFuzz_MaxBorrowStaysHealthy(uint96 amount, uint64 priceUsd) public {
        uint256 collateralAmount = bound(amount, 1e15, 1_000 ether);
        uint256 p = bound(priceUsd, 1, 100_000);           // $1 to $100,000
        feed.setPrice(int256(p * 1e8));
        weth.mint(address(this), collateralAmount);
        weth.approve(address(pool), collateralAmount);
        pool.depositCollateral(collateralAmount);
        uint256 maxBorrow = pool.availableToBorrow(address(this));
        vm.assume(maxBorrow > 0 && maxBorrow <= 1e15);
        pool.borrow(maxBorrow);
        assertGe(pool.healthFactor(address(this)), 1e18);
    }

    function test_ConstructorChecks() public {
        vm.expectRevert(LendingPool.ZeroAddress.selector);
        new LendingPool(weth, usd, feed, address(0));
        vm.expectRevert(LendingPool.UnsupportedDecimals.selector);
        new LendingPool(usd, weth, feed, address(this));       // swapped decimals
    }

    function test_BorrowRepayWithdrawCycle() public {
        vm.startPrank(bob);
        pool.depositCollateral(3 ether);                       // $7,500
        assertEq(pool.collateralValueUsd(bob), 7_500e18);
        assertEq(pool.availableToBorrow(bob), 5_625e6);
        vm.expectRevert(
            abi.encodeWithSelector(LendingPool.ExceedsBorrowLimit.selector, 5_626e6, 5_625e6)
        );
        pool.borrow(5_626e6);
        pool.borrow(5_000e6);
        assertEq(pool.debtValueUsd(bob), 5_000e18);
        vm.expectRevert(abi.encodeWithSelector(LendingPool.ExceedsBalance.selector, 6_000e6, 5_000e6));
        pool.repay(6_000e6);
        usd.approve(address(pool), type(uint256).max);
        pool.repay(5_000e6);
        vm.expectRevert(abi.encodeWithSelector(LendingPool.ExceedsBalance.selector, 4 ether, 3 ether));
        pool.withdrawCollateral(4 ether);
        pool.withdrawCollateral(3 ether);
        vm.stopPrank();
        assertEq(pool.debtOf(bob), 0);
        assertEq(weth.balanceOf(bob), 10 ether);
        assertEq(pool.healthFactor(bob), type(uint256).max);
    }

    function test_ZeroAmountsRevert() public {
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.supply(0);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.withdrawSupply(0);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.depositCollateral(0);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.borrow(0);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.repay(0);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.withdrawCollateral(0);
    }

    function test_LenderWithdrawsOnlyIdleCash() public {
        vm.startPrank(bob);
        pool.depositCollateral(10 ether);
        pool.borrow(18_000e6);
        vm.stopPrank();
        vm.expectRevert(
            abi.encodeWithSelector(LendingPool.ExceedsBalance.selector, 1e15 + 1, 1e15)
        );
        pool.withdrawSupply(1e15 + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                LendingPool.InsufficientLiquidity.selector, 1e15, 1e15 - 18_000e6
            )
        );
        pool.withdrawSupply(1e15);
        pool.withdrawSupply(1e15 - 18_000e6);
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(LendingPool.InsufficientLiquidity.selector, 1e6, 0)
        );
        pool.borrow(1e6);
    }

    function test_UnhealthyWithdrawalIsBlocked() public {
        vm.startPrank(bob);
        pool.depositCollateral(3 ether);
        pool.borrow(5_000e6);
        vm.expectRevert();
        pool.withdrawCollateral(1 ether);
        vm.stopPrank();
    }

    function test_LiquidationAfterPriceDrop() public {
        vm.startPrank(bob);
        pool.depositCollateral(3 ether);
        pool.borrow(5_000e6);
        vm.stopPrank();
        vm.prank(liquidator);
        vm.expectRevert();
        pool.liquidate(bob, 1_000e6);                          // still healthy
        feed.setPrice(2_000e8);
        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(LendingPool.RepayTooLarge.selector, 0, 2_500e6)
        );
        pool.liquidate(bob, 0);
        pool.liquidate(bob, 2_500e6);
        vm.stopPrank();
        assertEq(weth.balanceOf(liquidator), 2_500e6 * 1e12 * 105 / 100 / 2_000);
    }

    function test_SeizureIsCappedAtCollateral() public {
        vm.startPrank(bob);
        pool.depositCollateral(1 ether);
        pool.borrow(1_875e6);                                  // the 75% maximum
        vm.stopPrank();
        feed.setPrice(900e8);                                  // collateral worth $900
        vm.prank(liquidator);
        pool.liquidate(bob, 937e6);
        assertEq(pool.collateralOf(bob), 0);
        assertEq(weth.balanceOf(liquidator), 1 ether);
    }

    function test_OracleChecks() public {
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert();
        pool.price();
        feed.setPrice(0);
        vm.expectRevert(abi.encodeWithSelector(LendingPool.BadPrice.selector, 0));
        pool.price();
        BrokenFeed broken = new BrokenFeed();
        LendingPool p2 =
            new LendingPool(weth, usd, IPriceFeed(address(broken)), address(this));
        vm.expectRevert(abi.encodeWithSelector(LendingPool.StalePrice.selector, 0));
        p2.price();
        broken.setUpdatedAt(block.timestamp + 1);
        vm.expectRevert(
            abi.encodeWithSelector(LendingPool.StalePrice.selector, block.timestamp + 1)
        );
        p2.price();
    }

    function test_PauseStopsNewRiskOnly() public {
        vm.prank(bob);
        pool.depositCollateral(3 ether);
        vm.prank(bob);
        pool.borrow(1_000e6);
        pool.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pool.supply(1);
        vm.startPrank(bob);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pool.borrow(1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pool.depositCollateral(1);
        usd.approve(address(pool), type(uint256).max);
        pool.repay(1_000e6);                                   // still allowed
        pool.withdrawCollateral(3 ether);                      // still allowed
        vm.stopPrank();
        vm.prank(bob);
        vm.expectRevert();
        pool.unpause();
        pool.unpause();
        assertFalse(pool.paused());
    }
}

/// @notice A feed that reports 8 decimals and a chosen update time.
contract BrokenFeed {
    uint256 private _updatedAt;

    function setUpdatedAt(uint256 t) external {
        _updatedAt = t;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, 2_500e8, _updatedAt, _updatedAt, 1);
    }
}

/// @notice Random lenders, borrowers, price moves and liquidations.
contract LendingPoolHandler is Test {
    TestToken public weth;
    TestToken public usd;
    MockPriceFeed public feed;
    LendingPool public pool;
    address[3] public actors = [address(0xA1), address(0xA2), address(0xA3)];

    constructor() {
        weth = new TestToken("Wrapped Ether", "WETH", 18);
        usd = new TestToken("Test USD", "tUSD", 6);
        feed = new MockPriceFeed(2_500e8);
        pool = new LendingPool(weth, usd, feed, address(this));
        for (uint256 i = 0; i < 3; i++) {
            weth.mint(actors[i], 1_000 ether);
            usd.mint(actors[i], 10_000_000e6);
            vm.startPrank(actors[i]);
            weth.approve(address(pool), type(uint256).max);
            usd.approve(address(pool), type(uint256).max);
            vm.stopPrank();
        }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % 3];
    }

    function supply(uint256 seed, uint256 amount) external {
        vm.prank(_actor(seed));
        try pool.supply(bound(amount, 1, 1_000_000e6)) {} catch {}
    }

    function withdrawSupply(uint256 seed, uint256 amount) external {
        vm.prank(_actor(seed));
        try pool.withdrawSupply(bound(amount, 1, 1_000_000e6)) {} catch {}
    }

    function deposit(uint256 seed, uint256 amount) external {
        vm.prank(_actor(seed));
        try pool.depositCollateral(bound(amount, 1, 100 ether)) {} catch {}
    }

    function borrow(uint256 seed, uint256 amount) external {
        vm.prank(_actor(seed));
        try pool.borrow(bound(amount, 1, 200_000e6)) {} catch {}
    }

    function repay(uint256 seed, uint256 amount) external {
        vm.prank(_actor(seed));
        try pool.repay(bound(amount, 1, 200_000e6)) {} catch {}
    }

    function withdrawCollateral(uint256 seed, uint256 amount) external {
        vm.prank(_actor(seed));
        try pool.withdrawCollateral(bound(amount, 1, 100 ether)) {} catch {}
    }

    function movePrice(uint256 p) external {
        feed.setPrice(int256(bound(p, 500, 5_000)) * 1e8);
    }

    function liquidate(uint256 seed, uint256 victim, uint256 amount) external {
        vm.prank(_actor(seed));
        try pool.liquidate(_actor(victim), bound(amount, 1, 100_000e6)) {} catch {}
    }
}

/// @notice Invariants: the pool's books always match its token balances.
contract LendingPoolInvariantTest is Test {
    LendingPoolHandler handler;

    function setUp() public {
        handler = new LendingPoolHandler();
        targetContract(address(handler));
    }

    /// Cash plus outstanding debt equals what lenders supplied.
    function invariant_CashPlusDebtEqualsSupply() public view {
        LendingPool pool = handler.pool();
        uint256 debt;
        uint256 supplied;
        for (uint256 i = 0; i < 3; i++) {
            debt += pool.debtOf(handler.actors(i));
            supplied += pool.suppliedOf(handler.actors(i));
        }
        assertEq(handler.usd().balanceOf(address(pool)) + debt, supplied);
    }

    /// Recorded collateral equals the collateral the pool holds.
    function invariant_CollateralIsBacked() public view {
        LendingPool pool = handler.pool();
        uint256 total;
        for (uint256 i = 0; i < 3; i++) total += pool.collateralOf(handler.actors(i));
        assertEq(handler.weth().balanceOf(address(pool)), total);
    }
}
