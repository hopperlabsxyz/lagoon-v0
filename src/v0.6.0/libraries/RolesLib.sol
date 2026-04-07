// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Roles} from "../Roles.sol";
import {OnlySafe, OnlySecurityCouncil, OnlyValuationManager, OnlyWhitelistManager} from "../primitives/Errors.sol";
import {
    FeeReceiverUpdated,
    SafeUpdated,
    SecurityCouncilUpdated,
    SuperOperatorUpdated,
    ValuationManagerUpdated,
    WhitelistManagerUpdated
} from "../primitives/Events.sol";

library RolesLib {
    // keccak256(abi.encode(uint256(keccak256("hopper.storage.Roles")) - 1)) & ~bytes32(uint256(0xff))
    /// @custom:storage-location erc7201:hopper.storage.Roles
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant rolesStorage = 0x7c302ed2c673c3d6b4551cf74a01ee649f887e14fd20d13dbca1b6099534d900;

    /// @dev Returns the storage struct of the roles.
    /// @return _rolesStorage The storage struct of the roles.
    function _getRolesStorage() internal pure returns (Roles.RolesStorage storage _rolesStorage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _rolesStorage.slot := rolesStorage
        }
    }

    /// @dev Reverts if the caller is not the safe
    function _onlySafe() internal view {
        address _safe = _getRolesStorage().safe;
        if (_safe != msg.sender) revert OnlySafe(_safe);
    }

    /// @dev Reverts if the caller is not the whitelist manager
    function _onlyWhitelistManager() internal view {
        address _whitelistManager = _getRolesStorage().whitelistManager;
        if (_whitelistManager != msg.sender) {
            revert OnlyWhitelistManager(_whitelistManager);
        }
    }

    /// @dev Reverts if the caller is not the valuation manager
    function _onlyValuationManager() internal view {
        address _valuationManager = _getRolesStorage().valuationManager;
        if (_valuationManager != msg.sender) {
            revert OnlyValuationManager(_valuationManager);
        }
    }

    /// @dev Reverts if the caller is not the security council
    function _onlySecurityCouncil() internal view {
        address _securityCouncil = _getRolesStorage().securityCouncil;
        if (_securityCouncil != msg.sender) {
            revert OnlySecurityCouncil(_securityCouncil);
        }
    }

    /// @dev Returns the protocol fee receiver address from the fee registry
    /// @return The protocol fee receiver address
    function _protocolFeeReceiver() internal view returns (address) {
        return _getRolesStorage().feeRegistry.protocolFeeReceiver();
    }

    /// @notice Updates the whitelist manager address
    /// @param _whitelistManager The new whitelist manager address
    function updateWhitelistManager(
        address _whitelistManager
    ) public {
        Roles.RolesStorage storage $ = _getRolesStorage();
        emit WhitelistManagerUpdated($.whitelistManager, _whitelistManager);
        $.whitelistManager = _whitelistManager;
    }

    /// @notice Updates the valuation manager address
    /// @param _valuationManager The new valuation manager address
    function updateValuationManager(
        address _valuationManager
    ) public {
        Roles.RolesStorage storage $ = _getRolesStorage();
        emit ValuationManagerUpdated($.valuationManager, _valuationManager);
        $.valuationManager = _valuationManager;
    }

    /// @notice Updates the fee receiver address
    /// @param _feeReceiver The new fee receiver address
    function updateFeeReceiver(
        address _feeReceiver
    ) public {
        Roles.RolesStorage storage $ = _getRolesStorage();
        emit FeeReceiverUpdated($.feeReceiver, _feeReceiver);
        $.feeReceiver = _feeReceiver;
    }

    /// @notice Updates the safe address (asset custodian)
    /// @param _safe The new safe address
    function updateSafe(
        address _safe
    ) public {
        Roles.RolesStorage storage $ = _getRolesStorage();
        emit SafeUpdated($.safe, _safe);
        $.safe = _safe;
    }

    /// @notice Updates the security council address
    /// @param _securityCouncil The new security council address
    function updateSecurityCouncil(
        address _securityCouncil
    ) public {
        Roles.RolesStorage storage $ = _getRolesStorage();
        emit SecurityCouncilUpdated($.securityCouncil, _securityCouncil);
        $.securityCouncil = _securityCouncil;
    }

    /// @notice Updates the super operator address
    /// @param _superOperator The new super operator address
    function updateSuperOperator(
        address _superOperator
    ) public {
        Roles.RolesStorage storage $ = _getRolesStorage();
        emit SuperOperatorUpdated($.superOperator, _superOperator);
        $.superOperator = _superOperator;
    }

    /// @notice Checks whether an address is the super operator for a given controller
    /// @dev The super operator cannot act on behalf of the protocol fee receiver
    /// @param controller The controller address to check against
    /// @param superOperator The address to check as super operator
    /// @return True if the address is the super operator and the controller is not the protocol fee receiver
    function isSuperOperator(
        address controller,
        address superOperator
    ) public view returns (bool) {
        // SuperOperator can be the super operator of any address except the protocolFeeReceiver
        return _getRolesStorage().superOperator == superOperator && controller != _protocolFeeReceiver();
    }
}
