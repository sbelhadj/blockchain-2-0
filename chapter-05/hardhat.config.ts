import toolbox from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { configVariable, defineConfig } from "hardhat/config";

export default defineConfig({
  plugins: [toolbox],
  solidity: {
    profiles: {
      default: {
        version: "0.8.34",
      },
      production: {
        version: "0.8.34",
        settings: {
          optimizer: { enabled: true, runs: 200 },
        },
      },
    },
  },
  networks: {
    // Used by the Exercise 5.4 boundary test: several blocks may share a timestamp.
    frozenClock: {
      type: "edr-simulated",
      chainType: "l1",
      allowBlocksWithSameTimestamp: true,
    },
    hardhatMainnet: { type: "edr-simulated", chainType: "l1" },
    sepolia: {
      type: "http",
      chainType: "l1",
      // Secrets come from the encrypted Hardhat keystore, never from a file.
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
  },
  verify: {
    etherscan: {
      apiKey: configVariable("ETHERSCAN_API_KEY"),
    },
  },
});
