// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Vault} from "../src/vault/Vault.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script, console} from "forge-std/Script.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*
  run `make vault` to deploy this script
*/

contract DeployVault is Script {
    // General
    address UNDERLYING = vm.envAddress("UNDERLYING");
    address WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");
    address FEE_REGISTRY = vm.envAddress("FEE_REGISTRY");
    address BEACON = vm.envAddress("BEACON");
    string NAME = vm.envString("NAME");
    string SYMBOL = vm.envString("SYMBOL");
    bool ENABLE_WHITELIST = vm.envBool("ENABLE_WHITELIST");

    // Fees
    uint16 MANAGEMENT_RATE = uint16(vm.envUint("MANAGEMENT_RATE"));
    uint16 PERFORMANCE_RATE = uint16(vm.envUint("PERFORMANCE_RATE"));
    uint256 RATE_UPDATE_COOLDOWN = vm.envUint("RATE_UPDATE_COOLDOWN") * 1 days;

    // Roles
    address SAFE = vm.envAddress("SAFE");
    address FEE_RECEIVER = vm.envAddress("FEE_RECEIVER");
    address ADMIN = vm.envAddress("ADMIN");
    address WHITELIST_MANAGER = vm.envAddress("WHITELIST_MANAGER");
    address VALUATION_MANAGER = vm.envAddress("VALUATION_MANAGER");

    function run() external {
        vm.startBroadcast();

        console.log("UNDERLYING:", UNDERLYING);
        console.log("WRAPPED_NATIVE_TOKEN:", WRAPPED_NATIVE_TOKEN);
        console.log("FEE_REGISTRY:", FEE_REGISTRY);
        console.log("BEACON:", BEACON);
        console.log("NAME:", NAME);
        console.log("SYMBOL:", SYMBOL);
        console.log("ENABLE_WHITELIST:", ENABLE_WHITELIST);
        console.log("MANAGEMENT_RATE:", MANAGEMENT_RATE);
        console.log("PERFORMANCE_RATE:", PERFORMANCE_RATE);
        console.log("RATE_UPDATE_COOLDOWN:", RATE_UPDATE_COOLDOWN);
        console.log("SAFE:", SAFE);
        console.log("FEE_RECEIVER:", FEE_RECEIVER);
        console.log("ADMIN:", ADMIN);
        console.log("WHITELIST_MANAGER:", WHITELIST_MANAGER);
        console.log("VALUATION_MANAGER:", VALUATION_MANAGER);

        Vault.InitStruct memory v = Vault.InitStruct({
            underlying: IERC20(UNDERLYING),
            name: NAME,
            symbol: SYMBOL,
            safe: SAFE,
            whitelistManager: WHITELIST_MANAGER,
            valuationManager: VALUATION_MANAGER,
            admin: ADMIN,
            feeReceiver: FEE_RECEIVER,
            feeRegistry: FEE_REGISTRY,
            managementRate: MANAGEMENT_RATE,
            performanceRate: PERFORMANCE_RATE,
            wrappedNativeToken: WRAPPED_NATIVE_TOKEN,
            enableWhitelist: ENABLE_WHITELIST,
            rateUpdateCooldown: RATE_UPDATE_COOLDOWN
        });

        BeaconProxy proxy = BeaconProxy(
            payable(Upgrades.deployBeaconProxy(BEACON, abi.encodeWithSelector(Vault.initialize.selector, v)))
        );

        // todo
        // whitelist the following addresses:
        // - feeReceiver
        // - protocolFeeReceiver
        // - safe
        // - pendingSilo

        console.log("Vault proxy address: ", address(proxy));

        vm.stopBroadcast();
    }
}
