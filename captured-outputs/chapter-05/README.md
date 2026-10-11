# Chapter 5 captured outputs

Captured 3 October 2026 (test-run and permit-flow again on 11 October 2026) with Hardhat 3.18.1 (in-process network, hardfork osaka),
solc 0.8.34, OpenZeppelin 5.6.1, Python 3.12.3.
- test-run.txt: npx hardhat test (44 passing: 30 Solidity, 14 Mocha)
- approve-flow.txt, permit-flow.txt: npx hardhat run scripts/<name>.ts
- read-feed-local.txt: npx tsx scripts/read-feed.ts without FEED (mock feed)
- amm.txt: python3 tools/amm.py
