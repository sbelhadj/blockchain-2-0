// Copies the compiled ABI into the frontend after every contract change.
// Usage: npx hardhat compile && npx tsx scripts/export-abi.ts
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";

const artifact = JSON.parse(readFileSync(
  "artifacts/contracts/PatientConsent.sol/PatientConsent.json", "utf8"));
mkdirSync("../frontend/src/abi", { recursive: true });
writeFileSync("../frontend/src/abi/PatientConsent.json",
  JSON.stringify(artifact.abi, null, 2) + "\n");
console.log(`exported ${artifact.abi.length} ABI entries`);
