// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ILogicRegistry} from "./protocol-v0.2.0/ILogicRegistry.sol";
import {
    ERC1967Utils,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract VaultProxy is TransparentUpgradeableProxy {
    ILogicRegistry public immutable REGISTRY;
    string public proxyVersion;

    constructor(
        string memory _proxyVersion,
        address _logic,
        address _logicRegistry,
        address initialOwner,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logicAtConstruction(_logic, _proxyVersion, _logicRegistry), initialOwner, _data) {
        proxyVersion = _proxyVersion;
        REGISTRY = ILogicRegistry(_logicRegistry);
    }

    function _logicAtConstruction(
        address _logic,
        string memory _proxyVersion,
        address _logicRegistry
    ) internal view returns (address) {
        if (_logic == address(0)) {
            return ILogicRegistry(_logicRegistry).defaultLogic(_proxyVersion);
        }
        if (!REGISTRY.canUseLogic(_proxyVersion, _implementation(), _logic)) revert("can't update");

        return _logic;
    }

    function upgradeToAndCall(address logic, bytes calldata _data) external payable {
        if (!REGISTRY.canUseLogic(proxyVersion, implementation(), logic)) revert("can't update");
        ERC1967Utils.upgradeToAndCall(logic, _data);
    }

    function implementation() public view returns (address) {
        return _implementation();
    }

    receive() external payable {} // to remove
}
