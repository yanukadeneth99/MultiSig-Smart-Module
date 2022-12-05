// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMultiSig {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E V E N T S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    ///+events

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T R U C T S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Vault Object holds all the values required to create and manage a vault
    /// @param users User Object which has the address and the position
    /// @param votes Total votes required to pass a transaction (counted from the number of owners)
    struct Vault {
        User[] users;
        uint256 votes;
    }

    /// @dev Transaction Object
    /// @param to The Address you want to do the transaction to
    /// @param amount The Vault passed in the transaction
    /// @param data The Data passed in the transaction
    /// @param done Whether the Transaction is executed
    /// @param numOfVotes The number of Votes that were casted
    /// @param votes Mapping of address to the vote (0 - None, 1 - Positive(Yes), 2 - Negative(No), 3 - Withdrawn (Neutral))
    struct TxObj {
        address to;
        uint amount;
        bytes data;
        bool done;
        uint numOfVotes;
        mapping(address => uint8) votes;
    }

    /// @dev User Object which holds all users
    /// @param person The Address of the User
    /// @param position Position Object which contains the user's position
    struct User {
        address person;
        Position position;
    }

    /// @dev Enum which holds the position of the user (0 - ADMIN, 1 - USER)
    enum Position {
        OWNER,
        USER
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
}
