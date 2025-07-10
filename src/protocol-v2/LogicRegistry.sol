// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title LogicRegistry
/// @notice Abstract contract for managing whitelisted logic implementations and default logic
/// @dev Inherits from Ownable2StepUpgradeable to provide ownership functionality with 2-step transfer
/// @dev Implements ILogicRegistry interface for standard registry functions
abstract contract LogicRegistry is Ownable2StepUpgradeable {
    error LogicNotWhitelisted(address Logic);
    error CantRemoveDefaultLogic();

    event DefaultLogicUpdated(address previous, address newImpl);
    event LogicAdded(address Logic);
    event LogicRemoved(address Logic);

    /// @custom:storage-location erc7201:hopper.storage.LogicRegistry
    /// @notice Storage layout for the LogicRegistry contract
    struct LogicRegistryStorage {
        /// @notice Address of the default logic implementation
        address defaultLogic;
        /// @notice Mapping of logic addresses to their whitelist status
        mapping(address logic => bool) whitelist;
    }

    // Storage slot for LogicRegistryStorage
    // keccak256(abi.encode(uint256(keccak256("hopper.storage.LogicRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant logicRegistryStorage = 0x1f7af4bd0bb99469a9721ca3a846842162947039ac74427c73a74c47aae0d400;

    /// @notice Returns the storage struct at the predefined slot
    /// @dev Uses assembly to access storage at a specific slot
    /// @return $ The storage struct
    function _getLogicRegistryStorage() internal pure returns (LogicRegistryStorage storage $) {
        assembly {
            $.slot := logicRegistryStorage
        }
    }

    /// @notice Updates the default logic implementation
    /// @dev Only callable by owner. Automatically adds new logic to whitelist if not already present
    /// @param _newLogic Address of the new default logic implementation
    function updateDefaultLogic(
        address _newLogic
    ) public onlyOwner {
        if (!_getLogicRegistryStorage().whitelist[_newLogic]) {
            addLogic(_newLogic);
        }
        address previous = _getLogicRegistryStorage().defaultLogic;
        _getLogicRegistryStorage().defaultLogic = _newLogic;
        emit DefaultLogicUpdated(previous, _newLogic);
    }

    /// @notice Removes a logic implementation from the whitelist
    /// @dev Only callable by owner. Does not affect default logic if removed.
    /// @param _logic Address of the logic implementation to remove
    function removeLogic(
        address _logic
    ) public onlyOwner {
        if (_logic == _getLogicRegistryStorage().defaultLogic) {
            revert CantRemoveDefaultLogic();
        }
        _getLogicRegistryStorage().whitelist[_logic] = false;
        emit LogicRemoved(_logic);
    }

    /// @notice Adds a logic implementation to the whitelist
    /// @dev Only callable by owner
    /// @param _newLogic Address of the logic implementation to add
    function addLogic(
        address _newLogic
    ) public onlyOwner {
        _getLogicRegistryStorage().whitelist[_newLogic] = true;
        emit LogicAdded(_newLogic);
    }

    /// @notice Checks if a logic implementation can be used
    /// @dev Ignores the fromLogic parameter (present in interface) and only checks whitelist status for now
    /// @param fromLogic Previous logic implementation (unused in this implementation)
    /// @param logic Address of the logic implementation to check
    /// @return True if the logic is whitelisted, false otherwise
    function canUseLogic(address fromLogic, address logic) public view returns (bool) {
        if (owner() == address(0)) return true; // logic can always be used if the protocol renounceOwnership()
        return _getLogicRegistryStorage().whitelist[logic];
    }

    /// @notice Returns the current default logic implementation address
    /// @return Address of the default logic implementation
    function defaultLogic() external view returns (address) {
        return _getLogicRegistryStorage().defaultLogic;
    }
}
