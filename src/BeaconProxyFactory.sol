// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

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

contract BeaconProxyFactory is UpgradeableBeacon {
    event BeaconProxyDeployed(address proxy, address deployer);

    address public immutable REGISTRY;

    address public immutable WRAPPED_NATIVE;

    mapping(address => bool) public isInstance;

    address[] public instances;

    constructor(
        address _registry,
        address _implementation,
        address _owner,
        address _wrappedNativeToken
    ) UpgradeableBeacon(_implementation, _owner) {
        REGISTRY = _registry;
        WRAPPED_NATIVE = _wrappedNativeToken;
    }

    function createBeaconProxy(bytes memory init, bytes32 salt) public returns (address) {
        address proxy = address(
            new BeaconProxy{salt: keccak256(abi.encode(block.chainid, salt))}(
                address(this), abi.encodeWithSelector(IVault.initialize.selector, init, REGISTRY, WRAPPED_NATIVE)
            )
        );
        isInstance[proxy] = true;
        instances.push(proxy);

        emit BeaconProxyDeployed(proxy, msg.sender);

        return address(proxy);
    }

    function createVaultProxy(InitStruct calldata init, bytes32 salt) external returns (address) {
        return createBeaconProxy(abi.encode(init), salt);
    }
}
