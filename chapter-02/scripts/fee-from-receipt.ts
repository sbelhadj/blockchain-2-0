// Listing 2.2: rebuild a transaction's fee from its receipt and its block.
// Usage: RPC_URL=<endpoint> TX=0x... npx tsx scripts/fee-from-receipt.ts
import { JsonRpcProvider, formatEther, formatUnits } from "ethers";

const url = process.env.RPC_URL ?? "http://127.0.0.1:8545";
const provider = new JsonRpcProvider(url);
const hash = process.env.TX;
if (hash === undefined) throw new Error("Set TX");

const tx = await provider.getTransaction(hash);
const receipt = await provider.getTransactionReceipt(hash);
if (tx === null || receipt === null) {
  throw new Error("Transaction not found or not mined");
}
const block = await provider.getBlock(receipt.blockNumber);
if (block === null || block.baseFeePerGas === null) {
  throw new Error("Block has no base fee");
}

const baseFee = block.baseFeePerGas;
const effective = receipt.gasPrice; // price actually paid per unit of gas
const tip = effective - baseFee;                // priority fee per unit of gas
const gwei = (x: bigint) => `${formatUnits(x, "gwei")} gwei`;

console.log(`type               ${tx.type}`);
console.log(`gasLimit           ${tx.gasLimit}`);
console.log(`gasUsed            ${receipt.gasUsed}`);
console.log(`maxFeePerGas       ${gwei(tx.maxFeePerGas ?? 0n)}`);
console.log(`maxPriorityFee     ${gwei(tx.maxPriorityFeePerGas ?? 0n)}`);
console.log(`block baseFee      ${gwei(baseFee)}`);
console.log(`effective price    ${gwei(effective)}`);
console.log(`total fee          ${formatEther(receipt.gasUsed * effective)} ETH`);
console.log(`  burned           ${formatEther(receipt.gasUsed * baseFee)} ETH`);
console.log(`  to proposer      ${formatEther(receipt.gasUsed * tip)} ETH`);
console.log(`receipt.fee check  ${receipt.fee === receipt.gasUsed * effective}`);
