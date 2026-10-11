// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Voting
/// @author Sami BELHADJ, Book 3, Exercise 3.2 solution
/// @notice A single election with registered voters.
/// @dev The candidate list is capped so winner() runs in bounded gas.
///      Teaching code, not audited.
contract Voting is Ownable {
    /// @notice Whether votes are accepted.
    enum Phase {
        Open,
        Closed
    }

    struct Candidate {
        string name;
        uint256 votes;
    }

    /// @notice Most candidates one election can have.
    uint256 public constant MAX_CANDIDATES = 50;

    /// @notice Current phase.
    Phase public phase;
    Candidate[] private _candidates;
    /// @notice Whether an account may vote.
    mapping(address => bool) public isRegistered;
    /// @notice Whether an account has voted.
    mapping(address => bool) public hasVoted;
    /// @notice Votes cast so far.
    uint256 public totalVotes;

    /// @notice The election is closed.
    error ElectionClosed();
    /// @notice The election is still open.
    error ElectionOpen();
    /// @notice The candidate list is full.
    error TooManyCandidates();
    /// @notice The voter address is zero.
    error ZeroAddress();
    /// @notice The voter is already registered.
    error AlreadyRegistered(address voter);
    /// @notice The caller is not a registered voter.
    error NotRegistered(address voter);
    /// @notice The caller has already voted.
    error AlreadyVoted(address voter);
    /// @notice No candidate has this index.
    error UnknownCandidate(uint256 index);
    /// @notice There are no candidates.
    error NoCandidates();

    /// @notice A candidate was added.
    event CandidateAdded(uint256 indexed index, string name);
    /// @notice A voter was registered.
    event VoterRegistered(address indexed voter);
    /// @notice A vote was cast.
    event VoteCast(address indexed voter, uint256 indexed candidate);
    /// @notice The election closed with `totalVotes` votes.
    event ElectionClosedEvent(uint256 totalVotes);

    /// @param initialOwner Account that runs the election.
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @dev Restricts a function to the voting period.
    modifier whenOpen() {
        if (phase != Phase.Open) revert ElectionClosed();
        _;
    }

    /// @notice Adds a candidate.
    /// @param name Candidate's name.
    function addCandidate(string calldata name) external onlyOwner whenOpen {
        if (_candidates.length >= MAX_CANDIDATES) revert TooManyCandidates();
        _candidates.push(Candidate(name, 0));
        emit CandidateAdded(_candidates.length - 1, name);
    }

    /// @notice Registers a voter.
    /// @param voter Account allowed to vote.
    function registerVoter(address voter) external onlyOwner whenOpen {
        if (voter == address(0)) revert ZeroAddress();
        if (isRegistered[voter]) revert AlreadyRegistered(voter);
        isRegistered[voter] = true;
        emit VoterRegistered(voter);
    }

    /// @notice Casts the caller's vote.
    /// @param index Candidate's index.
    function vote(uint256 index) external whenOpen {
        if (!isRegistered[msg.sender]) revert NotRegistered(msg.sender);
        if (hasVoted[msg.sender]) revert AlreadyVoted(msg.sender);
        if (index >= _candidates.length) revert UnknownCandidate(index);
        hasVoted[msg.sender] = true;
        _candidates[index].votes += 1;
        totalVotes += 1;
        emit VoteCast(msg.sender, index);
    }

    /// @notice Closes the election. Nothing can change afterwards.
    function close() external onlyOwner whenOpen {
        phase = Phase.Closed;
        emit ElectionClosedEvent(totalVotes);
    }

    /// @notice Returns one candidate.
    /// @param index Candidate's index.
    /// @return name Candidate's name.
    /// @return votes Votes received.
    function candidate(
        uint256 index
    ) external view returns (string memory name, uint256 votes) {
        if (index >= _candidates.length) revert UnknownCandidate(index);
        Candidate storage c = _candidates[index];
        return (c.name, c.votes);
    }

    /// @notice Number of candidates.
    /// @return The count.
    function candidateCount() external view returns (uint256) {
        return _candidates.length;
    }

    /// @notice The first candidate with the most votes; ties go to the lower
    ///         index.
    /// @return index Winner's index.
    /// @return name Winner's name.
    function winner() external view returns (uint256 index, string memory name) {
        if (phase != Phase.Closed) revert ElectionOpen();
        uint256 n = _candidates.length;
        if (n == 0) revert NoCandidates();
        for (uint256 i = 1; i < n; ++i) {
            if (_candidates[i].votes > _candidates[index].votes) index = i;
        }
        name = _candidates[index].name;
    }
}
