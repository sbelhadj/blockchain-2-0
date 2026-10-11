import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploys SupplyChainToken. The deploying account is admin and, by default,
// treasury. Override with --parameters, e.g. a multisig as treasury.
export default buildModule("SupplyChainTokenModule", (m) => {
  const admin = m.getAccount(0);
  const treasury = m.getParameter("treasury", admin);
  const adminDelay = m.getParameter("adminDelay", 86_400n);   // one day
  const token = m.contract("SupplyChainToken", [admin, treasury, adminDelay]);
  return { token };
});
