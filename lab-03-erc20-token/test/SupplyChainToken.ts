import { expect } from "chai";
import { network } from "hardhat";
import { Signature, id } from "ethers";

const { ethers, networkHelpers } = await network.create();
const E18 = 10n ** 18n;
const DAY = 24n * 3600n;
const Reward = { OnTimeDelivery: 0, QualityCheck: 1, Sustainability: 2 };
const shipment = (n: number) => id(`SHP-${n}`);   // event ids chosen off-chain

async function deploy() {
  const [admin, treasury, carrier, shipper, relayer, stranger, rewarder] =
    await ethers.getSigners();
  const sct = await ethers.deployContract("SupplyChainToken",
    [admin.address, treasury.address, DAY]);
  await sct.setCarrier(carrier.address, true);
  return { sct, admin, treasury, carrier, shipper, relayer, stranger, rewarder };
}

async function signPermit(token: any, owner: any, spender: string, value: bigint,
  deadline: bigint) {
  const { chainId } = await ethers.provider.getNetwork();
  const domain = { name: "SupplyChainToken", version: "1", chainId,
    verifyingContract: await token.getAddress() };
  const types = { Permit: [
    { name: "owner", type: "address" }, { name: "spender", type: "address" },
    { name: "value", type: "uint256" }, { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" }] };
  const message = { owner: owner.address, spender, value,
    nonce: await token.nonces(owner.address), deadline };
  return Signature.from(await owner.signTypedData(domain, types, message));
}

describe("SupplyChainToken", function () {
  describe("deployment", function () {
    it("mints 10 million SCT to the treasury, cap 100 million", async function () {
      const { sct, treasury } = await networkHelpers.loadFixture(deploy);
      expect(await sct.symbol()).to.equal("SCT");
      expect(await sct.balanceOf(treasury.address)).to.equal(10_000_000n * E18);
      expect(await sct.cap()).to.equal(100_000_000n * E18);
      expect(await sct.rewardAmount(Reward.Sustainability)).to.equal(200n * E18);
      expect(await sct.defaultAdminDelay()).to.equal(DAY);
    });

    it("rejects a zero treasury and a zero carrier", async function () {
      const { sct, admin } = await networkHelpers.loadFixture(deploy);
      await expect(ethers.deployContract("SupplyChainToken",
        [admin.address, ethers.ZeroAddress, DAY]))
        .to.be.revertedWithCustomError(sct, "ZeroAddress");
      await expect(sct.setCarrier(ethers.ZeroAddress, true))
        .to.be.revertedWithCustomError(sct, "ZeroAddress");
    });
  });

  describe("rewards", function () {
    it("rewards a verified carrier once per event", async function () {
      const { sct, carrier } = await networkHelpers.loadFixture(deploy);
      await expect(sct.reward(carrier.address, Reward.OnTimeDelivery, shipment(1)))
        .to.emit(sct, "RewardIssued")
        .withArgs(carrier.address, Reward.OnTimeDelivery, shipment(1), 100n * E18);
      await sct.reward(carrier.address, Reward.Sustainability, shipment(2));
      expect(await sct.balanceOf(carrier.address)).to.equal(300n * E18);
      expect(await sct.deliveryCount(carrier.address)).to.equal(1n);
      await expect(sct.reward(carrier.address, Reward.OnTimeDelivery, shipment(1)))
        .to.be.revertedWithCustomError(sct, "AlreadyRewarded")
        .withArgs(shipment(1));
    });

    it("refuses unverified and unverified-again carriers", async function () {
      const { sct, carrier, stranger, admin } =
        await networkHelpers.loadFixture(deploy);
      await expect(sct.reward(stranger.address, Reward.QualityCheck, shipment(3)))
        .to.be.revertedWithCustomError(sct, "CarrierNotVerified")
        .withArgs(stranger.address);
      await expect(sct.setCarrier(carrier.address, false))
        .to.emit(sct, "CarrierStatusChanged")
        .withArgs(carrier.address, false, admin.address);
      await expect(sct.reward(carrier.address, Reward.QualityCheck, shipment(4)))
        .to.be.revertedWithCustomError(sct, "CarrierNotVerified");
    });

    it("lets the admin change a reward within MAX_REWARD", async function () {
      const { sct } = await networkHelpers.loadFixture(deploy);
      await expect(sct.setRewardAmount(Reward.QualityCheck, 75n * E18))
        .to.emit(sct, "RewardAmountUpdated")
        .withArgs(Reward.QualityCheck, 50n * E18, 75n * E18);
      await expect(sct.setRewardAmount(Reward.QualityCheck, 10_001n * E18))
        .to.be.revertedWithCustomError(sct, "RewardTooLarge");
    });
  });

  describe("access control", function () {
    it("rejects privileged calls from accounts without the role", async function () {
      const { sct, carrier, stranger } = await networkHelpers.loadFixture(deploy);
      const s = sct.connect(stranger);
      const calls = [
        () => s.reward(carrier.address, Reward.QualityCheck, shipment(5)),
        () => s.setCarrier(stranger.address, true),
        () => s.setRewardAmount(Reward.QualityCheck, 1n),
        () => s.mint(stranger.address, 1n),
        () => s.pause(),
        () => s.unpause(),
      ];
      for (const call of calls) {
        await expect(call())
          .to.be.revertedWithCustomError(sct, "AccessControlUnauthorizedAccount");
      }
    });

    it("lets a dedicated rewarder reward but not mint or pause", async function () {
      const { sct, carrier, rewarder } = await networkHelpers.loadFixture(deploy);
      await sct.grantRole(await sct.REWARDER_ROLE(), rewarder.address);
      await sct.connect(rewarder)
        .reward(carrier.address, Reward.QualityCheck, shipment(6));
      expect(await sct.balanceOf(carrier.address)).to.equal(50n * E18);
      await expect(sct.connect(rewarder).mint(rewarder.address, 1n))
        .to.be.revertedWithCustomError(sct, "AccessControlUnauthorizedAccount");
      await expect(sct.connect(rewarder).pause())
        .to.be.revertedWithCustomError(sct, "AccessControlUnauthorizedAccount");
    });

    it("hands over the admin role only after the delay", async function () {
      const { sct, admin, stranger } = await networkHelpers.loadFixture(deploy);
      await sct.beginDefaultAdminTransfer(stranger.address);
      await expect(sct.connect(stranger).acceptDefaultAdminTransfer())
        .to.be.revertedWithCustomError(sct, "AccessControlEnforcedDefaultAdminDelay");
      await networkHelpers.time.increase(DAY + 1n);
      await sct.connect(stranger).acceptDefaultAdminTransfer();
      expect(await sct.defaultAdmin()).to.equal(stranger.address);
      expect(await sct.hasRole(await sct.DEFAULT_ADMIN_ROLE(), admin.address))
        .to.equal(false);
    });
  });

  describe("supply and transfers", function () {
    it("enforces the cap on treasury mints", async function () {
      const { sct, treasury, admin } = await networkHelpers.loadFixture(deploy);
      await expect(sct.mint(treasury.address, 90_000_000n * E18))
        .to.emit(sct, "TreasuryMinted")
        .withArgs(treasury.address, 90_000_000n * E18, admin.address);
      await expect(sct.mint(treasury.address, 1n))
        .to.be.revertedWithCustomError(sct, "ERC20ExceededCap");
    });

    it("supports approve, transferFrom and burning", async function () {
      const { sct, treasury, shipper } = await networkHelpers.loadFixture(deploy);
      await sct.connect(treasury).approve(shipper.address, 500n * E18);
      await sct.connect(shipper)
        .transferFrom(treasury.address, shipper.address, 200n * E18);
      expect(await sct.allowance(treasury.address, shipper.address))
        .to.equal(300n * E18);
      await sct.connect(shipper).burn(50n * E18);
      expect(await sct.balanceOf(shipper.address)).to.equal(150n * E18);
    });

    it("blocks transfers and rewards while paused", async function () {
      const { sct, treasury, shipper, carrier } =
        await networkHelpers.loadFixture(deploy);
      await sct.pause();
      await expect(sct.connect(treasury).transfer(shipper.address, 1n))
        .to.be.revertedWithCustomError(sct, "EnforcedPause");
      await expect(sct.reward(carrier.address, Reward.QualityCheck, shipment(7)))
        .to.be.revertedWithCustomError(sct, "EnforcedPause");
      await sct.unpause();
      await sct.connect(treasury).transfer(shipper.address, 1n);
      expect(await sct.balanceOf(shipper.address)).to.equal(1n);
    });
  });

  describe("permit", function () {
    it("accepts a valid permit once, submitted by a relayer", async function () {
      const { sct, treasury, shipper, relayer } =
        await networkHelpers.loadFixture(deploy);
      const deadline = BigInt(await networkHelpers.time.latest()) + 3600n;
      const sig =
        await signPermit(sct, treasury, shipper.address, 1_000n * E18, deadline);
      await sct.connect(relayer).permit(treasury.address, shipper.address,
        1_000n * E18, deadline, sig.v, sig.r, sig.s);
      expect(await sct.allowance(treasury.address, shipper.address))
        .to.equal(1_000n * E18);
      await expect(sct.connect(relayer).permit(treasury.address, shipper.address,
        1_000n * E18, deadline, sig.v, sig.r, sig.s))
        .to.be.revertedWithCustomError(sct, "ERC2612InvalidSigner");
    });

    it("rejects an expired permit", async function () {
      const { sct, treasury, shipper, relayer } =
        await networkHelpers.loadFixture(deploy);
      const deadline = BigInt(await networkHelpers.time.latest()) + 60n;
      const sig = await signPermit(sct, treasury, shipper.address, 1n, deadline);
      await networkHelpers.time.increase(120);
      await expect(sct.connect(relayer).permit(treasury.address, shipper.address, 1n,
        deadline, sig.v, sig.r, sig.s))
        .to.be.revertedWithCustomError(sct, "ERC2612ExpiredSignature");
    });
  });
});
