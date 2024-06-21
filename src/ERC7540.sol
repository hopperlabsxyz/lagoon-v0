//SPDX-License-Identifier: MIT
pragma solidity "0.8.25";
import {IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {IERC7540Deposit} from "./interfaces/IERC7540Deposit.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, ERC20Upgradeable, IERC20Metadata} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Silo} from "./Silo.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

struct EpochData {
    uint256 totalSupplyDeposit;
    uint256 totalAssetsDeposit;
    uint256 totalAssetsRedeem;
    uint256 totalSupplyRedeem;
    mapping(address => uint256) depositRequest;
    mapping(address => uint256) redeemRequest;
}

struct ERC7540Storage {
    mapping(address controller => mapping(address operator => bool)) isOperator;
    uint256 totalAssets;
    uint256 epochId;
    Silo pendingSilo;
    Silo claimableSilo;
    mapping(uint256 epochId => EpochData epoch) epochs;
    mapping(address user => uint256 epochId) lastDepositRequestId;
    mapping(address user => uint256 epochId) lastRedeemRequestId;
}

using SafeERC20 for IERC20;
using Math for uint256;

abstract contract ERC7540Upgradeable is
    IERC7540Redeem,
    IERC7540Deposit,
    ERC20PausableUpgradeable,
    ERC4626Upgradeable
{
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
        $.epochId = 1;
        $.claimableSilo = new Silo(underlying);
        $.pendingSilo = new Silo(underlying);
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
    ) public pure virtual returns (bool) {
        interfaceId;
        return true;
    }

    function previewDeposit(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        require(false);
    }

    function previewMint(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        require(false);
    }

    function previewRedeem(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        require(false);
    }

    function previewWithdraw(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        require(false);
    }

    // ## EIP7540 Deposit Flow ##
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) external returns (uint256) {
        address msgSender = _msgSender();
        require(assets != 0);
        require(owner == msgSender || isOperator(owner, msgSender));

        uint256 claimbaleDeposit = claimableDepositRequest(0, controller);
        if (claimbaleDeposit > 0)
            _deposit(claimbaleDeposit, controller, controller);

        ERC7540Storage storage $ = _getERC7540Storage();

        IERC20(asset()).safeTransferFrom(owner, address($.pendingSilo), assets);

        _requestDeposit(assets, controller, owner);
        return $.epochId;
    }

    function _requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        $.epochs[$.epochId].depositRequest[controller] += assets;
        if ($.lastDepositRequestId[controller] != $.epochId) {
            $.lastDepositRequestId[controller] = $.epochId;
        }
        emit DepositRequest(controller, owner, $.epochId, _msgSender(), assets);
    }

    function pendingDepositRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0)
            return $.epochs[$.epochId].depositRequest[controller];
        else if (requestId == $.epochId) return 0;
        else return $.epochs[requestId].depositRequest[controller];
    }

    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == $.epochId) return 0;
        else if (requestId == 0) {
            uint256 lastDepositRequestId = $.lastDepositRequestId[controller];
            if (lastDepositRequestId == $.epochId) return 0;
            else
                return
                    $.epochs[lastDepositRequestId].depositRequest[controller];
        } else return $.epochs[requestId].depositRequest[controller];
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
    ) external returns (uint256) {
        require(
            controller == _msgSender() || isOperator(controller, _msgSender())
        );
        return _deposit(assets, receiver, controller);
    }

    function _deposit(
        uint256 assets,
        address receiver,
        address controller
    ) private returns (uint256 shares) {
        require(assets > 0);

        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastDepositRequestId[controller];
        require(requestId != $.epochId);

        $.epochs[requestId].depositRequest[controller] -= assets;
        shares = convertToShares(assets, requestId);
        _update(address($.claimableSilo), receiver, shares);
        emit Deposit(controller, receiver, assets, shares);
        return shares;
    }

    function mint(
        uint256 assets,
        address receiver
    ) public virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _deposit(assets, receiver, _msgSender());
    }

    function mint(
        uint256 shares,
        address receiver,
        address controller
    ) external returns (uint256) {
        require(
            controller == _msgSender() || isOperator(controller, _msgSender())
        );

        return _mint(shares, receiver, controller);
    }

    function _mint(
        uint256 shares,
        address receiver,
        address controller
    ) internal returns (uint256 assets) {
        require(shares > 0);
        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastDepositRequestId[controller];
        require(requestId != $.epochId);

        assets = convertToAssets(shares, requestId);

        $.epochs[requestId].depositRequest[controller] -= assets;
        _update(address($.claimableSilo), receiver, shares);
        emit Deposit(controller, receiver, assets, shares);
        return assets;
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
        _update(owner, address($.pendingSilo), shares);
        $.epochs[$.epochId].redeemRequest[controller] += shares;
        if ($.lastRedeemRequestId[controller] != $.epochId) {
            $.lastRedeemRequestId[controller] = $.epochId;
        }

        emit RedeemRequest(controller, owner, $.epochId, _msgSender(), shares);
        return $.epochId;
    }

    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();

        if (requestId == 0)
            return $.epochs[$.epochId].redeemRequest[controller];
        else if (requestId == $.epochId) return 0;
        else return $.epochs[requestId].redeemRequest[controller];
    }

    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        ERC7540Storage storage $ = _getERC7540Storage();
        uint256 _epochId = $.epochId;
        if (requestId == 0) {
            uint256 lastRedeemRequestId = $.lastRedeemRequestId[controller];
            if (lastRedeemRequestId == _epochId) return 0;
            else return $.epochs[lastRedeemRequestId].redeemRequest[controller];
        } else if (requestId == _epochId) return 0;
        else return $.epochs[requestId].redeemRequest[controller];
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
        whenNotPaused
        returns (uint256)
    {
        require(
            controller == _msgSender() || isOperator(controller, _msgSender())
        );
        return _redeem(shares, receiver, controller);
    }

    function _redeem(
        uint256 shares,
        address receiver,
        address controller
    ) private returns (uint256 assets) {
        require(shares > 0);

        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastRedeemRequestId[controller];
        require(requestId != $.epochId);

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
        whenNotPaused
        returns (uint256)
    {
        require(
            controller == _msgSender() || isOperator(controller, _msgSender())
        );
        return _withdraw(assets, receiver, controller);
    }

    function _withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) private returns (uint256 shares) {
        require(assets > 0);

        ERC7540Storage storage $ = _getERC7540Storage();

        uint256 requestId = $.lastRedeemRequestId[controller];
        require(requestId != $.epochId);

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
        if (requestId == $.epochId) return 0;

        uint256 _totalAssets = $.epochs[requestId].totalAssetsDeposit + 1;
        uint256 _totalSupply = $.epochs[requestId].totalSupplyDeposit +
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
        if (requestId == $.epochId) return 0;

        uint256 _totalAssets = $.epochs[requestId].totalAssetsRedeem + 1;
        uint256 _totalSupply = $.epochs[requestId].totalSupplyRedeem +
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

    function epochId() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochId;
    }

    function setTotalAssets(uint256 _totalAssets) internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        $.totalAssets = _totalAssets;
    }

    function setTotalAssetsDeposit(
        uint256 _totalAssets,
        uint256 _epochId
    ) internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        $.epochs[_epochId].totalAssetsDeposit = _totalAssets;
    }

    function setTotalSupplyDeposit(
        uint256 _totalSupply,
        uint256 _epochId
    ) internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        $.epochs[_epochId].totalSupplyDeposit = _totalSupply;
    }

    function setTotalAssetsRedeem(
        uint256 _totalAssets,
        uint256 _epochId
    ) internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        $.epochs[_epochId].totalAssetsRedeem = _totalAssets;
    }

    function setTotalSupplyRedeem(
        uint256 _totalSupply,
        uint256 _epochId
    ) internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        $.epochs[_epochId].totalSupplyRedeem = _totalSupply;
    }

    function increaseEpochId() internal {
        ERC7540Storage storage $ = _getERC7540Storage();
        $.epochId++;
    }

    function settle() public virtual;
}
