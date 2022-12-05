// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMultiSig {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E V E N T S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    ///+events

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T R U C T S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Vault Object holds all the values required to create and manage a vault
    /// @dev Owners and Users will have specific permissions
    /// @dev Votes are the total votes required to pass a transaction (counted from the number of owners)
    struct Vault {
        User[] users;
        uint256 votes;
    }

    /// @dev User Object which holds all users
    /// @dev 0 - None, 1 - Admin, 2 - User

    struct User {
        address person;
        Position position;
    }

    /// @dev Enum which holds the position of the user
    enum Position {
        ADMIN,
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
