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
    function deployBeacon(
        address _owner
    ) internal returns (address) {
        console.log("--- deployBeacon() ---");
        console.log("Beacon owner:  ", _owner);
        Options memory opts;
        opts.constructorData = abi.encode(true);
        UpgradeableBeacon beacon = UpgradeableBeacon(Upgrades.deployBeacon("Vault0.2.1.sol:Vault0_2_1", _owner, opts));
        console.log("Beacon address:", address(beacon));
        return address(beacon);
    }

    function run() external virtual {
        address BEACON_OWNER = vm.envAddress("BEACON_OWNER");
        string memory tag = vm.envString("VERSION_TAG");

        require(keccak256(abi.encode(tag)) == keccak256("v0.2.1"), "Can only deploy v0.2.1 vault for now");

        vm.startBroadcast();
        deployBeacon(BEACON_OWNER);
        vm.stopBroadcast();
    }
}

// Use carefully /!\
//
// This script just change the beacon implementation pointer and does not check for compabitibility between upgrades.
contract UpgradeBeaconImplementation is Script {
    function run() external {
        vm.startBroadcast();
        Options memory opts;
        opts.constructorData = abi.encode(true);
        address implementation = Upgrades.deployImplementation("Vault.sol:Vault", opts);
        vm.stopBroadcast();

        console.log("implementation address:", implementation);
    }
}
