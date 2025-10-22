// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC7540} from "../ERC7540.sol";
import {
    CantDepositNativeToken,
    ERC7540InvalidOperator,
    ERC7540PreviewDepositDisabled,
    ERC7540PreviewMintDisabled,
    ERC7540PreviewRedeemDisabled,
    ERC7540PreviewWithdrawDisabled,
    NewTotalAssetsMissing,
    OnlyOneRequestAllowed,
    RequestIdNotClaimable,
    RequestNotCancelable,
    WrongNewTotalAssets
} from "../primitives/Errors.sol";
import {
    DepositRequestCanceled,
    NewTotalAssetsUpdated,
    SettleDeposit,
    SettleRedeem,
    TotalAssetsLifespanUpdated,
    TotalAssetsUpdated
} from "../primitives/Events.sol";

library ERC7540Lib {
    /// @dev Updates the totalAssets variable with the newTotalAssets variable.
    function updateTotalAssets(
        ERC7540.ERC7540Storage storage self,
        uint256 _newTotalAssets
    ) internal {
        uint256 newTotalAssets = self.newTotalAssets;

        if (
            newTotalAssets == type(uint256).max // it means newTotalAssets has not been updated
        ) revert NewTotalAssetsMissing();

        if (_newTotalAssets != newTotalAssets) {
            revert WrongNewTotalAssets();
        }

        self.totalAssets = newTotalAssets;
        self.newTotalAssets = type(uint256).max; // by setting it to max, we ensure that it is not called again

        self.totalAssetsExpiration = uint128(block.timestamp) + self.totalAssetsLifespan;
        emit TotalAssetsUpdated(newTotalAssets);
    }

    function updateTotalAssetsLifespan(
        ERC7540.ERC7540Storage storage self,
        uint128 lifespan
    ) internal {
        uint128 oldLifespan = self.totalAssetsLifespan;
        self.totalAssetsLifespan = lifespan;
        emit TotalAssetsLifespanUpdated(oldLifespan, lifespan);
    }
}
