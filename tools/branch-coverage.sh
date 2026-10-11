#!/usr/bin/env bash
# Branch coverage for one project's Solidity tests, measured with Foundry's forge.
#
# Hardhat 3's --coverage reports lines and statements only. The book's claim that the
# production contracts reach 100% branch coverage was measured with this script.
# forge is a measuring tool here, not part of the book's toolchain: install it with
# foundryup (https://getfoundry.sh), then run, from the repository root:
#
#   tools/branch-coverage.sh lab-01-asset-registry
#   tools/branch-coverage.sh lab-02-consent-dapp/contracts
#   tools/branch-coverage.sh chapter-05
#
# The project must have run `npm install` and `npx hardhat compile` once, so that its
# node_modules and Hardhat's solc 0.8.34 binary are present. The script works in a
# scratch copy and never writes into the project.
set -euo pipefail
proj=$(realpath "$1"); src=${2:-contracts}
FORGE=${FORGE:-forge}
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cp -r "$proj/$src" "$work/src"
ln -s "$proj/node_modules" "$work/node_modules"
SOLC=$(ls "${HARDHAT_COMPILERS:-$HOME/.cache/hardhat-nodejs/compilers-v3}"/*/solc-*-v0.8.34* | head -1)
cat > "$work/foundry.toml" <<TOML
[profile.default]
src = "src"
test = "src"
out = "out"
libs = ["node_modules"]
solc = "$SOLC"
evm_version = "osaka"
offline = true
remappings = ["@openzeppelin/=node_modules/@openzeppelin/", "forge-std/=node_modules/forge-std/src/", "@account-abstraction/=node_modules/@account-abstraction/"]
TOML
# Fewer invariant runs than the Hardhat suites (256) keep coverage under a few minutes;
# coverage depends on which branches are reached, not on how often.
cd "$work" && FOUNDRY_INVARIANT_RUNS=32 FOUNDRY_INVARIANT_DEPTH=40 \
  "$FORGE" coverage --report summary --ir-minimum --no-match-coverage "node_modules|\.t\.sol" 2>&1 \
  | sed -n "/^| File/,\$p"
