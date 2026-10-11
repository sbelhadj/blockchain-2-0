// Listing 1.1: read Ethereum's first two blocks and print the fields
// that Exercise 1.1 asks about.
// Usage: RPC_URL=<your endpoint> npx tsx read-blocks.ts
import { JsonRpcProvider } from "ethers";

const url = process.env.RPC_URL ?? "https://ethereum-rpc.publicnode.com";
const provider = new JsonRpcProvider(url);

for (const n of [0, 1]) {
  const block = await provider.getBlock(n);
  if (block === null) throw new Error(`Block ${n} not found`);
  const date = new Date(block.timestamp * 1000).toISOString(); // seconds to ms
  console.log(`Block ${block.number}`);
  console.log(`  hash         ${block.hash}`);
  console.log(`  parentHash   ${block.parentHash}`);
  console.log(`  timestamp    ${block.timestamp} (${date})`);
  console.log(`  miner        ${block.miner}`);
  console.log(`  difficulty   ${block.difficulty}`);
  console.log(`  gasLimit     ${block.gasLimit}`);
  console.log(`  gasUsed      ${block.gasUsed}`);
  console.log(`  transactions ${block.transactions.length}`);
  console.log(`  extraData    ${block.extraData}`);
}
