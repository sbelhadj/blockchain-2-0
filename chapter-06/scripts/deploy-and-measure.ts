// Deploy AssetRegistry, register one asset, and save the cost breakdown.
// Usage: npx hardhat run scripts/deploy-and-measure.ts --network <name>
import { writeFileSync, mkdirSync } from "node:fs";
import { network } from "hardhat";

const conn = await network.getOrCreate();
const { ethers } = conn;
const fee = 1_000_000_000_000_000n;                     // 0.001 ETH registration fee

const registry = await ethers.deployContract("AssetRegistry", [fee]);
const deployRcpt = await registry.deploymentTransaction()!.wait();
const tx = await registry.registerAsset("Pump P-101", "Cooling pump", 3, "", {
  value: fee,
});
const regRcpt = await tx.wait();

// OP Stack receipts carry the L1 data fee as extra JSON-RPC fields.
async function costs(hash: string) {
  const raw = await ethers.provider.send("eth_getTransactionReceipt", [hash]);
  const gasUsed = BigInt(raw.gasUsed);
  const price = BigInt(raw.effectiveGasPrice);
  const l1Fee = raw.l1Fee !== undefined ? BigInt(raw.l1Fee) : 0n;      // absent on L1
  const l1GasUsed = raw.l1GasUsed !== undefined ? BigInt(raw.l1GasUsed) : 0n;
  return {
    gasUsed: gasUsed.toString(),
    executionFeeWei: (gasUsed * price).toString(),
    l1GasUsed: l1GasUsed.toString(),  // L1 gas the L2 charges for the data
    l1DataFeeWei: l1Fee.toString(),
    totalWei: (gasUsed * price + l1Fee).toString(),
  };
}

const result = {
  network: conn.networkName,
  chainId: (await ethers.provider.getNetwork()).chainId.toString(),
  deploy: await costs(deployRcpt!.hash),
  register: await costs(regRcpt!.hash),
};
mkdirSync("results", { recursive: true });
const file = `results/${conn.networkName}.json`;
writeFileSync(file, JSON.stringify(result, null, 2) + "\n");
console.log(JSON.stringify(result, null, 2));
