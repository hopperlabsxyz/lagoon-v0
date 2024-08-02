// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

// import "forge-std/Test.sol";
import {ERC7540Upgradeable, EpochData} from "./ERC7540.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {AccessControlUpgradeable, IAccessControl} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Whitelistable, WHITELISTED} from "./Whitelistable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FeeManager} from "./FeeManager.sol";
// import {console} from "forge-std/console.sol";
// import {console2} from "forge-std/console2.sol";

using Math for uint256;
using SafeERC20 for IERC20;

uint256 constant BPS_DIVIDER = 10_000;

bytes32 constant ASSET_MANAGER_ROLE = keccak256("ASSET_MANAGER");
bytes32 constant VALORIZATION_ROLE = keccak256("VALORIZATION_MANAGER");
bytes32 constant HOPPER_ROLE = keccak256("HOPPER");
bytes32 constant FEE_RECEIVER = keccak256("FEE_RECEIVER");

error CooldownNotOver();
error AssetManagerNotSet();

/// @custom:oz-upgrades-from VaultV2
contract Vault is
    ERC7540Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    Whitelistable,
    FeeManager
{
    struct InitStruct {
        IERC20 underlying;
        string name;
        string symbol;
        address dao;
        address assetManager;
        address valorization;
        address admin;
        address feeReceiver;
        address feeModule;
        address feeRegistry;
        uint256 managementRate;
        uint256 performanceRate;
        uint256 cooldown;
        bool enableWhitelist;
        address[] whitelist;
    }

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
    bytes32 private constant vaultStorage =
        0x0e6b3200a60a991c539f47dddaca04a18eb4bcf2b53906fb44751d827f001400;

    function _getVaultStorage() internal pure returns (VaultStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := vaultStorage
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor() {
        // if (disable) _disableInitializers();
    }

    function initialize(InitStruct memory init) public virtual initializer {
        __ERC4626_init(init.underlying);
        __ERC20_init(init.name, init.symbol);
        __ERC20Permit_init(init.name);
        __ERC20Pausable_init();
        __FeeManager_init(
            init.feeModule,
            init.feeRegistry,
            init.managementRate,
            init.performanceRate
        );
        __ERC7540_init(init.underlying);
        __Whitelistable_init(init.enableWhitelist);

        VaultStorage storage $ = _getVaultStorage();
        $.newTotalAssetsCooldown = init.cooldown;

        _grantRole(HOPPER_ROLE, init.dao);
        _setRoleAdmin(HOPPER_ROLE, HOPPER_ROLE);

        _grantRole(ASSET_MANAGER_ROLE, init.assetManager);
        _setRoleAdmin(ASSET_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(VALORIZATION_ROLE, init.valorization);
        _setRoleAdmin(VALORIZATION_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);

        _grantRole(FEE_RECEIVER, init.feeReceiver);
        if (init.enableWhitelist) {
            _grantRole(WHITELISTED, init.feeReceiver);
            _grantRole(WHITELISTED, init.dao);
            _grantRole(WHITELISTED, init.assetManager);
            _grantRole(WHITELISTED, init.valorization);
            _grantRole(WHITELISTED, init.admin);
            _grantRole(WHITELISTED, pendingSilo());
            _grantRole(WHITELISTED, claimableSilo());
            _grantRole(WHITELISTED, address(0));
            for (uint256 i = 0; i < init.whitelist.length; i++) {
                _grantRole(WHITELISTED, init.whitelist[i]);
            }
        }
    }

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(ERC7540Upgradeable, ERC20Upgradeable)
        onlyWhitelisted(to)
    {
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

    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) public override onlyWhitelisted(controller) returns (uint256) {
        return super.requestDeposit(assets, controller, owner);
    }

    /**
     * @param receiver who will receive the shares
     * @param controller who the depositRequest belongs to
     * @dev if whistelist is activated, receiver must be whitelisted because _update is called and
     * onlyWhitelisted modifier is applied
     */
    function _deposit(
        uint256 assets,
        address receiver,
        address controller
    ) internal override returns (uint256 shares) {
        return super._deposit(assets, receiver, controller);
    }

    /**
     * @param receiver who will receive the shares
     * @param controller who the depositRequest belongs to
     * @dev if whistelist is activated, receiver must be whitelisted, because _update is called and
     * onlyWhitelisted modifier is applied
     */
    function _mint(
        uint256 shares,
        address receiver,
        address controller
    ) internal override returns (uint256 assets) {
        return super._mint(shares, receiver, controller);
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

    function _takeFees() internal {
        if (lastFeeTime() == block.timestamp) return;
        address feeReceiver = getRoleMember(FEE_RECEIVER, 0);
        address hopperDao = getRoleMember(HOPPER_ROLE, 0);

        uint256 _totalAssets = totalAssets();
        (uint256 managerShares, uint256 protocolShares) = _calculateFees(
            _totalAssets,
            totalSupply()
        );

        if (managerShares > 0) {
            _mint(feeReceiver, managerShares);
        }

        if (protocolShares > 0) {
            _mint(hopperDao, protocolShares);
        }
        FeeManagerStorage storage $feeManagerStorage = _getFeeManagerStorage();
        $feeManagerStorage.lastFeeTime = block.timestamp;
    }

    function settleDeposit() public override onlyRole(VALORIZATION_ROLE) {
        VaultStorage storage $vault = _getVaultStorage();
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        if (
            $vault.newTotalAssetsTimestamp + $vault.newTotalAssetsCooldown >
            block.timestamp
        ) revert CooldownNotOver();

        $erc7540.totalAssets = $vault.newTotalAssets;
        $vault.newTotalAssetsTimestamp = type(uint256).max; // we do not allow to use 2 time the same newTotalAssets in a row
        _setHighWaterMark($erc7540.totalAssets);
        _takeFees();
        _settleDeposit();
    }

    function _settleDeposit() public {
        uint256 pendingAssets = IERC20(asset()).balanceOf(pendingSilo());
        if (pendingAssets == 0) return;

        // Then save the deposit parameters
        ERC7540Storage storage $erc7540 = _getERC7540Storage();
        uint256 _totalAssets = totalAssets();
        uint256 depositId = $erc7540.depositId;
        EpochData storage epoch = $erc7540.epochs[depositId];
        epoch.totalAssets = _totalAssets;
        epoch.totalSupply = totalSupply();

        uint256 shares = _convertToShares(pendingAssets, Math.Rounding.Floor);
        _mint(claimableSilo(), shares);
        _totalAssets += pendingAssets;
        $erc7540.totalAssets = _totalAssets;
        // We must not take into account new assets into next fee calculation
        _increaseHighWaterMark(pendingAssets);

        address assetManager = getRoleMember(ASSET_MANAGER_ROLE, 0);
        IERC20(asset()).safeTransferFrom(
            pendingSilo(),
            assetManager,
            pendingAssets
        );
        // let's assess if we can do a settle redeem
        // assets in the safe ready to be taken
        uint256 assetsInTheSafe = IERC20(asset()).balanceOf(assetManager);
        uint256 assetsToWithdraw = _convertToAssets(
            balanceOf(pendingSilo()),
            Math.Rounding.Floor
        );
        if (assetsToWithdraw > 0 && assetsToWithdraw <= assetsInTheSafe)
            _settleRedeem();

        $erc7540.depositId += 2;
        // todo emit event
    }

    function settleRedeem() public override onlyRole(VALORIZATION_ROLE) {
        VaultStorage storage $vault = _getVaultStorage();
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        if (
            $vault.newTotalAssetsTimestamp + $vault.newTotalAssetsCooldown >
            block.timestamp
        ) revert CooldownNotOver();

        $erc7540.totalAssets = $vault.newTotalAssets;
        $vault.newTotalAssetsTimestamp = type(uint256).max; // we do not allow to use 2 times the same newTotalAssets
        _setHighWaterMark($erc7540.totalAssets);
        _takeFees();
        _settleRedeem();
    }

    function _settleRedeem() internal {
        uint256 pendingShares = balanceOf(pendingSilo());
        if (pendingShares == 0) return;

        uint256 assets = _convertToAssets(
            balanceOf(pendingSilo()),
            Math.Rounding.Floor
        );
        if (assets == 0) return;
        // We must not take into account assets leaving the fund into next fee calculation

        // first we save epochs data
        ERC7540Storage storage $erc7540 = _getERC7540Storage();
        uint256 redeemId = $erc7540.redeemId;
        EpochData storage epoch = $erc7540.epochs[redeemId];
        uint256 _totalAssets = totalAssets();
        epoch.totalAssets = _totalAssets;
        epoch.totalSupply = totalSupply();

        // then we proceed to redeem the shares
        _burn(pendingSilo(), balanceOf(pendingSilo()));
        $erc7540.totalAssets = _totalAssets - assets;

        // high water mark must now be decreased of withdrawn assets
        uint256 newHighWaterMark = highWaterMark();
        newHighWaterMark -= assets;
        _decreaseHighWaterMark(newHighWaterMark);

        IERC20(asset()).safeTransferFrom(
            getRoleMember(ASSET_MANAGER_ROLE, 0),
            claimableSilo(),
            assets
        );
        $erc7540.redeemId += 2;
    }

    // function settle() public onlyRole(VALORIZATION_ROLE) {
    //     VaultStorage storage $vault = _getVaultStorage();
    //     ERC7540Storage storage $erc7540 = _getERC7540Storage();
    //     FeeManagerStorage storage $feeManager = _getFeeManagerStorage();

    //     address assetManager = getRoleMember(ASSET_MANAGER_ROLE, 0);
    //     address feeReceiver = getRoleMember(FEE_RECEIVER, 0);
    //     address hopperDao = getRoleMember(HOPPER_ROLE, 0);

    //     // we allowe to settle only if the newTotalAssets:
    //     // is not to recent must be > $.newTotalAssetsCooldown
    //     if (
    //         $vault.newTotalAssetsTimestamp + $vault.newTotalAssetsCooldown >
    //         block.timestamp
    //     ) revert CooldownNotOver();

    //     // avoid settle using same newTotalAssets input
    //     $vault.newTotalAssetsTimestamp = type(uint256).max;

    //     // caching the value
    //     // uint256 epochId = $erc7540.;

    //     $erc7540.totalAssets = $vault.newTotalAssets;

    //     EpochData storage epoch = $erc7540.epochs[epochId];
    //     uint256 _totalAssets = totalAssets();

    //     (uint256 managerShares, uint256 protocolShares) = _calculateFees(
    //         _totalAssets,
    //         totalSupply()
    //     );

    //     if (managerShares > 0) {
    //         _mint(feeReceiver, managerShares);
    //     }

    //     if (protocolShares > 0) {
    //         _mint(hopperDao, protocolShares);
    //     }

    //     uint256 newHighWaterMark = _totalAssets;

    //     // Then we proceed the deposit request and save the deposit parameters
    //     uint256 pendingAssets = IERC20(asset()).balanceOf(pendingSilo());

    //     // We must not take into account new assets into next fee calculation
    //     newHighWaterMark += pendingAssets;

    //     epoch.totalAssets = _totalAssets;
    //     epoch.totalSupply = totalSupply();
    //     if (pendingAssets > 0) {
    //         uint256 shares = _convertToShares(
    //             pendingAssets,
    //             Math.Rounding.Floor
    //         );
    //         _mint(claimableSilo(), shares);
    //         _totalAssets += pendingAssets;
    //         $erc7540.totalAssets = _totalAssets;
    //     }

    //     // Then we proceed the redeem request and save the redeem parameters
    //     uint256 assets = _convertToAssets(
    //         balanceOf(pendingSilo()),
    //         Math.Rounding.Floor
    //     );

    //     // We must not take into account assets leaving the fund into next fee calculation
    //     newHighWaterMark -= assets;

    //     epoch.totalAssets = _totalAssets;
    //     epoch.totalSupply = totalSupply();
    //     if (assets > 0) {
    //         _burn(pendingSilo(), balanceOf(pendingSilo()));
    //         $erc7540.totalAssets = _totalAssets - assets;
    //         $vault.toUnwind += assets;
    //     }

    //     // Then we put a maximum of assets in the claimable silo so that user can claim
    //     // if (pendingAssets > 0 && $vault.toUnwind > 0)
    //     // _unwind(pendingAssets, pendingSilo());
    //     // If there is a surplus of assets, we send those to the asset manager
    //     pendingAssets = IERC20(asset()).balanceOf(pendingSilo());
    //     if (pendingAssets > 0) {
    //         // there must be an asset manager
    //         if (assetManager == address(0)) revert AssetManagerNotSet();

    //         IERC20(asset()).safeTransferFrom(
    //             pendingSilo(),
    //             assetManager,
    //             pendingAssets
    //         );
    //     }

    //     _setHighWaterMark(newHighWaterMark);
    //     $feeManager.lastFeeTime = block.timestamp;
    //     $erc7540.epochId = epochId + 1;
    // }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC7540Upgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return
            AccessControlEnumerableUpgradeable.supportsInterface(interfaceId) ||
            ERC7540Upgradeable.supportsInterface(interfaceId);
    }

    function hopperRole() public view returns (address) {
        return getRoleMember(HOPPER_ROLE, 0);
    }

    function adminRole() public view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }

    function assetManagerRole() public view returns (address) {
        return getRoleMember(ASSET_MANAGER_ROLE, 0);
    }

    function valorizationRole() public view returns (address) {
        return getRoleMember(VALORIZATION_ROLE, 0);
    }

    function grantRole(
        bytes32 role,
        address account
    )
        public
        virtual
        override(AccessControlUpgradeable, IAccessControl)
        onlyRole(getRoleAdmin(role))
    {
        // we accept only one role holder for the hopper/asset manager/valorization/fee receiver/admin role
        if (role != WHITELISTED) _revokeRole(role, getRoleMember(role, 0));
        super.grantRole(role, account);
    }

    /////////////////
    // MVP UPGRADE //
    /////////////////

    // Pending states
    function pendingDeposit() public view returns (uint256) {
        return IERC20(asset()).balanceOf(pendingSilo());
    }

    function pendingRedeem() public view returns (uint256) {
        return balanceOf(pendingSilo());
    }

    // Sensible variables countdown update
    function newTotalAssetsCountdown() public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        if ($.newTotalAssetsTimestamp == type(uint256).max) {
            return 0;
        }
        if (
            $.newTotalAssetsTimestamp + $.newTotalAssetsCooldown >
            block.timestamp
        ) {
            return
                $.newTotalAssetsTimestamp +
                $.newTotalAssetsCooldown -
                block.timestamp;
        }
        return 0;
    }

    function updateNewTotalAssetsCountdown(
        uint256 _newTotalAssetsCooldown
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        VaultStorage storage $ = _getVaultStorage();
        $.newTotalAssetsCooldown = _newTotalAssetsCooldown;
    }
}
