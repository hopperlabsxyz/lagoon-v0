// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC7540} from "../ERC7540.sol";
import {FeeLib} from "../FeeManager.sol";
import {RolesLib} from "../Roles.sol";
import {IERC7540Deposit} from "../interfaces/IERC7540Deposit.sol";
import {VaultLib} from "./VaultLib.sol";

import {FeeType, State, SyncMode} from "../primitives/Enums.sol";
import {
    AddressNotAllowed,
    AsyncOnly,
    CantDepositNativeToken,
    ERC7540InvalidOperator,
    MaxCapReached,
    NewTotalAssetsMissing,
    OnlyOneRequestAllowed,
    RequestIdNotClaimable,
    RequestNotCancelable,
    WrongNewTotalAssets
} from "../primitives/Errors.sol";
import {
    AsyncOnlyActivated,
    DepositRequestCanceled,
    NewTotalAssetsUpdated,
    RedeemRequestCanceled,
    Referral,
    SettleDeposit,
    SettleRedeem,
    SyncModeUpdated,
    TotalAssetsExpirationUpdated,
    TotalAssetsLifespanUpdated,
    TotalAssetsUpdated
} from "../primitives/Events.sol";
import {SettleData} from "../primitives/Struct.sol";
import {AccessableLib} from "./AccessableLib.sol";
import {PausableLib} from "./PausableLib.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface Vault {
    function safe() external view returns (address);
}

