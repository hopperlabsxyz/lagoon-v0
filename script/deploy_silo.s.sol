// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Silo} from "@src/v0.5.0/Silo.sol";

import {ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";
import {Script, console} from "forge-std/Script.sol";

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*
  run `make protocol` to deploy this script
*/

contract DeploySilo is Script {
    function run() external virtual {
        address asset = vm.envAddress("ASSET");
        address wrappedNativeToken = vm.envAddress("WRAPPED_NATIVE_TOKEN");

        vm.startBroadcast();
        deploySilo(asset, wrappedNativeToken);
        vm.stopBroadcast();
    }

    function deploySilo(address _asset, address _wrappedNativeToken) internal returns (address) {
        console.log("--- deploySilo() ---");

        Options memory opts;
        opts.constructorData = abi.encode(true);

        Silo silo = new Silo(IERC20(_asset), _wrappedNativeToken);
        console.log("Silo address: ", address(silo));

        return address(silo);
    }
}
