// Exercise 7.1 solution: one UserOperation that pays two recipients with
// executeBatch, and the error a too-small verificationGasLimit produces.
// Usage: npx hardhat run scripts/solutions/userop-variants.ts
import { readFileSync } from "node:fs";
import { network } from "hardhat";
import {
  Contract,
  ContractFactory,
  Wallet,
  id,
  parseEther,
  solidityPacked,
  toBeHex,
  zeroPadValue,
} from "ethers";

const { ethers } = await network.create();
const [bundler, bob, carol] = await ethers.getSigners();
const art = (n: string) =>
  JSON.parse(
    readFileSync(
      `node_modules/@account-abstraction/contracts/artifacts/${n}.json`,
      "utf8",
    ),
  );
const deploy = async (n: string, ...args: unknown[]) => {
  const a = art(n);
  return (await new ContractFactory(a.abi, a.bytecode, bundler).deploy(
    ...args,
  )) as Contract;
};
const entryPoint = await deploy("EntryPoint");
const factory = await deploy("SimpleAccountFactory", await entryPoint.getAddress());
const account = new Contract(ethers.ZeroAddress, art("SimpleAccount").abi);
const pack = (hi: bigint, lo: bigint) =>
  zeroPadValue(toBeHex((hi << 128n) | lo), 32);

async function run(
  label: string,
  salt: number,
  callData: string,
  verifGas: bigint,
) {
  const owner = new Wallet(id(`book 3 appendix ${salt}`));
  const sender: string = await factory["getAddress(address,uint256)"](
    owner.address,
    salt,
  );
  const exists = (await ethers.provider.getCode(sender)) !== "0x";
  if (!exists) {
    await (
      await bundler.sendTransaction({ to: sender, value: parseEther("1") })
    ).wait();
  }
  const op = {
    sender,
    nonce: await entryPoint.getNonce(sender, 0),
    initCode: exists
      ? "0x"
      : solidityPacked(
          ["address", "bytes"],
          [
            await factory.getAddress(),
            factory.interface.encodeFunctionData("createAccount", [
              owner.address,
              salt,
            ]),
          ],
        ),
    callData,
    accountGasLimits: pack(verifGas, 200_000n),
    preVerificationGas: 60_000n,
    gasFees: pack(1_000_000_000n, 3_000_000_000n),
    paymasterAndData: "0x",
    signature: "0x",
  };
  op.signature = owner.signingKey.sign(
    await entryPoint.getUserOpHash(op),
  ).serialized;
  try {
    const rcpt = await (await entryPoint.handleOps([op], bundler.address)).wait();
    for (const log of rcpt.logs) {
      const p = entryPoint.interface.parseLog(log);
      if (p?.name === "UserOperationEvent") {
        console.log(
          `${label.padEnd(30)} success ${p.args.success}, ` +
            `gas used ${p.args.actualGasUsed}`,
        );
      }
    }
  } catch (err) {
    const p = entryPoint.interface.parseError((err as { data: string }).data);
    console.log(`${label.padEnd(30)} reverted ${p?.name}(${p?.args.join(", ")})`);
  }
}

const single = (to: string) =>
  account.interface.encodeFunctionData("execute", [to, parseEther("0.1"), "0x"]);
const batch = account.interface.encodeFunctionData("executeBatch", [
  [
    { target: bob.address, value: parseEther("0.1"), data: "0x" },
    { target: carol.address, value: parseEther("0.1"), data: "0x" },
  ],
]);

await run("A: deploy + pay bob", 1, single(bob.address), 500_000n);
await run("A again: pay carol", 1, single(carol.address), 500_000n);
await run("B: deploy + batch (bob, carol)", 2, batch, 500_000n);
await run("C: verificationGasLimit 50,000", 3, single(bob.address), 50_000n);
