// Lab 2, Part E: the end-to-end consent scenario, run from a script.
// Local:   npx hardhat run scripts/scenario.ts
// Sepolia: CONSENT=0x... npx hardhat run scripts/scenario.ts --network sepolia
//          (the deployer must hold the admin role; PATIENT and PROVIDER keys needed)
import { network } from "hardhat";
import { id } from "ethers";

const { ethers } = await network.getOrCreate();
const [admin, patient, provider] = await ethers.getSigners();
const consent = process.env.CONSENT
  ? await ethers.getContractAt("PatientConsent", process.env.CONSENT)
  : await ethers.deployContract("PatientConsent", [admin.address]);
const LAB = id("LAB_RESULTS");                       // published category code
const PURPOSE = id("referral-letter-2026-10.pdf");   // stands in for a document hash
const READ = id("READ");

const step = async (label: string, p: Promise<{ hash: string;
  wait: () => Promise<unknown> }>) => {
  const tx = await p; await tx.wait();
  console.log(`${label.padEnd(30)} ${tx.hash}`);
};
const check = async () => console.log(`${"  hasActiveConsent".padEnd(30)} ` +
  `${await consent.hasActiveConsent(patient.address, provider.address, LAB)}`);

await step("0. admin registers provider", consent.grantRole(
  await consent.PROVIDER_ROLE(), provider.address));
await step("1. patient grants 30 days",
  consent.connect(patient).grantConsent(provider.address, LAB, 30, PURPOSE));
await check();
await step("2. provider records access",
  consent.connect(provider).recordAccess(patient.address, LAB, READ));
await step("3. patient revokes",
  consent.connect(patient).revokeConsent(await consent.consentCount()));
await check();
try {
  await consent.connect(provider).recordAccess(patient.address, LAB, READ);
} catch (err) {
  const reason = consent.interface.parseError((err as { data: string }).data);
  console.log(`${"4. provider tries again".padEnd(30)} refused: ${reason?.name}`);
}
const accessFilter = consent.filters.DataAccessed(patient.address);
const events = await consent.queryFilter(accessFilter);
console.log(`${"DataAccessed events".padEnd(30)} ${events.length}`);
