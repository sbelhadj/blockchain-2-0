import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Registration fee in wei. Override at deploy time with --parameters.
const DEFAULT_FEE = 1_000_000_000_000_000n; // 0.001 ETH

export default buildModule("AssetRegistryModule", (m) => {
  const fee = m.getParameter("registrationFee", DEFAULT_FEE);
  const registry = m.contract("AssetRegistry", [fee]);
  return { registry };
});