library ERC7540Lib {
    using Math for uint256;
    using SafeERC20 for IERC20;

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.ERC7540")) - 1)) & ~bytes32(uint256(0xff));
    /// @custom:storage-location erc7201:hopper.storage.ERC7540
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

    /// @dev Checks if an address is an operator or super operator for a controller
    /// @param controller The controller address
    /// @param operator The address to check
    /// @return True if the address is an operator or super operator
    function _isOperatorOrSuperOperator(
        address controller,
        address operator
    ) internal view returns (bool) {
        return _isOperator(controller, operator) || _isSuperOperator(controller, operator);
    }

    /// @dev Checks if an address is an operator for a controller
    /// @param controller The controller address
    /// @param operator The address to check
    /// @return True if the address is an operator
    function _isOperator(
        address controller,
        address operator
    ) internal view returns (bool) {
        return _getERC7540Storage().isOperator[controller][operator];
    }

    /// @dev Checks if an address is the super operator for a controller
    /// @param controller The controller address
    /// @param superOperator The address to check
    /// @return True if the address is the super operator
    function _isSuperOperator(
        address controller,
        address superOperator
    ) internal view returns (bool) {
        return RolesLib.isSuperOperator(controller, superOperator);
    }

    /// @dev Reverts if msg.sender is not the controller, an operator, or the super operator
    /// @param controller The controller address to check against
    function _onlyOperatorOrSuperOperator(
        address controller
    ) internal view {
        // Include super operator
        if (controller != msg.sender && !_isOperatorOrSuperOperator(controller, msg.sender)) {
            revert ERC7540InvalidOperator();
        }
    }

    /// @dev Reverts if msg.sender is not the controller or an operator (excludes super operator)
    /// @param controller The controller address to check against
    function _onlyOperator(
        address controller
    ) internal view {
        // Exclude super operator
        if (controller != msg.sender && !_isOperator(controller, msg.sender)) {
            revert ERC7540InvalidOperator();
        }
    }

    /// @notice Updates the totalAssets variable with the newTotalAssets variable
    /// @dev Reverts if newTotalAssets has not been set or if the provided value doesn't match
    /// @param _newTotalAssets The expected new total assets value (must match the stored newTotalAssets)
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

        // If the vault has been set to async-only, we never make totalAssets valid again.
        if (!$.isAsyncOnly) {
            uint128 oldExpiration = $.totalAssetsExpiration;
            uint128 newExpiration = uint128(block.timestamp) + $.totalAssetsLifespan;
            $.totalAssetsExpiration = newExpiration;
            emit TotalAssetsExpirationUpdated(oldExpiration, newExpiration);
        }
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
        uint256 pendingAssets = IERC20(asset()).balanceOf(_pendingSilo);
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

    /// @notice Updates the lifespan duration for total assets validity
    /// @dev Reverts if the vault is in async-only mode since totalAssets is never valid in that mode
    /// @param lifespan The new lifespan duration in seconds
    function updateTotalAssetsLifespan(
        uint128 lifespan
    ) public {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        // When the vault is configured as async-only, totalAssets are never valid again,
        // so updating the lifespan has no effect and is therefore blocked.
        if ($.isAsyncOnly) {
            revert AsyncOnly();
        }

        uint128 oldLifespan = $.totalAssetsLifespan;
        $.totalAssetsLifespan = lifespan;
        emit TotalAssetsLifespanUpdated(oldLifespan, lifespan);
    }

    /// @notice Permanently disables synchronous behavior for the vault.
    /// @dev This sets the vault in async-only mode by making totalAssets permanently invalid.
    ///      It also sets sync mode to None.
    ///      It resets both totalAssetsExpiration and totalAssetsLifespan to zero.
    ///      This mode is irreversible.
    function setAsyncOnly() public {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        $.isAsyncOnly = true;
        uint128 oldExpiration = $.totalAssetsExpiration;
        $.totalAssetsExpiration = 0;
        $.totalAssetsLifespan = 0;
        SyncMode oldMode = $.syncMode;
        $.syncMode = SyncMode.None;

        emit TotalAssetsExpirationUpdated(oldExpiration, 0);
        emit SyncModeUpdated(oldMode, SyncMode.None);
        emit AsyncOnlyActivated();
    }

    /// @notice Updates the sync mode for the vault.
    /// @param _mode The new sync mode.
    /// @dev Reverts if the vault is in async-only mode.
    function setSyncMode(
        SyncMode _mode
    ) public {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        if ($.isAsyncOnly) revert AsyncOnly();

        SyncMode oldMode = $.syncMode;
        $.syncMode = _mode;

        emit SyncModeUpdated(oldMode, _mode);
    }

    /// @dev Returns the decimals offset used in share/asset conversions to mitigate inflation attacks
    /// @return The decimals offset value
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

    /// @notice Returns the maximum amount of assets that a controller can withdraw
    /// @dev Accounts for exit fees and considers both claimable redeem requests and closed vault state
    /// @param controller The address to check the max withdrawable amount for
    /// @return assets The maximum amount of assets that can be withdrawn
    function maxWithdraw(
        address controller
    ) public view returns (uint256 assets) {
        if (Pausable(address(this)).paused()) return 0;
        uint256 shares = claimableRedeemRequest(0, controller);
        if (shares == 0 && VaultLib._getVaultStorage().state == State.Closed) {
            uint256 controllerShares = IERC20(address(this)).balanceOf(controller);
            uint256 _exitFeeShares = FeeLib.computeFee(controllerShares, FeeLib.feeRates().exitRate);
            return IERC4626(address(this)).convertToAssets(controllerShares - _exitFeeShares);
        }
        uint40 lastRedeemId = ERC7540Lib._getERC7540Storage().lastRedeemRequestId[controller];
        // introduced in v0.6.0
        // we need to take into account the exit fee to compute the assets
        uint256 exitFeeShares = FeeLib.computeFee(shares, getSettlementExitFeeRate(lastRedeemId));
        assets = ERC7540(address(this)).convertToAssets(shares - exitFeeShares, lastRedeemId);

        return assets;
    }

    /// @notice Reverts if depositing the given assets would exceed the vault's max cap
    /// @param assets The amount of assets being deposited
    function _onlyUnderMaxCap(
        uint256 assets
    ) public view {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        uint256 siloAssetsBalance = IERC20(asset()).balanceOf(address($.pendingSilo));

        if (IERC4626(address(this)).totalAssets() + assets + siloAssetsBalance > $.maxCap) {
            revert MaxCapReached();
        }
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
            // forge-lint: disable-next-line(unsafe-typecast)
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
            // forge-lint: disable-next-line(unsafe-typecast)
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
            // forge-lint: disable-next-line(unsafe-typecast)
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
            // forge-lint: disable-next-line(unsafe-typecast)
            return $.epochs[uint40(requestId)].depositRequest[controller];
        }
    }

    ////////////////////////////////
    // ## EIP7540 Deposit Flow ## //
    ////////////////////////////////

    /// @dev Unusable when paused. Modifier not needed as it's overridden.
    /// @notice Request deposit of assets into the vault.
    /// @param assets The amount of assets to deposit.
    /// @param controller The controller is the address that will manage the request.
    /// @param owner The owner of the assets.
    function _requestDeposit(
        uint256 assets,
        address controller,
        address owner,
        address referral
    ) public returns (uint256) {
        if (!AccessableLib.isAllowed(owner)) revert AddressNotAllowed(owner);
        if (!AccessableLib.isAllowed(controller)) revert AddressNotAllowed(controller);
        if (!AccessableLib.isAllowed(msg.sender)) revert AddressNotAllowed(msg.sender);

        uint256 claimable = claimableDepositRequest(0, controller);
        if (claimable > 0) _deposit(claimable, controller, controller);

        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();
        uint40 _depositId = $.depositEpochId;
        if ($.lastDepositRequestId[controller] != _depositId) {
            if (pendingDepositRequest(0, controller) > 0) {
                revert OnlyOneRequestAllowed();
            }
            $.lastDepositRequestId[controller] = _depositId;
        }

        if (msg.value != 0) {
            // if user sends eth and the underlying is wETH we will wrap it for him
            if (asset() == address($.wrappedNativeToken)) {
                // enforce maxCap against the actual amount of native assets being deposited
                _onlyUnderMaxCap(msg.value);
                $.pendingSilo.depositEth{value: msg.value}();
                assets = msg.value;
            } else {
                revert CantDepositNativeToken();
            }
        } else {
            _onlyUnderMaxCap(assets);
            IERC20(asset()).safeTransferFrom(owner, address($.pendingSilo), assets);
        }
        $.epochs[_depositId].depositRequest[controller] += assets;

        emit IERC7540Deposit.DepositRequest(controller, owner, _depositId, msg.sender, assets);
        if (referral != address(0)) {
            emit Referral(referral, owner, _depositId, assets);
        }
        return _depositId;
    }

    /// @notice Claim the assets from the vault after a request has been settled.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the shares.
    /// @param controller The controller, who owns the deposit request.
    /// @return shares The corresponding shares.
    function _deposit(
        uint256 assets,
        address receiver,
        address controller
    ) public returns (uint256 shares) {
        // when the super operator initiates the deposit call, we don't check the whitelist
        if (!RolesLib.isSuperOperator(controller, msg.sender)) {
            if (!AccessableLib.isAllowed(controller)) revert AddressNotAllowed(controller);
            if (!AccessableLib.isAllowed(receiver)) revert AddressNotAllowed(receiver);
            if (!AccessableLib.isAllowed(msg.sender)) revert AddressNotAllowed(msg.sender);
        }
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        $.epochs[requestId].depositRequest[controller] -= assets;
        uint256 entryFeeAssets = FeeLib.computeFee(assets, getSettlementEntryFeeRate(requestId));
        shares = ERC7540(address(this)).convertToShares(assets - entryFeeAssets, requestId);

        IERC20(address(this)).safeTransfer(receiver, shares);

        emit IERC4626.Deposit(controller, receiver, assets, shares);
    }

    /// @notice Mint shares from the vault.
    /// @param shares The shares to mint after fees.
    /// @param receiver The receiver of the shares.
    /// @param controller The controller, who owns the mint request.
    /// @return assets The corresponding assets.
    function _mint(
        uint256 shares,
        address receiver,
        address controller
    ) public returns (uint256 assets) {
        // when the super operator initiates the mint call, we don't check the whitelist
        if (!RolesLib.isSuperOperator(controller, msg.sender)) {
            if (!AccessableLib.isAllowed(controller)) revert AddressNotAllowed(controller);
            if (!AccessableLib.isAllowed(receiver)) revert AddressNotAllowed(receiver);
            if (!AccessableLib.isAllowed(msg.sender)) revert AddressNotAllowed(msg.sender);
        }
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        assets = convertToAssets(shares, requestId, Math.Rounding.Ceil);
        // introduced in v0.6.0
        // we need to take into account the entry fee to compute the assets
        assets += FeeLib.computeFeeReverse(assets, getSettlementEntryFeeRate(requestId));
        $.epochs[requestId].depositRequest[controller] -= assets;

        IERC20(address(this)).safeTransfer(receiver, shares);

        emit IERC4626.Deposit(controller, receiver, assets, shares);
    }

    /// @notice Cancels a pending deposit request and returns assets to the controller
    /// @dev Can only be called in the same epoch as the request. Unusable when paused.
    /// @param controller The controller whose deposit request should be canceled
    function cancelRequestDeposit(
        address controller
    ) public {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        if (!AccessableLib.isAllowed(controller)) {
            revert AddressNotAllowed(controller);
        }

        uint40 requestId = $.lastDepositRequestId[controller];
        if (requestId != $.depositEpochId) {
            revert RequestNotCancelable(requestId);
        }

        uint256 requestedAmount = $.epochs[requestId].depositRequest[controller];
        $.epochs[requestId].depositRequest[controller] = 0;
        IERC20(asset()).safeTransferFrom(address($.pendingSilo), controller, requestedAmount);

        emit DepositRequestCanceled(requestId, controller);
    }

    /// @notice Cancels a pending redeem request and returns shares to the controller
    /// @dev Can only be called in the same epoch as the request. Unusable when paused.
    /// @param controller The controller whose redeem request should be canceled
    function cancelRequestRedeem(
        address controller
    ) public {
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastRedeemRequestId[controller];
        if (requestId != $.redeemEpochId) {
            revert RequestNotCancelable(requestId);
        }

        uint256 requestedAmount = $.epochs[requestId].redeemRequest[controller];
        $.epochs[requestId].redeemRequest[controller] = 0;
        ERC7540(address(this)).transmitFrom(address($.pendingSilo), controller, requestedAmount);

        emit RedeemRequestCanceled(requestId, controller, requestedAmount);
    }

    ///////////////////////////////
    // ## EIP7540 Redeem Flow ## //
    ///////////////////////////////

    /// @notice Redeem shares from the vault.
    /// @param shares The shares to redeem.
    /// @param receiver The receiver of the assets.
    /// @param controller The controller, who owns the redeem request.
    /// @return assets The corresponding assets.
    function _redeem(
        uint256 shares,
        address receiver,
        address controller
    ) public returns (uint256 assets) {
        // when the super operator initiates the redeem call, we don't check the whitelist
        if (!RolesLib.isSuperOperator(controller, msg.sender)) {
            if (!AccessableLib.isAllowed(controller)) revert AddressNotAllowed(controller);
            if (!AccessableLib.isAllowed(receiver)) revert AddressNotAllowed(receiver);
            if (!AccessableLib.isAllowed(msg.sender)) revert AddressNotAllowed(msg.sender);
        }
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        $.epochs[requestId].redeemRequest[controller] -= shares;
        // introduced in v0.6.0
        uint256 exitFeeShares = FeeLib.computeFee(shares, getSettlementExitFeeRate(requestId));
        assets = convertToAssets(shares - exitFeeShares, requestId, Math.Rounding.Floor);
        IERC20(asset()).safeTransfer(receiver, assets);

        emit IERC4626.Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    /// @notice Withdraw assets from the vault.
    /// @param assets The assets to withdraw.
    /// @param receiver The receiver of the assets.
    /// @param controller The controller, who owns the request.
    /// @return shares The corresponding shares.
    function _withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) public returns (uint256 shares) {
        // when the super operator initiates the redeem call, we don't check the whitelist
        if (!RolesLib.isSuperOperator(controller, msg.sender)) {
            if (!AccessableLib.isAllowed(controller)) revert AddressNotAllowed(controller);
            if (!AccessableLib.isAllowed(receiver)) revert AddressNotAllowed(receiver);
            if (!AccessableLib.isAllowed(msg.sender)) revert AddressNotAllowed(msg.sender);
        }
        ERC7540.ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        shares = convertToShares(assets, requestId, Math.Rounding.Ceil);
        // introduced in v0.6.0
        // we need to take into account the exit fee to compute the shares
        shares += FeeLib.computeFeeReverse(shares, getSettlementExitFeeRate(requestId));
        $.epochs[requestId].redeemRequest[controller] -= shares;

        IERC20(asset()).safeTransfer(receiver, assets);

        emit IERC4626.Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    ////////////////////////////////
    // ## SETTLEMENT FUNCTIONS ## //
    ////////////////////////////////

    /// @notice Settles pending deposit requests by minting shares and transferring assets to the custodian
    /// @dev Computes entry fees and distributes them. Updates epoch and settlement tracking state.
    /// @param assetsCustodian The address that will receive the deposited assets (typically the safe)
    /// @return sharesToMint The total amount of shares minted during settlement
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
        uint16 _entryFeeRate = FeeLib.feeRates().entryRate;

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = _totalSupply;
        // added in v0.6.0
        // this will be used when a user claims his deposit request
        settleData.entryFeeRate = _entryFeeRate;

        _totalAssets += _pendingAssets;
        _totalSupply += shares;

        // introduced in v0.6.0
        uint256 entryFeeShares = FeeLib.computeFee(shares, _entryFeeRate);
        ERC7540(address(this)).forge(address(this), shares - entryFeeShares);
        FeeLib.takeFees(entryFeeShares, FeeType.Entry, _entryFeeRate, depositSettleId);

        $.totalAssets = _totalAssets;
        $.depositSettleId = depositSettleId + 2;
        $.lastDepositEpochIdSettled = lastDepositEpochIdSettled;

        IERC20(asset()).safeTransferFrom(address($.pendingSilo), assetsCustodian, _pendingAssets);

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

        address _asset = asset();
        uint16 _exitFeeRate = FeeLib.feeRates().exitRate;

        // amount of shares that are pending to be redeemed
        uint256 pendingShares = $.settles[redeemSettleId].pendingShares;

        // out of this amount of shares, we compute the exit fees
        uint256 exitFeeShares = FeeLib.computeFee(pendingShares, _exitFeeRate);

        // the actual amount of assets that will be withdrawn
        uint256 assetsToWithdraw = IERC4626(address(this)).convertToAssets(pendingShares - exitFeeShares);

        uint256 assetsInTheSafe = IERC20(_asset).balanceOf(assetsCustodian);
        if (assetsToWithdraw == 0 || assetsToWithdraw > assetsInTheSafe) return;

        // cache
        uint256 _totalAssets = IERC4626(address(this)).totalAssets();
        uint256 _totalSupply = IERC4626(address(this)).totalSupply();
        uint40 lastRedeemEpochIdSettled = $.redeemEpochId - 2;

        SettleData storage settleData = $.settles[redeemSettleId];

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = _totalSupply;

        // added in v0.6.0
        // this will be used when a user claims his redeem request
        settleData.exitFeeRate = _exitFeeRate;

        // external call
        // we burn the pending shares via a library function
        ERC7540(address(this)).void(address($.pendingSilo), pendingShares);

        // we mint back shares as the exit fees
        FeeLib.takeFees(exitFeeShares, FeeType.Exit, _exitFeeRate, redeemSettleId);

        _totalAssets -= assetsToWithdraw;
        _totalSupply -= (pendingShares - exitFeeShares);

        $.totalAssets = _totalAssets;

        $.redeemSettleId = redeemSettleId + 2;
        $.lastRedeemEpochIdSettled = lastRedeemEpochIdSettled;

        IERC20(_asset).safeTransferFrom(assetsCustodian, address(this), assetsToWithdraw);

        emit SettleRedeem(
            lastRedeemEpochIdSettled, redeemSettleId, _totalAssets, _totalSupply, assetsToWithdraw, pendingShares
        );
    }

    // Introduced with v0.6.0
    /// @notice Returns the exit fee rate for the settlement matching the given epoch ID.
    /// @param epochId The epoch ID.
    /// @return exitFeeRate The exit fee rate.
    function getSettlementExitFeeRate(
        uint40 epochId
    ) public view returns (uint16) {
        uint40 settleId = _getERC7540Storage().epochs[epochId].settleId;
        return _getERC7540Storage().settles[settleId].exitFeeRate;
    }

    /// @notice Returns the entry fee rate for the settlement matching the given epoch ID.
    /// @param epochId The epoch ID.
    /// @return entryFeeRate The entry fee rate.
    function getSettlementEntryFeeRate(
        uint40 epochId
    ) public view returns (uint16) {
        uint40 settleId = _getERC7540Storage().epochs[epochId].settleId;
        return _getERC7540Storage().settles[settleId].entryFeeRate;
    }

    /// @notice Checks if synchronous redeem is currently allowed
    /// @return True if the sync mode permits sync redeems and total assets has not expired
    function isSyncRedeemAllowed() public view returns (bool) {
        SyncMode mode = _getERC7540Storage().syncMode;
        return (mode == SyncMode.SyncRedeem || mode == SyncMode.Both) && isTotalAssetsValid();
    }

    /// @notice Checks if synchronous deposit is currently allowed
    /// @return True if the sync mode permits sync deposits and total assets has not expired
    function isSyncDepositAllowed() public view returns (bool) {
        SyncMode mode = _getERC7540Storage().syncMode;
        return (mode == SyncMode.SyncDeposit || mode == SyncMode.Both) && isTotalAssetsValid();
    }

    /// @notice Checks if the total assets valuation is still valid (not expired)
    /// @return True if the current timestamp is before the total assets expiration
    function isTotalAssetsValid() public view returns (bool) {
        return block.timestamp < _getERC7540Storage().totalAssetsExpiration;
    }

    /// @notice Checks if the contract supports the given interface
    /// @param interfaceId The interface identifier to check
    /// @return True if the interface is supported
    function supportsInterface(
        bytes4 interfaceId
    ) public pure returns (bool) {
        return interfaceId == 0x2f0a18c5 // IERC7575
            || interfaceId == 0xf815c03d // IERC7575 shares
            || interfaceId == 0xce3bbe50 // IERC7540Deposit
            || interfaceId == 0x620ee8e4 // IERC7540Redeem
            || interfaceId == 0xe3bc4e65 // IERC7540
            || interfaceId == type(IERC165).interfaceId;
    }

    /// @dev Returns the underlying asset address of the vault
    /// @return The address of the underlying ERC20 asset
    function asset() internal view returns (address) {
        return IERC4626(address(this)).asset();
    }
}
