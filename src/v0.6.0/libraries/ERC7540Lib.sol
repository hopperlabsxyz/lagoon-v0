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
import {Constant} from "./Constant.sol";
import {PausableLib} from "./PausableLib.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library ERC7540Lib {
    using Math for uint256;
    using SafeERC20 for IERC20;

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.ERC7540")) - 1)) & ~bytes32(uint256(0xff));
    /// @custom:slot erc7201:hopper.storage.ERC7540
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant erc7540Storage = 0x5c74d456014b1c0eb4368d944667a568313858a3029a650ff0cb7b56f8b57a00;

    /// @notice Returns the ERC7540 storage struct.
    /// @return _erc7540Storage The ERC7540 storage struct.
    function _getERC7540Storage() internal pure returns (ERC7540.ERC7540Storage storage _erc7540Storage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _erc7540Storage.slot := erc7540Storage
        }
    }

    function version() public pure returns (string memory) {
        return Constant.version();
    }

    /// @dev Updates the totalAssets variable with the newTotalAssets variable.
    function updateTotalAssets(
        uint256 _newTotalAssets
    ) public {
        PausableLib.requireNotPaused();
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        uint256 newTotalAssets = $.newTotalAssets;
        if (
            newTotalAssets == type(uint256).max // it means newTotalAssets has not been updated
        ) revert NewTotalAssetsMissing();

        if (_newTotalAssets != newTotalAssets) {
            revert WrongNewTotalAssets();
        }

        $.totalAssets = newTotalAssets;
        $.newTotalAssets = type(uint256).max; // by setting it to max, we ensure that it is not called again

        $.totalAssetsExpiration = uint128(block.timestamp) + $.totalAssetsLifespan;
        emit TotalAssetsUpdated(newTotalAssets);
    }

    /// @notice Update newTotalAssets variable in order to update totalAssets.
    /// @param _newTotalAssets The new total assets of the vault.
    function updateNewTotalAssets(
        uint256 _newTotalAssets
    ) public {
        PausableLib.requireNotPaused();
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        $.epochs[$.depositEpochId].settleId = $.depositSettleId;
        $.epochs[$.redeemEpochId].settleId = $.redeemSettleId;

        address _pendingSilo = address($.pendingSilo);
        uint256 pendingAssets = IERC20(IERC4626(address(this)).asset()).balanceOf(_pendingSilo);
        uint256 pendingShares = IERC20(address(this)).balanceOf(_pendingSilo);

        if (pendingAssets != 0) {
            $.depositEpochId += 2;
            $.settles[$.depositSettleId].pendingAssets = pendingAssets;
        }
        if (pendingShares != 0) {
            $.redeemEpochId += 2;
            $.settles[$.redeemSettleId].pendingShares = pendingShares;
        }

        $.newTotalAssets = _newTotalAssets;

        emit NewTotalAssetsUpdated(_newTotalAssets);
    }

    function updateTotalAssetsLifespan(
        uint128 lifespan
    ) public {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        uint128 oldLifespan = $.totalAssetsLifespan;
        $.totalAssetsLifespan = lifespan;
        emit TotalAssetsLifespanUpdated(oldLifespan, lifespan);
    }

    function decimalsOffset() internal view returns (uint8) {
        return _getERC7540Storage().decimalsOffset;
    }

    /// @notice Convert shares to assets for a specific epoch/request.
    /// @param shares The shares to convert.
    /// @param requestId The request ID at which the conversion should be done.
    /// @param rounding The rounding method.
    /// @return The corresponding assets.
    function convertToAssets(
        uint256 shares,
        uint40 requestId,
        Math.Rounding rounding
    ) public view returns (uint256) {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        // cache
        uint40 settleId = $.epochs[requestId].settleId;

        uint256 _totalAssets = $.settles[settleId].totalAssets + 1;
        uint256 _totalSupply = $.settles[settleId].totalSupply + 10 ** decimalsOffset();

        return shares.mulDiv(_totalAssets, _totalSupply, rounding);
    }

    /// @dev Converts assets to shares for a specific epoch.
    /// @param assets The assets to convert.
    /// @param requestId The request ID.
    /// @param rounding The rounding method.
    /// @return The corresponding shares.
    function convertToShares(
        uint256 assets,
        uint40 requestId,
        Math.Rounding rounding
    ) public view returns (uint256) {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        // cache
        uint40 settleId = $.epochs[requestId].settleId;

        uint256 _totalAssets = $.settles[settleId].totalAssets + 1;
        uint256 _totalSupply = $.settles[settleId].totalSupply + 10 ** decimalsOffset();

        return assets.mulDiv(_totalSupply, _totalAssets, rounding);
    }

    /// @notice Returns the pending redeem request for a controller.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return shares The shares that are waiting to be settled.
    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        if (requestId == 0) {
            requestId = $.lastRedeemRequestId[controller];
        }
        if (requestId > $.lastRedeemEpochIdSettled) {
            return $.epochs[uint40(requestId)].redeemRequest[controller];
        }
    }

    /// @notice Returns the claimable redeem request for a controller for a specific request ID.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return shares The shares that can be redeemed.
    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        if (requestId == 0) requestId = $.lastRedeemRequestId[controller];
        if (requestId <= $.lastRedeemEpochIdSettled) {
            return $.epochs[uint40(requestId)].redeemRequest[controller];
        }
    }

    /// @notice Returns the amount of assets that are pending to be deposited for a controller. For a specific request
    /// ID.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return assets The assets that are waiting to be settled.
    function pendingDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        if (requestId == 0) requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled) {
            return $.epochs[uint40(requestId)].depositRequest[controller];
        }
    }

    /// @notice Returns the claimable deposit request for a controller for a specific request ID.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return assets The assets that can be claimed.
    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        if (requestId == 0) requestId = $.lastDepositRequestId[controller];
        if (requestId <= $.lastDepositEpochIdSettled) {
            return $.epochs[uint40(requestId)].depositRequest[controller];
        }
    }

    ////////////////////////////////
    // ## SETTLEMENT FUNCTIONS ## //
    ////////////////////////////////

    function settleDeposit(
        address assetsCustodian
    ) public returns (uint256 sharesToMint) {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        uint40 depositSettleId = $.depositSettleId;

        uint256 _pendingAssets = $.settles[depositSettleId].pendingAssets;
        if (_pendingAssets == 0) return 0;

        uint256 shares = IERC4626(address(this)).convertToShares(_pendingAssets);

        // cache
        uint256 _totalAssets = IERC4626(address(this)).totalAssets();
        uint256 _totalSupply = IERC4626(address(this)).totalSupply();
        uint40 lastDepositEpochIdSettled = $.depositEpochId - 2;

        SettleData storage settleData = $.settles[depositSettleId];

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = _totalSupply;

        _totalAssets += _pendingAssets;
        _totalSupply += shares;

        ERC7540(address(this)).forge(address(this), shares);

        $.totalAssets = _totalAssets;
        $.depositSettleId = depositSettleId + 2;
        $.lastDepositEpochIdSettled = lastDepositEpochIdSettled;

        IERC20(IERC4626(address(this)).asset())
            .safeTransferFrom(address($.pendingSilo), assetsCustodian, _pendingAssets);

        emit SettleDeposit(
            lastDepositEpochIdSettled, depositSettleId, _totalAssets, _totalSupply, _pendingAssets, shares
        );
    }

    /// @dev This function will redeem the pending shares of the pendingSilo.
    /// and save the redeem parameters in the settleData.
    /// @param assetsCustodian The address that holds the assets.
    function settleRedeem(
        address assetsCustodian
    ) public {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        uint40 redeemSettleId = $.redeemSettleId;

        address _asset = IERC4626(address(this)).asset();

        uint256 pendingShares = $.settles[redeemSettleId].pendingShares;
        uint256 assetsToWithdraw = IERC4626(address(this)).convertToAssets(pendingShares);

        uint256 assetsInTheSafe = IERC20(_asset).balanceOf(assetsCustodian);
        if (assetsToWithdraw == 0 || assetsToWithdraw > assetsInTheSafe) return;

        // cache
        uint256 _totalAssets = IERC4626(address(this)).totalAssets();
        uint256 _totalSupply = IERC4626(address(this)).totalSupply();
        uint40 lastRedeemEpochIdSettled = $.redeemEpochId - 2;

        SettleData storage settleData = $.settles[redeemSettleId];

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = _totalSupply;

        // external call
        ERC7540(address(this)).void(address($.pendingSilo), pendingShares);

        _totalAssets -= assetsToWithdraw;
        _totalSupply -= pendingShares;

        $.totalAssets = _totalAssets;

        $.redeemSettleId = redeemSettleId + 2;
        $.lastRedeemEpochIdSettled = lastRedeemEpochIdSettled;

        IERC20(_asset).safeTransferFrom(assetsCustodian, address(this), assetsToWithdraw);

        emit SettleRedeem(
            lastRedeemEpochIdSettled, redeemSettleId, _totalAssets, _totalSupply, assetsToWithdraw, pendingShares
        );
    }
}
