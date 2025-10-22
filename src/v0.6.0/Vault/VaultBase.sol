// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

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

import {DepositSync, Referral, StateUpdated} from "../primitives/Events.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeRegistry} from "@src/protocol-v1/FeeRegistry.sol";

using SafeERC20 for IERC20;

/// @custom:oz-upgrades-from src/v0.4.0/Vault.sol:Vault
contract VaultBase {
    /// @custom:storage-location erc7201:hopper.storage.vault
    /// @param newTotalAssets The new total assets of the vault. It is used to update the totalAssets variable.
    /// @param state The state of the vault. It can be Open, Closing, or Closed.
    struct VaultStorage {
        State state;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.vault")) - 1)) & ~bytes32(uint256(0xff))
    /// @custom:slot erc7201:hopper.storage.vault
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant vaultStorage = 0x0e6b3200a60a991c539f47dddaca04a18eb4bcf2b53906fb44751d827f001400;

    /// @notice Returns the storage struct of the vault.
    /// @return _vaultStorage The storage struct of the vault.
    function _getVaultStorage() internal pure returns (VaultStorage storage _vaultStorage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _vaultStorage.slot := vaultStorage
        }
    }
}
