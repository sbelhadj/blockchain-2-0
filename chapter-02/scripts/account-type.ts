// Listing 2.6: classify addresses as EOA, contract,
// or EOA with an EIP-7702 delegation.
// Usage: RPC_URL=<endpoint> npx tsx scripts/account-type.ts 0xA... 0xB... 0xC...
import { JsonRpcProvider, getAddress } from "ethers";

const url = process.env.RPC_URL ?? "http://127.0.0.1:8545";
const provider = new JsonRpcProvider(url);
const DELEGATION_PREFIX = "0xef0100"; // EIP-7702 delegation designator

for (const input of process.argv.slice(2)) {
  const address = getAddress(input);
  const code = await provider.getCode(address);
  if (code === "0x") {
    console.log(`${address}  EOA (no code)`);
  } else if (code.startsWith(DELEGATION_PREFIX) && code.length === 2 + 46) {
    const target = getAddress("0x" + code.slice(8));
    console.log(`${address}  EOA with EIP-7702 delegation`);
    console.log(`  delegated to ${target}`);
  } else {
    console.log(`${address}  contract, ${(code.length - 2) / 2} bytes of code`);
  }
}
