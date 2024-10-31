// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script, console} from "forge-std/Script.sol";

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*
  run `make beacon` to deploy this script
*/

contract DeployBeacon is Script {
    address BEACON_OWNER = vm.envAddress("BEACON_OWNER");

    function run() external {
        vm.startBroadcast();

        console.log("BEACON_OWNER:", BEACON_OWNER);

        Options memory opts;
        opts.constructorData = abi.encode(true);
        UpgradeableBeacon beacon = UpgradeableBeacon(Upgrades.deployBeacon("Vault.sol:Vault", BEACON_OWNER, opts));

        console.log("Beacon address: ", address(beacon));

        vm.stopBroadcast();
    }
}
