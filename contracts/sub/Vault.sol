// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/ReentrancyGuard.sol";

/// @title Vault
/// @author Yashura
/// @dev This contract handles everything related to the vault
contract Vault is ReentrancyGuard {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T A T E @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // User -> Vault IDs.
    /// @dev Always starts with 1
    mapping(uint256 => VaultObj) private _vaults;

    // Holds the current vaults count created
    uint256 _numOfVaults;

    struct VaultObj {
        // Total votes required to pass a transaction (counted from the number of owners)
        uint256 votesReq;
        // The Wei value of ether in this vault
        uint256 money;
        // The Status of the Vault (Active, Inactive) - `uint8`
        Status status;
    }

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

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ M O D I F I E R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Check whether the vault in inactive
    modifier notInactiveVault(uint256 index) {
        // Check if the Status is Inactive and revert if so
        if (_vaults[index].status == Status.INACTIVE) revert InActiveVault();

        // All Good Continue
        _;
    }

    // Check whether the vault in active
    modifier activeVault(uint256 index) {
        // Check if the Status is Inactive and revert if so
        if (_vaults[index].status == Status.ACTIVE) revert ActiveVault();

        // All Good Continue
        _;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Set the Vote Count
    /// @param index The Vault ID
    /// @param voteCount The Vote Count
    function setVotes(
        uint256 index,
        uint256 voteCount
    ) public notInactiveVault(index) {
        _vaults[index].votesReq = voteCount;
    }

    /// @dev Increases the Number of Vaults Count
    function createVault() internal {
        _numOfVaults++;
    }

    /// @dev Enabled a disabled Vault
    /// @param index The Vault ID
    function enableVault(uint256 index) internal activeVault(index) {
        _vaults[index].status = Status.ACTIVE;
    }

    /// @dev Set the Status of the Vault as Disabled
    /// @param index The Vault ID
    function disableVault(uint256 index) internal notInactiveVault(index) {
        _vaults[index].status = Status.INACTIVE;
    }

    /// @dev Add money into this vault
    /// @param index The Vault ID
    /// @param amount The amount added in Wei into this vault
    function addMoney(uint256 index, uint256 amount) internal {
        _vaults[index].money += amount;
    }

    /// @dev Get all the vault information
    /// @param index The Vault ID
    /// @return _votesReq The votes required to pass
    /// @return _money The amount this vault holds in wei
    /// @return _status The status of the vault
    function getVault(
        uint256 index
    )
        external
        view
        returns (uint256 _votesReq, uint256 _money, Status _status)
    {
        return (
            _vaults[index].votesReq,
            _vaults[index].money,
            _vaults[index].status
        );
    }

    /// @dev Get the Next Vault ID
    /// @return The next ID - `uint256`
    function getNextVault() internal view returns (uint256) {
        return _numOfVaults + 1;
    }
}
