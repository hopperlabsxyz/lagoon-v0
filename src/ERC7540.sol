//SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

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
// import {console} from "forge-std/console.sol";

using SafeERC20 for IERC20;
using Math for uint256;

error ERC7540PreviewDepositDisabled();
error ERC7540PreviewMintDisabled();
error ERC7540PreviewRedeemDisabled();
error ERC7540PreviewWithdrawDisabled();
error OnlyOneRequestAllowed();

error ERC7540InvalidOperator();
error ZeroPendingDeposit();
error ZeroPendingRedeem();

error RequestIdNotClaimable();

error CantDepositNativeToken();

struct NavData {
    uint256 settleId;
    mapping(address => uint256) depositRequest;
    mapping(address => uint256) redeemRequest; // todo maybe merge those 2 since navid can't be same
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
        mapping(address controller => mapping(address operator => bool)) isOperator;
        uint256 totalAssets;
        uint256 depositNavId;
        uint256 redeemNavId;
        uint256 depositSettleId;
        uint256 redeemSettleId;
        // uint256 currentNavIdRequestAssets;

        uint256 lastRedeemNavIdSettle;
        uint256 lastDepositNavIdSettle;
        Silo pendingSilo;
        mapping(uint256 depositNavId => NavData) navs;
        // mapping(uint256 redeemNavId => NavData) redeemNavs;
        mapping(uint256 settleId => SettleData) settles;
        // mapping(uint256 epochId => Data epoch) epochs;
        mapping(address user => uint256 epochId) lastDepositRequestId;
        mapping(address user => uint256 epochId) lastRedeemRequestId;
        IWETH9 wrapped_native_token;
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

