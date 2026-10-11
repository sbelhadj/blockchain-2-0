// Measures gas for the optimization examples in Section 3.8 and Exercise 3.4.
// Usage: npx hardhat run scripts/gas-compare.ts
import { network } from "hardhat";

const { ethers } = await network.create();
const [user] = await ethers.getSigners();
const used = async (tx: Promise<{ wait: () => Promise<{ gasUsed: bigint } | null> }>) =>
  (await (await tx).wait())!.gasUsed;
const row = (label: string, a: bigint, b: bigint) =>
  console.log(`${label.padEnd(30)} ${a.toString().padStart(8)} ${b.toString().padStart(8)}` +
    `  ${(Number(a - b) * 100 / Number(a)).toFixed(1).padStart(5)}%`);

console.log(`${"".padEnd(30)} ${"before".padStart(8)} ${"after".padStart(8)}  saved`);

// 1. Caching a storage read (same account, warm slot after deposit)
const book = await ethers.deployContract("BalanceBook");
await (await book.deposit({ value: 1_000n })).wait();
const repeated = await used(book.debitRepeated(1n));
const cached = await used(book.debitCached(1n));
row("debit: repeated vs cached read", repeated, cached);

// 2. Struct packing: first write of a new record
const wide = await ethers.deployContract("ShipmentLogWide");
const packed = await ethers.deployContract("ShipmentLogPacked");
row("record: wide vs packed struct", await used(wide.record(1, 500, true)),
  await used(packed.record(1, 500, true)));

// 3. Exercise 3.4: starting point vs reference solution, first and second shipment
const before = await ethers.deployContract("ShipmentTracker");
const after = await ethers.deployContract("ShipmentTrackerOptimized");
const args = ["Rades port", "Sfax warehouse", 1200, user.address, "IN_TRANSIT", 45] as const;
for (const n of [1, 2]) {
  row(`recordShipment, call ${n}`, await used(before.recordShipment(...args)),
    await used(after.recordShipment(...args)));
}
