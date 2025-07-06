// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ILogicRegistry} from "./protocol-v2/ILogicRegistry.sol";
import {
    ERC1967Utils,
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract OptinProxy is TransparentUpgradeableProxy {
    ILogicRegistry public immutable REGISTRY;

    error UpdateNotAllowed();

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
        if (!ILogicRegistry(_logicRegistry).canUseLogic(_implementation(), _logic)) revert UpdateNotAllowed();

        return _logic;
    }

    /**
     * @dev If caller is the admin process the call internally, otherwise transparently fallback to the proxy behavior.
     */
    function _fallback() internal virtual override {
        if (msg.sender == _proxyAdmin()) {
            if (msg.sig != ITransparentUpgradeableProxy.upgradeToAndCall.selector) {
                revert ProxyDeniedAdminAccess();
            } else {
                // equivalent to TransparentUpgradeableProxy.dispatchUpgradeToAndCall
                // with a check to the registry first.
                (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
                if (!REGISTRY.canUseLogic(_implementation(), newImplementation)) revert UpdateNotAllowed();
                ERC1967Utils.upgradeToAndCall(newImplementation, data);
            }
        } else {
            super._fallback();
        }
    }

    receive() external payable {}
}
