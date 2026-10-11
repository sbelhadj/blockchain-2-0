#!/usr/bin/env bash
# Recaptures every Chapter 2 output on one fresh local node, in the order of
# captured-outputs/chapter-02/README.md.
set -uo pipefail
C=../captured-outputs/chapter-02
npx hardhat compile >/dev/null
npx hardhat node > /tmp/chapter-02-node.log 2>&1 &
sleep 12
npx hardhat run scripts/delegate-demo.ts --network localhost > $C/listing-2-5.txt
npx hardhat run scripts/read-storage.ts --network localhost > $C/listing-2-4.txt
npx hardhat run scripts/set-delegation.ts --network localhost > $C/set-delegation.txt
ALICE=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
EXEC=$(grep executor $C/set-delegation.txt | awk '{print $2}')
ADDRESS=$ALICE npx tsx scripts/account-info.ts > $C/listing-2-3.txt
npx tsx scripts/account-type.ts 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 "$EXEC" $ALICE > $C/listing-2-6.txt
TX=$(grep "batch tx hash" $C/listing-2-5.txt | awk '{print $4}') npx tsx scripts/fee-from-receipt.ts > $C/listing-2-2.txt
for p in $(pgrep -f "[b]in/hardhat node"); do kill "$p"; done
./scripts/disassemble.sh > $C/listing-2-1.txt
for f in $C/*.txt; do sed -i '/./,$!d' "$f"; done
