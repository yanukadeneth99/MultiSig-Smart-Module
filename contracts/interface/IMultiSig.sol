// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// TODO : Add functions

interface IMultiSig {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E V E N T S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Emitted when a new vault is created
    event VaultCreated(
        address indexed owner,
        uint256 vaultId,
        uint256 numOfUsers
    );

    // Emitted when creating a transaction
    event TransactionCreated(
        address indexed owner,
        uint256 indexed vaultId,
        uint256 indexed transactionId
    );

    // Emitted when new users are added into a vault
    event NewUsersAdded(
        address indexed owner,
        uint256 indexed vaultId,
        uint256 numOfUsers
    );

    // Emitted when you make a user an owner
    event MadeOwner(
        address indexed owner,
        uint256 indexed vaultId,
        address newOwner
    );

    // Emitted when you change the vote count of a vault
    event ChangeVoteCount(
        address indexed owner,
        uint256 indexed vaultId,
        uint256 voteCount
    );

    // Emitted when a transaction is edited
    event TransactionEdited(
        address indexed owner,
        uint256 indexed vaultId,
        uint256 indexed transactionId
    );

    // Emitted when a Transaction is completed
    event TransactionComplete(
        address indexed owner,
        uint256 indexed vaultId,
        uint256 indexed transactionId,
        uint256 amount
    );

    // Emitted when a owner casts a vote
    event CastVote(
        address indexed owner,
        uint256 indexed vaultId,
        uint256 indexed transactionId,
        bool vote
    );

    // Emitted when a vote is changed
    event ChangeVote(
        address indexed owner,
        uint256 indexed vaultId,
        uint256 indexed transactionId,
        bool prevVote,
        bool newVote
    );

    // Emitted when a vault is enabled
    event EnableVault(address indexed owner, uint256 indexed vaultId);

    // Emitted when a vault is disabled
    event DisableVault(address indexed owner, uint256 indexed vaultId);

    // Emitted when a user is enabled
    event EnableUser(
        address indexed owner,
        uint256 indexed vaultId,
        address user
    );

    // Emitted when a user is disabled
    event DisableUser(
        address indexed owner,
        uint256 indexed vaultId,
        address user
    );

    // Emitted when an amount is sent to the contract
    event Deposit(
        address indexed sender,
        uint256 indexed vaultId,
        uint256 amount
    );

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E R R O R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // // Triggered when a function is access which the user has no permission to
    // error Unauthorized();

    // Trigerred when a functionality is called on an already initialised contract
    error AlreadyInitialized();

    // // Triggered when a function is being used with an Address 0
    // error ZeroAddress();

    // // Triggered when a functionality is requested using the same `to` and `from` address
    // error SameAddress();

    // // Triggered when there is no vault
    // error InvalidVault();

    // Triggered when a functionality is done on an address that does not belong to any vault
    error AddressNotInAVault();

    // // Triggered when a caller uses a function that only a owner can do
    // error NotAnOwner();

    // // Triggered when an interaction on an address is requested but the address does not exist
    // error UserNotFound();

    // // Trigered when an interaction is called on a vault that has not enough members
    // error NotEnoughUsers();

    // // Triggered when you want to do an interaction to yourself that is not allowed
    // error CannotRemoveSelf();

    // // Triggered when you want to add yourself into a vault which you created
    // error CannotAddSelf();

    // // Triggered when you set Votes neccessary to a number higher than the owner count
    // /// @param owners The number of owners that exist in the vault
    // error VoteCountTooHigh(uint256 owners);

    // // Triggered when an operation is requested on a Vault that is inactive
    // error InActiveVault();

    // // Triggered when a vault is called to active but it is already active
    // error AlreadyActiveVault();

    // // Triggered when a vault is called to disable but it is already disable
    // error AlreadyInactiveVault();

    // // Triggered when an edit to a transaction is called on a Transaction which already has votes
    // error VotedTransaction();

    // // Triggered when you try to vote again, with the same voting decision
    // error SameVote();

    // // Triggered when someone requests a do proceed with a transaction that does not exist
    // error NullTransaction();

    // // Triggered when a user is called to enable but it is already enabled
    // error AlreadyEnabledUser();

    // // Triggered when a user is called to disable but it is already disable
    // error AlreadyDisabledUser();

    // // Triggered when an invalid transaction ID is called
    // error InvalidTransactionID();

    // // Triggered when no money is passed
    // error NoEtherPassed();

    // // Triggered when an interaction is done with not enough Ether
    // error NotEnoughEther();

    // // Triggered when trying to add in a user that already exists
    // error UserExists();
}
