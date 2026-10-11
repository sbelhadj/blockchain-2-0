import { expect } from "chai";
import { network } from "hardhat";

const { ethers, networkHelpers } = await network.create();
const PRICE = ethers.parseEther("1");
const WINDOW = 7n * 24n * 3600n; // seven days for the agent to decide
const State = {
  AwaitingPayment: 0n, AwaitingDelivery: 1n, Complete: 2n, Refunded: 3n,
};

async function deployEscrow() {
  const [buyer, seller, agent, stranger] = await ethers.getSigners();
  const escrow = await ethers.deployContract("Escrow", [
    buyer.address, seller.address, agent.address, PRICE, WINDOW,
  ]);
  return { escrow, buyer, seller, agent, stranger };
}

describe("Escrow", function () {
  it("moves through the happy path; the seller withdraws", async function () {
    const { escrow, seller, agent } =
      await networkHelpers.loadFixture(deployEscrow);
    await expect(escrow.pay({ value: PRICE })).to.emit(escrow, "Paid");
    expect(await escrow.state()).to.equal(State.AwaitingDelivery);
    await expect(escrow.connect(agent).confirmDelivery())
      .to.emit(escrow, "Released").withArgs(seller.address, PRICE);
    expect(await escrow.state()).to.equal(State.Complete);
    await expect(escrow.connect(seller).withdraw())
      .to.changeEtherBalances(ethers, [escrow, seller], [-PRICE, PRICE]);
  });

  it("rejects the wrong amount", async function () {
    const { escrow } = await networkHelpers.loadFixture(deployEscrow);
    await expect(escrow.pay({ value: 1n }))
      .to.be.revertedWithCustomError(escrow, "WrongAmount").withArgs(1n, PRICE);
  });

  it("rejects callers without the right role", async function () {
    const { escrow, stranger } = await networkHelpers.loadFixture(deployEscrow);
    await expect(escrow.connect(stranger).pay({ value: PRICE }))
      .to.be.revertedWithCustomError(escrow, "OnlyRole").withArgs(stranger.address);
  });

  it("rejects steps taken in the wrong state", async function () {
    const { escrow, agent } = await networkHelpers.loadFixture(deployEscrow);
    await expect(escrow.connect(agent).confirmDelivery())
      .to.be.revertedWithCustomError(escrow, "WrongState")
      .withArgs(State.AwaitingDelivery, State.AwaitingPayment);
  });

  it("lets the agent cancel, and the buyer withdraws", async function () {
    const { escrow, buyer, agent } = await networkHelpers.loadFixture(deployEscrow);
    await escrow.pay({ value: PRICE });
    await escrow.connect(agent).refund();
    expect(await escrow.state()).to.equal(State.Refunded);
    await expect(escrow.connect(buyer).withdraw())
      .to.changeEtherBalances(ethers, [escrow, buyer], [-PRICE, PRICE]);
  });

  it("lets the buyer reclaim only after the deadline", async function () {
    const { escrow } = await networkHelpers.loadFixture(deployEscrow);
    await escrow.pay({ value: PRICE });
    const deadline = await escrow.deadline();
    await expect(escrow.refund())
      .to.be.revertedWithCustomError(escrow, "DeadlineNotReached")
      .withArgs(deadline);
    await networkHelpers.time.increaseTo(deadline);
    await expect(escrow.refund()).to.emit(escrow, "Refunded");
  });

  it("cannot be blocked by a seller that rejects ether", async function () {
    const [buyer, , agent] = await ethers.getSigners();
    const rejecter = await ethers.deployContract("RejectingRecipient");
    const escrow = await ethers.deployContract("Escrow", [
      buyer.address, await rejecter.getAddress(), agent.address, PRICE, WINDOW,
    ]);
    await escrow.pay({ value: PRICE });
    // With a push payment this call would revert; with pull it completes.
    await escrow.connect(agent).confirmDelivery();
    expect(await escrow.owed(await rejecter.getAddress())).to.equal(PRICE);
  });
});
