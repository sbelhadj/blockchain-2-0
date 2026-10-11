// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Voting} from "./Voting.sol";

/// @notice Exercise 3.2: unit tests for the edges, and the fuzz property that
///         one voter can raise the total by at most one.
contract VotingTest is Test {
    Voting voting;

    function setUp() public {
        voting = new Voting(address(this));
        voting.addCandidate("A");
        voting.addCandidate("B");
    }

    function testFuzz_OneVoterAtMostOneVote(
        address voter,
        uint8 tries,
        uint256 pick
    ) public {
        vm.assume(voter != address(0));
        voting.registerVoter(voter);
        uint256 before = voting.totalVotes();
        for (uint256 i = 0; i < bound(tries, 1, 5); i++) {
            vm.prank(voter);
            try voting.vote(pick % 3) {} catch {}
        }
        assertLe(voting.totalVotes(), before + 1);
    }

    function test_RegistrationEdges() public {
        vm.expectRevert(Voting.ZeroAddress.selector);
        voting.registerVoter(address(0));
        voting.registerVoter(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(Voting.AlreadyRegistered.selector, address(1))
        );
        voting.registerVoter(address(1));
    }

    function test_CandidateCap() public {
        for (uint256 i = 2; i < voting.MAX_CANDIDATES(); i++) {
            voting.addCandidate("X");
        }
        vm.expectRevert(Voting.TooManyCandidates.selector);
        voting.addCandidate("One too many");
    }

    function test_TieGoesToLowerIndexAndLaterLeaderWins() public {
        voting.addCandidate("C");
        address[3] memory voters = [address(11), address(12), address(13)];
        for (uint256 i = 0; i < 3; i++) voting.registerVoter(voters[i]);
        vm.prank(voters[0]);
        voting.vote(1);
        vm.prank(voters[1]);
        voting.vote(2);
        vm.prank(voters[2]);
        voting.vote(2);
        voting.close();
        (uint256 index, string memory name) = voting.winner();
        assertEq(index, 2);
        assertEq(name, "C");
        Voting tie = new Voting(address(this));
        tie.addCandidate("P");
        tie.addCandidate("Q");
        tie.close();
        (index, ) = tie.winner();
        assertEq(index, 0);
    }

    function test_VoteRejections() public {
        vm.prank(address(7));
        vm.expectRevert(abi.encodeWithSelector(Voting.NotRegistered.selector, address(7)));
        voting.vote(0);
        voting.registerVoter(address(7));
        vm.prank(address(7));
        vm.expectRevert(abi.encodeWithSelector(Voting.UnknownCandidate.selector, 9));
        voting.vote(9);
        vm.prank(address(7));
        voting.vote(0);
        vm.prank(address(7));
        vm.expectRevert(abi.encodeWithSelector(Voting.AlreadyVoted.selector, address(7)));
        voting.vote(1);
        (string memory name, uint256 votes) = voting.candidate(0);
        assertEq(name, "A");
        assertEq(votes, 1);
        assertEq(voting.candidateCount(), 2);
        vm.expectRevert(abi.encodeWithSelector(Voting.UnknownCandidate.selector, 5));
        voting.candidate(5);
    }

    function test_PhaseRules() public {
        vm.expectRevert(Voting.ElectionOpen.selector);
        voting.winner();
        voting.close();
        vm.expectRevert(Voting.ElectionClosed.selector);
        voting.addCandidate("Late");
        vm.expectRevert(Voting.ElectionClosed.selector);
        voting.close();
        vm.expectRevert(Voting.ElectionClosed.selector);
        voting.vote(0);
        Voting empty = new Voting(address(this));
        empty.close();
        vm.expectRevert(Voting.NoCandidates.selector);
        empty.winner();
    }
}

/// @notice Registers voters and casts votes at random for the invariant test.
contract VotingHandler is Test {
    Voting public immutable voting;
    uint256 public registered;
    address[] internal voters;

    constructor(Voting v) {
        voting = v;
    }

    function register(uint160 seed) external {
        address voter = address(uint160(bound(seed, 1, 30)));
        try voting.registerVoter(voter) {
            registered++;
            voters.push(voter);
        } catch {}
    }

    function vote(uint256 who, uint256 pick) external {
        if (voters.length == 0) return;
        vm.prank(voters[who % voters.length]);
        try voting.vote(pick % 3) {} catch {}
    }
}

/// @notice Exercise 3.2, Step 4: the votes counted never exceed the voters
///         registered.
contract VotingInvariantTest is Test {
    Voting internal voting;
    VotingHandler internal handler;

    function setUp() public {
        voting = new Voting(address(this));
        voting.addCandidate("A");
        voting.addCandidate("B");
        handler = new VotingHandler(voting);
        voting.transferOwnership(address(handler));
        targetContract(address(handler));
    }

    function invariant_VotesNeverExceedVoters() public view {
        assertLe(voting.totalVotes(), handler.registered());
    }
}
