// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {NameUpdated, SymbolUpdated} from "../primitives/Events.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/// @title ERC20Lib - Library for updating ERC20 token metadata
/// @notice Provides functions to update the name and symbol of an ERC20Upgradeable token
library ERC20Lib {
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    /// @dev Returns the ERC20Upgradeable storage struct
    function _getERC20UpgradeableStorage() private pure returns (ERC20Upgradeable.ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    /// @notice Updates the name of the ERC20 token
    /// @param newName The new name for the token
    function updateName(
        string memory newName
    ) public {
        ERC20Upgradeable.ERC20Storage storage $ = _getERC20UpgradeableStorage();
        emit NameUpdated($._name, newName);
        $._name = newName;
    }

    /// @notice Updates the symbol of the ERC20 token
    /// @param newSymbol The new symbol for the token
    function updateSymbol(
        string memory newSymbol
    ) public {
        ERC20Upgradeable.ERC20Storage storage $ = _getERC20UpgradeableStorage();
        emit SymbolUpdated($._symbol, newSymbol);
        $._symbol = newSymbol;
    }
}

