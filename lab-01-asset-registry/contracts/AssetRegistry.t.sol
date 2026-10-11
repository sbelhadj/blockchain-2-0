// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetRegistry} from "./AssetRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Owner that refuses ETH, used to exercise the WithdrawalFailed path.
contract RejectingOwner {
    function accept(AssetRegistry registry) external {
        registry.acceptOwnership();
    }

    function withdraw(AssetRegistry registry) external {
        registry.withdrawFees();
    }
}

/// @notice Unit and fuzz tests. Solidity tests run inside Hardhat 3 with
///         Foundry-compatible syntax.
contract AssetRegistryTest is Test {
    AssetRegistry registry;
    uint256 constant FEE = 0.01 ether;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    // The contract pays fees to its owner, which is this test contract.
    receive() external payable {}

    function setUp() public {
        registry = new AssetRegistry(FEE);
        vm.deal(address(this), 100 ether);
    }

    function _register() internal returns (uint256) {
        return registry.registerAsset{value: FEE}("A", "", AssetRegistry.Industry.Healthcare, "");
    }

    function testFuzz_RejectsAnyWrongFee(uint256 sent) public {
        vm.assume(sent != FEE && sent < 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(AssetRegistry.IncorrectFee.selector, sent, FEE)
        );
        registry.registerAsset{value: sent}("X", "", AssetRegistry.Industry.Finance, "");
    }

    function testFuzz_OwnerListsStayConsistent(uint8 count, uint8 moveIndex) public {
        count = uint8(bound(count, 1, 20));
        moveIndex = uint8(bound(moveIndex, 0, count - 1));
        for (uint256 i = 0; i < count; i++) {
            registry.registerAsset{value: FEE}("A", "", AssetRegistry.Industry.Industrial, "");
        }

        registry.transferAsset(moveIndex, alice, "move");

        uint256[] memory mine = registry.getOwnerAssets(address(this));
        uint256[] memory hers = registry.getOwnerAssets(alice);
        assertEq(mine.length, count - 1);
        assertEq(hers.length, 1);
        assertEq(hers[0], moveIndex);
        for (uint256 i = 0; i < mine.length; i++) {
            assertTrue(mine[i] != moveIndex);
            assertEq(registry.getAsset(mine[i]).currentOwner, address(this));
        }
    }

    function testFuzz_StatusChangesUntilDecommissioned(uint8 raw) public {
        uint256 id = _register();
        AssetRegistry.AssetStatus s = AssetRegistry.AssetStatus(bound(raw, 1, 4));
        registry.updateStatus(id, s);
        assertEq(uint8(registry.getAsset(id).status), uint8(s));
        if (s != AssetRegistry.AssetStatus.Decommissioned) {
            vm.expectRevert(abi.encodeWithSelector(AssetRegistry.StatusUnchanged.selector, id, s));
            registry.updateStatus(id, s);
        } else {
            vm.expectRevert(abi.encodeWithSelector(AssetRegistry.AssetDecommissioned.selector, id));
            registry.updateStatus(id, AssetRegistry.AssetStatus.Active);
            vm.expectRevert(abi.encodeWithSelector(AssetRegistry.AssetDecommissioned.selector, id));
            registry.transferAsset(id, alice, "");
        }
    }

    function test_FeeUpdateAndEmptyName() public {
        vm.expectRevert(AssetRegistry.EmptyName.selector);
        registry.registerAsset{value: FEE}("", "", AssetRegistry.Industry.Finance, "");
        vm.expectEmit(address(registry));
        emit AssetRegistry.RegistrationFeeUpdated(FEE, 0);
        registry.updateRegistrationFee(0);
        assertEq(registry.registrationFee(), 0);
        registry.registerAsset("Free", "", AssetRegistry.Industry.Finance, "");
    }

    function test_RegistrarRules() public {
        vm.expectRevert(AssetRegistry.ZeroAddress.selector);
        registry.authorizeRegistrar(address(0));
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AssetRegistry.NotAuthorizedRegistrar.selector, alice));
        registry.registerAsset{value: FEE}("A", "", AssetRegistry.Industry.Logistics, "");
        registry.authorizeRegistrar(alice);
        vm.prank(alice);
        uint256 id = registry.registerAsset{value: FEE}("A", "", AssetRegistry.Industry.Logistics, "");
        assertEq(registry.getAsset(id).registeredBy, alice);
        registry.revokeRegistrar(alice);
        assertFalse(registry.authorizedRegistrars(alice));
    }

    function test_TransferAndHistory() public {
        uint256 id = _register();
        registry.transferAsset(id, alice, "sale");
        AssetRegistry.TransferRecord[] memory h = registry.getTransferHistory(id);
        assertEq(h.length, 1);
        assertEq(h[0].to, alice);
        vm.expectRevert(abi.encodeWithSelector(AssetRegistry.NotAssetOwner.selector, id, address(this)));
        registry.transferAsset(id, bob, "");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AssetRegistry.InvalidNewOwner.selector, alice));
        registry.transferAsset(id, alice, "");
        vm.expectRevert(abi.encodeWithSelector(AssetRegistry.AssetNotFound.selector, 99));
        registry.getTransferHistory(99);
    }

    function test_PauseStopsChangesNotWithdrawals() public {
        uint256 id = _register();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        registry.pause();
        registry.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        _register();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        registry.transferAsset(id, alice, "");
        vm.expectRevert(Pausable.EnforcedPause.selector);
        registry.updateStatus(id, AssetRegistry.AssetStatus.Active);
        registry.withdrawFees();                               // still possible
        registry.unpause();
        registry.updateStatus(id, AssetRegistry.AssetStatus.Active);
    }

    function test_WithdrawPaysOwner() public {
        _register();
        uint256 before = address(this).balance;
        registry.withdrawFees();
        assertEq(address(this).balance, before + FEE);
        vm.expectRevert(AssetRegistry.NoFeesToWithdraw.selector);
        registry.withdrawFees();
    }

    function test_OwnershipMovesInTwoSteps() public {
        registry.transferOwnership(alice);
        assertEq(registry.owner(), address(this));             // not yet
        assertEq(registry.pendingOwner(), alice);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        registry.acceptOwnership();
        vm.prank(alice);
        registry.acceptOwnership();
        assertEq(registry.owner(), alice);
    }

    function test_WithdrawRevertsWhenOwnerRejectsEth() public {
        _register();
        RejectingOwner rejecter = new RejectingOwner();
        registry.transferOwnership(address(rejecter));
        rejecter.accept(registry);
        vm.expectRevert(AssetRegistry.WithdrawalFailed.selector);
        rejecter.withdraw(registry);
    }
}

