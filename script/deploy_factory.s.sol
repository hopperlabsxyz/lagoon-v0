// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {BeaconProxyFactory} from "@src/protocol/BeaconProxyFactory.sol";
import {Script, console} from "forge-std/Script.sol";

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {IVersion} from "@test/IVersion.sol";

/*
  run `make beacon` to deploy this script
*/

contract DeployBeaconProxyFactory is Script {
    function deployBeaconProxyFactory(
        address _registry,
        address _implementation,
        address _owner,
        address _wrappedNativeToken
    ) internal returns (address) {
        console.log("--- deployBeaconProxyFactory() ---");
        console.log("Protocol registry:  ", _registry);
        console.log("Implementation:  ", _implementation);
        console.log("Owner:  ", _owner);

        BeaconProxyFactory beaconProxyFactory =
            new BeaconProxyFactory(_registry, _implementation, _owner, _wrappedNativeToken);

        console.log("Beacon proxy factory  address:", address(beaconProxyFactory));
        return address(beaconProxyFactory);
    }

    function run() external virtual {
        address FEE_REGISTRY = vm.envAddress("FEE_REGISTRY");
        address BEACON_OWNER = vm.envAddress("BEACON_OWNER");
        address WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");

        // ex: v0.3.0
        string memory tag = vm.envString("VERSION_TAG");

        vm.startBroadcast();

        Options memory opts;
        opts.constructorData = abi.encode(true);
        address IMPLEMENTATION = Upgrades.deployImplementation(string.concat(tag, "/Vault.sol:Vault"), opts);

        try IVersion(IMPLEMENTATION).version() returns (string memory version) {
            require(keccak256(abi.encode(tag)) == keccak256(abi.encode(version)), "Wrong beacon version deployed");
            console.log(string.concat(string.concat("Implementation ", version), " deployed."));
        } catch (bytes memory) {
            console.log("\x1b[33mWarning!\x1b[0m There is no `version()` on the contract deployed");
        }

        BeaconProxyFactory beaconProxyFactory = BeaconProxyFactory(
            deployBeaconProxyFactory({
                _registry: FEE_REGISTRY,
                _implementation: IMPLEMENTATION,
                _owner: BEACON_OWNER,
                _wrappedNativeToken: WRAPPED_NATIVE_TOKEN
            })
        );

        require(beaconProxyFactory.REGISTRY() == FEE_REGISTRY, "wrong registry address");
        require(beaconProxyFactory.WRAPPED_NATIVE() == WRAPPED_NATIVE_TOKEN, "wrong wrapped native token");
        require(beaconProxyFactory.owner() == BEACON_OWNER, "wrong beacon owner");

        vm.stopBroadcast();
    }
}
