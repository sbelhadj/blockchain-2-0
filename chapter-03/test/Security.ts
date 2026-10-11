import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.create();
const ONE = ethers.parseEther("1");

describe("Reentrancy", function () {
  async function fund(vaultName: string) {
    const [, alice, bob, mallory] = await ethers.getSigners();
    const vault = await ethers.deployContract(vaultName);
    await vault.connect(alice).deposit({ value: ONE * 5n });   // honest deposits
    await vault.connect(bob).deposit({ value: ONE * 5n });
    const vaultAddress = await vault.getAddress();
    const attacker =
      await ethers.deployContract("Attacker", [vaultAddress], mallory);
    return { vault, attacker, mallory };
  }

  it("drains VulnerableVault with a 1 ETH deposit", async function () {
    const { vault, attacker, mallory } = await fund("VulnerableVault");
    await attacker.connect(mallory).attack({ value: ONE });
    const left = await ethers.provider.getBalance(await vault.getAddress());
    const stolen = await ethers.provider.getBalance(await attacker.getAddress());
    console.log(`      vault left:     ${ethers.formatEther(left)} ETH`);
    console.log(`      attacker holds: ${ethers.formatEther(stolen)} ETH`);
    console.log(`      re-entries:     ${await attacker.reentries()}`);
    expect(left).to.equal(0n);
  });

  it("blocks the same attack on SecureVault", async function () {
    const { vault, attacker, mallory } = await fund("SecureVault");
    await expect(attacker.connect(mallory).attack({ value: ONE }))
      .to.be.revertedWithCustomError(vault, "TransferFailed");
    const kept = await ethers.provider.getBalance(await vault.getAddress());
    expect(kept).to.equal(ONE * 10n);
  });
});

describe("Access control", function () {
  it("lets anyone mint on OpenMintToken", async function () {
    const [, mallory] = await ethers.getSigners();
    const token = await ethers.deployContract("OpenMintToken");
    await token.connect(mallory).mint(mallory.address, 1_000_000n);
    expect(await token.balances(mallory.address)).to.equal(1_000_000n);
  });

  it("requires MINTER_ROLE on RoleMintToken", async function () {
    const [admin, minter, mallory] = await ethers.getSigners();
    const token = await ethers.deployContract("RoleMintToken", [admin.address]);
    await expect(token.connect(mallory).mint(mallory.address, 1n))
      .to.be.revertedWithCustomError(token, "AccessControlUnauthorizedAccount")
      .withArgs(mallory.address, await token.MINTER_ROLE());
    await token.grantRole(await token.MINTER_ROLE(), minter.address);
    await token.connect(minter).mint(minter.address, 5n);
    expect(await token.balances(minter.address)).to.equal(5n);
  });
});

describe("tx.origin", function () {
  it("lets a phishing contract empty TxOriginWallet", async function () {
    const [owner, thief] = await ethers.getSigners();
    const wallet = await ethers.deployContract("TxOriginWallet", [], {
      value: ONE * 3n,
    });
    const walletAddress = await wallet.getAddress();
    const phisher = await ethers.deployContract("Phisher", [walletAddress], thief);
    // The owner believes they are claiming a reward:
    await expect(phisher.connect(owner).claimReward())
      .to.changeEtherBalances(ethers, [wallet, thief], [-ONE * 3n, ONE * 3n]);
  });
});

describe("Push versus pull payments", function () {
  it("one rejecting recipient blocks every push payout", async function () {
    const [, a, b] = await ethers.getSigners();
    const push = await ethers.deployContract("PushPayout");
    const bad = await ethers.deployContract("RejectingRecipient");
    const list = [a.address, await bad.getAddress(), b.address];
    await expect(push.payAll(list, ONE, { value: ONE * 3n }))
      .to.be.revertedWith("Payout failed");
  });

  it("pull payouts let honest recipients withdraw", async function () {
    const [, a, b] = await ethers.getSigners();
    const pull = await ethers.deployContract("PullPayout");
    const bad = await ethers.deployContract("RejectingRecipient");
    const list = [a.address, await bad.getAddress(), b.address];
    await pull.allocate(list, ONE, { value: ONE * 3n });
    await expect(pull.connect(a).withdraw()).to.changeEtherBalance(ethers, a, ONE);
    await expect(pull.connect(b).withdraw()).to.changeEtherBalance(ethers, b, ONE);
    await expect(pull.connect(a).withdraw())
      .to.be.revertedWithCustomError(pull, "NothingOwed");
  });
});
