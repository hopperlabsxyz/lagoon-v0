// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ILogicRegistry} from "./protocol-v0.2.0/ILogicRegistry.sol";
import {
    ERC1967Utils,
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";

contract VaultProxy is TransparentUpgradeableProxy {
    ILogicRegistry public immutable logicRegistry;
    string public version;

    constructor(
        string memory _version,
        address _logic,
        address _logicRegistry,
        address initialOwner,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logicAtConstruction(_logic, _version, _logicRegistry), initialOwner, _data) {
        version = _version;
        logicRegistry = ILogicRegistry(_logicRegistry);
    }

    function _logicAtConstruction(
        address _logic,
        string memory _version,
        address _logicRegistry
    ) internal view returns (address) {
        if (_logic == address(0)) {
            return ILogicRegistry(_logicRegistry).defaultLogic(_version);
        }
        if (!logicRegistry.canUseLogic(_version, _implementation(), _logic)) revert("can't update");

        return _logic;
    }

    function upgradeToAndCall(address logic, bytes calldata _data) external payable {
        if (!logicRegistry.canUseLogic(version, implementation(), logic)) revert("can't update");
        ERC1967Utils.upgradeToAndCall(logic, _data);
    }

    function implementation() public view returns (address) {
        return _implementation();
    }

    receive() external payable {} // to remove
}
