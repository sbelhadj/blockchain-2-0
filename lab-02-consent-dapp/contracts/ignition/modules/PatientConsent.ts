import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploys PatientConsent with the deployer as admin and registers one provider.
export default buildModule("PatientConsentModule", (m) => {
  const admin = m.getAccount(0);
  const provider = m.getParameter("provider", m.getAccount(1));
  const consent = m.contract("PatientConsent", [admin]);
  const role = m.staticCall(consent, "PROVIDER_ROLE");
  m.call(consent, "grantRole", [role, provider]);
  return { consent };
});
