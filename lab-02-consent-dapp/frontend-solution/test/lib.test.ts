// Checks the dApp's library code against a local Hardhat node.
// Usage: (in ../contracts) npx hardhat node, then: npm run test:lib
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Contract, ContractFactory, JsonRpcProvider, Wallet, id } from "ethers";
import { explainError } from "../src/lib/errors.ts";
import { queryPaged } from "../src/lib/events.ts";
import { txReducer, type TxState } from "../src/lib/txMachine.ts";

// cacheTimeout -1: no request caching, so nonces are always fresh between tests.
const provider =
  new JsonRpcProvider("http://127.0.0.1:8545", undefined, { cacheTimeout: -1 });
// Hardhat's well-known test keys: local use only.
const admin = new Wallet(
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80", provider);
const patient = new Wallet(
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d", provider);
const artifact = JSON.parse(readFileSync(
  "../contracts/artifacts/contracts/PatientConsent.sol/PatientConsent.json", "utf8"));

async function deploy(): Promise<Contract> {
  const factory = new ContractFactory(artifact.abi, artifact.bytecode, admin);
  const c = await factory.deploy(admin.address);
  await c.waitForDeployment();
  return c as Contract;
}

test("txReducer follows the happy path and ignores invalid moves", () => {
  let s: TxState = { status: "idle" };
  s = txReducer(s, { type: "mined", block: 1 });          // invalid: still idle
  assert.equal(s.status, "idle");
  s = txReducer(s, { type: "start", label: "Grant" });
  s = txReducer(s, { type: "start", label: "Again" });     // ignored while busy
  assert.deepEqual(s, { status: "awaiting-signature", label: "Grant" });
  s = txReducer(s, { type: "signed", hash: "0xabc" });
  s = txReducer(s, { type: "mined", block: 42 });
  assert.deepEqual(s, { status: "confirmed", label: "Grant", hash: "0xabc", block: 42 });
});

test("txReducer distinguishes rejection from revert", () => {
  const start = txReducer({ status: "idle" }, { type: "start", label: "Revoke" });
  assert.equal(txReducer(start, { type: "user-rejected" }).status, "rejected");
  const pending = txReducer(start, { type: "signed", hash: "0x1" });
  const failed = txReducer(pending, { type: "reverted", reason: "AlreadyInactive(1)" });
  assert.deepEqual(failed,
    { status: "failed", label: "Revoke", reason: "AlreadyInactive(1)", hash: "0x1" });
});

test("explainError decodes the contract's custom error", async () => {
  const consent = await deploy();
  const stranger = Wallet.createRandom().address;
  try {
    await (consent.connect(patient) as Contract)
      .grantConsent.estimateGas(stranger, id("LAB_RESULTS"), 30, id("doc"));
    assert.fail("should revert");
  } catch (err) {
    const message = explainError(err, consent.interface);
    console.log(`  decoded: ${message}`);
    assert.equal(message, `NotProvider(${stranger})`);
  }
});

test("queryPaged returns every event and survives range limits", async () => {
  const consent = await deploy();
  await (await consent.grantRole(await consent.PROVIDER_ROLE(), admin.address)).wait();
  const asPatient = consent.connect(patient) as Contract;
  const first = await provider.getBlockNumber();
  for (let i = 0; i < 12; i++) {
    await (await asPatient.grantConsent(admin.address, id(`CAT_${i}`), 30, id("doc"))).wait();
  }
  const last = await provider.getBlockNumber();
  const filter = consent.filters.ConsentGranted(null, patient.address);
  const all = await queryPaged(consent, filter, first, last, 3);
  // A provider that refuses ranges wider than 2 blocks forces the step to shrink.
  const picky = Object.create(consent) as Contract;
  picky.queryFilter = async (f, from, to) => {
    if (Number(to) - Number(from) + 1 > 2) throw new Error("range too large");
    return consent.queryFilter(f, from, to);
  };
  const halved = await queryPaged(picky, filter, first, last, 8);
  console.log(`  blocks ${first}-${last}: ${all.length} events, ${halved.length} with halving`);
  assert.equal(all.length, 12);
  assert.equal(halved.length, 12);
});
