// Lab 2, Part B: the two additional tests (reference solution, Appendix B).
import { expect } from "chai";
import { network } from "hardhat";
import { id } from "ethers";

const { ethers, networkHelpers } = await network.create();
const LAB = id("LAB_RESULTS");
const PURPOSE = id("referral.pdf");

async function deploy() {
  const [admin, patient, provider] = await ethers.getSigners();
  const consent = await ethers.deployContract("PatientConsent", [admin.address]);
  await consent.grantRole(await consent.PROVIDER_ROLE(), provider.address);
  return { consent, admin, patient, provider };
}

describe("PatientConsent, Lab 2 additions", function () {
  it("a 1-day consent is inactive after 1 day and 1 second", async function () {
    const { consent, patient, provider } = await networkHelpers.loadFixture(deploy);
    await consent.connect(patient).grantConsent(provider.address, LAB, 1, PURPOSE);
    await networkHelpers.time.increase(24 * 3600 - 1);
    expect(await consent.hasActiveConsent(patient.address, provider.address, LAB))
      .to.equal(true);
    await networkHelpers.time.increase(2);
    expect(await consent.hasActiveConsent(patient.address, provider.address, LAB))
      .to.equal(false);
  });

  it("a provider whose role is revoked cannot record access", async function () {
    const { consent, patient, provider } = await networkHelpers.loadFixture(deploy);
    await consent.connect(patient).grantConsent(provider.address, LAB, 30, PURPOSE);
    await consent.revokeRole(await consent.PROVIDER_ROLE(), provider.address);
    const asProvider = consent.connect(provider);
    const attempt = asProvider.recordAccess(patient.address, LAB, id("READ"));
    await expect(attempt)
      .to.be.revertedWithCustomError(consent, "AccessControlUnauthorizedAccount");
  });
});
