import { expect } from "chai";
import { network } from "hardhat";

const { ethers, networkHelpers } = await network.create();
const E18 = 10n ** 18n;
const E6 = 10n ** 6n;
const usd8 = (x: number) => BigInt(x) * 10n ** 8n;        // Chainlink-style price
const hf = (x: bigint) => ethers.formatUnits(x, 18);

async function deployPool() {
  const [owner, lender, bob, liquidator] = await ethers.getSigners();
  const weth = await ethers.deployContract("TestToken", ["Wrapped ETH", "WETH", 18]);
  const usdc = await ethers.deployContract("TestToken", ["Test USD", "tUSD", 6]);
  const feed = await ethers.deployContract("MockPriceFeed", [usd8(2_500)]);
  const pool = await ethers.deployContract("LendingPool", [
    await weth.getAddress(), await usdc.getAddress(), await feed.getAddress(),
    owner.address]);
  const at = await pool.getAddress();
  await usdc.mint(lender.address, 100_000n * E6);
  await usdc.connect(lender).approve(at, 100_000n * E6);
  await pool.connect(lender).supply(100_000n * E6);
  await weth.mint(bob.address, 3n * E18);
  await weth.connect(bob).approve(at, 3n * E18);
  await pool.connect(bob).depositCollateral(3n * E18);     // 3 WETH = $7,500
  await usdc.mint(liquidator.address, 10_000n * E6);
  await usdc.connect(liquidator).approve(at, 10_000n * E6);
  return { owner, pool, weth, usdc, feed, bob, liquidator };
}

describe("LendingPool", function () {
  it("lets Bob borrow up to 75% of his collateral value", async function () {
    const { pool, bob } = await networkHelpers.loadFixture(deployPool);
    expect(await pool.availableToBorrow(bob.address)).to.equal(5_625n * E6);
    await expect(pool.connect(bob).borrow(5_626n * E6))
      .to.be.revertedWithCustomError(pool, "ExceedsBorrowLimit");
    await pool.connect(bob).borrow(5_000n * E6);
    const after = await pool.healthFactor(bob.address);
    console.log(`      health factor after borrowing 5,000: ${hf(after)}`);
  });

  it("refuses to liquidate a healthy position", async function () {
    const { pool, bob, liquidator } = await networkHelpers.loadFixture(deployPool);
    await pool.connect(bob).borrow(5_000n * E6);
    await expect(pool.connect(liquidator).liquidate(bob.address, 1_000n * E6))
      .to.be.revertedWithCustomError(pool, "Healthy");
  });

  it("liquidates after a price drop (5% bonus, 50% close factor)", async function () {
    const { pool, feed, weth, bob, liquidator } =
      await networkHelpers.loadFixture(deployPool);
    await pool.connect(bob).borrow(5_000n * E6);
    await feed.setPrice(usd8(2_000));                      // ETH falls 20%
    const before = await pool.healthFactor(bob.address);
    await expect(pool.connect(liquidator).liquidate(bob.address, 2_501n * E6))
      .to.be.revertedWithCustomError(pool, "RepayTooLarge");
    await expect(pool.connect(liquidator).liquidate(bob.address, 2_500n * E6))
      .to.emit(pool, "Liquidated");
    const seized = await weth.balanceOf(liquidator.address);
    console.log(`      health factor before: ${hf(before)}`);
    console.log(`      liquidator repaid 2,500 tUSD, ` +
      `received ${ethers.formatEther(seized)} WETH`);
    const afterHf = await pool.healthFactor(bob.address);
    console.log(`      health factor after:  ${hf(afterHf)}`);
    expect(seized).to.equal(2_500n * 105n * E18 / 100n / 2_000n);   // $2,625 of WETH
  });

  it("rejects a stale oracle price", async function () {
    const { pool, bob } = await networkHelpers.loadFixture(deployPool);
    await networkHelpers.time.increase(2 * 60 * 60);
    await expect(pool.connect(bob).borrow(1n))
      .to.be.revertedWithCustomError(pool, "StalePrice");
  });

  it("blocks withdrawals that would make the position unhealthy", async function () {
    const { pool, bob } = await networkHelpers.loadFixture(deployPool);
    await pool.connect(bob).borrow(5_000n * E6);
    await expect(pool.connect(bob).withdrawCollateral(E18))
      .to.be.revertedWithCustomError(pool, "Unhealthy");
  });
});
