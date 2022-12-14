// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Transactions
/// @author Yashura
/// @dev Manage the Transactions related to the vault
contract Transactions {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T A T E @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // ID => Transaction Address
    mapping(uint256 => address) public to;

    // ID => Transaction Value
    mapping(uint256 => uint256) public amount;

    // ID => Transaction Data
    mapping(uint256 => bytes) public data;

    // ID => Transaction Status
    mapping(uint256 => bool) public done;

    // Transaction ID => ID => Voted Person Address
    mapping(uint256 => mapping(uint256 => address)) public person;

    // Transaction ID => ID => Vote Type
    mapping(uint256 => mapping(uint256 => VoteSelection)) public vote;

    // Total Transaction Count
    uint256 public transactionCount;

    // Transaction ID => Vote Count
    mapping(uint256 => uint256) voteCount;

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

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ M O D I F I E R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Check whether the index passed is in bounds
    modifier indexInBounds(uint256 index) {
        // Checking sent index
        uint256 count = transactionCount;
        if (transactionCount > 0) count--;
        if (index > count || count == 0) revert InvalidTransactionID();

        _;
    }

    // Check whether address passed in a zero address
    modifier notZeroAddress(address _in) {
        if (_in == address(0)) revert ZeroAddress();
        _;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Create a Transaction with Data
    /// @param _to The Address to transfer
    /// @param _amount The amount in Wei
    /// @param _data The data of the function
    function createTransaction(
        address _to,
        uint256 _amount,
        bytes memory _data
    ) internal notZeroAddress(_to) {
        to[transactionCount] = _to;
        amount[transactionCount] = _amount;
        data[transactionCount++] = _data;
    }

    /// @dev Edit an existing transaction
    /// @notice Editing can only be done if there are no votes to the transaction to prevent exploits
    /// @param index The Transaction ID
    /// @param _to The new Address to send
    /// @param _amount The New Amount in Wei
    /// @param _data The New Data
    function editTransaction(
        uint256 index,
        address _to,
        uint256 _amount,
        bytes memory _data
    ) internal notZeroAddress(_to) indexInBounds(index) {
        // Setting values
        to[index] = _to;
        amount[index] = _amount;
        data[index] = _data;
    }

    /// @dev Perform a Vote, Owners only
    /// @param index Transaction ID
    /// @param decision The Decision ID (0 - None, 1 - Positive(Yes), 2 - Negative(No), 3 - Withdrawn (Neutral))
    function castVote(
        uint256 index,
        VoteSelection decision
    ) internal indexInBounds(index) {
        person[index][voteCount[index]] = msg.sender;
        vote[index][voteCount[index]++] = decision;
    }

    /// @dev Finish a transaction
    /// @param index Transaction ID
    function completeTransaction(uint256 index) internal indexInBounds(index) {
        done[index] = true;
    }

    /// @dev Returns Information about a Transaction
    /// @notice The caller must have a vault
    /// @param index Transaction ID
    /// @return _to The Address to send the transaction
    /// @return _amount The Amount to transact
    /// @return _done Whether the transaction is executed (true - executed)
    /// @return _votes Total votes count
    function getTransaction(
        uint256 index
    )
        internal
        view
        indexInBounds(index)
        returns (address _to, uint256 _amount, bool _done, uint256 _votes)
    {
        _to = to[index];
        _amount = amount[index];
        _done = done[index];
        _votes = voteCount[index];
    }

    /// @dev Returns the Positive Count of Votes of a Transaction
    /// @param index Transaction ID
    function getPositiveVoteCount(
        uint256 index
    ) internal view indexInBounds(index) returns (uint256) {
        uint256 count;
        for (uint256 i; i < voteCount[index]; i++) {
            if (vote[index][i] == VoteSelection.POSITIVE) count++;
        }

        return count;
    }
}
