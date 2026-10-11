# Chapter 4 captured outputs

Captured 3 October 2026; contract tests, library tests, build and ABI export again on 11 October 2026. Contracts: Hardhat 3.18.1, solc 0.8.34, OpenZeppelin 5.6.1.
Frontend: Vite 8.3.2, React 19.3.0, ethers 6.17.0, Node 22.22.2.
- contract-tests.txt: npx hardhat test in lab-02-consent-dapp/contracts
- export-abi.txt: npx tsx scripts/export-abi.ts
- lib-tests.txt: npm run test:lib in frontend, against a local Hardhat node
- build.txt: npm run build with VITE_CONSENT_ADDRESS, VITE_CHAIN_ID=31337 and a localhost RPC set
- tree.txt: lab-02-consent-dapp/tree.sh
The in-browser wallet flow is exercised by the reader (Exercise 4.1, Lab 2).
