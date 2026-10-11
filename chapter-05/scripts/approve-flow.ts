// The approve / transferFrom pattern, step by step, on the local network.
// Usage: npx hardhat run scripts/approve-flow.ts
import { network } from "hardhat";

const { ethers } = await network.create();
// "pool" stands in for a contract such as a lending pool.
const [alice, pool] = await ethers.getSigners();
const usd = await ethers.deployContract("TestToken", ["Test USD", "tUSD", 6]);
const fmt = (x: bigint) => ethers.formatUnits(x, 6);
await usd.mint(alice.address, 1_000_000_000n);       // 1,000 tUSD

const show = async (step: string) => console.log(
  `${step.padEnd(34)} alice ${fmt(await usd.balanceOf(alice.address)).padStart(8)}` +
  `  pool ${fmt(await usd.balanceOf(pool.address)).padStart(8)}` +
  `  allowance ${fmt(await usd.allowance(alice.address, pool.address)).padStart(8)}`);

await show("start");
const a = await (await usd.connect(alice).approve(pool.address, 250_000_000n)).wait();
await show(`1. alice approves 250 (gas ${a!.gasUsed})`);
const t = await (await usd.connect(pool).transferFrom(alice.address, pool.address,
  100_000_000n)).wait();
await show(`2. pool pulls 100 (gas ${t!.gasUsed})`);
try {
  await usd.connect(pool).transferFrom(alice.address, pool.address, 200_000_000n);
} catch (err) {
  const reason = usd.interface.parseError((err as { data: string }).data);
  console.log(`3. pool pulls 200: reverted with ${reason?.name}`);
}
