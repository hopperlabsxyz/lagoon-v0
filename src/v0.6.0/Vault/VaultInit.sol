// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ERC7540} from "../ERC7540.sol";
import {FeeManager} from "../FeeManager.sol";
import {Roles} from "../Roles.sol";
import {Whitelistable} from "../Whitelistable.sol";
import {State} from "../primitives/Enums.sol";
import {
    CantDepositNativeToken,
    Closed,
    ERC7540InvalidOperator,
    NotClosing,
    NotOpen,
    NotWhitelisted,
    OnlyAsyncDepositAllowed,
    OnlySyncDepositAllowed,
    ValuationUpdateNotAllowed
} from "../primitives/Errors.sol";
import {Vault_Storage} from "./VaultStorage.sol";

import {DepositSync, Referral, StateUpdated} from "../primitives/Events.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeRegistry} from "@src/protocol-v1/FeeRegistry.sol";

using SafeERC20 for IERC20;

/// @custom:storage-definition erc7201:hopper.storage.vault
/// @param underlying The address of the underlying asset.
/// @param name The name of the vault and by extension the ERC20 token.
/// @param symbol The symbol of the vault and by extension the ERC20 token.
/// @param safe The address of the safe smart contract.
/// @param whitelistManager The address of the whitelist manager.
/// @param valuationManager The address of the valuation manager.
/// @param admin The address of the owner of the vault.
/// @param feeReceiver The address of the fee receiver.
/// @param feeRegistry The address of the fee registry.
/// @param wrappedNativeToken The address of the wrapped native token.
/// @param managementRate The management fee rate.
/// @param performanceRate The performance fee rate.
/// @param rateUpdateCooldown The cooldown period for updating the fee rates.
/// @param enableWhitelist A boolean indicating whether the whitelist is enabled.
struct InitStruct {
    IERC20 underlying;
    string name;
    string symbol;
    address safe;
    address whitelistManager;
    address valuationManager;
    address admin;
    address feeReceiver;
    uint16 managementRate;
    uint16 performanceRate;
    bool enableWhitelist;
    uint256 rateUpdateCooldown;
}

/// @custom:oz-upgrades-from src/v0.4.0/Vault.sol:Vault
contract VaultInit is Vault_Storage, ERC7540, Whitelistable, FeeManager {
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(
        bool disable
    ) {
        if (disable) _disableInitializers();
    }

    /// @notice Initializes the vault.
    /// @param data The encoded initialization parameters of the vault.
    function initialize(
        bytes memory data,
        address feeRegistry,
        address wrappedNativeToken
    ) public virtual initializer {
        InitStruct memory init = abi.decode(data, (InitStruct));
        __Ownable_init(init.admin); // initial vault owner
        __Roles_init(
            Roles.RolesStorage({
                whitelistManager: init.whitelistManager,
                feeReceiver: init.feeReceiver,
                safe: init.safe,
                feeRegistry: FeeRegistry(feeRegistry),
                valuationManager: init.valuationManager
            })
        );
        __ERC20_init(init.name, init.symbol);
        __ERC20Pausable_init();
        __ERC4626_init(init.underlying);
        __ERC7540_init(init.underlying, wrappedNativeToken);
        __Whitelistable_init(init.enableWhitelist);
        __FeeManager_init(
            feeRegistry,
            init.managementRate,
            init.performanceRate,
            IERC20Metadata(address(init.underlying)).decimals(),
            init.rateUpdateCooldown
        );

        emit StateUpdated(State.Open);
    }

    /////////////////////
    // ## MODIFIERS ## //
    /////////////////////

    /////////////////////////////////////////////
    // ## DEPOSIT AND REDEEM FLOW FUNCTIONS ## //
    /////////////////////////////////////////////

    /// @param assets The amount of assets to deposit.
    /// @param controller The address of the controller involved in the deposit request.
    /// @param owner The address of the owner for whom the deposit is requested.
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) public payable override returns (uint256 requestId) {
        return 0;
    }

    /// @notice Requests the redemption of tokens, subject to whitelist validation.
    /// @param shares The number of tokens to redeem.
    /// @param controller The address of the controller involved in the redemption request.
    /// @param owner The address of the token owner requesting redemption.
    /// @return requestId The id of the redeem request.
    function requestRedeem(uint256 shares, address controller, address owner) public returns (uint256 requestId) {
        return 0;
    }

    /// @notice Settles deposit requests, integrates user funds into the vault strategy, and enables share claims.
    /// If possible, it also settles redeem requests.
    /// @dev Unusable when paused, protected by whenNotPaused in _updateTotalAssets.
    function settleDeposit(
        uint256 _newTotalAssets
    ) public override {}

    /// @notice Settles redeem requests, only callable by the safe.
    /// @dev Unusable when paused, protected by whenNotPaused in _updateTotalAssets.
    /// @dev After updating totalAssets, it takes fees, updates highWaterMark and finally settles redeem requests.
    /// @inheritdoc ERC7540
    function settleRedeem(
        uint256 _newTotalAssets
    ) public override {}

    function isTotalAssetsValid() public view returns (bool) {
        return block.timestamp < _getERC7540Storage().totalAssetsExpiration;
    }

    function safe() public view override returns (address) {
        return _getRolesStorage().safe;
    }
}
