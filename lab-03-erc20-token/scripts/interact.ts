// Part D: use the token. With TOKEN unset, deploys a fresh one on the local network.
// Sepolia: TOKEN=0x... RECIPIENT=0x... \
//   npx hardhat run scripts/interact.ts --network sepolia
import { network } from "hardhat";
import { Signature } from "ethers";

const { ethers } = await network.getOrCreate();
const [owner, second] = await ethers.getSigners();
const recipient = process.env.RECIPIENT ?? second.address;
const token = process.env.TOKEN
  ? await ethers.getContractAt("SupplyChainToken", process.env.TOKEN)
  : await ethers.deployContract("SupplyChainToken",
      [owner.address, owner.address, 86_400n]);   // admin, treasury, delay
const fmt = (x: bigint) => ethers.formatUnits(x, 18);
const hashes: string[] = [];

// 1. A plain transfer.
let tx = await token.transfer(recipient, ethers.parseUnits("250", 18));
hashes.push(`transfer        ${tx.hash}`); await tx.wait();

// 2. Approve, then transferFrom by the recipient (only possible if we hold its key).
tx = await token.approve(recipient, ethers.parseUnits("100", 18));
hashes.push(`approve         ${tx.hash}`); await tx.wait();
if (!process.env.RECIPIENT) {
  tx = await token.connect(second)
    .transferFrom(owner.address, second.address, ethers.parseUnits("40", 18));
  hashes.push(`transferFrom    ${tx.hash}`); await tx.wait();
}

// 3. A permit signed off-chain by the owner and submitted in a transaction.
const { chainId } = await ethers.provider.getNetwork();
const deadline = BigInt((await ethers.provider.getBlock("latest"))!.timestamp + 3600);
const domain = { name: "SupplyChainToken", version: "1", chainId,
  verifyingContract: await token.getAddress() };
const types = { Permit: [
  { name: "owner", type: "address" }, { name: "spender", type: "address" },
  { name: "value", type: "uint256" }, { name: "nonce", type: "uint256" },
  { name: "deadline", type: "uint256" }] };
const value = ethers.parseUnits("500", 18);
const message = { owner: owner.address, spender: recipient, value,
  nonce: await token.nonces(owner.address), deadline };
const sig = Signature.from(await owner.signTypedData(domain, types, message));
// permit SETS the allowance to 500; it does not add to what was left.
tx = await token.permit(owner.address, recipient, value, deadline,
  sig.v, sig.r, sig.s);
hashes.push(`permit          ${tx.hash}`); await tx.wait();

console.log(`token           ${await token.getAddress()}`);
console.log(`owner balance   ${fmt(await token.balanceOf(owner.address))} SCT`);
console.log(`recipient bal.  ${fmt(await token.balanceOf(recipient))} SCT`);
const allowance = await token.allowance(owner.address, recipient);
console.log(`allowance       ${fmt(allowance)} SCT`);
hashes.forEach((h) => console.log(h));
