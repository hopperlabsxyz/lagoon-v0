// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {VaultStorage} from "../primitives/VaultStorage.sol"; // Import the shared struct

/// @custom:oz-upgrades-from src/v0.4.0/Vault.sol:Vault
contract VaultBase {
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
