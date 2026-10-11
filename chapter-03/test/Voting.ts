import { expect } from "chai";
import { network } from "hardhat";

const { ethers, networkHelpers } = await network.create();

async function election() {
  const [owner, alice, bob, carol] = await ethers.getSigners();
  const voting = await ethers.deployContract("Voting", [owner.address]);
  await voting.addCandidate("Port of Rades");
  await voting.addCandidate("Port of Sfax");
  await voting.registerVoter(alice.address);
  await voting.registerVoter(bob.address);
  return { voting, owner, alice, bob, carol };
}

describe("Voting (Exercise 3.2 solution)", function () {
  it("counts votes and names the winner after closing", async function () {
    const { voting, alice, bob } = await networkHelpers.loadFixture(election);
    await expect(voting.connect(alice).vote(1))
      .to.emit(voting, "VoteCast")
      .withArgs(alice.address, 1);
    await voting.connect(bob).vote(1);
    await voting.close();
    const [index, name] = await voting.winner();
    expect(index).to.equal(1n);
    expect(name).to.equal("Port of Sfax");
    expect((await voting.candidate(1))[1]).to.equal(2n);
  });

  it("rejects unregistered, repeat and unknown-candidate votes", async function () {
    const { voting, alice, carol } = await networkHelpers.loadFixture(election);
    await expect(voting.connect(carol).vote(0))
      .to.be.revertedWithCustomError(voting, "NotRegistered")
      .withArgs(carol.address);
    await voting.connect(alice).vote(0);
    await expect(voting.connect(alice).vote(0)).to.be.revertedWithCustomError(
      voting,
      "AlreadyVoted",
    );
    await expect(voting.connect(carol).vote(0)).to.be.revertedWithCustomError(
      voting,
      "NotRegistered",
    );
    const { voting: v2, bob } = await networkHelpers.loadFixture(election);
    await expect(v2.connect(bob).vote(7))
      .to.be.revertedWithCustomError(v2, "UnknownCandidate")
      .withArgs(7);
  });

  it("blocks every change after closing", async function () {
    const { voting, owner, alice, carol } =
      await networkHelpers.loadFixture(election);
    await voting.close();
    await expect(voting.connect(alice).vote(0)).to.be.revertedWithCustomError(
      voting,
      "ElectionClosed",
    );
    await expect(voting.addCandidate("Late")).to.be.revertedWithCustomError(
      voting,
      "ElectionClosed",
    );
    await expect(voting.registerVoter(carol.address)).to.be.revertedWithCustomError(
      voting,
      "ElectionClosed",
    );
    await expect(voting.close()).to.be.revertedWithCustomError(
      voting,
      "ElectionClosed",
    );
    expect(await voting.owner()).to.equal(owner.address);
  });

  it("refuses the winner while open, and without candidates", async function () {
    const { voting } = await networkHelpers.loadFixture(election);
    await expect(voting.winner()).to.be.revertedWithCustomError(
      voting,
      "ElectionOpen",
    );
    const [owner] = await ethers.getSigners();
    const empty = await ethers.deployContract("Voting", [owner.address]);
    await empty.close();
    await expect(empty.winner()).to.be.revertedWithCustomError(
      empty,
      "NoCandidates",
    );
    await expect(voting.candidate(9)).to.be.revertedWithCustomError(
      voting,
      "UnknownCandidate",
    );
    expect(await voting.candidateCount()).to.equal(2n);
  });

  it("restricts administration to the owner", async function () {
    const { voting, alice } = await networkHelpers.loadFixture(election);
    for (const call of [
      () => voting.connect(alice).addCandidate("X"),
      () => voting.connect(alice).registerVoter(alice.address),
      () => voting.connect(alice).close(),
    ]) {
      await expect(call()).to.be.revertedWithCustomError(
        voting,
        "OwnableUnauthorizedAccount",
      );
    }
  });
});

describe("SecureVault, empty withdrawal", function () {
  it("reverts NoBalance when withdrawing nothing", async function () {
    const vault = await ethers.deployContract("SecureVault");
    await expect(vault.withdraw()).to.be.revertedWithCustomError(
      vault,
      "NoBalance",
    );
  });
});
