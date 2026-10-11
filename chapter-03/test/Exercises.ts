import { expect } from "chai";
import { network } from "hardhat";

const { ethers, networkHelpers } = await network.create();
const TICKET = ethers.parseEther("0.1");
const ONE = ethers.parseEther("1");

describe("Exercise 3.3, Lottery", function () {
  it("A1: anyone can pick the winner, at a moment they choose", async function () {
    const [, p1, p2, outsider] = await ethers.getSigners();
    const lottery = await ethers.deployContract("Lottery");
    await lottery.connect(p1).enter({ value: TICKET });
    await lottery.connect(p2).enter({ value: TICKET });
    // The outsider, not a player and not an operator, triggers the draw.
    await expect(lottery.connect(outsider).pickWinner()).not.to.be.revert(ethers);
  });

  it("A2: the outcome is predictable from the block timestamp", async function () {
    const [, p1, p2] = await ethers.getSigners();
    const lottery = await ethers.deployContract("Lottery");
    await lottery.connect(p1).enter({ value: TICKET });
    await lottery.connect(p2).enter({ value: TICKET });
    const next = BigInt(await networkHelpers.time.latest()) + 10n;
    const seed = BigInt(ethers.solidityPackedKeccak256(["uint256"], [next]));
    const predicted = [p1, p2][Number(seed % 2n)];
    await networkHelpers.time.setNextBlockTimestamp(next);
    await expect(lottery.pickWinner()).to.changeEtherBalance(
      ethers,
      predicted,
      TICKET * 2n,
    );
  });

  it("A3: a contract winner blocks the transfer payout", async function () {
    const [, p1] = await ethers.getSigners();
    const lottery = await ethers.deployContract("Lottery");
    const sink = await ethers.deployContract("RejectingRecipient");
    await networkHelpers.impersonateAccount(await sink.getAddress());
    await networkHelpers.setBalance(await sink.getAddress(), ONE);
    const sinkSigner = await ethers.getSigner(await sink.getAddress());
    await lottery.connect(sinkSigner).enter({ value: TICKET });
    await expect(lottery.connect(p1).pickWinner()).to.be.revert(ethers);
  });

  it("fixed: no early draw; the winner claims the prize", async function () {
    const [, p1, p2] = await ethers.getSigners();
    const lottery = await ethers.deployContract("LotteryFixed", [3600]);
    await lottery.connect(p1).enter({ value: TICKET });
    await lottery.connect(p2).enter({ value: TICKET });
    await expect(lottery.close()).to.be.revertedWithCustomError(
      lottery,
      "StillOpen",
    );
    await networkHelpers.time.increase(3600);
    await lottery.close();
    await expect(lottery.draw()).to.be.revertedWithCustomError(lottery, "TooEarly");
    await networkHelpers.mine(6);
    await lottery.draw();
    const winner = await ethers.getSigner(await lottery.winner());
    await expect(lottery.connect(winner).claim()).to.changeEtherBalance(
      ethers,
      winner,
      TICKET * 2n,
    );
  });
});

describe("Exercise 3.3, TokenSale", function () {
  it("B1: anyone can set the price to zero and buy for free", async function () {
    const [, mallory] = await ethers.getSigners();
    const sale = await ethers.deployContract("TokenSale");
    await sale.connect(mallory).setPrice(0);
    await sale.connect(mallory).buy(1_000_000, { value: 0 });
    expect(await sale.tokenBalances(mallory.address)).to.equal(1_000_000n);
  });

  it("B2: ether paid in can never leave the contract", async function () {
    const sale = await ethers.deployContract("TokenSale");
    await sale.buy(2, { value: 2n * ONE });
    const fns = sale.interface.fragments
      .filter((f) => f.type === "function")
      .map((f) => (f as { name: string }).name);
    expect(fns).to.not.include("withdraw");
    expect(await ethers.provider.getBalance(await sale.getAddress())).to.equal(
      2n * ONE,
    );
  });

  it("fixed: price is owner-only, buyers cap it, owner withdraws", async function () {
    const [owner, mallory] = await ethers.getSigners();
    const sale = await ethers.deployContract("TokenSaleFixed", [owner.address]);
    await expect(sale.connect(mallory).setPrice(0)).to.be.revertedWithCustomError(
      sale,
      "OwnableUnauthorizedAccount",
    );
    await sale.setPrice(2n * ONE);
    await expect(
      sale.connect(mallory).buy(1, ONE, { value: ONE }),
    ).to.be.revertedWithCustomError(sale, "PriceAboveLimit");
    await sale.connect(mallory).buy(1, 2n * ONE, { value: 2n * ONE });
    await expect(sale.withdraw()).to.changeEtherBalance(ethers, owner, 2n * ONE);
  });
});

describe("Exercise 3.3, Airdrop", function () {
  it("C1: anyone can send the contract's ether to themselves", async function () {
    const [owner, mallory] = await ethers.getSigners();
    const drop = await ethers.deployContract("Airdrop");
    await owner.sendTransaction({ to: await drop.getAddress(), value: 5n * ONE });
    await expect(
      drop.connect(mallory).distribute([mallory.address], 5n * ONE),
    ).to.changeEtherBalance(ethers, mallory, 5n * ONE);
  });

  it("C2: one rejecting recipient blocks the whole distribution", async function () {
    const [owner, a] = await ethers.getSigners();
    const drop = await ethers.deployContract("Airdrop");
    const sink = await ethers.deployContract("RejectingRecipient");
    await owner.sendTransaction({ to: await drop.getAddress(), value: 2n * ONE });
    await expect(
      drop.distribute([a.address, await sink.getAddress()], ONE),
    ).to.be.revert(ethers);
  });

  it("fixed: owner-only, accumulating shares, pull claims", async function () {
    const [owner, a, mallory] = await ethers.getSigners();
    const drop = await ethers.deployContract("AirdropFixed", [owner.address]);
    const sink = await ethers.deployContract("RejectingRecipient");
    await owner.sendTransaction({ to: await drop.getAddress(), value: 3n * ONE });
    await expect(
      drop.connect(mallory).allocate([mallory.address], ONE),
    ).to.be.revertedWithCustomError(drop, "OwnableUnauthorizedAccount");
    await drop.allocate([a.address, await sink.getAddress()], ONE);
    await drop.allocate([a.address], ONE); // adds, does not overwrite
    await expect(drop.connect(a).claim()).to.changeEtherBalance(
      ethers,
      a,
      2n * ONE,
    );
    await expect(
      drop.allocate([a.address], 2n * ONE),
    ).to.be.revertedWithCustomError(drop, "InsufficientFunds");
  });
});
