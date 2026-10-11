import { expect } from "chai";
import { network } from "hardhat";

const { ethers, networkHelpers } = await network.create("frozenClock");
const E18 = 10n ** 18n;
const E6 = 10n ** 6n;
const usd8 = (x: bigint) => x * 10n ** 8n;
const DAY = 24n * 3600n;

async function deployPool() {
  const [owner, lender, bob, liquidator] = await ethers.getSigners();
  const weth = await ethers.deployContract("TestToken", [
    "Wrapped ETH",
    "WETH",
    18,
  ]);
  const usd = await ethers.deployContract("TestToken", ["Test USD", "tUSD", 6]);
  const feed = await ethers.deployContract("MockPriceFeed", [usd8(2_500n)]);
  const pool = await ethers.deployContract("LendingPoolWithInterest", [
    await weth.getAddress(),
    await usd.getAddress(),
    await feed.getAddress(),
    owner.address,
  ]);
  const at = await pool.getAddress();
  for (const [who, amount] of [
    [lender, 10_000n],
    [liquidator, 10_000n],
  ] as const) {
    await usd.mint(who.address, amount * E6);
    await usd.connect(who).approve(at, amount * E6);
  }
  await weth.mint(bob.address, 10n * E18);
  await weth.connect(bob).approve(at, 10n * E18);
  await usd.connect(bob).approve(at, 100_000n * E6);
  await usd.mint(bob.address, 1_000n * E6); // to pay interest later
  return { pool, feed, weth, usd, lender, bob, liquidator };
}

describe("LendingPoolWithInterest (Exercise 5.4 solution)", function () {
  it("rate model: 2% at 0, 7% at 50%, 10% at 80%, 60% at 100%", async function () {
    const { pool } = await networkHelpers.loadFixture(deployPool);
    const rates = await Promise.all(
      [0, 5_000, 8_000, 10_000].map((u) => pool.borrowRateBps(u)),
    );
    expect(rates).to.deep.equal([200n, 700n, 1_000n, 6_000n]);
  });

  it("charges 7% a year at 50% utilization and pays the lender", async function () {
    const { pool, feed, lender, bob } =
      await networkHelpers.loadFixture(deployPool);
    await pool.connect(lender).supply(10_000n * E6);
    await pool.connect(bob).depositCollateral(10n * E18);
    await pool.connect(bob).borrow(5_000n * E6); // utilization 50%
    await networkHelpers.time.increase(365n * DAY);
    await feed.setPrice(usd8(2_500n)); // keep the price fresh
    const debt = await pool.debtOf(bob.address);
    const supplied = await pool.suppliedOf(lender.address);
    console.log(`      debt after 1 year:     ${ethers.formatUnits(debt, 6)} tUSD`);
    console.log(
      `      lender after 1 year:   ${ethers.formatUnits(supplied, 6)} tUSD`,
    );
    expect(debt).to.be.closeTo(5_350n * E6, 1n * E6);
    expect(supplied).to.be.closeTo(10_350n * E6, 1n * E6);
  });

  it("lets a lender withdraw only what is not lent out", async function () {
    const { pool, lender, bob } = await networkHelpers.loadFixture(deployPool);
    await pool.connect(lender).supply(10_000n * E6);
    await pool.connect(bob).depositCollateral(10n * E18);
    await pool.connect(bob).borrow(6_000n * E6);
    await expect(
      pool.connect(lender).withdrawSupply(5_000n * E6),
    ).to.be.revertedWithCustomError(pool, "InsufficientLiquidity");
    await pool.connect(lender).withdrawSupply(4_000n * E6);
  });

  it("makes a position liquidatable through interest alone", async function () {
    const { pool, feed, lender, bob, liquidator } =
      await networkHelpers.loadFixture(deployPool);
    await pool.connect(lender).supply(6_000n * E6);
    await pool.connect(bob).depositCollateral(3n * E18); // $7,500
    await pool.connect(bob).borrow(5_625n * E6); // max LTV, 93.75% util
    expect(await pool.healthFactor(bob.address)).to.be.greaterThan(E18);
    await networkHelpers.time.increase(90n * DAY);
    await feed.setPrice(usd8(2_500n)); // same price, fresh
    const hf = await pool.healthFactor(bob.address);
    console.log(
      `      health factor after 90 days: ${ethers.formatUnits(hf, 18)}`,
    );
    expect(hf).to.be.lessThan(E18);
    await expect(
      pool.connect(liquidator).liquidate(bob.address, 1_000n * E6),
    ).to.emit(pool, "Liquidated");
  });

  it("does not liquidate at exactly 1.0, does just below", async function () {
    const { pool, feed, lender, bob, liquidator } =
      await networkHelpers.loadFixture(deployPool);
    await pool.connect(lender).supply(10_000n * E6);
    await pool.connect(bob).depositCollateral(3n * E18);
    await pool.connect(bob).borrow(4_800n * E6);
    // Freeze the clock: the next blocks share the borrow block's timestamp,
    // so no interest accrues and 3 WETH x $2,000 x 80% equals 4,800 exactly.
    const t = await networkHelpers.time.latest();
    await networkHelpers.time.setNextBlockTimestamp(t);
    await feed.setPrice(usd8(2_000n));
    expect(await pool.healthFactor(bob.address)).to.equal(E18);
    await networkHelpers.time.setNextBlockTimestamp(t);
    await expect(pool.connect(liquidator).liquidate(bob.address, 1_000n * E6))
      .to.be.revertedWithCustomError(pool, "Healthy")
      .withArgs(E18);
    await networkHelpers.time.setNextBlockTimestamp(t + 1); // one second of interest
    await expect(
      pool.connect(liquidator).liquidate(bob.address, 1_000n * E6),
    ).to.emit(pool, "Liquidated");
  });

  it("clears the debt exactly on full repayment", async function () {
    const { pool, lender, bob } = await networkHelpers.loadFixture(deployPool);
    await pool.connect(lender).supply(10_000n * E6);
    await pool.connect(bob).depositCollateral(3n * E18);
    await pool.connect(bob).borrow(1_000n * E6);
    await networkHelpers.time.increase(30n * DAY);
    await pool.connect(bob).repay(2_000n * E6); // more than owed: capped
    expect(await pool.scaledDebtOf(bob.address)).to.equal(0n);
    expect(await pool.totalScaledDebt()).to.equal(0n);
  });
});
