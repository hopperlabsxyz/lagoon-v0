// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ILogicRegistry} from "./ILogicRegistry.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title LogicRegistry
abstract contract LogicRegistry is Ownable2StepUpgradeable, ILogicRegistry {
    /// @custom:storage-location erc7201:lagoon.storage.LogicRegistry
    struct LogicRegistryStorage {
        mapping(string version => address logic) defaultLogic;
        mapping(string version => mapping(address logic => bool)) whitelist;
    }

    // keccak256(abi.encode(uint256(keccak256("lagoon.storage.LogicRegistry")) - 1)) & ~bytes32(uint256(0xff));
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant logicRegistryStorage = 0xa63b9b2735273a8363378bc9a6a1619c72742579a0271bb71db3d083bb631c00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(
        bool disable
    ) {
        if (disable) _disableInitializers();
    }

    function _getLogicRegistryStorage() internal pure returns (LogicRegistryStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := logicRegistryStorage
        }
    }

    function updateDefaultLogic(string calldata version, address _newLogic) public onlyOwner {
        if (!_getLogicRegistryStorage().whitelist[version][_newLogic]) {
            revert LogicNotWhitelisted(_newLogic);
        }
        address previous = _getLogicRegistryStorage().defaultLogic[version];
        _getLogicRegistryStorage().defaultLogic[version] = _newLogic;
        emit DefaultLogicUpdated(version, previous, _newLogic);
    }

    function removeLogic(string calldata version, address _newLogic) public onlyOwner {
        _getLogicRegistryStorage().whitelist[version][_newLogic] = false;
        emit LogicRemoved(version, _newLogic);
    }

    function addLogic(string calldata version, address _newLogic) public onlyOwner {
        _getLogicRegistryStorage().whitelist[version][_newLogic] = true;
        emit LogicAdded(version, _newLogic);
    }

    function canUseLogic(string calldata version, address, address logic) public view returns (bool) {
        return _getLogicRegistryStorage().whitelist[version][logic];
    }
}
