// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Accessable} from "../Accessable.sol";
import {ERC7540} from "../ERC7540.sol";
import {FeeManager} from "../FeeManager.sol";
import {Roles} from "../Roles.sol";
import {State} from "../primitives/Enums.sol";
import {InitStruct} from "./Vault-v0.6.0.sol";

import {GuardrailsManager} from "../GuardRailsManager.sol";
import {StateUpdated} from "../primitives/Events.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FeeRegistry} from "@src/protocol-v2/FeeRegistry.sol";

using SafeERC20 for IERC20;

/// @custom:oz-upgrades-from src/v0.5.0/Vault.sol:Vault
contract VaultInit is ERC7540, Accessable, FeeManager, GuardrailsManager {
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(
        bool disable
    ) {
        if (disable) _disableInitializers();
    }

    /// @notice Initializes the vault with all required parameters
    /// @param data The ABI-encoded InitStruct containing vault configuration
    /// @param feeRegistry The address of the protocol fee registry
    /// @param wrappedNativeToken The address of the wrapped native token (e.g., WETH)
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
                valuationManager: init.valuationManager,
                securityCouncil: init.securityCouncil,
                superOperator: init.superOperator
            })
        );
        __ERC20_init(init.name, init.symbol);
        __ERC20Pausable_init();
        __ERC4626_init(init.underlying);
        __ERC7540_init({
            underlying: init.underlying,
            wrappedNativeToken: wrappedNativeToken,
            initialTotalAssets: init.initialTotalAssets,
            _safe: init.safe
        });
        __Accessable_init(init.accessMode, address(0));
        __FeeManager_init({
            _registry: feeRegistry,
            _managementRate: init.managementRate,
            _performanceRate: init.performanceRate,
            _decimals: IERC20Metadata(address(init.underlying)).decimals(),
            _entryRate: init.entryRate,
            _exitRate: init.exitRate,
            _haircutRate: init.haircutRate,
            _allowHighWaterMarkReset: init.allowHighWaterMarkReset
        });

        emit StateUpdated(State.Open);
    }

    /////////////////////////////////////////////
    // ## DEPOSIT AND REDEEM FLOW FUNCTIONS ## //
    /////////////////////////////////////////////

    /// @notice No-op override for the initialization contract
    /// @return Always returns 0
    function requestDeposit(
        uint256,
        address,
        address
    ) public payable override returns (uint256) {
        return 0;
    }

    /// @notice No-op override for the initialization contract
    /// @return Always returns 0
    function requestRedeem(
        uint256,
        address,
        address
    ) public returns (uint256) {
        return 0;
    }

    /// @notice No-op override for the initialization contract
    function settleDeposit(
        uint256
    ) public override {}

    /// @notice No-op override for the initialization contract
    function settleRedeem(
        uint256
    ) public override {}

    /// @notice Always returns false in the initialization contract
    /// @return Always false
    function isTotalAssetsValid() public view returns (bool) {
        return false;
    }

    /// @notice Always returns address(0) in the initialization contract
    /// @return Always address(0)
    function safe() public view override returns (address) {
        return address(0);
    }

    /// @notice Always returns false in the initialization contract
    /// @return Always false
    function isAllowed(
        address
    ) public view override(ERC7540, Accessable) returns (bool) {
        return false;
    }
}
