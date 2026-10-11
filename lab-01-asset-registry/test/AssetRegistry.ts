import { expect } from "chai";
import { network } from "hardhat";

const { ethers, networkHelpers } = await network.create();

const FEE = ethers.parseEther("0.01");
const Industry = {
  Healthcare: 0,
  Logistics: 1,
  Finance: 2,
  Industrial: 3,
} as const;
const Status = {
  Registered: 0,
  Active: 1,
  InTransit: 2,
  Maintenance: 3,
  Decommissioned: 4,
} as const;

async function deployFixture() {
  const [owner, registrar, user1, user2] = await ethers.getSigners();
  const registry = await ethers.deployContract("AssetRegistry", [FEE]);
  return { registry, owner, registrar, user1, user2 };
}

async function registeredFixture() {
  const f = await deployFixture();
  await f.registry.registerAsset(
    "MRI Scanner",
    "Siemens Magnetom",
    Industry.Healthcare,
    "ipfs://QmTest",
    {
      value: FEE,
    },
  );
  return f;
}

describe("AssetRegistry", function () {
  describe("Deployment", function () {
    it("sets the deployer as owner", async function () {
      const { registry, owner } = await networkHelpers.loadFixture(deployFixture);
      expect(await registry.owner()).to.equal(owner.address);
    });

    it("sets the registration fee", async function () {
      const { registry } = await networkHelpers.loadFixture(deployFixture);
      expect(await registry.registrationFee()).to.equal(FEE);
    });

    it("authorizes the deployer as registrar", async function () {
      const { registry, owner } = await networkHelpers.loadFixture(deployFixture);
      expect(await registry.authorizedRegistrars(owner.address)).to.equal(true);
    });
  });

  describe("Registration", function () {
    it("registers an asset and emits AssetRegistered", async function () {
      const { registry, owner } = await networkHelpers.loadFixture(deployFixture);
      await expect(
        registry.registerAsset(
          "MRI Scanner",
          "Siemens Magnetom",
          Industry.Healthcare,
          "ipfs://QmTest",
          { value: FEE },
        ),
      )
        .to.emit(registry, "AssetRegistered")
        .withArgs(0n, "MRI Scanner", Industry.Healthcare, owner.address);

      const asset = await registry.getAsset(0);
      expect(asset.name).to.equal("MRI Scanner");
      expect(asset.industry).to.equal(BigInt(Industry.Healthcare));
      expect(asset.status).to.equal(BigInt(Status.Registered));
      expect(asset.currentOwner).to.equal(owner.address);
      expect(await registry.totalAssets()).to.equal(1n);
      expect(await registry.getOwnerAssets(owner.address)).to.deep.equal([0n]);
    });

    it("rejects a fee below the required amount", async function () {
      const { registry } = await networkHelpers.loadFixture(deployFixture);
      const low = ethers.parseEther("0.001");
      await expect(
        registry.registerAsset("Test", "Description", Industry.Healthcare, "", {
          value: low,
        }),
      )
        .to.be.revertedWithCustomError(registry, "IncorrectFee")
        .withArgs(low, FEE);
    });

    it("rejects a fee above the required amount", async function () {
      const { registry } = await networkHelpers.loadFixture(deployFixture);
      const high = ethers.parseEther("1");
      await expect(
        registry.registerAsset("Test", "Description", Industry.Healthcare, "", {
          value: high,
        }),
      )
        .to.be.revertedWithCustomError(registry, "IncorrectFee")
        .withArgs(high, FEE);
    });

    it("rejects an unauthorized caller", async function () {
      const { registry, user1 } = await networkHelpers.loadFixture(deployFixture);
      await expect(
        registry
          .connect(user1)
          .registerAsset("Test", "Description", Industry.Healthcare, "", {
            value: FEE,
          }),
      )
        .to.be.revertedWithCustomError(registry, "NotAuthorizedRegistrar")
        .withArgs(user1.address);
    });

    it("rejects an empty name", async function () {
      const { registry } = await networkHelpers.loadFixture(deployFixture);
      await expect(
        registry.registerAsset("", "Description", Industry.Healthcare, "", {
          value: FEE,
        }),
      ).to.be.revertedWithCustomError(registry, "EmptyName");
    });

    it("lets an authorized registrar register", async function () {
      const { registry, registrar } =
        await networkHelpers.loadFixture(deployFixture);
      await expect(registry.authorizeRegistrar(registrar.address))
        .to.emit(registry, "RegistrarAuthorized")
        .withArgs(registrar.address);
      await registry
        .connect(registrar)
        .registerAsset("Pallet", "Euro pallet", Industry.Logistics, "", {
          value: FEE,
        });
      expect((await registry.getAsset(0)).currentOwner).to.equal(registrar.address);
    });

    it("blocks a registrar after revocation", async function () {
      const { registry, registrar } =
        await networkHelpers.loadFixture(deployFixture);
      await registry.authorizeRegistrar(registrar.address);
      await expect(registry.revokeRegistrar(registrar.address))
        .to.emit(registry, "RegistrarRevoked")
        .withArgs(registrar.address);
      await expect(
        registry
          .connect(registrar)
          .registerAsset("Pallet", "", Industry.Logistics, "", { value: FEE }),
      ).to.be.revertedWithCustomError(registry, "NotAuthorizedRegistrar");
    });
  });

  describe("Transfer", function () {
    it("transfers ownership, records history, updates lists", async function () {
      const { registry, owner, user1 } =
        await networkHelpers.loadFixture(registeredFixture);
      await expect(registry.transferAsset(0, user1.address, "Sold to hospital B"))
        .to.emit(registry, "AssetTransferred")
        .withArgs(0n, owner.address, user1.address, "Sold to hospital B");

      expect((await registry.getAsset(0)).currentOwner).to.equal(user1.address);
      const history = await registry.getTransferHistory(0);
      expect(history.length).to.equal(1);
      expect(history[0].from).to.equal(owner.address);
      expect(history[0].to).to.equal(user1.address);
      expect(await registry.getOwnerAssets(owner.address)).to.deep.equal([]);
      expect(await registry.getOwnerAssets(user1.address)).to.deep.equal([0n]);
    });

    it("keeps owner lists consistent when a middle asset leaves", async function () {
      const { registry, owner, user1 } =
        await networkHelpers.loadFixture(deployFixture);
      for (const name of ["A", "B", "C"]) {
        await registry.registerAsset(name, "", Industry.Industrial, "", {
          value: FEE,
        });
      }
      await registry.transferAsset(1, user1.address, "Moved");
      expect(await registry.getOwnerAssets(owner.address)).to.deep.equal([0n, 2n]);
      await registry.transferAsset(2, user1.address, "Moved");
      expect(await registry.getOwnerAssets(owner.address)).to.deep.equal([0n]);
      expect(await registry.getOwnerAssets(user1.address)).to.deep.equal([1n, 2n]);
    });

    it("rejects a transfer from a non-owner", async function () {
      const { registry, user1, user2 } =
        await networkHelpers.loadFixture(registeredFixture);
      await expect(
        registry.connect(user1).transferAsset(0, user2.address, "Unauthorized"),
      )
        .to.be.revertedWithCustomError(registry, "NotAssetOwner")
        .withArgs(0n, user1.address);
    });

    it("rejects the zero address and self-transfer", async function () {
      const { registry, owner } =
        await networkHelpers.loadFixture(registeredFixture);
      await expect(
        registry.transferAsset(0, ethers.ZeroAddress, "x"),
      ).to.be.revertedWithCustomError(registry, "InvalidNewOwner");
      await expect(
        registry.transferAsset(0, owner.address, "x"),
      ).to.be.revertedWithCustomError(registry, "InvalidNewOwner");
    });

    it("rejects operations on a missing asset", async function () {
      const { registry, user1 } = await networkHelpers.loadFixture(deployFixture);
      await expect(registry.transferAsset(7, user1.address, "x"))
        .to.be.revertedWithCustomError(registry, "AssetNotFound")
        .withArgs(7n);
      await expect(registry.getAsset(7)).to.be.revertedWithCustomError(
        registry,
        "AssetNotFound",
      );
      await expect(registry.getTransferHistory(7)).to.be.revertedWithCustomError(
        registry,
        "AssetNotFound",
      );
    });

    it("rejects transferring a decommissioned asset", async function () {
      const { registry, user1 } =
        await networkHelpers.loadFixture(registeredFixture);
      await registry.updateStatus(0, Status.Decommissioned);
      await expect(registry.transferAsset(0, user1.address, "x"))
        .to.be.revertedWithCustomError(registry, "AssetDecommissioned")
        .withArgs(0n);
    });
  });

  describe("Status", function () {
    it("updates status and emits AssetStatusChanged", async function () {
      const { registry } = await networkHelpers.loadFixture(registeredFixture);
      await expect(registry.updateStatus(0, Status.Active))
        .to.emit(registry, "AssetStatusChanged")
        .withArgs(0n, Status.Registered, Status.Active);
      expect((await registry.getAsset(0)).status).to.equal(BigInt(Status.Active));
    });

    it("blocks updates after decommissioning", async function () {
      const { registry } = await networkHelpers.loadFixture(registeredFixture);
      await registry.updateStatus(0, Status.Decommissioned);
      await expect(
        registry.updateStatus(0, Status.Active),
      ).to.be.revertedWithCustomError(registry, "AssetDecommissioned");
    });

    it("rejects a status update from a non-owner", async function () {
      const { registry, user1 } =
        await networkHelpers.loadFixture(registeredFixture);
      await expect(
        registry.connect(user1).updateStatus(0, Status.Active),
      ).to.be.revertedWithCustomError(registry, "NotAssetOwner");
    });
  });

  describe("Fees and admin", function () {
    it("lets the owner withdraw collected fees", async function () {
      const { registry, owner } =
        await networkHelpers.loadFixture(registeredFixture);
      await expect(registry.withdrawFees()).to.changeEtherBalances(
        ethers,
        [registry, owner],
        [-FEE, FEE],
      );
    });

    it("rejects withdrawal when there are no fees", async function () {
      const { registry } = await networkHelpers.loadFixture(deployFixture);
      await expect(registry.withdrawFees()).to.be.revertedWithCustomError(
        registry,
        "NoFeesToWithdraw",
      );
    });

    it("updates the fee and emits RegistrationFeeUpdated", async function () {
      const { registry } = await networkHelpers.loadFixture(deployFixture);
      const newFee = ethers.parseEther("0.02");
      await expect(registry.updateRegistrationFee(newFee))
        .to.emit(registry, "RegistrationFeeUpdated")
        .withArgs(FEE, newFee);
      expect(await registry.registrationFee()).to.equal(newFee);
    });

    it("restricts admin functions to the owner", async function () {
      const { registry, user1 } = await networkHelpers.loadFixture(deployFixture);
      await expect(registry.connect(user1).updateRegistrationFee(0))
        .to.be.revertedWithCustomError(registry, "OwnableUnauthorizedAccount")
        .withArgs(user1.address);
      await expect(
        registry.connect(user1).authorizeRegistrar(user1.address),
      ).to.be.revertedWithCustomError(registry, "OwnableUnauthorizedAccount");
      await expect(
        registry.connect(user1).revokeRegistrar(user1.address),
      ).to.be.revertedWithCustomError(registry, "OwnableUnauthorizedAccount");
      await expect(
        registry.connect(user1).withdrawFees(),
      ).to.be.revertedWithCustomError(registry, "OwnableUnauthorizedAccount");
    });
  });
});
