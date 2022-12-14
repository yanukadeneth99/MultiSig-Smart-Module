// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/ReentrancyGuard.sol";

/// @title Vault
/// @author Yashura
/// @dev This contract handles everything related to the vault
contract Vault is ReentrancyGuard {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T A T E @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // The total number of users in this Vault
    uint256 public userCount;

    // The number of transactions in this Vault
    uint256 public transactionCount;

    // Total votes required to pass a transaction (counted from the number of owners)
    uint256 public votesReq;

    // The Wei value of ether in this vault
    uint256 public money;

    // The Status of the Vault (Active, Inactive) - `uint8`
    Status public status;

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E N U M S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Enum which holds the status of the Vault
    enum Status {
        ACTIVE,
        INACTIVE
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ E R R O R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Triggered when no money is passed
    error NoEtherPassed();

    // Triggered when an operation is requested on a Vault that is inactive
    error InActiveVault();

    // Triggered when an operation is requested on a Vault that is active
    error ActiveVault();

    // Triggered when there is no vault
    error InvalidVault();

    // Triggered when an interaction is done with not enough Ether
    error NotEnoughEther();

    // Triggered when a function is being used with an Address 0
    error ZeroAddress();

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ M O D I F I E R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Check whether address passed in a zero address
    modifier notZeroAddress(address _in) {
        if (_in == address(0)) revert ZeroAddress();
        _;
    }

    // Check whether the vault in inactive
    modifier notInactiveVault() {
        // Check if the Status is Inactive and revert if so
        if (status == Status.INACTIVE) revert InActiveVault();

        // All Good Continue
        _;
    }

    // Check whether the vault in active
    modifier activeVault() {
        // Check if the Status is Inactive and revert if so
        if (status == Status.ACTIVE) revert ActiveVault();

        // All Good Continue
        _;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Added Users into this Vault
    /// @param amount The Amount of users added into this vault.
    function addUsers(uint256 amount) internal notInactiveVault {
        userCount += amount;
    }

    /// @dev Add one Transaction into the Vault
    function addTransaction() internal notInactiveVault {
        transactionCount++;
    }

    /// @dev Set the Vote Count
    /// @param voteCount The Vote Count
    function setVotes(uint256 voteCount) internal notInactiveVault {
        votesReq = voteCount;
    }

    /// @dev Enabled a disabled Vault
    function enableVault() internal activeVault {
        status = Status.ACTIVE;
    }

    /// @dev Set the Status of the Vault as Disabled
    function disableVault() internal notInactiveVault {
        status = Status.INACTIVE;
    }

    /// @dev Add money into this vault
    /// @param amount The amount added in Wei into this vault
    function addMoney(uint256 amount) internal {
        money += amount;
    }

    /// @dev Get all the vault information
    /// @return _userCount User Count
    /// @return _transactionCount The Transaction Count
    /// @return _votesReq The votes required to pass
    /// @return _money The amount this vault holds in wei
    /// @return _status The status of the vault
    function getVault()
        external
        view
        returns (
            uint256 _userCount,
            uint256 _transactionCount,
            uint256 _votesReq,
            uint256 _money,
            Status _status
        )
    {
        return (userCount, transactionCount, votesReq, money, status);
    }
}
