#!/usr/bin/env bash
# Runs the full test suite with coverage and prints a compact table.
set -euo pipefail
printf "%-38s %6s %6s  %s\n" "file" "line%" "stmt%" "uncovered lines"
npx hardhat test --coverage 2>&1 \
  | sed -n '/File Path/,/Total/p' \
  | grep -E 'contracts/|Total' \
  | awk -F'│' '{gsub(/║|contracts\/| /,"",$1); gsub(/ /,"",$2); gsub(/ /,"",$3); gsub(/║/,"",$4); gsub(/^ +| +$/,"",$4);
                printf "%-38s %6s %6s  %s\n", $1, $2, $3, $4}'
