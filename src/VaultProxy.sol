// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ILogicRegistry} from "./protocol-v0.2.0/ILogicRegistry.sol";
import {
    ERC1967Utils,
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract VaultProxy is TransparentUpgradeableProxy {
    ILogicRegistry public immutable implementationRegistry;
    string public version;

    constructor(
        string memory _version,
        address _logic,
        address initialOwner,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logicAtConstruction(_logic), initialOwner, _data) {
        version = _version;
    }

    function _logicAtConstruction(
        address _logic
    ) internal view returns (address) {
        if (_logic == address(0)) {
            return implementation();
        }
        if (!implementationRegistry.canUseLogic(version, address(0), _logic)) revert("can't update");

        return _logic;
    }

    function upgradeToAndCall(address logic, bytes calldata _data) external payable {
        if (!implementationRegistry.canUseLogic(version, address(0), logic)) revert("can't update");
        ERC1967Utils.upgradeToAndCall(logic, _data);
    }

    function implementation() public view returns (address) {
        return _implementation();
    }

    receive() external payable {} // to remove
}
