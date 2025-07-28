// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {BeaconProxyFactory} from "@src/protocol-v1/BeaconProxyFactory.sol";
import {Script, console} from "forge-std/Script.sol";

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {OptinProxyFactory} from "@src/protocol-v2/OptinProxyFactory.sol";
import {IVersion} from "@test/IVersion.sol";

/*
  run `make beacon` to deploy this script
*/

contract DeployBeaconProxyFactory is Script {
    // function deployBeaconProxyFactory(
    //     address _registry,
    //     address _implementation,
    //     address _owner,
    //     address _wrappedNativeToken
    // ) internal returns (address) {
    //     console.log("--- deployBeaconProxyFactory() ---");
    //     console.log("Protocol registry:  ", _registry);
    //     console.log("Implementation:  ", _implementation);
    //     console.log("Owner:  ", _owner);

    //     BeaconProxyFactory beaconProxyFactory =
    //         new BeaconProxyFactory(_registry, _implementation, _owner, _wrappedNativeToken);

    //     console.log("Beacon proxy factory  address:", address(beaconProxyFactory));
    //     return address(beaconProxyFactory);
    // }

    function run() external virtual {
        address FEE_REGISTRY = vm.envAddress("REGISTRY");
        address DAO = vm.envAddress("DAO");

        address WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");

        vm.startBroadcast();
        deployOptinFactory(FEE_REGISTRY, WRAPPED_NATIVE_TOKEN, DAO);

        vm.stopBroadcast();
    }

    function deployOptinFactory(address _registry, address _wrappedNativeToken, address _DAO) public {
        console.log("--- Deploy Optin Factory ---");

        Options memory opts;
        opts.constructorData = abi.encode(true);
        bytes memory init =
            abi.encodeWithSelector(OptinProxyFactory.initialize.selector, _registry, _wrappedNativeToken, _DAO);
        address optinFactory =
            address(Upgrades.deployTransparentProxy("OptinProxyFactory.sol:OptinProxyFactory", _DAO, init, opts));
        console.log("Optin Factory:", optinFactory);
    }
}
