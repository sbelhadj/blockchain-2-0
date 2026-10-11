import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.create();

describe("Factory", function () {
  it("deploys and registers one escrow per deal", async function () {
    const [, seller, agent] = await ethers.getSigners();
    const factory = await ethers.deployContract("EscrowFactory");
    await expect(factory.createEscrow(seller.address, agent.address, 1000n, 3600n))
      .to.emit(factory, "EscrowCreated");
    await factory.createEscrow(seller.address, agent.address, 2000n, 3600n);
    expect(await factory.count()).to.equal(2n);
    const first = await ethers.getContractAt("Escrow", await factory.escrows(0));
    const [caller] = await ethers.getSigners();
    expect(await first.buyer()).to.equal(caller.address);   // not the factory
  });
});

describe("Pausable", function () {
  it("stops payments while paused, never withdrawals", async function () {
    const [admin, pauser, payee] = await ethers.getSigners();
    const hub = await ethers.deployContract("PaymentHub", [
      admin.address, pauser.address,
    ]);
    await hub.pay(payee.address, { value: 1n });
    await hub.connect(pauser).pause();
    await expect(hub.pay(payee.address, { value: 1n }))
      .to.be.revertedWithCustomError(hub, "EnforcedPause");
    await expect(hub.connect(payee).withdraw())
      .to.changeEtherBalance(ethers, payee, 1n);
    await expect(hub.connect(pauser).unpause())
      .to.be.revertedWithCustomError(hub, "AccessControlUnauthorizedAccount");
    await hub.connect(admin).unpause();
  });
});

describe("UUPS proxy", function () {
  async function deployProxy() {
    const [owner, user, mallory] = await ethers.getSigners();
    const v1 = await ethers.deployContract("PaymentHubV1");
    const init = v1.interface.encodeFunctionData("initialize", [owner.address]);
    const impl = await v1.getAddress();
    const proxy = await ethers.deployContract("HubProxy", [impl, init]);
    const proxyAddress = await proxy.getAddress();
    const hub = await ethers.getContractAt("PaymentHubV1", proxyAddress);
    return { hub, proxy, v1, owner, user, mallory };
  }

  it("keeps state and address across an upgrade", async function () {
    const { hub, owner, user } = await deployProxy();
    await hub.connect(user).pay({ value: 100n });
    const v2 = await ethers.deployContract("PaymentHubV2");
    await hub.connect(owner).upgradeToAndCall(await v2.getAddress(), "0x");
    const hubAddress = await hub.getAddress();
    const hubV2 = await ethers.getContractAt("PaymentHubV2", hubAddress);
    expect(await hubV2.version()).to.equal("2");
    expect(await hubV2.totalPayments()).to.equal(100n);      // state survived
    await hubV2.connect(user).payAndCount({ value: 50n });
    expect(await hubV2.totalPayments()).to.equal(150n);
    expect(await hubV2.paymentCount()).to.equal(1n);
  });

  it("allows only the owner to upgrade", async function () {
    const { hub, mallory } = await deployProxy();
    const v2 = await ethers.deployContract("PaymentHubV2");
    await expect(hub.connect(mallory).upgradeToAndCall(await v2.getAddress(), "0x"))
      .to.be.revertedWithCustomError(hub, "OwnableUnauthorizedAccount");
  });

  it("cannot initialize the implementation directly", async function () {
    const { v1, mallory } = await deployProxy();
    await expect(v1.initialize(mallory.address))
      .to.be.revertedWithCustomError(v1, "InvalidInitialization");
  });
});
