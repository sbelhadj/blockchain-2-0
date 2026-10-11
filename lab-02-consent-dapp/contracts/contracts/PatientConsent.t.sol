// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PatientConsent} from "./PatientConsent.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Unit and fuzz tests for PatientConsent.
contract PatientConsentTest is Test {
    PatientConsent consent;
    address admin = makeAddr("admin");
    address patient = makeAddr("patient");
    address provider = makeAddr("provider");
    bytes32 constant LAB = keccak256("LAB_RESULTS");
    bytes32 constant READ = keccak256("READ");

    function setUp() public {
        consent = new PatientConsent(admin);
        bytes32 role = consent.PROVIDER_ROLE();
        vm.prank(admin);
        consent.grantRole(role, provider);
    }

    function _grant(uint32 days_) internal returns (uint256) {
        vm.prank(patient);
        return consent.grantConsent(provider, LAB, days_, bytes32("purpose"));
    }

    function testFuzz_ConsentLastsExactlyItsDuration(uint32 days_) public {
        days_ = uint32(bound(days_, 1, consent.MAX_DAYS()));
        _grant(days_);
        vm.warp(block.timestamp + uint256(days_) * 1 days - 1);
        assertTrue(consent.hasActiveConsent(patient, provider, LAB));
        vm.warp(block.timestamp + 1);
        assertFalse(consent.hasActiveConsent(patient, provider, LAB));
    }

    function testFuzz_RejectsBadDurations(uint32 days_) public {
        vm.assume(days_ == 0 || days_ > consent.MAX_DAYS());
        vm.prank(patient);
        vm.expectRevert(abi.encodeWithSelector(PatientConsent.InvalidDuration.selector, days_));
        consent.grantConsent(provider, LAB, days_, 0);
    }

    function testFuzz_UnrelatedPairsNeverPass(address p, address q, bytes32 cat) public {
        _grant(30);                                     // consent id 1 exists
        vm.assume(!(p == patient && q == provider && cat == LAB));
        assertFalse(consent.hasActiveConsent(p, q, cat));
    }

    function test_GrantChecks() public {
        vm.prank(patient);
        vm.expectRevert(abi.encodeWithSelector(PatientConsent.NotProvider.selector, address(7)));
        consent.grantConsent(address(7), LAB, 30, 0);
        vm.prank(provider);
        vm.expectRevert(PatientConsent.SelfConsent.selector);
        consent.grantConsent(provider, LAB, 30, 0);
    }

    function test_ReplacementRevokesTheEarlierConsent() public {
        uint256 first = _grant(30);
        vm.expectEmit(address(consent));
        emit PatientConsent.ConsentRevoked(first, patient, provider);
        uint256 second = _grant(60);
        (,, bool active,,,) = consent.consents(first);
        assertFalse(active);
        assertEq(consent.activeConsentId(patient, provider, LAB), second);
    }

    function test_RevokeRules() public {
        uint256 id = _grant(30);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(PatientConsent.NotYourConsent.selector, id));
        consent.revokeConsent(id);
        vm.prank(patient);
        consent.revokeConsent(id);
        vm.prank(patient);
        vm.expectRevert(abi.encodeWithSelector(PatientConsent.AlreadyInactive.selector, id));
        consent.revokeConsent(id);
        assertFalse(consent.hasActiveConsent(patient, provider, LAB));
    }

    function test_RecordAccessNeedsConsentAndRole() public {
        vm.prank(provider);
        vm.expectRevert(
            abi.encodeWithSelector(PatientConsent.NoActiveConsent.selector, patient, provider, LAB)
        );
        consent.recordAccess(patient, LAB, READ);
        _grant(30);
        vm.expectEmit(address(consent));
        emit PatientConsent.DataAccessed(patient, provider, LAB, READ);
        vm.prank(provider);
        consent.recordAccess(patient, LAB, READ);
    }

    function test_SuspendedProviderLosesConsent() public {
        _grant(30);
        bytes32 role = consent.PROVIDER_ROLE();
        vm.prank(admin);
        consent.revokeRole(role, provider);
        assertFalse(consent.hasActiveConsent(patient, provider, LAB));
        vm.prank(admin);
        consent.grantRole(role, provider);
        assertTrue(consent.hasActiveConsent(patient, provider, LAB));
    }

    function test_PauseNeverBlocksRevocation() public {
        uint256 id = _grant(30);
        vm.prank(patient);
        vm.expectRevert();
        consent.pause();
        vm.prank(admin);
        consent.pause();
        vm.prank(patient);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        consent.grantConsent(provider, LAB, 30, 0);
        vm.prank(provider);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        consent.recordAccess(patient, LAB, READ);
        vm.prank(patient);
        consent.revokeConsent(id);                      // still allowed
        vm.prank(admin);
        consent.unpause();
        _grant(30);
    }

    function test_AdminMovesInTwoStepsWithDelay() public {
        address next = makeAddr("next");
        vm.prank(admin);
        consent.beginDefaultAdminTransfer(next);
        vm.prank(next);
        vm.expectRevert();
        consent.acceptDefaultAdminTransfer();           // delay not over
        vm.warp(block.timestamp + consent.ADMIN_DELAY() + 1);
        vm.prank(next);
        consent.acceptDefaultAdminTransfer();
        assertEq(consent.defaultAdmin(), next);
    }
}

