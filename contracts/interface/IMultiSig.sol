// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMultiSig {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E V E N T S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    ///+events

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T R U C T S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Vault Object holds all the values required to create and manage a vault
    /// @param users User Object which has the address and the position
    /// @param votes Total votes required to pass a transaction (counted from the number of owners)
    /// @param status The Status of the Vault (Active, Inactive)
    struct Vault {
        User[] users;
        uint256 votes;
        TxObj[] transactions;
        Status status;
    }

    /// @dev Transaction Object
    /// @param to The Address you want to do the transaction to
    /// @param amount The Vault passed in the transaction
    /// @param data The Data passed in the transaction
    /// @param done Whether the Transaction is executed
    /// @param votes The Total Votes that were done
    struct TxObj {
        address to;
        uint amount;
        bytes data;
        bool done;
        Vote[] votes;
    }

    /// @dev Transaction Object used to Get all transactions with their ID
    /// @param ID The index of the transaction in the `transactions` array in `Vault`
    /// @param transaction The Transaction Object
    struct AllTxObj {
        uint256 Id;
        TxObj transaction;
    }

    /// @dev User Object which holds all users
    /// @param person The Address of the User
    /// @param position Position Object which contains the user's position
    struct User {
        address person;
        Position position;
    }

    /// @dev The Vote Object which holds all votes
    /// @param person The Address of the person voting
    /// @param vote The ID of the vote (0 - None, 1 - Positive(Yes), 2 - Negative(No), 3 - Withdrawn (Neutral))
    struct Vote {
        address person;
        uint8 vote;
    }

    /// @dev Enum which holds the position of the user (0 - ADMIN, 1 - USER)
    enum Position {
        OWNER,
        USER,
        INACTIVE
    }

    /// @dev Enum which holds the status of the Vault
    enum Status {
        ACTIVE,
        INACTIVE
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E R R O R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Triggered when a function is access which the user has no permission to
    error Unauthorized();

    // Trigerred when a functionality is called on an already initialised contract
    error AlreadyInitialized();

    // Triggered when a function is being used with an Address 0
    error ZeroAddress();

    // Triggered when a functionality is requested using the same `to` and `from` address
    error SameAddress();

    // Triggered when there is no vault
    error InvalidVault();

    // Triggered when a functionality is done on an address that does not belong to any vault
    error AddressNotInAVault();

    // Triggered when a caller uses a function that only a owner can do
    error NotAnOwner();

    // Triggered when an interaction on an address is requested but the address does not exist
    error UserNotFound();

    // Trigered when an interaction is called on a vault that has not enough members
    error NotEnoughUsers();

    // Triggered when you want to do an interaction to yourself that is not allowed
    error CannotRemoveSelf();

    // Triggered when you set Votes neccessary to a number higher than the owner count
    /// @param owners The number of owners that exist in the vault
    error VoteCountTooHigh(uint256 owners);

    // Triggered when an operation is requested on a Vault that is inactive
    error InActiveVault();

    // Triggered when a vault is called to active but it is already active
    error AlreadyActiveVault();

    // Triggered when a vault is called to disable but it is already disable
    error AlreadyInactiveVault();

    // Triggered when an edit to a transaction is called on a Transaction which already has votes
    error VotedTransaction();
}
