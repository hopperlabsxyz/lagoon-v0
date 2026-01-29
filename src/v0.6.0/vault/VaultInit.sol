// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC7540} from "../ERC7540.sol";
import {FeeManager} from "../FeeManager.sol";
import {Roles} from "../Roles.sol";
import {Whitelistable} from "../Whitelistable.sol";
import {State, WhitelistState} from "../primitives/Enums.sol";
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
import {InitStruct} from "./Vault-v0.6.0.sol";

import {GuardrailsManager} from "../GuardRailsManager.sol";
import {DepositSync, Referral, StateUpdated} from "../primitives/Events.sol";
import {Guardrails} from "../primitives/Struct.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeRegistry} from "@src/protocol-v2/FeeRegistry.sol";

using SafeERC20 for IERC20;

/// @custom:oz-upgrades-from src/v0.4.0/Vault.sol:Vault
contract VaultInit is ERC7540, Whitelistable, FeeManager, GuardrailsManager {
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
                valuationManager: init.valuationManager,
                securityCouncil: init.securityCouncil
            })
        );
        __ERC20_init(init.name, init.symbol);
        __ERC20Pausable_init();
        __ERC4626_init(init.underlying);
        __ERC7540_init(init.underlying, wrappedNativeToken);
        __Whitelistable_init(init.whitelistState);
        __FeeManager_init(
            feeRegistry,
            init.managementRate,
            init.performanceRate,
            IERC20Metadata(address(init.underlying)).decimals(),
            init.rateUpdateCooldown,
            init.entryRate,
            init.exitRate
        );
        __GuardrailsManager_init(Guardrails({upperRate: type(uint256).max, lowerRate: type(int256).min + 1}));

        // $.totalAssets = initialTotalAssets;
        // mint(initialTotalAssets, address(init.safe));

        emit StateUpdated(State.Open);
    }

    /////////////////////////////////////////////
    // ## DEPOSIT AND REDEEM FLOW FUNCTIONS ## //
    /////////////////////////////////////////////

    function requestDeposit(
        uint256,
        address,
        address
    ) public payable override returns (uint256) {
        return 0;
    }

    function requestRedeem(
        uint256,
        address,
        address
    ) public returns (uint256) {
        return 0;
    }

    function settleDeposit(
        uint256
    ) public override {}

    function settleRedeem(
        uint256
    ) public override {}

    function isTotalAssetsValid() public view returns (bool) {
        return false;
    }

    function safe() public view override returns (address) {
        return address(0);
    }

    function _protocolFeeReceiver() internal view override returns (address) {
        return address(0);
    }
}
