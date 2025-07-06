// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ILogicRegistry} from "./protocol-v2/ILogicRegistry.sol";
import {
    ERC1967Utils,
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title OptinProxy
/// @notice A transparent upgradeable proxy that allows opting into logic upgrades through a registry
/// @dev Extends TransparentUpgradeableProxy with additional logic verification through a registry
contract OptinProxy is TransparentUpgradeableProxy {
    /// @notice The immutable logic registry contract that governs which logic implementations can be used
    ILogicRegistry public immutable REGISTRY;

    /// @notice Error thrown when an unauthorized logic update is attempted
    error UpdateNotAllowed();

    /// @notice Constructs the OptinProxy contract
    /// @dev Initializes the proxy with logic, registry, admin and initialization data
    /// @param _logic The initial logic implementation address (can be zero to use registry's default)
    /// @param _logicRegistry The address of the logic registry contract
    /// @param initialOwner The initial owner/admin of the proxy
    /// @param _data The initialization data to pass to the logic contract
    constructor(
        address _logic,
        address _logicRegistry,
        address initialOwner,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logicAtConstruction(_logic, _logicRegistry), initialOwner, _data) {
        REGISTRY = ILogicRegistry(_logicRegistry);
    }

    /// @notice Determines the appropriate logic address to use at construction time
    /// @dev If _logic is zero, uses registry's default. Otherwise verifies the logic is allowed
    /// @param _logic The proposed logic implementation address
    /// @param _logicRegistry The registry contract to check against
    /// @return The validated logic implementation address
    function _logicAtConstruction(address _logic, address _logicRegistry) internal view returns (address) {
        if (_logic == address(0)) {
            return ILogicRegistry(_logicRegistry).defaultLogic();
        }
        if (!ILogicRegistry(_logicRegistry).canUseLogic(_implementation(), _logic)) revert UpdateNotAllowed();

        return _logic;
    }

    /**
     * @notice Handles fallback calls to the proxy
     * @dev If caller is admin, processes upgrade calls with registry verification. Otherwise forwards transparently.
     * @custom:behavior When msg.sender is admin:
     *   - Only upgradeToAndCall calls are allowed
     *   - Verifies new implementation with registry before upgrading
     * @custom:behavior When msg.sender is not admin:
     *   - Forwards call transparently to current implementation
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
}
