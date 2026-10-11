#!/usr/bin/env bash
# Part D: run Slither on AssetRegistry and count findings by impact and detector.
set -uo pipefail
slither contracts/AssetRegistry.sol \
  --solc-remaps "@openzeppelin/=node_modules/@openzeppelin/" --json - 2>/dev/null \
  | python3 tools/slither_summary.py
