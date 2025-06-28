// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ILogicRegistry} from "./ILogicRegistry.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title LogicRegistry
abstract contract LogicRegistry is Ownable2StepUpgradeable, ILogicRegistry {
    /// @custom:storage-location erc7201:lagoon.storage.LogicRegistry
    struct LogicRegistryStorage {
        mapping(string proxyVersion => address logic) defaultLogic;
        mapping(string proxyVersion => mapping(address logic => bool)) whitelist;
    }

    // keccak256(abi.encode(uint256(keccak256("lagoon.storage.LogicRegistry")) - 1)) & ~bytes32(uint256(0xff));
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant logicRegistryStorage = 0xa63b9b2735273a8363378bc9a6a1619c72742579a0271bb71db3d083bb631c00;

    function _getLogicRegistryStorage() internal pure returns (LogicRegistryStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := logicRegistryStorage
        }
    }

    function updateDefaultLogic(string calldata proxyVersion, address _newLogic) public onlyOwner {
        if (!_getLogicRegistryStorage().whitelist[proxyVersion][_newLogic]) {
            addLogic(proxyVersion, _newLogic);
        }
        address previous = _getLogicRegistryStorage().defaultLogic[proxyVersion];
        _getLogicRegistryStorage().defaultLogic[proxyVersion] = _newLogic;
        emit DefaultLogicUpdated(proxyVersion, previous, _newLogic);
    }

    function removeLogic(string calldata proxyVersion, address _newLogic) public onlyOwner {
        _getLogicRegistryStorage().whitelist[proxyVersion][_newLogic] = false;
        emit LogicRemoved(proxyVersion, _newLogic);
    }

    function addLogic(string calldata proxyVersion, address _newLogic) public onlyOwner {
        _getLogicRegistryStorage().whitelist[proxyVersion][_newLogic] = true;
        emit LogicAdded(proxyVersion, _newLogic);
    }

    function canUseLogic(string calldata proxyVersion, address, address logic) public view returns (bool) {
        return _getLogicRegistryStorage().whitelist[proxyVersion][logic];
    }

    function defaultLogic(
        string calldata proxyVersion
    ) external view returns (address) {
        return _getLogicRegistryStorage().defaultLogic[proxyVersion];
    }
}
