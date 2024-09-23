//SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {IERC7540Deposit} from "./interfaces/IERC7540Deposit.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC20, ERC20Upgradeable, IERC20Metadata} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Silo} from "./Silo.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
// import {ERC7540PreviewDepositDisabled, ERC7540PreviewMintDisabled, ERC7540PreviewRedeemDisabled, ERC7540PreviewWithdrawDisabled, OnlyOneRequestAllowed, RequestNotCancelable, ERC7540InvalidOperator, ZeroPendingDeposit, ZeroPendingRedeem, RequestIdNotClaimable, CantDepositNativeToken} from "./Errors.sol";

using SafeERC20 for IERC20;
using Math for uint256;

error ERC7540PreviewDepositDisabled();
error ERC7540PreviewMintDisabled();
error ERC7540PreviewRedeemDisabled();
error ERC7540PreviewWithdrawDisabled();
error OnlyOneRequestAllowed();
error RequestNotCancelable();

error ERC7540InvalidOperator();
error ZeroPendingDeposit();
error ZeroPendingRedeem();

error RequestIdNotClaimable();

error CantDepositNativeToken();

struct EpochData {
    uint256 settleId;
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
    struct ERC7540Storage {
        uint256 totalAssets;
        uint256 depositEpochId;
        uint256 redeemEpochId;
        uint256 depositSettleId;
        uint256 redeemSettleId;
        uint256 lastRedeemEpochIdSettled;
        uint256 lastDepositEpochIdSettled;
        mapping(uint256 epochId => EpochData) epochs;
        mapping(uint256 settleId => SettleData) settles;
        mapping(address user => uint256 epochId) lastDepositRequestId;
        mapping(address user => uint256 epochId) lastRedeemRequestId;
        mapping(address controller => mapping(address operator => bool)) isOperator;
        Silo pendingSilo;
        IWETH9 wrappedNativeToken;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.ERC7540")) - 1)) & ~bytes32(uint256(0xff));
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant erc7540Storage =
        0x5c74d456014b1c0eb4368d944667a568313858a3029a650ff0cb7b56f8b57a00;

