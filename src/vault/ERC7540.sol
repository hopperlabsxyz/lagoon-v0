// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {Silo} from "./Silo.sol";
import {IERC7540Deposit} from "./interfaces/IERC7540Deposit.sol";
import {IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
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

import {
    CantDepositNativeToken,
    ERC7540InvalidOperator,
    ERC7540PreviewDepositDisabled,
    ERC7540PreviewMintDisabled,
    ERC7540PreviewRedeemDisabled,
    ERC7540PreviewWithdrawDisabled,
    OnlyOneRequestAllowed,
    RequestIdNotClaimable,
    RequestNotCancelable
} from "./Errors.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

using SafeERC20 for IERC20;
using Math for uint256;

struct EpochData {
    uint40 settleId;
    mapping(address => uint256) depositRequest;
    mapping(address => uint256) redeemRequest;
}

struct SettleData {
    uint256 totalSupply;
    uint256 totalAssets;
}

abstract contract ERC7540Upgradeable is
    IERC7540Redeem,
    IERC7540Deposit,
    ERC20PausableUpgradeable,
    ERC4626Upgradeable
{
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

        $.pendingSilo = new Silo(underlying);
        $.wrappedNativeToken = IWETH9(wrappedNativeToken);
    }

    /// @notice Make sure the caller is an operator or the controller.
    /// @param controller The controller.
    modifier onlyOperator(address controller) {
        if (controller != _msgSender() && !isOperator(controller, _msgSender())) {
            revert ERC7540InvalidOperator();
        }
        _;
    }

    // ## Overrides ##
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
        return ERC4626Upgradeable.decimals();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20PausableUpgradeable, ERC20Upgradeable) {
        return ERC20PausableUpgradeable._update(from, to, value);
    }

    // ## EIP7540 ##
    function isOperator(address controller, address operator) public view returns (bool) {
        return _getERC7540Storage().isOperator[controller][operator];
    }

    /// @dev should not be usable when contract is paused
    function setOperator(address operator, bool approved) external whenNotPaused returns (bool success) {
        address msgSender = _msgSender();
        _getERC7540Storage().isOperator[msgSender][operator] = approved;
        emit OperatorSet(msgSender, operator, approved);
        return true;
    }

    // ## EIP7575 ##
    function share() external view returns (address) {
        return (address(this));
    }

    // ## EIP165 ##
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == 0x2f0a18c5 // IERC7575
            || interfaceId == 0xf815c03d // IERC7575 shares
            || interfaceId == 0xce3bbe50 // IERC7540Deposit
            || interfaceId == 0x620ee8e4 // IERC7540Redeem
            || interfaceId == 0xe3bc4e65 // IERC7540
            || interfaceId == type(IERC165).interfaceId;
    }

    function previewDeposit(uint256) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256 shares) {
        shares;
        if (true) revert ERC7540PreviewDepositDisabled();
    }

    function previewMint(uint256) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256 assets) {
        assets;
        if (true) revert ERC7540PreviewMintDisabled();
    }

    function previewRedeem(uint256) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256 assets) {
        assets;
        if (true) revert ERC7540PreviewRedeemDisabled();
    }

    function previewWithdraw(uint256) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256 shares) {
        shares;
        if (true) revert ERC7540PreviewWithdrawDisabled();
    }

    // ## EIP7540 Deposit Flow ##

    /// @dev Unusable when paused. Modifier not needed as it's overridden.
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) public payable virtual onlyOperator(owner) returns (uint256) {
        uint256 claimable = claimableDepositRequest(0, controller);
        if (claimable > 0) _deposit(claimable, controller, controller);

        ERC7540Storage storage $ = _getERC7540Storage();

        uint40 _depositId = $.depositEpochId;
        if ($.lastDepositRequestId[controller] != _depositId) {
            if (pendingDepositRequest(0, controller) > 0) {
                revert OnlyOneRequestAllowed();
            }
            $.lastDepositRequestId[controller] = _depositId;
        }
        $.epochs[_depositId].depositRequest[controller] += assets;

        // Shoudn't we move native token wrapping outside the ERC7540?
        if (msg.value != 0) {
            // if user sends eth and the underlying is wETH we will wrap it for him
            if (asset() == address($.wrappedNativeToken)) {
                //todo remove this security
                IWETH9($.wrappedNativeToken).deposit{value: msg.value}();
                IWETH9($.wrappedNativeToken).transfer(address($.pendingSilo), msg.value);
            } else {
                revert CantDepositNativeToken();
            }
        } else {
            IERC20(asset()).safeTransferFrom(owner, address($.pendingSilo), assets);
        }

        emit DepositRequest(controller, owner, _depositId, _msgSender(), assets);
        return _depositId;
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

    // todo: replace with the implementation of claimableDepositRequest
    function maxDeposit(address controller) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        return claimableDepositRequest(0, controller);
    }

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _update function.
    /// @notice Claim the assets from the vault after a request has been settled.
    /// @param assets The amount of assets requested to deposit.
    /// @param receiver The receiver of the shares.
    /// @return shares The corresponding shares.
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _deposit(assets, receiver, _msgSender());
    }

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _update function.
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

        _update(address(this), receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
    }

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _update function.
    function mint(
        uint256 shares,
        address receiver
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _mint(shares, receiver, _msgSender());
    }

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _update function.
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

        assets = _convertToAssets(shares, requestId, Math.Rounding.Floor);

        $.epochs[requestId].depositRequest[controller] -= assets;
        _update(address(this), receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
    }

    /// @dev Unusable when paused. Protected by whenNotPaused.
    /// @notice Cancel a deposit request.
    /// @dev It can only be called in the same epoch.
    function cancelRequestDeposit() external whenNotPaused {
        ERC7540Storage storage $ = _getERC7540Storage();
        address msgSender = _msgSender();

        uint40 requestId = $.lastDepositRequestId[msgSender];
        if (requestId != $.depositEpochId) {
            revert RequestNotCancelable(requestId);
        }

        uint256 request = $.epochs[requestId].depositRequest[msgSender];
        if (request != 0) {
            $.epochs[requestId].depositRequest[msgSender] = 0;
            IERC20(asset()).safeTransferFrom(pendingSilo(), msgSender, request);
        }
    }

    // ## EIP7540 Redeem flow ##

    /// @dev Unusable when paused. Protected by ERC20PausableUpgradeable's _update function.
    /// @notice Request redemption of shares from the vault.
    /// @param shares The amount of shares to redeem.
    /// @param controller The controller is the address that will manage the request.
    /// @param owner The owner of the shares.
    /// @return The request ID. It is the current redeem epoch ID.
    function requestRedeem(uint256 shares, address controller, address owner) public virtual returns (uint256) {
        if (_msgSender() != owner && !isOperator(owner, _msgSender())) {
            _spendAllowance(owner, _msgSender(), shares);
        }

        uint256 claimable = claimableRedeemRequest(0, controller);
        if (claimable > 0) _redeem(claimable, controller, controller);

        ERC7540Storage storage $ = _getERC7540Storage();

        uint40 _redeemId = $.redeemEpochId;
        if ($.lastRedeemRequestId[controller] != _redeemId) {
            if (pendingRedeemRequest(0, controller) > 0) {
                revert OnlyOneRequestAllowed();
            }
            $.lastRedeemRequestId[controller] = _redeemId;
        }
        $.epochs[_redeemId].redeemRequest[controller] += shares;

        _update(owner, address($.pendingSilo), shares);

        emit RedeemRequest(controller, owner, _redeemId, _msgSender(), shares);
        return _redeemId;
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

    /// @notice Returns the maximum redeemable shares for a controller.
    /// @param controller The controller.
    /// @return The maximum redeemable shares.
    function maxRedeem(address controller) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        return claimableRedeemRequest(0, controller);
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
    ) internal onlyOperator(controller) whenNotPaused returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        $.epochs[requestId].redeemRequest[controller] -= shares;
        assets = _convertToAssets(shares, requestId, Math.Rounding.Floor);
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
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
    ) internal onlyOperator(controller) whenNotPaused returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint40 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemEpochIdSettled) {
            revert RequestIdNotClaimable();
        }

        shares = convertToShares(assets, requestId);
        $.epochs[requestId].redeemRequest[controller] -= shares;
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
    }

    // ## Conversion functions ##
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

        uint256 _totalAssets = $.settles[$.epochs[requestId].settleId].totalAssets + 1;

        uint256 _totalSupply = $.settles[$.epochs[requestId].settleId].totalSupply + 10 ** _decimalsOffset();

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

        uint256 _totalAssets = $.settles[$.epochs[requestId].settleId].totalAssets + 1;

        uint256 _totalSupply = $.settles[$.epochs[requestId].settleId].totalSupply + 10 ** _decimalsOffset();

        return shares.mulDiv(_totalAssets, _totalSupply, rounding);
    }

    /// @dev This function will deposit the pending assets of the pendingSilo.
    /// and save the deposit parameters in the settleData.
    /// @param assetsCustodian The address that will hold the assets.
    function _settleDeposit(address assetsCustodian) internal {
        address _asset = asset();
        address _pendingSilo = pendingSilo();

        uint256 pendingAssets = IERC20(_asset).balanceOf(_pendingSilo);
        if (pendingAssets == 0) return;

        uint256 shares = _convertToShares(pendingAssets, Math.Rounding.Floor);

        // Then save the deposit parameters
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        uint256 _totalAssets = totalAssets();
        uint40 depositSettleId = $erc7540.depositSettleId;

        SettleData storage settleData = $erc7540.settles[depositSettleId];

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = totalSupply();
        _mint(address(this), shares);

        _totalAssets += pendingAssets;

        $erc7540.totalAssets = _totalAssets;

        $erc7540.depositSettleId = depositSettleId + 2;
        $erc7540.lastDepositEpochIdSettled = $erc7540.depositEpochId - 2;

        IERC20(_asset).safeTransferFrom(_pendingSilo, assetsCustodian, pendingAssets);

        // change this event maybe
        emit Deposit(_msgSender(), address(this), pendingAssets, shares);
    }

    /// @dev This function will redeem the pending shares of the pendingSilo.
    /// and save the redeem parameters in the settleData.
    /// @param assetsCustodian The address that holds the assets.
    function _settleRedeem(address assetsCustodian) internal {
        // address _safe = safe();
        address _asset = asset();
        address _pendingSilo = pendingSilo();

        uint256 pendingShares = balanceOf(_pendingSilo);
        uint256 assetsToWithdraw = _convertToAssets(pendingShares, Math.Rounding.Floor);

        uint256 assetsInTheSafe = IERC20(_asset).balanceOf(assetsCustodian);
        if (assetsToWithdraw == 0 || assetsToWithdraw > assetsInTheSafe) return;

        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        uint256 _totalAssets = totalAssets();
        uint40 redeemSettleId = $erc7540.redeemSettleId;

        SettleData storage settleData = $erc7540.settles[redeemSettleId];

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = totalSupply();

        _burn(_pendingSilo, pendingShares);

        _totalAssets -= assetsToWithdraw;
        $erc7540.totalAssets = _totalAssets;

        $erc7540.redeemSettleId = redeemSettleId + 2;
        $erc7540.lastRedeemEpochIdSettled = $erc7540.redeemEpochId - 2;

        IERC20(_asset).safeTransferFrom(assetsCustodian, address(this), assetsToWithdraw);

        // change this event maybe
        emit Withdraw(_msgSender(), address(this), _pendingSilo, assetsToWithdraw, pendingShares);
    }

    function pendingSilo() public view returns (address) {
        return address(_getERC7540Storage().pendingSilo);
    }

    function redeemId() public view returns (uint256) {
        return _getERC7540Storage().redeemEpochId;
    }

    function depositId() public view returns (uint256) {
        return _getERC7540Storage().depositEpochId;
    }

    function settleDeposit() public virtual;

    /// @dev Settles redeem requests by transferring assets from the safe to the vault
    /// and burning the corresponding shares from the pending silo.
    function settleRedeem() public virtual;
}
