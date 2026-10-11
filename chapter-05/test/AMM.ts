import { expect } from "chai";
import { network } from "hardhat";

const { ethers, networkHelpers } = await network.create();
const E18 = 10n ** 18n;
const E6 = 10n ** 6n;
const soon = async () => BigInt(await networkHelpers.time.latest()) + 600n;

async function deployPool() {
  const [owner, trader] = await ethers.getSigners();
  const weth = await ethers.deployContract("TestToken", ["Wrapped ETH", "WETH", 18]);
  const usdc = await ethers.deployContract("TestToken", ["Test USD", "tUSD", 6]);
  const amm = await ethers.deployContract("SimpleAMM", [
    await weth.getAddress(), await usdc.getAddress(), owner.address]);
  const ammAddress = await amm.getAddress();
  await weth.mint(owner.address, 100n * E18);
  await usdc.mint(owner.address, 300_000n * E6);
  await weth.approve(ammAddress, 100n * E18);
  await usdc.approve(ammAddress, 300_000n * E6);
  // 1 WETH = 3,000 tUSD
  await amm.addLiquidity(100n * E18, 300_000n * E6, 0n, await soon());
  await weth.mint(trader.address, 10n * E18);
  await weth.connect(trader).approve(ammAddress, 10n * E18);
  return { amm, weth, usdc, trader };
}

describe("SimpleAMM", function () {
  it("pays out according to x * y = k with a 0.3% fee", async function () {
    const { amm, weth, usdc, trader } = await networkHelpers.loadFixture(deployPool);
    const expected = await amm.getAmountOut(E18, 100n * E18, 300_000n * E6);
    await amm.connect(trader).swap(await weth.getAddress(), E18, 0, await soon());
    expect(await usdc.balanceOf(trader.address)).to.equal(expected);
    console.log(`      1 WETH -> ${ethers.formatUnits(expected, 6)} tUSD`);
  });

  it("never lets k decrease", async function () {
    const { amm, weth, trader } = await networkHelpers.loadFixture(deployPool);
    const k0 = (await amm.reserveA()) * (await amm.reserveB());
    await amm.connect(trader).swap(await weth.getAddress(), 5n * E18, 0, await soon());
    const k1 = (await amm.reserveA()) * (await amm.reserveB());
    expect(k1 >= k0).to.equal(true);
  });

  it("reverts when the output falls below the trader's minimum", async function () {
    const { amm, weth, trader } = await networkHelpers.loadFixture(deployPool);
    const quote = await amm.getAmountOut(E18, 100n * E18, 300_000n * E6);
    const weth_ = await weth.getAddress();
    await expect(amm.connect(trader).swap(weth_, E18, quote + 1n, await soon()))
      .to.be.revertedWithCustomError(amm, "SlippageExceeded");
  });
});
