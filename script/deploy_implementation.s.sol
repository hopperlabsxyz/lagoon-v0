// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";

import {Vault} from "@src/vault/Vault.sol";
import {VaultLegacy} from "@src/vault0.0/VaultLegacy.sol";
import {Script, console} from "forge-std/Script.sol";

import {DefenderOptions} from "openzeppelin-foundry-upgrades/Options.sol";
import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract Deploy is Script {
    function run() external {
        // VaultLegacy;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Options memory opts;
        // opts.constructorData = abi.encode(false);
        vm.startBroadcast(deployerPrivateKey);

        new Vault(true);

        vm.stopBroadcast();

        // Arbitrum
        // source .env forge clean && forge script script/upgrade_arbitrum.s.sol --ffi -f <RPC_URL> --private-key
        // <PRIVATE_KEY> #--broadcast
    }
}
