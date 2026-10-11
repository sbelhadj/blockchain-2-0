import toolbox from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { configVariable, defineConfig } from "hardhat/config";

export default defineConfig({
  plugins: [toolbox],
  solidity: {
    profiles: {
      default: { version: "0.8.34" },
      production: {
        version: "0.8.34",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
    },
  },
  networks: {
    // Local simulations of an L1 and of an OP Stack L2 (which adds an L1 data fee).
    localL1: { type: "edr-simulated", chainType: "l1" },
    localOp: { type: "edr-simulated", chainType: "op" },
    sepolia: {
      type: "http", chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
    // Choose one L2 testnet (Section 6.9); both are OP Stack chains.
    baseSepolia: {
      type: "http", chainType: "op",
      url: configVariable("BASE_SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
    opSepolia: {
      type: "http", chainType: "op",
      url: configVariable("OP_SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
  },
});
