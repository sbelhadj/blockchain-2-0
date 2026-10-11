// Registers one sample asset on a deployed AssetRegistry and prints the receipt.
// Usage: REGISTRY=0x... npx hardhat run scripts/register-sample.ts --network sepolia
import { network } from "hardhat";

const address = process.env.REGISTRY;
if (address === undefined) {
  throw new Error("Set REGISTRY to the deployed contract address");
}

const { ethers } = await network.getOrCreate();
const registry = await ethers.getContractAt("AssetRegistry", address);
const fee = await registry.registrationFee();

const tx = await registry.registerAsset(
  "MRI Scanner Lab Demo",
  "Demonstration asset for Book 3 Lab 1",
  0, // Industry.Healthcare
  "ipfs://QmLabDemoAsset",
  { value: fee },
);
console.log(`Transaction sent: ${tx.hash}`);

const receipt = await tx.wait();
if (receipt === null) throw new Error("No receipt");
console.log(`Mined in block ${receipt.blockNumber}`);
console.log(`Gas used: ${receipt.gasUsed}`);
console.log(
  `Effective gas price: ${ethers.formatUnits(receipt.gasPrice, "gwei")} gwei`,
);
console.log(`Fee paid: ${ethers.formatEther(receipt.fee)} ETH`);

const ids = await registry.getOwnerAssets(receipt.from);
const asset = await registry.getAsset(ids[ids.length - 1]);
console.log(`Asset ${asset.id}: ${asset.name}, owner ${asset.currentOwner}`);
