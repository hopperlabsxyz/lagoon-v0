// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Roles} from "../Roles.sol";
import {FeeReceiverUpdated, ValuationManagerUpdated, WhitelistManagerUpdated} from "../primitives/Events.sol";

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

    function updateWhitelistManager(
        address _whitelistManager
    ) public {
        Roles.RolesStorage storage $ = _getRolesStorage();
        emit WhitelistManagerUpdated($.whitelistManager, _whitelistManager);
        $.whitelistManager = _whitelistManager;
    }

    function updateValuationManager(
        address _valuationManager
    ) public {
        Roles.RolesStorage storage $ = _getRolesStorage();
        emit ValuationManagerUpdated($.valuationManager, _valuationManager);
        $.valuationManager = _valuationManager;
    }

    function updateFeeReceiver(
        address _feeReceiver
    ) public {
        Roles.RolesStorage storage $ = _getRolesStorage();
        emit FeeReceiverUpdated($.feeReceiver, _feeReceiver);
        $.feeReceiver = _feeReceiver;
    }
}
