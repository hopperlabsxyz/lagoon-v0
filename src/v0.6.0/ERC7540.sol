// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Silo} from "./Silo.sol";
import {IERC7540Deposit} from "./interfaces/IERC7540Deposit.sol";
import {IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {AccessableLib} from "./libraries/AccessableLib.sol";
import {ERC7540Lib} from "./libraries/ERC7540Lib.sol";
import {RolesLib} from "./libraries/RolesLib.sol";
import {VaultLib} from "./libraries/VaultLib.sol";
import {SyncMode} from "./primitives/Enums.sol";
import {
    AddressNotAllowed,
    ERC7540PreviewDepositDisabled,
    ERC7540PreviewMintDisabled,
    ERC7540PreviewRedeemDisabled,
    ERC7540PreviewWithdrawDisabled,
    InvalidController,
    OnlyOneRequestAllowed,
    SyncOperationNotAllowed
} from "./primitives/Errors.sol";
import {DepositSync, MaxCapUpdated, PreMint, SyncModeUpdated} from "./primitives/Events.sol";
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
        SyncMode syncMode;
        // When true, the vault permanently forbids synchronous deposits by keeping totalAssets invalid.
        bool isAsyncOnly;
    }

    /// @notice Initializes the ERC7540 contract.
    /// @param underlying The underlying token.
    /// @param wrappedNativeToken The wrapped native token.
    // solhint-disable-next-line func-name-mixedcase
    function __ERC7540_init(
        IERC20 underlying,
        address wrappedNativeToken,
        uint256 initialTotalAssets,
        address _safe
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
        if (initialTotalAssets > 0) {
            _preMint(initialTotalAssets, _safe);
        }
        _updateMaxCap(type(uint256).max);
        // syncMode defaults to SyncMode.Both (enum value 0)
        emit SyncModeUpdated(SyncMode.Both, SyncMode.Both);
    }

    /// @notice Pre-mints shares to the receiver based on the provided assets amount.
    /// @dev This function is used during vault initialization to set initial total assets and mint corresponding
    /// shares. @dev The shares are calculated using _convertToShares with Floor rounding, and totalAssets is
    /// incremented by the assets amount.
    /// @param assets The amount of assets to convert to shares and add to totalAssets.
    /// @param receiver The address that will receive the minted shares. Must not be address(0).
    /// @custom:reverts ERC20InvalidReceiver If receiver is address(0).
    function _preMint(
        uint256 assets,
        address receiver
    ) internal {
        ERC7540.ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();
        uint256 shares = _convertToShares(assets, Math.Rounding.Floor);
        $.totalAssets += assets;

        // ERC20 mint function
        _mint(receiver, shares);
        emit PreMint(msg.sender, receiver, assets, shares);
        emit DepositSync(msg.sender, receiver, assets, shares);
    }

    ///////////////
    // MODIFIERS //
    ///////////////

    /// @notice Make sure the caller is an operator or the safe (if activated) or the controller.
    /// @param controller The controller.
    modifier onlyOperatorOrSuperOperator(
        address controller
    ) {
        ERC7540Lib._onlyOperatorOrSuperOperator(controller);
        _;
    }

    /// @notice Make sure the caller is an operator or the controller.
    /// @param controller The controller.
    modifier onlyOperator(
        address controller
    ) {
        ERC7540Lib._onlyOperator(controller);
        _;
    }

    /// @notice Make sure new deposit request is under the max cap.
    /// @param assets The amount of assets to deposit or request deposit for.
    function _onlyUnderMaxCap(
        uint256 assets
    ) internal view {
        ERC7540Lib._onlyUnderMaxCap(assets);
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

    function transfer(
        address to,
        uint256 value
    ) public virtual override(ERC20Upgradeable, IERC20) returns (bool) {
        if (AccessableLib.isBlacklistMode()) {
            if (!isAllowed(to)) revert AddressNotAllowed(to);
            if (!isAllowed(msg.sender)) revert AddressNotAllowed(msg.sender);
        }
        return ERC20Upgradeable.transfer(to, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual override(ERC20Upgradeable, IERC20) returns (bool) {
        // if the caller is not the super operator and the blacklist mode is active, we check if the from and to
        // addresses are allowed
        if (!ERC7540Lib._isSuperOperator(from, msg.sender) && AccessableLib.isBlacklistMode()) {
            if (!isAllowed(from)) revert AddressNotAllowed(from);
            if (!isAllowed(to)) revert AddressNotAllowed(to);
            if (!isAllowed(msg.sender)) revert AddressNotAllowed(msg.sender);
        }

        // If the caller is not the super operator, we spend the allowance
        if (!ERC7540Lib._isSuperOperator(from, msg.sender)) {
            address spender = msg.sender;
            _spendAllowance(from, spender, value);
        }
        _transfer(from, to, value);

        return true;
    }

    ///////////////////
    // ## EIP7540 ## //
    ///////////////////

    function isOperator(
        address controller,
        address operator
    ) public view returns (bool) {
        return ERC7540Lib._isOperator(controller, operator);
    }

    function isOperatorOrSuperOperator(
        address controller,
        address operator
    ) internal view returns (bool) {
        return ERC7540Lib._isOperatorOrSuperOperator(controller, operator);
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
        address owner,
        address referral
    ) internal returns (uint256) {
        return ERC7540Lib._requestDeposit(assets, controller, owner, referral);
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
        return ERC7540Lib._deposit(assets, receiver, msg.sender);
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
    ) external virtual onlyOperatorOrSuperOperator(controller) returns (uint256) {
        return ERC7540Lib._deposit(assets, receiver, controller);
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
        return ERC7540Lib._deposit(assets, receiver, controller);
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
    ) external virtual onlyOperatorOrSuperOperator(controller) returns (uint256) {
        return _mint(shares, receiver, controller);
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
    ) internal virtual returns (uint256 assets) {
        return ERC7540Lib._mint(shares, receiver, controller);
    }

    /// @dev Unusable when paused. Protected by whenNotPaused.
    function cancelRequestDeposit() external whenNotPaused {
        ERC7540Lib.cancelRequestDeposit(msg.sender);
    }

    /// @dev Unusable when paused. Protected by whenNotPaused.
    /// @notice Cancel a deposit request on behalf of a controller.
    /// @param controller The controller, who owns the deposit request.
    function cancelRequestDeposit(
        address controller
    ) external whenNotPaused onlyOperatorOrSuperOperator(controller) {
        ERC7540Lib.cancelRequestDeposit(controller);
    }

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _update function.
    /// @notice Cancel a redeem request on behalf of a controller.
    /// @param controller The controller, who owns the redeem request.
    function cancelRequestRedeem(
        address controller
    ) external onlyOperatorOrSuperOperator(controller) {
        ERC7540Lib.cancelRequestRedeem(controller);
    }

    ///////////////////////////////
    // ## EIP7540 REDEEM FLOW ## //
    ///////////////////////////////

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _update function.
    /// @notice Request redemption of shares from the vault.
    /// @param shares The amount of shares to redeem.
    /// @param controller The controller is the address that will manage the request.
    /// @param owner The owner of the shares.
    /// @dev This function was not added to the libbrary because it used multiple internal functions from
    /// the ERC20 underlying contract.
    /// @return The request ID. It is the current redeem epoch ID.
    function _requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) internal returns (uint256) {
        // when the super operator requests a redeem, we don't check the whitelist
        if (!RolesLib.isSuperOperator(controller, msg.sender)) {
            if (!isAllowed(owner)) revert AddressNotAllowed(owner);
            if (!isAllowed(controller)) revert AddressNotAllowed(controller);
            // operator must also be whitelisted
            if (!isAllowed(msg.sender)) revert AddressNotAllowed(msg.sender);
        }

        if (controller == address(0)) {
            revert InvalidController(controller);
        }

        // if the caller is not an operator we use its allowance
        if (msg.sender != owner && !isOperatorOrSuperOperator(owner, msg.sender)) {
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
        return ERC7540Lib._redeem(shares, receiver, controller);
    }

    /// @notice Withdraw assets from the vault.
    /// @param assets The amount of assets to withdraw.
    /// @param receiver The receiver of the assets.
    /// @param controller The controller, who owns the withdraw request.
    /// @return shares The corresponding shares.
    function _withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) internal returns (uint256 shares) {
        return ERC7540Lib._withdraw(assets, receiver, controller);
    }

    ////////////////////////////////////
    // ## FORGE AND VOID FUNCTIONS ## //
    ////////////////////////////////////

    /// @notice Forges shares to the receiver. This function is used to allow a mint shares from a library function.
    /// @param to The receiver of the shares.
    /// @param shares The amount of shares to forge.
    function forge(
        address to,
        uint256 shares
    ) external {
        // only the vault can mint shares
        require(msg.sender == address(this));
        _mint(to, shares);
    }

    /// @notice Burns shares from the from address. This function is used to allow a burn shares from a library
    /// function. @param from The address from which the shares will be burned.
    /// @param shares The amount of shares to burn.
    function void(
        address from,
        uint256 shares
    ) external {
        // only the vault can burn shares
        require(msg.sender == address(this));
        _burn(from, shares);
    }

    /// @notice Transfers shares without any checks. This function is used to allow a transfer shares from a library
    /// function.
    /// @param from The address from which the shares will be transferred.
    /// @param to The address to which the shares will be transferred.
    /// @param value The amount of shares to transfer.
    function transmitFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        // only the vault can burn shares
        require(msg.sender == address(this));
        ERC20Upgradeable._transfer(from, to, value);
        return true;
    }

    function _updateMaxCap(
        uint256 _maxCap
    ) internal {
        ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();
        emit MaxCapUpdated({previousMaxCap: $.maxCap, maxCap: _maxCap});
        $.maxCap = _maxCap;
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
        // forge-lint: disable-next-line(unsafe-typecast)
        return ERC7540Lib.convertToShares(assets, uint40(requestId), Math.Rounding.Floor);
    }

    /// @dev Converts shares to assets for a specific epoch.
    /// @param shares The shares to convert.
    /// @param requestId The request ID.
    function convertToAssets(
        uint256 shares,
        uint256 requestId
    ) public view returns (uint256) {
        // forge-lint: disable-next-line(unsafe-typecast)
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
        return ERC7540Lib.supportsInterface(interfaceId);
    }

    function settlementEntryFeeRate(
        uint40 settleId
    ) public view returns (uint16) {
        return ERC7540Lib._getERC7540Storage().settles[settleId].entryFeeRate;
    }

    function settlementExitFeeRate(
        uint40 settleId
    ) public view returns (uint16) {
        return ERC7540Lib._getERC7540Storage().settles[settleId].exitFeeRate;
    }

    /// @notice Returns true if the vault has permanently given up the ability to be synchronous.
    /// @dev When true, totalAssets will always be considered invalid and only async flows are allowed.
    function isAsyncOnly() public view returns (bool) {
        return ERC7540Lib._getERC7540Storage().isAsyncOnly;
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

    function isAllowed(
        address account
    ) public view virtual returns (bool);
}