    function _getERC7540Storage()
        internal
        pure
        returns (ERC7540Storage storage $)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := erc7540Storage
        }
    }

    // solhint-disable-next-line func-name-mixedcase
    function __ERC7540_init(
        IERC20 underlying,
        address wrappedNativeToken
    ) internal onlyInitializing {
        ERC7540Storage storage $ = _getERC7540Storage();

        $.depositEpochId = 1;
        $.redeemEpochId = 2;

        $.depositSettleId = 1;
        $.redeemSettleId = 2;

        $.pendingSilo = new Silo(underlying);
        $.wrappedNativeToken = IWETH9(wrappedNativeToken);
    }

    modifier onlyOperator(address controller) {
        if (
            controller != _msgSender() && !isOperator(controller, _msgSender())
        ) {
            revert ERC7540InvalidOperator();
        }
        _;
    }

    // ## Overrides ##
    function totalAssets()
        public
        view
        override(IERC4626, ERC4626Upgradeable)
        returns (uint256)
    {
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
    function isOperator(
        address controller,
        address operator
    ) public view returns (bool) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.isOperator[controller][operator];
    }

    /// @dev should not be usable when contract is paused
    function setOperator(
        address operator,
        bool approved
    ) external whenNotPaused returns (bool success) {
        ERC7540Storage storage $ = _getERC7540Storage();
        address msgSender = _msgSender();
        $.isOperator[msgSender][operator] = approved;
        emit OperatorSet(msgSender, operator, approved);
        return true;
    }

    // ## EIP7575 ##
    function share() external view returns (address) {
        return (address(this));
    }

    // ## EIP165 ##
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
        return
            interfaceId == 0x2f0a18c5 || // IERC7575
            interfaceId == 0xf815c03d || // IERC7575 shares
            interfaceId == 0xce3bbe50 || // IERC7540Deposit
            interfaceId == 0x620ee8e4 || // IERC7540Redeem
            interfaceId == 0xe3bc4e65 || // IERC7540
            interfaceId == type(IERC165).interfaceId;
    }

    function previewDeposit(
        uint256
    )
        public
        pure
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256 shares)
    {
        shares;
        if (true) revert ERC7540PreviewDepositDisabled();
    }

    function previewMint(
        uint256
    )
        public
        pure
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256 assets)
    {
        assets;
        if (true) revert ERC7540PreviewMintDisabled();
    }

    function previewRedeem(
        uint256
    )
        public
        pure
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256 assets)
    {
        assets;
        if (true) revert ERC7540PreviewRedeemDisabled();
    }

    function previewWithdraw(
        uint256
    )
        public
        pure
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256 shares)
    {
        shares;
        if (true) revert ERC7540PreviewWithdrawDisabled();
    }

    // ## EIP7540 Deposit Flow ##

    /// @dev should not be usable when contract is paused
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    )
        public
        payable
        virtual
        onlyOperator(owner)
        whenNotPaused
        returns (uint256 _depositId)
    {
        uint256 claimable = claimableDepositRequest(0, controller);
        if (claimable > 0) _deposit(claimable, controller, controller);

        ERC7540Storage storage $ = _getERC7540Storage();

        _depositId = $.depositEpochId;
        if ($.lastDepositRequestId[controller] != _depositId) {
            if (pendingDepositRequest(0, controller) > 0)
                revert OnlyOneRequestAllowed();
            $.lastDepositRequestId[controller] = _depositId;
        }
        $.epochs[_depositId].depositRequest[controller] += assets;

        // Shoudn't we move native token wrapping outside the ERC7540?
        if (msg.value != 0) {
            // if user sends eth and the underlying is wETH we will wrap it for him
            if (asset() == address($.wrappedNativeToken)) {
                //todo remove this security
                IWETH9($.wrappedNativeToken).deposit{value: msg.value}();
                IWETH9($.wrappedNativeToken).transfer(
                    address($.pendingSilo),
                    msg.value
                );
            } else {
                revert CantDepositNativeToken();
            }
        } else {
            IERC20(asset()).safeTransferFrom(
                owner,
                address($.pendingSilo),
                assets
            );
        }

        emit DepositRequest(
            controller,
            owner,
            _depositId,
            _msgSender(),
            assets
        );
    }

    function pendingDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0) requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled)
            return $.epochs[requestId].depositRequest[controller];
    }

    // todo: Pass this function as external
    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0) requestId = $.lastDepositRequestId[controller];
        if (requestId <= $.lastDepositEpochIdSettled)
            return $.epochs[requestId].depositRequest[controller];
    }

    // todo: replace with the implementation of claimableDepositRequest
    function maxDeposit(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        return claimableDepositRequest(0, controller);
    }

    /// @dev should not be usable when contract is paused
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _deposit(assets, receiver, _msgSender());
    }

    /// @dev should not be usable when contract is paused
    function deposit(
        uint256 assets,
        address receiver,
        address controller
    ) external virtual onlyOperator(controller) returns (uint256) {
        return _deposit(assets, receiver, controller);
    }

    function _deposit(
        uint256 assets,
        address receiver,
        address controller
    ) internal virtual returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled)
            revert RequestIdNotClaimable();

        $.epochs[requestId].depositRequest[controller] -= assets;
        shares = convertToShares(assets, requestId);

        _update(address(this), receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
    }

    /// @dev should not be usable when contract is paused
    function mint(
        uint256 shares,
        address receiver
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _mint(shares, receiver, _msgSender());
    }

    /// @dev should not be usable when contract is paused
    function mint(
        uint256 shares,
        address receiver,
        address controller
    ) external virtual onlyOperator(controller) returns (uint256) {
        return _mint(shares, receiver, controller);
    }

    function _mint(
        uint256 shares,
        address receiver,
        address controller
    ) internal virtual returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastDepositRequestId[controller];
        if (requestId > $.lastDepositEpochIdSettled)
            revert RequestIdNotClaimable();

        assets = convertToAssets(shares, requestId);

        $.epochs[requestId].depositRequest[controller] -= assets;
        _update(address(this), receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
    }

    /// @dev should not be usable when contract is paused
    function cancelRequestDeposit() external whenNotPaused {
        ERC7540Storage storage $ = _getERC7540Storage();
        address msgSender = _msgSender();
        uint256 requestId = $.lastDepositRequestId[msgSender];
        if (requestId <= $.lastDepositEpochIdSettled)
            revert("can't cancel claimable request"); //todo revert error
        if (requestId != $.depositEpochId) revert RequestNotCancelable();

        uint256 request = $.epochs[requestId].depositRequest[msgSender];
        if (request != 0) {
            $.epochs[requestId].depositRequest[msgSender] = 0;
            IERC20(asset()).safeTransferFrom(pendingSilo(), msgSender, request);
        }
    }

    // ## EIP7540 Redeem flow ##

    /// @dev should not be usable when contract is paused
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) public virtual returns (uint256 _redeemId) {
        if (_msgSender() != owner && !isOperator(owner, _msgSender())) {
            _spendAllowance(owner, _msgSender(), shares);
        }

        uint256 claimable = claimableRedeemRequest(0, controller);
        if (claimable > 0) _redeem(claimable, controller, controller);

        ERC7540Storage storage $ = _getERC7540Storage();

        _redeemId = $.redeemEpochId;
        if ($.lastRedeemRequestId[controller] != _redeemId) {
            if (pendingRedeemRequest(0, controller) > 0)
                revert OnlyOneRequestAllowed();
            $.lastRedeemRequestId[controller] = _redeemId;
        }
        $.epochs[_redeemId].redeemRequest[controller] += shares;

        _update(owner, address($.pendingSilo), shares);

        emit RedeemRequest(controller, owner, _redeemId, _msgSender(), shares);
    }

    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0) {
            requestId = $.lastRedeemRequestId[controller];
        }
        if (requestId > $.lastRedeemEpochIdSettled) {
            return $.epochs[requestId].redeemRequest[controller];
        }
    }

    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0) requestId = $.lastRedeemRequestId[controller];

        if (requestId <= $.lastRedeemEpochIdSettled) {
            return $.epochs[requestId].redeemRequest[controller];
        }
    }

    function maxRedeem(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        return claimableRedeemRequest(0, controller);
    }

    /// @dev should not be usable when contract is paused
    function redeem(
        uint256 shares,
        address receiver,
        address controller
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _redeem(shares, receiver, controller);
    }

    function _redeem(
        uint256 shares,
        address receiver,
        address controller
    ) internal onlyOperator(controller) whenNotPaused returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemEpochIdSettled)
            revert RequestIdNotClaimable();

        $.epochs[requestId].redeemRequest[controller] -= shares;
        assets = convertToAssets(shares, requestId);
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
    }

    /// @dev should not be usable when contract is paused
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _withdraw(assets, receiver, controller);
    }

    function _withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) internal onlyOperator(controller) returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemEpochIdSettled)
            revert RequestIdNotClaimable();

        shares = convertToShares(assets, requestId);
        $.epochs[requestId].redeemRequest[controller] -= shares;
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
    }

    // ## Conversion functions ##
    function convertToShares(
        uint256 assets,
        uint256 requestId
    ) public view returns (uint256) {
        return _convertToShares(assets, requestId, Math.Rounding.Floor);
    }

    function _convertToShares(
        uint256 assets,
        uint256 requestId,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 _totalAssets = $
            .settles[$.epochs[requestId].settleId]
            .totalAssets + 1;

        uint256 _totalSupply = $
            .settles[$.epochs[requestId].settleId]
            .totalSupply + 10 ** _decimalsOffset();

        return assets.mulDiv(_totalSupply, _totalAssets, rounding);
    }

    function convertToAssets(
        uint256 shares,
        uint256 requestId
    ) public view returns (uint256) {
        return _convertToAssets(shares, requestId, Math.Rounding.Floor);
    }

    function _convertToAssets(
        uint256 shares,
        uint256 requestId,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 _totalAssets = $
            .settles[$.epochs[requestId].settleId]
            .totalAssets + 1;

        uint256 _totalSupply = $
            .settles[$.epochs[requestId].settleId]
            .totalSupply + 10 ** _decimalsOffset();

        return shares.mulDiv(_totalAssets, _totalSupply, rounding);
    }

    function pendingSilo() public view returns (address) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return address($.pendingSilo);
    }

    function redeemId() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.redeemEpochId;
    }

    function depositId() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.depositEpochId;
    }

    function settleDeposit() public virtual;

    function settleRedeem() public virtual;
}
