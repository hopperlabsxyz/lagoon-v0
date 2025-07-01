// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ILogicRegistry} from "./protocol-v2/ILogicRegistry.sol";
import {
    ERC1967Utils,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract OptinProxy is TransparentUpgradeableProxy {
    ILogicRegistry public immutable REGISTRY;
    string public proxyVersion;

    constructor(
        address _logic,
        address _logicRegistry,
        address initialOwner,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logicAtConstruction(_logic, _logicRegistry), initialOwner, _data) {
        REGISTRY = ILogicRegistry(_logicRegistry);
    }

    function _logicAtConstruction(address _logic, address _logicRegistry) internal view returns (address) {
        if (_logic == address(0)) {
            return ILogicRegistry(_logicRegistry).defaultLogic();
        }
        if (!REGISTRY.canUseLogic(_implementation(), _logic)) revert("can't update");

        return _logic;
    }

    function upgradeToAndCall(address logic, bytes calldata _data) external payable {
        if (!REGISTRY.canUseLogic(implementation(), logic)) revert("can't update");
        ERC1967Utils.upgradeToAndCall(logic, _data);
    }

    function implementation() public view returns (address) {
        return _implementation();
    }

    receive() external payable {} // to remove
}
