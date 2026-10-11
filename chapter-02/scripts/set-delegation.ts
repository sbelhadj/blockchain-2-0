// Helper for Exercise 2.4: delegate Hardhat test account #1
// to a fresh BatchExecutor
// and leave the delegation in place. Local networks only.
// Usage: npx hardhat run scripts/set-delegation.ts --network localhost
import { network } from "hardhat";
import { HDNodeWallet } from "ethers";

const { ethers } = await network.getOrCreate();
const [relayer] = await ethers.getSigners();
const MNEMONIC = "test test test test test test test test test test test junk";
const alice = HDNodeWallet.fromPhrase(MNEMONIC, undefined, "m/44'/60'/0'/0/1")
  .connect(ethers.provider);
const executor = await ethers.deployContract("BatchExecutor");
const auth = await alice.authorize({ address: await executor.getAddress() });
const tx = await relayer.sendTransaction({
  type: 4,
  to: alice.address,
  authorizationList: [auth],
});
await tx.wait();
console.log(`relayer  ${relayer.address}`);
console.log(`executor ${await executor.getAddress()}`);
console.log(`alice    ${alice.address} (now delegated)`);
