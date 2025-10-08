// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {Silo} from "./Silo.sol";
import {IERC7540Deposit} from "./interfaces/IERC7540Deposit.sol";
import {IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {
    CantDepositNativeToken,
    ERC7540InvalidOperator,
    ERC7540PreviewDepositDisabled,
    ERC7540PreviewMintDisabled,
    ERC7540PreviewRedeemDisabled,
    ERC7540PreviewWithdrawDisabled,
    MaxCapReached,
    NewTotalAssetsMissing,
    OnlyOneRequestAllowed,
    RequestIdNotClaimable,
    RequestNotCancelable,
    WrongNewTotalAssets
} from "./primitives/Errors.sol";
import {
    DepositRequestCanceled,
    GaveUpOperatorPrivileges,
    MaxCapUpdated,
    NewTotalAssetsUpdated,
    SettleDeposit,
    SettleRedeem,
    TotalAssetsLifespanUpdated,
    TotalAssetsUpdated
} from "./primitives/Events.sol";
import {EpochData, SettleData} from "./primitives/Struct.sol";
import {
    ERC20Upgradeable,
    IERC20,
    IERC20Metadata
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

using SafeERC20 for IERC20;
using Math for uint256;

/// @title ERC7540Upgradeable
/// @dev An implementation of the ERC7540 standard. It defines the core data structures and functions necessary
/// to do requests and process them.
abstract contract ERC7540 is IERC7540Redeem, IERC7540Deposit, ERC20PausableUpgradeable, ERC4626Upgradeable {
    /// @custom:storage-location erc7201:hopper.storage.ERC7540
    /// @param totalAssets The total assets.
    /// @param depositEpochId The current deposit epoch ID.
    /// @param depositSettleId The current deposit settle ID.
    /// @param lastDepositEpochIdSettled The last deposit epoch ID settled.
    /// @param redeemEpochId The current redeem epoch ID.
    /// @param redeemSettleId The current redeem settle ID.
    /// @param lastRedeemEpochIdSettled The last redeem epoch ID settled.
    /// @param epochs A mapping of epochs data.
    /// @param settles A mapping of settle data.
    /// @param lastDepositRequestId A mapping of the last deposit request ID for each user.
    /// @param lastRedeemRequestId A mapping of the last redeem request ID for each user.
    /// @param isOperator A mapping of operators for each user.
    /// @param pendingSilo The pending silo.
    /// @param wrappedNativeToken The wrapped native token. WETH9 for ethereum.
    struct ERC7540Storage {
        uint256 totalAssets;
        uint256 newTotalAssets;
        uint40 depositEpochId;
        uint40 depositSettleId;
        uint40 lastDepositEpochIdSettled;
        uint40 redeemEpochId;
        uint40 redeemSettleId;
        uint40 lastRedeemEpochIdSettled;
        mapping(uint40 epochId => EpochData) epochs;
        mapping(uint40 settleId => SettleData) settles;
        mapping(address user => uint40 epochId) lastDepositRequestId;
        mapping(address user => uint40 epochId) lastRedeemRequestId;
        mapping(address controller => mapping(address operator => bool)) isOperator;
        Silo pendingSilo;
        IWETH9 wrappedNativeToken;
        uint8 decimals;
        uint8 decimalsOffset;
        // New variables introduce with v0.5.0
        uint128 totalAssetsExpiration;
        uint128 totalAssetsLifespan;
        // New variables introduce with v0.6.0
        uint256 maxCap;
        bool gaveUpOperatorPrivileges;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.ERC7540")) - 1)) & ~bytes32(uint256(0xff));
    /// @custom:slot erc7201:hopper.storage.ERC7540
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant erc7540Storage = 0x5c74d456014b1c0eb4368d944667a568313858a3029a650ff0cb7b56f8b57a00;

    /// @notice Returns the ERC7540 storage struct.
    /// @return _erc7540Storage The ERC7540 storage struct.
    function _getERC7540Storage() internal pure returns (ERC7540Storage storage _erc7540Storage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _erc7540Storage.slot := erc7540Storage
        }
    }

    /// @notice Initializes the ERC7540 contract.
    /// @param underlying The underlying token.
    /// @param wrappedNativeToken The wrapped native token.
    // solhint-disable-next-line func-name-mixedcase
    function __ERC7540_init(IERC20 underlying, address wrappedNativeToken) internal onlyInitializing {
        ERC7540Storage storage $ = _getERC7540Storage();

        $.depositEpochId = 1;
        $.redeemEpochId = 2;

        $.depositSettleId = 1;
        $.redeemSettleId = 2;

        $.pendingSilo = new Silo(underlying, wrappedNativeToken);
        $.wrappedNativeToken = IWETH9(wrappedNativeToken);
        $.newTotalAssets = type(uint256).max;

        uint8 underlyingDecimals = ERC20Upgradeable(asset()).decimals();
        if (underlyingDecimals >= 18) {
            $.decimals = underlyingDecimals;
        } else {
            $.decimals = 18;
            unchecked {
                $.decimalsOffset = 18 - underlyingDecimals;
            }
        }
        $.maxCap = type(uint256).max;
    }

    ///////////////
    // MODIFIERS //
    ///////////////

    /// @notice Make sure the caller is an operator or the controller.
    /// @param controller The controller.
    modifier onlyOperator(
        address controller
    ) {
        bool safeAsOperator = msg.sender == safe() && !_getERC7540Storage().gaveUpOperatorPrivileges;
        if (controller != msg.sender && !isOperator(controller, msg.sender) && !safeAsOperator) {
            revert ERC7540InvalidOperator();
        }
        _;
    }

    /// @notice Make sure new deposit request is under the max cap.
    function _onlyUnderMaxCap(uint256 assets, uint256 siloAssetsBalance) internal {
        if (totalAssets() + assets + siloAssetsBalance > _getERC7540Storage().maxCap) {
            revert MaxCapReached();
        }
    }

    /////////////////////
    // ## Overrides ## //
    /////////////////////

    /// @notice Returns the total assets.
    /// @return The total assets.
    function totalAssets() public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.totalAssets;
    }

    function decimals()
        public
        view
        virtual
        override(ERC4626Upgradeable, ERC20Upgradeable, IERC20Metadata)
        returns (uint8)
    {
        return _getERC7540Storage().decimals;
    }

    function _decimalsOffset() internal view virtual override returns (uint8) {
        return _getERC7540Storage().decimalsOffset;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20PausableUpgradeable, ERC20Upgradeable) {
        return ERC20PausableUpgradeable._update(from, to, value);
    }

    ///////////////////
    // ## EIP7540 ## //
    ///////////////////

    function isOperator(address controller, address operator) public view returns (bool) {
        return _getERC7540Storage().isOperator[controller][operator];
    }

    /// @dev should not be usable when contract is paused
    function setOperator(address operator, bool approved) external whenNotPaused returns (bool success) {
        _getERC7540Storage().isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    function previewDeposit(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        revert ERC7540PreviewDepositDisabled();
    }

    function previewMint(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        revert ERC7540PreviewMintDisabled();
    }

    function previewRedeem(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        revert ERC7540PreviewRedeemDisabled();
    }

    function previewWithdraw(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        revert ERC7540PreviewWithdrawDisabled();
    }

    ////////////////////////////////
    // ## EIP7540 Deposit Flow ## //
    ////////////////////////////////

    /// @dev Unusable when paused. Modifier not needed as it's overridden.
    /// @notice Request deposit of assets into the vault.
    /// @param assets The amount of assets to deposit.
    /// @param controller The controller is the address that will manage the request.
    /// @param owner The owner of the assets.
    function _requestDeposit(uint256 assets, address controller, address owner) internal returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();

        _onlyUnderMaxCap(assets, IERC20(asset()).balanceOf(address($.pendingSilo)));

        uint256 claimable = claimableDepositRequest(0, controller);
        if (claimable > 0) _deposit(claimable, controller, controller);

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
                $.pendingSilo.depositEth{value: msg.value}();
                assets = msg.value;
            } else {
                revert CantDepositNativeToken();
            }
        } else {
            IERC20(asset()).safeTransferFrom(owner, address($.pendingSilo), assets);
        }
        $.epochs[_depositId].depositRequest[controller] += assets;

        emit DepositRequest(controller, owner, _depositId, msg.sender, assets);
        return _depositId;
    }

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _transfer function.
    /// @notice Claim the assets from the vault after a request has been settled.
    /// @param assets The amount of assets requested to deposit.
    /// @param receiver The receiver of the shares.
    /// @return shares The corresponding shares.
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _deposit(assets, receiver, msg.sender);
    }

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _transfer function.
    /// @notice Claim the assets from the vault after a request has been settled.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the shares.
    /// @param controller The controller, who owns the deposit request.
    /// @return shares The corresponding shares.
    function deposit(
        uint256 assets,
        address receiver,
        address controller
    ) external virtual onlyOperator(controller) returns (uint256) {
        return _deposit(assets, receiver, controller);
    }

    /// @notice Claim the assets from the vault after a request has been settled.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the shares.
    /// @param controller The controller, who owns the deposit request.
    /// @return shares The corresponding shares.
    function _deposit(uint256 assets, address receiver, address controller) internal virtual returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        $.epochs[requestId].depositRequest[controller] -= assets;
        shares = convertToShares(assets, requestId);

        _transfer(address(this), receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
    }

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _transfer function.
    function mint(
        uint256 shares,
        address receiver
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _mint(shares, receiver, msg.sender);
    }

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _transfer function.
    /// @notice Claim shares from the vault after a request deposit.
    function mint(
        uint256 shares,
        address receiver,
        address controller
    ) external virtual onlyOperator(controller) returns (uint256) {
        return _mint(shares, receiver, controller);
    }

    /// @notice Mint shares from the vault.
    /// @param shares The shares to mint.
    /// @param receiver The receiver of the shares.
    /// @param controller The controller, who owns the mint request.
    /// @return assets The corresponding assets.
    function _mint(uint256 shares, address receiver, address controller) internal virtual returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        assets = _convertToAssets(shares, requestId, Math.Rounding.Ceil);

        $.epochs[requestId].depositRequest[controller] -= assets;
        _transfer(address(this), receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
    }

    /// @dev Unusable when paused. Protected by whenNotPaused.
    /// @notice Cancel a deposit request.
    /// @dev It can only be called in the same epoch.
    function cancelRequestDeposit() external whenNotPaused {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastDepositRequestId[msg.sender];
        if (requestId != $.depositEpochId) {
            revert RequestNotCancelable(requestId);
        }

        uint256 requestedAmount = $.epochs[requestId].depositRequest[msg.sender];
        $.epochs[requestId].depositRequest[msg.sender] = 0;
        IERC20(asset()).safeTransferFrom(address($.pendingSilo), msg.sender, requestedAmount);

        emit DepositRequestCanceled(requestId, msg.sender);
    }

    ///////////////////////////////
    // ## EIP7540 REDEEM FLOW ## //
    ///////////////////////////////

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _update function.
    /// @notice Request redemption of shares from the vault.
    /// @param shares The amount of shares to redeem.
    /// @param controller The controller is the address that will manage the request.
    /// @param owner The owner of the shares.
    /// @return The request ID. It is the current redeem epoch ID.
    function _requestRedeem(uint256 shares, address controller, address owner) internal returns (uint256) {
        if (msg.sender != owner && !isOperator(owner, msg.sender)) {
            _spendAllowance(owner, msg.sender, shares);
        }
        ERC7540Storage storage $ = _getERC7540Storage();
        uint256 claimable = claimableRedeemRequest(0, controller);
        if (claimable > 0) _redeem(claimable, controller, controller);

        uint40 _redeemId = $.redeemEpochId;
        if ($.lastRedeemRequestId[controller] != _redeemId) {
            if (pendingRedeemRequest(0, controller) > 0) {
                revert OnlyOneRequestAllowed();
            }
            $.lastRedeemRequestId[controller] = _redeemId;
        }
        $.epochs[_redeemId].redeemRequest[controller] += shares;

        _update(owner, address($.pendingSilo), shares);

        emit RedeemRequest(controller, owner, _redeemId, msg.sender, shares);
        return _redeemId;
    }

    /// @notice Redeem shares from the vault.
    /// @param shares The shares to redeem.
    /// @param receiver The receiver of the assets.
    /// @param controller The controller, who owns the redeem request.
    /// @return assets The corresponding assets.
    function _redeem(uint256 shares, address receiver, address controller) internal returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        $.epochs[requestId].redeemRequest[controller] -= shares;
        assets = _convertToAssets(shares, requestId, Math.Rounding.Floor);
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    /// @notice Withdraw assets from the vault.
    /// @param assets The assets to withdraw.
    /// @param receiver The receiver of the assets.
    /// @param controller The controller, who owns the request.
    /// @return shares The corresponding shares.
    function _withdraw(uint256 assets, address receiver, address controller) internal returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        shares = _convertToShares(assets, requestId, Math.Rounding.Ceil);
        $.epochs[requestId].redeemRequest[controller] -= shares;
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    ////////////////////////////////
    // ## SETTLEMENT FUNCTIONS ## //
    ////////////////////////////////

    /// @dev This function will deposit the pending assets of the pendingSilo.
    /// and save the deposit parameters in the settleData.
    /// @param assetsCustodian The address that will hold the assets.
    function _settleDeposit(
        address assetsCustodian
    ) internal {
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        uint40 depositSettleId = $erc7540.depositSettleId;

        uint256 _pendingAssets = $erc7540.settles[depositSettleId].pendingAssets;
        if (_pendingAssets == 0) return;

        uint256 shares = _convertToShares(_pendingAssets, Math.Rounding.Floor);

        // cache
        uint256 _totalAssets = totalAssets();
        uint256 _totalSupply = totalSupply();
        uint40 lastDepositEpochIdSettled = $erc7540.depositEpochId - 2;

        SettleData storage settleData = $erc7540.settles[depositSettleId];

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = _totalSupply;

        _mint(address(this), shares);

        _totalAssets += _pendingAssets;
        _totalSupply += shares;

        $erc7540.totalAssets = _totalAssets;
        $erc7540.depositSettleId = depositSettleId + 2;
        $erc7540.lastDepositEpochIdSettled = lastDepositEpochIdSettled;

        IERC20(asset()).safeTransferFrom(address($erc7540.pendingSilo), assetsCustodian, _pendingAssets);

        emit SettleDeposit(
            lastDepositEpochIdSettled, depositSettleId, _totalAssets, _totalSupply, _pendingAssets, shares
        );
    }

    /// @dev This function will redeem the pending shares of the pendingSilo.
    /// and save the redeem parameters in the settleData.
    /// @param assetsCustodian The address that holds the assets.
    function _settleRedeem(
        address assetsCustodian
    ) internal {
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        uint40 redeemSettleId = $erc7540.redeemSettleId;

        address _asset = asset();

        uint256 pendingShares = $erc7540.settles[redeemSettleId].pendingShares;
        uint256 assetsToWithdraw = _convertToAssets(pendingShares, Math.Rounding.Floor);

        uint256 assetsInTheSafe = IERC20(_asset).balanceOf(assetsCustodian);
        if (assetsToWithdraw == 0 || assetsToWithdraw > assetsInTheSafe) return;

        // cache
        uint256 _totalAssets = totalAssets();
        uint256 _totalSupply = totalSupply();
        uint40 lastRedeemEpochIdSettled = $erc7540.redeemEpochId - 2;

        SettleData storage settleData = $erc7540.settles[redeemSettleId];

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = _totalSupply;

        _burn(address($erc7540.pendingSilo), pendingShares);

        _totalAssets -= assetsToWithdraw;
        _totalSupply -= pendingShares;

        $erc7540.totalAssets = _totalAssets;

        $erc7540.redeemSettleId = redeemSettleId + 2;
        $erc7540.lastRedeemEpochIdSettled = lastRedeemEpochIdSettled;

        IERC20(_asset).safeTransferFrom(assetsCustodian, address(this), assetsToWithdraw);

        emit SettleRedeem(
            lastRedeemEpochIdSettled, redeemSettleId, _totalAssets, _totalSupply, assetsToWithdraw, pendingShares
        );
    }

    ////////////////////////////////////////
    // ## TOTALASSETS UPDATE FUNCTIONS ## //
    ////////////////////////////////////////

    /// @notice Update newTotalAssets variable in order to update totalAssets.
    /// @param _newTotalAssets The new total assets of the vault.
    function _updateNewTotalAssets(
        uint256 _newTotalAssets
    ) internal whenNotPaused {
        ERC7540Storage storage $ = _getERC7540Storage();

        $.epochs[$.depositEpochId].settleId = $.depositSettleId;
        $.epochs[$.redeemEpochId].settleId = $.redeemSettleId;

        address _pendingSilo = address($.pendingSilo);
        uint256 pendingAssets = IERC20(asset()).balanceOf(_pendingSilo);
        uint256 pendingShares = balanceOf(_pendingSilo);

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

    /// @dev Updates the totalAssets variable with the newTotalAssets variable.
    function _updateTotalAssets(
        uint256 _newTotalAssets
    ) internal whenNotPaused {
        ERC7540Storage storage $ = _getERC7540Storage();

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

    function _updateTotalAssetsLifespan(
        uint128 lifespan
    ) internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        uint128 oldLifespan = $.totalAssetsLifespan;
        $.totalAssetsLifespan = lifespan;
        emit TotalAssetsLifespanUpdated(oldLifespan, lifespan);
    }

    function _updateMaxCap(
        uint256 maxCap
    ) internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        emit MaxCapUpdated({previousMaxCap: $.maxCap, maxCap: maxCap});
        $.maxCap = maxCap;
    }

    function _giveUpOperatorPrivileges() internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        $.gaveUpOperatorPrivileges = true;
        emit GaveUpOperatorPrivileges();
    }

    //////////////////////////
    // ## VIEW FUNCTIONS ## //
    //////////////////////////

    /// @notice Converts assets to shares for a specific epoch.
    /// @param assets The assets to convert.
    /// @param requestId The request ID, which is equivalent to the epoch ID.
    /// @return The corresponding shares.
    function convertToShares(uint256 assets, uint256 requestId) public view returns (uint256) {
        return _convertToShares(assets, uint40(requestId), Math.Rounding.Floor);
    }

    /// @dev Converts assets to shares for a specific epoch.
    /// @param assets The assets to convert.
    /// @param requestId The request ID.
    /// @param rounding The rounding method.
    /// @return The corresponding shares.
    function _convertToShares(
        uint256 assets,
        uint40 requestId,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();

        // cache
        uint40 settleId = $.epochs[requestId].settleId;

        uint256 _totalAssets = $.settles[settleId].totalAssets + 1;
        uint256 _totalSupply = $.settles[settleId].totalSupply + 10 ** _decimalsOffset();

        return assets.mulDiv(_totalSupply, _totalAssets, rounding);
    }

    /// @dev Converts shares to assets for a specific epoch.
    /// @param shares The shares to convert.
    /// @param requestId The request ID.
    function convertToAssets(uint256 shares, uint256 requestId) public view returns (uint256) {
        return _convertToAssets(shares, uint40(requestId), Math.Rounding.Floor);
    }

    /// @notice Convert shares to assets for a specific epoch/request.
    /// @param shares The shares to convert.
    /// @param requestId The request ID at which the conversion should be done.
    /// @param rounding The rounding method.
    /// @return The corresponding assets.
    function _convertToAssets(
        uint256 shares,
        uint40 requestId,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();

        // cache
        uint40 settleId = $.epochs[requestId].settleId;

        uint256 _totalAssets = $.settles[settleId].totalAssets + 1;
        uint256 _totalSupply = $.settles[settleId].totalSupply + 10 ** _decimalsOffset();

        return shares.mulDiv(_totalAssets, _totalSupply, rounding);
    }

    /// @notice Returns the pending redeem request for a controller.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return shares The shares that are waiting to be settled.
    function pendingRedeemRequest(uint256 requestId, address controller) public view returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

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
    function claimableRedeemRequest(uint256 requestId, address controller) public view returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

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
    function pendingDepositRequest(uint256 requestId, address controller) public view returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0) requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled) {
            return $.epochs[uint40(requestId)].depositRequest[controller];
        }
    }

    /// @notice Returns the claimable deposit request for a controller for a specific request ID.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return assets The assets that can be claimed.
    function claimableDepositRequest(uint256 requestId, address controller) public view returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0) requestId = $.lastDepositRequestId[controller];
        if (requestId <= $.lastDepositEpochIdSettled) {
            return $.epochs[uint40(requestId)].depositRequest[controller];
        }
    }

    ///////////////////
    // ## EIP7575 ## //
    ///////////////////

    function share() external view returns (address) {
        return (address(this));
    }

    ///////////////////
    // ## EIP165 ## //
    //////////////////

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
        return interfaceId == 0x2f0a18c5 // IERC7575
            || interfaceId == 0xf815c03d // IERC7575 shares
            || interfaceId == 0xce3bbe50 // IERC7540Deposit
            || interfaceId == 0x620ee8e4 // IERC7540Redeem
            || interfaceId == 0xe3bc4e65 // IERC7540
            || interfaceId == type(IERC165).interfaceId;
    }

    //////////////////////////////////
    // ## FUNCTIONS TO IMPLEMENT ## //
    //////////////////////////////////

    /// @dev Settles deposit requests by transferring assets from the pendingSilo to the safe
    /// and minting the corresponding shares to vault.
    /// The function is not implemented here and must be implemented.
    function settleDeposit(
        uint256 _newTotalAssets
    ) public virtual;

    /// @dev Settles redeem requests by transferring assets from the safe to the vault
    /// and burning the corresponding shares from the pending silo.
    /// The function is not implemented here and must be implemented.
    function settleRedeem(
        uint256 _newTotalAssets
    ) public virtual;

    function safe() public view virtual returns (address);
}
