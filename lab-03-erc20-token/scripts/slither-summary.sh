#!/usr/bin/env bash
# Run Slither on SupplyChainToken and list findings in our code only.
# Requires: pip install slither-analyzer, and solc 0.8.34 on PATH.
set -uo pipefail
slither contracts/SupplyChainToken.sol \
  --solc-remaps "@openzeppelin/=node_modules/@openzeppelin/" \
  --filter-paths "node_modules" 2>&1 | grep -E "^Detector:|result\(s\) found"
