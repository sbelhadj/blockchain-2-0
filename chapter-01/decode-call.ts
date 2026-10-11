// Listing 1.2: what an Ethereum contract call carries in its data field.
// Runs offline: it encodes an ERC-20 transfer call, then decodes it back.
import { Interface, parseUnits } from "ethers";

const erc20 = new Interface([
  "function transfer(address to, uint256 amount) returns (bool)",
]);

const to = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
const amount = parseUnits("250", 6); // 250 units of a token with 6 decimals

const data = erc20.encodeFunctionData("transfer", [to, amount]);
console.log("length    ", (data.length - 2) / 2, "bytes");
console.log("selector  ", data.slice(0, 10));
// The rest of the data is two 32-byte words, one per argument.
console.log("word 1    ", data.slice(10, 74));
console.log("word 2    ", data.slice(74, 138));

const decoded = erc20.parseTransaction({ data });
console.log("function  ", decoded?.signature);
console.log("to        ", decoded?.args[0]);
console.log("amount    ", decoded?.args[1].toString());
