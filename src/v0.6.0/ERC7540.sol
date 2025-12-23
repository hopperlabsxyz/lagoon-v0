// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Silo} from "./Silo.sol";
import {IERC7540Deposit} from "./interfaces/IERC7540Deposit.sol";
import {IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {ERC7540Lib} from "./libraries/ERC7540Lib.sol";
import {FeeLib} from "./libraries/FeeLib.sol";
import {State} from "./primitives/Enums.sol";
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
} from "./primitives/Errors.sol";
import {
    DepositRequestCanceled,
    NewTotalAssetsUpdated,
    SettleDeposit,
    SettleRedeem,
    TotalAssetsLifespanUpdated,
    TotalAssetsUpdated
} from "./primitives/Events.sol";
import {Rates} from "./primitives/Struct.sol";
import {EpochData, SettleData} from "./primitives/Struct.sol";
import {
    ERC20Upgradeable,
    IERC20,
    IERC20Metadata
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
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
    }

    /// @notice Initializes the ERC7540 contract.
    /// @param underlying The underlying token.
    /// @param wrappedNativeToken The wrapped native token.
    // solhint-disable-next-line func-name-mixedcase
    function __ERC7540_init(
        IERC20 underlying,
        address wrappedNativeToken
    ) internal onlyInitializing {
        ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();

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
    }

    ///////////////
    // MODIFIERS //
    ///////////////

    /// @notice Make sure the caller is an operator or the controller.
    /// @param controller The controller.
    modifier onlyOperator(
        address controller
    ) {
        ERC7540Lib._onlyOperator(controller);
        _;
    }

    /////////////////////
    // ## Overrides ## //
    /////////////////////

    /// @notice Returns the total assets.
    /// @return The total assets.
    function totalAssets() public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        return ERC7540Lib._getERC7540Storage().totalAssets;
    }

    function decimals()
        public
        view
        virtual
        override(ERC4626Upgradeable, ERC20Upgradeable, IERC20Metadata)
        returns (uint8)
    {
        return ERC7540Lib._getERC7540Storage().decimals;
    }

    function _decimalsOffset() internal view virtual override returns (uint8) {
        return ERC7540Lib.decimalsOffset();
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

    function isOperator(
        address controller,
        address operator
    ) public view returns (bool) {
        return ERC7540Lib._getERC7540Storage().isOperator[controller][operator];
    }

    /// @dev should not be usable when contract is paused
    function setOperator(
        address operator,
        bool approved
    ) external whenNotPaused returns (bool success) {
        ERC7540Lib._getERC7540Storage().isOperator[msg.sender][operator] = approved;
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
    function _requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) internal returns (uint256) {
        uint256 claimable = claimableDepositRequest(0, controller);
        if (claimable > 0) _deposit(claimable, controller, controller);

        ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();

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
    function _deposit(
        uint256 assets,
        address receiver,
        address controller
    ) internal virtual returns (uint256 shares) {
        ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();

        uint40 requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        $.epochs[requestId].depositRequest[controller] -= assets;
        uint256 entryFeeAssets = FeeLib.calculateEntryFees(assets, false);
        shares = convertToShares(assets - entryFeeAssets, requestId);

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
    function _mint(
        uint256 shares,
        address receiver,
        address controller
    ) internal virtual returns (uint256 assets) {
        ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();

        uint40 requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        assets = ERC7540Lib.convertToAssets(shares, requestId, Math.Rounding.Ceil);
        assets += FeeLib.calculateEntryFees(assets, true);
        $.epochs[requestId].depositRequest[controller] -= assets;

        _transfer(address(this), receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
    }

    /// @dev Unusable when paused. Protected by whenNotPaused.
    /// @notice Cancel a deposit request.
    /// @dev It can only be called in the same epoch.
    function cancelRequestDeposit() external whenNotPaused {
        ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();

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
    function _requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) internal returns (uint256) {
        if (msg.sender != owner && !isOperator(owner, msg.sender)) {
            _spendAllowance(owner, msg.sender, shares);
        }
        ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();
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
    function _redeem(
        uint256 shares,
        address receiver,
        address controller
    ) internal returns (uint256 assets) {
        ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();

        uint40 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        $.epochs[requestId].redeemRequest[controller] -= shares;
        uint256 exitFeeShares = FeeLib.calculateExitFees(shares, false);
        assets = ERC7540Lib.convertToAssets(shares - exitFeeShares, requestId, Math.Rounding.Floor);
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, controller, assets, shares);
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
    ) internal returns (uint256 shares) {
        ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();

        uint40 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        shares = ERC7540Lib.convertToShares(assets, requestId, Math.Rounding.Ceil);
        shares += FeeLib.calculateExitFees(shares, true);
        $.epochs[requestId].redeemRequest[controller] -= shares;

        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    function forge(
        address to,
        uint256 shares
    ) external {
        require(msg.sender == address(this));
        _mint(to, shares);
    }

    function void(
        address from,
        uint256 shares
    ) external {
        require(msg.sender == address(this));
        _burn(from, shares);
    }

    //////////////////////////
    // ## VIEW FUNCTIONS ## //
    //////////////////////////

    /// @notice Converts assets to shares for a specific epoch.
    /// @param assets The assets to convert.
    /// @param requestId The request ID, which is equivalent to the epoch ID.
    /// @return The corresponding shares.
    function convertToShares(
        uint256 assets,
        uint256 requestId
    ) public view returns (uint256) {
        return ERC7540Lib.convertToShares(assets, uint40(requestId), Math.Rounding.Floor);
    }

    /// @dev Converts shares to assets for a specific epoch.
    /// @param shares The shares to convert.
    /// @param requestId The request ID.
    function convertToAssets(
        uint256 shares,
        uint256 requestId
    ) public view returns (uint256) {
        return ERC7540Lib.convertToAssets(shares, uint40(requestId), Math.Rounding.Floor);
    }

    /// @notice Returns the pending redeem request for a controller.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return shares The shares that are waiting to be settled.
    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        return ERC7540Lib.pendingRedeemRequest(requestId, controller);
    }

    /// @notice Returns the claimable redeem request for a controller for a specific request ID.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return shares The shares that can be redeemed.
    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        return ERC7540Lib.claimableRedeemRequest(requestId, controller);
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
        return ERC7540Lib.pendingDepositRequest(requestId, controller);
    }

    /// @notice Returns the claimable deposit request for a controller for a specific request ID.
    /// @param requestId The request ID.
    /// @param controller The controller.
    /// @return assets The assets that can be claimed.
    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        return ERC7540Lib.claimableDepositRequest(requestId, controller);
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
