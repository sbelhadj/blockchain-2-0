// Query past events in block ranges small enough for free RPC tiers.
import type { Contract, ContractEventName, EventLog, Log } from "ethers";

export async function queryPaged(
  contract: Contract,
  filter: ContractEventName,
  fromBlock: number,
  toBlock: number,
  step = 5_000,
): Promise<(EventLog | Log)[]> {
  const out: (EventLog | Log)[] = [];
  let start = fromBlock;
  while (start <= toBlock) {
    const end = Math.min(start + step - 1, toBlock);
    try {
      out.push(...(await contract.queryFilter(filter, start, end)));
      start = end + 1;
    } catch (err) {
      if (step <= 1) throw err;
      step = Math.floor(step / 2);   // provider refused the range: halve and retry
    }
  }
  return out;
}
