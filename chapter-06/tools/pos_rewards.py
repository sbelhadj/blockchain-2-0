"""Ideal annual consensus-layer reward for a 32 ETH validator (Exercise 6.3).
Constants from the consensus specifications. Execution-layer tips and MEV
are not included.
Usage: python3 tools/pos_rewards.py <total ETH staked>"""
import sys
from math import isqrt

GWEI = 10**9
BASE_REWARD_FACTOR = 64
INCREMENT = 1 * 10**9            # EFFECTIVE_BALANCE_INCREMENT: 1 ETH in gwei
SECONDS_PER_SLOT, SLOTS_PER_EPOCH = 12, 32
EPOCHS_PER_YEAR = 365.25 * 24 * 3600 / (SECONDS_PER_SLOT * SLOTS_PER_EPOCH)

def apr(total_staked_eth: float, participation: float = 1.0,
        balance_eth: int = 32) -> float:
    total_gwei = int(total_staked_eth * GWEI)
    # Base reward per 1 ETH increment per epoch, in gwei.
    per_increment = INCREMENT * BASE_REWARD_FACTOR // isqrt(total_gwei)
    per_epoch = per_increment * balance_eth * participation
    return per_epoch * EPOCHS_PER_YEAR / (balance_eth * GWEI)

if __name__ == "__main__":
    staked = float(sys.argv[1]) if len(sys.argv) > 1 else 34_000_000
    print(f"total staked: {staked:,.0f} ETH")
    print(f"epochs per year: {EPOCHS_PER_YEAR:,.0f}")
    print(f"{'participation':>13} {'reward / year':>14} {'APR':>7}")
    for p in (1.00, 0.95, 0.80):
        r = apr(staked, p)
        print(f"{p:>13.0%} {r * 32:>10.4f} ETH {r:>7.2%}")
    print()
    print(f"{'ETH staked':>14} {'APR at 100%':>12}")
    for s in (10e6, 20e6, 34e6, 50e6, 80e6):
        print(f"{s:>14,.0f} {apr(s):>12.2%}")