/// @notice Drives the registry with bounded random registrations, transfers and
///         status changes across a small set of accounts.
contract RegistryHandler is Test {
    AssetRegistry internal immutable registry;
    address[3] internal actors = [address(0xA1), address(0xA2), address(0xA3)];
    uint256 public feesPaid;
    uint256 public feesWithdrawn;

    constructor(AssetRegistry r) {
        registry = r;
    }

    function register(uint256 who) external {
        address a = actors[who % 3];
        uint256 fee = registry.registrationFee();
        vm.deal(a, fee);
        vm.prank(a);
        registry.registerAsset{value: fee}("A", "", AssetRegistry.Industry.Logistics, "");
        feesPaid += fee;
    }

    function transfer(uint256 seed, uint256 to) external {
        uint256 n = registry.totalAssets();
        if (n == 0) return;
        uint256 id = seed % n;
        AssetRegistry.Asset memory a = registry.getAsset(id);
        address target = actors[to % 3];
        if (target == a.currentOwner || a.status == AssetRegistry.AssetStatus.Decommissioned) return;
        vm.prank(a.currentOwner);
        registry.transferAsset(id, target, "");
    }

    function setStatus(uint256 seed, uint8 raw) external {
        uint256 n = registry.totalAssets();
        if (n == 0) return;
        uint256 id = seed % n;
        AssetRegistry.Asset memory a = registry.getAsset(id);
        AssetRegistry.AssetStatus s = AssetRegistry.AssetStatus(raw % 5);
        if (s == a.status || a.status == AssetRegistry.AssetStatus.Decommissioned) return;
        vm.prank(a.currentOwner);
        registry.updateStatus(id, s);
    }

    function withdraw() external {
        uint256 bal = address(registry).balance;
        if (bal == 0) return;
        vm.prank(registry.owner());
        registry.withdrawFees();
        feesWithdrawn += bal;
    }

    function actor(uint256 i) external view returns (address) {
        return actors[i];
    }
}

/// @title Invariant suite for AssetRegistry
contract AssetRegistryInvariantTest is Test {
    AssetRegistry internal registry;
    RegistryHandler internal handler;

    receive() external payable {}

    function setUp() public {
        registry = new AssetRegistry(0.01 ether);
        handler = new RegistryHandler(registry);
        for (uint256 i; i < 3; i++) registry.authorizeRegistrar(handler.actor(i));
        targetContract(address(handler));
    }

    /// Every asset is in exactly one owner list, and that owner is its currentOwner.
    function invariant_OwnerListsPartitionAssets() public view {
        uint256 listed;
        for (uint256 i; i < 3; i++) {
            address a = handler.actor(i);
            uint256[] memory ids = registry.getOwnerAssets(a);
            listed += ids.length;
            for (uint256 j; j < ids.length; j++) {
                assertEq(registry.getAsset(ids[j]).currentOwner, a);
            }
        }
        assertEq(listed, registry.totalAssets());
    }

    /// The contract holds exactly the fees paid and not yet withdrawn.
    function invariant_FeesAreAccounted() public view {
        assertEq(address(registry).balance, handler.feesPaid() - handler.feesWithdrawn());
    }

    /// A transfer history has one record per transfer, and the last record
    /// names the current owner.
    function invariant_HistoryEndsAtCurrentOwner() public view {
        uint256 n = registry.totalAssets();
        for (uint256 id; id < n; id++) {
            AssetRegistry.TransferRecord[] memory h = registry.getTransferHistory(id);
            if (h.length > 0) assertEq(h[h.length - 1].to, registry.getAsset(id).currentOwner);
        }
    }
}
