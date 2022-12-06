// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./hyperverse/IHyperverseModule.sol";
import "./hyperverse/Initializable.sol";
import "./interface/IMultiSig.sol";

// TODO : Gas optimizations - Use mload instead of sload (Load variables into memory than storage)
// TODO : Gas optimizations - Use Remix Gas Optimizer

/// @title MultiSig Main Contract
/// @author Yashura
/// @dev This is a contract to handle Multi-Sig Vaults.
contract MultiSig is IMultiSig, IHyperverseModule, Initializable {
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T A T E @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Account used to deploy contract
    address public immutable contractOwner;

    // Stores the tenant owner
    address private _tenantOwner;

    // InterfaceID for the Contract
    // Hex Value of all the functions in IMultiSig passed through XOR
    //TODO : Change this
    bytes4 private constant _INTERFACE_ID = 0x0342a3c8;

    // User -> Vault IDs. Always starts with 1
    mapping(address => uint256[]) private _vaultId;

    // Holds the current vaults created
    uint256 private _numOfVaults;

    // Vault ID -> Vault Object
    mapping(uint256 => Vault) private _vaults;

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ M O D I F I E R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Is the caller the Tenant Owner
    modifier isTenantOwner() {
        if (msg.sender != _tenantOwner) {
            revert Unauthorized();
        }
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
        Vault memory _v = _vaults[_vaultId[_caller][index]];
        bool _isOwner;
        for (uint256 i; i < _v.users.length; i++) {
            User memory _finder = _v.users[i];
            if (_finder.person == _caller) {
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
            _v.users.push(User(_userAddresses[i], Position.USER));
            _vaultId[_userAddresses[i]].push(_numOfVaults);
        }

        // Add yourself as admin
        _v.users.push(User(msg.sender, Position.OWNER));
        _vaultId[msg.sender].push(_numOfVaults);

        // Votes will start with one since there is only one owner
        _v.votes = 1;

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
            _v.users.push(User(_userAddresses[i], Position.USER));
            _vaultId[_userAddresses[i]].push(_numOfVaults);
        }

        // Add all the admin people into the object
        for (uint256 i; i < _ownerAddresses.length; i++) {
            _v.users.push(User(_ownerAddresses[i], Position.OWNER));
            _vaultId[_ownerAddresses[i]].push(_numOfVaults);
        }

        // Add yourself as admin
        _v.users.push(User(msg.sender, Position.OWNER));
        _vaultId[msg.sender].push(_numOfVaults);

        // Votes will start with one since there is only one owner
        _v.votes = 1;

        // Vault will be active
        _v.status = Status.ACTIVE;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ADD - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

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
        for (uint256 i; i < _userAddresses.length; i++) {
            _v.users.push(User(_userAddresses[i], Position.USER));
        }
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
        // Create a transaction Object
        TxObj memory _tx;

        // Set the Values, rest will be default
        _tx.to = to;
        _tx.amount = value;

        // Get Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Add in the transaction
        _v.transactions.push(_tx);
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ EDIT - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

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
        for (uint256 i; i < _v.users.length; i++) {
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

        for (uint256 i; i < _v.users.length; i++) {
            if (_v.users[i].position == Position.OWNER) _u[i] = _v.users[i];
        }

        if (voteCount > _u.length) revert VoteCountTooHigh(_u.length);

        // Set Votes
        _v.votes = voteCount;
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
        if (_tx.votes.length > 0) revert VotedTransaction();

        // Change the data
        _tx.to = to;
        _tx.amount = amount;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ REMOVE - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Remove a user or inactive member from the Vault
    /// @dev UnRecommended for High Gas Fees
    /// TODO : Check Gas Fees
    /// @param _userAddress The Address you want to remove
    /// @param index The Vault No
    function removeUser(
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

        // There should be atleast 3 members
        if (_v.users.length < 3) revert NotEnoughUsers();

        // Local Variables
        uint256 _i;
        bool _uExists;
        User[] memory _saveV = new User[](_v.users.length - 1);

        // Loop until you find the index of the user that needed to be removed
        // Can remove users or inactive members
        for (uint256 i; i < _v.users.length; i++) {
            if (
                _userAddress == _v.users[i].person &&
                (_v.users[i].position == Position.USER ||
                    _v.users[i].position == Position.INACTIVE)
            ) {
                _uExists = true;
                _i = i;
                break;
            }
        }

        if (!_uExists) revert UserNotFound();

        // Loop until you find the index of the user that needed to be removed, and just don't add it into the memory array
        for (uint256 i; i < _v.users.length; i++) {
            if (i == _i) {
                continue;
            }
            _saveV[i] = _v.users[i];
        }

        _v.users = _saveV;
    }

    /// @dev Remove a user from the Vault
    /// @dev UnRecommended for High Gas Fees
    /// TODO : Check Gas Fees
    /// @param _userAddress The Address you want to remove
    /// @param index The Vault No
    function removeOwner(
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

        // There should be atleast 3 members
        if (_v.users.length < 3) revert NotEnoughUsers();

        // Local Variables
        uint256 _i;
        bool _uExists;
        User[] memory _saveV = new User[](_v.users.length - 1);

        // Loop until you find the index of the user that needed to be removed
        for (uint256 i; i < _v.users.length; i++) {
            if (
                _userAddress == _v.users[i].person &&
                _v.users[i].position == Position.OWNER
            ) {
                _uExists = true;
                _i = i;
                break;
            }
        }

        if (!_uExists) revert UserNotFound();

        // Loop until you find the index of the user that needed to be removed, and just don't add it into the memory array
        for (uint256 i; i < _v.users.length; i++) {
            if (i == _i) {
                continue;
            }
            _saveV[i] = _v.users[i];
        }

        _v.users = _saveV;

        // Change count of approvals needed
        if (_v.votes - 1 == 0) {
            _v.votes = 1;
        } else {
            _v.votes = _v.votes - 1;
        }
    }

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
        for (uint256 i; i < _v.users.length; i++) {
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

    //? Does this make sense
    function deleteVault(uint256 index) external hasVault isOwnerVault(index) {}

    // TODO : Vote on a TX (Remember there is a neutral vote)

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ GETTER - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Gets the Vault Details of the Passed Index
    /// @param index The Vault No
    /// @return Vault Object which contains all the users and the votes required - `Vault`
    function getVault(
        uint256 index
    ) external view hasVault returns (Vault memory) {
        return _vaults[_vaultId[msg.sender][index]];
    }

    /// @dev Get All the Vault IDs the caller has joined
    /// @return All the Vault IDs the user has joined - `uint256[]`
    function getAllVaultCount()
        external
        view
        hasVault
        returns (uint256[] memory)
    {
        return _vaultId[msg.sender];
    }

    /// @dev Get all the Transactions with the ID
    /// @param index The Vault ID
    /// @return The Transaction Array which contains the ID and the transaction.
    function getAllTransactions(
        uint256 index
    ) external view hasVault returns (AllTxObj[] memory) {
        // Get all the transactions of the vault
        Vault memory _v = _vaults[_vaultId[msg.sender][index]];

        // New Transaction Object with ID
        AllTxObj[] memory _allTx;

        // Set the Transaction and the ID(Index) into a new struct
        for (uint256 i; i < _v.transactions.length; i++) {
            _allTx[i] = AllTxObj(i, _v.transactions[i]);
        }

        return _allTx;
    }
}
