// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {LagoonVaultProxy} from "@src/proxy/LagoonVaultProxy.sol";
import {InitStruct} from "@src/v0.5.1/Vault.sol";

interface IVault {
    function initialize(
        bytes memory data,
        address feeRegistry,
        address wrappedNativeToken
    ) external;
}

/// @title OptinProxyFactoryStorage
/// @notice Storage layout for the OptinProxyFactory contract
/// @dev Contains registry address, wrapped native token address, and instance tracking
struct OptinProxyFactoryStorage {
    /// @notice Address of the registry contract
    address REGISTRY;
    /// @notice Address of the wrapped native token (e.g. WETH)
    address WRAPPED_NATIVE;
    /// @notice Mapping to track whether an address is a proxy instance created by this factory
    mapping(address => bool) isInstance;
}

/// @title OptinProxyFactory
/// @notice Factory contract for creating and managing OptinProxy instances
/// @dev Inherits from OwnableUpgradeable to provide ownership functionality
/// @custom:contact team@hopperlabs.xyz
/// @custom:oz-upgrades-from src/protocol-v2/OptinProxyFactory.sol:OptinProxyFactory
contract OptinProxyFactory is OwnableUpgradeable {
    /// @notice Emitted when a new proxy is deployed
    /// @param proxy Address of the newly deployed proxy
    /// @param deployer Address that initiated the deployment
    event ProxyDeployed(address proxy, address deployer);

    // Storage slot for OptinProxyFactoryStorage
    // keccak256(abi.encode(uint256(keccak256("hopper.storage.opt-inProxyFactory")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant proxyFactoryStorage = 0xda29f9cce8913a5999de49b73cd9d621b583d9cae78170dc4846b93899df8600;

    /// @notice Returns the storage struct at the predefined slot
    /// @dev Uses assembly to access storage at a specific slot
    /// @return $ The storage struct
    function _getProxyFactoryStorage() internal pure returns (OptinProxyFactoryStorage storage $) {
        assembly {
            $.slot := proxyFactoryStorage
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @notice Constructor that can disable initializers for the implementation contract
    /// @dev Prevents implementation contract from being initialized
    /// @param disable If true, disables initializers permanently
    constructor(
        bool disable
    ) {
        if (disable) _disableInitializers();
    }

    /// @notice Initializes the factory contract
    /// @dev Sets up the registry, wrapped native token, and owner
    /// @param _registry Address of the logic registry contract
    /// @param _wrappedNativeToken Address of the wrapped native token (e.g. WETH)
    /// @param owner Address of the initial owner
    function initialize(
        address _registry,
        address _wrappedNativeToken,
        address owner
    ) public initializer {
        __Ownable_init(owner);
        OptinProxyFactoryStorage storage $ = _getProxyFactoryStorage();
        $.REGISTRY = _registry;
        $.WRAPPED_NATIVE = _wrappedNativeToken;
    }

    /// @param _logic Address of the vault logic implementation
    /// @param _initialOwner Address of the initial proxy owner
    /// @param _initialDelay The initial delay before which an upgrade can occur by the proxy admin
    /// @param _init Initialization parameters for the vault
    /// @param salt Salt used for deterministic deployment
    /// @return The address of the newly created proxy
    function createVaultProxy(
        address _logic,
        address _initialOwner,
        uint256 _initialDelay,
        InitStruct calldata _init,
        bytes32 salt
    ) external returns (address) {
        OptinProxyFactoryStorage storage $ = _getProxyFactoryStorage();
        bytes memory call_data = abi.encodeCall(IVault.initialize, (abi.encode(_init), $.REGISTRY, $.WRAPPED_NATIVE));
        return createVaultProxy({
            _logic: _logic, _initialOwner: _initialOwner, _initialDelay: _initialDelay, call_data: call_data, salt: salt
        });
    }

    function createVaultProxy(
        address _logic,
        address _initialOwner,
        uint256 _initialDelay,
        bytes memory call_data,
        bytes32 salt
    ) public returns (address) {
        OptinProxyFactoryStorage storage $ = _getProxyFactoryStorage();

        address proxy = address(
            new LagoonVaultProxy{salt: salt}({
                _logic: _logic,
                _logicRegistry: $.REGISTRY,
                _initialOwner: _initialOwner,
                _initialDelay: _initialDelay,
                _data: call_data
            })
        );

        $.isInstance[proxy] = true;
        emit ProxyDeployed(proxy, msg.sender);

        return proxy;
    }

    /// @notice Returns the address of the registry contract
    /// @return The registry address
    function registry() external view returns (address) {
        return _getProxyFactoryStorage().REGISTRY;
    }

    /// @notice Returns the address of the wrapped native token
    /// @return The wrapped native token address
    function wrappedNativeToken() external view returns (address) {
        return _getProxyFactoryStorage().WRAPPED_NATIVE;
    }

    /// @notice Checks if an address is a proxy instance created by this factory
    /// @param vault Address to check
    /// @return True if the address is a factory instance, false otherwise
    function isInstance(
        address vault
    ) external view returns (bool) {
        return _getProxyFactoryStorage().isInstance[vault];
    }
}
