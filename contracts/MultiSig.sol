// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./hyperverse/IHyperverseModule.sol";
import "./hyperverse/Initializable.sol";
import "./interface/IMultiSig.sol";
import "./helpers/ReentrancyGuard.sol";

/// @title MultiSig Contract
/// @author Yashura
/// @dev Create, manage, add, remove and control collective funds in a group vault.
contract MultiSig is
    IMultiSig,
    ReentrancyGuard,
    IHyperverseModule,
    Initializable
{
    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ S T A T E @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // Account used to deploy contract
    address public immutable contractOwner;

    // Stores the tenant owner
    address private _tenantOwner;

    // User -> Vault IDs.
    /// @dev Always starts with 1
    mapping(address => uint256[]) private _vaultId;

    // Holds the current vaults count created
    uint256 private _numOfVaults;

    // Vault ID => Vault Object
    // Vault information can be viewed by anyone via the getter provided
    mapping(uint256 => Vault) private _vaults;

    // Vault ID => (Index ID => Transaction Object)
    mapping(uint256 => mapping(uint256 => TxObj)) private _transactions;

    // Transaction ID => (Vote Index => Vote Object)
    mapping(uint256 => mapping(uint256 => Vote)) private _votes;

    // Vault ID => (Index ID => User Object)
    // You can get the number of users from the Vault Object - `userCount`
    mapping(uint256 => mapping(uint256 => User)) _users;

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
        for (uint256 i = 0; i < _in.length; i++) {
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
    /// @param index Your Vault Position ID
    modifier indexInBounds(uint256 index) {
        unchecked {
            uint256 _id = _vaultId[msg.sender].length;
            if (_id > 0) _id--;
            if (index > _id) revert InvalidVault();

            // Do not need a check for `0` since `hasVault()` already checks this.
        }
        _;
    }

    // Check if the caller is the owner of the vault
    /// @param index Your Vault Position ID
    modifier isOwnerVault(uint256 index) {
        // Get Vault Object
        uint256 vaultId = _vaultId[msg.sender][index];
        Vault memory v = _vaults[vaultId];

        // Flag
        bool _isOwner;

        // Loop over till all users are checked
        for (uint256 i; i < v.userCount; i++) {
            // Create a User Object
            User memory u = _users[vaultId][i];

            if (u.person == msg.sender && u.position == Position.OWNER) {
                _isOwner = true;
                break;
            }
        }

        // Not an Owner
        if (!_isOwner) revert NotAnOwner();

        // All Good
        _;
    }

    // Check if the caller is an active member (Owner or User)
    // @param index Your Vault Position ID
    // modifier isActiveMember(uint256 index) {
    //     // Get Vault
    //     Vault storage _v = _vaults[_vaultId[msg.sender][index]];

    //     // Loop over to get the User
    //     for (uint256 i; i < _v.userCount; i++) {
    //         if (_v.users[i].person == msg.sender) {
    //             if (_v.users[i].position == Position.INACTIVE)
    //                 revert Unauthorized();

    //             break;
    //         }
    //     }
    //     _;
    // }

    // Check whether address passed in a zero address
    modifier notZeroAddress(address _in) {
        if (_in == address(0)) revert ZeroAddress();
        _;
    }

    // Check whether the vault in inactive
    /// @param index Your Vault Position ID
    modifier notInactiveVault(uint256 index) {
        // Get Vault Object
        Vault memory _v = _vaults[_vaultId[msg.sender][index]];

        // Check if the Status is Inactive and revert if so
        if (_v.status == Status.INACTIVE) revert InActiveVault();

        // All Good Continue
        _;
    }

    // Check if the caller is not an inactive member
    /// @param index Your Vault Position ID
    modifier callerNotInactive(uint256 index) {
        // Get Vault Object
        uint256 vaultId = _vaultId[msg.sender][index];
        Vault memory v = _vaults[_vaultId[msg.sender][index]];

        // Check if the caller is not inactive
        for (uint256 i; i < v.userCount; i++) {
            // Get Object into memory
            User memory u = _users[vaultId][i];

            if (u.person == msg.sender) {
                if (u.position == Position.INACTIVE) {
                    revert Unauthorized();
                }
                break;
            }
        }

        // All good
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
    ) external virtual override addressArrayCheck(_userAddresses) {
        // Increment Vault Count
        _numOfVaults++;

        // Create Vault Object
        Vault memory v;

        // Set it's values
        v.votesReq = 1;
        v.status = Status.ACTIVE;

        // Add all the people into the object
        for (uint256 i; i < _userAddresses.length; i++) {
            // Cannot add self
            if (_userAddresses[i] == msg.sender) revert CannotAddSelf();

            _users[_numOfVaults][v.userCount++] = (
                User(_userAddresses[i], Position.USER)
            );
            _vaultId[_userAddresses[i]].push(_numOfVaults);
        }

        // Add yourself as admin
        _users[_numOfVaults][v.userCount++] = (
            User(msg.sender, Position.OWNER)
        );
        _vaultId[msg.sender].push(_numOfVaults);

        // Assign the vault and users
        _vaults[_numOfVaults] = v;

        // Emit event
        emit VaultCreated(msg.sender, _numOfVaults, _userAddresses.length);
    }

    /// @dev Create a Transaction with Data
    /// @param index Your Vault Position ID
    /// @param to The Address to transfer
    /// @param value The amount in Wei
    function createTransaction(
        uint256 index,
        address to,
        uint256 value
    ) external {
        // Get Vault Object
        uint256 vaultId = _vaultId[msg.sender][index];
        Vault memory v = _vaults[vaultId];

        // Creating a transaction Object
        TxObj memory _tx;

        // Set the data
        _tx.to = to;
        _tx.amount = value;

        // Setting Values
        _transactions[vaultId][v.transactionCount++] = _tx;
        _vaults[vaultId].transactionCount = v.transactionCount;

        // Emit event
        emit TransactionCreated(msg.sender, vaultId, v.transactionCount--);
    }

    // /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ADD - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Owners are able to add users if the user already doesn't exist
    /// @param index Your Vault Position ID
    /// @param _userAddresses The userrs you want to add into your vault
    function addUsers(
        uint256 index,
        address[] calldata _userAddresses
    ) external {
        // Atleast one user should be passed
        require(_userAddresses.length > 0, "No address added");

        // Get the Vault Object
        uint256 vaultId = _vaultId[msg.sender][index];
        Vault memory v = _vaults[vaultId];

        // Revert if the user already exists
        for (uint256 i; i < v.userCount; i++) {
            // Get User Object
            User memory u = _users[vaultId][i];

            // Loop over the user Address array
            for (uint256 j; j < _userAddresses.length; j++) {
                if (u.person == _userAddresses[j]) revert UserExists();
            }
        }

        // Add in the users
        for (uint256 i; i < _userAddresses.length; i++) {
            _users[vaultId][v.userCount++] = (
                User(_userAddresses[i], Position.USER)
            );
            _vaultId[_userAddresses[i]].push(_numOfVaults);
        }

        // Save User Count
        _vaults[vaultId].userCount = v.userCount;

        // Emit event
        emit NewUsersAdded(
            msg.sender,
            _vaultId[msg.sender][index],
            _userAddresses.length
        );
    }

    // /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ EDIT - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Make an added User as Owner
    /// @notice You need to add a user using `addUsers` first
    /// @param index Your Vault Position ID
    /// @param _ownerAddress The Address you want to make an owner
    function makeOwner(uint256 index, address _ownerAddress) external {
        // Get Vault
        uint256 vaultId = _vaultId[msg.sender][index];
        Vault memory v = _vaults[vaultId];

        // Flag
        bool done;

        // Make the address an admin if it exists
        for (uint256 i; i < v.userCount; i++) {
            // Create a user Object
            User memory u = _users[vaultId][i];
            if (_ownerAddress == u.person && u.position != Position.INACTIVE) {
                _users[vaultId][i].position = Position.OWNER;
                done = true;
                break;
            }
        }

        // If User not found, revert
        if (!done) revert UserNotFound();

        // Event emitted
        emit MadeOwner(msg.sender, vaultId, _ownerAddress);
    }

    /// @dev Set the Necessary Vote Count to approve any Transaction
    /// @param index Your Vault Position ID
    /// @param voteCount The Vote Count
    function setVotesCount(uint256 index, uint256 voteCount) external {
        // Get the Vault Object
        uint256 vaultId = _vaultId[msg.sender][index];
        Vault memory v = _vaults[vaultId];

        // Votes cannot be higher than admin count
        uint256 adminCount;
        for (uint256 i; i < v.userCount; i++) {
            // Create a new User Object
            User memory u = _users[vaultId][i];

            if (u.position == Position.OWNER) adminCount++;
        }

        if (voteCount > adminCount) revert VoteCountTooHigh(adminCount);

        // Set Votes
        _vaults[vaultId].votesReq = voteCount;

        // Event emitted
        emit ChangeVoteCount(
            msg.sender,
            _vaultId[msg.sender][index],
            voteCount
        );
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
    ) external {
        // Get Vault Object
        uint256 vaultId = _vaultId[msg.sender][index];
        Vault memory v = _vaults[vaultId];

        // If the transaction ID requested is higher than the current count, then revert
        checkTransactionCount(v, txIndex);

        // Get the Transaction Object
        TxObj memory transaction = _transactions[vaultId][txIndex];

        // Revert if there are votes already
        if (transaction.voteCount > 0) revert VotedTransaction();

        // Set the data
        transaction.to = to;
        transaction.amount = amount;

        // Set the data
        _transactions[vaultId][txIndex] = transaction;

        // Event emitted
        emit TransactionEdited(msg.sender, vaultId, txIndex);
    }

    /// @dev Internal Function to revert if the transaction ID requested is more than what the vault holds
    function checkTransactionCount(
        Vault memory v,
        uint256 txIndex
    ) internal pure {
        // If the transaction ID requested is higher than the current count, then revert
        uint256 _transCount = v.transactionCount;
        if (_transCount > 0) _transCount--;
        if (txIndex > _transCount || v.transactionCount == 0)
            revert InvalidTransactionID();
    }

    // /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ PERFORM - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Perform a Transaction
    /// @notice Anyone in the Vault can perform this provided the transaction is voted yes
    /// @param index Your Vault Position ID
    /// @param transactionId The Transaction ID
    function performTransaction(uint256 index, uint256 transactionId) external {
        // Get Vault object
        uint256 vaultId = _vaultId[msg.sender][index];
        Vault memory v = _vaults[vaultId];

        // If the transaction ID requested is higher than the current count, then revert
        checkTransactionCount(v, transactionId);

        // Get the Transaction Object
        TxObj memory _tx = _transactions[vaultId][transactionId];

        // The Transaction must not already be executed
        require(!_tx.done, "Transaction already executed");

        // The Transaction must have enough positive votes
        uint256 _reqVotes = v.votesReq;
        uint256 yesVotes;
        for (uint256 i; i < _tx.voteCount; i++) {
            // Make a Vote Object
            Vote memory vt = _votes[transactionId][i];
            if (vt.vote == VoteSelection.POSITIVE) yesVotes++;
        }
        require(yesVotes >= _reqVotes, "Not enough Votes");

        // Confirm that there is ether remaining in the vault to transfer
        if (v.money < _tx.amount) revert NotEnoughEther();

        // All Good, proceed with the transaction
        _transactions[vaultId][transactionId].done = true;
        (bool accept, ) = _tx.to.call{value: _tx.amount}("");
        require(accept, "Transaction Failed");

        // Emit Event
        emit TransactionComplete(_tx.to, vaultId, transactionId, _tx.amount);
    }

    // /// @dev Perform a Vote, Owners only
    // /// @param index Your Vault Position ID
    // /// @param transactionId The Transaction ID
    // /// @param decision The Decision ID (0 - None, 1 - Positive(Yes), 2 - Negative(No), 3 - Withdrawn (Neutral))
    // function castVote(
    //     uint256 index,
    //     uint256 transactionId,
    //     bool decision
    // ) external hasVault indexInBounds(index) {
    //     // Get Vault Object
    //     Vault storage _v = _vaults[_vaultId[msg.sender][index]];

    //     // Check if the Status is Inactive and revert if so
    //     if (_v.status == Status.INACTIVE) revert InActiveVault();

    //     address _caller = msg.sender;

    //     bool _isOwner;
    //     for (uint256 i; i < _v.userCount; i++) {
    //         User memory _finder = _v.users[i];
    //         if (
    //             _finder.person == _caller && _finder.position == Position.OWNER
    //         ) {
    //             _isOwner = true;
    //             break;
    //         }
    //     }
    //     if (!_isOwner) revert NotAnOwner();

    //     // If the transaction ID requested is higher than the current count, then revert
    //     uint256 _transCount = _v.transactionCount;
    //     if (_transCount > 0) _transCount--;
    //     if (transactionId > _transCount) revert InvalidTransactionID();

    //     // Get the Transaction Object
    //     TxObj storage _tx = _v.transactions[transactionId];

    //     // If already voted, then change the vote, revert if it's the same vote
    //     for (uint256 i; i < _tx.voteCount; i++) {
    //         if (_tx.votes[i].person == msg.sender) {
    //             // If it's the same vote, then revert
    //             if (_tx.votes[i].vote == decision) revert SameVote();

    //             // Else Do the vote and return
    //             _tx.votes[i].vote = decision;

    //             // Emit event
    //             emit ChangeVote(
    //                 msg.sender,
    //                 _vaultId[msg.sender][index],
    //                 transactionId,
    //                 _tx.votes[i].vote,
    //                 decision
    //             );
    //             return;
    //         }
    //     }

    //     // No vote is already done, add it
    //     _tx.votes[_tx.voteCount] = (Vote(msg.sender, decision));
    //     _tx.voteCount++;

    //     // Event Emitted
    //     emit CastVote(
    //         msg.sender,
    //         _vaultId[msg.sender][index],
    //         transactionId,
    //         decision
    //     );
    // }

    // /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ENABLE - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // /// @dev Enabled a disabled Vault
    // /// @param index Your Vault Position ID
    // function enableVault(
    //     uint256 index
    // ) external hasVault indexInBounds(index) isOwnerVault(index) {
    //     // Get Vault object
    //     Vault storage _v = _vaults[_vaultId[msg.sender][index]];

    //     // Vault should be disabled
    //     if (_v.status == Status.ACTIVE) revert AlreadyActiveVault();

    //     // Set it as active
    //     _v.status = Status.ACTIVE;

    //     // Emit event
    //     emit EnableVault(msg.sender, _vaultId[msg.sender][index]);
    // }

    // /// @dev Enable a User
    // /// @notice Must be already Inactive
    // function enableUser(
    //     uint256 index,
    //     address _userAddress
    // )
    //     external
    //     hasVault
    //     indexInBounds(index)
    //     notInactiveVault(index)
    //     isOwnerVault(index)
    // {
    //     // Get Vault Object
    //     Vault storage _v = _vaults[_vaultId[msg.sender][index]];

    //     // Get the User out
    //     for (uint256 i; i < _v.userCount; i++) {
    //         if (_v.users[i].person == _userAddress) {
    //             // Revert if already a user/Not inactive
    //             if (
    //                 _v.users[i].position == Position.USER ||
    //                 _v.users[i].position == Position.OWNER
    //             ) revert AlreadyEnabledUser();

    //             _v.users[i].position = Position.USER;

    //             // Emit event
    //             emit EnableUser(
    //                 msg.sender,
    //                 _vaultId[msg.sender][index],
    //                 _v.users[i].person
    //             );
    //             return;
    //         }
    //     }

    //     // No user found, revert
    //     revert UserNotFound();
    // }

    // /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ DISABLE - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // /// @dev Disables the User without removing the user
    // /// @param index Your Vault Position ID
    // /// @param _userAddress The User address you want to disable
    // function disableUser(
    //     uint256 index,
    //     address _userAddress
    // )
    //     external
    //     hasVault
    //     indexInBounds(index)
    //     notInactiveVault(index)
    //     addressCheck(msg.sender, _userAddress)
    //     isOwnerVault(index)
    // {
    //     // Get the Vault Object
    //     Vault storage _v = _vaults[_vaultId[msg.sender][index]];

    //     // Loop until the right person is found, if found, change position
    //     for (uint256 i; i < _v.userCount; i++) {
    //         if (_userAddress == _v.users[i].person) {
    //             // User must already be active
    //             if (_v.users[i].position == Position.INACTIVE)
    //                 revert AlreadyDisabledUser();

    //             _v.users[i].position = Position.INACTIVE;

    //             // Emit event
    //             emit DisableUser(
    //                 msg.sender,
    //                 _vaultId[msg.sender][index],
    //                 _v.users[i].person
    //             );

    //             return;
    //         }
    //     }

    //     // User not found, revert
    //     revert UserNotFound();
    // }

    // /// @dev Set the Status of the Vault as Disabled
    // /// @param index Your Vault Position ID
    // function disableVault(
    //     uint256 index
    // ) external hasVault indexInBounds(index) isOwnerVault(index) {
    //     // Get Vault Object
    //     Vault storage _v = _vaults[_vaultId[msg.sender][index]];

    //     //  Vault must be active
    //     if (_v.status == Status.INACTIVE) revert AlreadyInactiveVault();

    //     // Set the Vault as Disabled
    //     _v.status = Status.INACTIVE;

    //     // Emit event
    //     emit DisableVault(msg.sender, _vaultId[msg.sender][index]);
    // }

    // /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ GETTER - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

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
            bool _done,
            uint256 _posVoteCount,
            Status _status
        )
    {
        // Get Vault Object
        uint256 vaultId = _vaultId[msg.sender][index];

        // Get the Transaction Object
        TxObj memory transaction = _transactions[vaultId][transactionId];

        // Revert if the transaction does not exist
        if (transaction.to == address(0)) revert InvalidTransactionID();

        // Get the Positive Vote Count
        uint256 _posVotes;
        for (uint256 i; i < transaction.voteCount; i++) {
            if (_votes[transactionId][i].vote == VoteSelection.POSITIVE)
                _posVotes++;
        }

        // Return the values
        _to = transaction.to;
        _amount = transaction.amount;
        _done = transaction.done;
        _posVoteCount = _posVotes;
        _status = _vaults[vaultId].status;
    }

    /// @dev Get a Vault information
    /// @notice Anyone can perform this
    /// @param vaultId The Vault ID
    /// @return _allusers All the active users in the vault
    /// @return _alltransactions All the transactions that done using this vault
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
            TxObj[] memory _alltransactions,
            uint256 _reqVotes,
            uint256 _transCount,
            Status _status,
            uint256 _money
        )
    {
        // Get Vault
        Vault memory v = _vaults[vaultId];

        // Get all the active users
        User[] memory users = new User[](v.userCount);
        for (uint256 i; i < v.userCount; i++) {
            users[i] = _users[vaultId][i];
        }

        // Get all transactions
        TxObj[] memory transactions = new TxObj[](v.transactionCount);
        for (uint256 i; i < v.transactionCount; i++) {
            transactions[i] = _transactions[vaultId][i];
        }

        // Return all variables
        _allusers = users;
        _alltransactions = transactions;
        _reqVotes = v.votesReq;
        _transCount = v.transactionCount;
        _status = v.status;
        _money = v.money;
    }

    /// @dev Get the Total Number of Vaults present
    /// @return The total number of vaults - `uint256`
    function getNoOfVaults() external view returns (uint256) {
        return _numOfVaults;
    }

    // /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@ MONEY - F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    // /// @dev Function to pass money to a vault
    // /// @param vaultId The Vault ID
    // function transferMoney(uint256 vaultId) external payable {
    //     // Check Ethers passed
    //     if (msg.value == 0 ether) revert NoEtherPassed();

    //     // Check Vault ID
    //     if (vaultId > _numOfVaults) revert InvalidVault();

    //     // Get Vault Object
    //     Vault storage _v = _vaults[vaultId];
    //     uint256 _mon = _v.money;

    //     // Vault needs to be active
    //     if (_v.status == Status.INACTIVE) revert InActiveVault();

    //     // Update the money
    //     _v.money += msg.value;

    //     // Confirm the right value is updated
    //     assert(_v.money == _mon + msg.value);

    //     // Emit event
    //     emit Deposit(msg.sender, vaultId, msg.value);
    // }

    // /// @dev Pass money into a vault confirming a owner
    // /// @param vaultId The Vault ID
    // /// @param ownerAddress A Owner address to confirm the vault
    // function transferMoneyWithProof(
    //     uint256 vaultId,
    //     address ownerAddress
    // ) external payable notZeroAddress(ownerAddress) {
    //     // Check Ethers passed
    //     if (msg.value == 0 ether) revert NoEtherPassed();

    //     // Check Vault ID
    //     if (vaultId > _numOfVaults) revert InvalidVault();

    //     // Get Vault Object
    //     Vault storage _v = _vaults[vaultId];

    //     // Vault needs to be active
    //     if (_v.status == Status.INACTIVE) revert InActiveVault();

    //     // Local Variables
    //     uint256 _mon = _v.money;
    //     bool found;

    //     // Loop over to find the owneraddress
    //     for (uint256 i; i < _v.userCount; i++) {
    //         if (_v.users[i].person == ownerAddress) {
    //             found = true;
    //             break;
    //         }
    //     }

    //     // Not Found User
    //     if (!found) revert AddressNotInAVault();

    //     // Update the money
    //     _v.money += msg.value;

    //     // Confirm the right value is updated
    //     assert(_v.money == _mon + msg.value);

    //     // Emit event
    //     emit Deposit(msg.sender, vaultId, msg.value);
    // }
}
