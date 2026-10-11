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

/// @title LendingPool
/// @author Sami BELHADJ, Book 3, Chapter 5
/// @notice Over-collateralized lending with one collateral asset (18 decimals)
///         and one borrowable stablecoin (6 decimals). No interest: Exercise 5.4
///         adds it.
/// @dev Pausing stops new risk (supply, deposits, borrowing). Repaying,
///      withdrawing and liquidating always work, so a pause cannot trap funds
///      or let bad debt grow. Teaching code, not audited.
contract LendingPool is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role allowed to pause.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice 100% in basis points.
    uint256 public constant BPS = 10_000;
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

    /// @notice Collateral asset, e.g. a wrapped ETH, 18 decimals.
    IERC20 public immutable collateral;
    /// @notice Borrowable asset, e.g. a USD stablecoin, 6 decimals.
    IERC20 public immutable stable;
    /// @notice USD price of one collateral unit, 8 decimals.
    IPriceFeed public immutable feed;

    /// @notice Collateral deposited by each borrower.
    mapping(address => uint256) public collateralOf;
    /// @notice Stablecoin owed by each borrower.
    mapping(address => uint256) public debtOf;
    /// @notice Stablecoin supplied by each lender.
    mapping(address => uint256) public suppliedOf;

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
    /// @notice The amount is larger than the caller's balance or debt.
    error ExceedsBalance(uint256 requested, uint256 balance);
    /// @notice The action would leave the position liquidatable.
    error Unhealthy(uint256 healthFactor);
    /// @notice The position is healthy and cannot be liquidated.
    error Healthy(uint256 healthFactor);
    /// @notice The repayment is zero or above the close factor.
    error RepayTooLarge(uint256 repay, uint256 maxRepay);
    /// @notice The pool does not hold enough stablecoin.
    error InsufficientLiquidity(uint256 requested, uint256 available);

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
    event Liquidated(address indexed user, address indexed liquidator,
        uint256 repaid, uint256 collateralSeized);

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
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    // ---- prices and health ------------------------------------------------

    /// @notice Collateral price in USD with 18 decimals.
    /// @dev Rejects non-positive, future and stale answers.
    /// @return The price.
    function price() public view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        if (answer <= 0) revert BadPrice(answer);
        if (updatedAt == 0 || updatedAt > block.timestamp
            || block.timestamp - updatedAt > MAX_PRICE_AGE) {
            revert StalePrice(updatedAt);
        }
        return uint256(answer) * 1e10;               // 8 decimals -> 18 decimals
    }

    /// @notice USD value of `user`'s collateral, 18 decimals.
    /// @param user Borrower.
    /// @return The value.
    function collateralValueUsd(address user) public view returns (uint256) {
        return collateralOf[user] * price() / 1e18;
    }

    /// @notice USD value of `user`'s debt, 18 decimals, at $1 per stablecoin.
    /// @param user Borrower.
    /// @return The value.
    function debtValueUsd(address user) public view returns (uint256) {
        return debtOf[user] * 1e12;                  // 6 decimals -> 18
    }

    /// @notice 1e18 means exactly at the liquidation threshold; below 1e18 the
    ///         position can be liquidated.
    /// @param user Borrower.
    /// @return The health factor, 18 decimals.
    function healthFactor(address user) public view returns (uint256) {
        uint256 debt = debtValueUsd(user);
        if (debt == 0) return type(uint256).max;
        return collateralValueUsd(user) * LIQ_THRESHOLD_BPS * 1e18 / (BPS * debt);
    }

    /// @notice Stablecoin `user` can still borrow, 6 decimals.
    /// @param user Borrower.
    /// @return The amount.
    function availableToBorrow(address user) public view returns (uint256) {
        uint256 limit = collateralValueUsd(user) * LTV_BPS / BPS / 1e12;
        return limit > debtOf[user] ? limit - debtOf[user] : 0;
    }

    // ---- lenders ----------------------------------------------------------

    /// @notice Supplies stablecoin for borrowers.
    /// @param amount Amount, 6 decimals.
    function supply(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        suppliedOf[msg.sender] += amount;
        emit Supplied(msg.sender, amount);
        stable.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Withdraws supplied stablecoin that is not currently lent out.
    /// @param amount Amount, 6 decimals.
    function withdrawSupply(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 balance = suppliedOf[msg.sender];
        if (amount > balance) revert ExceedsBalance(amount, balance);
        uint256 cash = stable.balanceOf(address(this));
        if (amount > cash) revert InsufficientLiquidity(amount, cash);
        suppliedOf[msg.sender] = balance - amount;
        emit SupplyWithdrawn(msg.sender, amount);
        stable.safeTransfer(msg.sender, amount);
    }

    // ---- borrowers --------------------------------------------------------

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
        uint256 available = availableToBorrow(msg.sender);
        if (amount > available) revert ExceedsBorrowLimit(amount, available);
        uint256 cash = stable.balanceOf(address(this));
        if (amount > cash) revert InsufficientLiquidity(amount, cash);
        debtOf[msg.sender] += amount;
        emit Borrowed(msg.sender, amount);
        stable.safeTransfer(msg.sender, amount);
    }

    /// @notice Repays the caller's debt. Works while paused.
    /// @param amount Amount, 6 decimals, at most the debt.
    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 debt = debtOf[msg.sender];
        if (amount > debt) revert ExceedsBalance(amount, debt);
        debtOf[msg.sender] = debt - amount;
        emit Repaid(msg.sender, amount);
        stable.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Withdraws collateral, if the position stays healthy.
    /// @param amount Amount, 18 decimals.
    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 balance = collateralOf[msg.sender];
        if (amount > balance) revert ExceedsBalance(amount, balance);
        collateralOf[msg.sender] = balance - amount;
        uint256 hf = healthFactor(msg.sender);
        if (hf < 1e18) revert Unhealthy(hf);         // check after the change
        emit CollateralWithdrawn(msg.sender, amount);
        collateral.safeTransfer(msg.sender, amount);
    }

    // ---- liquidators ------------------------------------------------------

    /// @notice Repays part of an unhealthy position's debt and takes collateral
    ///         worth the repayment plus the bonus. Works while paused.
    /// @param user Borrower to liquidate.
    /// @param repayAmount Stablecoin to repay, at most the close factor.
    function liquidate(address user, uint256 repayAmount) external nonReentrant {
        uint256 hf = healthFactor(user);
        if (hf >= 1e18) revert Healthy(hf);
        uint256 maxRepay = debtOf[user] * CLOSE_FACTOR_BPS / BPS;
        if (repayAmount == 0 || repayAmount > maxRepay) {
            revert RepayTooLarge(repayAmount, maxRepay);
        }
        // Collateral worth the repaid debt plus the bonus, at the oracle price.
        uint256 repaidUsd = repayAmount * 1e12;
        uint256 seized = repaidUsd * (BPS + LIQ_BONUS_BPS) * 1e18 / (BPS * price());
        if (seized > collateralOf[user]) seized = collateralOf[user];

        debtOf[user] -= repayAmount;
        collateralOf[user] -= seized;
        emit Liquidated(user, msg.sender, repayAmount, seized);
        stable.safeTransferFrom(msg.sender, address(this), repayAmount);
        collateral.safeTransfer(msg.sender, seized);
    }

    // ---- emergency --------------------------------------------------------

    /// @notice Stops supply, deposits and borrowing.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Resumes normal operation.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
