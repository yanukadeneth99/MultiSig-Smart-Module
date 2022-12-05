// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./hyperverse/IHyperverseModule.sol";
import "./hyperverse/Initializable.sol";
import "./interface/IMultiSig.sol";

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
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ADD - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Owners are able to add users if the user already doesn't exist
    /// @param _userAddresses The userrs you want to add into your vault
    /// @param index The Vault No
    function addUsers(
        address[] calldata _userAddresses,
        uint256 index
    ) external hasVault isOwnerVault(index) addressArrayCheck(_userAddresses) {
        // Add in the users
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];
        for (uint256 i; i < _userAddresses.length; i++) {
            _v.users.push(User(_userAddresses[i], Position.USER));
        }
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
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];
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

        if (!done) revert UserNotFound();
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ REMOVE - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Remove a user from the Vault
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

        // There should be two users
        if (_v.users.length < 3) revert NotEnoughUsers();

        // Can't remove self
        if (_userAddress == msg.sender) revert CannotRemoveSelf();

        // Local Variables
        uint256 _i;
        bool _uExists;
        User[] memory _saveV = new User[](_v.users.length - 1);

        // Loop until you find the index of the user that needed to be removed
        for (uint256 i; i < _v.users.length; i++) {
            if (_userAddress == _v.users[i].person) {
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
    }

    //TODO : Remove owners/users (change the vote count)
    // TODO : Change votes
    // TODO : Delete vault
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
}
