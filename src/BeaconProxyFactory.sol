// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {InitStruct, Vault} from "@src/v0.3.0/Vault.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract BeaconProxyFactory is UpgradeableBeacon {
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

    function createBeaconProxy(
        bytes memory init
    ) public returns (address) {
        address proxy = address(
            new BeaconProxy(
                address(this), abi.encodeWithSelector(Vault.initialize.selector, init, REGISTRY, WRAPPED_NATIVE)
            )
        );
        isInstance[proxy] = true;
        instances.push(proxy);

        return address(proxy);
    }

    function createVaultProxy(
        InitStruct calldata init
    ) external returns (address) {
        return createBeaconProxy(abi.encode(init));
    }
}
