# Lab 1: Deploying your first smart contract on Ethereum

## Setup

```bash
npm install
npx hardhat compile
npx hardhat test              # 13 Solidity tests (unit, fuzz, invariant) + 23 Mocha tests
npx hardhat test --coverage
npx hardhat test --gas-stats
```

## Secrets (once per machine)

```bash
npx hardhat keystore set SEPOLIA_RPC_URL
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
npx hardhat keystore set ETHERSCAN_API_KEY
```

Use a dedicated test wallet. Never reuse a key that holds mainnet funds.

## Deploy, verify, interact

```bash
npx hardhat ignition deploy ignition/modules/AssetRegistry.ts --network sepolia --verify
REGISTRY=0xYourAddress npx hardhat run scripts/register-sample.ts --network sepolia
```

## Static analysis

```bash
pip install slither-analyzer
npm run slither
```
