// Read a Chainlink-style price feed and check that the answer is fresh.
// Sepolia: RPC_URL=<endpoint> FEED=<feed address> npx tsx scripts/read-feed.ts
// Without FEED, the script deploys MockPriceFeed on an in-memory network instead.
import { Contract, JsonRpcProvider, formatUnits } from "ethers";

const abi = [
  "function decimals() view returns (uint8)",
  "function latestRoundData() view returns " +
    "(uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80)",
];

async function feedContract(): Promise<{ feed: Contract; now: number }> {
  if (process.env.FEED) {
    const provider = new JsonRpcProvider(process.env.RPC_URL);
    const now = (await provider.getBlock("latest"))!.timestamp;
    return { feed: new Contract(process.env.FEED, abi, provider), now };
  }
  const { network } = await import("hardhat");
  const { ethers } = await network.create();
  const mock = await ethers.deployContract("MockPriceFeed", [2_500n * 10n ** 8n]);
  const now = (await ethers.provider.getBlock("latest"))!.timestamp;
  return { feed: new Contract(await mock.getAddress(), abi, ethers.provider), now };
}

const { feed, now } = await feedContract();
const decimals = await feed.decimals();
const [roundId, answer, , updatedAt] = await feed.latestRoundData();
const age = now - Number(updatedAt);
console.log(`round       ${roundId}`);
console.log(`price       ${formatUnits(answer, decimals)} USD`);
console.log(`decimals    ${decimals}`);
console.log(`updated     ${age} seconds before the latest block`);
const usable = answer > 0n && age <= 3600;     // same rule as LendingPool.price()
console.log(`usable      ${usable ? "yes" : "no: stale or invalid"}`);
