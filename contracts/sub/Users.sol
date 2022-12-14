// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Get Owner Position
// Is caller active

/// @title Users
/// @author Yashura
/// @dev Handles the users expected to be in a vault
contract Users {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T A T E @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // ID => User Address
    mapping(uint256 => address) public person;

    // ID => User Position (Inactive, User or Owner)
    mapping(uint256 => Position) public position;

    // The total users present
    uint256 userCount;

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E N U M S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Enum which holds the position of the user
    enum Position {
        INACTIVE,
        USER,
        OWNER
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E R R O R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Triggered when a function is access which the user has no permission to
    error Unauthorized();

    // Triggered when a function is being used with an Address 0
    error ZeroAddress();

    // Triggered when an interaction on an address is requested but the address does not exist
    error UserNotFound();

    // Triggered when an interaction is called on a person who is already an owner
    error AlreadyOwner();

    // Triggered when an interaction is called on a person who is already an user
    error AlreadyUser();

    // Triggered when an interaction is called on a person who is already inactive
    error AlreadyInactiveUser();

    // Triggered when an interaction is called on a person who is already active
    error AlreadyActiveUser();

    // Triggered when an interaction makes you remove all admins from vault
    error NoAdmins();

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ M O D I F I E R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Check whether address passed in a zero address
    modifier notZeroAddress(address _in) {
        if (_in == address(0)) revert ZeroAddress();
        _;
    }

    // Checks whether the caller is an owner
    modifier owner() {
        if (!isOwner(msg.sender)) revert Unauthorized();
        _;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Self add yourself to be the owner
    /// @notice Used at the start
    function selfAdd() internal {
        person[userCount] = msg.sender;
        position[userCount++] = Position.OWNER;
    }

    /// @dev Add in one user
    /// @param user The user address you want to add
    function addUser(address user) internal notZeroAddress(user) owner {
        person[userCount] = user;
        position[userCount++] = Position.USER;

        _oneOwnerExists();
    }

    /// @dev Add in Multiple users
    /// @param users The Array of users of you want to add
    function addUsers(address[] calldata users) internal owner {
        for (uint256 i; i < users.length; i++) {
            // Zero Address Check
            if (users[i] == address(0)) revert ZeroAddress();

            // Add the users in
            person[userCount] = users[i];
            position[userCount++] = Position.USER;

            _oneOwnerExists();
        }
    }

    /// @dev Make an added User an Owner
    /// @param user The user you want to make an Owner
    function makeOwner(address user) internal notZeroAddress(user) owner {
        for (uint256 i; i < userCount; i++) {
            if (person[i] == user) {
                // Can not already be owner
                if (position[i] == Position.OWNER) revert AlreadyOwner();

                // Can not be inactive
                if (position[i] == Position.INACTIVE)
                    revert AlreadyInactiveUser();

                position[i] = Position.OWNER;

                _oneOwnerExists();
                return;
            }
        }

        revert UserNotFound();
    }

    /// @dev Make an added Owner a User
    /// @param user The Owner you want to make a User
    function makeUser(address user) internal notZeroAddress(user) owner {
        for (uint256 i; i < userCount; i++) {
            if (person[i] == user) {
                // Can not already be owner
                if (position[i] == Position.USER) revert AlreadyUser();

                // Can not be inactive
                if (position[i] == Position.INACTIVE)
                    revert AlreadyInactiveUser();

                position[i] = Position.USER;

                _oneOwnerExists();
                return;
            }
        }

        revert UserNotFound();
    }

    /// @dev Enable a User
    /// @param user The User address to enable
    function enableUser(address user) internal notZeroAddress(user) owner {
        for (uint256 i; i < userCount; i++) {
            if (person[i] == user) {
                // Should not already be enabled
                if (
                    position[i] == Position.OWNER ||
                    position[i] == Position.USER
                ) revert AlreadyActiveUser();

                position[i] = Position.USER;

                _oneOwnerExists();
                return;
            }
        }

        // No user found, revert
        revert UserNotFound();
    }

    /// @dev Disable a User
    /// @param user The User address to disable
    function disableUser(address user) internal notZeroAddress(user) owner {
        for (uint256 i; i < userCount; i++) {
            if (person[i] == user) {
                // Should not already be disabled
                if (position[i] == Position.INACTIVE)
                    revert AlreadyInactiveUser();

                position[i] = Position.INACTIVE;

                _oneOwnerExists();
                return;
            }
        }

        // No user found, revert
        revert UserNotFound();
    }

    /// @dev Checks whether the pass address is a Owner
    /// @param user The User address to check
    /// @return Returns true if the user is an Owner, false if not
    function isOwner(
        address user
    ) internal view notZeroAddress(user) returns (bool) {
        for (uint256 i; i < userCount; i++) {
            if (person[i] == user) return true;
        }

        return false;
    }

    /// @dev Checks if there is atleast one Owner
    function _oneOwnerExists() private view {
        uint256 count;
        for (uint256 i; i < userCount; i++) {
            if (position[i] == Position.OWNER) count++;
        }

        if (count == 0) revert NoAdmins();
    }
}
