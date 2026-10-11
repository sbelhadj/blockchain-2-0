// ERC-4337 end to end on a local network: a smart account that does not exist yet
// pays 0.1 ETH. The owner only signs; a bundler submits and pays the gas up front.
// Usage: npx hardhat run scripts/userop-demo.ts
import { readFileSync } from "node:fs";
import { network } from "hardhat";
import { ContractFactory, Contract, Wallet, parseEther, solidityPacked, toBeHex,
  zeroPadValue, formatEther, id } from "ethers";

const { ethers } = await network.create();
const [bundler, bob] = await ethers.getSigners();
const artifact = (name: string) => JSON.parse(readFileSync(
  `node_modules/@account-abstraction/contracts/artifacts/${name}.json`, "utf8"));

// 1. Infrastructure: the EntryPoint (v0.8) and a factory for SimpleAccount.
const ep = artifact("EntryPoint");
const entryPoint =
  await new ContractFactory(ep.abi, ep.bytecode, bundler).deploy() as Contract;
const fa = artifact("SimpleAccountFactory");
const factory = await new ContractFactory(fa.abi, fa.bytecode, bundler)
  .deploy(await entryPoint.getAddress()) as Contract;

// 2. The owner is a key with no ETH. Its account address is known before deployment.
// A fixed test key, so the account address is the same on every run.
const owner = new Wallet(id("book 3, chapter 7, demo owner"));
const sender: string = await factory["getAddress(address,uint256)"](owner.address, 0);
console.log("smart account      ", sender);
console.log("code before        ", await ethers.provider.getCode(sender));
await (await bundler.sendTransaction({ to: sender, value: parseEther("1") })).wait();

// 3. Build the UserOperation: deploy the account and pay bob in one go.
const account = new Contract(sender, artifact("SimpleAccount").abi);
const pack = (hi: bigint, lo: bigint) => zeroPadValue(toBeHex((hi << 128n) | lo), 32);
const userOp = {
  sender,
  nonce: await entryPoint.getNonce(sender, 0),
  initCode: solidityPacked(["address", "bytes"], [await factory.getAddress(),
    factory.interface.encodeFunctionData("createAccount", [owner.address, 0])]),
  callData: account.interface.encodeFunctionData("execute",
    [bob.address, parseEther("0.1"), "0x"]),
  accountGasLimits: pack(500_000n, 100_000n),      // verification | call gas limit
  preVerificationGas: 60_000n,
  gasFees: pack(1_000_000_000n, 3_000_000_000n),   // max priority fee | max fee
  paymasterAndData: "0x",
  signature: "0x",
};
const userOpHash: string = await entryPoint.getUserOpHash(userOp); // EIP-712 hash
// Set WRONG_SIGNER=1 to sign with another key and watch validation fail.
const signer = process.env.WRONG_SIGNER ? Wallet.createRandom() : owner;
userOp.signature = signer.signingKey.sign(userOpHash).serialized; // just a signature

// 4. The bundler submits it and is repaid by the account from its ETH.
const bobBefore = await ethers.provider.getBalance(bob.address);
let rcpt;
try {
  rcpt = await (await entryPoint.handleOps([userOp], bundler.address)).wait();
} catch (err) {
  const data = (err as { data?: string }).data;
  const parsed = data ? entryPoint.interface.parseError(data) : null;
  const reason = parsed ? `${parsed.name}(${parsed.args.join(", ")})` : err;
  console.log("handleOps reverted ", reason);
  process.exit(0);
}
for (const log of rcpt.logs) {
  const parsed = entryPoint.interface.parseLog(log);
  if (parsed?.name === "AccountDeployed") {
    console.log("AccountDeployed    ", parsed.args.sender);
  }
  if (parsed?.name === "UserOperationEvent") {
    console.log("UserOperationEvent  success:", parsed.args.success,
      " gas cost:", formatEther(parsed.args.actualGasCost), "ETH");
  }
}
const codeAfter = await ethers.provider.getCode(sender);
console.log("code after         ", (codeAfter.length - 2) / 2, "bytes (a proxy)");
console.log("bob received       ",
  formatEther((await ethers.provider.getBalance(bob.address)) - bobBefore), "ETH");
const ownerEth = await ethers.provider.getBalance(owner.address);
console.log("owner's ETH        ", formatEther(ownerEth));
