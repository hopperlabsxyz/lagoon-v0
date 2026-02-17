// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {NameUpdated, SymbolUpdated} from "../primitives/Events.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

library ERC20Lib {
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20UpgradeableStorage() private pure returns (ERC20Upgradeable.ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    function updateName(
        string memory newName
    ) public {
        ERC20Upgradeable.ERC20Storage storage $ = _getERC20UpgradeableStorage();
        emit NameUpdated($._name, newName);
        $._name = newName;
    }

    function updateSymbol(
        string memory newSymbol
    ) public {
        ERC20Upgradeable.ERC20Storage storage $ = _getERC20UpgradeableStorage();
        emit SymbolUpdated($._symbol, newSymbol);
        $._symbol = newSymbol;
    }
}

