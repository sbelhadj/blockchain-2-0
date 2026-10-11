// Listing 2.4: reading "private" contract storage directly from the state.
// Usage: npx hardhat run scripts/read-storage.ts
import { network } from "hardhat";
import { AbiCoder, keccak256, toBigInt } from "ethers";

const { ethers } = await network.getOrCreate();
const [owner] = await ethers.getSigners();
const secret = await ethers.deployContract("Secret", [424242n]);
const address = await secret.getAddress();

const slot0 = await ethers.provider.getStorage(address, 0);
const slot1 = await ethers.provider.getStorage(address, 1);
console.log("slot 0 (owner)  ", slot0);
console.log("slot 1 (code)   ", slot1);
console.log("  as a number   ", toBigInt(slot1).toString());

// A mapping entry lives at keccak256(abi.encode(key, baseSlot)).
const coder = AbiCoder.defaultAbiCoder();
const key = coder.encode(["address", "uint256"], [owner.address, 2]);
const entrySlot = keccak256(key);
const entry = await ethers.provider.getStorage(address, entrySlot);
console.log("entry slot      ", entrySlot);
console.log("entry value     ", entry);
console.log("  as a number   ", toBigInt(entry).toString());
