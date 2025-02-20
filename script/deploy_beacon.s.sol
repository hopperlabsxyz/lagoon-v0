// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IBeacon, UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script, console} from "forge-std/Script.sol";

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {IVersion} from "@test/IVersion.sol";

/*
  run `make beacon` to deploy this script
*/

contract DeployBeacon is Script {
    function deployBeacon(address _owner, string memory versionTag) internal returns (address) {
        console.log("--- deployBeacon() ---");
        console.log("Beacon owner:  ", _owner);
        Options memory opts;
        opts.constructorData = abi.encode(true);
        UpgradeableBeacon beacon =
            UpgradeableBeacon(Upgrades.deployBeacon(string.concat(versionTag, "/Vault.sol:Vault"), _owner, opts));
        console.log("Beacon address:", address(beacon));
        return address(beacon);
    }

    function run() external virtual {
        address BEACON_OWNER = vm.envAddress("BEACON_OWNER");

        string memory tag = vm.envString("VERSION_TAG");

        vm.startBroadcast();
        address beacon = deployBeacon(BEACON_OWNER, tag);

        // todo: add try execpt
        // since <v0.2.1 does not implement version() this will revert without info
        require(
            keccak256(abi.encode(tag)) == keccak256(abi.encode(IVersion(IBeacon(beacon).implementation()).version())),
            "Wrong beacon version deployed"
        );
        vm.stopBroadcast();
    }
}

// Use carefully /!\
//
// This script just change the beacon implementation pointer and does not check for compabitibility between upgrades.
// contract UpgradeBeaconImplementation is Script {
//     function run() external {
//         vm.startBroadcast();
//         Options memory opts;
//         opts.constructorData = abi.encode(true);
//         address implementation = Upgrades.deployImplementation("v0.2.1/Vault.sol:Vault", opts);
//         vm.stopBroadcast();
//
//         console.log("implementation address:", implementation);
//     }
// }
