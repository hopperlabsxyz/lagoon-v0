// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {ERC7540Upgradeable, ERC7540Storage, EpochData} from "./ERC7540.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FeeManager, FeeManagerStorage, FeeSchema} from "./FeeManager.sol";
// import {console} from "forge-std/console.sol";
// import {console2} from "forge-std/console2.sol";

using Math for uint256;
using SafeERC20 for IERC20;

uint256 constant BPS_DIVIDER = 10_000;

struct RoleSchema {
    address assetManager;
    address valorization;
    address admin;
    address dao;
}

bytes32 constant ASSET_MANAGER_ROLE = keccak256("ASSET_MANAGER");
bytes32 constant VALORIZATION_ROLE = keccak256("VALORIZATION_MANAGER");
bytes32 constant HOPPER_ROLE = keccak256("HOPPER");

contract Vault is
    ERC7540Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlEnumerableUpgradeable,
    FeeManager
{
    /// @custom:storage-location erc7201:hopper.storage.vault
    struct VaultStorage {
        uint256 toUnwind;
        // totalAssets maj
        uint256 newTotalAssets;
        uint256 newTotalAssetsTimestamp;
        uint256 newTotalAssetsCooldown;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.vault")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant HopperVaultStorage =
        0x0e6b3200a60a991c539f47dddaca04a18eb4bcf2b53906fb44751d827f001400;

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
        string memory symbol,
        RoleSchema calldata roleSchema,
        FeeSchema calldata feeSchema,
        uint256 cooldown
    ) public virtual initializer {
        __ERC4626_init(underlying);
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __ERC20Pausable_init();
        __FeeManager_init(feeSchema);
        __ERC7540_init(underlying);
        VaultStorage storage $ = _getVaultStorage();
        $.newTotalAssetsCooldown = cooldown;

        _grantRole(HOPPER_ROLE, roleSchema.dao); // TODO PUT A REAL ADDRESS
        _setRoleAdmin(HOPPER_ROLE, HOPPER_ROLE); // only hopper manage itself

        _grantRole(ASSET_MANAGER_ROLE, roleSchema.assetManager);
        _setRoleAdmin(ASSET_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(VALORIZATION_ROLE, roleSchema.valorization);
        _setRoleAdmin(VALORIZATION_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(DEFAULT_ADMIN_ROLE, roleSchema.admin);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC7540Upgradeable, ERC20Upgradeable) {
        return ERC20PausableUpgradeable._update(from, to, value);
    }

    function decimals()
        public
        view
        override(ERC20Upgradeable, ERC7540Upgradeable)
        returns (uint8)
    {
        return ERC4626Upgradeable.decimals();
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

    function updateTotalAssets(
        uint256 _newTotalAssets
    ) public onlyRole(VALORIZATION_ROLE) {
        VaultStorage storage $ = _getVaultStorage();
        $.newTotalAssets = _newTotalAssets;
        $.newTotalAssetsTimestamp = block.timestamp;
    }

    function settle() public override onlyRole(VALORIZATION_ROLE) {
        VaultStorage storage $vault = _getVaultStorage();
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        // we allowe to settle only if the newTotalAssets:
        // - is not to recent (must be > $.newTotalAssetsCooldown
        require(
            $vault.newTotalAssetsTimestamp + $vault.newTotalAssetsCooldown <=
                block.timestamp
        );

        // avoid settle using same newTotalAssets input
        $vault.newTotalAssetsTimestamp = 0;

        // caching the value
        uint256 epochId = $erc7540.epochId;

        // First we update the vault value and collect fees.
        _collectFees($vault.newTotalAssets);
        $erc7540.totalAssets = $vault.newTotalAssets;

        EpochData storage epoch = $erc7540.epochs[epochId];
        uint256 _totalAssets = totalAssets();

        // Then we proceed the deposit request and save the deposit parameters
        uint256 pendingAssets = IERC20(asset()).balanceOf(pendingSilo());
        if (pendingAssets > 0) {
            epoch.totalAssetsDeposit = _totalAssets;
            epoch.totalSupplyDeposit = totalSupply();
            uint256 shares = _convertToShares(
                pendingAssets,
                Math.Rounding.Floor
            );
            _mint(claimableSilo(), shares);
            _totalAssets += pendingAssets;
            $erc7540.totalAssets = _totalAssets;
        }

        // Then we proceed the redeem request and save the redeem parameters
        uint256 assets = _convertToAssets(
            balanceOf(pendingSilo()),
            Math.Rounding.Floor
        );
        if (assets > 0) {
            epoch.totalAssetsRedeem = _totalAssets;
            epoch.totalSupplyRedeem = totalSupply();
            _burn(pendingSilo(), balanceOf(pendingSilo()));
            $erc7540.totalAssets = _totalAssets - assets;
            $vault.toUnwind += assets;
        }

        // Then we put a maximum of assets in the claimable silo so that user can claim
        if (pendingAssets > 0 && $vault.toUnwind > 0)
            _unwind(pendingAssets, pendingSilo());

        // If there is a surplus of assets, we send those to the asset manager
        pendingAssets = IERC20(asset()).balanceOf(pendingSilo());
        if (pendingAssets > 0) {
            address assetManager = getRoleMember(ASSET_MANAGER_ROLE, 0);
            // there must be an asset manager
            require(assetManager != address(0));
            IERC20(asset()).safeTransferFrom(
                pendingSilo(),
                assetManager,
                pendingAssets
            );
        }

        $erc7540.epochId = epochId + 1;
    }

    function unwind(uint256 amount) external onlyRole(ASSET_MANAGER_ROLE) {
        _unwind(amount, _msgSender());
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
        override(ERC7540Upgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return true;
    }

    function setProtocolFee(
        uint256 _protocolFee
    ) public override onlyRole(HOPPER_ROLE) {
        super.setProtocolFee(_protocolFee);
    }

    function setManagementFee(
        uint256 _managementFee
    ) public override onlyRole(ASSET_MANAGER_ROLE) {
        super.setManagementFee(_managementFee);
    }

    function setPerformanceFee(
        uint256 _performanceFee
    ) public override onlyRole(ASSET_MANAGER_ROLE) {
        super.setPerformanceFee(_performanceFee);
    }

    function _collectFees(uint256 newTotalAssets) internal override {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        uint256 _averageAUM = newTotalAssets;
        uint256 managementFee = calculateManagementFee(_averageAUM);
        uint256 _netAUM;
        unchecked {
            _netAUM = newTotalAssets - managementFee;
        }
        uint256 performanceFee = calculatePerformanceFee(_netAUM);

        (uint256 managerFees, uint256 protocolFee) = calculateProtocolFee(
            managementFee + performanceFee
        );

        $.lastFeeTime = block.timestamp;

        if (_netAUM > $.highWaterMark) {
            $.highWaterMark = _netAUM;
        }

        address assetManager = getRoleMember(ASSET_MANAGER_ROLE, 0);
        address hopperDao = getRoleMember(HOPPER_ROLE, 0);
        uint256 totalSupply = totalSupply();

        if (managerFees > 0) {
            uint256 newShares = managerFees.mulDiv(totalSupply, newTotalAssets);
            _mint(assetManager, newShares);
        }

        if (protocolFee > 0) {
            uint256 newShares = protocolFee.mulDiv(totalSupply, newTotalAssets);
            _mint(hopperDao, newShares);
        }
    }
}