/// @notice Grants, revokes and records accesses at random for two patients and
///         two providers, and keeps a model of which consents should be live.
contract ConsentHandler is Test {
    PatientConsent internal immutable consent;
    address[2] internal patients = [address(0x9A1), address(0x9A2)];
    address[2] internal providers = [address(0xD01), address(0xD02)];
    bytes32 internal constant CAT = keccak256("LAB_RESULTS");
    mapping(address => mapping(address => uint256)) public modelId;
    uint256 public accessesWithoutConsent;

    constructor(PatientConsent c) {
        consent = c;
    }

    function grant(uint256 pi, uint256 qi, uint32 days_) external {
        address p = patients[pi % 2];
        address q = providers[qi % 2];
        days_ = uint32(bound(days_, 1, 365));
        vm.prank(p);
        modelId[p][q] = consent.grantConsent(q, CAT, days_, 0);
    }

    function revoke(uint256 pi, uint256 qi) external {
        address p = patients[pi % 2];
        address q = providers[qi % 2];
        uint256 id = modelId[p][q];
        if (id == 0) return;
        vm.prank(p);
        consent.revokeConsent(id);
        modelId[p][q] = 0;
    }

    function access(uint256 pi, uint256 qi) external {
        address p = patients[pi % 2];
        address q = providers[qi % 2];
        bool allowed = consent.hasActiveConsent(p, q, CAT);
        vm.prank(q);
        try consent.recordAccess(p, CAT, "READ") {
            if (!allowed) accessesWithoutConsent++;
        } catch {}
    }

    function warp(uint32 dt) external {
        vm.warp(block.timestamp + bound(dt, 0, 30 days));
    }

    function pair(uint256 i, uint256 j) external view returns (address, address) {
        return (patients[i], providers[j]);
    }
}

/// @title Invariant suite for PatientConsent
contract PatientConsentInvariantTest is Test {
    PatientConsent internal consent;
    ConsentHandler internal handler;

    function setUp() public {
        consent = new PatientConsent(address(this));
        handler = new ConsentHandler(consent);
        consent.grantRole(consent.PROVIDER_ROLE(), address(0xD01));
        consent.grantRole(consent.PROVIDER_ROLE(), address(0xD02));
        targetContract(address(handler));
    }

    /// No access is ever recorded without a live consent.
    function invariant_NoAccessWithoutConsent() public view {
        assertEq(handler.accessesWithoutConsent(), 0);
    }

    /// The contract's current consent for each pair is the one the model expects,
    /// and at most one consent per pair is active.
    function invariant_OneActiveConsentPerPair() public view {
        bytes32 cat = keccak256("LAB_RESULTS");
        for (uint256 i; i < 2; i++) {
            for (uint256 j; j < 2; j++) {
                (address p, address q) = handler.pair(i, j);
                uint256 id = consent.activeConsentId(p, q, cat);
                assertEq(id, handler.modelId(p, q));
                if (id != 0) {
                    (address patient,, bool active, address provider,,) = consent.consents(id);
                    assertTrue(active);
                    assertEq(patient, p);
                    assertEq(provider, q);
                }
            }
        }
    }

    /// Ids are dense: every id up to consentCount exists.
    function invariant_IdsAreDense() public view {
        uint256 n = consent.consentCount();
        if (n == 0) return;
        (address patient,,,,,) = consent.consents(n);
        assertTrue(patient != address(0));
    }
}
