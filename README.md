# Blockchain 2.0: companion repository

Code for *Blockchain 2.0: The Evolution to Smart Contracts and Decentralized Applications*
(The Blockchain Professional Series, Book 3) by Sami BELHADJ.

Every listing in the book comes from this repository and every output printed in the book
comes from `captured-outputs/`. If the book and the code disagree, the code is right.

| Folder | Content | Status |
|--------|---------|--------|
| `lab-01-asset-registry/` | Lab 1: AssetRegistry on Hardhat 3 | done, 36 tests |
| `lab-02-consent-dapp/` | Lab 2: consent contract and Vite frontend | done, 20 contract tests (22 with the lab tests), 4 library tests |
| `lab-03-erc20-token/` | Lab 3: SupplyChainToken | done, 22 tests |
| `chapter-01/` to `chapter-07/` | Chapter code and exercises | done |
| `captured-outputs/` | Real runs used in the book | local runs captured; Sepolia runs pending |

Toolchain pins are in `VERSIONS.md`.

## Contract standard

Every contract meant for use carries full NatSpec in this repository (the book prints the
listings without it), uses custom errors, emits an event for every change of state, and has
Solidity unit, fuzz and invariant tests next to it (`*.t.sol`) as well as Mocha tests in
`test/`. Ownership moves in two steps (`Ownable2Step` or `AccessControlDefaultAdminRules`),
and where a contract can be paused, the pause never blocks a withdrawal, a repayment or a
revocation. Hardhat's `--coverage` reports lines and statements; `tools/branch-coverage.sh`
measures branch coverage of the Solidity tests with Foundry's forge, and every production
contract reaches 100% (`captured-outputs/appendix/branch-coverage.txt`).

The deliberately flawed specimens keep their flaws, because the book asks you to find them:
`VulnerableVault`, `TxOrigin`, `PushPayout`, `Airdrop`, `Lottery`, `TokenSale` and
`ShipmentTracker` in chapter-03, and `legacy/PatientConsentDraft` in lab-02. Their NatSpec says
so. Do not deploy them. `Lottery` and `Airdrop` produce the only compiler warnings in the
repository: they use `transfer` on purpose.

Reference solutions for the exercises and labs (Appendices A and B) live next to the
code they extend: `contracts/solutions/` and `test/` in chapter-03 and chapter-05,
`scripts/solutions/` in chapter-07, and `lab-02-consent-dapp/frontend-solution/`.
