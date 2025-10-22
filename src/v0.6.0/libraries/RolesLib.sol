// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Roles} from "../Roles.sol";
import {FeeReceiverUpdated, ValuationManagerUpdated, WhitelistManagerUpdated} from "../primitives/Events.sol";
import {Constant} from "./constant.sol";

library RolesLib {
    function version() public pure returns (string memory) {
        return Constant.version();
    }

    function updateWhitelistManager(
        Roles.RolesStorage storage self,
        address _whitelistManager
    ) public {
        emit WhitelistManagerUpdated(self.whitelistManager, _whitelistManager);
        self.whitelistManager = _whitelistManager;
    }

    function updateValuationManager(
        Roles.RolesStorage storage self,
        address _valuationManager
    ) public {
        emit ValuationManagerUpdated(self.valuationManager, _valuationManager);
        self.valuationManager = _valuationManager;
    }

    function updateFeeReceiver(
        Roles.RolesStorage storage self,
        address _feeReceiver
    ) public {
        emit FeeReceiverUpdated(self.feeReceiver, _feeReceiver);
        self.feeReceiver = _feeReceiver;
    }
}
