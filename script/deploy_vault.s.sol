// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {InitStruct, Vault} from "@src/v0.2.1/Vault.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script, console} from "forge-std/Script.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*
  run `make vault` to deploy this script
*/

contract DeployVault is Script {
    function _loadInitStructFromEnv() internal view returns (InitStruct memory v, address beacon) {
        // General
        address UNDERLYING = vm.envAddress("UNDERLYING");
        address WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");
        address FEE_REGISTRY = vm.envAddress("FEE_REGISTRY");
        beacon = vm.envAddress("BEACON");
        string memory NAME = vm.envString("NAME");
        string memory SYMBOL = vm.envString("SYMBOL");
        bool ENABLE_WHITELIST = vm.envBool("ENABLE_WHITELIST");

        // Fees
        uint16 MANAGEMENT_RATE = uint16(vm.envUint("MANAGEMENT_RATE"));
        uint16 PERFORMANCE_RATE = uint16(vm.envUint("PERFORMANCE_RATE"));
        uint256 RATE_UPDATE_COOLDOWN = vm.envUint("RATE_UPDATE_COOLDOWN");

        // Roles
        address SAFE = vm.envAddress("SAFE");
        address FEE_RECEIVER = vm.envAddress("FEE_RECEIVER");
        address ADMIN = vm.envAddress("ADMIN");
        address WHITELIST_MANAGER = vm.envAddress("WHITELIST_MANAGER");
        address VALUATION_MANAGER = vm.envAddress("VALUATION_MANAGER");
        v = InitStruct({
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
    }

    function deployVault(InitStruct memory init, address beacon) internal returns (address) {
        console.log("--- deployVault() ---");

        console.log("Beacon:              ", beacon);
        console.log("Underlying:          ", address(init.underlying));
        console.log("Wrapped_native_token:", init.wrappedNativeToken);
        console.log("Fee_registry:        ", init.feeRegistry);
        console.log("Name:                ", init.name);
        console.log("Symbol:              ", init.symbol);
        console.log("Enable_whitelist:    ", init.enableWhitelist);
        console.log("Management_rate:     ", init.managementRate);
        console.log("Performance_rate:    ", init.performanceRate);
        console.log("Rate_update_cooldown:", init.rateUpdateCooldown);
        console.log("Safe:                ", init.safe);
        console.log("Fee_receiver:        ", init.feeReceiver);
        console.log("Admin:               ", init.admin);
        console.log("Whitelist_manager:   ", init.whitelistManager);
        console.log("Valuation_manager:   ", init.valuationManager);

        BeaconProxy proxy = BeaconProxy(
            payable(Upgrades.deployBeaconProxy(beacon, abi.encodeWithSelector(Vault.initialize.selector, init)))
        );

        // todo
        // whitelist the following addresses:
        // - feeReceiver
        // - protocolFeeReceiver
        // - safe
        // - pendingSilo

        console.log("Vault proxy address: ", address(proxy));
        return address(proxy);
    }

    function run() external virtual {
        vm.startBroadcast();
        (InitStruct memory v, address beacon) = _loadInitStructFromEnv();
        deployVault(v, beacon);
        vm.stopBroadcast();
    }
}
