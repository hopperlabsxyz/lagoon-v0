// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

// import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {VaultProxy} from "./VaultProxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

struct InitStruct {
    address underlying;
    string name;
    string symbol;
    address safe;
    address whitelistManager;
    address valuationManager;
    address admin;
    address feeReceiver;
    uint16 managementRate;
    uint16 performanceRate;
    bool enableWhitelist;
    uint256 rateUpdateCooldown;
}

interface IVault {
    function initialize(bytes memory data, address feeRegistry, address wrappedNativeToken) external;
}

/// @title BeaconProxyFactory
/// @notice A factory contract for creating BeaconProxy instances with upgradeable functionality
/// @dev Inherits from UpgradeableBeacon to provide upgrade functionality for all created proxies
contract ProxyFactory is OwnableUpgradeable {
    event BeaconProxyDeployed(address proxy, address deployer);

    /// @notice Address of the registry contract
    address public REGISTRY;

    /// @notice Address of the wrapped native token (e.g., WETH)
    address public WRAPPED_NATIVE;

    /// @notice Mapping to track whether an address is a proxy instance created by this factory
    mapping(address => bool) public isInstance;

    /// @notice Array of all proxy instances created by this factory
    address[] public instances;

    /// @notice Constructs the BeaconProxyFactory
    /// @param _registry Address of the registry contract
    /// @param _wrappedNativeToken Address of the wrapped native token (e.g., WETH)
    function initialize(address _registry, address _wrappedNativeToken, address owner) public initializer {
        __Ownable_init(owner);
        REGISTRY = _registry;
        WRAPPED_NATIVE = _wrappedNativeToken;
    }

    /// @notice Creates a new vault proxy with structured initialization data
    /// @dev Wrapper around createBeaconProxy that takes InitStruct as parameter
    /// @param init Structured initialization data for the vault
    /// @param salt Salt used for deterministic address calculation
    /// @return The address of the newly created vault proxy
    function createVaultProxy(
        address _logic,
        address initialOwner,
        InitStruct calldata init,
        bytes32 salt
    ) external returns (address) {
        address proxy = address(
            new VaultProxy{salt: salt}(
                _logic,
                REGISTRY,
                initialOwner,
                abi.encodeWithSelector(IVault.initialize.selector, abi.encode(init), REGISTRY, WRAPPED_NATIVE)
            )
        );
        isInstance[proxy] = true;
        instances.push(proxy);

        emit BeaconProxyDeployed(proxy, msg.sender);

        return address(proxy);
    }
}
