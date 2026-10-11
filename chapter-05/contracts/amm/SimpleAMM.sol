// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title SimpleAMM
/// @author Sami BELHADJ, Book 3, Chapter 5
/// @notice Constant product market maker (x * y = k) with a 0.3% fee.
/// @dev Every trade takes a minimum output and a deadline. The first deposit
///      locks MINIMUM_LIQUIDITY shares, as Uniswap v2 does, so nobody can
///      inflate the share price of an empty pool. Pausing stops swaps and new
///      liquidity, never withdrawals. Tokens that charge a fee on transfer are
///      not supported. Teaching code, not audited.
contract SimpleAMM is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role allowed to pause.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @notice Shares locked forever by the first deposit.
    uint256 public constant MINIMUM_LIQUIDITY = 1_000;
    uint256 private constant FEE_NUM = 997;    // 0.3% fee stays in the pool
    uint256 private constant FEE_DEN = 1000;

    /// @notice First token of the pair.
    IERC20 public immutable tokenA;
    /// @notice Second token of the pair.
    IERC20 public immutable tokenB;
    /// @notice Pool balance of token A used for pricing.
    uint256 public reserveA;
    /// @notice Pool balance of token B used for pricing.
    uint256 public reserveB;
    /// @notice All shares in existence, including the locked ones.
    uint256 public totalShares;
    /// @notice Shares held by each liquidity provider.
    mapping(address => uint256) public shares;

    /// @notice A token is zero, both tokens are the same, or the token is not
    ///         part of the pair.
    error InvalidToken();
    /// @notice The admin address is zero.
    error ZeroAddress();
    /// @notice The amount is zero.
    error ZeroAmount();
    /// @notice The transaction was mined after its deadline.
    error Expired(uint256 deadline);
    /// @notice The swap would pay less than the trader's minimum.
    error SlippageExceeded(uint256 out, uint256 minOut);
    /// @notice The deposit would mint fewer shares than the provider's minimum.
    error InsufficientShares(uint256 minted, uint256 minShares);
    /// @notice A withdrawal would pay less than the provider's minimum.
    error InsufficientOutput(uint256 amountA, uint256 amountB);
    /// @notice The provider does not hold that many shares.
    error ExceedsShares(uint256 requested, uint256 held);

    /// @notice A trade happened.
    event Swap(
        address indexed trader, address indexed tokenIn, uint256 amountIn,
        uint256 amountOut
    );
    /// @notice Liquidity was added.
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB,
        uint256 sharesMinted);
    /// @notice Liquidity was removed.
    event LiquidityRemoved(address indexed provider, uint256 amountA,
        uint256 amountB, uint256 sharesBurned);

    /// @dev Rejects a call mined after the caller's deadline.
    modifier beforeDeadline(uint256 deadline) {
        _checkDeadline(deadline);
        _;
    }

    /// @param a First token.
    /// @param b Second token.
    /// @param admin Account that manages roles and can pause and unpause.
    constructor(IERC20 a, IERC20 b, address admin) {
        if (address(a) == address(0) || address(b) == address(0)
            || address(a) == address(b)) {
            revert InvalidToken();
        }
        if (admin == address(0)) revert ZeroAddress();
        tokenA = a;
        tokenB = b;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    /// @notice Output for a given input, after the fee:
    ///         out = y * dx' / (x + dx'), with dx' = dx * 0.997.
    /// @param amountIn Input amount.
    /// @param reserveIn Reserve of the input token.
    /// @param reserveOut Reserve of the output token.
    /// @return The output amount.
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256)
    {
        uint256 inWithFee = amountIn * FEE_NUM;
        return (reserveOut * inWithFee) / (reserveIn * FEE_DEN + inWithFee);
    }

    /// @notice Deposits both tokens and mints pool shares.
    /// @param amountA Token A to deposit.
    /// @param amountB Token B to deposit.
    /// @param minShares Fewest shares the provider accepts.
    /// @param deadline Latest timestamp at which the deposit may execute.
    /// @return minted Shares minted to the caller.
    function addLiquidity(
        uint256 amountA,
        uint256 amountB,
        uint256 minShares,
        uint256 deadline
    )
        external
        nonReentrant
        whenNotPaused
        beforeDeadline(deadline)
        returns (uint256 minted)
    {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();
        if (totalShares == 0) {
            uint256 root = Math.sqrt(amountA * amountB);
            if (root <= MINIMUM_LIQUIDITY) revert InsufficientShares(0, minShares);
            minted = root - MINIMUM_LIQUIDITY;
            shares[address(0)] = MINIMUM_LIQUIDITY;
            totalShares = MINIMUM_LIQUIDITY;
        } else {
            minted = Math.min(
                amountA * totalShares / reserveA, amountB * totalShares / reserveB
            );
        }
        if (minted == 0 || minted < minShares) {
            revert InsufficientShares(minted, minShares);
        }
        shares[msg.sender] += minted;
        totalShares += minted;
        reserveA += amountA;
        reserveB += amountB;
        emit LiquidityAdded(msg.sender, amountA, amountB, minted);
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);
    }

    /// @notice Burns shares and returns the provider's part of both reserves.
    ///         Works while paused.
    /// @param shareAmount Shares to burn.
    /// @param minA Least token A the provider accepts.
    /// @param minB Least token B the provider accepts.
    /// @param deadline Latest timestamp at which the withdrawal may execute.
    /// @return amountA Token A paid out.
    /// @return amountB Token B paid out.
    function removeLiquidity(
        uint256 shareAmount,
        uint256 minA,
        uint256 minB,
        uint256 deadline
    )
        external
        nonReentrant
        beforeDeadline(deadline)
        returns (uint256 amountA, uint256 amountB)
    {
        if (shareAmount == 0) revert ZeroAmount();
        uint256 held = shares[msg.sender];
        if (shareAmount > held) revert ExceedsShares(shareAmount, held);
        amountA = reserveA * shareAmount / totalShares;
        amountB = reserveB * shareAmount / totalShares;
        if (amountA < minA || amountB < minB) {
            revert InsufficientOutput(amountA, amountB);
        }
        shares[msg.sender] = held - shareAmount;
        totalShares -= shareAmount;
        reserveA -= amountA;
        reserveB -= amountB;
        emit LiquidityRemoved(msg.sender, amountA, amountB, shareAmount);
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);
    }

    /// @notice Sells `amountIn` of `tokenIn` for the other token.
    /// @param tokenIn Token the trader pays with.
    /// @param amountIn Amount the trader pays.
    /// @param minOut Least output the trader accepts; protects against slippage
    ///        and sandwich attacks.
    /// @param deadline Latest timestamp at which the trade may execute.
    /// @return out Amount paid to the trader.
    function swap(IERC20 tokenIn, uint256 amountIn, uint256 minOut, uint256 deadline)
        external
        nonReentrant
        whenNotPaused
        beforeDeadline(deadline)
        returns (uint256 out)
    {
        if (amountIn == 0) revert ZeroAmount();
        bool aIn = address(tokenIn) == address(tokenA);
        if (!aIn && address(tokenIn) != address(tokenB)) revert InvalidToken();
        (uint256 rIn, uint256 rOut) =
            aIn ? (reserveA, reserveB) : (reserveB, reserveA);
        out = getAmountOut(amountIn, rIn, rOut);
        if (out == 0 || out < minOut) revert SlippageExceeded(out, minOut);

        if (aIn) { reserveA += amountIn; reserveB -= out; }
        else     { reserveB += amountIn; reserveA -= out; }
        emit Swap(msg.sender, address(tokenIn), amountIn, out);
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        (aIn ? tokenB : tokenA).safeTransfer(msg.sender, out);
    }

    /// @notice Stops swaps and new liquidity.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Resumes trading.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @dev Kept out of the modifier so its body is not copied into every
    ///      function that uses it.
    function _checkDeadline(uint256 deadline) private view {
        if (block.timestamp > deadline) revert Expired(deadline);
    }
}
