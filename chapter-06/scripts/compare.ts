// Compare two saved results, e.g. Sepolia against an L2 testnet.
// Usage: npx tsx scripts/compare.ts results/sepolia.json results/baseSepolia.json
import { readFileSync } from "node:fs";
import { formatEther } from "ethers";

const [a, b] = process.argv.slice(2).map((f) => JSON.parse(readFileSync(f, "utf8")));
const eth = (wei: string) => formatEther(BigInt(wei)).padStart(22);
console.log(`${"".padEnd(30)}${a.network.padStart(22)}${b.network.padStart(22)}`);
for (const step of ["deploy", "register"] as const) {
  console.log(`${step}: gas used`.padEnd(30) +
    `${a[step].gasUsed.padStart(22)}${b[step].gasUsed.padStart(22)}`);
  console.log(`${step}: execution fee (ETH)`.padEnd(30) +
    `${eth(a[step].executionFeeWei)}${eth(b[step].executionFeeWei)}`);
  console.log(`${step}: L1 gas for data`.padEnd(30) +
    `${a[step].l1GasUsed.padStart(22)}${b[step].l1GasUsed.padStart(22)}`);
  console.log(`${step}: L1 data fee (ETH)`.padEnd(30) +
    `${eth(a[step].l1DataFeeWei)}${eth(b[step].l1DataFeeWei)}`);
  console.log(`${step}: total (ETH)`.padEnd(30) +
    `${eth(a[step].totalWei)}${eth(b[step].totalWei)}`);
}
