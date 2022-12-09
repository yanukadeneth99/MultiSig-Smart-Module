// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./hyperverse/IHyperverseModule.sol";
import "./hyperverse/Initializable.sol";
import "./interface/IMultiSig.sol";
import "./helpers/ReentrancyGuard.sol";
import "./utils/Strings.sol";
import "./utils/Address.sol";

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
// TODO : Add event to `receiveMoney`

/// @title MultiSig Main Contract
/// @author Yashura
/// @dev This is a contract to handle Multi-Sig Vaults.
contract MultiSig is
    IMultiSig,
    ReentrancyGuard,
    IHyperverseModule,
    Initializable
{
    using Strings for uint256;
    using Address for address;

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

    // Holds the Vault Object
    // Vault information can be viewed by anyone
    mapping(uint256 => Vault) _vaults;

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ M O D I F I E R S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Is the caller the Tenant Owner
    modifier isTenantOwner() {
        if (msg.sender != _tenantOwner) revert Unauthorized();
        _;
    }

    // Make sure the Tenant Owner is null, and the _tenant is not passed address 0
    /// @param _tenant The Address of the Tenant
    modifier canInitialize(address _tenant) {
        if (_tenantOwner != address(0) || _tenant == address(0)) {
            revert AlreadyInitialized();
        }
        _;
    }

    // Check if addresses are same and not null
    /// @param _from From address
    /// @param _to To address
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
    /// @param _in A List of Addresses to check
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

    // Check if the Vault index exists
    modifier indexInBounds(uint256 index) {
        uint256 _id = _vaultId[msg.sender].length;
        if (_id > 0) _id--;
        if (index > _id) revert InvalidVault();
        _;
    }

    // Check if the caller is the owner of the vault
    /// @param index Your Vault Position ID
    modifier isOwnerVault(uint256 index) {
        // Check if the caller is the owner
        address _caller = msg.sender;
        Vault storage _v = _vaults[_vaultId[_caller][index]];
        bool _isOwner;
        for (uint256 i; i < _v.userCount; i++) {
            User memory _finder = _v.users[i];
            if (
                _finder.person == _caller && _finder.position == Position.OWNER
            ) {
                _isOwner = true;
                break;
            }
        }
        if (!_isOwner) revert NotAnOwner();
        _;
    }

    // Check if the caller is an active member (Owner or User)
    /// @param index Your Vault Position ID
    modifier isActiveMember(uint256 index) {
        // Get Vault
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Loop over to get the User
        for (uint256 i; i < _v.userCount; i++) {
            if (_v.users[i].person == msg.sender) {
                if (_v.users[i].position == Position.INACTIVE)
                    revert Unauthorized();

                break;
            }
        }
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

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ CREATION - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Creates a Vault
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
        _v.users[_v.userCount++] = (User(msg.sender, Position.OWNER));
        _vaultId[msg.sender].push(_numOfVaults);

        // Votes will start with one since there is only one owner
        _v.votesReq = 1;

        // Vault will be active
        _v.status = Status.ACTIVE;
    }

    /// @dev Create a Transaction with Data
    /// @param index Your Vault Position ID
    /// @param to The Address to transfer
    /// @param value The amount in Wei
    /// @param data Data to be passed in the transaction
    function createTransaction(
        uint256 index,
        address to,
        uint256 value,
        bytes calldata data
    ) external hasVault indexInBounds(index) addressCheck(msg.sender, to) {
        // Get Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Get the Transaction Object
        TxObj storage _tx = _v.transactions[_v.transactionCount++];

        // Set the data
        _tx.to = to;
        _tx.amount = value;
        _tx.data = data;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ADD - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Owners are able to add users if the user already doesn't exist
    /// @param index Your Vault Position ID
    /// @param _userAddresses The userrs you want to add into your vault
    function addUsers(
        uint256 index,
        address[] calldata _userAddresses
    )
        external
        hasVault
        indexInBounds(index)
        isOwnerVault(index)
        addressArrayCheck(_userAddresses)
    {
        // Get the Vault
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Vault must be active
        if (_v.status == Status.INACTIVE) revert InActiveVault();

        // Add in the users
        for (uint256 i; i < _userAddresses.length; i++) {
            _v.users[_v.userCount++] = (User(_userAddresses[i], Position.USER));
            _vaultId[_userAddresses[i]].push(_numOfVaults);
        }
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ EDIT - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Make an added User as Owner
    /// @notice You need to add a user using `addUsers` first
    /// @param index Your Vault Position ID
    /// @param _ownerAddress The Address you want to make an owner
    function makeOwner(
        uint256 index,
        address _ownerAddress
    )
        external
        hasVault
        indexInBounds(index)
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
    /// @param index Your Vault Position ID
    /// @param voteCount The Vote Count
    function setVotesCount(
        uint256 index,
        uint256 voteCount
    ) external hasVault indexInBounds(index) isOwnerVault(index) {
        // Get the Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Vault must be active
        if (_v.status == Status.INACTIVE) revert InActiveVault();

        // Votes cannot be higher than admin count
        uint256 _votes;

        for (uint256 i; i < _v.userCount; i++) {
            if (_v.users[i].position == Position.OWNER) _votes++;
        }

        if (voteCount > _votes) revert VoteCountTooHigh(_votes);

        // Set Votes
        _v.votesReq = voteCount;
    }

    /// @dev Edit an existing transaction
    /// @notice Editing can only be done if there are no votes to the transaction to prevent exploits
    /// @param index Your Vault Position ID
    /// @param txIndex The transaction ID
    /// @param to The new Address to send
    /// @param amount The New Amount in Wei
    function editTransaction(
        uint256 index,
        uint256 txIndex,
        address to,
        uint256 amount
    ) external hasVault indexInBounds(index) addressCheck(msg.sender, to) {
        // Get Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        uint256 _transCount = _v.transactionCount;

        if (_transCount > 0) _transCount--;

        // If the transaction ID requested is higher than the current count, then revert
        if (txIndex > _transCount) revert InvalidTransactionID();

        // Get the Transaction Object
        TxObj storage _tx = _v.transactions[txIndex];

        // Revert if there are votes already
        if (_tx.voteCount > 0) revert VotedTransaction();

        // Change the data
        _tx.to = to;
        _tx.amount = amount;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ PERFORM - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Perform a Transaction
    /// @notice Anyone in the Vault can perform this provided the transaction is voted yes
    /// @param index Your Vault Position ID
    /// @param transactionId The Transaction ID
    function performTransaction(
        uint256 index,
        uint256 transactionId
    ) external nonReentrant indexInBounds(index) hasVault {
        // Get Storage object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // If the transaction ID requested is higher than the current count, then revert
        uint256 _transCount = _v.transactionCount;
        if (_transCount > 0) _transCount--;
        if (transactionId > _transCount) revert InvalidTransactionID();

        // Get the Transaction Object
        TxObj storage _tx = _v.transactions[transactionId];

        // The Transaction must not already be executed
        require(!_tx.done, "Transaction already executed");

        // The Transaction must have enough positive votes
        uint256 _reqVotes = _v.votesReq;
        uint256 yesVotes;
        for (uint256 i; i < _tx.voteCount; i++) {
            if (_tx.votes[i].vote) yesVotes++;
        }
        require(yesVotes >= _reqVotes, "Not enough Votes");

        // Confirm that there is ether remaining in the vault to transfer
        if(_v.money < _tx.amount) revert NotEnoughEther();

        // All Good, proceed with the transaction
        _tx.done = true;
        (bool accept, ) = _tx.to.call{value: _tx.amount}(_tx.data);
        require(accept, "Transaction Failed");

        _tx.done = true;

        // Emit Event
        emit SuccessTransaction(_tx.to, transactionId, index, _tx.amount);
    }

    /// @dev Perform a Vote, Owners only
    /// @param index Your Vault Position ID
    /// @param transactionId The Transaction ID
    /// @param decision The Decision ID (0 - None, 1 - Positive(Yes), 2 - Negative(No), 3 - Withdrawn (Neutral))
    function castVote(
        uint256 index,
        uint256 transactionId,
        bool decision
    ) external hasVault indexInBounds(index) isOwnerVault(index) {
        // Get Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // If the transaction ID requested is higher than the current count, then revert
        uint256 _transCount = _v.transactionCount;
        if (_transCount > 0) _transCount--;
        if (transactionId > _transCount) revert InvalidTransactionID();

        // Get the Transaction Object
        TxObj storage _tx = _v.transactions[
            transactionId
        ];

        // If already voted, then change the vote, revert if it's the same vote
        for (uint256 i; i < _tx.voteCount; i++) {
            if (_tx.votes[i].person == msg.sender) {
                // If it's the same vote, then revert
                if (_tx.votes[i].vote == decision) revert SameVote();

                // Else Do the vote and return
                _tx.votes[i].vote = decision;
                return;
            }
        }

        // No vote is already done, add it
        _tx.votes[_tx.voteCount] = (Vote(msg.sender, decision));
        _tx.voteCount++;        
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ENABLE - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Enabled a disabled Vault
    /// @param index Your Vault Position ID
    function enableVault(uint256 index) external hasVault isOwnerVault(index) {
        // Get Vault object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Vault should be disabled
        if (_v.status == Status.ACTIVE) revert AlreadyActiveVault();

        // Set it as active
        _v.status = Status.ACTIVE;
    }

    /// @dev Enable a User
    /// @notice Must be already Inactive
    function enableUser(
        uint256 index,
        address _userAddress
    ) external hasVault isOwnerVault(index) {
        // Get Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        // Get the User out
        for (uint256 i; i < _v.userCount; i++) {
            if (_v.users[i].person == _userAddress) {
                // Revert if already a user/Not inactive
                if (
                    _v.users[i].position == Position.USER ||
                    _v.users[i].position == Position.OWNER
                ) revert AlreadyEnabledUser();

                _v.users[i].position = Position.USER;
                return;
            }
        }

        // No user found, revert
        revert UserNotFound();
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ DISABLE - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Disables the User without removing the user
    /// @param index Your Vault Position ID
    /// @param _userAddress The User address you want to disable
    function disableUser(
        uint256 index,
        address _userAddress
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

        // Loop until the right person is found, if found, change position
        for (uint256 i; i < _v.userCount; i++) {
            if (_userAddress == _v.users[i].person) {
                // User must already be active
                if (_v.users[i].position == Position.INACTIVE)
                    revert AlreadyDisabledUser();

                _v.users[i].position = Position.INACTIVE;
                return;
            }
        }

        // User not found, revert
        revert UserNotFound();
    }

    /// @dev Set the Status of the Vault as Disabled
    /// @param index Your Vault Position ID
    function disableVault(uint256 index) external hasVault isOwnerVault(index) {
        // Get Vault Object
        Vault storage _v = _vaults[_vaultId[msg.sender][index]];

        //  Vault must be active
        if (_v.status == Status.INACTIVE) revert AlreadyInactiveVault();

        // Set the Vault as Disabled
        _v.status = Status.INACTIVE;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ GETTER - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

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

    /// @dev Returns Information about a Transaction
    /// @notice The caller must have a vault
    /// @param index Your Vault Position ID
    /// @param transactionId The Transaction ID
    /// @return _to The Address to send the transaction
    /// @return _amount The Amount to transact
    /// @return _data Any Data passed in the transaction
    /// @return _done Whether the transaction is executed (true - executed)
    /// @return _posVoteCount Number of people who votes yes
    /// @return _status The Status of the Vault (Active, or Inactive)
    function getTransaction(
        uint256 index,
        uint256 transactionId
    )
        external
        view
        hasVault
        indexInBounds(index)
        returns (
            address _to,
            uint256 _amount,
            bytes memory _data,
            bool _done,
            uint256 _posVoteCount,
            Status _status
        )
    {
        // Get the Transaction Object
        TxObj storage _tx = _vaults[_vaultId[msg.sender][index]].transactions[
            transactionId
        ];

        // Revert if the transaction does not exist
        if (_tx.to == address(0)) revert InvalidTransactionID();

        // Get the Positive Vote Count
        uint256 _posVotes;
        for (uint256 i; i < _tx.voteCount; i++) {
            if (_tx.votes[i].vote == true) _posVotes++;
        }

        // Return the values
        _to = _tx.to;
        _amount = _tx.amount;
        _data = _tx.data;
        _done = _tx.done;
        _posVoteCount = _posVotes;
        _status = _vaults[index].status;
    }

    /// @dev Get a Vault information
    /// @notice Anyone can perform this
    /// @param vaultId The Vault ID
    /// @return _allusers All the active users in the vault
    /// @return _reqVotes The Required Votes to pass a transaction
    /// @return _transCount The Total Transaction count that exists in this project
    /// @return _status The Status of the Vault
    /// @return _money The amount of wei the vault holds
    function getVault(
        uint256 vaultId
    )
        external
        view
        returns (
            User[] memory _allusers,
            uint256 _reqVotes,
            uint256 _transCount,
            Status _status,
            uint256 _money
        )
    {
        // Get Vault
        Vault storage _v = _vaults[vaultId];

        // Get all the active users
        User[] memory _users = new User[](_v.userCount);
        for (uint256 i; i < _v.userCount; i++) {
            if (_v.users[i].position != Position.INACTIVE)
                _users[i] = _v.users[i];
        }

        // Return all variables
        _allusers = _users;
        _reqVotes = _v.votesReq;
        _transCount = _v.transactionCount;
        _status = _v.status;
        _money = _v.money;
    }

    /// @dev Get the Total Number of Vaults present
    /// @return The total number of vaults - `uint256`
    function getNoOfVaults() external view returns (uint256) {
        return _numOfVaults;
    }

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ MONEY - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Function to pass money to a vault
    /// @param vaultId The Vault ID
    function transferMoney(uint256 vaultId) external payable {

        // Check Ethers passed
        if(msg.value == 0 ether) revert NoEtherPassed();

        // Check Vault ID
        if(vaultId > _numOfVaults) revert InvalidVault();

        // Get Vault Object
        Vault storage _v = _vaults[vaultId];
        uint256 _mon = _v.money;

        // Update the money
        _v.money += msg.value;

        // Confirm the right value is updated
        assert(_v.money == _mon + msg.value);
    }

    /// @dev Pass money into a vault confirming a owner
    /// @param vaultId The Vault ID
    /// @param ownerAddress A Owner address to confirm the vault
    function transferMoneyWithProof(uint256 vaultId, address ownerAddress) external payable addressCheck(msg.sender,ownerAddress) {

        // Check Ethers passed
        if(msg.value == 0 ether) revert NoEtherPassed();

        // Check Vault ID
        if(vaultId > _numOfVaults) revert InvalidVault();

        // Get Vault Object
        Vault storage _v = _vaults[vaultId];

        // Local Variables
        uint256 _mon = _v.money;
        bool found;
        
        // Loop over to find the owneraddress
        for(uint256 i; i < _v.userCount; i++){
            if(_v.users[i].person == ownerAddress){
                found = true;
                break;
            }
        }

        // Not Found User
        if(!found) revert AddressNotInAVault();


        // Update the money
        _v.money += msg.value;

        // Confirm the right value is updated
        assert(_v.money == _mon + msg.value);
    }
}
