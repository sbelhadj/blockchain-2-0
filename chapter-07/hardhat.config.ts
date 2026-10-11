import toolbox from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { defineConfig } from "hardhat/config";

export default defineConfig({
  plugins: [toolbox],
  solidity: { version: "0.8.34" },
});
