// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OptinProxy} from "@src/OptinProxy.sol";

interface IVault {
    function initialize(bytes memory data, address feeRegistry, address wrappedNativeToken) external;
}

struct OptinProxyFactoryStorage {
    /// @notice Address of the registry contract
    address REGISTRY;
    /// @notice Address of the wrapped native token (e.g. WETH)
    address WRAPPED_NATIVE;
    /// @notice Mapping to track whether an address is a proxy instance created by this factory
    mapping(address => bool) isInstance;
}

struct InitStruct {
    IERC20 underlying;
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

/// @title ProxyFactory
/// @notice A factory contract for creating OptinProxy instances with upgradeable functionality
/// @dev Inherits from UpgradeableBeacon to provide upgrade functionality for all created proxies
contract OptinProxyFactory is OwnableUpgradeable {
    event ProxyDeployed(address proxy, address deployer);

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.opt-inProxyFactory")) - 1)) & ~bytes32(uint256(0xff));
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant proxyFactoryStorage = 0xda29f9cce8913a5999de49b73cd9d621b583d9cae78170dc4846b93899df8600;

    function _getProxyFactoryStorage() internal pure returns (OptinProxyFactoryStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := proxyFactoryStorage
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(
        bool disable
    ) {
        if (disable) _disableInitializers();
    }

    /// @notice Constructs the BeaconProxyFactory
    /// @param _registry Address of the registry contract
    /// @param _wrappedNativeToken Address of the wrapped native token (e.g., WETH)
    function initialize(address _registry, address _wrappedNativeToken, address owner) public initializer {
        __Ownable_init(owner);
        OptinProxyFactoryStorage storage $ = _getProxyFactoryStorage();
        $.REGISTRY = _registry;
        $.WRAPPED_NATIVE = _wrappedNativeToken;
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
        OptinProxyFactoryStorage storage $ = _getProxyFactoryStorage();
        bytes memory call_data = abi.encodeCall(IVault.initialize, (abi.encode(init), $.REGISTRY, $.WRAPPED_NATIVE));

        address proxy = address(new OptinProxy{salt: salt}(_logic, $.REGISTRY, initialOwner, call_data));

        $.isInstance[proxy] = true;
        emit ProxyDeployed(proxy, msg.sender);

        return address(proxy);
    }

    function registry() external view returns (address) {
        return _getProxyFactoryStorage().REGISTRY;
    }

    function wrappredNativeToken() external view returns (address) {
        return _getProxyFactoryStorage().WRAPPED_NATIVE;
    }

    function isInstance(
        address vault
    ) external view returns (bool) {
        return _getProxyFactoryStorage().isInstance[vault];
    }
}
