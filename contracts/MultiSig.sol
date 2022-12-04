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

    /*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ F U N C T I O N S @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

    /// @dev Initializes the instance of a tenant for this contract and sets the state variables
    /// @param _tenant The address of the instance owner
    function initialize(
        address _tenant
    ) external initializer canInitialize(_tenant) {
        _tenantOwner = _tenant;
    }

    ///+functions
}