    function __ERC7540_init(
        IERC20 underlying,
        address wrapped_native_token
    ) internal onlyInitializing {
        ERC7540Storage storage $ = _getERC7540Storage();

        $.depositNavId = 1;
        $.redeemNavId = 2;

        $.depositSettleId = 1;
        $.redeemSettleId = 2;

        $.pendingSilo = new Silo(underlying);
        $.wrapped_native_token = IWETH9(wrapped_native_token);
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

    function setOperator(
        address operator,
        bool approved
    ) external returns (bool success) {
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
            interfaceId == 0x01ffc9a7 || // IERC7575 shares
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
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) public payable virtual onlyOperator(owner) returns (uint256 _depositId) {
        uint256 claimable = claimableDepositRequest(0, controller);
        if (claimable > 0) _deposit(claimable, controller, controller);

        ERC7540Storage storage $ = _getERC7540Storage();
        if (msg.value != 0) {
            // if user sends eth and the underlying is wETH we will wrap it for him
            if (asset() == address($.wrapped_native_token)) {
                //todo remove this security
                IWETH9($.wrapped_native_token).deposit{value: msg.value}();
                IWETH9($.wrapped_native_token).transfer(
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

        _depositId = $.depositNavId;
        uint256 pendingReq = pendingDepositRequest(0, controller);
        uint256 lastDepositId = $.lastDepositRequestId[controller];
        if (pendingReq > 0 && lastDepositId != _depositId) {
            revert OnlyOneRequestAllowed();
        }

        $.navs[_depositId].depositRequest[controller] += assets;
        if ($.lastDepositRequestId[controller] != _depositId) {
            $.lastDepositRequestId[controller] = _depositId;
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

        if (requestId == 0) {
            requestId = $.lastDepositRequestId[controller];
        }
        if (requestId > $.lastDepositNavIdSettle) {
            return $.navs[requestId].depositRequest[controller];
        }
    }

    // todo: Pass this function as external
    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0) requestId = $.lastDepositRequestId[controller];

        if (requestId <= $.lastDepositNavIdSettle) {
            return $.navs[requestId].depositRequest[controller];
        }
    }

    // todo: replace with the implementation of claimableDepositRequest
    function maxDeposit(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        return claimableDepositRequest(0, controller);
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _deposit(assets, receiver, _msgSender());
    }

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
        if (requestId > $.lastDepositNavIdSettle)
            revert RequestIdNotClaimable();

        $.navs[requestId].depositRequest[controller] -= assets;
        shares = convertToShares(assets, requestId);

        _update(address(this), receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
    }

    function mint(
        uint256 shares,
        address receiver
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _mint(shares, receiver, _msgSender());
    }

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
        if (requestId > $.lastDepositNavIdSettle)
            revert RequestIdNotClaimable();

        assets = convertToAssets(shares, requestId);

        $.navs[requestId].depositRequest[controller] -= assets;
        _update(address(this), receiver, shares);
        emit Deposit(controller, receiver, assets, shares);
        return assets;
    }

    // todo: block cancel request deposit after first nav of the current settle period
    function cancelRequestDeposit() external {
        ERC7540Storage storage $ = _getERC7540Storage();
        address msgSender = _msgSender();
        uint256 requestId = $.lastDepositRequestId[msgSender];
        if (requestId <= $.lastDepositNavIdSettle)
            revert("can't cancel claimable request");

        uint256 request = $.navs[requestId].depositRequest[msgSender];
        if (request == 0) return;
        $.navs[requestId].depositRequest[msgSender] = 0;
        IERC20(asset()).safeTransferFrom(pendingSilo(), msgSender, request);
    }

    // cancelRedeemRequest before nav update should be possible

    // ## EIP7540 Redeem flow ##
    /**
     * @dev if paused will revert thanks to _update()
     */
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
        _update(owner, address($.pendingSilo), shares);

        // pending ?

        _redeemId = $.redeemNavId;
        uint256 pendingReq = pendingRedeemRequest(0, controller);
        uint256 lastRedeemId = $.lastRedeemRequestId[controller];
        if (pendingReq > 0 && lastRedeemId != _redeemId) {
            revert OnlyOneRequestAllowed();
        }
        $.navs[_redeemId].redeemRequest[controller] += shares;
        if ($.lastRedeemRequestId[controller] != _redeemId) {
            $.lastRedeemRequestId[controller] = _redeemId;
        }

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
        if (requestId > $.lastRedeemNavIdSettle) {
            return $.navs[requestId].redeemRequest[controller];
        }
    }

    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0) requestId = $.lastRedeemRequestId[controller];

        if (requestId <= $.lastRedeemNavIdSettle) {
            return $.navs[requestId].redeemRequest[controller];
        }
    }

    function maxRedeem(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        return claimableRedeemRequest(0, controller);
    }

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
    ) internal onlyOperator(controller) returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastRedeemRequestId[controller];
        if (requestId > $.lastRedeemNavIdSettle) revert RequestIdNotClaimable();

        $.navs[requestId].redeemRequest[controller] -= shares;
        assets = convertToAssets(shares, requestId);
        IERC20(asset()).safeTransfer(receiver, assets);
        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
        return assets;
    }

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
        if (requestId > $.lastRedeemNavIdSettle) revert RequestIdNotClaimable();
        shares = convertToShares(assets, requestId);
        $.navs[requestId].redeemRequest[controller] -= shares;

        IERC20(asset()).safeTransfer(receiver, assets);
        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
        return shares;
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
            .settles[$.navs[requestId].settleId]
            .totalAssets + 1;

        uint256 _totalSupply = $
            .settles[$.navs[requestId].settleId]
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
            .settles[$.navs[requestId].settleId]
            .totalAssets + 1;

        uint256 _totalSupply = $
            .settles[$.navs[requestId].settleId]
            .totalSupply + 10 ** _decimalsOffset();

        return shares.mulDiv(_totalAssets, _totalSupply, rounding);
    }

    function pendingSilo() public view returns (address) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return address($.pendingSilo);
    }

    function redeemId() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.redeemNavId;
    }

    function depositId() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.depositNavId;
    }

    function settleDeposit() public virtual;

    function settleRedeem() public virtual;
}
