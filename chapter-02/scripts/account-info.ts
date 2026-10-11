// Listing 2.3: what the world state holds for one account.
// Usage: RPC_URL=<endpoint> ADDRESS=0x... npx tsx scripts/account-info.ts
import { JsonRpcProvider, formatEther, formatUnits, keccak256 } from "ethers";

const url = process.env.RPC_URL ?? "http://127.0.0.1:8545";
const provider = new JsonRpcProvider(url);
const address = process.env.ADDRESS;
if (address === undefined) throw new Error("Set ADDRESS");

const [balance, nonce, code, block] = await Promise.all([
  provider.getBalance(address),
  provider.getTransactionCount(address),
  provider.getCode(address),
  provider.getBlock("latest"),
]);

console.log(`Account   ${address}`);
console.log(`  balance  ${balance} wei (${formatEther(balance)} ETH)`);
console.log(`  nonce    ${nonce}`);
console.log(`  code     ${(code.length - 2) / 2} bytes`);
console.log(`  codeHash ${keccak256(code)}`);
if (block !== null) {
  console.log(`Latest block ${block.number}`);
  console.log(`  gasLimit ${block.gasLimit}`);
  console.log(`  gasUsed  ${block.gasUsed}`);
  console.log(`  baseFee  ${formatUnits(block.baseFeePerGas ?? 0n, "gwei")} gwei`);
}
