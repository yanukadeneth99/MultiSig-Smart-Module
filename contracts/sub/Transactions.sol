// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Transactions
/// @author Yashura
/// @dev Manage the Transactions related to the vault
contract Transactions {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T A T E @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Vault ID => (ID => Transaction Object)
    mapping(uint256 => mapping(uint256 => TxObj)) private _transactions;

    struct TxObj {
        address to;
        bool done;
        uint256 amount;
        bytes data;
    }

    // Vault ID => (Transaction ID => (ID => Vote Object))
    mapping(uint256 => mapping(uint256 => mapping(uint256 => VoteObj)))
        private _votes;

    struct VoteObj {
        address person;
        VoteSelection vote;
    }

    // Vault ID =>  Total Transaction Count
    mapping(uint256 => uint256) public transactionCount;

    // Vault ID => (Transaction ID => Vote Count)
    mapping(uint256 => mapping(uint256 => uint256)) public voteCount;

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E N U M S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Enum which holds which vote is selected
    enum VoteSelection {
        NEUTRAL,
        POSITIVE,
        NEGATIVE
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E R R O R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Triggered when an invalid transaction ID is called
    error InvalidTransactionID();

    // Triggered when a function is being used with an Address 0
    error ZeroAddress();

    // Triggered when there is an issue with a transaction
    error TransactionIssue();

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ M O D I F I E R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Check whether the index passed is in bounds
    /// @param index The Vault ID
    /// @param txindex The Transaction ID
    modifier indexInBounds(uint256 index, uint256 txindex) {
        // Checking sent index
        uint256 count = transactionCount[index];
        if (count == 0) revert InvalidTransactionID();

        if (count > 0) count--;
        if (txindex > count) revert InvalidTransactionID();

        _;
    }

    // Check whether address passed in a zero address
    modifier nonZeroAddress(address _in) {
        if (_in == address(0)) revert ZeroAddress();
        _;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Create a Transaction with Data
    /// @param index The Vault ID
    /// @param _to The Address to transfer
    /// @param _amount The amount in Wei
    /// @param _data The data of the function
    function createTransaction(
        uint256 index,
        address _to,
        uint256 _amount,
        bytes memory _data
    ) internal nonZeroAddress(_to) {
        _transactions[index][transactionCount[index]].to = _to;
        _transactions[index][transactionCount[index]].data = _data;
        _transactions[index][transactionCount[index]++].amount = _amount;
    }

    /// @dev Edit an existing transaction
    /// @notice Editing can only be done if there are no votes to the transaction to prevent exploits
    /// @param index The Vault ID
    /// @param txindex The Transaction ID
    /// @param _to The new Address to send
    /// @param _amount The New Amount in Wei
    /// @param _data The New Data
    function editTransaction(
        uint256 index,
        uint256 txindex,
        address _to,
        uint256 _amount,
        bytes memory _data
    ) internal nonZeroAddress(_to) indexInBounds(index, txindex) {
        _transactions[index][txindex].to = _to;
        _transactions[index][txindex].amount = _amount;
        _transactions[index][txindex].data = _data;
    }

    /// @dev Perform a Vote, Owners only
    /// @param index The Vault ID
    /// @param index The Transaction ID
    /// @param decision The Decision ID (0 - None, 1 - Positive(Yes), 2 - Negative(No), 3 - Withdrawn (Neutral))
    function castVote(
        uint256 index,
        uint256 txindex,
        VoteSelection decision
    ) internal indexInBounds(index, txindex) {
        VoteObj storage v = _votes[index][txindex][voteCount[index][txindex]++];
        v.person = msg.sender;
        v.vote = decision;
    }

    /// @dev Finish a transaction
    /// @param index Vault ID
    /// @param txindex Transaction ID
    /// @param votesReq The Votes required to pass
    function completeTransaction(
        uint256 index,
        uint256 txindex,
        uint256 votesReq
    ) internal indexInBounds(index, index) {
        if (checkVotes(index, txindex, votesReq)) {
            _transactions[index][txindex].done = true;
        } else {
            revert TransactionIssue();
        }
    }

    /// @dev Checking the Positive Votes against the necessary votes
    /// @notice True - Votes are right
    /// @param index The Vault ID
    /// @param txindex Transaction ID
    /// @param votesReq Votes required to be positive
    function checkVotes(
        uint256 index,
        uint256 txindex,
        uint256 votesReq
    ) private view returns (bool) {
        uint256 posCount = getPositiveVoteCount(index, txindex);

        if (posCount >= votesReq) return true;

        return false;
    }

    /// @dev Returns Information about a Transaction
    /// @notice The caller must have a vault
    /// @param index The Vault ID
    /// @param txindex Transaction ID
    /// @return _to The Address to send the transaction
    /// @return _amount The Amount to transact
    /// @return _data The Data passed
    /// @return _done Whether the transaction is executed (true - executed)
    /// @return votes Total votes count
    function _getTransaction(
        uint256 index,
        uint256 txindex
    )
        internal
        view
        indexInBounds(index, txindex)
        returns (
            address _to,
            uint256 _amount,
            bytes memory _data,
            bool _done,
            uint256 votes
        )
    {
        TxObj memory transaction = _transactions[index][txindex];
        _to = transaction.to;
        _amount = transaction.amount;
        _data = transaction.data;
        _done = transaction.done;
        votes = voteCount[index][txindex];
    }

    /// @dev Returns the Positive Count of Votes of a Transaction
    /// @param index Transaction ID
    /// @return The Positive Vote Count
    function getPositiveVoteCount(
        uint256 index,
        uint256 txindex
    ) internal view indexInBounds(index, txindex) returns (uint256) {
        uint256 count;
        for (uint256 i; i < voteCount[index][txindex]; i++) {
            if (_votes[index][txindex][i].vote == VoteSelection.POSITIVE)
                count++;
        }

        return count;
    }
}
