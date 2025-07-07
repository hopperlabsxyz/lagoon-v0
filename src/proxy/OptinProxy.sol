// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ILogicRegistry} from "../protocol-v2/ILogicRegistry.sol";

import {ERC1967Utils, ITransparentUpgradeableProxy, TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";

import {DelayProxyAdmin} from "./DelayProxyAdmin.sol";

/**
 * @dev This contract implements a proxy that is upgradeable through an associated {DelayProxyAdmin} instance.
 *
 * To avoid https://medium.com/nomic-labs-blog/malicious-backdoors-in-ethereum-proxies-62629adf3357[proxy selector
 * clashing], which can potentially be used in an attack, this contract uses the
 * https://blog.openzeppelin.com/the-transparent-proxy-pattern/[transparent proxy pattern]. This pattern implies two
 * things that go hand in hand:
 *
 * 1. If any account other than the admin calls the proxy, the call will be forwarded to the implementation, even if
 * that call matches the {ITransparentUpgradeableProxy-upgradeToAndCall} function exposed by the proxy itself.
 * 2. If the admin calls the proxy, it can call the `upgradeToAndCall` function but any other call won't be forwarded to
 * the implementation. If the admin tries to call a function on the implementation it will fail with an error indicating
 * the proxy admin cannot fallback to the target implementation.
 *
 * These properties mean that the admin account can only be used for upgrading the proxy, so it's best if it's a
 * dedicated account that is not used for anything else. This will avoid headaches due to sudden errors when trying to
 * call a function from the proxy implementation. For this reason, the proxy deploys an instance of {ProxyAdmin} and
 * allows upgrades only if they come through it. You should think of the `ProxyAdmin` instance as the administrative
 * interface of the proxy, including the ability to change who can trigger upgrades by transferring ownership.
 *
 * NOTE: The real interface of this proxy is that defined in `ITransparentUpgradeableProxy`. This contract does not
 * inherit from that interface, and instead `upgradeToAndCall` is implicitly implemented using a custom dispatch
 * mechanism in `_fallback`. Consequently, the compiler will not produce an ABI for this contract. This is necessary to
 * fully implement transparency without decoding reverts caused by selector clashes between the proxy and the
 * implementation.
 *
 * NOTE: This proxy does not inherit from {Context} deliberately. The {DelayProxyAdmin} of this contract won't send a
 * meta-transaction in any way, and any other meta-transaction setup should be made in the implementation contract.
 *
 * IMPORTANT: This contract avoids unnecessary storage reads by setting the admin only during construction as an
 * immutable variable, preventing any changes thereafter. However, the admin slot defined in ERC-1967 can still be
 * overwritten by the implementation logic pointed to by this proxy. In such cases, the contract may end up in an
 * undesirable state where the admin slot is different from the actual admin.
 *
 * WARNING: It is not recommended to extend this contract to add additional external functions. If you do so, the
 * compiler will not check that there are no selector conflicts, due to the note above. A selector clash between any new
 * function and the functions declared in {ITransparentUpgradeableProxy} will be resolved in favor of the new one. This
 * could render the `upgradeToAndCall` function inaccessible, preventing upgradeability and compromising transparency.
 */

/// @title OptinProxy
/// @notice A transparent upgradeable proxy that allows opting into logic upgrades through a registry
/// @dev Extends TransparentUpgradeableProxy with additional logic verification through a registry
contract OptinProxy is ERC1967Proxy {
    // An immutable address for the admin to avoid unnecessary SLOADs before each call
    // at the expense of removing the ability to change the admin once it's set.
    // This is acceptable if the admin is always a ProxyAdmin instance or similar contract
    // with its own ability to transfer the permissions to another account.
    address private immutable _admin;

    /// @notice The immutable logic registry contract that governs which logic implementations can be used
    ILogicRegistry public immutable REGISTRY;

    ///@notice The proxy caller is the current admin, and can't fallback to the proxy target.
    error ProxyDeniedAdminAccess();

    /// @notice Error thrown when an unauthorized logic update is attempted
    error UpdateNotAllowed();

    /// @dev Initializes an upgradeable proxy managed by an instance of a {DelayProxyAdmin} with an `initialOwner`,
    /// backed by the implementation at `_logic`, and optionally initialized with `_data` as explained in
    /// {ERC1967Proxy-constructor}.
    ///
    /// @notice Constructs the OptinProxy contract
    /// @dev Initializes the proxy with logic, registry, admin and initialization data
    /// @param _logic The initial logic implementation address (can be zero to use registry's default)
    /// @param _logicRegistry The address of the logic registry contract
    /// @param _initialOwner The initial owner/admin of the proxy
    /// @param _initialDelay The initial delay before which an upgrade can occur by the proxy admin
    /// @param _data The initialization data to pass to the logic contract
    constructor(
        address _logic,
        address _logicRegistry,
        address _initialOwner,
        uint256 _initialDelay,
        bytes memory _data
    ) payable ERC1967Proxy(_logic, _data) {
        _admin = address(new DelayProxyAdmin(_initialOwner, _initialDelay));
        // Set the storage value and emit an event for ERC-1967 compatibility
        ERC1967Utils.changeAdmin(_proxyAdmin());

        REGISTRY = ILogicRegistry(_logicRegistry);
    }

    /// @dev Returns the admin of this proxy.
    function _proxyAdmin() internal virtual returns (address) {
        return _admin;
    }

    /// @notice Determines the appropriate logic address to use at construction time
    /// @dev If _logic is zero, uses registry's default. Otherwise verifies the logic is allowed
    /// @param _logic The proposed logic implementation address
    /// @param _logicRegistry The registry contract to check against
    /// @return The validated logic implementation address
    function _logicAtConstruction(
        address _logic,
        address _logicRegistry
    ) internal view returns (address) {
        if (_logic == address(0)) {
            return ILogicRegistry(_logicRegistry).defaultLogic();
        }
        if (
            !ILogicRegistry(_logicRegistry).canUseLogic(
                _implementation(),
                _logic
            )
        ) revert UpdateNotAllowed();

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
            if (
                msg.sig !=
                ITransparentUpgradeableProxy.upgradeToAndCall.selector
            ) {
                revert ProxyDeniedAdminAccess();
            } else {
                // equivalent to TransparentUpgradeableProxy.dispatchUpgradeToAndCall
                // with a check to the registry first.
                (address newImplementation, bytes memory data) = abi.decode(
                    msg.data[4:],
                    (address, bytes)
                );
                if (!REGISTRY.canUseLogic(_implementation(), newImplementation))
                    revert UpdateNotAllowed();
                ERC1967Utils.upgradeToAndCall(newImplementation, data);
            }
        } else {
            super._fallback();
        }
    }

    /**
     * @dev Upgrade the implementation of the proxy. See {ERC1967Utils-upgradeToAndCall}.
     *
     * Requirements:
     *
     * - If `data` is empty, `msg.value` must be zero.
     */
    function _dispatchUpgradeToAndCall() private {
        (address newImplementation, bytes memory data) = abi.decode(
            msg.data[4:],
            (address, bytes)
        );
        ERC1967Utils.upgradeToAndCall(newImplementation, data);
    }

    // To remove /!\
    receive() external payable {}
}
