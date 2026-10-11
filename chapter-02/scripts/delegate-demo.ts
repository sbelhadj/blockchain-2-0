// Listing 2.5: give an EOA contract code with EIP-7702, use it, then remove it.
// Usage: npx hardhat run scripts/delegate-demo.ts --network localhost
import { network } from "hardhat";
import { HDNodeWallet, ZeroAddress, parseEther } from "ethers";

const { ethers } = await network.getOrCreate();
const [relayer, , bob, carol] = await ethers.getSigners();
// Signing an authorization needs the private key, so alice is a local wallet.
// This is Hardhat's well-known test mnemonic: never use it outside a local network.
const MNEMONIC = "test test test test test test test test test test test junk";
const alice = HDNodeWallet.fromPhrase(MNEMONIC, undefined, "m/44'/60'/0'/0/1")
  .connect(ethers.provider);
const executor = await ethers.deployContract("BatchExecutor");
const target = await executor.getAddress();
console.log("BatchExecutor     ", target);
console.log("alice code before ", await ethers.provider.getCode(alice.address));

// 1. Alice signs an authorization; the relayer submits it in a type 4 transaction.
const auth = await alice.authorize({ address: target });
const setTx = await relayer.sendTransaction({
  type: 4,
  to: alice.address,
  authorizationList: [auth],
});
const setRcpt = await setTx.wait();
console.log("set-code tx type  ", setTx.type);
console.log("set-code gasUsed  ", setRcpt?.gasUsed.toString());
console.log("alice code after  ", await ethers.provider.getCode(alice.address));

// 2. Alice calls her own address, which now runs BatchExecutor's code.
const asContract = executor.attach(alice.address) as typeof executor;
const calls = [
  { to: bob.address, value: parseEther("0.1"), data: "0x" },
  { to: carol.address, value: parseEther("0.2"), data: "0x" },
];
const balances = async () => [
  await ethers.provider.getBalance(bob.address),
  await ethers.provider.getBalance(carol.address),
];
const before = await balances();
const batchTx = await asContract.connect(alice).execute(calls);
const batchRcpt = await batchTx.wait();
const after = await balances();
console.log("batch gasUsed     ", batchRcpt?.gasUsed.toString());
console.log("bob received      ", ethers.formatEther(after[0] - before[0]), "ETH");
console.log("carol received    ", ethers.formatEther(after[1] - before[1]), "ETH");

// 3. Delegating to the zero address clears the code again.
const clear = await alice.authorize({ address: ZeroAddress });
const clearTx = await relayer.sendTransaction({
  type: 4,
  to: alice.address,
  authorizationList: [clear],
});
await clearTx.wait();
console.log("alice code cleared", await ethers.provider.getCode(alice.address));
console.log("alice              " + alice.address);
console.log("set-code tx hash   " + setTx.hash);
console.log("batch tx hash      " + batchTx.hash);
