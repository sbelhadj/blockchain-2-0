// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BatchExecutor} from "./BatchExecutor.sol";

/// @notice Target that records calls or refuses them.
contract Target {
    uint256 public hits;

    function hit() external payable {
        hits++;
    }

    function fail() external pure {
        revert("no");
    }
}

/// @notice Tests the executor's rules. The executor's own address stands in for
///         a delegated EOA, since execute only checks msg.sender == address(this).
contract BatchExecutorTest is Test {
    BatchExecutor ex;
    Target target;

    function setUp() public {
        ex = new BatchExecutor();
        target = new Target();
        vm.deal(address(ex), 10 ether);
    }

    function _calls(uint256 n) internal view returns (BatchExecutor.Call[] memory c) {
        c = new BatchExecutor.Call[](n);
        for (uint256 i; i < n; i++) {
            c[i] = BatchExecutor.Call(address(target), 1 wei, abi.encodeCall(Target.hit, ()));
        }
    }

    function testFuzz_RunsEveryCallInOrder(uint8 n) public {
        n = uint8(bound(n, 1, ex.MAX_CALLS()));
        vm.prank(address(ex));
        ex.execute(_calls(n));
        assertEq(target.hits(), n);
        assertEq(address(target).balance, n);
    }

    function testFuzz_OnlyTheAccountItself(address caller) public {
        vm.assume(caller != address(ex));
        vm.prank(caller);
        vm.expectRevert(BatchExecutor.OnlySelf.selector);
        ex.execute(_calls(1));
    }

    function test_BatchSizeLimits() public {
        vm.startPrank(address(ex));
        vm.expectRevert(abi.encodeWithSelector(BatchExecutor.BadBatchSize.selector, 0));
        ex.execute(_calls(0));
        vm.expectRevert(abi.encodeWithSelector(BatchExecutor.BadBatchSize.selector, 17));
        ex.execute(_calls(17));
        vm.stopPrank();
    }

    function test_OneFailureRevertsTheBatch() public {
        BatchExecutor.Call[] memory c = _calls(3);
        c[1].data = abi.encodeCall(Target.fail, ());
        vm.prank(address(ex));
        vm.expectRevert(abi.encodeWithSelector(BatchExecutor.CallFailed.selector, 1));
        ex.execute(c);
        assertEq(target.hits(), 0);
    }

    function test_EmitsOnePerCallAndAcceptsEth() public {
        vm.expectEmit(address(ex));
        emit BatchExecutor.CallExecuted(0, address(target), 1 wei);
        vm.prank(address(ex));
        ex.execute(_calls(1));
        (bool ok,) = address(ex).call{value: 1 ether}("");
        assertTrue(ok);
    }
}
