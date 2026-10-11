import { expect } from "chai";
import { network } from "hardhat";
import { id as keccakText } from "ethers";

const { ethers, networkHelpers } = await network.create();
const LAB = keccakText("LAB_RESULTS");          // category codes from a published list
const IMAGING = keccakText("IMAGING");
const PURPOSE = keccakText("second-opinion-2026-10.pdf"); // stands in for a document hash
const DAY = 24n * 60n * 60n;

async function deploy() {
  const [admin, patient, provider, other, stranger] = await ethers.getSigners();
  const consent = await ethers.deployContract("PatientConsent", [admin.address]);
  const role = await consent.PROVIDER_ROLE();
  await consent.grantRole(role, provider.address);
  await consent.grantRole(role, other.address);
  return { consent, admin, patient, provider, other, stranger };
}

describe("PatientConsent", function () {
  it("grants consent and emits the event", async function () {
    const { consent, patient, provider } = await networkHelpers.loadFixture(deploy);
    await expect(consent.connect(patient).grantConsent(provider.address, LAB, 30, PURPOSE))
      .to.emit(consent, "ConsentGranted");
    expect(await consent.hasActiveConsent(patient.address, provider.address, LAB)).to.equal(true);
    expect(await consent.hasActiveConsent(patient.address, provider.address, IMAGING))
      .to.equal(false);
  });

  it("refuses unregistered providers, self-consent and bad durations", async function () {
    const { consent, patient, provider, stranger } = await networkHelpers.loadFixture(deploy);
    await expect(consent.connect(patient).grantConsent(stranger.address, LAB, 30, PURPOSE))
      .to.be.revertedWithCustomError(consent, "NotProvider").withArgs(stranger.address);
    await expect(consent.connect(provider).grantConsent(provider.address, LAB, 30, PURPOSE))
      .to.be.revertedWithCustomError(consent, "SelfConsent");
    await expect(consent.connect(patient).grantConsent(provider.address, LAB, 0, PURPOSE))
      .to.be.revertedWithCustomError(consent, "InvalidDuration").withArgs(0);
    await expect(consent.connect(patient).grantConsent(provider.address, LAB, 366, PURPOSE))
      .to.be.revertedWithCustomError(consent, "InvalidDuration").withArgs(366);
  });

  it("expires after the chosen number of days", async function () {
    const { consent, patient, provider } = await networkHelpers.loadFixture(deploy);
    await consent.connect(patient).grantConsent(provider.address, LAB, 7, PURPOSE);
    await networkHelpers.time.increase(7n * DAY + 1n);
    expect(await consent.hasActiveConsent(patient.address, provider.address, LAB)).to.equal(false);
  });

  it("lets only the patient revoke, once", async function () {
    const { consent, patient, provider, stranger } = await networkHelpers.loadFixture(deploy);
    await consent.connect(patient).grantConsent(provider.address, LAB, 30, PURPOSE);
    await expect(consent.connect(stranger).revokeConsent(1))
      .to.be.revertedWithCustomError(consent, "NotYourConsent").withArgs(1);
    await expect(consent.connect(patient).revokeConsent(1))
      .to.emit(consent, "ConsentRevoked").withArgs(1, patient.address, provider.address);
    await expect(consent.connect(patient).revokeConsent(1))
      .to.be.revertedWithCustomError(consent, "AlreadyInactive");
    expect(await consent.hasActiveConsent(patient.address, provider.address, LAB)).to.equal(false);
  });

  it("replaces an earlier consent and records the replacement as a revocation", async function () {
    const { consent, patient, provider } = await networkHelpers.loadFixture(deploy);
    await consent.connect(patient).grantConsent(provider.address, LAB, 30, PURPOSE);
    await expect(consent.connect(patient).grantConsent(provider.address, LAB, 90, PURPOSE))
      .to.emit(consent, "ConsentRevoked").withArgs(1, patient.address, provider.address);
    expect(await consent.activeConsentId(patient.address, provider.address, LAB)).to.equal(2);
    expect((await consent.consents(1)).active).to.equal(false);
  });

  it("allows recordAccess only with active consent", async function () {
    const { consent, patient, provider, other } = await networkHelpers.loadFixture(deploy);
    const READ = keccakText("READ");
    await consent.connect(patient).grantConsent(provider.address, LAB, 30, PURPOSE);
    await expect(consent.connect(provider).recordAccess(patient.address, LAB, READ))
      .to.emit(consent, "DataAccessed")
      .withArgs(patient.address, provider.address, LAB, READ);
    await expect(consent.connect(other).recordAccess(patient.address, LAB, READ))
      .to.be.revertedWithCustomError(consent, "NoActiveConsent");
    await expect(consent.connect(patient).recordAccess(patient.address, LAB, READ))
      .to.be.revertedWithCustomError(consent, "AccessControlUnauthorizedAccount");
  });
});

describe("PatientConsentDraft (earlier version)", function () {
  it("reports consent for a pair that never granted any", async function () {
    const [admin, patient, provider, otherPatient, otherProvider] =
      await ethers.getSigners();
    const draft = await ethers.deployContract("PatientConsentDraft", [], admin);
    // Consent id 0 is a real consent between patient and provider...
    await draft.connect(patient)
      .grantConsent(provider.address, "LAB_RESULTS", 30, "care");
    // ...and an unknown triple also maps to id 0, so the check finds that consent.
    const leaked = await draft.hasActiveConsent(
      otherPatient.address, otherProvider.address, "PSYCHIATRY");
    console.log(`      draft hasActiveConsent for a stranger pair: ${leaked}`);
    expect(leaked).to.equal(true);
  });
});
