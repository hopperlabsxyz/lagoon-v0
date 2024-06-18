// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable, IERC20, IERC20Metadata} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC7540Upgradeable} from "./ERC7540.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Silo} from "./Silo.sol";
// import {console} from "forge-std/console.sol";
// import {console2} from "forge-std/console2.sol";

using Math for uint256;
using SafeERC20 for IERC20;

uint256 constant BPS_DIVIDER = 10_000;

struct EpochData {
    uint256 totalSupplyDeposit;
    uint256 totalAssetsDeposit;
    uint256 totalAssetsRedeem;
    uint256 totalSupplyRedeem;
    mapping(address => uint256) depositRequest;
    mapping(address => uint256) redeemRequest;
}

contract Vault is
    ERC7540Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable
{
    /// @custom:storage-location erc7201:hopper.storage.vault
    struct VaultStorage {
        uint256 totalAssets;
        uint256 epochId;
        uint256 toUnwind;
        address vaultOwner;
        Silo pendingSilo;
        Silo claimableSilo;
        mapping(uint256 epochId => EpochData epoch) epochs;
        mapping(address user => uint256 epochId) lastDepositRequestId;
        mapping(address user => uint256 epochId) lastRedeemRequestId;
    }

    // keccak256(abi.encode(uint256(keccak256("hopperprotocol.storage.vault")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant HopperVaultStorage =
        0xfdb0cd9880e84ca0b573fff91a05faddfecad925c5f393111a47359314e28e00;

    function _getVaultStorage() internal pure returns (VaultStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := HopperVaultStorage
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(bool disable) {
        if (disable) _disableInitializers();
    }

    function initialize(
        IERC20 underlying,
        string memory name,
        string memory symbol
    ) public virtual initializer {
        __ERC4626_init(underlying);
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __ERC20Pausable_init();
        VaultStorage storage $ = _getVaultStorage();
        $.claimableSilo = new Silo(underlying);
        $.pendingSilo = new Silo(underlying);
        $.epochId = 1;
        $.vaultOwner = address(1);
    }

    // ## Overrides ##
    function totalAssets()
        public
        view
        override(IERC4626, ERC4626Upgradeable)
        returns (uint256)
    {
        VaultStorage storage $ = _getVaultStorage();
        return $.totalAssets;
    }

    function decimals()
        public
        view
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

    // ## EIP7540 Deposit Flow ##
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) external whenNotPaused returns (uint256) {
        address msgSender = _msgSender();
        require(assets != 0);
        require(owner == msgSender || isOperator(owner, msgSender));

        uint256 claimbaleDeposit = claimableDepositRequest(0, controller);
        if (claimbaleDeposit > 0)
            _deposit(claimbaleDeposit, controller, controller);

        VaultStorage storage $ = _getVaultStorage();

        IERC20(asset()).safeTransferFrom(owner, address($.pendingSilo), assets);

        _requestDeposit(assets, controller, owner);
        return $.epochId;
    }

    function _requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) internal {
        VaultStorage storage $ = _getVaultStorage();
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
        VaultStorage storage $ = _getVaultStorage();

        if (requestId == 0)
            return $.epochs[$.epochId].depositRequest[controller];
        else if (requestId == $.epochId) return 0;
        else return $.epochs[requestId].depositRequest[controller];
    }

    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 assets) {
        VaultStorage storage $ = _getVaultStorage();

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

        VaultStorage storage $ = _getVaultStorage();

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
        VaultStorage storage $ = _getVaultStorage();

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

        VaultStorage storage $ = _getVaultStorage();
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
        VaultStorage storage $ = _getVaultStorage();

        if (requestId == 0)
            return $.epochs[$.epochId].redeemRequest[controller];
        else if (requestId == $.epochId) return 0;
        else return $.epochs[requestId].redeemRequest[controller];
    }

    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256 shares) {
        VaultStorage storage $ = _getVaultStorage();
        uint256 epochId = $.epochId;
        if (requestId == 0) {
            uint256 lastRedeemRequestId = $.lastRedeemRequestId[controller];
            if (lastRedeemRequestId == epochId) return 0;
            else return $.epochs[lastRedeemRequestId].redeemRequest[controller];
        } else if (requestId == epochId) return 0;
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

        VaultStorage storage $ = _getVaultStorage();

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

        VaultStorage storage $ = _getVaultStorage();

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
        VaultStorage storage $ = _getVaultStorage();
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
        VaultStorage storage $ = _getVaultStorage();
        if (requestId == $.epochId) return 0;

        uint256 _totalAssets = $.epochs[requestId].totalAssetsRedeem + 1;
        uint256 _totalSupply = $.epochs[requestId].totalSupplyRedeem +
            10 ** _decimalsOffset();

        return shares.mulDiv(_totalAssets, _totalSupply, rounding);
    }

    function pendingSilo() public view returns (address) {
        VaultStorage storage $ = _getVaultStorage();
        return address($.pendingSilo);
    }

    function claimableSilo() public view returns (address) {
        VaultStorage storage $ = _getVaultStorage();
        return address($.claimableSilo);
    }

    function _computeFees(
        uint256 previousBalance,
        uint256 newBalance,
        uint256 feesInBps
    ) internal pure returns (uint256 fees) {
        if (newBalance > previousBalance && feesInBps > 0) {
            uint256 profits;
            unchecked {
                profits = newBalance - previousBalance;
            }
            fees = (profits).mulDiv(
                feesInBps,
                BPS_DIVIDER,
                Math.Rounding.Floor
            );
        }
    }

    function newSettle(uint256 newTotalAssets) public {
        VaultStorage storage $ = _getVaultStorage();

        // First we update the vault value.
        $.totalAssets = newTotalAssets;

        // Then we proceed the deposit request and save the deposit parameters
        $.epochs[$.epochId].totalAssetsDeposit = $.totalAssets;
        $.epochs[$.epochId].totalSupplyDeposit = totalSupply();
        uint256 pendingAssets = IERC20(asset()).balanceOf(
            address($.pendingSilo)
        );
        if (pendingAssets > 0) {
            uint256 shares = _convertToShares(
                pendingAssets,
                Math.Rounding.Floor
            );
            _mint(address($.claimableSilo), shares);
            $.totalAssets += pendingAssets;
        }

        // Then we proceed the redeem request and save the redeem parameters
        $.epochs[$.epochId].totalAssetsRedeem = $.totalAssets;
        $.epochs[$.epochId].totalSupplyRedeem = totalSupply();
        uint256 assets = _convertToAssets(
            balanceOf(address($.pendingSilo)),
            Math.Rounding.Floor
        );
        if (assets > 0) {
            _burn(address($.pendingSilo), balanceOf(address($.pendingSilo)));
            $.totalAssets -= assets;
            $.toUnwind += assets;
        }

        // Then we put a maximum of assets in the claimable silo so that user can claim
        if (pendingAssets > 0 && $.toUnwind > 0)
            _unwind(pendingAssets, pendingSilo());

        // If there is a surplus of assets, we send those to the asset manager
        pendingAssets = IERC20(asset()).balanceOf(pendingSilo());
        if (pendingAssets > 0)
            IERC20(asset()).safeTransferFrom(
                pendingSilo(),
                $.vaultOwner,
                pendingAssets
            );

        $.epochId++;
    }

    function unwind(uint256 amount) external {
        VaultStorage storage $ = _getVaultStorage();
        _unwind(amount, $.vaultOwner);
    }

    function _unwind(uint256 amount, address from) internal {
        VaultStorage storage $ = _getVaultStorage();

        if (amount > $.toUnwind) amount = $.toUnwind;
        $.toUnwind -= amount;
        IERC20(asset()).safeTransferFrom(from, claimableSilo(), amount);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        pure
        override(ERC7540Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return true;
    }
}
