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
    address public immutable REGISTRY;

    /// @notice Address of the wrapped native token (e.g., WETH)
    address public immutable WRAPPED_NATIVE;

    /// @notice Mapping to track whether an address is a proxy instance created by this factory
    mapping(address => bool) public isInstance;

    /// @notice Array of all proxy instances created by this factory
    address[] public instances;

    string public version;

    /// @notice Constructs the BeaconProxyFactory
    /// @param _registry Address of the registry contract
    /// @param _wrappedNativeToken Address of the wrapped native token (e.g., WETH)
    constructor(address _registry, address _wrappedNativeToken, string memory _version) {
        REGISTRY = _registry;
        WRAPPED_NATIVE = _wrappedNativeToken;
        version = _version;
    }

    /// @notice Creates a new BeaconProxy instance
    /// @dev Uses CREATE2 with provided salt for deterministic address calculation
    /// @param init Initialization data for the proxy
    /// @param salt Salt used for deterministic address calculation
    /// @return The address of the newly created proxy
    function createProxy(
        address _logic,
        address initialOwner,
        bytes memory init,
        bytes32 salt
    ) public returns (address) {
        address proxy = address(
            new VaultProxy{salt: salt}(
                version,
                _logic,
                initialOwner,
                abi.encodeWithSelector(IVault.initialize.selector, init, REGISTRY, WRAPPED_NATIVE)
            )
        );
        isInstance[proxy] = true;
        instances.push(proxy);

        emit BeaconProxyDeployed(proxy, msg.sender);

        return address(proxy);
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
        return createProxy(_logic, initialOwner, abi.encode(init), salt);
    }
}
