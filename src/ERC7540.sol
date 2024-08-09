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
// import {console} from "forge-std/console.sol";

struct EpochData {
    uint256 totalSupply;
    uint256 totalAssets;
    mapping(address => uint256) depositRequest;
    mapping(address => uint256) redeemRequest;
}

using SafeERC20 for IERC20;
using Math for uint256;

error ERC7540PreviewDepositDisabled();
error ERC7540PreviewMintDisabled();
error ERC7540PreviewRedeemDisabled();
error ERC7540PreviewWithdrawDisabled();

error RequestDepositZero();
error RequestRedeemZero();
error DepositZero();
error RedeemZero();
error WithdrawZero();

error ERC7540InvalidOperator();
error ZeroPendingDeposit();
error ZeroPendingRedeem();

error RequestIdNotClaimable();

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
        uint256 depositId;
        uint256 redeemId;
        Silo pendingSilo;
        Silo claimableSilo;
        mapping(uint256 epochId => EpochData epoch) epochs;
        mapping(address user => uint256 epochId) lastDepositRequestId;
        mapping(address user => uint256 epochId) lastRedeemRequestId;
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

    function __ERC7540_init(IERC20 underlying) internal onlyInitializing {
        ERC7540Storage storage $ = _getERC7540Storage();
        $.depositId = 1;
        $.redeemId = 2;
        $.claimableSilo = new Silo(underlying);
        $.pendingSilo = new Silo(underlying);
    }

    modifier onlyOperator(address controller) {
        if (controller != _msgSender() && !isOperator(controller, _msgSender()))
            revert ERC7540InvalidOperator();

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
    ) public virtual onlyOperator(owner) returns (uint256) {
        if (assets == 0) revert RequestDepositZero();

        uint256 claimbaleDeposit = claimableDepositRequest(0, controller);
        if (claimbaleDeposit > 0)
            _deposit(claimbaleDeposit, controller, controller);

        ERC7540Storage storage $ = _getERC7540Storage();

        IERC20(asset()).safeTransferFrom(owner, address($.pendingSilo), assets);

        _requestDeposit(assets, controller, owner);
        return $.depositId;
    }

    function _requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        $.epochs[$.depositId].depositRequest[controller] += assets;
        if ($.lastDepositRequestId[controller] != $.depositId) {
            $.lastDepositRequestId[controller] = $.depositId;
        }
        emit DepositRequest(
            controller,
            owner,
            $.depositId,
            _msgSender(),
            assets
        );
    }

    function pendingDepositRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0)
            return $.epochs[$.depositId].depositRequest[controller];
        else if (requestId != $.depositId) return 0;
        else return $.epochs[requestId].depositRequest[controller];
    }

    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0) requestId = $.lastDepositRequestId[controller];

        if (requestId != $.depositId)
            return $.epochs[requestId].depositRequest[controller];
    }

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
    ) external onlyOperator(controller) returns (uint256) {
        return _deposit(assets, receiver, controller);
    }

    function _deposit(
        uint256 assets,
        address receiver,
        address controller
    ) internal virtual returns (uint256 shares) {
        if (assets == 0) revert DepositZero();

        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastDepositRequestId[controller];
        if (requestId == $.depositId) revert RequestIdNotClaimable();

        $.epochs[requestId].depositRequest[controller] -= assets;
        shares = convertToShares(assets, requestId);
        _update(address($.claimableSilo), receiver, shares);
        emit Deposit(controller, receiver, assets, shares);
        return shares;
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
    ) external onlyOperator(controller) returns (uint256) {
        return _mint(shares, receiver, controller);
    }

    function _mint(
        uint256 shares,
        address receiver,
        address controller
    ) internal virtual returns (uint256 assets) {
        if (shares == 0) revert DepositZero();
        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastDepositRequestId[controller];
        if (requestId == $.depositId) revert RequestIdNotClaimable();

        assets = convertToAssets(shares, requestId);

        $.epochs[requestId].depositRequest[controller] -= assets;
        _update(address($.claimableSilo), receiver, shares);
        emit Deposit(controller, receiver, assets, shares);
        return assets;
    }

    function cancelRequestDeposit() external {
        ERC7540Storage storage $ = _getERC7540Storage();
        address msgSender = _msgSender();
        uint256 request = $.epochs[$.depositId].depositRequest[msgSender];
        if (request == 0) revert ZeroPendingDeposit();
        $.epochs[$.depositId].depositRequest[msgSender] = 0;
        IERC20(asset()).safeTransferFrom(pendingSilo(), msgSender, request);
    }

    // ## EIP7540 Redeem flow ##
    /** @dev if paused will revert thanks to _update() */
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) external returns (uint256) {
        if (_msgSender() != owner && !isOperator(owner, _msgSender()))
            _spendAllowance(owner, _msgSender(), shares);

        uint256 claimable = claimableRedeemRequest(0, controller);
        if (claimable > 0) _redeem(claimable, controller, controller);

        ERC7540Storage storage $ = _getERC7540Storage();
        uint256 _redeemId = $.redeemId;
        _update(owner, address($.pendingSilo), shares);
        $.epochs[_redeemId].redeemRequest[controller] += shares;
        if ($.lastRedeemRequestId[controller] != _redeemId) {
            $.lastRedeemRequestId[controller] = _redeemId;
        }

        emit RedeemRequest(controller, owner, _redeemId, _msgSender(), shares);
        return _redeemId;
    }

    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();
        uint256 _redeemId = $.redeemId;
        if (requestId == 0)
            return $.epochs[_redeemId].redeemRequest[controller];
        else if (requestId != _redeemId) return 0;
        else return $.epochs[requestId].redeemRequest[controller];
    }

    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0) requestId = $.lastRedeemRequestId[controller];

        if (requestId != $.redeemId)
            return $.epochs[requestId].redeemRequest[controller];
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
    )
        public
        override(ERC4626Upgradeable, IERC4626)
        onlyOperator(controller)
        returns (uint256)
    {
        return _redeem(shares, receiver, controller);
    }

    function _redeem(
        uint256 shares,
        address receiver,
        address controller
    ) private returns (uint256 assets) {
        if (shares == 0) revert RedeemZero();

        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastRedeemRequestId[controller];
        if (requestId == $.redeemId) revert RequestIdNotClaimable();

        $.epochs[requestId].redeemRequest[controller] -= shares;
        assets = convertToAssets(shares, requestId);
        IERC20(asset()).safeTransferFrom(
            address($.claimableSilo),
            receiver,
            assets
        );

        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
        return assets;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    )
        public
        override(ERC4626Upgradeable, IERC4626)
        onlyOperator(controller)
        returns (uint256)
    {
        return _withdraw(assets, receiver, controller);
    }

    function _withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) private returns (uint256 shares) {
        if (assets == 0) revert WithdrawZero();

        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastRedeemRequestId[controller];
        if (requestId == $.redeemId) revert RequestIdNotClaimable();
        shares = convertToShares(assets, requestId);
        $.epochs[requestId].redeemRequest[controller] -= shares;

        IERC20(asset()).safeTransferFrom(
            address($.claimableSilo),
            receiver,
            assets
        );
        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
        return shares;
    }

    function cancelRequestRedeem() external {
        ERC7540Storage storage $ = _getERC7540Storage();
        address msgSender = _msgSender();
        uint256 request = $.epochs[$.redeemId].redeemRequest[msgSender];
        if (request == 0) revert ZeroPendingRedeem();
        $.epochs[$.redeemId].redeemRequest[msgSender] = 0;
        _transfer(pendingSilo(), msgSender, request);
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
        if (
            requestId == $.redeemId ||
            requestId == $.depositId ||
            requestId == 0
        ) return 0;

        uint256 _totalAssets = $.epochs[requestId].totalAssets + 1;
        uint256 _totalSupply = $.epochs[requestId].totalSupply +
            10 ** _decimalsOffset();
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

        if (
            requestId == $.depositId ||
            requestId == $.redeemId ||
            requestId == 0
        ) return 0;

        uint256 _totalAssets = $.epochs[requestId].totalAssets + 1;
        uint256 _totalSupply = $.epochs[requestId].totalSupply +
            10 ** _decimalsOffset();

        return shares.mulDiv(_totalAssets, _totalSupply, rounding);
    }

    function pendingSilo() public view returns (address) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return address($.pendingSilo);
    }

    function claimableSilo() public view returns (address) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return address($.claimableSilo);
    }

    function redeemId() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.redeemId;
    }

    function depositId() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.depositId;
    }

    function settleDeposit() public virtual;

    function settleRedeem() public virtual;
}
