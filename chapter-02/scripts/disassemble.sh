#!/usr/bin/env bash
# Listing 2.1: what the compiler makes of Adder.add (requires solc 0.8.34 on PATH).
set -euo pipefail
echo "== function selector"
solc --hashes contracts/Adder.sol | tail -1
echo "== first 40 bytes of the runtime bytecode"
solc --bin-runtime contracts/Adder.sol | tail -1 | cut -c1-80
echo "== dispatcher (assembly excerpt)"
solc --asm contracts/Adder.sol | sed -n '33,42p'
echo "== overflow check: Panic(uint256) selector and code 0x11"
solc --asm contracts/Adder.sol \
  | grep -E '0x4e487b71|^\s+0x11$' \
  | sed 's/0\{56\}$/.../'
