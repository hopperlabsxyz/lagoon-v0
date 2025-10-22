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
import {EpochData, SettleData} from "../primitives/Struct.sol";
import {PausableLib} from "./PausableLib.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library ERC7540Lib {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /// @dev Updates the totalAssets variable with the newTotalAssets variable.
    function updateTotalAssets(
        ERC7540.ERC7540Storage storage self,
        uint256 _newTotalAssets
    ) internal {
        PausableLib.requireNotPaused();
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

    /// @notice Update newTotalAssets variable in order to update totalAssets.
    /// @param _newTotalAssets The new total assets of the vault.
    function updateNewTotalAssets(
        ERC7540.ERC7540Storage storage self,
        uint256 _newTotalAssets
    ) internal {
        PausableLib.requireNotPaused();

        self.epochs[self.depositEpochId].settleId = self.depositSettleId;
        self.epochs[self.redeemEpochId].settleId = self.redeemSettleId;

        address _pendingSilo = address(self.pendingSilo);
        uint256 pendingAssets = IERC20(IERC4626(address(this)).asset()).balanceOf(_pendingSilo);
        uint256 pendingShares = IERC20(address(this)).balanceOf(_pendingSilo);

        if (pendingAssets != 0) {
            self.depositEpochId += 2;
            self.settles[self.depositSettleId].pendingAssets = pendingAssets;
        }
        if (pendingShares != 0) {
            self.redeemEpochId += 2;
            self.settles[self.redeemSettleId].pendingShares = pendingShares;
        }

        self.newTotalAssets = _newTotalAssets;

        emit NewTotalAssetsUpdated(_newTotalAssets);
    }

    function updateTotalAssetsLifespan(
        ERC7540.ERC7540Storage storage self,
        uint128 lifespan
    ) internal {
        uint128 oldLifespan = self.totalAssetsLifespan;
        self.totalAssetsLifespan = lifespan;
        emit TotalAssetsLifespanUpdated(oldLifespan, lifespan);
    }

    function decimalsOffset(
        ERC7540.ERC7540Storage storage self
    ) internal view returns (uint8) {
        return self.decimalsOffset;
    }

    /// @notice Convert shares to assets for a specific epoch/request.
    /// @param shares The shares to convert.
    /// @param requestId The request ID at which the conversion should be done.
    /// @param rounding The rounding method.
    /// @return The corresponding assets.
    function convertToAssets(
        ERC7540.ERC7540Storage storage self,
        uint256 shares,
        uint40 requestId,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        // cache
        uint40 settleId = self.epochs[requestId].settleId;

        uint256 _totalAssets = self.settles[settleId].totalAssets + 1;
        uint256 _totalSupply = self.settles[settleId].totalSupply + 10 ** decimalsOffset(self);

        return shares.mulDiv(_totalAssets, _totalSupply, rounding);
    }

    /// @dev Converts assets to shares for a specific epoch.
    /// @param assets The assets to convert.
    /// @param requestId The request ID.
    /// @param rounding The rounding method.
    /// @return The corresponding shares.
    function convertToShares(
        ERC7540.ERC7540Storage storage self,
        uint256 assets,
        uint40 requestId,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        // cache
        uint40 settleId = self.epochs[requestId].settleId;

        uint256 _totalAssets = self.settles[settleId].totalAssets + 1;
        uint256 _totalSupply = self.settles[settleId].totalSupply + 10 ** decimalsOffset(self);

        return assets.mulDiv(_totalSupply, _totalAssets, rounding);
    }

    /// @notice Returns the pending redeem request for a controller.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return shares The shares that are waiting to be settled.
    function pendingRedeemRequest(
        ERC7540.ERC7540Storage storage self,
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        if (requestId == 0) {
            requestId = self.lastRedeemRequestId[controller];
        }
        if (requestId > self.lastRedeemEpochIdSettled) {
            return self.epochs[uint40(requestId)].redeemRequest[controller];
        }
    }

    /// @notice Returns the claimable redeem request for a controller for a specific request ID.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return shares The shares that can be redeemed.
    function claimableRedeemRequest(
        ERC7540.ERC7540Storage storage self,
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        if (requestId == 0) requestId = self.lastRedeemRequestId[controller];
        if (requestId <= self.lastRedeemEpochIdSettled) {
            return self.epochs[uint40(requestId)].redeemRequest[controller];
        }
    }

    /// @notice Returns the amount of assets that are pending to be deposited for a controller. For a specific request
    /// ID.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return assets The assets that are waiting to be settled.
    function pendingDepositRequest(
        ERC7540.ERC7540Storage storage self,
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        if (requestId == 0) requestId = self.lastDepositRequestId[controller];
        if (requestId > self.lastDepositEpochIdSettled) {
            return self.epochs[uint40(requestId)].depositRequest[controller];
        }
    }

    /// @notice Returns the claimable deposit request for a controller for a specific request ID.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return assets The assets that can be claimed.
    function claimableDepositRequest(
        ERC7540.ERC7540Storage storage self,
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        if (requestId == 0) requestId = self.lastDepositRequestId[controller];
        if (requestId <= self.lastDepositEpochIdSettled) {
            return self.epochs[uint40(requestId)].depositRequest[controller];
        }
    }

    function settleDeposit(
        ERC7540.ERC7540Storage storage self,
        address assetsCustodian
    ) internal returns (uint256 sharesToMint) {
        uint40 depositSettleId = self.depositSettleId;

        uint256 _pendingAssets = self.settles[depositSettleId].pendingAssets;
        if (_pendingAssets == 0) return 0;

        uint256 shares = IERC4626(address(this)).convertToShares(_pendingAssets);

        // cache
        uint256 _totalAssets = IERC4626(address(this)).totalAssets();
        uint256 _totalSupply = IERC4626(address(this)).totalSupply();
        uint40 lastDepositEpochIdSettled = self.depositEpochId - 2;

        SettleData storage settleData = self.settles[depositSettleId];

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = _totalSupply;

        _totalAssets += _pendingAssets;
        _totalSupply += shares;

        // TODO: can we find a way to keep the same logic order and not return sharesToMint and not reimplement the
        // erc20 update logic entirely also IERC20(address(this))._mint(address(this), shares);

        self.totalAssets = _totalAssets;
        self.depositSettleId = depositSettleId + 2;
        self.lastDepositEpochIdSettled = lastDepositEpochIdSettled;

        IERC20(IERC4626(address(this)).asset())
            .safeTransferFrom(address(self.pendingSilo), assetsCustodian, _pendingAssets);

        emit SettleDeposit(
            lastDepositEpochIdSettled, depositSettleId, _totalAssets, _totalSupply, _pendingAssets, shares
        );

        return shares;
    }
}
