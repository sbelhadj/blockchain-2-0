#!/usr/bin/env bash
# Run Slither on each flawed contract and list the detectors that fire.
# Requires: pip install slither-analyzer, and solc 0.8.34 on PATH.
set -uo pipefail
for f in security/VulnerableVault.sol security/TxOrigin.sol \
         exercises/Lottery.sol exercises/TokenSale.sol exercises/Airdrop.sol; do
  found=$(slither "contracts/$f" \
            --solc-remaps "@openzeppelin/=node_modules/@openzeppelin/" \
            --exclude-dependencies --exclude-informational 2>&1 \
          | sed -n "s/^Detector: //p" | sort -u | paste -sd, - | sed "s/,/, /g")
  printf '%-28s %s\n' "$f" "${found:-none}"
done
