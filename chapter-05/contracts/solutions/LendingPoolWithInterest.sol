// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPriceFeed} from "../oracles/MockPriceFeed.sol";

/// @title LendingPoolWithInterest
/// @author Sami BELHADJ, Book 3, Exercise 5.4 solution
/// @notice LendingPool with utilization-based interest. All interest goes to
///         lenders.
/// @dev Debt and deposits are stored as scaled balances; two indexes grow with
///      time, so interest accrues without touching every account. Debt rounds
///      up and deposits round down, always in the pool's favour. Pausing stops
///      new risk; repaying, withdrawing and liquidating always work.
///      Teaching code, not audited.
contract LendingPoolWithInterest is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role allowed to pause.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Fixed-point unit of the indexes (27 decimals).
    uint256 public constant RAY = 1e27;
    /// @notice 100% in basis points.
    uint256 public constant BPS = 10_000;
    /// @notice Seconds in the year used for rates.
    uint256 public constant YEAR = 365 days;
    /// @notice Borrow up to 75% of the collateral's value.
    uint256 public constant LTV_BPS = 7_500;
    /// @notice A position is liquidatable once debt exceeds 80% of its value.
    uint256 public constant LIQ_THRESHOLD_BPS = 8_000;
    /// @notice Extra collateral a liquidator receives: 5%.
    uint256 public constant LIQ_BONUS_BPS = 500;
    /// @notice Share of a debt one liquidation may repay: 50%.
    uint256 public constant CLOSE_FACTOR_BPS = 5_000;
    /// @notice Oldest oracle answer the pool accepts.
    uint256 public constant MAX_PRICE_AGE = 1 hours;
    /// @notice Borrow rate at 0% utilization: 2%.
    uint256 public constant BASE_RATE_BPS = 200;
    /// @notice Borrow rate at the kink: 10%.
    uint256 public constant KINK_RATE_BPS = 1_000;
    /// @notice Borrow rate at 100% utilization: 60%.
    uint256 public constant MAX_RATE_BPS = 6_000;
    /// @notice Utilization at which the rate curve steepens: 80%.
    uint256 public constant KINK_UTIL_BPS = 8_000;

    /// @notice Collateral asset, 18 decimals.
    IERC20 public immutable collateral;
    /// @notice Borrowable asset, 6 decimals.
    IERC20 public immutable stable;
    /// @notice USD price of one collateral unit, 8 decimals.
    IPriceFeed public immutable feed;

    /// @notice Debt per scaled debt unit, in RAY.
    uint256 public borrowIndex = RAY;
    /// @notice Deposit per scaled supply unit, in RAY.
    uint256 public supplyIndex = RAY;
    /// @notice Time of the last accrual.
    uint256 public lastAccrual;
    /// @notice Sum of all scaled debts.
    uint256 public totalScaledDebt;
    /// @notice Sum of all scaled deposits.
    uint256 public totalScaledSupply;
    /// @notice Collateral deposited by each borrower.
    mapping(address => uint256) public collateralOf;
    /// @notice Scaled debt of each borrower.
    mapping(address => uint256) public scaledDebtOf;
    /// @notice Scaled deposit of each lender.
    mapping(address => uint256) public scaledSupplyOf;

    /// @notice An address argument is zero.
    error ZeroAddress();
    /// @notice The amount is zero.
    error ZeroAmount();
    /// @notice A token or the feed does not use the expected decimals.
    error UnsupportedDecimals();
    /// @notice The oracle answer is too old, missing or in the future.
    error StalePrice(uint256 updatedAt);
    /// @notice The oracle answer is zero or negative.
    error BadPrice(int256 answer);
    /// @notice The borrow would exceed the loan-to-value limit.
    error ExceedsBorrowLimit(uint256 requested, uint256 available);
    /// @notice The action would leave the position liquidatable.
    error Unhealthy(uint256 healthFactor);
    /// @notice The position is healthy and cannot be liquidated.
    error Healthy(uint256 healthFactor);
    /// @notice The repayment is zero or above the close factor.
    error RepayTooLarge(uint256 repay, uint256 maxRepay);
    /// @notice The pool does not hold enough stablecoin.
    error InsufficientLiquidity(uint256 requested, uint256 available);
    /// @notice The amount is larger than the caller's balance.
    error ExceedsBalance(uint256 requested, uint256 balance);

    /// @notice Indexes were brought up to date.
    event Accrued(uint256 borrowIndex, uint256 supplyIndex, uint256 timestamp);
    /// @notice A lender supplied stablecoin.
    event Supplied(address indexed lender, uint256 amount);
    /// @notice A lender withdrew stablecoin.
    event SupplyWithdrawn(address indexed lender, uint256 amount);
    /// @notice A borrower deposited collateral.
    event CollateralDeposited(address indexed user, uint256 amount);
    /// @notice A borrower withdrew collateral.
    event CollateralWithdrawn(address indexed user, uint256 amount);
    /// @notice A borrower borrowed stablecoin.
    event Borrowed(address indexed user, uint256 amount);
    /// @notice A borrower repaid stablecoin.
    event Repaid(address indexed user, uint256 amount);
    /// @notice A liquidator repaid part of `user`'s debt and seized collateral.
    event Liquidated(
        address indexed user,
        address indexed liquidator,
        uint256 repaid,
        uint256 collateralSeized
    );

    /// @param collateral_ Collateral token, 18 decimals.
    /// @param stable_ Borrowable token, 6 decimals.
    /// @param feed_ Price feed for the collateral, 8 decimals.
    /// @param admin Account that manages roles and can pause and unpause.
    constructor(IERC20 collateral_, IERC20 stable_, IPriceFeed feed_, address admin) {
        if (address(collateral_) == address(0) || address(stable_) == address(0)
            || address(feed_) == address(0) || admin == address(0)) {
            revert ZeroAddress();
        }
        if (IERC20Metadata(address(collateral_)).decimals() != 18
            || IERC20Metadata(address(stable_)).decimals() != 6
            || feed_.decimals() != 8) {
            revert UnsupportedDecimals();
        }
        collateral = collateral_;
        stable = stable_;
        feed = feed_;
        lastAccrual = block.timestamp;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    // ---- interest -----------------------------------------------------------

    /// @notice Annual borrow rate for a utilization, on a kinked line.
    /// @param utilBps Utilization in basis points.
    /// @return The rate in basis points.
    function borrowRateBps(uint256 utilBps) public pure returns (uint256) {
        if (utilBps <= KINK_UTIL_BPS) {
            return
                BASE_RATE_BPS +
                ((KINK_RATE_BPS - BASE_RATE_BPS) * utilBps) / KINK_UTIL_BPS;
        }
        return
            KINK_RATE_BPS +
            ((MAX_RATE_BPS - KINK_RATE_BPS) * (utilBps - KINK_UTIL_BPS)) /
                (BPS - KINK_UTIL_BPS);
    }

    /// @notice Share of supplied funds that is lent out.
    /// @return Utilization in basis points, at most 100%.
    function utilizationBps() public view returns (uint256) {
        uint256 supplied = (totalScaledSupply * supplyIndex) / RAY;
        if (supplied == 0) return 0;
        uint256 util = (((totalScaledDebt * borrowIndex) / RAY) * BPS) / supplied;
        return util > BPS ? BPS : util;
    }

    /// @notice Indexes as they would be after accruing up to now.
    /// @return bIndex Borrow index.
    /// @return sIndex Supply index.
    function currentIndexes() public view returns (uint256 bIndex, uint256 sIndex) {
        bIndex = borrowIndex;
        sIndex = supplyIndex;
        uint256 dt = block.timestamp - lastAccrual;
        if (dt == 0 || totalScaledDebt == 0) return (bIndex, sIndex);
        uint256 factor =
            (borrowRateBps(utilizationBps()) * dt * RAY) / (BPS * YEAR);
        uint256 interest = (((totalScaledDebt * bIndex) / RAY) * factor) / RAY;
        bIndex += (bIndex * factor) / RAY;
        if (totalScaledSupply > 0) sIndex += (interest * RAY) / totalScaledSupply;
    }

    /// @notice Brings both indexes up to date. Anyone may call it.
    function accrue() public {
        (uint256 b, uint256 s) = currentIndexes();
        borrowIndex = b;
        supplyIndex = s;
        lastAccrual = block.timestamp;
        emit Accrued(b, s, block.timestamp);
    }

    // ---- balances, prices and health -------------------------------------------

    /// @notice Current debt of `user`, interest included, rounded up.
    /// @param user Borrower.
    /// @return Debt, 6 decimals.
    function debtOf(address user) public view returns (uint256) {
        (uint256 bIndex, ) = currentIndexes();
        return _ceilDiv(scaledDebtOf[user] * bIndex, RAY);
    }

    /// @notice Current deposit of `user`, interest included, rounded down.
    /// @param user Lender.
    /// @return Deposit, 6 decimals.
    function suppliedOf(address user) public view returns (uint256) {
        (, uint256 sIndex) = currentIndexes();
        return (scaledSupplyOf[user] * sIndex) / RAY;
    }

    /// @notice Collateral price in USD with 18 decimals.
    /// @dev Rejects non-positive, future and stale answers.
    /// @return The price.
    function price() public view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = feed.latestRoundData();
        if (answer <= 0) revert BadPrice(answer);
        if (updatedAt == 0 || updatedAt > block.timestamp
            || block.timestamp - updatedAt > MAX_PRICE_AGE) {
            revert StalePrice(updatedAt);
        }
        return uint256(answer) * 1e10;
    }

    /// @notice 1e18 means exactly at the liquidation threshold.
    /// @param user Borrower.
    /// @return The health factor, 18 decimals.
    function healthFactor(address user) public view returns (uint256) {
        uint256 debtUsd = debtOf(user) * 1e12;
        if (debtUsd == 0) return type(uint256).max;
        uint256 collUsd = (collateralOf[user] * price()) / 1e18;
        return (collUsd * LIQ_THRESHOLD_BPS * 1e18) / (BPS * debtUsd);
    }

    /// @notice Stablecoin `user` can still borrow, 6 decimals.
    /// @param user Borrower.
    /// @return The amount.
    function availableToBorrow(address user) public view returns (uint256) {
        uint256 limit =
            (collateralOf[user] * price() * LTV_BPS) / (1e18 * BPS * 1e12);
        uint256 debt = debtOf(user);
        return limit > debt ? limit - debt : 0;
    }

    // ---- lenders ------------------------------------------------------------------

    /// @notice Supplies stablecoin for borrowers.
    /// @param amount Amount, 6 decimals.
    function supply(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        accrue();
        uint256 scaled = (amount * RAY) / supplyIndex;
        scaledSupplyOf[msg.sender] += scaled;
        totalScaledSupply += scaled;
        emit Supplied(msg.sender, amount);
        stable.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Withdraws a deposit, interest included, if it is not lent out.
    /// @param amount Amount, 6 decimals.
    function withdrawSupply(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        accrue();
        uint256 balance = (scaledSupplyOf[msg.sender] * supplyIndex) / RAY;
        if (amount > balance) revert ExceedsBalance(amount, balance);
        uint256 cash = stable.balanceOf(address(this));
        if (amount > cash) revert InsufficientLiquidity(amount, cash);
        // Rounding up favours the pool. It cannot exceed the lender's scaled
        // balance, because amount <= floor(scaled * index / RAY).
        uint256 scaled = _ceilDiv(amount * RAY, supplyIndex);
        scaledSupplyOf[msg.sender] -= scaled;
        totalScaledSupply -= scaled;
        emit SupplyWithdrawn(msg.sender, amount);
        stable.safeTransfer(msg.sender, amount);
    }

    // ---- borrowers ----------------------------------------------------------------

    /// @notice Deposits collateral.
    /// @param amount Amount, 18 decimals.
    function depositCollateral(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        collateralOf[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
        collateral.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Borrows stablecoin against the caller's collateral.
    /// @param amount Amount, 6 decimals.
    function borrow(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        accrue();
        uint256 available = availableToBorrow(msg.sender);
        if (amount > available) revert ExceedsBorrowLimit(amount, available);
        uint256 cash = stable.balanceOf(address(this));
        if (amount > cash) revert InsufficientLiquidity(amount, cash);
        uint256 scaled = _ceilDiv(amount * RAY, borrowIndex);
        scaledDebtOf[msg.sender] += scaled;
        totalScaledDebt += scaled;
        emit Borrowed(msg.sender, amount);
        stable.safeTransfer(msg.sender, amount);
    }

    /// @notice Repays debt; an amount above the debt repays exactly the debt.
    /// @param amount Amount, 6 decimals.
    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        accrue();
        uint256 debt = debtOf(msg.sender);
        if (amount > debt) amount = debt; // never take more than owed
        _reduceDebt(msg.sender, amount, debt);
        emit Repaid(msg.sender, amount);
        stable.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Withdraws collateral, if the position stays healthy.
    /// @param amount Amount, 18 decimals.
    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        accrue();
        uint256 balance = collateralOf[msg.sender];
        if (amount > balance) revert ExceedsBalance(amount, balance);
        collateralOf[msg.sender] = balance - amount;
        uint256 hf = healthFactor(msg.sender);
        if (hf < 1e18) revert Unhealthy(hf);
        emit CollateralWithdrawn(msg.sender, amount);
        collateral.safeTransfer(msg.sender, amount);
    }

    // ---- liquidators --------------------------------------------------------------

    /// @notice Repays part of an unhealthy position's debt and takes collateral
    ///         worth the repayment plus the bonus.
    /// @param user Borrower to liquidate.
    /// @param repayAmount Stablecoin to repay, at most the close factor.
    function liquidate(address user, uint256 repayAmount) external nonReentrant {
        accrue();
        uint256 hf = healthFactor(user);
        if (hf >= 1e18) revert Healthy(hf);
        uint256 debt = debtOf(user);
        uint256 maxRepay = (debt * CLOSE_FACTOR_BPS) / BPS;
        if (repayAmount == 0 || repayAmount > maxRepay) {
            revert RepayTooLarge(repayAmount, maxRepay);
        }
        uint256 seized =
            (repayAmount * 1e12 * (BPS + LIQ_BONUS_BPS) * 1e18) / (BPS * price());
        if (seized > collateralOf[user]) seized = collateralOf[user];
        _reduceDebt(user, repayAmount, debt);
        collateralOf[user] -= seized;
        emit Liquidated(user, msg.sender, repayAmount, seized);
        stable.safeTransferFrom(msg.sender, address(this), repayAmount);
        collateral.safeTransfer(msg.sender, seized);
    }

    // ---- emergency --------------------------------------------------------------

    /// @notice Stops supply, deposits and borrowing.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Resumes normal operation.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ---- internal -----------------------------------------------------------------

    function _reduceDebt(address user, uint256 amount, uint256 debt) private {
        uint256 scaled =
            amount == debt
                ? scaledDebtOf[user] // clear exactly
                : (amount * RAY) / borrowIndex; // round in pool's favour
        scaledDebtOf[user] -= scaled;
        totalScaledDebt -= scaled;
    }

    function _ceilDiv(uint256 a, uint256 b) private pure returns (uint256) {
        return a == 0 ? 0 : (a - 1) / b + 1;
    }
}
