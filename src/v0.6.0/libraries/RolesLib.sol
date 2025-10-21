// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Roles} from "../Roles.sol";
import {FeeReceiverUpdated, ValuationManagerUpdated, WhitelistManagerUpdated} from "../primitives/Events.sol";

library RolesLib {
    function updateWhitelistManager(
        Roles.RolesStorage storage roles,
        address _whitelistManager
    ) internal {
        emit WhitelistManagerUpdated(roles.whitelistManager, _whitelistManager);
        roles.whitelistManager = _whitelistManager;
    }

    function updateValuationManager(
        Roles.RolesStorage storage roles,
        address _valuationManager
    ) internal {
        emit ValuationManagerUpdated(roles.valuationManager, _valuationManager);
        roles.valuationManager = _valuationManager;
    }

    function updateFeeReceiver(
        Roles.RolesStorage storage roles,
        address _feeReceiver
    ) internal {
        emit FeeReceiverUpdated(roles.feeReceiver, _feeReceiver);
        roles.feeReceiver = _feeReceiver;
    }
}
