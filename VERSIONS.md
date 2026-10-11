# Frozen toolchain for Book 3

Frozen on 3 October 2026. Every version printed in the book is taken from this file.
Change a pin only together with a re-run of every affected test and an errata entry in Appendix D.

| Tool | Version | How it is installed |
|------|---------|---------------------|
| Node.js | 22 LTS (verified on 22.22.2) | nodejs.org |
| npm | 10.x (verified on 10.9.7) | ships with Node.js |
| Hardhat | 3.18.1 | `npm install --save-dev hardhat@3.18.1` |
| Hardhat toolbox | @nomicfoundation/hardhat-toolbox-mocha-ethers 4.0.0 | project devDependency |
| Solidity compiler | 0.8.34 (Hardhat 3.18 template default, EVM target `osaka`) | downloaded by Hardhat on first compile |
| Contract pragma | `^0.8.24` | source files |
| OpenZeppelin Contracts | 5.6.1 | project dependency |
| ethers | 6.17.0 | project devDependency |
| TypeScript | 6.0.3 | project devDependency |
| forge-std (Solidity tests) | 1.16.2 | `github:foundry-rs/forge-std#v1.16.2` |
| Slither | 0.11.6 | `pip install slither-analyzer` |
| Foundry forge (optional) | 1.5.1 | `foundryup`; used only by `tools/branch-coverage.sh` |
| Python | 3.10 or later (verified on 3.12.3) | python.org |
| React | 19.x | Lab 2 frontend |
| Vite | 8.x | Lab 2 frontend |
| MetaMask | `[VERIFY]` record the extension version at capture time | browser store |

## Networks

| Network | Use | Note |
|---------|-----|------|
| Hardhat simulated (`edr-simulated`) | Tests and local runs | no setup |
| Sepolia | All labs and chapter exercises | captures taken after the Glamsterdam Sepolia fork (6 October 2026) |
| L2 testnet | Exercise 6.1 only | Base Sepolia or OP Sepolia, chosen at capture time by faucet reliability `[VERIFY]` |

## Secrets

RPC URLs, private keys and the Etherscan API key are stored in the encrypted Hardhat keystore
(`npx hardhat keystore set NAME`). Nothing secret goes into a file in the repository.
