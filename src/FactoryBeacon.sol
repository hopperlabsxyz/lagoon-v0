// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {InitStruct, Vault} from "@src/v0.3.0/Vault.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IBeacon, UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract FactoryBeacon is UpgradeableBeacon {
    address public immutable registry;

    address public immutable wrappedNativeToken;

    mapping(address => bool) public isInstance;

    address[] public instances;

    constructor(
        address _registry,
        address _implementation,
        address _owner,
        address _wrappedNativeToken
    ) UpgradeableBeacon(_implementation, _owner) {
        registry = _registry;
        wrappedNativeToken = _wrappedNativeToken;
    }

    function createVaultProxy(
        InitStruct calldata init
    ) public returns (address) {
        address proxy = address(
            new BeaconProxy(
                address(this), abi.encodeWithSelector(Vault.initialize.selector, init, registry, wrappedNativeToken)
            )
        );
        isInstance[proxy] = true;
        instances.push(proxy);

        return address(proxy);
    }
}
