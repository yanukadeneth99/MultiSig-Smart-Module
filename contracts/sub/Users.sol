// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Users
/// @author Yashura
/// @dev Handles the users expected to be in a vault
contract Users {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T A T E @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Vault ID => (Index => User Object)
    mapping(uint256 => mapping(uint256 => UserObj)) private _users;

    // Vault ID => User Count
    mapping(uint256 => uint256) public userCount;
    struct UserObj {
        // Address of the person in the vault
        address person;
        // Type of person (Inactive, User, Owner)
        Position position;
    }

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
    error NullAddress();

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

    // Triggered when an interaction is created when it already exists
    error UserAlreadyExists();

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ M O D I F I E R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Check whether address passed in a zero address
    modifier notZeroAddress(address _in) {
        if (_in == address(0)) revert NullAddress();
        _;
    }

    // Checks whether the caller is an owner
    /// @param index The Vault ID
    modifier owner(uint256 index) {
        if (!isOwner(index, msg.sender)) revert Unauthorized();
        _;
    }

    // Makes sure the index passed is valid
    modifier validIndex(uint256 index) {
        uint256 uCount = userCount[index];
        if (uCount > 0) uCount--;
        if (index > uCount) revert UserNotFound();
        _;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Self add yourself to be the owner
    /// @notice Used at the start
    /// @param index The Vault ID
    function selfAdd(uint256 index) internal {
        _users[index][userCount[index]].person = msg.sender;
        _users[index][userCount[index]++].position = Position.OWNER;
    }

    /// @dev Add in one user
    /// @param index The Vault ID
    /// @param user The user address you want to add
    function addUser(
        uint256 index,
        address user
    ) internal validIndex(index) notZeroAddress(user) owner(index) {
        _userCannotExist(index, user);
        _users[index][userCount[index]].person = user;
        _users[index][userCount[index]++].position = Position.USER;

        _oneOwnerExists(index);
    }

    /// @dev Add in Multiple users
    /// @param index Start of the Vault ID
    /// @param users The Array of users of you want to add
    function addUsers(
        uint256 index,
        address[] calldata users
    ) internal owner(index) {
        for (uint256 i; i < users.length; i++) {
            // Zero Address Check
            if (users[i] == address(0)) revert NullAddress();

            _userCannotExist(index, users[i]);

            // Add the users in
            _users[index][userCount[index]].person = users[i];
            _users[index][userCount[index]++].position = Position.USER;

            _oneOwnerExists(index);
        }
    }

    /// @dev Make an added User an Owner
    /// @param index Vault ID
    /// @param user The user you want to make an Owner
    function makeOwner(
        uint256 index,
        address user
    ) internal validIndex(index) notZeroAddress(user) owner(index) {
        for (uint256 i; i < userCount[index]; i++) {
            // Call to memory
            UserObj memory u = _users[index][i];

            if (u.person == user) {
                // Can not already be owner
                if (u.position == Position.OWNER) revert AlreadyOwner();

                // Can not be inactive
                if (u.position == Position.INACTIVE)
                    revert AlreadyInactiveUser();

                _users[index][i].position = Position.OWNER;

                _oneOwnerExists(index);
                return;
            }
        }

        revert UserNotFound();
    }

    /// @dev Make an added Owner a User
    /// @param index Vault ID
    /// @param user The Owner you want to make a User
    function makeUser(
        uint256 index,
        address user
    ) internal validIndex(index) notZeroAddress(user) owner(index) {
        for (uint256 i; i < userCount[index]; i++) {
            UserObj memory u = _users[index][i];
            if (u.person == user) {
                // Can not already be owner
                if (u.position == Position.USER) revert AlreadyUser();

                // Can not be inactive
                if (u.position == Position.INACTIVE)
                    revert AlreadyInactiveUser();

                _users[index][i].position = Position.USER;

                _oneOwnerExists(index);
                return;
            }
        }

        revert UserNotFound();
    }

    /// @dev Enable a User
    /// @param index Vault ID
    /// @param user The User address to enable
    function enableUser(
        uint256 index,
        address user
    ) internal validIndex(index) notZeroAddress(user) owner(index) {
        for (uint256 i; i < userCount[index]; i++) {
            UserObj memory u = _users[index][i];
            if (u.person == user) {
                // Should not already be enabled
                if (u.position == Position.OWNER || u.position == Position.USER)
                    revert AlreadyActiveUser();

                _users[index][i].position = Position.USER;

                _oneOwnerExists(index);
                return;
            }
        }

        // No user found, revert
        revert UserNotFound();
    }

    /// @dev Disable a User
    /// @param index Vault ID
    /// @param user The User address to disable
    function disableUser(
        uint256 index,
        address user
    ) internal validIndex(index) notZeroAddress(user) owner(index) {
        for (uint256 i; i < userCount[index]; i++) {
            UserObj memory u = _users[index][i];
            if (u.person == user) {
                // Should not already be disabled
                if (u.position == Position.INACTIVE)
                    revert AlreadyInactiveUser();

                _users[index][i].position = Position.INACTIVE;

                _oneOwnerExists(index);
                return;
            }
        }

        // No user found, revert
        revert UserNotFound();
    }

    /// @dev Checks whether the pass address is a Owner
    /// @param index Vault ID
    /// @param user The User address to check
    /// @return Returns true if the user is an Owner, false if not
    function isOwner(
        uint256 index,
        address user
    ) internal view notZeroAddress(user) returns (bool) {
        for (uint256 i; i < userCount[index]; i++) {
            if (_users[index][i].person == user) {
                if (_users[index][i].position == Position.OWNER) {
                    return true;
                } else {
                    return false;
                }
            }
        }

        return false;
    }

    /// @dev Checks if there is atleast one Owner
    /// @param index The Vault ID
    function _oneOwnerExists(uint256 index) private view {
        uint256 count;
        for (uint256 i; i < userCount[index]; i++) {
            if (_users[index][i].position == Position.OWNER) count++;
        }

        if (count == 0) revert NoAdmins();
    }

    /// @dev Checks if the user is acitve
    function isCallerActive(
        uint256 index,
        address user
    ) internal view validIndex(index) notZeroAddress(user) returns (bool) {
        for (uint256 i; i < userCount[index]; i++) {
            if (_users[index][i].person == user) {
                if (_users[index][i].position != Position.INACTIVE) {
                    return true;
                } else {
                    return false;
                }
            }
        }

        return false;
    }

    // Makes sure the user cannot exist
    function _userCannotExist(uint256 index, address user) private view {
        for (uint256 i; i < userCount[index]; i++) {
            if (_users[index][i].person == user) revert UserAlreadyExists();
        }
    }
}
