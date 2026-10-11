// ERC-2612 permit: Alice signs an approval off-chain; anyone can submit it.
// Usage: npx hardhat run scripts/permit-flow.ts
import { network } from "hardhat";
import { Signature } from "ethers";

const { ethers } = await network.create();
const [alice, relayer, pool] = await ethers.getSigners();
const usd = await ethers.deployContract("TestToken", ["Test USD", "tUSD", 6]);
await usd.mint(alice.address, 1_000_000_000n);

const { chainId } = await ethers.provider.getNetwork();
const deadline = BigInt((await ethers.provider.getBlock("latest"))!.timestamp + 3600);
const domain = { name: "Test USD", version: "1", chainId,
  verifyingContract: await usd.getAddress() };
const types = { Permit: [
  { name: "owner", type: "address" }, { name: "spender", type: "address" },
  { name: "value", type: "uint256" }, { name: "nonce", type: "uint256" },
  { name: "deadline", type: "uint256" }] };
const value = { owner: alice.address, spender: pool.address, value: 250_000_000n,
  nonce: await usd.nonces(alice.address), deadline };

// Signing costs no gas and sends nothing to the chain.
const sig = Signature.from(await alice.signTypedData(domain, types, value));
const tx = await usd.connect(relayer).permit(alice.address, pool.address,
  250_000_000n, deadline, sig.v, sig.r, sig.s);
const receipt = await tx.wait();
console.log(`permit submitted by relayer, gas ${receipt!.gasUsed}`);
console.log(`allowance now ${ethers.formatUnits(
  await usd.allowance(alice.address, pool.address), 6)} tUSD`);
console.log(`alice's permit nonce ${await usd.nonces(alice.address)}`);
try {          // the same signature cannot be used twice: the nonce has moved on
  await usd.connect(relayer).permit(alice.address, pool.address,
    250_000_000n, deadline, sig.v, sig.r, sig.s);
} catch (err) {
  const reason = usd.interface.parseError((err as { data: string }).data);
  console.log(`replaying the same signature: ${reason?.name}`);
}
