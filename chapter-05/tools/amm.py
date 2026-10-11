"""Constant product AMM and impermanent loss calculator (Exercise 5.2).
Usage: python3 tools/amm.py"""
from math import sqrt

FEE = 0.003

def amount_out(x_in: float, reserve_in: float, reserve_out: float,
               fee: float = FEE) -> float:
    dx = x_in * (1 - fee)
    return reserve_out * dx / (reserve_in + dx)

def impermanent_loss(ratio: float) -> float:
    """LP position value relative to holding, after a given price ratio change."""
    return 2 * sqrt(ratio) / (1 + ratio) - 1

if __name__ == "__main__":
    x, y = 100.0, 300_000.0          # 100 WETH and 300,000 tUSD: 3,000 tUSD per WETH
    print("Swaps into a pool of 100 WETH / 300,000 tUSD")
    print(f"{'WETH in':>8} {'tUSD out':>12} {'avg price':>10} {'below spot':>11}")
    for dx in (1, 5, 10, 25):
        out = amount_out(dx, x, y)
        avg = out / dx
        print(f"{dx:>8} {out:>12,.2f} {avg:>10,.2f} {(1 - avg / 3000) * 100:>10.2f}%")
    print()
    print("Impermanent loss (fees not included)")
    print(f"{'price ratio':>11} {'loss':>8}")
    for r in (0.25, 0.5, 0.8, 1.0, 1.25, 1.5, 2.0, 3.0, 5.0):
        print(f"{r:>10.2f}x {impermanent_loss(r) * 100:>7.2f}%")
