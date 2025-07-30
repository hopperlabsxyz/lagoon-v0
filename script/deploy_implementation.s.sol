// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {BeaconProxyFactory} from "@src/protocol-v1/BeaconProxyFactory.sol";
import {Script, console} from "forge-std/Script.sol";

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {IVersion} from "@test/IVersion.sol";

/*
  run `make implementation` to deploy this script
*/

contract DeployImplementation is Script {
    address IMPLEMENTATION;

    function run() external virtual {
        // ex: v0.3.0
        string memory tag = vm.envString("VERSION_TAG");

        vm.startBroadcast();
        Options memory opts;
        opts.constructorData = abi.encode(true);
        IMPLEMENTATION = Upgrades.deployImplementation(string.concat(tag, "/Vault.sol:Vault"), opts);

        try IVersion(IMPLEMENTATION).version() returns (string memory version) {
            require(keccak256(abi.encode(tag)) == keccak256(abi.encode(version)), "Wrong beacon version deployed");
            console.log(string.concat(string.concat("Implementation ", version), " deployed."));
        } catch (bytes memory) {
            console.log("\x1b[33mWarning!\x1b[0m There is no `version()` on the contract deployed");
        }

        vm.stopBroadcast();
        console.log("Implementation address: ", IMPLEMENTATION);
    }
}
