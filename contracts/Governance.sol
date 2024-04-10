// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Governance is Ownable {
    // Proposal
    struct Proposal {
        uint256 id; // Nuevo campo para el ID
        string title; 
        string description;
        address author; // Nueva dirección del autor de la propuesta
        uint256 createdAt; // Nueva fecha de creación de la propuesta
        uint256 expiresAt;
        string category;
        string[] attachments;
        uint256 votesInFavor;
        uint256 votesAgainst;
        bool executed;
        ProposalStatus status; // New field to track proposal status
    }

    // Mapping of proposals
    mapping(uint256 => Proposal) public proposals;
    uint256 public numProposals;

    // Balances and votes of users
    mapping(address => uint256) public balances;
    mapping(address => uint256) public votes;

    // Treasury address
    address public treasury;

    // --- Events ---
    event ProposalCreated(uint256 indexed proposalId, address indexed author, string title);
    event ProposalCanceled(uint256 indexed proposalId, address indexed author);
    event ProposalStatusChanged(uint256 indexed proposalId, ProposalStatus status);
    event ProposalVoted(uint256 indexed proposalId, address indexed voter, bool vote, uint256 numVotes);
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor, UpdateType updateType, uint256 newValue);
    event ParameterUpdated(UpdateType updateType, uint256 newValue);
    

    // Proposal status
    enum ProposalStatus { Pending, Approved, Rejected, Executed }

    

    // --- Enum for update types ---
    enum UpdateType {NONE, VOTES_PER_MATIC, WITHDRAWAL_COMMISSION, MIN_QUORUM, VOTE_THRESHOLD, PROPOSAL_EXPIRATION_TIME }

    // --- Variables to store the new values of the constants ---
    uint256 private _votesPerMatic;
    uint256 private _withdrawalCommission;
    uint256 private _minQuorum;
    uint256 private _voteThreshold;
    uint256 private _proposalExpirationTime; // New parameter

    // --- Constructor to initialize the variables ---
    constructor(address _treasury) {
        _votesPerMatic = 2;
        _withdrawalCommission = 6;
        _minQuorum = 500;
        _voteThreshold = 60;
        _proposalExpirationTime = 7 days; // 1 week expiration time
        treasury = _treasury;
    }

    // Deposit MATIC to get votes
    function deposit() public payable {
        require(msg.value > 0, "You must deposit an amount greater than zero");
        balances[msg.sender] += msg.value;
        votes[msg.sender] += msg.value * _votesPerMatic;
    }

    // Withdraw Matic and lose votes
    function withdraw(uint256 _amount) public {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        uint256 commission = _amount * _withdrawalCommission / 100;
        uint256 netAmount = _amount - commission;

        balances[msg.sender] -= _amount;
        votes[msg.sender] = balances[msg.sender] * _votesPerMatic; // Actualizar votos según el saldo restante

        payable(treasury).transfer(commission); // Send commission to treasury
        payable(msg.sender).transfer(netAmount);
        // The commission remains in the contract
    }


    // Voting
    function vote(uint256 _proposalId, bool _vote, uint256 _numVotes) public {
        require(votes[msg.sender] >= _numVotes, "Insufficient votes");
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp <= proposal.expiresAt, "Proposal has expired");

        require(_numVotes > 0, "Number of votes must be greater than zero");

        if (_vote) {
            proposal.votesInFavor += _numVotes;
        } else {
            proposal.votesAgainst += _numVotes;
        }

        votes[msg.sender] -= _numVotes; // Resta los votos usados
        
        // Verificar cambio de estado
        checkProposalStatus(_proposalId);
        
        emit ProposalVoted(_proposalId, msg.sender, _vote, _numVotes);
    }

    function updateVote(uint256 _proposalId, bool _vote, uint256 _numVotes) public {
        require(votes[msg.sender] >= _numVotes, "Insufficient votes");
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp <= proposal.expiresAt, "Proposal has expired");

        // Restar los votos anteriores
        if (proposal.votesInFavor > 0 && proposal.votesAgainst > 0) {
            if (proposal.votesInFavor >= _numVotes) {
                proposal.votesInFavor -= _numVotes;
            } else {
                proposal.votesAgainst -= (_numVotes - proposal.votesInFavor);
                proposal.votesInFavor = 0;
            }
        }

        // Agregar los nuevos votos
        if (_vote) {
            proposal.votesInFavor += _numVotes;
        } else {
            proposal.votesAgainst += _numVotes;
        }

        // Verificar cambio de estado
        checkProposalStatus(_proposalId);
        
        emit ProposalVoted(_proposalId, msg.sender, _vote, _numVotes);
    }



    // Submit proposal (anyone can submit)
    function submitProposal(
        string memory _title,
        string memory _description,
        string memory _category,
        string[] memory _attachments
    ) public {
        require(votes[msg.sender] > 0, "You must have available votes to submit a proposal");

        uint256 proposalId = numProposals; // Assign numProposals as ID 

        proposals[proposalId] = Proposal(
            proposalId, // Assign the ID to the structure
            _title,
            _description,
            msg.sender, // Assign the sender's address as the author
            block.timestamp, // Save the creation date of the proposal
            block.timestamp + _proposalExpirationTime,
            _category,
            _attachments,
            0,
            0,
            false,
            ProposalStatus.Pending 
        );

        numProposals++; // Increment numProposals for the next ID

        emit ProposalCreated(proposalId, msg.sender, _title); // Emit the event with the ID
    }

    // Cancel proposal (only the author can cancel)
    function cancelProposal(uint256 _proposalId) public {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.author == msg.sender, "Only the author can cancel the proposal");
        require(!proposal.executed, "Proposal has already been executed");

        proposal.status = ProposalStatus.Rejected; // Update proposal status to Rejected
        proposals[_proposalId].executed = true;

        emit ProposalCanceled(_proposalId, msg.sender);
        emit ProposalStatusChanged(_proposalId, ProposalStatus.Rejected);
    }

    // List all proposals
    function listProposals() public view returns (Proposal[] memory) {
        Proposal[] memory allProposals = new Proposal[](numProposals);
        for (uint256 i = 0; i < numProposals; i++) {
            allProposals[i] = proposals[i];
        }
        return allProposals;
    }

    // Execute proposal (only owner can execute)
    function executeProposal(uint256 _proposalId, UpdateType _updateType, uint256 _newValue) public onlyOwner {
    Proposal storage proposal = proposals[_proposalId];
    require(!proposal.executed, "Proposal has already been executed");
    require(block.timestamp <= proposal.expiresAt, "Proposal has expired");

    // Verificar cambio de estado
    checkProposalStatus(_proposalId);

    // Check quorum and vote threshold
    uint256 totalVotes = proposal.votesInFavor + proposal.votesAgainst;
    require(totalVotes >= _minQuorum, "Not enough votes to reach quorum.");
    require(proposal.votesInFavor >= totalVotes * _voteThreshold / 100, "Not enough votes in favor.");

    // Update the proposal in storage
    proposal.executed = true;
    proposal.status = ProposalStatus.Executed; // Update proposal status to Executed

    // Delegatecall to update the corresponding constant if update type and new value are provided
    if (_updateType != UpdateType.NONE) { // Verificar si se proporciona un tipo de actualización válido
        if (_updateType == UpdateType.VOTES_PER_MATIC) {
            updateVotesPerMatic(_newValue);
        } else if (_updateType == UpdateType.WITHDRAWAL_COMMISSION) {
            updateWithdrawalCommission(_newValue);
        } else if (_updateType == UpdateType.MIN_QUORUM) {
            updateMinQuorum(_newValue);
        } else if (_updateType == UpdateType.VOTE_THRESHOLD) {
            updateVoteThreshold(_newValue);
        } else if (_updateType == UpdateType.PROPOSAL_EXPIRATION_TIME) {
            updateProposalExpirationTime(_newValue);
        }
    }

    emit ProposalExecuted(_proposalId, msg.sender, _updateType, _newValue);
    emit ProposalStatusChanged(_proposalId, ProposalStatus.Executed);
    }
    // --- Función para determinar si una propuesta ha sido aprobada o rechazada ---
        function checkProposalStatus(uint256 _proposalId) internal {
            Proposal storage proposal = proposals[_proposalId];

            // Check if the proposal has expired
            if (block.timestamp > proposal.expiresAt) {
                proposal.status = ProposalStatus.Rejected;
                emit ProposalStatusChanged(_proposalId, proposal.status);
                return;
            }

            uint256 totalVotes = proposal.votesInFavor + proposal.votesAgainst;
            uint256 favorPercentage = proposal.votesInFavor * 100 / totalVotes;
            if (totalVotes >= _minQuorum && favorPercentage >= _voteThreshold) {
                proposal.status = ProposalStatus.Approved;
            } else if (totalVotes < _minQuorum) { // Check if quorum is not met
                proposal.status = ProposalStatus.Pending;
            } else {
                proposal.status = ProposalStatus.Rejected;
            }

            emit ProposalStatusChanged(_proposalId, proposal.status);
        }


    // --- Internal update functions ---
    function updateVotesPerMatic(uint256 _newValue) internal {
        require(address(this) != msg.sender, "Can only be called via delegatecall");
        _votesPerMatic = _newValue;
    }

    function updateWithdrawalCommission(uint256 _newValue) internal {
        require(address(this) != msg.sender, "Can only be called via delegatecall");
        _withdrawalCommission = _newValue;
    }

    function updateMinQuorum(uint256 _newValue) internal {
        require(address(this) != msg.sender, "Can only be called via delegatecall");
        _minQuorum = _newValue;
    }

    function updateVoteThreshold(uint256 _newValue) internal {
        require(address(this) != msg.sender, "Can only be called via delegatecall");
        _voteThreshold = _newValue;
    }

    function updateProposalExpirationTime(uint256 _newValue) internal {
        require(address(this) != msg.sender, "Can only be called via delegatecall");
        _proposalExpirationTime = _newValue;
    }

    // --- Owner functions ---
    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }
}
