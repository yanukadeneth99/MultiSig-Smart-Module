// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./hyperverse/IHyperverseModule.sol";
import "./hyperverse/Initializable.sol";
import "./interface/IMultiSig.sol";
import "./helpers/ReentrancyGuard.sol";

// TODO : Gas optimizations - Use mload instead of sload (Load variables into memory than storage)
// TODO : Gas optimizations - Use Remix Gas Optimizer
// TODO : Do events
// TODO : Do `delete arr[index];`
// TODO : Getters only work if the caller is an active member
// TODO : Perform Transaction Function
// TODO : Change the _INTERFACE_ID variable
// TODO : Add ERC-165 function (supports interface)
// TODO : Check non-reentrancy
// TODO : Interactions can only happen if the vault is enabled
// TODO : Setup _Vaults Getter

/// @title MultiSig Main Contract
/// @author Yashura
/// @dev This is a contract to handle Multi-Sig Vaults.
contract MultiSig is
    IMultiSig,
    IHyperverseModule,
    Initializable,
    ReentrancyGuard
{
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T A T E @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Account used to deploy contract
    address public immutable contractOwner;

    // Stores the tenant owner
    address private _tenantOwner;

    // InterfaceID for the Contract
    // Hex Value of all the functions in IMultiSig passed through XOR
    bytes4 private constant _INTERFACE_ID = 0x0342a3c8;

    // User -> Vault IDs. Always starts with 1
    mapping(address => uint256[]) private _vaultId;

    // Holds the current vaults created
    uint256 private _numOfVaults;

    // Vault ID -> Vault Object
    // Vault information can be viewed by anyone
    mapping(uint256 => Vault) public _vaults;

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ M O D I F I E R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Is the caller the Tenant Owner
    modifier isTenantOwner() {
        if (msg.sender != _tenantOwner) revert Unauthorized();
        _;
    }

    // Make sure the Tenant Owner is null, and the _tenant is not passed address 0
    modifier canInitialize(address _tenant) {
        if (_tenantOwner != address(0) || _tenant == address(0)) {
            revert AlreadyInitialized();
        }
        _;
    }

    // Check if addresses are same and not null
    modifier addressCheck(address _from, address _to) {
        if (_from == _to) {
            revert SameAddress();
        }
        if (_to == address(0) || _from == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    // Check if there is an Address 0 in an array of addresses
    modifier addressArrayCheck(address[] calldata _in) {
        for (uint i = 0; i < _in.length; i++) {
            if (_in[i] == address(0)) revert ZeroAddress();
        }
        _;
    }

    // Check if the caller has a vault
    modifier hasVault() {
        if (_vaultId[msg.sender].length == 0) revert AddressNotInAVault();
        _;
    }

    // Check if the caller is the owner of the vault
    modifier isOwnerVault(uint256 index) {
        // Check if the caller is the owner
        address _caller = msg.sender;
        Vault storage _v = _vaults[_vaultId[_caller][index]];
        bool _isOwner;
        for (uint256 i; i < _v.userCount ; i++) {
            User memory _finder = _v.users[i];
            if (_finder.person == _caller && _finder.position == Position.OWNER) {
                _isOwner = true;
                break;
            }
        }
        if (!_isOwner) revert NotAnOwner();
        _;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ C O N S T R U C T O R @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Make sure to update the information in the metadata before you deploy
    constructor(address _owner) {
        metadata = ModuleMetadata(
            "MultiSig",
            _owner,
            "0.0.1",
            block.timestamp,
            "https://github.com/yanukadeneth99/MultiSig-Smart-Module"
        );
        contractOwner = _owner;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ INITIALIZE - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Initializes the instance of a tenant for this contract and sets the state variables
    /// @param _tenant The address of the instance owner
    function initialize(
        address _tenant
    ) external initializer canInitialize(_tenant) {
        _tenantOwner = _tenant;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ CREATOR - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Creates a Vault with multiple users only
    /// @param _userAddresses All the addresses you wish to add as users
    function createVault(
        address[] calldata _userAddresses
    ) external addressArrayCheck(_userAddresses) {
        // Create empty Vault Object
        Vault storage _v = _vaults[++_numOfVaults];

        // Add all the people into the object
        for (uint256 i; i < _userAddresses.length; i++) {
            _v.users[i] = (User(_userAddresses[i], Position.USER));
            _v.userCount++;
            _vaultId[_userAddresses[i]].push(_numOfVaults);
        }

        // Add yourself as admin
        _v.users[_v.userCount] = (User(msg.sender, Position.OWNER));
        _vaultId[msg.sender].push(_numOfVaults);

        // Votes will start with one since there is only one owner
        _v.votesReq = 1;

        // Vault will be active
        _v.status = Status.ACTIVE;
    }

    /// @dev Creates a Vault with multiple users and multiple owners
    /// @param _userAddresses All the user addresses you wish to add
    /// @param _ownerAddresses All the owner addresses you wish to add
    function createVault(
        address[] calldata _userAddresses,
        address[] calldata _ownerAddresses
    )
        external
        addressArrayCheck(_userAddresses)
        addressArrayCheck(_ownerAddresses)
    {
        // Create empty Vault Object
        Vault storage _v = _vaults[++_numOfVaults];

        // Add all the user people into the object
        for (uint256 i; i < _userAddresses.length; i++) {
            _v.users[i] = (User(_userAddresses[i], Position.USER));
            _v.userCount++;
            _vaultId[_userAddresses[i]].push(_numOfVaults);
        }

        // Add all the admin people into the object
        for (uint256 i; i < _ownerAddresses.length; i++) {
            _v.users[i] = (User(_ownerAddresses[i], Position.OWNER));
            _v.userCount++;
            _vaultId[_ownerAddresses[i]].push(_numOfVaults);
        }

        // Add yourself as admin
        _v.users[_v.userCount] = (User(msg.sender, Position.OWNER));
        _vaultId[msg.sender].push(_numOfVaults);

        // Votes will start with one
        _v.votesReq = 1;

        // Vault will be active
        _v.status = Status.ACTIVE;
    }

    /// @dev Create a Transaction
    /// @param to The Address to transfer
    /// @param value The amount in Wei
    /// @param index The Vault ID
    function createTransaction(
        address to,
        uint256 value,
        uint256 index
    ) external hasVault addressCheck(msg.sender, to) {
        // Get Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Get the Transaction Object
        TxObj storage _tx = _v.transactions[_v.transactionCount];

        // Set the data
        _tx.to = to;
        _tx.amount = value;
    }

    /// @dev Create a Transaction with Data
    /// @param to The Address to transfer
    /// @param value The amount in Wei
    /// @param index The Vault ID
    /// @param data Data to be passed in the transaction

    function createTransaction(
        address to,
        uint256 value,
        uint256 index,
        bytes calldata data
    ) external hasVault addressCheck(msg.sender, to) {
        // Get Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Get the Transaction Object
        TxObj storage _tx = _v.transactions[_v.transactionCount];

        // Set the data
        _tx.to = to;
        _tx.amount = value;
        _tx.data = data;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ EDIT - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Perform a Vote, Owners only
    /// @param index The Vault ID
    /// @param transactionId The Transaction ID
    /// @param decision The Decision ID (0 - None, 1 - Positive(Yes), 2 - Negative(No), 3 - Withdrawn (Neutral))
    function castVote(
        uint256 index,
        uint256 transactionId,
        uint8 decision
    ) external hasVault isOwnerVault(index) {
        // Get the Transaction Object
        TxObj storage _tx = _vaults[_vaultId[msg.sender][index]].transactions[
            transactionId
        ];

        // If already voted, then change the vote, revert if it's the same vote
        for (uint256 i; i < _tx.voteCount; i++) {
            if (_tx.votes[i].person == msg.sender) {
                // If it's the same vote, then revert
                if (_tx.votes[i].vote == decision) revert SameVote(decision);

                // Else Do the vote and return
                _tx.votes[i].vote = decision;
                return;
            }
        }

        // No vote is already done, add it
        _tx.votes[_tx.voteCount] = (Vote(msg.sender, decision));
        _tx.voteCount++;
    }

    /// @dev Owners are able to add users if the user already doesn't exist
    /// @param _userAddresses The userrs you want to add into your vault
    /// @param index The Vault No
    function addUsers(
        address[] calldata _userAddresses,
        uint256 index
    ) external hasVault isOwnerVault(index) addressArrayCheck(_userAddresses) {
        // Get the Vault
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Vault must be active
        if (_v.status == Status.INACTIVE) revert InActiveVault();

        // Add in the users
        // TODO : Check whether the `_v.userCount++` works
        for (uint256 i; i < _userAddresses.length; i++) {
            _v.users[_v.userCount++] = (User(_userAddresses[i], Position.USER));
        }
    }

    /// @dev Make an added User as Owner
    /// @notice You need to add a user using `addUsers` first
    /// @param _ownerAddress The Address you want to make an owner
    /// @param index The Vault No
    function makeOwner(
        address _ownerAddress,
        uint256 index
    )
        external
        hasVault
        isOwnerVault(index)
        addressCheck(msg.sender, _ownerAddress)
    {
        // Get Vault
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Vault must be active
        if (_v.status == Status.INACTIVE) revert InActiveVault();

        // Flag
        bool done;

        // Make the address an admin if it exists
        for (uint256 i; i < _v.userCount; i++) {
            if (
                _ownerAddress == _v.users[i].person &&
                _v.users[i].position != Position.INACTIVE
            ) {
                _v.users[i].position = Position.OWNER;
                done = true;
                break;
            }
        }

        // If User not found, revert
        if (!done) revert UserNotFound();
    }

    /// @dev Set the Necessary Vote Count to approve any Transaction
    /// @param index The Vault ID
    /// @param voteCount The Vote Count
    function setVotesCount(
        uint256 index,
        uint256 voteCount
    ) external hasVault isOwnerVault(index) {
        // Get the Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Vault must be active
        if (_v.status == Status.INACTIVE) revert InActiveVault();

        // Votes cannot be higher than admin count
        User[] memory _u;

        for (uint256 i; i < _v.userCount; i++) {
            if (_v.users[i].position == Position.OWNER) _u[i] = _v.users[i];
        }

        if (voteCount > _u.length) revert VoteCountTooHigh(_u.length);

        // Set Votes
        _v.votesReq = voteCount;
    }

    /// @dev Enabled a disabled Vault
    /// @param index The Vault ID
    function enableVault(uint256 index) external hasVault isOwnerVault(index) {
        // Get Vault object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Vault should be disabled
        if (_v.status == Status.ACTIVE) revert AlreadyActiveVault();

        // Set it as active
        _v.status = Status.ACTIVE;
    }

    /// @dev Edit an existing transaction
    /// @notice Editing can only be done if there are no votes to the transaction to prevent exploits
    /// @param index The Vault ID
    /// @param txIndex The transaction ID
    /// @param to The new Address to send
    /// @param amount The New Amount in Wei
    function editTransaction(
        uint256 index,
        uint256 txIndex,
        address to,
        uint256 amount
    ) external hasVault {
        // Get the Transaction Object
        TxObj storage _tx = _vaults[_vaultId[msg.sender][index]].transactions[
            txIndex
        ];

        // Revert if there are votes already
        if (_tx.voteCount > 0) revert VotedTransaction();

        // Change the data
        _tx.to = to;
        _tx.amount = amount;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ PERFORM - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Perform a Transaction
    /// @notice Anyone in the Vault can perform this provided the transaction is voted yes
    function performTransaction(
        uint256 index,
        uint256 transactionId
    ) external nonReentrant hasVault {
        // The Transaction must exist
        if(transactionId < _vaults[_vaultId[msg.sender][index]].transactionCount) revert NullTransaction();

        // Get the Transaction Object
        TxObj storage _tx = _vaults[_vaultId[msg.sender][index]].transactions[
            transactionId
        ];

        // The Transaction must not already be executed
        require(!_tx.done, "Transaction already executed");

        // The Transaction must have enough positive votes
        uint256 _reqVotes = _vaults[_vaultId[msg.sender][index]].votesReq;
        uint256 yesVotes;
        for (uint256 i; i < _tx.voteCount; i++){
            if(_tx.votes[i].vote == uint8(1)) yesVotes++;
        }
        require(yesVotes >= _reqVotes, "Not enough Votes");

        // All Good, proceed with the transaction
        _tx.done = true;
        (bool accept, ) = _tx.to.call{value:_tx.amount}(_tx.data);
        require(accept, "Transaction Failed");

        // Emit Event
        emit SuccessTransaction(_tx.to, transactionId, index, _tx.amount);

    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ REMOVE - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // TODO : Enable user and enable owner functions

    /// @dev Disables the User without removing the user
    /// @param _userAddress The User address you want to disable
    /// @param index The Vault No
    function disableUser(
        address _userAddress,
        uint256 index
    )
        external
        hasVault
        isOwnerVault(index)
        addressCheck(msg.sender, _userAddress)
    {
        // Get the Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Vault must be active
        if (_v.status == Status.INACTIVE) revert InActiveVault();

        // Flag
        bool found;

        // Loop until the right person is found, if found, change position
        for (uint256 i; i < _v.userCount; i++) {
            if (_userAddress == _v.users[i].person) {
                _v.users[i].position = Position.INACTIVE;
                found = true;
                break;
            }
        }

        // If not found, then revert
        if (!found) revert UserNotFound();
    }

    /// @dev Set the Status of the Vault as Disabled
    /// @param index The Vault ID
    function disableVault(uint256 index) external hasVault isOwnerVault(index) {
        // Get Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        //  Vault must be active
        if (_v.status == Status.INACTIVE) revert AlreadyInactiveVault();

        // Set the Vault as Disabled
        _v.status = Status.INACTIVE;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ GETTER - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // /// @dev Get All the Vault IDs the caller has joined
    // /// @return All the Vault IDs the user has joined - `uint256[]`
    function getAllVaultCount()
        external
        view
        hasVault
        returns (uint256[] memory)
    {
        return _vaultId[msg.sender];
    }

}
