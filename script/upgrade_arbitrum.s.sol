// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";
import {Vault} from "@src/vault0.1/Vault.sol";
import {Script, console} from "forge-std/Script.sol";

import {DefenderOptions} from "openzeppelin-foundry-upgrades/Options.sol";
import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract Deploy is Script {
    // upgrade info from previous deployment
    address vaultProxy = 0x73FC6DE92c9F502046Ca49F36c0B8C968575356D;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        Upgrades.upgradeProxy(vaultProxy, "Vault.sol:Vault", "");

        vm.stopBroadcast();

        // Arbitrum
        // source .env forge clean && forge script script/upgrade_arbitrum.s.sol --ffi -f <RPC_URL> --private-key
        // <PRIVATE_KEY> #--broadcast
    }
}
